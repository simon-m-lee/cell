# HowTo-Tissue.md

**Working with Reactive Collections in `cell_tissue`**
*A guide for human developers and AI prompt agents*

---

## Abstract

`cell_tissue` provides reactive collections for the Mitosis framework — `TissueList`, `TissueSet`, `TissueMap`, `TissueQueue`, and `TissueValue`. Each collection behaves like its standard Dart counterpart (`List`, `Set`, `Map`, `Queue`) but every mutation is validated by an integrity gate, emitted as a signal, and synchronised through a thread-safe lock. Collections can be deputized into read-only views, validated by custom rules, and orchestrated atomically with `Cell.txApply`.

This guide is written in two registers simultaneously:

- **For human developers:** prose sections explain the "why" behind each abstraction, with worked examples that build up from a trivial case.
- **For AI prompt agents:** each concept is stated as a numbered, executable instruction set with machine-checkable success criteria (✅), failure modes (⚠️), and canonical code patterns (📋).

By the end, you will be able to build validated reactive collections, share them safely through deputies and unmodifiable views, and coordinate atomic multi-collection mutations with `Cell.txApply`.

---

## How to Use This Guide

**If you are a human developer**, read sequentially. Each section builds on the previous. The code samples are runnable; you can paste them into a Dart file and execute them.

**If you are an AI prompt agent**, treat this document as a procedural specification:

- Each `##` section is an atomic task.
- Numbered lists within a section are **ordered steps**; do not skip them.
- Code blocks marked 📋 are **canonical templates**; adapt names and types but preserve structure.
- Bullets marked ✅ are **post-conditions**; verify them before proceeding.
- Bullets marked ⚠️ are **failure modes**; if any applies, stop and report.
- Bullets marked 🔁 are **loop invariants**; check them on every iteration.
- Bullets marked ❌ are **prohibitions**; never do these.

When generating code for a user, prefer the simplest construction that satisfies the requirements. When in doubt, follow the canonical template exactly.

---

## Table of Contents

1. [Mental Model](#1-mental-model)
2. [Installation and Imports](#2-installation-and-imports)
3. [Your First Tissue: `TissueList`](#3-your-first-tissue-tissuelist)
4. [Validating Mutations with `TestTissue`](#4-validating-mutations-with-testtissue)
5. [The Five Tissue Types](#5-the-five-tissue-types)
6. [Deputies and Unmodifiable Views](#6-deputies-and-unmodifiable-views)
7. [Observing Tissue Mutations](#7-observing-tissue-mutations)
8. [Async Mutations](#8-async-mutations)
9. [Serialisation and Re-hydration](#9-serialisation-and-re-hydration)
10. **Integrating `Cell.txApply` with Multiple Tissue Cells**
11. [Common Patterns](#11-common-patterns)
12. [Troubleshooting](#12-troubleshooting)
13. [References](#13-references)

---

## 1. Mental Model

A **Tissue** is a reactive collection. It is simultaneously:

- A **standard Dart collection** — you can call `add`, `remove`, iterate, and use `map` / `where` / `fold` as usual.
- A **governed reactive node** — every mutation passes through an integrity gate (`TestTissue`) and, if accepted, emits a `TissuePulse` to observers.
- A **thread-safe container** — mutations are serialised through an internal `Lock`.
- A **projection source** — you can produce deputies (restricted views) and unmodifiable views (read-only) that share the same storage.

Every Tissue has three parts:

| Part | Role |
|---|---|
| **Container** | The physical storage — a `List`, `Set`, `Map`, `Queue`, or single-value cell |
| **Nucleus** | The immutable blueprint — receptor, test rule, context, synapses |
| **Synapses** | The distribution network — who gets notified on mutation |

✅ **Post-condition (for AI agents):** After reading this section, you should be able to state, for any Tissue operation, which of the three parts is responsible for it. If you cannot, re-read the table.

---

## 2. Installation and Imports

### 2.1 Install

Add the packages to your `pubspec.yaml`:

```yaml
dependencies:
  cell: ^1.0.0-rc.8
  cell_tissue: ^1.0.0-rc.9
```

### 2.2 Import

```dart
import 'package:cell_tissue/cell_tissue.dart';
```

This single import re-exports `package:cell` as well, so you have access to `Cell`, `Pulse`, `TestCell`, `Context`, and so on without a second import.

✅ **Post-condition:** `import 'package:cell_tissue/cell_tissue.dart';` compiles without errors.

⚠️ **Failure mode:** If you see `Undefined class 'Cell'` after this import, you have a version mismatch between `cell` and `cell_tissue`. Both must be on the same version line.

❌ **Prohibition:** Do not import `package:cell/cell.dart` alongside `package:cell_tissue/cell_tissue.dart` — you will get duplicate-symbol errors.

---

## 3. Your First Tissue: `TissueList`

### 3.1 Create a List

📋 **Canonical template:**

```dart
import 'package:cell_tissue/cell_tissue.dart';

final scores = TissueList<int>();
```

Or, with initial elements:

```dart
final scores = TissueList<int>([10, 20, 30]);
```

**For human readers:** `TissueList` is a drop-in replacement for Dart's `List`. You can use it anywhere a `List` is expected (it implements `List<int>`), and every method works the way you expect.

### 3.2 Mutate the List

📋 **Canonical template:**

```dart
scores.add(40);
scores.addAll([50, 60]);
scores.remove(20);
scores.removeAt(0);
scores.clear();
```

**For AI agents:**

1. Call the mutation method directly on the `TissueList` instance.
2. Do not wrap the call in a `Future` — synchronous mutations return `void`, `bool`, or the removed element, exactly as Dart's `List` does.
3. If you need an awaitable mutation, use `scores.async.add(...)` (see [Section 8](#8-async-mutations)).

✅ **Post-condition:** After `scores.add(40)`, `scores.contains(40)` returns `true`.

⚠️ **Failure mode:** If the list is unmodifiable, `add` throws `UnsupportedError`. Check `scores is Unmodifiable` if you are unsure.

### 3.3 Iterate the List

Because `TissueList` implements `Iterable<int>`, all standard iteration works:

```dart
for (final score in scores) {
  print(score);
}

final doubled = scores.map((s) => s * 2).toList();
final passing = scores.where((s) => s >= 50).toList();
```

**For AI agents:** Prefer `map` / `where` / `fold` over manual index-based iteration. The `TissueList` is designed to work with Dart's collection pipeline.

---

## 4. Validating Mutations with `TestTissue`

### 4.1 What a Test Rule Does

A `TestTissue` is an **integrity gate**. Every mutation passes through it. If the rule returns `false`, the mutation is rejected, the state is unchanged, and no signal is emitted.

**For human readers:** Think of `TestTissue` as a business rule that runs automatically on every mutation. You do not call it; the framework does. You only declare what is allowed.

### 4.2 Declaring a Test Rule

📋 **Canonical template:**

```dart
final scores = TissueList<int>(
  testRule: TestTissue<int, TissueList<int>>(
    (value, {host, action, user}) {
      // Allow only non-negative integers
      return value is int && value >= 0;
    },
  ),
);
```

**For AI agents:**

1. `TestTissue<E, C>` is parameterised by element type `E` and the concrete Tissue type `C`.
2. The rule function receives: `value` (the element or action being validated), `host` (the tissue instance), `action` (the operation, e.g., `add`), and `user` (optional metadata).
3. Return `true` to allow, `false` to reject.
4. The rule can be synchronous (`bool`) or asynchronous (`Future<bool>`).

✅ **Post-condition:** After declaring the above rule, `scores.add(5)` succeeds and `scores.add(-1)` is a silent no-op.

⚠️ **Failure mode:** If the rule throws an exception, the mutation is rejected (the framework catches and logs).

### 4.3 Composing Rules

Two rules compose additively with `+`:

```dart
final isPositive = TestTissue<int, TissueList<int>>(
  (value, {host, action, user}) => value is int && value > 0,
);

final isEven = TestTissue<int, TissueList<int>>(
  (value, {host, action, user}) => value is int && value.isEven,
);

final positiveEven = isPositive + isEven;
```

**For AI agents:**

1. Use `+` to compose rules; the result is a new `TestTissue`.
2. The composed rule accepts a value only if **both** operands accept it (logical AND).
3. Composition is left-associative: `a + b + c` means `(a + b) + c`.
4. Composition is additive in the sense of *narrowing*: the composed rule can only be stricter than its parts, never more permissive.

✅ **Post-condition:** `positiveEven.call(4, host: scores)` returns `true`; `positiveEven.call(-4, host: scores)` returns `false`; `positiveEven.call(3, host: scores)` returns `false`.

### 4.4 The Read-Only Rule

The framework provides a prebuilt read-only rule:

```dart
final source = TissueList<int>([1, 2, 3]);
final readOnly = source.deputy(testRule: TestTissue.readOnly);
```

`TestTissue.readOnly` rejects every mutating operation routed through it. Use it whenever you want to expose a Tissue as read-only without copying it.

### 4.5 Async Validation

Rules can be asynchronous:

```dart
final remoteValidated = TestTissue<String, TissueList<String>>(
  (value, {host, action, user}) async {
    return await someRemoteCheck(value as String);
  },
);
```

**For AI agents:**

1. When a rule returns a `Future<bool>`, the mutation suspends until the future resolves.
2. The Tissue's lock is **held** during the suspension. Keep async rules short.
3. If the future resolves to `false`, the mutation is rejected atomically.

⚠️ **Failure mode:** Long-running async rules can cause lock contention. If you need to validate asynchronously, consider validating outside the Tissue and passing an already-validated value.

---

## 5. The Five Tissue Types

### 5.1 `TissueList<E>` — Ordered, Indexable

A reactive `List<E>`. Use it when you need ordered, duplicate-allowing storage with index access.

📋 **Canonical template:**

```dart
final scores = TissueList<int>([10, 20, 30]);

scores.add(40);
scores[0] = 15;            // setValueAt
final first = scores[0];   // operator []
final removed = scores.removeAt(1);
```

**For AI agents:**

- Prefer `TissueList` for sequences where order matters.
- `operator []=` is routed through the validation pipeline (it is not a direct write).
- `setValueAt(index, value)` is the named-method equivalent of `operator []=`.
- Fixed-length lists can be created via `Container.growableFalse` (advanced; see `HowTo-Tissue-Advanced.md`).

### 5.2 `TissueSet<E>` — Unique, Unordered

A reactive `Set<E>`. Use it when uniqueness matters and order does not.

📋 **Canonical template:**

```dart
final tags = TissueSet<String>({'dart', 'flutter'});

tags.add('reactive');
tags.add('reactive');       // no-op — already present
final has = tags.contains('dart');
tags.remove('flutter');
```

**For AI agents:**

- Prefer `TissueSet` when membership semantics are important.
- Uniqueness is value-based by default. For identity-based sets, use `Container.identitySet` at construction.

### 5.3 `TissueMap<K, V>` — Key-Value

A reactive `Map<K, V>`. Use it for associative data.

📋 **Canonical template:**

```dart
final scores = TissueMap<String, int>({
  'alice': 10,
  'bob': 20,
});

scores['carol'] = 30;         // operator []=
final aliceScore = scores['alice'];
scores.remove('bob');
```

**For AI agents:**

- Validation applies to **values**, not keys. Keys are structural indices.
- `putIfAbsent`, `update`, `updateAll` are all available and all validated.

### 5.4 `TissueQueue<E>` — FIFO / Double-Ended

A reactive `Queue<E>`. Use it for buffers, pipelines, and event streams.

📋 **Canonical template:**

```dart
final queue = TissueQueue<int>(capacity: 10);

queue.addLast(1);
queue.addLast(2);
queue.addFirst(0);

final first = queue.removeFirst(); // 0
final last = queue.removeLast();   // 2
```

**For AI agents:**

- Provide a `capacity` for bounded queues. When full, `add` drops the oldest element (circular buffer semantics).
- Omit `capacity` for unbounded queues.

⚠️ **Failure mode:** Calling `removeFirst` on an empty queue throws `StateError`. Check `queue.isNotEmpty` first.

### 5.5 `TissueValue<V>` — Reactive Scalar

A reactive single value. Use it when you need a single observable scalar.

📋 **Canonical template:**

```dart
final counter = TissueValue<int>(0);

counter.value = 1;
counter.set(2);
final current = counter.value;
```

**For AI agents:**

- `TissueValue` is the base type for `Field` in `cell_organ`.
- `set(value)` returns `bool` indicating whether the mutation was accepted.
- Setting the same value is a no-op (no pulse emitted).

---

## 6. Deputies and Unmodifiable Views

### 6.1 Unmodifiable View

An unmodifiable view is a **live, read-only projection** of the source:

```dart
final source = TissueList<int>([1, 2, 3]);
final readOnly = source.unmodifiable;

print(readOnly.length);        // 3
// readOnly.add(4);            // throws UnsupportedError

source.add(4);
print(readOnly.length);        // 4 — reflects the source's change
```

**For AI agents:**

1. `.unmodifiable` returns a view; it does **not** copy the source.
2. The view is **live**: changes to the source are visible immediately.
3. Mutations through the view are rejected.
4. `source == source.unmodifiable` is `true`.

✅ **Post-condition:** After `source.add(4)`, `readOnly.length` reflects the new length.

❌ **Prohibition:** Do not use `.unmodifiable` when you need a snapshot. Use `.toList()` or `.toSet()` to obtain a fresh copy.

### 6.2 Deputy

A deputy is a restricted view with its own governance:

```dart
final source = TissueList<int>([1, 2, 3]);
final uiDeputy = await source.deputy(
  testRule: TestTissue.readOnly,
  context: DeputyContext.system,
);
```

**For AI agents:**

1. `.deputy()` returns a `FutureOr<Tissue<E>>`; `await` it.
2. The deputy shares the source's storage and lock.
3. The deputy's `testRule` is layered on top of the source's rule (additive narrowing).
4. The deputy can have its own context, ephemeral policy, and synapses.
5. If all parameters are default, `.deputy()` returns the source itself (no-op optimisation).

✅ **Post-condition:** `deputy == source` returns `true` (they are logically equivalent identities).

### 6.3 Choosing Between Unmodifiable and Deputy

| Need | Use |
|---|---|
| Simple read-only sharing | `.unmodifiable` |
| Read-only + custom context | `.deputy(testRule: TestTissue.readOnly, context: ...)` |
| Custom validation, still mutable | `.deputy(testRule: myCustomRule)` |
| Temporary access with TTL | `.deputy(ephemeralPolicy: ...)` |

---

## 7. Observing Tissue Mutations

Every mutation emits a `TissuePulse`. Observe with `Cell.observe`:

📋 **Canonical template:**

```dart
final source = TissueList<int>([1, 2, 3]);

final observer = Cell.observe(
  source: source,
  effect: (pulse) {
    if (pulse.type == Tissue.elementAdded) {
      print('Added: ${pulse.payload}');
    } else if (pulse.type == Tissue.elementRemoved) {
      print('Removed: ${pulse.payload}');
    }
  },
);

source.add(4);      // prints: Added: 4
source.remove(1);   // prints: Removed: 1

observer.stop();
```

**For AI agents:**

1. Use `Cell.observe` to attach an observer.
2. The effect receives a `TissuePulse` with a `type` field that is a `TissueEvent`.
3. Common event types: `Tissue.elementAdded`, `Tissue.elementRemoved`, `Tissue.elementUpdated`, `Tissue.entryUpdated`.
4. Always `observer.stop()` when done — observers hold references and prevent garbage collection.
5. The observer's `effect` runs synchronously on the mutation caller's thread.

✅ **Post-condition:** After `source.add(4)`, the observer's effect has been invoked exactly once with a pulse whose payload is `4`.

⚠️ **Failure mode:** If `observer.stop()` is not called, the observer remains registered and its effect continues to fire.

### 7.1 Filtering Events

Filter inside the effect for clarity:

```dart
final observer = Cell.observe(
  source: source,
  effect: (pulse) {
    if (pulse.type == Tissue.elementAdded && pulse.payload is int && (pulse.payload as int) > 100) {
      handleLargeAddition(pulse.payload as int);
    }
  },
);
```

**For AI agents:**

1. Filtering inside the effect is preferred over pre-filtering with `Cell.valve` unless you are sure the valve's semantics match.
2. For richer filtering, compose `Cell.observe` with `Cell.derive` (from `cell` package).

---

## 8. Async Mutations

Every Tissue provides an `.async` facade:

```dart
final scores = TissueList<int>();

await scores.async.add(40);
await scores.async.addAll([50, 60]);
await scores.async.remove(20);
```

**For AI agents:**

1. `scores.async` returns a `ModifiableListAsync<int>` (or the corresponding async facade for the tissue type).
2. Every method returns a `Future`.
3. The mutation is serialised through the tissue's lock.
4. The `Future` resolves after the mutation has been committed and propagated.

### 8.1 When to Use Async

- You are in an `async` context (network callback, background task).
- You want to ensure the mutation is fully committed before proceeding.
- You want to chain multiple mutations in a specific order.

### 8.2 When NOT to Use Async

- You are in a synchronous context (UI event handler that does not await).
- You do not care about ordering or completion.
- You are inside a `Tissue.apply` call (which is already serialised).

⚠️ **Failure mode:** Calling `scores.async.add(...)` without `await` may result in the mutation being applied asynchronously — the caller's subsequent code may observe an inconsistent state.

---

## 9. Serialisation and Re-hydration

Tissues can be serialised to standard Dart collections, then re-hydrated:

```dart
// Serialise
final snapshot = scores.toList();

// Re-hydrate
final restored = TissueList<int>(snapshot);
```

**For AI agents:**

1. Tissues do **not** have a `toJson` / `fromJson` pair by default. They serialise as their underlying collection type.
2. To persist a Tissue, serialise the underlying collection, then reconstruct the Tissue with the same nucleus configuration.
3. If you need policy-preserving serialisation, construct the Tissue with the same `testRule` and `context`.

---

## 10. Integrating `Cell.txApply` with Multiple Tissue Cells

This is the most architecturally significant section of this guide. It explains how to coordinate atomic mutations across multiple Tissues using `Cell.txApply`.

### 10.1 The Problem: Multi-Tissue Atomicity

Consider a bank transfer:

- Debit `$100` from `aliceBalance`.
- Credit `$100` to `bobBalance`.

If the debit succeeds and the credit fails, the system is inconsistent. If the credit succeeds and the debit fails, the money is created from nothing. You need a way to commit both changes atomically, or neither.

`Cell.txApply` provides exactly that: a **staged application scope** that buffers mutations across multiple cells and commits them as a single atomic unit — or rolls them back via compensations if any step fails.

### 10.2 The `txApply` Contract

📋 **Canonical template:**

```dart
final result = Cell.txApply(
  TxApplyOptions(
    context: Context.system,          // operational authority
    policy: TxApplyPolicy.rollback,   // behaviour on failure
    wait: true,                       // await full propagation before returning
  ),
);
```

**For AI agents:**

1. `Cell.txApply()` returns a `TxApplyScope` (a record-like handle).
2. Inside the scope, use `tx.apply(...)` to stage mutations.
3. Each staged mutation can carry a **compensation** — a reversal function.
4. Call `tx.commit()` to apply all staged mutations atomically.
5. Or call `tx.rollback()` to discard all staged mutations (compensations run in reverse order).
6. If `wait: true`, `commit()` and `rollback()` return `Future`s that resolve after full propagation.

✅ **Post-condition:** After `tx.commit()`, all staged mutations have been applied and all observers have been notified exactly once per stage, in order.

⚠️ **Failure mode:** If a staged mutation fails during commit (e.g., rejected by its tissue's test rule), the framework invokes all registered compensations in reverse order, restoring the state to its pre-transaction value.

❌ **Prohibition:** Do not call `tx.apply(...)` outside a `Cell.txApply` scope. The `tx` parameter on `Cell.apply` requires a scope from `Cell.txApply()`.

### 10.3 A Basic Atomic Transfer

Here is the canonical example — a transfer between two `TissueValue<int>` cells:

```dart
import 'package:cell_tissue/cell_tissue.dart';

Future<void> transfer(
  TissueValue<int> from,
  TissueValue<int> to,
  int amount,
) async {
  final tx = Cell.txApply();

  try {
    // Read both balances inside the transaction
    final fromBalance = from.value ?? 0;
    final toBalance = to.value ?? 0;

    // Stage the debit
    tx.apply(
      from,
      () => from.value = fromBalance - amount,
      compensate: () => from.value = fromBalance,
    );

    // Stage the credit
    tx.apply(
      to,
      () => to.value = toBalance + amount,
      compensate: () => to.value = toBalance,
    );

    // Commit atomically
    await tx.commit();
    print('Transfer successful');
  } catch (e) {
    // Rollback runs compensations in reverse order
    await tx.rollback();
    print('Transfer failed: $e');
  }
}
```

**For AI agents — canonical structure:**

1. **Create scope:** `final tx = Cell.txApply();`
2. **Read state:** Read all relevant cells **inside** the transaction, not before. This ensures consistent reads.
3. **Stage each mutation:** Call `tx.apply(cell, mutation, compensate: reversal)` for each cell.
4. **Provide compensation:** Every staged mutation **must** have a `compensate` function that reverses its effect.
5. **Commit:** `await tx.commit();` — the framework acquires locks, validates, applies, and propagates.
6. **Rollback on failure:** `await tx.rollback();` — the framework runs compensations in reverse order.

✅ **Post-condition:** Either both `from` and `to` reflect the transfer, or neither does.

⚠️ **Failure mode:** If you forget to provide a `compensate`, the framework cannot roll back that stage. The transaction may become partially applied.

### 10.4 Multi-Tissue with Compensation

For collections, the compensation is usually a reverse operation:

```dart
Future<void> moveItem(
  TissueList<Item> fromList,
  TissueList<Item> toList,
  Item item,
) async {
  final tx = Cell.txApply();

  try {
    tx.apply(
      fromList,
      () => fromList.remove(item),
      compensate: () => fromList.add(item),
    );

    tx.apply(
      toList,
      () => toList.add(item),
      compensate: () => toList.remove(item),
    );

    await tx.commit();
  } catch (e) {
    await tx.rollback();
    rethrow;
  }
}
```

**For AI agents:**

1. Each compensation is the inverse of the corresponding mutation.
2. The framework runs compensations in **reverse order** of staging — the last-staged mutation is compensated first.
3. This gives you SAGA-style rollback semantics: partial effects are undone step by step.

### 10.5 Multi-Tissue with Savepoint

For finer control, use `savepoint`:

```dart
final tx = Cell.txApply();

tx.apply(cellA, () => cellA.value = 1,
  compensate: () => cellA.value = 0);

tx.apply(cellB, () => cellB.value = 2,
  compensate: () => cellB.value = 0);

// Savepoint after cellA and cellB are staged
final sp = tx.savepoint();

tx.apply(cellC, () => cellC.value = 3,
  compensate: () => cellC.value = 0);

// Rollback to savepoint — only cellC is reversed
await tx.rollback(savepoint: sp);

// cellA and cellB remain staged
await tx.commit();
```

**For AI agents:**

1. `savepoint()` captures the current staging state.
2. `rollback(savepoint: sp)` runs compensations only for mutations staged **after** the savepoint.
3. `commit()` applies all staged mutations still in scope.
4. Savepoints are **not** transactions-within-transactions; they are checkpoints.

✅ **Post-condition:** After rollback to savepoint, only mutations staged after `sp` are reversed.

### 10.6 Conflict Policy

The `TxApplyPolicy` determines behaviour when a staged mutation conflicts with an existing state:

```dart
final tx = Cell.txApply(
  TxApplyOptions(
    policy: TxApplyPolicy.fail,
  ),
);
```

**For AI agents — policy options:**

| Policy | Behaviour |
|---|---|
| `TxApplyPolicy.rollback` | On any failure, roll back all staged mutations |
| `TxApplyPolicy.fail` | On first failure, abort immediately without compensation |
| `TxApplyPolicy.ignore` | Skip failing mutations and continue |
| `TxApplyPolicy.retry` | Retry failing mutations up to a configured limit |

Choose `rollback` for transactional integrity; `fail` for early abort; `ignore` for best-effort batching.

⚠️ **Failure mode:** `TxApplyPolicy.ignore` may leave the system in a partial state. Use it only when partial application is acceptable.

### 10.7 Waiting for Full Propagation

When `wait: true`, `commit()` resolves only after the entire downstream graph has stabilised:

```dart
final tx = Cell.txApply(TxApplyOptions(wait: true));

tx.apply(cellA, () => cellA.value = 1,
  compensate: () => cellA.value = 0);

await tx.commit(); // returns only after all observers have been notified
print('All observers have processed the mutation');
```

**For AI agents:**

1. Use `wait: true` when subsequent code depends on the graph being fully settled.
2. Use `wait: false` for fire-and-forget semantics; `commit()` returns as soon as the mutations are staged for propagation.
3. The default is policy-dependent; check the `TxApplyOptions` documentation for the concrete default.

⚠️ **Failure mode:** `wait: true` on a graph with slow observers (e.g., a `Cell.debounce` downstream) may cause `commit()` to block longer than expected.

### 10.8 Integration Pattern: Coordinating Multiple Tissue Types

`Cell.txApply` works with any mix of Tissue types — the atomicity guarantee is per-staged-mutation, not per-tissue-type:

```dart
Future<void> placeOrder(
  TissueList<Order> orders,
  TissueMap<String, int> inventory,
  TissueValue<double> wallet,
  Order order,
) async {
  final tx = Cell.txApply();

  try {
    final itemId = order.itemId;
    final price = order.price;
    final currentInventory = inventory[itemId] ?? 0;
    final currentBalance = wallet.value ?? 0.0;

    // Guard: check preconditions inside the transaction
    if (currentInventory < 1) {
      throw StateError('Out of stock');
    }
    if (currentBalance < price) {
      throw StateError('Insufficient funds');
    }

    // Stage all three mutations
    tx.apply(
      orders,
      () => orders.add(order),
      compensate: () => orders.remove(order),
    );

    tx.apply(
      inventory,
      () => inventory[itemId] = currentInventory - 1,
      compensate: () => inventory[itemId] = currentInventory,
    );

    tx.apply(
      wallet,
      () => wallet.value = currentBalance - price,
      compensate: () => wallet.value = currentBalance,
    );

    await tx.commit();
  } catch (e) {
    await tx.rollback();
    rethrow;
  }
}
```

**For AI agents — key patterns:**

1. **Read-guard-stage-commit.** Read preconditions inside the transaction; guard with `throw` if violated; stage all mutations; commit.
2. **Compensations are inverses.** Each compensation restores the pre-transaction state of its cell.
3. **Catch and rollback.** Wrap the commit in `try / catch`; on any exception, `await tx.rollback()` and rethrow.
4. **Type-mixing is fine.** `TissueList`, `TissueMap`, `TissueValue`, `TissueSet`, `TissueQueue` all interoperate inside a single `txApply` scope.

✅ **Post-condition:** Either all three mutations are applied and observable, or the system is unchanged.

⚠️ **Failure mode:** Reading state **before** the transaction (e.g., `final bal = wallet.value;` before `Cell.txApply()`) can result in stale reads if another transaction is concurrently modifying the cell. Always read inside the transaction scope.

### 10.9 Composition with Deputies

`txApply` respects deputies — a mutation staged on a deputy is validated by the deputy's test rule:

```dart
final source = TissueValue<int>(100);
final readOnly = source.deputy(testRule: TestTissue.readOnly);

final tx = Cell.txApply();
tx.apply(
  readOnly,
  () => readOnly.value = 50,
  compensate: () => {}, // never runs
);

try {
  await tx.commit();
} catch (e) {
  print('Rejected by read-only gate');
}
```

**For AI agents:**

1. Staging a mutation on a deputy validates against the deputy's test rule.
2. If the deputy is read-only, the commit fails and rollback runs.
3. This is how you enforce scoped authority inside transactions.

### 10.10 Integration with `Field` from `cell_organ`

`TissueValue` is the base of `Field` in `cell_organ`. `txApply` works directly with fields:

```dart
final tx = Cell.txApply();

tx.apply(
  user.name,
  () => user.name.set('Alice'),
  compensate: () => user.name.set('Original'),
);

tx.apply(
  user.email,
  () => user.email.set('alice@example.com'),
  compensate: () => user.email.set('original@example.com'),
);

await tx.commit();
```

**For AI agents:**

1. A `Field` is a `TissueValue`; you can stage mutations on fields directly.
2. The field's test rule (`TestValue` or `TestRelation`) is consulted during commit.
3. The Double Handshake still runs for relational fields — the reciprocal side is updated atomically.

### 10.11 Anti-Patterns

❌ **Prohibition 1:** Do not stage mutations on **unrelated** cells. `txApply` is for coordinated mutations, not for batch commits across unrelated domains. Use multiple transactions instead.

❌ **Prohibition 2:** Do not read state before opening the transaction. Reads must occur inside the transaction scope.

❌ **Prohibition 3:** Do not call `tx.apply(...)` outside a `try / catch`. Any thrown exception must trigger `await tx.rollback()`.

❌ **Prohibition 4:** Do not omit `compensate`. Every staged mutation must be reversible; without a compensation, partial rollback is impossible.

❌ **Prohibition 5:** Do not call `tx.commit()` twice. The scope is single-use.

### 10.12 Success Criteria Summary

For an AI agent verifying a `txApply` implementation:

✅ The scope is created with `Cell.txApply(...)`.
✅ All reads of cell state occur **after** the scope is created.
✅ Each `tx.apply(...)` call has a `compensate` function.
✅ The commit is wrapped in `try / catch`.
✅ Rollback is called on any exception.
✅ The staged mutations and their compensations are true inverses.
✅ The pattern is **read-guard-stage-commit-rollback-on-error**.

If any criterion is not satisfied, the transaction pattern is incorrect.

---

## 11. Common Patterns

### 11.1 Validated Form Field

```dart
final email = TissueValue<String>('');

final emailValidator = TestTissue<String, TissueValue<String>>(
  (value, {host, action, user}) {
    if (value == null) return true; // allow empty during typing
    return (value as String).isEmpty || (value as String).contains('@');
  },
);

final validatedEmail = email.deputy(testRule: emailValidator);
```

### 11.2 Batched Updates with Debounce

```dart
final source = TissueValue<int>(0);

final debounced = Flow.debounce<Pulse<int>>(
  source,
  duration: Duration(milliseconds: 300),
);

Cell.observe(
  source: debounced.cell,
  effect: (pulse) => print('Debounced: ${pulse.payload}'),
);
```

### 11.3 Live Read-Only View for UI

```dart
class ScoreBoard extends StatelessWidget {
  final TissueList<int> _scores;

  ScoreBoard(this._scores);

  @override
  Widget build(BuildContext context) {
    final view = _scores.unmodifiable;
    return ListView.builder(
      itemCount: view.length,
      itemBuilder: (context, i) => Text('${view[i]}'),
    );
  }
}
```

### 11.4 Atomic Counter Increment

```dart
Future<void> increment(TissueValue<int> counter) async {
  final tx = Cell.txApply();
  final current = counter.value ?? 0;
  tx.apply(
    counter,
    () => counter.value = current + 1,
    compensate: () => counter.value = current,
  );
  await tx.commit();
}
```

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `UnsupportedError` on mutation | Tissue is unmodifiable | Use `.deputy()` or the mutable source |
| `Future` not resolving | Async rule suspended under lock | Shorten async rules; check lock contention |
| Observer fires multiple times per mutation | Multiple tissues linked to same observer | Check the observer's source; avoid duplicate links |
| Compensation not running | Mutation was staged but scope not rolled back | Ensure `await tx.rollback()` in the catch block |
| Partial application after rollback | A staged mutation lacks compensation | Every `tx.apply` must provide `compensate` |
| Stale reads in transaction | Reads performed before scope creation | Move reads inside the transaction |
| `Cell.txApply` scope rejected | Mutations attempted outside the scope | All mutations must be staged via `tx.apply(...)` |

---

## 13. References

| Document | Purpose |
|---|---|
| [`README.md`](README.md) | Package overview. |
| [`ARCHITECTURE-Tissue.md`](ARCHITECTURE-Tissue.md) | Design rationale for the collection layer. |
| [`FEATURES-Tissue.md`](FEATURES-Tissue.md) | Source-checked feature catalog. |
| [`HowTo-Tissue-Advanced.md`](HowTo-Tissue-Advanced.md) | Advanced topics — custom containers, propagation policies. |
| [`HowTo-Transaction.md`](../cell/guide/HowTo-Transaction.md) | Full transaction reference in `cell`. |
| [`HowTo-TransactionOnApply.md`](../cell/guide/HowTo-TransactionOnApply.md) | Full `txApply` reference in `cell`. |
| [`packages/cell/guide/HowTo-Start.md`](../cell/guide/HowTo-Start.md) | Starting with the `cell` layer. |
| [`packages/cell_flow/guide/HowTo-Start.md`](../cell_flow/guide/HowTo-Start.md) | Starting with the `cell_flow` layer. |
| [`packages/cell_organ/guide/HowTo-Start.md`](../cell_organ/guide/HowTo-Start.md) | Starting with the `cell_organ` layer. |

---

*If a guide and the source disagree, the source is current.*