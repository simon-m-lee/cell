# `HowTo-Cell.apply.md`

*A complete guide to `Cell.apply`, `ApplyCommand`, and `ApplyOutcome` — for humans and AI agents.*

---

## 0. TL;DR

```dart
final outcome = await cell.apply<int>((
  function: someWhitelistedFn,
  arguments: (positionalArguments: [arg1, arg2], namedArguments: null),
  compensation: null, // only used by txApply
));

switch (outcome) {
  case ApplyAccepted<int>(:final result, :final receipt):
    // Gate approved (or didn't need to run — check receipt.vetted).
  case ApplyRejected<int>(:final reason, :final receipt):
    // Gate denied.
  case ApplyStaged(:final receipt):
    // Queued inside a transaction — call tx.commit().
}
```

`Cell.apply` is a **command gateway**, not a **security boundary**. Read §4 before you trust it for access control.

---

## 1. What `Cell.apply` actually is

`Cell.apply` is the framework's **Command Pattern entry point**. It takes a single `ApplyCommand` record — function + arguments + optional compensation — and returns an `ApplyOutcome`.

It does four things, and only four:

1. **Records a receipt** — an immutable, timestamped audit trail for every attempt (`ApplyLedger.receipt`).
2. **Checks the whitelist** — if `command.function` is in `cell.modifiable`, the call is *vetted* and routed through `TestCell.action`.
3. **Stages into a transaction** — if `tx` is provided, the command is enqueued instead of executed (`ApplyStaged`).
4. **Returns a typed outcome** — one of `ApplyAccepted<R>`, `ApplyRejected<R>`, or `ApplyStaged`.

It does **not** invoke compensation. That's `txApply`'s job (§9).
It does **not** fire veto conversion. That's also `txApply`'s job (§8).
It is **not** a sandbox. See §4.

---

## 2. When to use `apply` — and when not to

### Use `apply` when

| Situation | Why `apply` helps |
|---|---|
| You need an **audit trail** for a mutation | Every call produces an `ApplyReceipt` with a unique `id` and `timestamp` |
| You want **policy-gated mutations** (`TestCell.action`) | Vetted functions go through the integrity gate |
| You need to **stage commands** for atomic execution | Pass `tx: someTxApplyScope` |
| You want to **declare compensation** | Package the reversal alongside the action (§10) |
| You want a **uniform call surface** for heterogeneous cells | A generic controller doesn't need to know concrete types |

### Do **not** use `apply` when

| Situation | Use instead |
|---|---|
| Mutating a `ValueCell`'s value | `handle.update(v)` or `handle.updateAsync(v)` — `apply` is for *commands*, not *values* |
| You need **atomic multi-cell value updates** | `Cell.transaction()` + `tx.update(cell, value)` |
| Your logic is a direct method call on a known-typed cell | Just call the method — `apply` is overhead |
| You're trying to **prevent** a caller from invoking a function | **`apply` alone won't stop it.** See §4. |

---

## 3. The API at a glance

### 3.1 `ApplyCommand`

```dart
typedef ApplyCommand = ({
  Function function,
  ApplyArguments arguments,
  ApplyCompensation? compensation,
});

typedef ApplyArguments = ({
  List<Object?>? positionalArguments,
  Map<Symbol, Object?>? namedArguments,
});

typedef ApplyCompensation = ({
  Function function,
  ApplyArguments arguments,
  Cell? cell, // null = compensate on the same cell
});
```

All three are plain Dart records. Nullability is permissive: arguments and compensation are optional.

### 3.2 `ApplyOutcome<R>` (sealed)

| Case | Meaning | Fields |
|---|---|---|
| `ApplyAccepted<R>` | Function executed, result available | `result: R`, `receipt` |
| `ApplyRejected<R>` | Gate refused; **nothing executed** | `reason: Object?`, `receipt` |
| `ApplyStaged` (extends `ApplyOutcome<Never>`) | Queued in a transaction, **not yet executed** | `receipt` |

`ApplyStaged` deliberately carries `Never` as the result type — there is no result until the transaction commits.

### 3.3 `ApplyReceipt`

```dart
typedef ApplyReceipt = ({
  String id,             // unique correlation id
  Cell cell,             // the cell that received the command
  Function function,     // the function that was requested
  ApplyArguments arguments,
  DateTime timestamp,    // submission time
  int? txSequence,       // position in the transaction, if staged
  bool vetted,           // did the gate participate?
});
```

`vetted` is the single most important field on the receipt. See §4.

### 3.4 `ApplyCommandRunner` (the DSL)

Fluent builder that produces an `ApplyCommand`. See §11.

```dart
await cell.command(fn).args([1]).named({#k: v}).undo(undoFn).run<int>();
```

---

## 4. The critical concept: **vetted vs. unvetted**

This is the one thing you must understand or `apply` will bite you.

`CellBase.apply` starts with:

```dart
final vetted = modifiable.contains(command.function);
```

From there, two completely different paths diverge:

```
                    ┌─────────────────────────────────┐
  apply(command) ──▶│  modifiable.contains(function)? │
                    └────────────────┬────────────────┘
                             yes ────┴──── no
                              │            │
                  ┌───────────▼──┐     ┌───▼──────────────┐
                  │ VETTED path  │     │ UNVETTED path    │
                  │ gate runs    │     │ gate skipped     │
                  │ TestCell     │     │ function         │
                  │  .action()   │     │ executes         │
                  │              │     │ receipt.vetted   │
                  │ if approved: │     │  = false         │
                  │   execute    │     │                  │
                  │ if rejected: │     │                  │
                  │   ApplyRejected                    │
                  └──────────────┘     └──────────────────┘
```

### What this means in practice

- **`modifiable` is a gate-list, not an allow-list.** A function *in* `modifiable` must pass `TestCell.action` to execute. A function *not in* `modifiable` executes without any gate check at all.
- **The default `modifiable` is `{apply}`.** For every built-in cell type (`ValueCell`, `_Cell`, `_OpenCell`), the only "vetted" function is `apply` itself — a circular no-op. In practice, **every domain command you pass through `apply` on a stock cell is unvetted.**
- **The docstring on `Cell.modifiable` says "whitelist of functions authorized for execution."** The implementation is the opposite: functions *not* in the manifest are authorized unconditionally. Trust the code, not the docstring.

### So how do you get real gating?

Override `modifiable` on your cell subclass and attach a `TestCell.action` that inspects function identity:

```dart
class AccountCell extends CellBase {
  AccountCell()
      : super(
          context: Context.module('Accounts'),
          testRule: TestCell<Cell>((obj, {host, arguments, user}) {
            // Runs for pulses AND vetted commands.
            if (obj is Function) {
              // Command path — inspect the function.
              final allowed = (host as AccountCell).modifiable.contains(obj);
              return allowed;
            }
            // Pulse path (ValueCell updates, etc.) — see other TestRules.
            return true;
          }),
        );

  int _balance = 100;

  void deposit(int amount) { _balance += amount; }
  void withdraw(int amount) { _balance -= amount; }

  @override
  Iterable<Function> get modifiable => {deposit, withdraw, ...super.modifiable};
}
```

Now:

```dart
final acc = AccountCell();
await acc.apply<void>((function: acc.deposit, arguments: (positionalArguments: [50], namedArguments: null), compensation: null));
// → vetted = true, gate runs, then deposit(50) executes
// → receipt.vetted == true

await acc.apply<void>((function: () => print('sneaky'), arguments: (positionalArguments: null, namedArguments: null), compensation: null));
// → vetted = false, executes anyway, receipt.vetted == false
```

If you need to **prevent** the second call, the cell cannot — the caller has the cell reference and `apply` runs unvetted functions by design. Prevention requires *not* exposing `apply` to that caller, or wrapping your cell so `apply` itself is not a public method.

### Deputies and gating

A `deputy(testRule: TestCell.readOnly)` (with the §3 fix applied) *will* reject vetted commands. But because the default `modifiable` doesn't contain user functions, even a read-only deputy permits unvetted commands — unless the deputy's cell subclass overrides `modifiable` to include them.

**Bottom line:** if you want `apply` to be a security boundary, you must (a) override `modifiable` to include every function callers might invoke, and (b) attach a `TestCell.action` that decides which of those are permitted. Otherwise `apply` is an audit tool, not a gate.

---

## 5. Sync vs. async

`apply` returns `FutureOr<ApplyOutcome<R>>`.

The synchronous path holds when the gate's `TestCell.action` returns `bool`. If it returns `Future<bool>`, `apply` returns a `Future<ApplyOutcome<R>>`:

```dart
// Gate rule:
final remoteAuthRule = TestActionRule<Cell>((action, {required host, arguments, user}) async {
  return await authService.canInvoke(host.context, action);
});

// Caller: always await. Works either way.
final outcome = await cell.apply<int>(cmd);
```

**Rule of thumb:** always `await` the result. The `FutureOr` distinction is invisible to correct callers; only code that manually branches on `is Future` can mishandle it.

---

## 6. Handling outcomes

`ApplyOutcome` is `sealed` — exhaustive `switch` gives compile-time guarantees.

```dart
final outcome = await cell.apply<int>(cmd);

switch (outcome) {
  case ApplyAccepted<int>(:final result, :final receipt):
    log('ok id=${receipt.id} vetted=${receipt.vetted}');
    use(result);

  case ApplyRejected<int>(:final reason, :final receipt):
    log('rejected: $reason');
    // Nothing executed — safe to retry, fix args, or escalate.

  case ApplyStaged(:final receipt):
    // You passed a tx. Call tx.commit() somewhere upstream.
    assert(receipt.txSequence != null);
    await tx!.commit();
}
```

### What `ApplyAccepted` does *not* mean

- **It does not mean the state is committed.** The function returned. Whether it left the world consistent is up to the function.
- **It does not mean the gate approved.** If `receipt.vetted` is `false`, the gate never ran.
- **It does not mean the result is not a veto.** See §8 — `apply` outside `txApply` does not auto-convert `ApplyVeto`.

### What `ApplyRejected` guarantees

Nothing executed. The gate refused the call. State is unchanged by this command.

### What `ApplyStaged` guarantees

The command is enqueued. It will execute on `tx.commit()`, or be discarded on `tx.rollback()`. The receipt's `txSequence` is its position in the queue.

---

## 7. The DSL — `ApplyCommandRunner`

For readability when building non-trivial commands.

```dart
final runner = cell.command(account.withdraw);   // picks the function

final cmd = runner
    .args([50])                                   // positional
    .named({#reason: 'ATM'})                      // named
    .undo(account.deposit, args: [50])            // compensation
    .build();                                     // → ApplyCommand

// Or run it directly:
final outcome = await runner.run<int>();
```

Notes:

- `runner` is mutable during construction (`args`, `named`, `undo` mutate fields) and short-lived. Reuse across calls is legal but confusing; construct a fresh one.
- `.arg(x)` is a single-arg shorthand for `.args([x])`.
- `.undo(fn, args: [...], named: {...}, cell: maybeAnotherCell)` — `cell: null` means "the same cell that received the command".
- `.run<R>({tx})` is literally `cell.apply<R>(build(), tx: tx)`. There is no other behavior.

The DSL is pure syntax sugar. Every example in the rest of this document can be written either way.

---

## 8. `ApplyVeto` — soft rejection from inside the function

Sometimes the function itself discovers, mid-execution, that it should not complete. It can return `ApplyVeto.instance`:

```dart
Object? transfer(Account to, int amount) {
  if (balance < amount) {
    return ApplyVeto.instance;   // soft rejection
  }
  balance -= amount;
  return null;                   // success
}
```

### Behavior depends on the transaction

| Path | What happens |
|---|---|
| **Plain `apply` (no `tx`)** | Returns `ApplyAccepted(ApplyVeto.instance, receipt)`. **You must inspect the result.** The framework does *not* auto-convert. |
| **`apply` inside `txApply` (`tx:`)**, at commit | `txApply` detects the veto via `_isApplyRejected` and treats it as a **rejection**, triggering compensation for earlier commands. |

So in a plain `apply`:

```dart
final outcome = await cell.apply<Object?>(cmd);
if (outcome case ApplyAccepted<Object?>(:final result)) {
  if (result is ApplyVeto) {
    // soft rejection — do not treat as success
  }
}
```

Or use `txApply` when you need the framework to handle veto for you.

### When to prefer `ApplyVeto` over `throw`

- **`ApplyVeto`** — expected, domain-level rejection. The caller should treat it as "not accepted" and proceed.
- **`throw`** — unexpected error. The call fails; `txApply` compensates.

Returning `ApplyVeto` is cheap; throwing builds a stack trace.

---

## 9. Transactions: `apply` with a `tx`

`Cell.apply` accepts an `ApplyTransactionScope` (created via `Cell.txApply()`).

```dart
final tx = Cell.txApply();

await tx.begin([accountA, accountB]);

final stagedA = await accountA.apply<void>((
  function: accountA.deposit,
  arguments: (positionalArguments: [100], namedArguments: null),
  compensation: (function: accountA.withdraw, arguments: (positionalArguments: [100], namedArguments: null), cell: null),
), tx: tx);
// stagedA is ApplyStaged — nothing has executed yet

final stagedB = await accountB.apply<void>((
  function: accountB.withdraw,
  arguments: (positionalArguments: [100], namedArguments: null),
  compensation: null,
), tx: tx);

await tx.commit();   // both commands execute atomically (with compensation on failure)
```

### What `txApply` guarantees

- **Atomic attempt.** All staged commands are attempted; the first failure triggers compensation for previously-*executed* commands (§10).
- **Gate is re-checked at commit.** A function removed from `modifiable` between staging and commit will be rejected.
- **Compensation is invoked on failure** for commands that actually ran.
- **Ordering is preserved** — commands execute in staging order. `receipt.txSequence` is the position.

### What `txApply` does **not** do

- **No isolation levels.** Unlike `Cell.transaction` (repeatable-read etc.), `txApply` is a strict serial executor. It doesn't snapshot values.
- **No value buffering.** You can't `tx.update(cell, value)` — that's `Cell.transaction`. `txApply` only executes commands.
- **No re-entrancy.** You can't call `begin` while a scope is open.

### `txApply` vs. `Cell.transaction` — pick one

| You want to… | Use |
|---|---|
| Buffer `ValueCell` updates and commit atomically | **`Cell.transaction()`** + `tx.update(cell, value)` |
| Read with a snapshot (repeatable-read, serializable) | **`Cell.transaction()`** + `tx.read(cell)` |
| Stage **commands** with compensation | **`Cell.txApply()`** + `cell.apply(cmd, tx: tx)` |
| Rollback via compensation functions | **`Cell.txApply()`** |
| Rollback via value discard | **`Cell.transaction()`** |

`apply` only accepts `ApplyTransactionScope` (from `txApply`). It does **not** accept `TransactionScope` (from `Cell.transaction`).

### Convenience: `execute`

```dart
await tx.execute(
  participants: [accountA, accountB],
  body: (tx) {
    accountA.apply(cmdA, tx: tx);  // ApplyStaged
    accountB.apply(cmdB, tx: tx);
  },
);
// begin / commit are handled; rollback happens if body throws
```

`execute` is `begin` → `body` → `commit`, with automatic rollback on `body` throwing. The `body` is synchronous (its commands are staged) — awaiting individual `apply` calls inside `body` is legal but wasteful.

---

## 10. Compensation

`ApplyCommand.compensation` is **only consumed by `txApply`**. Plain `apply` ignores it entirely.

### Shape

```dart
compensation: (
  function: account.deposit,          // what to run to reverse the change
  arguments: (positionalArguments: [100], namedArguments: null),
  cell: null,                          // null = same cell that received the command
)
```

The `cell` field lets a command on cell A be reversed by logic on cell B:

```dart
compensation: (
  function: ledger.recordRefund,
  arguments: (positionalArguments: [txId], namedArguments: null),
  cell: ledger,   // compensate on a different cell
)
```

### When compensation runs

- **`tx.commit()`** — if any staged command fails or vetoes, previously-executed commands are compensated in reverse order.
- **`tx.rollback()`** — all executed commands are compensated in reverse order.
- **`tx.rollback(savepoint: sp)`** — commands staged *after* the savepoint are compensated and discarded.

### What compensation does **not** do

- **It does not run on plain `apply` failures.** Plain `apply` doesn't fail — it returns `ApplyAccepted`, `ApplyRejected`, or `ApplyStaged`. Only `txApply` invokes compensation.
- **It does not run for commands that never executed.** Unless `compensateIfNotExecuted: true` is set in `TxApplyOptions`.
- **It is not automatic retry.** Compensation runs once per executed command; retry policy for *compensation itself* is configured via `compensationMaxAttempts`.

### Failure handling

Configure via `TxApplyOptions`:

```dart
final tx = Cell.txApply(TxApplyOptions(
  stopOnFirstFailure: true,
  compensateIfNotExecuted: false,
  compensationErrorPolicy: CompensationErrorPolicy.collectThenThrow,
  compensationMaxAttempts: 3,
  compensationBackoff: (attempt) => Duration(milliseconds: 50 * attempt),
));
```

If compensation itself fails and `collectThenThrow` is set, `commit` throws `TxApplyCompensationException` carrying a list of `CompensationFailure`.

---

## 11. Common patterns

### Pattern 1 — One-off audited mutation

```dart
final outcome = await user.apply<void>((
  function: user.setName,
  arguments: (positionalArguments: ['Alice'], namedArguments: null),
  compensation: null,
));
if (outcome is ApplyRejected) throw StateError('refused: ${outcome.reason}');
```

### Pattern 2 — Domain cell with real gating

```dart
class UserCell extends CellBase {
  String _name = '';
  void setName(String n) { _name = n; }

  @override
  Iterable<Function> get modifiable => {setName, ...super.modifiable};

  @override
  TestCell get validate => TestCell.chain([
    // Original rule
    _nucleus.testRule,
    // Only Alice can call setName
    TestActionRule<Cell>((fn, {required host, arguments, user}) {
      if (fn != setName) return true;
      return (host.context as ModuleContext).identity == 'Alice';
    }),
  ]);
}

await user.apply<void>((function: user.setName, arguments: (positionalArguments: ['Alice'], namedArguments: null), compensation: null));
// → vetted=true, gate runs, approved, setName('Alice') executes
```

### Pattern 3 — Transfer with compensation (Saga)

```dart
final tx = Cell.txApply();

await tx.execute(
  participants: [from, to],
  body: (tx) {
    from.apply<void>((
      function: from.debit,
      arguments: (positionalArguments: [100], namedArguments: null),
      compensation: (
        function: from.credit,
        arguments: (positionalArguments: [100], namedArguments: null),
        cell: null,
      ),
    ), tx: tx);

    to.apply<void>((
      function: to.credit,
      arguments: (positionalArguments: [100], namedArguments: null),
      compensation: (
        function: to.debit,
        arguments: (positionalArguments: [100], namedArguments: null),
        cell: null,
      ),
    ), tx: tx);
  },
);
// If to.credit throws, from.credit (compensation) runs.
```

### Pattern 4 — Remote authorization gate

```dart
final remoteAuth = TestActionRule<Cell>((fn, {required host, arguments, user}) async {
  return await authService.canInvoke(host.context, fn);
});

final cell = Cell.governed(
  context: Context.module('Payments'),
  testRule: TestCell.chain([remoteAuth]),
);

// apply now returns a Future
final outcome = await cell.apply<void>(cmd);
```

### Pattern 5 — Veto-driven conditional

```dart
Object? tryPurchase(Item item, int amount) {
  if (balance < amount) return ApplyVeto.instance;
  if (!item.inStock)     return ApplyVeto.instance;
  balance -= amount;
  return null;
}

// In txApply:
await tx.commit();   // veto → ApplyRejected path → compensation runs
```

### Pattern 6 — Fluent builder

```dart
final outcome = await cell
    .command(account.withdraw)
    .args([50])
    .named({#reference: 'ATM-991'})
    .undo(account.deposit, args: [50])
    .run<void>(tx: tx);
```

---

## 12. Anti-patterns and gotchas

### ✗ Trusting `apply` as a security boundary

`apply` does not gate unvetted functions. If you pass an arbitrary function reference and it isn't in `modifiable`, it runs. `apply` audits; it does not sandbox.

### ✗ Mutating a `ValueCell` via `apply`

```dart
// WRONG: circumvents the standard update path; state may not propagate.
await cell.apply<void>((
  function: (int v) => (cell as ValueCell<int>).value = v,  // also, `value` setter is _emit
  ...
));

// RIGHT: use the handle
handle.update(42);
await handle.updateAsync(43);
```

### ✗ Forgetting to commit a staged command

```dart
await cell.apply<void>(cmd, tx: tx);
// Nothing happened. You got ApplyStaged. Call tx.commit().
```

### ✗ Assuming `ApplyAccepted` means "state is now consistent"

`ApplyAccepted` means "the function returned." If the function throws internally without re-throwing, or leaves partial work in place, `apply` cannot know.

### ✗ Expecting compensation to fire on a plain `apply`

```dart
await cell.apply<void>(cmd); // command.compensation is IGNORED
```

Compensation is a `txApply` concept.

### ✗ Expecting `ApplyVeto` to be auto-converted

Plain `apply` returns `ApplyAccepted(ApplyVeto.instance)`. Only `txApply` treats veto as rejection.

### ✗ Assuming `ApplyStaged` has a result

`ApplyStaged` extends `ApplyOutcome<Never>`. There is no `result` field. Read `receipt.txSequence` for ordering, and the actual result — if you need it — becomes available only after commit through the function's side effects (there is no return-value channel back through `tx.commit()`).

### ✗ Expecting `receipt.vetted == true` without overriding `modifiable`

Stock cells have `modifiable == {apply}`. `receipt.vetted` will be `false` for every non-`apply` command you send. If you need audit of gate participation, override `modifiable` on your cell subclass.

### ✗ Passing a `TransactionScope` as `tx`

```dart
final tx = Cell.transaction(); // TransactionScope
cell.apply(cmd, tx: tx);       // TYPE ERROR: apply expects ApplyTransactionScope
```

`Cell.transaction` and `Cell.txApply` are distinct mechanisms.

### ✗ Relying on `late final`-adjacent behavior

`apply` returns whatever the gate returns. If the gate is synchronous, the call is synchronous. Don't write:

```dart
final outcome = cell.apply<int>(cmd);
if (outcome is Future) { ... } // fragile
```

Just `await`.

---

## 13. For AI agents

### 13.1 Decision tree

1. **Are you mutating a `ValueCell`'s scalar value?**
   → No. Stop. Use `handle.update(v)` / `handle.updateAsync(v)`. Do not use `apply`.
   → Yes → continue.

2. **Is the operation a *command* that needs audit, policy gating, or transaction staging?**
   → No → call the method directly.
   → Yes → continue.

3. **Does it need to be atomic with other commands?**
   → Yes → create `Cell.txApply()`, pass `tx:` to every `apply`, then `tx.commit()`.
   → No → plain `apply`.

4. **Does the command have a reversible side effect?**
   → Yes → declare `compensation:` in the command.
   → No → `compensation: null`.

5. **Does the gate need async approval?**
   → Yes → the `TestCell.action` returns `Future<bool>`; `await` the outcome.
   → No → sync gate.

### 13.2 Checklist — before calling `apply`

- You're using the **principal** cell, or a deputy whose `testRule` you actually want applied.
- The `function` either is in `cell.modifiable` (the receipt records `vetted: true`) or is a caller function the integrity gate must authorize — the gate runs **either way**.
- `arguments.positionalArguments` matches the function's positional arity exactly.
- `arguments.namedArguments` uses `#symbol` keys (e.g. `{#name: 'x'}`, not `{'name': 'x'}`).
- If you passed `tx:`, you will call `tx.commit()` (or `tx.rollback()`) afterwards.
- You will inspect **all three** outcome variants — not just `ApplyAccepted`.
- If the function might veto, you check for `ApplyRejected` — a returned `ApplyVeto` is reported as `ApplyRejected`, not as a successful outcome.

### 13.3 Required outcome handling

```dart
final outcome = await cell.apply<int>(cmd);

switch (outcome) {
  case ApplyAccepted<int>(:final result, :final receipt):
    if (result is ApplyVeto) {
      return Err('vetoed by function (id=${receipt.id})');
    }
    return Ok(result);

  case ApplyRejected<int>(:final reason, :final receipt):
    return Err('rejected by gate: $reason (id=${receipt.id})');

  case ApplyStaged(:final receipt):
    // You passed a tx — commit it now.
    assert(receipt.txSequence != null);
    await tx!.commit();
    return Ok(null);
}
```

Do not omit any branch. `ApplyStaged` falling through means the caller's transaction never commits and the command is silently lost.

### 13.4 Logging discipline

Always record at minimum:

```dart
log([
  'apply', receipt.id,
  'fn=${receipt.function}',
  'vetted=${receipt.vetted}',
  'txSeq=${receipt.txSequence}',
  'at=${receipt.timestamp.toIso8601String()}',
].join(' '));
```

Without `vetted`, you cannot tell from logs whether the gate even participated.

### 13.5 Compact rules (system-prompt snippet)

```
- apply(command) is a Command gateway, not a security sandbox.
- If command.function ∈ cell.modifiable → gate runs (TestCell.action).
  Else → function executes ungated, receipt.vetted = false.
- Default modifiable = {apply}. Real gating requires overriding modifiable.
- Outcomes are sealed: ApplyAccepted<R> | ApplyRejected<R> | ApplyStaged.
  ApplyStaged ⇒ tx was passed; you must tx.commit() afterwards.
- ApplyVeto.instance is only auto-converted to ApplyRejected inside txApply.
  Plain apply returns ApplyAccepted(ApplyVeto.instance) — inspect the result.
- compensation: on a command is IGNORED unless tx is passed (txApply).
- For ValueCell value mutation, use handle.update/updateAsync — not apply.
- Cell.transaction (value buffering) ≠ Cell.txApply (command staging).
  apply only accepts ApplyTransactionScope (from txApply).
- Always await the outcome. Always exhaust the switch.
```

---

## 14. Cheat sheet

### Command

```dart
(
  function: someFn,
  arguments: (positionalArguments: [a, b], namedArguments: {#k: v}),
  compensation: (
    function: undoFn,
    arguments: (positionalArguments: [a, b], namedArguments: null),
    cell: maybeAnotherCell, // null = same cell
  ),
)
```

### Outcome table

| Outcome | Meaning | Action |
|---|---|---|
| `ApplyAccepted<R>` | Function returned `R` (possibly `ApplyVeto.instance`) | Use `result`, log `receipt.id` |
| `ApplyRejected<R>` | Gate refused, nothing executed | Inspect `reason`, retry or escalate |
| `ApplyStaged` | Enqueued in a transaction | Call `tx.commit()` |

### Path selection

| `modifiable.contains(fn)` | Gate runs? | `receipt.vetted` |
|---|---|---|
| `true` | `TestCell.action` | `true` |
| `false` | *(skipped)* | `false` |

### Transaction type compatibility

| Mechanism | Returned by | `apply(tx:)` accepts? |
|---|---|---|
| `TransactionScope` | `Cell.transaction()` | ✗ |
| `ApplyTransactionScope` | `Cell.txApply()` | ✓ |

### Compensation

| Context | Compensation fires? |
|---|---|
| Plain `apply` | Never |
| `txApply.commit()` (success) | Never |
| `txApply.commit()` (any failure) | Yes, reverse order, for executed commands only |
| `txApply.rollback()` | Yes, reverse order |
| `txApply.rollback(savepoint)` | Yes, for commands after savepoint |

---

## 15. See also

- **`Cell.transaction`** — atomic multi-`ValueCell` value updates with isolation levels.
- **`Cell.txApply`** — atomic command staging with compensation (the transaction model that `apply` uses).
- **`TestCell`** — the integrity gate that vetted `apply` calls route through.
- **`TestActionRule`** — the rule class used by `TestCell.action` for command gating.
- **`ApplyCommandDSL`** — the fluent builder.
- **`ApplyLedger`** — receipt minting.
- `guide/HowTo-Start.md` — getting started with cells.
- `guide/HowTo-Transaction.md` — deeper transaction walkthrough.
- `guide/HowTo-TestCell.md` — writing integrity gates.

---

*End of guide.*