# DEMO_GUIDE.md (Tissue Edition)

# (Cell + Flow + Tissue) Demo Guide

## From Simple Collections to Governed Reactive Books

A comprehensive guide to understanding the Cell Framework through practical Tissue examples, organized from fundamental collection patterns to real-world governed-ledger applications.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Tissue Learning Path](#tissue-learning-path)
4. [Level 1: Tissue Collections](#level-1-tissue-collections)
5. [Level 2: Governance & Validation](#level-2-governance--validation)
6. [Level 3: Deputies & Immutability](#level-3-deputies--immutability)
7. [Level 4: The Seam — Flow + Tissue](#level-4-the-seam--flow--tissue)
8. [Level 5: Real-World Applications](#level-5-real-world-applications)
9. [Tissue Collection Reference](#tissue-collection-reference)
10. [Combining Patterns](#combining-patterns)
11. [Common Pitfalls](#common-pitfalls)
12. [Next Steps](#next-steps)

---

## Introduction

The Cell Framework provides a reactive programming model where **Cells** hold state, **Pulses** carry signals, and **Tissue** extends Cell to governed, observable, thread-safe collections. This guide walks you through the Tissue demo examples from simple collections to complex real-world books.

### What You'll Learn

- When to use `TissueList` vs `TissueSet` vs `TissueMap` vs `TissueQueue` vs `TissueValue`
- How to enforce business rules with `TestTissue`
- How to build read-only deputies and audit views
- How to wire Flow decisions into Tissue books
- Common patterns and anti-patterns

### The Two Subsystem Split

Every Tissue demo follows the same architectural pattern:

| Subsystem | Responsibility | Examples |
|-----------|----------------|----------|
| **Flow** | Decision, interpretation, transformation | `Flow.map`, `Flow.filter`, `Flow.debounce` |
| **Tissue** | Durable state, validation, audit trail | `TissueList`, `TissueValue`, `TissueMap` |

**The Golden Rule:** Flow decides. Tissue records. The observer is the only glue. Never mix these responsibilities.

**TestCell vs TestTissue — do not swap:**

| Host | Rule type | Parameter |
|------|-----------|-----------|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` |

`TestCell` is the integrity rule on a **Cell** (shape of an incoming pulse). `TestTissue` is the integrity rule on a **Tissue** (shape of a mutation, a member, a value write). Grep for `testRule: TestCell` on a Tissue constructor: zero hits.

---

## Core Concepts

### What is a Tissue?

A Tissue is a **Cell that is a collection**. It holds physical storage, applies validation, and broadcasts every mutation as a `TissuePulse`.

```dart
final tags = TissueSet<int>(
  const <int>[],
  testRule: TestTissue<int, TissueSet<int>>(
    (v, {host, arguments, user}) => v is int && v >= 0,
  ),
);

tags.add(42);          // validated, observable
tags.add(-1);          // silently rejected by TestTissue
```

### What is a TissuePulse?

A `TissuePulse` is the structural event emitted on every mutation. Three kinds:

| Event | Meaning | Payload |
|-------|---------|---------|
| `ElementAdded` | a member was added | the added element (or iterable for batch) |
| `ElementRemoved` | a member was removed | the removed element (or iterable) |
| `ElementUpdated` | a value cell changed | `ElementUpdatedRecord<V, E>` with `before`/`after` |

```dart
tags.listen((TissuePulse e) {
  if (e is ElementAdded<int>) {
    print('Added: ${e.payload}');
  }
});
```

### What is TestTissue?

`TestTissue` is the integrity rule on a Tissue. It runs on **every** mutation and can accept or reject it. Rules compose with `+`:

```dart
final elementRule = TestTissue<int, TissueSet<int>>(
  (v, {host, arguments, user}) => v is int && v >= 0,
);

final alsoSmall = TestTissue<int, TissueSet<int>>(
  (v, {host, arguments, user}) => v is int && v < 1000,
);

final policy = elementRule + alsoSmall;
```

### What is a Deputy?

A Deputy is a restricted view of a Tissue that shares the same physical storage but applies a different `TestTissue` or `Context`. Deputies are the primary mechanism for read-only projections and scoped authority.

```dart
final source = TissueList<String>(['A', 'B']);
final readOnly = source.deputy(testRule: TestTissue.readOnly);

readOnly.add('C');   // blocked
source.add('C');     // readOnly reflects the change
```

---

## Tissue Learning Path

```
Level 1: Tissue Collections (Start Here)
├── TissueList        - ordered, indexable
├── TissueSet         - unique members
├── TissueMap         - key-value association
├── TissueQueue       - FIFO / double-ended buffer
└── TissueValue       - single scalar atom

Level 2: Governance & Validation
├── TestTissue        - mutation rule
├── element rule      - per-member shape
├── action deny       - block clear/remove
└── runtime mutation  - ops add a rule at runtime

Level 3: Deputies & Immutability
├── .unmodifiable     - read-only projection
├── .deputy(...)      - scoped authority
└── deep projection   - recursive immutability

Level 4: The Seam — Flow + Tissue
├── Gate → Observer   - Flow decides, Tissue records
├── Distinct before Filter - latch ordering
└── ACK resets        - latch without graph rebuild

Level 5: Real-World Applications
├── Card Auth         - payments books
├── Ride-Hail Dispatch - mobility books
├── Grid Demand-Response - energy books
└── NL Instruction    - command surface books
```

---

## Level 1: Tissue Collections

### 1. TissueList — Ordered, Indexable

**What it does:** A reactive list with validation, thread safety, and observability.

**When to use:** Ordered collections where position matters — logs, queues, task lists, audit trails.

```dart
final ledger = TissueList<LedgerEntry>(
  testRule: TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
    (e, {host, arguments, user}) {
      // Append-only rule: allow add/addAll; deny remove/clear/[]=
      if (arguments is Function) {
        final src = arguments.toString();
        if (src.contains('remove') ||
            src.contains('clear') ||
            src.contains('[]=')) {
          return false;
        }
      }
      return true;
    },
  ),
);

ledger.add(LedgerEntry(kind: 'HOLD', authId: 'H-1', detail: '60000¢', at: DateTime.now()));
print(ledger.length); // 1
```

**Key Insight:** `TissueList` routes every mutation through `apply(...)`. The `arguments` parameter of a `TestTissue` rule receives the mutation function, so an append-only rule string-matches against `remove`/`clear`/`[]=`.

---

### 2. TissueSet — Unique Members

**What it does:** A reactive set with value-based or identity-based uniqueness.

**When to use:** Unique element collections — tags, roles, no-go zones, blocklists.

```dart
final mccBlock = TissueSet<String>(
  <String>[],
  testRule: TestTissue<String, TissueSet<String>>(
    (v, {host, arguments, user}) =>
        v is String && v.length == 4 && int.tryParse(v) != null,
  ),
);

mccBlock.add('7995');  // accepted
mccBlock.add('99');    // rejected by TestTissue
```

**Value-based vs identity-based:**

```dart
// Value-based (default): uses == and hashCode
final byValue = TissueSet<MyKey>(<MyKey>[]);

// Identity-based: uses identical
final byIdentity = TissueSet.identity<MyKey>();
```

**Key Insight:** The uniqueness strategy is structural — fixed at creation, inherited by all deputies. You cannot change a value-based set into an identity-based one through a deputy.

---

### 3. TissueMap — Key-Value Association

**What it does:** A reactive map with key-value association and per-value validation.

**When to use:** Registries, assignment tables, caches, index maps.

```dart
final holdsMap = TissueMap<String, Hold>(
  properties: TissueMapNucleus<String, Hold>(
    testRule: TestTissue<Hold, TissueMap<String, Hold>>(
      (v, {host, arguments, user}) =>
          v is Hold && v.amountCents > 0 && v.authId.isNotEmpty,
    ),
  ),
);

holdsMap['H-1'] = Hold(authId: 'H-1', amountCents: 60000, mid: 'M-4419');
```

**Key Insight:** `TissueMap` puts `testRule` on the **nucleus** via `properties:`, not on the constructor. The value type is the "element" type for validation.

---

### 4. TissueQueue — FIFO / Double-Ended Buffer

**What it does:** A reactive queue with optional capacity (circular buffer) behaviour.

**When to use:** Outbound queues, work buffers, event pipelines, bounded outbound channels.

```dart
final rtuQ = TissueQueue<RtuJob>(
  capacity: 32,
  testRule: TestTissue<RtuJob, TissueQueue<RtuJob>>(
    (v, {host, arguments, user}) => true,
  ),
);

rtuQ.addLast(RtuJob(feeder: 'INT-14', action: Action.shed));
```

**Key Insight:** With `capacity`, a full queue drops the oldest element on the next `addLast`. This is the circular-buffer behaviour that gives you backpressure without an explicit reject path.

---

### 5. TissueValue — Single Scalar Atom

**What it does:** A reactive single-value cell with validation and observability.

**When to use:** Counters, balances, flags, single state atoms.

```dart
final reserveMw = TissueValue<int>(
  800,
  testRule: TestTissue<int, TissueValue<int>>(
    (v, {host, arguments, user}) => v is int && v >= 0,
  ),
);

reserveMw.set(750);  // accepted, ElementUpdated emitted
reserveMw.set(-1);   // rejected by TestTissue
```

**Key Insight:** `TissueValue` is the atomic unit of the books. Every write emits an `ElementUpdated` with a `before`/`after` record.

---

## Level 2: Governance & Validation

### 6. TestTissue — Mutation Rule

**What it does:** Enforces a predicate on every mutation.

**When to use:** Any business rule that must hold on every add/remove/set.

```dart
final nonNegative = TestTissue<int, TissueValue<int>>(
  (v, {host, arguments, user}) => v is int && v >= 0,
);
```

**Key Insight:** The rule receives `(value, {host, arguments, user})`. The `arguments` parameter is the mutation function when the rule is invoked from the action path.

### 7. Composition — Multiple Rules

**What it does:** Combines rules with `+`. All must pass; short-circuits on `false`.

```dart
final policy = nonNegative + underThreshold + evenOnly;
```

**Key Insight:** Compose with `+` on the correct side. Do not wrap a `TestCell` in a `TestTissue` — they are not subtypes.

### 8. Runtime Mutation — Ops Change a Rule

**What it does:** Mutate a `TissueSet` or `TissueMap` at runtime without redeploying the graph.

```dart
mccBlock.add('7995');   // ops blocks a category
protected.add('HOSP-1'); // ops protects a feeder
```

**Key Insight:** Policy inputs that can change at runtime belong in a Tissue, not in a Dart `const`. The dispatcher reads the Tissue on every tick.

---

## Level 3: Deputies & Immutability

### 9. `.unmodifiable` — Read-Only Projection

**What it does:** Returns a live, zero-copy read-only view.

**When to use:** Sharing a collection with code that should observe but never mutate.

```dart
final auditor = ledger.unmodifiable;
auditor.add(entry);       // blocked
ledger.add(entry);        // auditor reflects the change (live)
```

**Key Insight:** The view is **not a snapshot** (in the general case). It stays in sync with the source. In some builds it may be a snapshot; check the demo header.

### 10. `.deputy(...)` — Scoped Authority

**What it does:** Returns a restricted view with a different `TestTissue` and `Context`.

**When to use:** Least-privilege access — read-only, scoped authority, temporary leases.

```dart
final readOnly = source.deputy(testRule: TestTissue.readOnly);
final temporary = source.deputy(ephemeralPolicy: EphemeralPolicy(...));
```

**Key Insight:** The deputy's `testRule` is layered **on top** of the principal's. You can only narrow permissions, never widen.

### 11. Deep Projection — Recursive Immutability

**What it does:** When `unmodifiableElement: true` (default), child `Cell` elements are automatically projected as their `.unmodifiable` deputies.

**When to use:** Prevent "side-door" mutations through nested mutable cells.

```dart
final source = TissueList<Task>([Task('Buy milk')]);
final readOnly = source.unmodifiable;
final task = readOnly.first;   // unmodifiable deputy of Task
// task.complete(); // blocked
```

**Key Insight:** The projection is lazy. You get the unmodifiable deputy when you iterate/access; the underlying storage is shared.

---

## Level 4: The Seam — Flow + Tissue

### 12. Gate → Observer — Flow Decides, Tissue Records

**What it does:** Wires a Flow pipeline's output to a Tissue write via `Cell.observe`.

**When to use:** Every real-world Tissue demo.

```dart
// Flow owns the decision
final declined = MapValue<AuthAttempt, Decision>(
      (a) => riskOf(a, mccBlock),
    ) +
    _distinctDecline() +
    Filter<Decision>((d) => d == Decision.decline);

declineCell = declined.toHandle(source: attemptIn.cell).cell;

// Tissue records the decision
Cell.observe(
  source: declineCell,
  effect: (pulse) {
    if (pulse.payload == Decision.decline) {
      ledger.add(LedgerEntry(kind: 'DECLINE', ...));
    }
  },
);
```

**Key Insight:** The Receptor lock on `declineCell` releases before the observer takes the `TissueList` lock. Two locks, two owners, two talk-track sentences.

### 13. Distinct Before Filter — Latch Ordering

**What it does:** Runs `Distinct` **before** `Filter`, so the latch records every decision the pipeline made (including `hold`/`approve`/`idle`).

**When to use:** Any gate where ACK resets the latch, and `shed → hold → shed` must fire twice.

```dart
MapValue<BayTick, Action>((t) => actionOf(t, protected))
  + _distinctShed()
  + Filter<Action>((a) => a == Action.shed)
```

**Key Insight:** If `Filter` ran first, `shed → hold → shed` would fire only once (latch still at `shed`). Running `Distinct` first means the latch tracks every decision.

### 14. ACK Resets — No Graph Rebuild

**What it does:** Clears the Distinct latches without creating a new `toHandle`.

**When to use:** Driver accepts, shift lead restores, operator approves.

```dart
Cell.observe(
  source: ackIn.cell,
  effect: (pulse) {
    resetDistinct();
    // optionally restore(...)
  },
);
```

**Key Insight:** Never call `toHandle` from an observer. It doubles every downstream effect. `resetDistinct` is a plain field assignment — no lock needed.

---

## Level 5: Real-World Applications

### 15. Card Auth — Payments Books

**File:** `card-auth-pipeline(tissue)-Demo.dart`

**What it demonstrates:** The full Flow + Tissue seam in a fintech context.

**Key Components:**

1. **Ingress Layer** — `TestCell` on amount (1–250_000¢), MCC (4 digits)
2. **Flow Layer** — `MapValue` + `Distinct` + `Filter` per decision (DECLINE / STEP-UP)
3. **Tissue Books** — `ledger` (append-only), `available`/`held` (non-negative cents), `holdsMap`, `mccBlock`, `issuerQ`
4. **Money Movement** — `placeHold` / `capture` / `voidHold` with v1 compensation ladder
5. **Compliance** — `ledger.unmodifiable` for the regulator

**Architecture:**

```
amountIn (TestCell) ─┐
mccIn (TestCell) ────┼─ publishAttempt → AuthAttempt
                     │
                     ▼
                  attemptIn
                ┌────┴────┐
                ▼         ▼
           decline     stepUp
           gate        gate
                │         │
                ▼         ▼
          observe     observe
          DECLINE     STEP-UP
                │
                ▼
             ledger.add(...)
             issuerQ.addLast(...)
```

**Key Lessons:**

1. `riskOf` reads `mccBlock` (TissueSet) but never writes it.
2. Distinct runs before Filter on **both** gates.
3. ACK does **not** call `toHandle`; it resets Distinct.
4. Money moves on ACK, not on decision.
5. The invariant `available + held + captured == 250000` holds after every money method.
6. Every Tissue constructor passes `TestTissue`, never `TestCell`.

### 16. Ride-Hail Dispatch — Mobility Books

**File:** `ride-hail-dispatch(tissue)-Demo.dart`

**What it demonstrates:** The same seam with mobility semantics.

**Key Components:**

1. **Sensors** — lat/lng/wait/surge with `TestCell`
2. **Flow** — `MapValue(matchOf)` + Distinct + Filter per gate (DISPATCH / SURGE)
3. **Tissue** — `trips` (append-only), `idleDrivers` (non-negative), `assignments`, `noGo`, `pushQ`
4. **Push Pump** — `_drivePush` with fail-once retry
5. **Auditor** — `trips.unmodifiable` for the city regulator

**Architecture:**

```
latIn / lngIn / waitIn / surgeIn ── publishTick
                                     │
                                     ▼
                                  tickIn
                              ┌─────┴─────┐
                              ▼           ▼
                          dispatch    surge
                          gate        gate
                              │           │
                              ▼           ▼
                          observe     observe
                          DISPATCH    SURGE
                              │
                              ▼
                          trips.add(...)
                          pushQ.addLast(...)
```

**Key Lessons:**

1. `matchOf` reads `noGo` (TissueSet) but never writes it.
2. Closed zone → `idle` before the nearby check.
3. Two latches, two gates, one ACK resets both.
4. Fleet invariant: `idleDrivers + assignments.length == 12`.
5. Forced-zero override in §11 proves the non-negative `TestTissue`.
6. Same two-lock discipline as card-auth.

### 17. Grid Demand-Response — Energy Books

**File:** `grid-demand-response(tissue)-Demo.dart`

**What it demonstrates:** The same seam with power-grid semantics.

**Key Components:**

1. **Sensors** — Hz (49–51), load MW (≥0), SOC (0–100) with `TestCell`
2. **Flow** — `MapValue(actionOf)` + Distinct + Filter per gate (SHED / WARN)
3. **Tissue** — `events` (append-only), `reserveMw` (non-negative), `shedMap`, `protected`, `rtuQ`
4. **RTU Pump** — `_driveRtu` with fail-once retry
5. **Council** — `events.unmodifiable` for the reliability council

**Architecture:**

```
hzIn / loadIn / socIn ── publishTick
                          │
                          ▼
                       tickIn
                   ┌─────┴─────┐
                   ▼           ▼
                shed        warn
                gate        gate
                   │           │
                   ▼           ▼
               observe     observe
               SHED        WARN
                   │
                   ▼
               events.add(...)
               rtuQ.addLast(...)
               applyShed(50)
```

**Key Lessons:**

1. `actionOf` reads `protected` (TissueSet) but never writes it.
2. Protected feeder → `hold` before the frequency check.
3. Reserve invariant: `reserveMw + sum(droppedMw) == 800`.
4. Forced-low override in §11 proves the non-negative `TestTissue`.
5. `_fmtHz` pins Hz to two decimals so `49.70` never renders as `49.7`.

### 18. NL Instruction → TissueSet — Command Surface Books

**File:** `nl-instruction-tissue-set-Demo.dart`

**What it demonstrates:** The same seam with a natural-language ingress.

**Key Components:**

1. **Sentence Ingress** — `TestCell` on non-empty, ≤ 200 chars
2. **Interpreter Instruction** — `AiTissueCommand<String>` (from `ai_tissue_command.dart`)
3. **Classification Filter** — `Flow.filter<Object>` drops `Reject`, counts both
4. **Dispatch Instruction** — `Flow.map` calls `_runDispatch(cmd)` against a swappable host
5. **Tissue Set** — `TissueSet<int>` with `>= 0` element rule
6. **Auditor** — `tags.unmodifiable` for read-only review

**Architecture:**

```
commandIn (TestCell) ── AiTissueCommand ── Filter ── MapValue
                                                        │
                                                        ▼
                                                    _runDispatch
                                                        │
                                                        ▼
                                                    tags.add(...)
```

**Key Lessons:**

1. The model chooses a verb; `modifiable` allows the verb; `TestTissue` allows the element.
2. The interpreter is Flow; the dispatch instruction is Flow; only `_runDispatch` writes Tissue.
3. The dispatcher's host is a `Box<TissueSet<int>>` — swapped to `auditor` in §8, back after.
4. The `modifiable` gate denies before the tear-off runs.
5. Full traffic logging is preserved offline and live.

---

## Tissue Collection Reference

### Collection Types

| Type | Uniqueness | Order | Key Access | Use Case |
|------|------------|-------|------------|----------|
| `TissueList<E>` | Duplicates allowed | Index | `[i]` | Logs, ordered sequences |
| `TissueSet<E>` | Value/identity | Insertion | — | Tags, blocklists, roles |
| `TissueMap<K,V>` | Key uniqueness | Insertion | `[key]` | Registries, indexes |
| `TissueQueue<E>` | Duplicates allowed | FIFO | — | Outbound buffers |
| `TissueValue<V>` | Singleton | — | `.value` | Counters, balances |

### Tissue Constructors

| Constructor | Parameters |
|-------------|------------|
| `TissueList()` | `testRule:` (named) |
| `TissueList.of(elements)` | `testRule:` (named) |
| `TissueSet(elements)` | initial iterable **positional**; `testRule:` named |
| `TissueSet.identity()` | `testRule:` (named) |
| `TissueMap()` | `properties:` named carrying `TissueMapNucleus` |
| `TissueQueue()` | `capacity:` and `testRule:` named |
| `TissueValue(value)` | initial scalar **positional**; `testRule:` named |

### TestTissue Rules

| Rule | Purpose |
|------|---------|
| Element shape | Validate each member (`v is int && v >= 0`) |
| Action deny | Block `remove`/`clear`/`[]=` for append-only logs |
| Non-negative | Reject negative balances |
| Shape-only | Require non-empty id, positive MW, etc. |
| `TestTissue.readOnly` | Block all mutations |
| `TestTissue.allowAll` | Default (no restriction) |

### Deputy Types

| Deputy | Behaviour |
|--------|-----------|
| `.unmodifiable` | `TestTissue.readOnly` + deep projection |
| `.deputy(testRule:)` | Custom `TestTissue`, layered on principal |
| `.deputy(context:)` | Scoped `DeputyContext` |
| `.deputy(ephemeralPolicy:)` | Independent TTL / event-limit |

---

## Combining Patterns

### Pattern: Append-Only Audit Log

Combine `TissueList` (append-only) with a read-only deputy and a Gate observer.

```dart
final ledger = TissueList<LedgerEntry>(
  testRule: TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
    (e, {host, arguments, user}) {
      if (arguments is Function) {
        final src = arguments.toString();
        if (src.contains('remove') || src.contains('clear') || src.contains('[]=')) {
          return false;
        }
      }
      return true;
    },
  ),
);

final auditor = ledger.unmodifiable;

Cell.observe(
  source: gateCell,
  effect: (pulse) => ledger.add(LedgerEntry(...)),
);
```

### Pattern: Bounded Outbound Queue

Combine `TissueQueue` (bounded) with a working list and a fail-once retry.

```dart
final rtuQ = TissueQueue<RtuJob>(capacity: 32);
final _rtuWork = <RtuJob>[];

Cell.observe(
  source: shedCell,
  effect: (pulse) {
    if (pulse.payload == Action.shed) {
      final job = RtuJob(...);
      rtuQ.addLast(job);
      _rtuWork.add(job);
      _driveRtu();
    }
  },
);
```

### Pattern: Money Movement with Compensation

Combine `TissueValue` (balances) with `TissueMap` (open holds) and a compensation ladder.

```dart
bool placeHold(String authId, int cents, String mid) {
  final before = available.value ?? 0;
  if (before < cents) return false;

  holdsMap[authId] = Hold(authId: authId, amountCents: cents, mid: mid);
  final okAvail = available.set(before - cents);
  if (!okAvail) {
    holdsMap.remove(authId);
    return false;
  }

  final heldBefore = held.value ?? 0;
  final okHeld = held.set(heldBefore + cents);
  if (!okHeld) {
    available.set(before);
    holdsMap.remove(authId);
    return false;
  }

  ledger.add(LedgerEntry(kind: 'HOLD', authId: authId, detail: '$cents¢', at: DateTime.now()));
  return true;
}
```

### Pattern: Flow Decision → Tissue Book

Combine a Flow gate with a `Cell.observe` and a `TissueList` append.

```dart
final declined = MapValue<AuthAttempt, Decision>(
      (a) => riskOf(a, mccBlock),
    ) +
    _distinctDecline() +
    Filter<Decision>((d) => d == Decision.decline);

final declineCell = declined.toHandle(source: attemptIn.cell).cell;

Cell.observe(
  source: declineCell,
  effect: (pulse) {
    if (pulse.payload == Decision.decline) {
      ledger.add(LedgerEntry(kind: 'DECLINE', ...));
      issuerQ.addLast(IssuerJob(...));
    }
  },
);
```

---

## Common Pitfalls

| Anti-pattern | Why it breaks the lesson |
|--------------|--------------------------|
| `ledger.add(...)` inside a `MapValue` | Folds Flow into the log; destroys the two-lock discipline. |
| `available.set(...)` inside `riskOf` | Folds Tissue into the decision; makes the policy untestable. |
| Passing `TestCell.allowAll` to a Tissue constructor | Type error at best; silent looseness at worst. |
| Wrapping a `TestCell` in `TestTissue` to "compose" | They are not subtypes; compose with `+` on the correct side. |
| Using a Dart `List<T>` as the source of truth | The books are the `TissueList`; a local list is only for formatting. |
| `toHandle` called from the ACK observer | Doubles every downstream effect on the next tick. |
| Reading `ledger` from inside an observer to "check duplicates" | Duplicates are Distinct's job, not the log's. |
| Emitting a decision from the policy | The policy returns a value; the gate emits the pulse. |
| Bypassing `placeHold` to write `available`/`held` directly | The three money methods are the only writers of the money tables. |
| Ignoring the compensation ladder in `placeHold` | A partial write leaves an orphan hold or a lost balance. |
| Replacing Distinct with "the log has this id" | The log is history; Distinct is the *current* latch. ACK clears the latch, never the log. |
| Holding the Receptor lock across a Tissue write | Violates the two-lock discipline; makes the two subsystems indivisible. |
| Encoding a two-product distinction in a boolean | Two products need two gates; a boolean cannot express the middle state. |
| Making `riskOf` / `actionOf` / `matchOf` async | Purity is the lesson; async reads belong at ingress. |
| Trying to make `.unmodifiable` a snapshot | The contract is live, zero-copy projection. |
| Reading `auditor.length` to prove liveliness without checking the header | Some builds are snapshots; verify before asserting. |

---

## Next Steps

### For Dart Developers New to Cell

1. Read the demo header for one sibling (`card-auth-pipeline(tissue)-Demo.dart`).
2. Read `riskOf` and `installGates` in isolation. They are pure.
3. Trace one DECLINE from `setAmount` through `ledger.add`.
4. Add a fourth decision (`review`) to see the mechanical pattern.

### For Framework Extenders

1. Read `tissue_nucleus.dart` for `TissueNucleusBase`.
2. Read `tissue_container.dart` for the `Container` strategy.
3. Read `tissue_receptor.dart` for the deputy sync engine.
4. Write a custom `Tissue` subtype for a non-standard storage.

### For Domain Porters

1. Pick a sibling closest to your domain.
2. Rename the domain types (`AuthAttempt` → `YourTick`).
3. Rewrite the policy (`riskOf` → `yourPolicy`).
4. Keep the seam: `MapValue → Distinct → Filter` per product, one observer per gate, one `TestTissue` per collection.
5. Keep the two-lock discipline.

### Sibling Demos

| File | Domain | Seam |
|------|--------|------|
| `card-auth-pipeline(tissue)-Demo.dart` | Payments | Flow decides, Tissue records cents |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility | Flow decides, Tissue records trips |
| `grid-demand-response(tissue)-Demo.dart` | Energy | Flow decides, Tissue records MW |
| `nl-instruction-tissue-set-Demo.dart` | Command surface | Flow interprets, Tissue records members |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical | Flow decides, Tissue records alarms |

### Companion Documents

For each demo, the following companions exist:

| Document | Purpose |
|----------|---------|
| `*-Demo.dart` | Executable implementation |
| `*-WalkThrough.md` | Requirement document and scenario contract |
| `*-ARCHITECTURE.md` | Layering, ownership, locking, failure semantics, anti-patterns |
| `*-FEATURES.md` | Operator catalogue and feature index |

Read them in this order:

1. **This file** — the guide in ten minutes.
2. **`*-Demo.dart`** — skim the class doc, then read the pure policy and the gate installation.
3. **`*-WalkThrough.md`** — the requirement and the scenario contract.
4. **`*-FEATURES.md`** — the operator catalogue.
5. **`*-ARCHITECTURE.md`** — the layering and ownership note.

---

*End of DEMO_GUIDE.md (Tissue Edition).*