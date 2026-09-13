# Architecture — card auth pipeline (Flow + Tissue)

**Companion to:** `card-auth-pipeline(tissue)-Demo.dart`
**Audience:** engineers extending the demo, teaching the seam, or porting the pattern to another industry.

---

## Contents

1. [One-paragraph summary](#1-one-paragraph-summary)
2. [Layering](#2-layering)
3. [Ownership matrix](#3-ownership-matrix)
4. [Locking](#4-locking)
5. [Failure semantics](#5-failure-semantics)
6. [Extending the demo](#6-extending-the-demo)
7. [Anti-patterns](#7-anti-patterns)
8. [Reading order for newcomers](#8-reading-order-for-newcomers)
9. [See also](#9-see-also)

---

## 1. One-paragraph summary

The demo wires two independent reactive subsystems together:

- **Flow** — the decision subsystem. Turns an `AuthAttempt` into a `Decision` (`none` / `approve` / `stepUp` / `decline`). Pure, synchronous, no I/O, no state mutation, no money writes.
- **Tissue** — the books subsystem. Records decisions, moves cents, tracks open holds, exports a read-only view for compliance. Every write is validated by a `TestTissue` and takes that collection's lock.

The two subsystems share exactly **one** communication channel: a `Cell.observe` attached to each gate cell (`declineCell`, `stepUpCell`, `ackIn.cell`). Nothing else crosses the seam. `riskOf` *reads* the `mccBlock` TissueSet (one-way, non-mutating); that read is the only other coupling and it is explicitly part of the policy input.

---

## 2. Layering

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  FLOW (decision)                                                │
│  ─────────────────                                              │
│  • Cells:  amountIn, mccIn, velocityIn, presentIn, attemptIn,   │
│            ackIn, declineCell, stepUpCell                       │
│  • Rules:  TestCell — shape only                                │
│  • State:  _lastDecline, _lastStepUp (Distinct latches)         │
│                                                                 │
│  Produces:  Decision  (none | approve | stepUp | decline)       │
│                                                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │  Cell.observe  (the only glue)
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                                                                 │
│  TISSUE (books)                                                 │
│  ─────────────                                                  │
│  • Collections:                                                 │
│      ledger    TissueList<LedgerEntry>                          │
│      available TissueValue<int>                                 │
│      held      TissueValue<int>                                 │
│      holdsMap  TissueMap<String, Hold>                          │
│      mccBlock  TissueSet<String>                                │
│      issuerQ   TissueQueue<IssuerJob>                           │
│  • Rules:  TestTissue — mutation validity                       │
│  • Deputy: ledger.unmodifiable (read-only, live)                │
│                                                                 │
│  Produces:  durable state + audit trail                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 What "the seam" means here

A **seam** is a boundary where two subsystems with different responsibilities, locks, and failure modes meet. In this demo the seam is one-directional for control (Flow → Tissue) and one-directional for policy input (Tissue → Flow via a read). The seam is not bidirectional for writes.

### 2.2 What the seam is **not**

- Not a shared mutable object.
- Not a callback registry.
- Not a shared lock.
- Not a shared enum-comparison pattern inside `riskOf` — the comparison reads the TissueSet, but does not mutate it.

The observer is a one-way delivery channel. If you ever find yourself wanting to write back from the observer to the decision pipeline, you have collapsed the seam and lost the lesson.

### 2.3 The four coupling points in this demo

There are exactly four places where the two subsystems touch:

| Coupling | Direction | Type | Notes |
|---|---|---|---|
| `declineCell` observer | Flow → Tissue | write-only | `ledger.add`, `issuerQ.addLast` |
| `stepUpCell` observer | Flow → Tissue | write-only | `ledger.add` |
| `ackIn.cell` observer | Flow → Tissue | write-only + latch reset | `resetDistinct`, `ledger.add(ACK)` |
| `riskOf` reads `mccBlock` | Tissue → Flow | read-only | one-way policy input |

The read of `mccBlock` is the only non-write coupling, and it is explicitly part of the policy input, not a control channel.

### 2.4 The money method is called by the caller, not the observer

A subtle point: the ACK observer does **not** call `placeHold`. The ACK observer only resets the latches and appends an `ACK` row. The **caller** — `main()` in the demo — then calls `placeHold` directly when the talk track says "approve after 3DS."

This is a deliberate design choice. It means:

- The ACK observer stays a pure latch reset + audit append. No money moves inside it.
- `placeHold` is a public method on the harness that can be called from any orchestration layer (a form handler, a 3DS callback, an operator console).
- The three money methods (`placeHold`, `capture`, `voidHold`) are the *only* methods that move cents. They are not observers; they are imperative APIs.

A real card network would wire the 3DS response to `placeHold` via a callback. The demo makes the wire explicit by putting the call directly in `main()`.

---

## 3. Ownership matrix

| Concern | Flow | Tissue |
|---|---|---|
| Parse amount / MCC | ✅ `TestCell` on ingress | — |
| Decide `none` / `approve` / `stepUp` / `decline` | ✅ `riskOf` + Distinct + Filter | — |
| Read `mccBlock` | ✅ (read-only, one-way) | ✅ (owns the set) |
| Write `ledger` | — | ✅ (append-only rule) |
| Write `available` / `held` | — | ✅ (non-negative rule) |
| Write `holdsMap` | — | ✅ (shape rule) |
| Write `issuerQ` | — | ✅ (bounded queue) |
| Enforce append-only log | — | ✅ `_ledgerAppendOnly` |
| Enforce non-negative cents | — | ✅ `_nonNegativeCents` |
| Enforce hold shape | — | ✅ `_holdRule` |
| Enforce MCC blocklist shape | — | ✅ `_mccBlockRule` |
| Export to compliance | — | ✅ `.unmodifiable` |
| React to `IssuerJob` | — (see §5.4 for the off-graph note) | ✅ (`issuerQ`) |
| Move cents | — | ✅ `placeHold` / `capture` / `voidHold` |
| Reset Distinct latches | ✅ `resetDistinct` | — |
| Rebuild graph | — | — (nobody does this after `install`) |

**Rule.** If a concern appears in both columns, it is a layering violation. The only intentional exception is that `riskOf` reads `mccBlock`: the read is one-way, non-mutating, and part of the policy input.

### 3.1 Which subsystem owns which lock

Every reactive node in this graph has its own lock. The demo deliberately keeps two disjoint lock domains (see §4). No operation in the demo holds both locks at the same time. That is a design choice, not a coincidence: it makes each subsystem independently testable.

### 3.2 Which subsystem owns which latch

Distinct latches are Flow state. They are not stored in any Tissue and they do not appear in the ledger. ACK resets them; nothing else does.

| Latch | Field | Set by | Reset by |
|---|---|---|---|
| DECLINE | `_lastDecline` | `_distinctDecline` on every attempt | `resetDistinct` (ACK) |
| STEP-UP | `_lastStepUp` | `_distinctStepUp` on every attempt | `resetDistinct` (ACK) |

The two latches are independent. A STEP-UP attempt sets the STEP-UP latch to `stepUp` but also sets the DECLINE latch to `stepUp` (because Distinct runs before Filter on both gates). See §5.2 for the consequence.

### 3.3 Which subsystem owns which money method

The three money methods are Tissue-only imperative APIs:

| Method | Writes | Reversible by |
|---|---|---|
| `placeHold` | `holdsMap[authId]`, `available`, `held`, `ledger` | `capture` (settles) or `voidHold` (releases) |
| `capture` | `holdsMap[authId]` (remove), `held`, `capturedCents`, `ledger` | — (terminal) |
| `voidHold` | `holdsMap[authId]` (remove), `held`, `available`, `ledger` | — (terminal) |

None of the three is called from an observer. All three are called by the harness's owner (the caller).

---

## 4. Locking

Two lock domains:

| Domain | Primitive | Held during |
|---|---|---|
| Decision | `Receptor` lock on `declineCell` / `stepUpCell` | `riskOf`, Distinct latch write, `Filter` |
| Books | Tissue lock on each collection | one `add` / `set` / `[key]=` |

A DECLINE pulse crosses the two domains **sequentially**, never simultaneously:

```
attemptIn.emit(a)
  ─► declineCell Receptor lock
       ─► riskOf
       ─► Distinct
       ─► Filter
  ─► unlock
  ─► observer
       ─► ledger.add             (TissueList lock)
       ─► issuerQ.addLast        (TissueQueue lock)
```

The ACK path is different: the ACK is not an attempt. It does not pass through `declineCell` or `stepUpCell`. It goes straight to the ACK observer, which calls `resetDistinct()` (Flow state, no lock needed — it's a plain field assignment) and appends an `ACK` row.

```
ackIn.emit('H-1')
  ─► ackIn.cell observer
       ─► resetDistinct()          (Flow state, no lock)
       ─► ledger.add(ACK)          (TissueList lock)
```

The `placeHold` path is also different: `placeHold` is called by the caller, not by an observer. It takes the Tissue locks in sequence:

```
h.placeHold('H-1', 60000, 'M-4419')
  ─► holdsMap['H-1'] = Hold(...)   (TissueMap lock released)
  ─► available.set(190000)         (TissueValue lock released)
  ─► held.set(60000)               (TissueValue lock released)
  ─► ledger.add(HOLD)              (TissueList lock released)
```

### 4.1 Consequences

- Because the domains are disjoint, `riskOf` cannot deadlock against `available.set`.
- Because they are sequential, `riskOf` cannot observe a half-written balance.
- Because each Tissue write takes its own lock, two observers on different gates (DECLINE and STEP-UP) do not contend on a shared Tissue lock unless they happen to target the same collection. Both gates write `ledger` on every fire, so they contend on the `TissueList` lock — but only briefly, one `add` at a time.
- The ACK path holds no Receptor lock; ACK is a direct imperative call, not a pulse.
- The money path holds no Receptor lock; `placeHold` is called directly by the harness owner.

### 4.2 Why the demo does not use a joint lock

A joint commit across `holdsMap` + `available` + `held` + `ledger` would require a single lock spanning all four. That is a legitimate pattern (see §6.4), but this build of `cell_tissue` does not expose it. The v1 protocol in `placeHold` compensates on failure instead, and the header documents the trade-off.

### 4.3 The `placeHold` compensation ladder

`placeHold` writes four things in order:

```
1. holdsMap[authId] = Hold(...)     (TissueMap lock released)
2. available.set(before - cents)    (TissueValue lock)
3. held.set(heldBefore + cents)     (TissueValue lock)
4. ledger.add(LedgerEntry(kind: 'HOLD', ...))  (TissueList lock)
```

If step 2 rejects (the non-negative rule fires), step 1 is compensated by `holdsMap.remove(authId)`. The method returns `false` without leaving a partial state. Steps 3 and 4 are never reached.

If step 3 rejects, steps 1 and 2 are compensated: `available.set(before)` restores the balance, `holdsMap.remove` removes the map row. Step 4 is never reached.

If step 4 were to reject (it cannot — `_ledgerAppendOnly` accepts all `add` calls), the demo does not currently compensate steps 1–3. That is a known limitation of the v1 protocol; §6.4 discusses the joint-commit alternative.

`capture` and `voidHold` have simpler ladders because fewer writes can reject:

- **`capture`**: remove map row, set `held`, add `capturedCents`, append `CAPTURE`. Only `held.set` can reject, and it can only reject if the subtraction goes negative — which is impossible given the invariant. So `capture` has no compensation ladder.
- **`voidHold`**: remove map row, set `held`, set `available`, append `VOID`. Neither `held.set` nor `available.set` can reject given the invariant. So `voidHold` has no compensation ladder.

### 4.4 Why the compensation ladder matters

In a real acquirer, the three money writes must be atomic. If `holdsMap` is written but `available` is not, the books are inconsistent: a hold exists in the map but the cents are still in `available`. The next `placeHold` could double-count those cents.

The v1 ladder prevents that by explicitly undoing the map row if the balance write fails. A joint-commit transaction (§6.4) would replace the ladder with a single atomic operation.

---

## 5. Failure semantics

### 5.1 Shape failure (TestCell)

A bad amount / MCC dies at ingress. `setAmount` / `setMcc` return `false` and do **not** update the cache. `publishAttempt` is not called. No Tissue is touched. The rejected value never appears in `ledger`, `available`, `held`, `holdsMap`, or `issuerQ`.

**Why at the sensor, not inside the policy.** A shape error is a terminal / gateway problem, not a policy problem. Folding it into `riskOf` would make the policy conditional on transport quality and would let a malformed reading produce a decision.

### 5.2 Policy approve (riskOf)

`riskOf` returning `approve` — the attempt passes all risk checks — produces a `Decision` the gates' `Filter` drops. The **Distinct latch still updates** to `approve`.

**Why Distinct still updates.** This is what makes `decline → approve → decline` fire twice. If the latch ignored `approve`, the second `decline` would be suppressed because the latch would still hold `decline` from the first attempt. See `installGates`'s doc for the full rationale.

**The cross-gate latch write.** Distinct runs before Filter on *both* gates. This means a STEP-UP attempt sets the DECLINE latch to `stepUp` (because the DECLINE Distinct sees `stepUp` as the current decision), and the DECLINE Filter then drops the pulse. On the next `decline` attempt, the DECLINE latch transitions `stepUp → decline` and the DECLINE Filter passes.

The rule in one sentence: **Distinct records every decision the pipeline made, regardless of which gate the decision belongs to.**

### 5.3 Book rejection (TestTissue)

`placeHold` pre-checks `available`. If the pre-check fails, no map row is written. If the pre-check passes but `available.set` rejects (belt-and-braces), the map row is compensated. If `held.set` rejects, both `available` and `holdsMap` are compensated.

**Invariant.** After a successful call, `available.value! + held.value! + capturedCents == 250000`.

### 5.4 Issuer retry

`_driveIssuer` catches the first failure and retries once. The retry is counted in `issuerAttempts`. A second failure is swallowed — the demo does not model dead-letter handling.

**Off-graph note.** The walkthrough specifies `AsyncMapWithRetry` with `count: 2`. This build's `TissueQueue` does not expose a Stream adapter and its `removeFirst` / `remove` do not drain. The demo therefore keeps `issuerQ` as the **audit-side enqueue** and uses a plain Dart `_issuerWork` list for the pump. The header documents this.

**Why the audit-side enqueue still matters.** Every `addLast` on `issuerQ` emits an `ElementAdded<IssuerJob>` on the Tissue. A downstream observer could subscribe to that queue and reconstruct exactly which issuer messages were attempted, when, and for which authorization. The queue is the durable record of the issuer channel's activity, even though the actual pump runs on a plain list.

**Where a real system would go next.** A production acquirer would replace `_issuerWork` with a proper outbound queue that persists across restarts, with backoff, dead-letter handling, and terminal-failure alerting. The demo stops at the retry-once boundary because the lesson is the seam, not the retry ladder.

### 5.5 NSF rejection (scenario 11)

Scenario 11 attempts `placeHold('H-2', 200000, 'M-4419')` while `available` is only 190000. The pre-check rejects it before any write. The invariant is preserved throughout — this is the pure demonstration of the non-negative `TestTissue` guard.

**Production note.** A real NSF attempt would be logged (as a `HOLD-REJECTED` or similar ledger row) to satisfy regulatory requirements. The demo does not do this because the demo's scenario table does not list such a row. In a real system, the `placeHold` method would append a rejection row before returning `false`.

### 5.6 Missing hold

`capture('UNKNOWN')` returns `false` and touches nothing. `voidHold('UNKNOWN')` returns `false` and touches nothing. Neither is an error.

**Why this is safe.** A missing hold means either (a) the hold was never opened, or (b) the hold was already captured or voided. Both are legitimate states; the method's job is to be idempotent on the "already done" side. The demo does not track which of the two cases applies.

### 5.7 Cascade failure

If `_driveIssuer` fails twice, the issuer job is dropped silently. The ledger records nothing about the second failure (it records the retry attempt, but not the terminal failure). A production system would emit an `ISSUER_FAILED` entry with the retry count.

### 5.8 ACK miss

An ACK with no matching pending state is not an error. It clears the latches and appends an `ACK` row. The caller may then call `placeHold` — but if the ACK is spurious (no 3DS challenge was actually pending), the hold is still legitimate: an operator has decided to approve the attempt.

**Why this is intentional.** The ACK is not a permission slip; it is a signal. It says "an analyst looked at this; proceed." The framework does not verify that a 3DS challenge was actually outstanding, because in a real system the analyst console and the framework are the same authority.

---

## 6. Extending the demo

### 6.1 Adding a third decision (e.g. `review`)

1. Add `Decision.review` to the enum.
2. Add the clause to `riskOf`.
3. Add a third gate: `MapValue + _distinctReview + Filter(review)`.
4. Add a third observer in `install`.
5. Add the corresponding `TestTissue` and any new collection.
6. Extend the trailer.

The pattern is mechanical: one enum value, one clause, one gate, one observer, one rule, one counter.

### 6.2 Multi-currency routing

Currently `AuthAttempt.amountCents` is implicitly in USD (or the demo's base currency). To support ISO-4217 routing:

1. Add a `currency` field to `AuthAttempt`.
2. Add a `TestCell` on the new `currencyIn` that rejects anything not matching the ISO-4217 pattern (`^[A-Z]{3}$`).
3. Add a `TissueMap<String, int>` for the FX table, keyed on currency code.
4. Convert in `riskOf` before the risk checks, or split into a second gate that emits a `convertedAmount`.

### 6.3 Persistent ledger

Replace `TissueList<LedgerEntry>` with a custom `Tissue` subtype that writes each `ElementAdded` to a database. The `TestTissue` and the observer code do not change; only the storage strategy changes.

**What this buys.** The compliance deputy's `ledger.unmodifiable` view still works — the view reads from the new storage strategy. The `_ledgerAppendOnly` rule still fires on every `add`. The observers still call `ledger.add(...)`. The only code that changes is the storage layer underneath the `TissueList`.

**What this costs.** A persistent store introduces I/O latency. The `placeHold` ladder would need to await the write, or accept that the ledger entry lands asynchronously. The v1 protocol currently assumes synchronous Tissue writes.

### 6.4 `Cell.transaction` across the money writes

When the running `cell_tissue` build exposes a joint commit across `TissueValue` + `TissueMap` + `TissueList`, replace the v1 try/compensate in `placeHold` / `capture` / `voidHold` with a single `Cell.transaction` block. Until then, stay on v1.

**The joint-commit shape.** A hypothetical joint commit would look like:

```dart
await Cell.transaction((tx) async {
  tx.update(holdsMap, {'H-1': Hold(...)});
  tx.update(available, 190000);
  tx.update(held, 60000);
  tx.update(ledger, LedgerEntry(kind: 'HOLD', ...));
  await tx.commit();
});
```

If any of the four writes reject, the whole transaction rolls back. This eliminates the need for `placeHold`'s try/compensate ladder.

### 6.5 Adding a debounce in front of `attemptIn`

A 10–15 second "finger on glass" window is a `Debounce` in front of `attemptIn`:

```dart
final debounced = Flow.debounce<AuthAttempt>(
  attemptIn.cell,
  duration: Duration(seconds: 12),
);
```

Wire the gates to `debounced.cell` instead of `attemptIn.cell`. The seam does not move; only the input cadence changes.

**What this changes.** The Distinct latch now sees one attempt per debounce window instead of one attempt per publish. If a merchant sends five identical attempts in three seconds, only the last reaches the gates. This is the desired behaviour for a real acquirer.

### 6.6 Settlement batch

A nightly settlement run can drain `issuerQ` on a timer:

```dart
Flow.interval(tick.cell, period: Duration(hours: 24))
  .flatMap((_) => Flow.fromIterable(issuerQ.toList()))
  // … map each job to a settlement call
```

The tissue queue stays the audit record; the batch is the process that reads from it. The `AsyncMapWithRetry` pattern that was specified for the issuer pump would be the natural fit for the settlement call itself.

### 6.7 Scheme STIP / partial auth

A stand-in processing (STIP) path requires the framework to handle the case where the issuer is unreachable. That would be:

1. A third decision `Decision.stip`.
2. A `TestTissue` on `issuerQ` that allows STIP-bound jobs to outlive the pump.
3. A `TissueValue<int>` tracking the number of STIP-bound authorizations.
4. A second observer that reads from `issuerQ` and re-routes STIP jobs to a different pump.

The pattern is the same: `MapValue + Distinct + Filter` per product, one observer per gate, one `TestTissue` per collection.

### 6.8 Multi-currency routing with FX

A multi-currency version would split `amountCents` into `(amountMinor, currency)`. The risk checks would need a converted amount in the base currency. That means either:

1. A `TissueMap<String, int>` of FX rates, read by `riskOf`.
2. A second gate that reads the FX table and emits `Decision.converted`.

Option 1 keeps the pipeline linear; option 2 introduces a parallel branch. The choice depends on whether FX conversion is a policy input (option 1) or a policy output (option 2).

### 6.9 Migration to a new industry

The pattern is domain-agnostic. To reuse it for, say, mobility:

1. Rename the domain types (`AuthAttempt` → `MatchTick`, `Hold` → `Assignment`, etc.).
2. Rewrite `riskOf` for the new policy.
3. Keep the seam: `MapValue → Distinct → Filter` per product, one observer per gate, one `TestTissue` per collection.
4. Keep the two-lock discipline.

The `grid-demand-response(tissue)-Demo.dart` and `ride-hail-dispatch(tissue)-Demo.dart` files are worked examples of the same pattern in different domains.

---

## 7. Anti-patterns

| Anti-pattern | Why it breaks the lesson |
|---|---|
| `ledger.add(...)` inside a `MapValue` | Folds Flow into the log; destroys the two-lock discipline. |
| `available.set(...)` inside `riskOf` | Folds Tissue into the decision; makes the policy untestable. |
| Replacing Distinct with "ledger has this auth id" | The log is history; Distinct is the *current* alarm latch. ACK clears the latch, never the log. |
| `toHandle` called from the ACK observer | Doubles every downstream effect on the next attempt. |
| Passing `TestCell.allowAll` to a Tissue constructor | Type error at best; silent looseness at worst. |
| Wrapping a `TestCell` in `TestTissue` to "compose" | They are not subtypes; compose with `+` on the correct side. |
| Using a Dart `List<LedgerEntry>` as the source of truth | The books are the `TissueList`; a local list is only for formatting. |
| Batching issuer jobs without a `TestTissue` | The queue would accept malformed jobs; the rule is the shape gate. |
| Holding the Receptor lock across a Tissue write | Violates the two-lock discipline; makes the two subsystems indivisible. |
| Using `mccBlock` as a shared mutable global | `riskOf` must read it, not own it; ownership stays with the Tissue. |
| Adding a second `toHandle` for the same gate on every ACK | Classic "stacked graph" bug; ACK must only call `resetDistinct`. |
| Trying to make `riskOf` async so it can await a Tissue read | `riskOf` must stay synchronous; async reads belong at ingress. |
| Encoding the DECLINE/STEP-UP distinction in a single boolean | Two products need two gates; a boolean cannot express the 3DS challenge. |
| Moving the Distinct latch into a Tissue | Distinct is Flow state, not book state. ACK resets it; the ledger does not. |
| Reading `ledger` from inside the DECLINE observer to "check duplicates" | Duplicates are Distinct's job, not the log's. Reading the log adds lock contention and couples the observer to the log's storage strategy. |
| Emitting a `Decision` directly from `riskOf` | `riskOf` returns a value; the gate emits the pulse. Separating the two is what makes `riskOf` unit-testable. |
| Bundling `placeHold` into the DECLINE observer | The DECLINE observer must not touch `available` or `held`. Money moves on ACK, not on decision. |
| Decrementing `available` inside `riskOf` | `riskOf` is pure. The balance is Tissue state. |
| Writing `available` inside the ACK observer | ACK clears the latches. The caller decides whether to move money. |
| Calling `placeHold` from the STEP-UP observer | STEP-UP is a decision, not a debit. The caller calls `placeHold` after the 3DS callback. |
| Bypassing `placeHold` to write `available` / `held` directly | The three money methods are the only writers of the money tables. Any other path breaks the invariant. |
| Ignoring the compensation ladder in `placeHold` | A partial write leaves an orphan hold or a lost balance. The ladder prevents both. |
| Hard-coding the base currency in `riskOf` | Currency is policy input; it belongs in the `AuthAttempt` or a `TissueMap`. |

---

## 8. Reading order for newcomers

1. **This file** — the architecture in five minutes.
2. **`card-auth-pipeline(tissue)-Demo.dart`** — skim the class doc, then read `riskOf`, `installGates`, `placeHold`.
3. **`card-auth-pipeline(tissue)-WalkThrough.md`** — the requirement and the scenario contract.
4. **`card-auth-pipeline(tissue)-FEATURES.md`** — the operator catalogue.

For a second domain, read `grid-demand-response(tissue)-Demo.dart` or `ride-hail-dispatch(tissue)-Demo.dart` in the same order. The seam is identical; only the policy, the domain types, and the `TestTissue` rules differ.

---

## 9. See also

| File | Purpose |
|---|---|
| `card-auth-pipeline(tissue)-Demo.dart` | Executable implementation. |
| `card-auth-pipeline(tissue)-WalkThrough.md` | Requirement document and scenario contract. |
| `card-auth-pipeline(tissue)-FEATURES.md` | Operator catalogue and feature index. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling — same graph shape, different domain. |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |