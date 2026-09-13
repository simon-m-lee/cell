# Features — ride-hail dispatch (Flow + Tissue)

**Companion to:** `ride-hail-dispatch(tissue)-Demo.dart`
**Audience:** operators and reviewers evaluating what the demo
demonstrates and what it deliberately leaves out.

---

## Contents

1. [Feature catalogue](#1-feature-catalogue)
    - [Sensor ingress (TestCell)](#11-sensor-ingress-testcell)
    - [Match policy (Flow)](#12-match-policy-flow)
    - [Distinct latches (Flow)](#13-distinct-latches-flow)
    - [Fleet books (Tissue)](#14-fleet-books-tissue)
    - [Fleet protocol](#15-fleet-protocol)
    - [Push pump](#16-push-pump)
    - [Compliance deputy](#17-compliance-deputy)
2. [Scenario catalogue](#2-scenario-catalogue)
3. [What the demo does not do (deliberately)](#3-what-the-demo-does-not-do-deliberately)
4. [Operator cheat sheet](#4-operator-cheat-sheet)
5. [Acceptance checklist](#5-acceptance-checklist)
6. [See also](#6-see-also)

---

## 1. Feature catalogue

### 1.1 Sensor ingress (TestCell)

| Feature | Where | Behaviour |
|---|---|---|
| Latitude shape validation | `_latRange` on `latIn` | Rejects < −90 or > 90. Accepts any `num`; coerces to double. |
| Longitude shape validation | `_lngRange` on `lngIn` | Rejects < −180 or > 180. Accepts any `num`; coerces to double. |
| Wait shape validation | `_waitRange` on `waitIn` | Rejects negative seconds. Requires `int`. |
| Surge shape validation | `_surgeRange` on `surgeIn` | Rejects < 1.0 or > 5.0. Accepts any `num`; coerces to double. |
| Pulse unwrapping | every `TestCell` rule | Rule reads `Pulse.payload`, not the wrapper. Without this the rule sees a `Pulse<double>` and rejects every emission. |
| Cache-on-accept | `setLat` / `setLng` / `setWait` / `setSurge` | Rejected values do **not** overwrite the previous accepted value. |
| Pre-flight guards | `publishTick` | Re-checks `_latValid` / `_lngValid` / `_waitValid` / `_surgeValid` before emitting, so a scenario can *report* a rejection without publishing. |
| Zero-delay drain | `publishTick` / `ack` | Awaits a `Duration.zero` future so the observer chain drains before the next scenario step. |
| Free-form caches | `setRider` / `setZone` / `setNearby` | No `TestCell` — the rider id, zone, and nearby count are policy inputs, not shape errors. |

### 1.2 Match policy (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Pure match evaluation | `matchOf` (static) | No `await`, no I/O, no state, no fleet writes. |
| Closed-zone idle | `matchOf` first clause | `t.zone in noGoSet` → `idle`, **before** any nearby check. |
| Long-wait surge | `matchOf` second clause | `nearby == 0` and `wait >= 180` → `surge`. |
| High-surge banner | `matchOf` third clause | `surgeX >= 1.8` → `surge`. |
| Dispatch | `matchOf` fourth clause | `nearby >= 1` → `dispatch`. |
| Default idle | `matchOf` final clause | Everything else → `idle`. |
| Ordering guarantee | clause order | A closed zone is never dispatched, even with drivers nearby. |
| Purity enforcement | `static` | A static method cannot reach `this`, so it cannot accidentally call `idleDrivers.set` or `trips.add`. |
| Unit-testable | `static` + no I/O | Can be tested with a bare `MatchTick` and an empty `TissueSet`. |
| Priority of rules | clause order | Earlier clauses win. A closed zone at surge 2.5 is `idle`, not `surge`. |

### 1.3 Distinct latches (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Per-gate latches | `_lastDispatch`, `_lastSurge` | Independent suppression: a SURGE does not clear the DISPATCH latch and vice versa. |
| Distinct-before-Filter | `installGates` order | `dispatch → idle → dispatch` fires **twice**. |
| Latch captures `idle` | Distinct instruction | The latch records the decision the pipeline *made*, including `idle`. |
| Cross-gate latch write | Distinct on both gates | A SURGE tick sets the DISPATCH latch to `surge` (and vice versa). This is the load-bearing consequence of ordering. |
| ACK reset | `resetDistinct` | Clears both latches; no graph rebuild, no new `toHandle`. |
| Single handle per gate | `installGates` | Exactly **two** `toHandle` calls in the whole demo, both in `installGates`. |
| Closure-captured latch | `_distinctDispatch` / `_distinctSurge` | Plain `Match?` fields, not `Box` or `Cell`, so ACK can reset without rebuilding. |

### 1.4 Fleet books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Append-only trip log | `_tripAppendOnly` on `trips` | `add` / `addAll` allowed; `remove` / `clear` / `[]=` denied. |
| Non-negative idle count | `_nonNegativeInt` on `idleDrivers` | Any write that would go negative is rejected. |
| Assignment shape validation | `_assignmentRule` on `assignments` | `driverId.isNotEmpty` and `riderId.isNotEmpty`. |
| No-go zone shape | `_noGoRule` on `noGo` | Uppercase string of length ≥ 3. |
| Bounded push queue | `pushQ` with `capacity: 32` | Overflow drops oldest (circular buffer behaviour). |
| Push job rule | `_pushJobRule` on `pushQ` | Accepts every job — extension hook for future rate-limiting. |
| Initial population is silent | every Tissue | Observers only see *post-create* mutations. |
| Cache of last tick | `_currentTick` | Lets the DISPATCH / SURGE observers correlate the decision with the correct rider and zone. |
| Runtime no-go mutation | `noGo.add(...)` | Ops can close a stand without redeploying the graph. |

### 1.5 Fleet protocol

| Feature | Where | Behaviour |
|---|---|---|
| Over-assignment pre-check | `accept` | Rejects *before* writing the map row, so no orphan `Assignment` record. |
| Compensating write | `accept` | Map row removed if the idle write rejects (belt-and-braces). |
| Complete-by-driver | `complete` | Looks up by driver id; returns the driver to idle. |
| No-op complete | `complete` returns `false` | ACK `'CANCEL'` does not invent drivers. |
| Fleet invariant | trailer | `idleDrivers + assignments.length == 12` — documented break in §11, restored in §12. |
| Out-of-band override | `idleDrivers.set(0)` | Scenario 11 fixture to prove the non-negative guard. |
| Ordered writes | `accept` / `complete` | Map row first, then idle, then trip entry. Order is load-bearing for compensation. |

### 1.6 Push pump

| Feature | Where | Behaviour |
|---|---|---|
| Single-shot retry | `_drivePush` | Retries once on failure. |
| Retry counter | `pushAttempts` | Counts **both** attempts (initial + retry). |
| Fail-once injection | `pushFailOnce` | Scenario 9 flips it on; the next attempt throws once. |
| Audit-side enqueue | `pushQ.addLast` | Every job appears as `ElementAdded<PushJob>` on the queue. |
| Working list | `_pushWork` | Drives the pump, because `TissueQueue.removeFirst` does not drain in this build. |
| Both gates enqueue | DISPATCH and SURGE observers | Every DISPATCH **and** every SURGE enqueues a push job. |
| Silent terminal failure | `_drivePush` catch block | A second failure is swallowed — the demo does not model dead-letter handling. |

### 1.7 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Live read-only view | `trips.unmodifiable` | Zero-copy projection. Reads share storage. |
| Write block | COMPLY scenario | `auditor.add` does not grow `trips`. |
| Length parity | COMPLY scenario | `auditor.length == trips.length` after the attempted write. |
| Silent swallow | this build | The unmodifiable wrapper swallows writes silently, so the demo checks length before/after. |
| Live reflection | this build | Changes to `trips` remain visible through `auditor`. |
| Read-shared storage | `.unmodifiable` contract | `auditor[i]` reads the same underlying `TissueContainer` slot as `trips[i]`. |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | Bus + Filter + first DISPATCH on seed (explicit choice) | `[trips] DISPATCH R-18`, `new dispatches: 1` |
| 1 | Distinct on `dispatch` | `new dispatches: 0` |
| 2 | Closed-zone policy (TissueSet feeds `matchOf`) | `[noGo] +STADIUM-CURB`, `new dispatches: 0` |
| 3 | Distinct `idle`→`dispatch` after recover | `new dispatches: 1` |
| 4 | Distinct suppression (latch holds `dispatch`) | `new dispatches: 0` |
| 5 | Distinct keys on Match, not wait | `new dispatches: 0` |
| SURGE | Second Receptor, independent latch | `[trips] SURGE R-19 — surge=2.1 wait=200`, `new surges: 1` |
| 6 | ACK clears latches + accept | `[idleDrivers] 12 → 11`, `idle=11 assignments=1` |
| 7 | Fresh dispatch after reset | `new dispatches: 1` |
| 8 | TestCell rejection at ingress | `accepted=false` ×3, `trips grew: 0` |
| 9 | Push retry | `[trips] PUSH R-20 — dispatch (retry)`, `pushAttempts=7` |
| 10 | TissueMap second driver | `[assignments] D-8 → R-20`, `assignments=2` |
| 11 | Non-negative TestTissue rejects | `accept ok=false`, `idleDrivers=0 assignments=2` |
| 12 | Complete returns driver to idle | `[idleDrivers] 0 → 1`, `idle=1 assignments=1` |
| 13 | Unmatched CANCEL invents no driver | `unchanged=true` |
| COMPLY | Deputy blocks write, shares storage | `blocked=true`, `auditor.length=17 trips.length=17` |

---

## 3. What the demo does **not** do (deliberately)

| Missing feature | Why it is out of scope | Where it would live |
|---|---|---|
| Real FCM / APNs push | The demo is in-process; a real push gateway is not. | A custom `Tissue` subtype wrapping the push SDK. |
| Real spatial index | `nearby` is a cache field driven by the scenario. | A `Cell.synthesis` over driver positions. |
| Multi-zone surge table | Single-zone keeps the invariant arithmetic honest. | `TissueMap<String, double>` + per-zone rules. |
| Joint commit across tissues | This build's `cell_tissue` does not expose it. | `Cell.transaction` spanning Tissue writes. |
| Persistent trip log | Demo is one-shot, ephemeral. | Same Tissue API over a store. |
| Settlement / billing batch | Not applicable to real-time dispatch. | `BufferTime` if needed. |
| Dead-letter handling | Retry-once is enough for the lesson. | `TissueQueue<PushJob>` with a second consumer. |
| Dead-letter alerting | Same. | An `observe` on the queue's `ElementAdded`. |
| Debounce in front of `tickIn` | The demo publishes one tick per scenario step. | `Flow.debounce<MatchTick>` between `tickIn` and the gates. |
| Multi-product gates beyond DISPATCH/SURGE | Two products are enough to show the shape. | Third gate + third `TestTissue` + third observer. |
| Async `matchOf` | Purity is the lesson; an async policy would require a different test story. | Would need a `FutureOr<Match>` variant of `MapValue`. |
| Rate limiting per rider | Out of scope for v1. | `TestTissue` on `assignments` keyed on a sliding window. |
| Encryption / signing of trips | Out of scope for v1. | A custom `Tissue` subtype that signs each row on `add`. |
| Rider-cancel handling | The demo only cancels the Distinct latch. | A second ACK payload (`'CANCEL-RIDER'`) plus a new observer path. |
| Driver-initiated complete | The demo completes on operator command. | An ingress from the driver app; a new observer path. |
| Payment capture | The demo tracks drivers, not fares. | A `TissueValue<int>` for captured fares plus a `TissueMap` for per-trip amounts. |
| Multi-region federation | The demo is single-zone. | `Cell.hub` keyed on region + per-region Tissue tables. |

---

## 4. Operator cheat sheet

### 4.1 Common operations

| Want | Call |
|---|---|
| Publish a fresh tick | `setRider` / `setZone` / `setLat` / `setLng` / `setWait` / `setNearby` / `setSurge`, then `await publishTick()` |
| Force a dispatch (operator override) | `accept('D-15')` |
| Complete an assignment | `complete('D-7')` |
| Clear the Distinct latches only | `await ack('CANCEL')` |
| Close a zone at runtime | `noGo.add('STADIUM-CURB')` |
| Reopen a closed zone | `noGo.remove('STADIUM-CURB')` |
| Inject a push failure | `pushFailOnce = true` before publishing |

### 4.2 Inspection

| Want | Read |
|---|---|
| All trip entries | `trips` (iterable) |
| Latest trip entry | `trips.last` |
| Trip count | `trips.length` |
| Open assignments | `assignments` |
| Open-assignment count | `assignmentCount` |
| Idle drivers | `idleDrivers.value` |
| Council / auditor view | `trips.unmodifiable` |
| Tick count | `ticks` |
| Dispatch count | `dispatchCount` |
| Surge count | `surgeCount` |
| Push attempt count | `pushAttempts` |
| Closed zones | `noGo` |
| Push queue depth | `pushQ.length` |

### 4.3 Inspecting a single trip entry

A `TripEntry` has four fields:

| Field | Meaning |
|---|---|
| `kind` | `DISPATCH` / `SURGE` / `PUSH` / `ACCEPT` / `COMPLETE` / `CANCEL` |
| `riderId` | the rider the entry refers to (`'ALL'` for `CANCEL ALL`) |
| `detail` | a human-readable summary |
| `at` | when the entry was committed |

A common query is “find all dispatches for rider R-18”:

```dart
final r18Dispatches = trips.where(
  (e) => e.kind == 'DISPATCH' && e.riderId == 'R-18',
);
```

### 4.4 Diagnosing a missing dispatch

1. **Did the coordinates reach the policy?**
   Check `setLat` / `setLng` / `setWait` / `setSurge` return values.
   If `false`, the TestCell rejected them. The caches did **not**
   update.
2. **Was the zone closed?**
   Check `noGo.contains(tick.zone)`. A closed zone returns `idle`
   unconditionally.
3. **Did the policy return `dispatch`?**
   Call `matchOf(tick, noGo)` in isolation. It is pure.
4. **Was the Distinct latch already at `dispatch`?**
   Check `_lastDispatch`. ACK with `'CANCEL'` or a driver id resets
   it.
5. **Was the fleet empty?**
   Check `idleDrivers.value`. `accept` requires
   `idleDrivers.value >= 1`.

### 4.5 Diagnosing a double dispatch

If the same rider dispatches twice for what looks like one tick:

- Check that `installGates` was called exactly **once**. A second
  call attaches a second observer to the same gate, doubling every
  effect.
- Check that `toHandle` was not called from the ACK observer. ACK
  must only call `resetDistinct` (and optionally `accept`).
- Check that the same `MatchTick` was not published twice with a
  latch reset in between. `ack` resets the latches — an ACK
  followed by the same tick will dispatch again.

### 4.6 Diagnosing a missing complete

- Check `assignments.containsKey(driverId)`. `complete` is a no-op
  without an open assignment.
- Check that the ACK payload was a driver id, not `'CANCEL'`.
  `'CANCEL'` clears the latches only.
- Check the `[idleDrivers]` transition line printed. If absent, the
  complete did not run.

### 4.7 Diagnosing an orphan assignment

If `assignments.length + idleDrivers.value != 12`:

- Check the trailer to see the current counts.
- Check `trips` for the last `ACCEPT` and `COMPLETE` rows.
- If an `ACCEPT` is unpaired with a `COMPLETE`, the driver is still
  on the trip. That is the expected state, not a bug.
- If the invariant is broken **without** an unmatched `ACCEPT`, an
  out-of-band `idleDrivers.set(...)` was called (e.g. the demo's
  §11 forced-zero beat).

### 4.8 Diagnosing a stalled push

- Check `pushQ.length`. A non-zero queue with no `_drivePush`
  activity suggests the pump is stuck.
- Check the last `[trips] PUSH` line printed. If it shows a retry,
  the pump succeeded on the second attempt.
- If no `PUSH` line appears at all, the observer never enqueued a
  job — check that the gate fired.

### 4.9 Priority of rules

When two clauses of `matchOf` both seem to apply, the earlier clause
wins. In order:

1. Closed zone → `idle`.
2. `nearby == 0` and `wait >= 180` → `surge`.
3. `surgeX >= 1.8` → `surge`.
4. `nearby >= 1` → `dispatch`.
5. Default → `idle`.

A closed zone at surge 2.5 is `idle`, not `surge`. The order is
load-bearing.

### 4.10 Priority of Distinct clauses

When two ticks seem to be treated as the same decision, check the
per-gate latch:

| Latch | Set by | Reset by |
|---|---|---|
| `_lastDispatch` | every tick (via DISPATCH Distinct) | `ack` |
| `_lastSurge` | every tick (via SURGE Distinct) | `ack` |

Note that **every** tick writes **both** latches (because Distinct
runs before Filter on both gates). A SURGE tick sets the DISPATCH
latch to `surge`; a DISPATCH tick sets the SURGE latch to
`dispatch`. This is why the demo’s §6 fires a DISPATCH after the
SURGE tick — the DISPATCH latch transitioned `dispatch → surge →
dispatch` across two ticks.

### 4.11 Priority of fleet writes

`accept` writes in this order:

1. `assignments[driverId] = Assignment(...)`
2. `idleDrivers.set(before - 1)`
3. `trips.add(TripEntry(kind: 'ACCEPT', ...))`

If step 2 rejects, step 1 is compensated. Step 3 is never reached.
This is the v1 protocol; §6.4 in the architecture note discusses
the joint-commit alternative.

`complete` writes in this order:

1. `assignments.remove(driverId)`
2. `idleDrivers.set(before + 1)`
3. `trips.add(TripEntry(kind: 'COMPLETE', ...))`

None of these steps can reject under the current rules, so
`complete` has no compensation ladder.

---

## 5. Acceptance checklist

The demo is done when **all** of the following hold:

1. `dart run ride-hail-dispatch(tissue)-Demo.dart` matches the
   scenario **Result** column in
   `ride-hail-dispatch(tissue)-WalkThrough.md`.
2. Exactly **two** `toHandle(` calls exist for the match gates, both
   inside `installGates`. Zero in ACK. Zero anywhere else.
3. `matchOf` contains no `await`, no `idleDrivers.set`, no
   `trips.add`, no `assignments[...] =`, no `pushQ.addLast`.
4. Scenario 2 mutates `noGo` **before** the closed-zone tick is
   published.
5. Scenario 8 prints all three TestCell rejections and appends zero
   rows to `trips`.
6. Scenario 9 shows a retry in `pushAttempts` while still producing
   exactly **one** new DISPATCH pulse after the ACK reset.
7. Accept / complete keep the invariant
   `idleDrivers.value! + assignments.length == 12` except during
   the forced-zero beat of scenario 11, and restore a
   self-consistent value in §12.
8. COMPLY shows the read-only deputy blocked on `add` and live on
   `length`.
9. The Dart file's header diagram matches the architecture note.
10. No Dart `List<TripEntry>` is used as the system of record. A
    local `List` used only for formatting is allowed.
11. Every `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` /
    `TissueValue` / `.deputy(` in the demo passes **`TestTissue`**
    (or omits the argument and takes `TestTissue.allowAll`). Grep
    must show **zero** `testRule: TestCell` on those calls.
12. The trailer's counts match
    `ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7` and
    `idle=1 assignments=1`.
13. `auditor.length == trips.length` in the COMPLY step.
14. Only two `toHandle` calls per gate exist across the whole demo
    (one for DISPATCH, one for SURGE). ACK does not call
    `toHandle`.
15. `accept` and `complete` are the only functions that write
    `idleDrivers` and `assignments`. No observer writes them.

---

## 6. See also

| File | Purpose |
|---|---|
| `ride-hail-dispatch(tissue)-Demo.dart` | Executable implementation. |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | Requirement document and scenario contract. |
| `ride-hail-dispatch(tissue)-ARCHITECTURE.md` | Layering, ownership, locking, failure semantics, anti-patterns. |
| `card-auth-pipeline(tissue)-Demo.dart` | Payments sibling — same graph shape, different domain. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |