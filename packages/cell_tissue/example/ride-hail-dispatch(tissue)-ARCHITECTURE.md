# Architecture — ride-hail dispatch (Flow + Tissue)

**Companion to:** `ride-hail-dispatch(tissue)-Demo.dart`
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

- **Flow** — the match decision subsystem. Turns a `MatchTick` into
  a `Match` (`idle` / `surge` / `dispatch`). Pure, synchronous, no
  I/O, no state mutation, no fleet writes.
- **Tissue** — the fleet books subsystem. Records dispatches, moves
  drivers, tracks open assignments, exports a read-only view for the
  city regulator. Every write is validated by a `TestTissue` and
  takes that collection's lock.

The two subsystems share exactly **one** communication channel: a
`Cell.observe` attached to each gate cell (`dispatchCell`,
`surgeCell`, `ackIn.cell`). Nothing else crosses the seam. `matchOf`
*reads* the `noGo` TissueSet (one-way, non-mutating); that read is
the only other coupling and it is explicitly part of the policy
input.

---

## 2. Layering

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  FLOW (decision)                                                │
│  ─────────────────                                              │
│  • Cells:  latIn, lngIn, waitIn, surgeIn, riderIn, zoneIn,      │
│            nearbyIn, tickIn, ackIn, dispatchCell, surgeCell     │
│  • Rules:  TestCell — shape only                                │
│  • State:  _lastDispatch, _lastSurge (Distinct latches)         │
│                                                                 │
│  Produces:  Match  (idle | surge | dispatch)                    │
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
│      trips       TissueList<TripEntry>                          │
│      idleDrivers TissueValue<int>                               │
│      assignments TissueMap<String, Assignment>                  │
│      noGo        TissueSet<String>                              │
│      pushQ       TissueQueue<PushJob>                           │
│  • Rules:  TestTissue — mutation validity                       │
│  • Deputy: trips.unmodifiable (read-only, live)                 │
│                                                                 │
│  Produces:  durable state + audit trail                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 What "the seam" means here

A **seam** is a boundary where two subsystems with different
responsibilities, locks, and failure modes meet. In this demo the
seam is one-directional for control (Flow → Tissue) and
one-directional for policy input (Tissue → Flow via a read). The
seam is not bidirectional for writes.

### 2.2 What the seam is **not**

- Not a shared mutable object.
- Not a callback registry.
- Not a shared lock.
- Not a shared enum-comparison pattern inside `matchOf` — the
  comparison reads the TissueSet, but does not mutate it.

The observer is a one-way delivery channel. If you ever find
yourself wanting to write back from the observer to the decision
pipeline, you have collapsed the seam and lost the lesson.

### 2.3 The three coupling points in this demo

There are exactly three places where the two subsystems touch:

| Coupling | Direction | Type | Notes |
|---|---|---|---|
| `dispatchCell` observer | Flow → Tissue | write-only | `trips.add`, `pushQ.addLast` |
| `surgeCell` observer | Flow → Tissue | write-only | `trips.add`, `pushQ.addLast` |
| `ackIn.cell` observer | Flow → Tissue | write-only + latch reset | `resetDistinct`, `accept`, or `trips.add(CANCEL)` |
| `matchOf` reads `noGo` | Tissue → Flow | read-only | one-way policy input |

The read of `noGo` is the only non-write coupling, and it is
explicitly part of the policy input, not a control channel.

---

## 3. Ownership matrix

| Concern | Flow | Tissue |
|---|---|---|
| Parse lat / lng / wait / surge | ✅ `TestCell` on ingress | — |
| Decide `idle` / `surge` / `dispatch` | ✅ `matchOf` + Distinct + Filter | — |
| Read `noGo` | ✅ (read-only, one-way) | ✅ (owns the set) |
| Write `trips` | — | ✅ (append-only rule) |
| Write `idleDrivers` | — | ✅ (non-negative rule) |
| Write `assignments` | — | ✅ (shape rule) |
| Write `pushQ` | — | ✅ (bounded queue) |
| Enforce append-only log | — | ✅ `_tripAppendOnly` |
| Enforce non-negative count | — | ✅ `_nonNegativeInt` |
| Enforce assignment shape | — | ✅ `_assignmentRule` |
| Enforce no-go zone shape | — | ✅ `_noGoRule` |
| Export to city regulator | — | ✅ `.unmodifiable` |
| React to `PushJob` | — (see §5.4 for the off-graph note) | ✅ (`pushQ`) |
| Move drivers | — | ✅ `accept` / `complete` |
| Reset Distinct latches | ✅ `resetDistinct` | — |
| Rebuild graph | — | — (nobody does this after `install`) |

**Rule.** If a concern appears in both columns, it is a layering
violation. The only intentional exception is that `matchOf` reads
`noGo`: the read is one-way, non-mutating, and part of the policy
input.

### 3.1 Which subsystem owns which lock

Every reactive node in this graph has its own lock. The demo
deliberately keeps two disjoint lock domains (see §4). No operation
in the demo holds both locks at the same time. That is a design
choice, not a coincidence: it makes each subsystem independently
testable.

### 3.2 Which subsystem owns which latch

Distinct latches are Flow state. They are not stored in any Tissue
and they do not appear in the trip log. ACK resets them; nothing
else does.

| Latch | Field | Set by | Reset by |
|---|---|---|---|
| DISPATCH | `_lastDispatch` | `_distinctDispatch` on every tick | `resetDistinct` (ACK) |
| SURGE | `_lastSurge` | `_distinctSurge` on every tick | `resetDistinct` (ACK) |

The two latches are independent. A SURGE tick sets the SURGE latch
to `surge` but also sets the DISPATCH latch to `surge` (because
Distinct runs before Filter on both gates). See §5.2 for the
consequence.

---

## 4. Locking

Two lock domains:

| Domain | Primitive | Held during |
|---|---|---|
| Decision | `Receptor` lock on `dispatchCell` / `surgeCell` | `matchOf`, Distinct latch write, `Filter` |
| Books | Tissue lock on each collection | one `add` / `set` / `[key]=` |

A DISPATCH pulse crosses the two domains **sequentially**, never
simultaneously:

```
tickIn.emit(t)
  ─► dispatchCell Receptor lock
       ─► matchOf
       ─► Distinct
       ─► Filter
  ─► unlock
  ─► observer
       ─► trips.add              (TissueList lock)
       ─► pushQ.addLast          (TissueQueue lock)
       ─► assignments[driverId]  (TissueMap lock, on ACK only)
       ─► idleDrivers.set        (TissueValue lock, on ACK only)
```

The ACK path is slightly different: the ACK is not a tick. It does
not pass through `dispatchCell` or `surgeCell`. It goes straight to
the ACK observer, which calls `resetDistinct()` (Flow state, no
lock needed — it's a plain field assignment) and then
`accept(driverId)` which takes the Tissue locks.

```
ackIn.emit(driverId)
  ─► ackIn.cell observer
       ─► resetDistinct()        (Flow state, no lock)
       ─► accept(driverId)
            ─► assignments[...]  (TissueMap lock)
            ─► idleDrivers.set   (TissueValue lock)
            ─► trips.add         (TissueList lock)
```

### 4.1 Consequences

- Because the domains are disjoint, `matchOf` cannot deadlock
  against `idleDrivers.set`.
- Because they are sequential, `matchOf` cannot observe a
  half-written fleet count.
- Because each Tissue write takes its own lock, two observers on
  different gates (DISPATCH and SURGE) do not contend on a shared
  Tissue lock unless they happen to target the same collection.
- The ACK path holds no Receptor lock; ACK is a direct imperative
  call, not a pulse.

### 4.2 Why the demo does not use a joint lock

A joint commit across `trips` + `idleDrivers` + `assignments` would
require a single lock spanning all three. That is a legitimate
pattern (see §6.4), but this build of `cell_tissue` does not expose
it. The v1 protocol in `accept` compensates on failure instead, and
the header documents the trade-off.

### 4.3 The `accept` compensation ladder

`accept` writes three things in order:

```
1. assignments[driverId] = Assignment(...)   (TissueMap lock released)
2. idleDrivers.set(before - 1)               (TissueValue lock)
3. trips.add(TripEntry(kind: 'ACCEPT', ...)) (TissueList lock)
```

If step 2 rejects (the non-negative rule fires), step 1 is
compensated by `assignments.remove(driverId)`. The method returns
`false` without leaving a partial state. Step 3 is never reached.

If step 3 were to reject (it cannot — `_tripAppendOnly` accepts all
`add` calls), the demo does not currently compensate step 1 or step
2. That is a known limitation of the v1 protocol; §6.4 discusses
   the joint-commit alternative.

`complete` writes in reverse order:

```
1. assignments.remove(driverId)              (TissueMap lock released)
2. idleDrivers.set(before + 1)               (TissueValue lock)
3. trips.add(TripEntry(kind: 'COMPLETE', ...)) (TissueList lock)
```

Step 2 cannot reject (the non-negative rule passes on a positive
write). Step 3 cannot reject. So `complete` has no compensation
ladder — every step is infallible given the current rules.

---

## 5. Failure semantics

### 5.1 Shape failure (TestCell)

A bad lat / lng / wait / surge dies at ingress. `setLat` /
`setLng` / `setWait` / `setSurge` return `false` and do **not**
update the cache. `publishTick` is not called. No Tissue is
touched. The rejected value never appears in `trips`,
`idleDrivers`, `assignments`, or `pushQ`.

**Why at the sensor, not inside the policy.** A shape error is a
GPS / telemetry problem, not a policy problem. Folding it into
`matchOf` would make the policy conditional on transport quality
and would let a malformed reading produce a match.

### 5.2 Policy idle (matchOf)

`matchOf` returning `idle` — closed zone, no nearby drivers,
otherwise unactionable — produces a `Match` the gates' `Filter`
drops. The **Distinct latch still updates** to `idle`.

**Why Distinct still updates.** This is what makes
`dispatch → idle → dispatch` fire twice. If the latch ignored
`idle`, the second `dispatch` would be suppressed because the
latch would still hold `dispatch` from the first tick. See
`installGates`'s doc for the full rationale.

**The cross-gate latch write.** Distinct runs before Filter on
*both* gates. This means a SURGE tick sets the DISPATCH latch to
`surge` (because the DISPATCH Distinct sees `surge` as the current
decision), and the DISPATCH Filter then drops the pulse. On the
next `dispatch` tick, the DISPATCH latch transitions `surge →
dispatch` and the DISPATCH Filter passes.

This is the load-bearing consequence of the `Distinct → Filter`
ordering. It is why §6 in the walkthrough fires a DISPATCH pulse
even though §3 set the latch to `dispatch` and the SURGE tick in
between did not seem to touch the DISPATCH state.

The rule in one sentence: **Distinct records every decision the
pipeline made, regardless of which gate the decision belongs to.**

### 5.3 Book rejection (TestTissue)

`accept` pre-checks `idleDrivers`. If the pre-check fails, no
assignment row is written. If the pre-check passes but the
`idleDrivers.set` rejects (belt-and-braces), the assignment row is
compensated by `assignments.remove` and the method returns `false`.

**Invariant.** After a successful call,
`idleDrivers.value! + assignments.length` is `12` (or the last
forced value, see §5.5).

### 5.4 Push retry

`_drivePush` catches the first failure and retries once. The retry
is counted in `pushAttempts`. A second failure is swallowed — the
demo does not model dead-letter handling.

**Off-graph note.** The walkthrough specifies `AsyncMapWithRetry`
with `count: 2`. This build's `TissueQueue` does not expose a Stream
adapter and its `removeFirst` / `remove` do not drain. The demo
therefore keeps `pushQ` as the **audit-side enqueue** and uses a
plain Dart `_pushWork` list for the pump. The header documents this.

**Why the audit-side enqueue still matters.** Every `addLast` on
`pushQ` emits an `ElementAdded<PushJob>` on the Tissue. A
downstream observer could subscribe to that queue and reconstruct
exactly which pushes were attempted, when, and for which match.
The queue is the durable record of the push channel's activity,
even though the actual pump runs on a plain list.

### 5.5 Forced-zero override

Scenario 11 forces `idleDrivers.set(0)` — an out-of-band write that
breaks the fleet invariant on purpose. It exists to prove the
`_nonNegativeInt` `TestTissue` rejects an over-assignment (`accept`
returns `false` at the pre-check). Scenario 12 restores the books to
a self-consistent `1`.

**Production note.** A forced-zero override in a real dispatcher
would require an explicit operator gesture and a `TestTissue` rule
guarding `set`. The demo does not model that rule because the
override is the test fixture, not production behaviour.

### 5.6 ACK miss

`complete('UNKNOWN')` returns `false` and touches nothing. ACK
`'CANCEL'` clears the latches without completing. Neither is an
error.

**The two ACK paths.**

| ACK payload | Observer behaviour | Tissue effect |
|---|---|---|
| Driver id (e.g. `'D-7'`) | `resetDistinct()` then `accept('D-7')` | `assignments['D-7']` written, `idleDrivers` decremented, `trips.add(ACCEPT)` |
| `'CANCEL'` (or empty / null) | `resetDistinct()` then `trips.add(CANCEL ALL)` | only the trip log grows; no fleet move |

The two paths are mutually exclusive. A driver id that happens to
be `'CANCEL'` (no real fleet would name a driver that) would be
treated as a cancel. The demo does not defend against that
collision; it is a reserved payload.

### 5.7 Cascade failure

If `_drivePush` fails twice, the push job is dropped silently. The
trip log records nothing about the second failure (it records the
retry attempt, but not the terminal failure). A production system
would emit a `PUSH_FAILED` entry with the retry count.

---

## 6. Extending the demo

### 6.1 Adding a third decision (e.g. `reserve`)

1. Add `Match.reserve` to the enum.
2. Add the clause to `matchOf`.
3. Add a third gate:
   `MapValue + _distinctReserve + Filter(reserve)`.
4. Add a third observer in `install`.
5. Add the corresponding `TestTissue` and any new collection.
6. Extend the trailer.

The pattern is mechanical: one enum value, one clause, one gate,
one observer, one rule, one counter.

### 6.2 Multi-zone routing

Currently `MatchTick.zone` is a policy input only (checked against
`noGo`). To make it a routing key:

1. Turn `tickIn` into a `Cell.hub` with spokes keyed by zone.
2. Move the gate installations into per-zone functions.
3. Make `noGo` a `TissueMap<String, TissueSet<String>>` keyed by
   region.

### 6.3 Persistent trip log

Replace `TissueList<TripEntry>` with a custom `Tissue` subtype that
writes each `ElementAdded` to a database. The `TestTissue` and the
observer code do not change; only the storage strategy changes.

**What this buys.** The city regulator's `trips.unmodifiable` view
still works — the view reads from the new storage strategy. The
`_tripAppendOnly` rule still fires on every `add`. The observers
still call `trips.add(...)`. The only code that changes is the
storage layer underneath the `TissueList`.

**What this costs.** A persistent store introduces I/O latency.
The `accept` and `complete` methods would need to await the write,
or accept that the trip entry lands asynchronously. The v1
protocol currently assumes synchronous Tissue writes.

### 6.4 `Cell.transaction` across the fleet writes

When the running `cell_tissue` build exposes a joint commit across
`TissueValue` + `TissueMap` + `TissueList`, replace the v1
try/compensate in `accept` / `complete` with a single
`Cell.transaction` block. Until then, stay on v1.

**The joint-commit shape.** A hypothetical joint commit would
look like:

```dart
await Cell.transaction((tx) async {
  tx.update(assignments, {'D-7': Assignment(...)});
  tx.update(idleDrivers, 11);
  tx.update(trips, TripEntry(kind: 'ACCEPT', ...));
  await tx.commit();
});
```

If any of the three writes reject, the whole transaction rolls
back. This eliminates the need for `accept`'s try/compensate
ladder.

### 6.5 Adding a debounce in front of `tickIn`

The walkthrough mentions a 3–5 second “rider still looking” window.
That is a `Debounce` in front of `tickIn`:

```dart
final debounced = Flow.debounce<MatchTick>(
  tickIn.cell,
  duration: Duration(seconds: 4),
);
```

Wire the gates to `debounced.cell` instead of `tickIn.cell`. The
seam does not move; only the input cadence changes.

**What this changes.** The Distinct latch now sees one tick per
debounce window instead of one tick per publish. If the rider’s
position changes five times in three seconds, only the last tick
reaches the gates. This is the desired behaviour for a real
dispatcher.

### 6.6 Adding a real spatial index

The `nearby` count is currently a cache field the scenario drives
directly. A real system would compute it from a spatial index of
driver positions. That index would live in a `Cell.synthesis` or a
`Tissue` of its own; the demo does not model it because a real
index is a separate subsystem, not part of the seam lesson.

**Where it would live.** The spatial index is a Flow concern (it
produces the `nearby` count consumed by `matchOf`) or a Tissue
concern (it owns a `TissueMap<Zone, int>` of driver counts). The
choice depends on whether the index is reactive (updated by driver
position pings) or computed on demand.

### 6.7 Multi-zone surge table

A single surge multiplier is a simplification. A real dispatcher
would key surge on `(zone, hourOfDay)` or `(zone, weather)`. That
would be a `TissueMap<String, double>` with a `TestTissue` on the
multiplier range:

```dart
final surgeTable = TissueMap<String, double>(
  properties: TissueMapNucleus<String, double>(
    testRule: TestTissue<double, TissueMap<String, double>>(
      (v, {host, arguments, user}) => v != null && v >= 1.0 && v <= 5.0,
    ),
  ),
);
```

`matchOf` would read `surgeTable[t.zone] ?? 1.0` instead of
`t.surgeX`. The policy stays pure (it reads a Tissue); the surge
input moves from the tick to the tissue.

### 6.8 Migration to a new industry

The pattern is domain-agnostic. To reuse it for, say, energy:

1. Rename the domain types (`MatchTick` → `BayTick`, `Assignment`
   → `Shed`, etc.).
2. Rewrite `matchOf` for the new policy.
3. Keep the seam: `MapValue → Distinct → Filter` per product, one
   observer per gate, one `TestTissue` per collection.
4. Keep the two-lock discipline.

The `card-auth-pipeline(tissue)-Demo.dart` and
`grid-demand-response(tissue)-Demo.dart` files are worked examples
of the same pattern in different domains.

---

## 7. Anti-patterns

| Anti-pattern | Why it breaks the lesson |
|---|---|
| `trips.add(...)` inside a `MapValue` | Folds Flow into the log; destroys the two-lock discipline. |
| `idleDrivers.set(...)` inside `matchOf` | Folds Tissue into the decision; makes the policy untestable. |
| Replacing Distinct with “trip log has this rider” | The log is history; Distinct is the *current* dispatch latch. ACK clears the latch, never the log. |
| `toHandle` called from the ACK observer | Doubles every downstream effect on the next tick. |
| Passing `TestCell.allowAll` to a Tissue constructor | Type error at best; silent looseness at worst. |
| Wrapping a `TestCell` in `TestTissue` to “compose” | They are not subtypes; compose with `+` on the correct side. |
| Using a Dart `List<TripEntry>` as the source of truth | The books are the `TissueList`; a local list is only for formatting. |
| Batching push jobs without a `TestTissue` | The queue would accept malformed jobs; the rule is the shape gate. |
| Holding the Receptor lock across a Tissue write | Violates the two-lock discipline; makes the two subsystems indivisible. |
| Using `noGo` as a shared mutable global | `matchOf` must read it, not own it; ownership stays with the Tissue. |
| Adding a second `toHandle` for the same gate on every ACK | Classic “stacked graph” bug; ACK must only call `resetDistinct`. |
| Trying to make `matchOf` async so it can await a Tissue read | `matchOf` must stay synchronous; async reads belong at ingress. |
| Encoding the DISPATCH/SURGE distinction in a single boolean | Two products need two gates; a boolean cannot express the surge banner. |
| Moving the Distinct latch into a Tissue | Distinct is Flow state, not book state. ACK resets it; the trip log does not. |
| Reading `trips` from inside the DISPATCH observer to “check duplicates” | Duplicates are Distinct's job, not the log's. Reading the log adds lock contention and couples the observer to the log’s storage strategy. |
| Emitting a `Match` directly from `matchOf` | `matchOf` returns a value; the gate emits the pulse. Separating the two is what makes `matchOf` unit-testable. |
| Bundling `accept` into the DISPATCH observer | The DISPATCH observer must not touch `idleDrivers`. Accept is a separate moment, triggered by an ACK. |
| Decrementing `idleDrivers` inside `matchOf` | `matchOf` is pure. The fleet count is Tissue state. |

---

## 8. Reading order for newcomers

1. **This file** — the architecture in five minutes.
2. **`ride-hail-dispatch(tissue)-Demo.dart`** — skim the class doc,
   then read `matchOf`, `installGates`, `accept`.
3. **`ride-hail-dispatch(tissue)-WalkThrough.md`** — the requirement
   and the scenario contract.
4. **`ride-hail-dispatch(tissue)-FEATURES.md`** — the operator catalogue.

For a second domain, read `card-auth-pipeline(tissue)-Demo.dart` or
`grid-demand-response(tissue)-Demo.dart` in the same order. The seam
is identical; only the policy, the domain types, and the
`TestTissue` rules differ.

---

## 9. See also

| File | Purpose |
|---|---|
| `ride-hail-dispatch(tissue)-Demo.dart` | Executable implementation. |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | Requirement document and scenario contract. |
| `ride-hail-dispatch(tissue)-FEATURES.md` | Operator catalogue and feature index. |
| `card-auth-pipeline(tissue)-Demo.dart` | Payments sibling — same graph shape, different domain. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |