# Architecture — grid demand-response (Flow + Tissue)

**Companion to:** `grid-demand-response(tissue)-Demo.dart`
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

- **Flow** — the decision subsystem. Turns a `BayTick` into an
  `Action` (`hold` / `warn` / `shed`). Pure, synchronous, no I/O, no
  state mutation, no megawatt writes.
- **Tissue** — the books subsystem. Records decisions, moves
  megawatts, tracks open sheds, exports a read-only view for the
  reliability council. Every write is validated by a `TestTissue`
  and takes that collection's lock.

The two subsystems share exactly **one** communication channel: a
`Cell.observe` attached to each gate cell (`shedCell`, `warnCell`,
`ackIn.cell`). Nothing else crosses the seam. `actionOf` *reads* the
`protected` TissueSet (one-way, non-mutating); that read is the only
other coupling and it is explicitly part of the policy input.

---

## 2. Layering

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  FLOW (decision)                                                │
│  ─────────────────                                              │
│  • Cells:  hzIn, loadIn, socIn, areaIn, feederIn, tickIn,       │
│            ackIn, shedCell, warnCell                            │
│  • Rules:  TestCell — shape only                                │
│  • State:  _lastShed, _lastWarn (Distinct latches)              │
│                                                                 │
│  Produces:  Action  (hold | warn | shed)                        │
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
│      events    TissueList<GridEvent>                            │
│      reserveMw TissueValue<int>                                 │
│      shedMap   TissueMap<String, Shed>                          │
│      protected TissueSet<String>                                │
│      rtuQ      TissueQueue<RtuJob>                              │
│  • Rules:  TestTissue — mutation validity                       │
│  • Deputy: events.unmodifiable (read-only, live)                │
│                                                                 │
│  Produces:  durable state + audit trail                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 What "the seam" means here

A **seam** is a boundary where two subsystems with different
responsibilities, locks, and failure modes meet. In this demo the
seam is one-directional for control (Flow → Tissue) and one-directional
for policy input (Tissue → Flow via a read). The seam is not
bidirectional for writes.

### 2.2 What the seam is **not**

- Not a shared mutable object.
- Not a callback registry.
- Not a shared lock.
- Not a shared enum-comparison pattern inside `actionOf` — the
  comparison reads the TissueSet, but does not mutate it.

The observer is a one-way delivery channel. If you ever find yourself
wanting to write back from the observer to the decision pipeline,
you have collapsed the seam and lost the lesson.

---

## 3. Ownership matrix

| Concern | Flow | Tissue |
|---|---|---|
| Parse Hz / MW / SOC | ✅ `TestCell` on ingress | — |
| Decide `hold` / `warn` / `shed` | ✅ `actionOf` + Distinct + Filter | — |
| Read `protected` | ✅ (read-only, one-way) | ✅ (owns the set) |
| Write `events` | — | ✅ (append-only rule) |
| Write `reserveMw` | — | ✅ (non-negative rule) |
| Write `shedMap` | — | ✅ (shape rule) |
| Write `rtuQ` | — | ✅ (bounded queue) |
| Enforce append-only log | — | ✅ `_eventAppendOnly` |
| Enforce non-negative MW | — | ✅ `_nonNegativeMw` |
| Export to council | — | ✅ `.unmodifiable` |
| React to `RtuJob` | — (see §5.4 for the off-graph note) | ✅ (`rtuQ`) |
| Move megawatts | — | ✅ `applyShed` / `restore` |
| Reset Distinct latches | ✅ `resetDistinct` | — |
| Rebuild graph | — | — (nobody does this after `install`) |

**Rule.** If a concern appears in both columns, it is a layering
violation. The only intentional exception is that `actionOf` reads
`protected`: the read is one-way, non-mutating, and part of the
policy input.

### 3.1 Which subsystem owns which lock

Every reactive node in this graph has its own lock. The demo
deliberately keeps two disjoint lock domains (see §4). No operation
in the demo holds both locks at the same time. That is a design
choice, not a coincidence: it makes each subsystem independently
testable.

---

## 4. Locking

Two lock domains:

| Domain | Primitive | Held during |
|---|---|---|
| Decision | `Receptor` lock on `shedCell` / `warnCell` | `actionOf`, Distinct latch write, `Filter` |
| Books | Tissue lock on each collection | one `add` / `set` / `[key]=` |

A SHED pulse crosses the two domains **sequentially**, never
simultaneously:

```
tickIn.emit(t)
  ─► shedCell Receptor lock
       ─► actionOf
       ─► Distinct
       ─► Filter
  ─► unlock
  ─► observer
       ─► events.add        (TissueList lock)
       ─► rtuQ.addLast      (TissueQueue lock)
       ─► reserveMw.set     (TissueValue lock)
       ─► shedMap[feeder]   (TissueMap lock)
```

### 4.1 Consequences

- Because the domains are disjoint, `actionOf` cannot deadlock
  against `reserveMw.set`.
- Because they are sequential, `actionOf` cannot observe a
  half-written reserve value.
- Because each Tissue write takes its own lock, two observers on
  different gates (SHED and WARN) do not contend on a shared Tissue
  lock unless they happen to target the same collection.

### 4.2 Why the demo does not use a joint lock

A joint commit across `events` + `reserveMw` + `shedMap` would
require a single lock spanning all three. That is a legitimate
pattern (see §6.4), but this build of `cell_tissue` does not expose
it. The v1 protocol in `applyShed` compensates on failure instead,
and the header documents the trade-off.

---

## 5. Failure semantics

### 5.1 Shape failure (TestCell)

A bad Hz / MW / SOC dies at ingress. `setHz` / `setLoad` / `setSoc`
return `false` and do **not** update the cache. `publishTick` is
not called. No Tissue is touched. The rejected value never appears
in `events`, `reserveMw`, `shedMap`, or `rtuQ`.

**Why at the sensor, not inside the policy.** A shape error is a
hardware / telemetry problem, not a policy problem. Folding it into
`actionOf` would make the policy conditional on transport quality
and would let a malformed reading produce a decision.

### 5.2 Policy hold (actionOf)

`actionOf` returning `hold` — protected feeder, in-band frequency,
or neither shed nor warn clause satisfied — produces an `Action` the
gates' `Filter` drops. The **Distinct latch still updates** to
`hold`.

**Why Distinct still updates.** This is what makes
`hold → shed → hold → shed` fire twice. If the latch ignored `hold`,
the second `shed` would be suppressed because the latch would still
hold `shed` from the first tick. See `installGates`'s doc for the
full rationale.

### 5.3 Book rejection (TestTissue)

`applyShed` pre-checks `reserveMw`. If the pre-check fails, no map
row is written. If the pre-check passes but the `reserveMw.set`
rejects (belt-and-braces), the map row is compensated by
`shedMap.remove` and the method returns `false`.

**Invariant.** After a successful call, `reserveMw + sum(droppedMw)`
is `800` (or the last forced value, see §5.5).

### 5.4 RTU retry

`_driveRtu` catches the first failure and retries once. The retry
is counted in `rtuAttempts`. A second failure is swallowed — the
demo does not model dead-letter handling.

**Off-graph note.** The walkthrough specifies `AsyncMapWithRetry`
with `count: 2`. This build's `TissueQueue` does not expose a Stream
adapter and its `removeFirst` / `remove` do not drain. The demo
therefore keeps `rtuQ` as the **audit-side enqueue** and uses a
plain Dart `_rtuWork` list for the pump. The header documents this.

### 5.5 ACK miss

`restore('NONEXISTENT')` returns `false` and touches nothing. ACK
`'ALL'` clears the latches without restoring. Neither is an error.

### 5.6 Forced-low override

Scenario 11 forces `reserveMw.set(30)` — an out-of-band write that
breaks the reserve invariant on purpose. It exists to prove the
`_nonNegativeMw` `TestTissue` rejects an over-shed (`applyShed`
returns `false` at the pre-check). Scenario 12 restores the books
to a self-consistent `80`.

**Production note.** A forced-low override in a real desk would
require an explicit operator gesture and a `TestTissue` rule
guarding `set`. The demo does not model that rule because the
override is the test fixture, not production behaviour.

---

## 6. Extending the demo

### 6.1 Adding a third decision (e.g. `island`)

1. Add `Action.island` to the enum.
2. Add the clause to `actionOf`.
3. Add a third gate: `MapValue + _distinctIsland + Filter(island)`.
4. Add a third observer in `install`.
5. Add the corresponding `TestTissue` and any new collection.
6. Extend the trailer.

The pattern is mechanical: one enum value, one clause, one gate,
one observer, one rule, one counter.

### 6.2 Multi-area routing

Currently `BayTick.area` is a cache field, not a routing key. To
make it a routing key:

1. Turn `tickIn` into a `Cell.hub` with spokes keyed by area.
2. Move the gate installations into per-area functions.
3. Make `protected` a `TissueMap<String, TissueSet<String>>` keyed
   by area.
4. Adjust `actionOf` to look up the area's protected set first, then
   the per-area rule.

### 6.3 Persistent historian

Replace `TissueList<GridEvent>` with a custom `Tissue` subtype that
writes each `ElementAdded` to a database. The `TestTissue` and the
observer code do not change; only the storage strategy changes.

### 6.4 `Cell.transaction` across the shed writes

When the running `cell_tissue` build exposes a joint commit across
`TissueValue` + `TissueMap` + `TissueList`, replace the v1
try/compensate in `applyShed` / `restore` with a single
`Cell.transaction` block. Until then, stay on v1.

### 6.5 Adding a rate limiter in front of `tickIn`

The walkthrough mentions a 6–10 second “frequency still low”
window. That is a `Debounce` in front of `tickIn`:

```dart
final debounced = Flow.debounce<BayTick>(
  tickIn.cell,
  duration: Duration(seconds: 6),
);
```

Wire the gates to `debounced.cell` instead of `tickIn.cell`. The
seam does not move; only the input cadence changes.

### 6.6 Adding an AGC / tie-line ingress

Add `agcIn` as a new ingress + `TestCell`. Publish it on the same
bus (extend `BayTick`) or on a sibling bus. If the AGC signal
affects `actionOf`, it becomes a second input to the policy; the
gates stay as they are.

### 6.7 Migration to a new industry

The pattern is domain-agnostic. To reuse it for, say, mobility:

1. Rename the domain types (`BayTick` → `RideTick`, `Shed` →
   `Dispatch`, etc.).
2. Rewrite `actionOf` for the new policy.
3. Keep the seam: `MapValue → Distinct → Filter` per product, one
   observer per gate, one `TestTissue` per collection.
4. Keep the two-lock discipline.

The `card-auth-pipeline(tissue)-Demo.dart` and
`ride-hail-dispatch(tissue)-WalkThrough.md` files are worked
examples of the same pattern in different domains.

---

## 7. Anti-patterns

| Anti-pattern | Why it breaks the lesson |
|---|---|
| `events.add(...)` inside a `MapValue` | Folds Flow into the log; destroys the two-lock discipline. |
| `reserveMw.set(...)` inside `actionOf` | Folds Tissue into the decision; makes the policy untestable. |
| Replacing Distinct with “event log has this feeder” | The log is history; Distinct is the *current* alarm latch. ACK clears the latch, never the log. |
| `toHandle` called from the ACK observer | Doubles every downstream effect on the next tick. |
| Passing `TestCell.allowAll` to a Tissue constructor | Type error at best; silent looseness at worst. |
| Wrapping a `TestCell` in `TestTissue` to “compose” | They are not subtypes; compose with `+` on the correct side. |
| Using a Dart `List<GridEvent>` as the source of truth | The books are the `TissueList`; a local list is only for formatting. |
| Batching RTU jobs without a `TestTissue` | The queue would accept malformed jobs; the rule is the shape gate. |
| Holding the Receptor lock across a Tissue write | Violates the two-lock discipline; makes the two subsystems indivisible. |
| Using `protected` as a shared mutable global | `actionOf` must read it, not own it; ownership stays with the Tissue. |
| Adding a second `toHandle` for the same gate on every ACK | Classic “stacked graph” bug; ACK must only call `resetDistinct`. |
| Trying to make `actionOf` async so it can await a Tissue read | `actionOf` must stay synchronous; async reads belong at ingress. |
| Encoding the SHED/WARN distinction in a single boolean | Two products need two gates; a boolean cannot express the yellow band. |

---

## 8. Reading order for newcomers

1. **This file** — the architecture in five minutes.
2. **`grid-demand-response(tissue)-Demo.dart`** — skim the class
   doc, then read `actionOf`, `installGates`, `applyShed`.
3. **`grid-demand-response(tissue)-WalkThrough.md`** — the
   requirement and the scenario contract.
4. **`grid-demand-response(tissue)-FEATURES.md`** — the operator catalogue.

For a second domain, read `card-auth-pipeline(tissue)-Demo.dart` in
the same order. The seam is identical; only the policy, the domain
types, and the `TestTissue` rules differ.

---

## 9. See also

| File | Purpose |
|---|---|
| `grid-demand-response(tissue)-Demo.dart` | Executable implementation. |
| `grid-demand-response(tissue)-WalkThrough.md` | Requirement document and scenario contract. |
| `grid-demand-response(tissue)-FEATURES.md` | Operator catalogue and feature index. |
| `card-auth-pipeline(tissue)-Demo.dart` | Payments sibling — same graph shape, different domain. |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | Mobility sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |