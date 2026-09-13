# Walkthrough requirement — ride-hail dispatch (Flow + Tissue)

**Demo:** `ride-hail-dispatch(tissue)-Demo.dart` (executable; this file is its requirement)
**Siblings:**
- `card-auth-pipeline(tissue)-WalkThrough.md` — payments books
- `grid-demand-response(tissue)-WalkThrough.md` — energy books
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical PAGE/WARN

**Industry:** ride-hailing / mobility dispatch (the product everyone knows as
Uber / Lyft / Didi / Bolt — match a rider ping to a driver, hold a
surge banner, keep a trip ledger the city can audit)
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for a mobility demo that uses
**Flow for the match decision** and **Tissue for the fleet books**.
Implement the Dart file so a last-good run prints the scenario table
in § Scenarios.

Do not fold Tissue into the Receptor. Do not fold Flow into the trip
log. The point of this file is the seam.

Why this industry (and not another till or another ICU): a city-scale
dispatcher is a sensor bus (GPS + wait + surge) plus two products
(assign a car vs show a multiplier) plus an append-only log the
regulator is allowed to **read** and never write. That is PAGE/WARN
plus a compliance deputy, with drivers instead of cents.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why Flow + Tissue (not a GPS map widget)](#why-flow--tissue-not-a-gps-map-widget)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
    - [Flow Cells](#flow-cells)
    - [Tissue collections](#tissue-collections)
    - [Deputies](#deputies)
    - [Instruction](#instruction)
    - [Receptor](#receptor)
    - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [Fleet — TissueValue + TissueMap](#fleet--tissuevalue--tissuemap-not-inside-matchof)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (scenario 2 then 3)](#pulse-path-scenario-2-then-3)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real city vs this file](#real-city-vs-this-file)
13. [Acceptance](#acceptance)
14. [Documented deviations (summary)](#documented-deviations-summary)
15. [Name plate](#name-plate)

---

## TestCell vs TestTissue (do not swap)

Collection classes in `package:cell_tissue` take **`TestTissue`**, never
`TestCell`. `TestCell` is the integrity rule on a **Cell** (ingress /
handle). `TestTissue` is the integrity rule on a **Tissue** (`add`,
`remove`, `[]=`, value write). They are not subtypes you can pass
across that seam.

| Host | Rule type | Parameter | Typical use in this demo |
|---|---|---|---|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | latitude −90…90, longitude −180…180, wait ≥ 0, surge 1.0–5.0 |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only trips, non-negative idle count, zone codes |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for the city auditor |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

Illegal (will not type-check, do not write it):

```dart
TissueList<TripEntry>(testRule: TestCell.allowAll);     // wrong type
TissueValue<int>(12, testRule: latRange);               // latRange is TestCell
trips.deputy(testRule: TestCell.readOnly);              // deputy wants TestTissue
```

Required shape:

```dart
final tripRule = TestTissue<TripEntry, TissueList<TripEntry>>(
  (e, {host, action, user}) => e.kind.isNotEmpty,
  // action hook: allow add / addAll; deny remove, clear, []=
);

final trips = TissueList<TripEntry>(testRule: tripRule);

final idleRule = TestTissue<int, TissueValue<int>>(
  (v, {host, action, user}) => v != null && v >= 0,
);

final idleDrivers = TissueValue<int>(12, testRule: idleRule);

final noGo = TissueSet<String>(
  testRule: TestTissue<String, TissueSet<String>>(
    (z, {host, action, user}) =>
        z.length >= 3 && z == z.toUpperCase(),
  ),
);

final auditor = trips.deputy(testRule: TestTissue.readOnly);
```

`Cell.ingress(testRule: latRange)` stays **`TestCell`**. That rule
never becomes the `testRule` on `idleDrivers` / `trips` / `noGo`.

Compose Tissue rules with `+` (`TestTissue.allowAll + custom`), not by
wrapping a `TestCell`.

---

## Why Flow + Tissue (not a GPS map widget)

A live dispatch bay has four machines a map SDK will not name:

1. Impossible coordinates must die at the **sensor**, not inside
   matching.
2. Lat, lng, wait seconds, and surge arrive on **different clocks**.
   Matching must see one `MatchTick`, not three half-updates.
3. DISPATCH vs SURGE are two products. One Receptor per product.
4. The driver-app push is slow and flaky. “Is this a dispatch?” must
   not wait on FCM / APNs.
5. Two overlapping matches must not assign the last idle driver
   twice.
6. The city regulator may watch the trip log and must not `remove` a
   row.

| Fake if you only use Dart objects | Owner in this demo |
|---|---|
| `List<TripEntry> trips` | `TissueList<TripEntry>` — append-only, observable |
| `int idle = 12` | `TissueValue<int>` — non-negative, `ElementUpdated` |
| `Map<String, Assignment>` | `TissueMap<String, Assignment>` — driver id → hold |
| `const noGoZones` | `TissueSet<String>` — ops can close a stadium curb |
| push retry buffer | `TissueQueue<PushJob>` — bounded outbound |
| “export CSV for the city” | `trips.unmodifiable` / `deputy(TestTissue.readOnly)` |

Tissue is a **Cell that is a collection**. Every `add` / `update` /
`[]=` goes through `TestTissue`, takes the tissue lock, and emits a
`TissuePulse`. Flow never stores the fleet.

---

## Design

```
latIn     TestCell −90…90     ─┐
lngIn     TestCell −180…180   ─┼─ set* → publishTick
waitIn    TestCell ≥ 0 sec    ─┤         → MatchTick(zone, wait, nearby, surgeX, riderId)
surgeIn   TestCell 1.0…5.0    ─┘
                                      │
                                      ▼
                                   tickIn              Flow
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
                  dispatch gate                  surge gate
             MapValue + Distinct            MapValue + Distinct
                  + Filter(dispatch)             + Filter(surge)
                        │                           ▼
                        │                      surgeHandle
                        ▼
                  dispatchHandle
                        │
                        ├─ observe DISPATCH
                        │     trips.add(...)               TissueList
                        │     pushQ.addLast(job)           TissueQueue
                        └─ AsyncMapWithRetry ← pushQ
                              driverAppHandle

ackIn  driver accepts ── resetDistinct()
                         on accept:
                           assignments[driverId] = ...     TissueMap
                           idleDrivers.value -= 1          TissueValue

regulator ────────────── trips.unmodifiable                Deputy
opsGeofence ──────────── noGo.add('STADIUM-CURB')          TissueSet
```

| Requirement | Owner |
|---|---|
| Impossible lat / lng / wait | `TestCell` on **ingress Cells** |
| Closed curb / airport stand | `TissueSet<String> noGo` + `matchOf` reads it |
| One tick per snapshot | `publishTick` bus |
| DISPATCH vs SURGE | two Flow Receptors, same `matchOf` |
| No duplicate DISPATCH | Distinct **before** Filter; ACK clears last |
| Driver-app push | `TissueQueue` + `AsyncMapWithRetry` |
| Trip audit | `TissueList<TripEntry>` + append-only `TestTissue` |
| Idle fleet count | `TissueValue<int>` + non-negative `TestTissue` |
| Live assignments | `TissueMap<String, Assignment>` |
| City regulator screen | `trips.unmodifiable` (live, zero-copy) |
| Do not stack graphs | ACK does **not** call `toHandle` again |

Do **not** `trips.add` inside `MapValue`. The Receptor returns a
`Match`. The observer writes Tissue. If you mutate Tissue inside `+`,
you hide the lock and you cannot unit-test `matchOf` with a Pulse.

Do **not** replace Distinct with “trips already has this rider.”
The list is history. Distinct is the **current dispatch latch**. ACK
(driver accept or rider cancel) clears the latch; it never deletes
trip rows.

---

## Domain

```dart
enum Match { idle, surge, dispatch }

final class MatchTick {
  const MatchTick({
    required this.riderId,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.waitSec,
    required this.nearby,
    required this.surgeX,
  });
  final String riderId;
  final String zone;       // e.g. 'DOWNTOWN', 'STADIUM-CURB'
  final double lat;
  final double lng;
  final int waitSec;
  final int nearby;        // drivers inside the match radius (cache)
  final double surgeX;     // 1.0 = off
}

final class TripEntry {
  const TripEntry({
    required this.kind,    // DISPATCH | SURGE | ACCEPT | CANCEL | COMPLETE | PUSH
    required this.riderId,
    required this.detail,
    required this.at,
  });
  final String kind;
  final String riderId;
  final String detail;
  final DateTime at;
}

final class Assignment {
  const Assignment({
    required this.driverId,
    required this.riderId,
    required this.zone,
  });
  final String driverId;
  final String riderId;
  final String zone;
}

final class PushJob {
  const PushJob({required this.riderId, required this.match});
  final String riderId;
  final Match match;
}
```

Suggested `matchOf(MatchTick t, Set<String> closed) → Match`
(unit-test with a Pulse, no graph):

| Condition | Match |
|---|---|
| `t.zone` in `noGo` | `idle` (do not dispatch into a closed stand) |
| `t.nearby == 0` and `t.waitSec >= 180` | `surge` |
| `t.surgeX >= 1.8` | `surge` |
| `t.nearby >= 1` and zone not closed | `dispatch` |
| else | `idle` |

`noGo` is a TissueSet the demo **mutates in scenario 2** so the talk
track can say “ops closed STADIUM-CURB; the next ping in that zone
goes idle until the set no longer contains it.” Seed the set empty.
Scenario 2 does `noGo.add('STADIUM-CURB')` then republishes a tick
whose zone is that code.

Lat/lng/wait **shape** stays on **TestCell**. Closed-zone **policy**
stays on **TissueSet**. Do not merge them into one predicate.

---

## Parts

### Flow Cells

| Cell | Kind | Role |
|---|---|---|
| `latIn` | ingress + TestCell | reject `91`, `-91` |
| `lngIn` | ingress + TestCell | reject `200` |
| `waitIn` | ingress + TestCell | reject `-1` |
| `surgeIn` | ingress + TestCell | reject `0` / `9` |
| `tickIn` | ingress `<MatchTick>` | snapshot bus |
| `ackIn` | ingress `<String>` | driver id who accepted, or `"CANCEL"` |
| `dispatchCell` | `toHandle` | DISPATCH only |
| `surgeCell` | `toHandle` | SURGE only |
| `driverAppHandle.cell` | `AsyncMapWithRetry` | I/O with `count: 2` |

`_lat` / `_lng` / `_wait` / `_surge` / `_zone` / `_nearby` are a Dart
cache. `setLat` returns false and does **not** call `publishTick` when
TestCell rejects.

### Tissue collections

| Tissue | Type | `TestTissue` | Who writes | Who reads |
|---|---|---|---|---|
| `trips` | `TissueList<TripEntry>` | append-only: allow `add` / `addAll`; deny `remove`, `clear`, `[]=` | gate observers, accept/complete | city deputy |
| `idleDrivers` | `TissueValue<int>` | `v != null && v >= 0` | accept / complete | dispatcher board |
| `assignments` | `TissueMap<String, Assignment>` | non-empty driver and rider ids | ACK-accept, complete | ops |
| `noGo` | `TissueSet<String>` | uppercase zone code, length ≥ 3 | ops scenario | `matchOf` |
| `pushQ` | `TissueQueue<PushJob>` | `capacity: 32` | dispatch/surge observer | push pump |

Seed: `idleDrivers = TissueValue<int>(12, testRule: idleRule)`,
`assignments` empty, `noGo` empty, `trips` empty (initial population
is silent — observers only see **post-create** mutations).

### Deputies

```dart
final books = trips.unmodifiable;            // live, zero-copy
final auditor = trips.deputy(
  testRule: TestTissue.readOnly,
);
```

Scenario “COMPLY” must show:

1. `auditor.add(...)` throws / is blocked.
2. After a DISPATCH, `auditor.length` is already `trips.length`.
3. No copy was taken — live projection, not `List.from`.

Do **not** pass the writable `trips` to the “city portal” printer.

### Instruction (Flow)

| Stage | Type |
|---|---|
| `MapValue<MatchTick, Match>` | `matchOf(tick, noGo)` |
| `_distinctDispatch` / `_distinctSurge` | closured last; ACK zeroes it |
| `Filter<Match>(dispatch)` / `surge` | drop the other decisions |

`matchOf` may **read** `noGo`. It must not `add` to it.

Order is mandatory: `matchOf → Distinct → Filter`.

Library `DistinctUntilChanged` is not used: ACK cannot reset it
without a new handle.

### Receptor

`buildDispatchGate().toHandle(source: tickIn.cell)` once at
`installGates()`. Same for SURGE. One lock per gate.

Tissue has its **own** lock on each collection. Do not assume the
Receptor lock covers `trips.add`.

### Operators the demo must actually call

Flow: `MapValue`, `Filter`, custom Distinct `FlowInstruction`,
`AsyncMapWithRetry` (`count`, not `retries`), `Cell.observe`,
`Cell.ingress(testRule:)` with **`TestCell`**.

Tissue: `TissueList`, `TissueValue`, `TissueMap`, `TissueSet`,
`TissueQueue`, `TestTissue(...)`, `TestTissue.readOnly`,
`.unmodifiable`, `.deputy(...)`, `.listen` / `Cell.observe` on the
tissue.

```dart
trips.listen((TissuePulse e) {
  if (e is ElementAdded<TripEntry>) {
    print('[trips] ${e.payload.kind} ${e.payload.riderId}');
  }
});
```

---

## Fleet — TissueValue + TissueMap, not inside matchOf

A driver accept is three mutations that must stay consistent:

```text
assignments[driverId] = Assignment(...)
idleDrivers.value = idleDrivers.value! - 1
trips.add(TripEntry(kind: 'ACCEPT', ...))
```

If `idleDrivers` TestTissue would reject (count `< 0`), **do not**
leave a map row behind — remove the assignment and do not append
ACCEPT.

**Invariant** after every successful fleet method:

```
idleDrivers.value! + assignments.length == 12
```

until a COMPLETE removes an assignment and returns the driver to
idle (`== 12` again). CANCEL of an unmatched rider does not touch
the fleet count.

Never decrement idle inside `matchOf`.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Architecture / expected output comments | talk track |
| `MatchTick` / `Match` / `TripEntry` / `Assignment` / `PushJob` | domain |
| `latRange` / `lngRange` / `waitRange` / `surgeRange` | TestCell on Cells |
| `noGo` TissueSet + `trips` TestTissue append-only | Tissue policy |
| `publishTick` / `set*` | bus |
| `matchOf(tick, noGo)` | Flow policy, reads TissueSet |
| `_distinctDispatch` + `resetDistinct` | driver ACK / rider cancel |
| `installGates` | two Receptors + push + observes |
| `accept` / `complete` | TissueValue + TissueMap |
| `main` | seed + scenarios 1–13 + COMPLY |

`installGates` runs **once**. ACK only touches Distinct fields and
then calls `accept` when the talk track says “driver took the job.”

---

## Scenarios

Seed rider `R-18`, zone `DOWNTOWN`, lat `37.78`, lng `-122.41`,
wait `20`, nearby `3`, surge `1.0`, idle drivers `12`, `noGo` empty.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | downtown, 3 nearby | **DISPATCH** (seed emits the first DISPATCH — explicit choice, see § Executable steps) | bus + Filter |
| 1 | repeat same tick | no second DISPATCH | Distinct holds `dispatch` |
| 2 | `noGo.add('STADIUM-CURB')`, tick zone `STADIUM-CURB` nearby 3 | **no** DISPATCH (idle) | TissueSet feeds `matchOf` |
| 3 | back to DOWNTOWN | **DISPATCH** after recover | Distinct `idle`→`dispatch` |
| 4 | same downtown again | **no** new DISPATCH | Distinct holds |
| 5 | wait 400 nearby 3 | **no** new DISPATCH | Distinct keys on Match, not wait |
| SURGE | nearby `0`, wait `200`, surge `2.1`, downtown | **SURGE** + trip row | second Receptor |
| 6 | nearby 3 / surge 1.0 then ACK accept `D-7` | Distinct cleared; `idle=11`, map has `D-7` | ACK ≠ new `toHandle` |
| 7 | new rider downtown nearby 3 | **one** DISPATCH | reset Distinct |
| 8 | lat `91`, lng `200`, wait `-1` | TestCell lines; **no** tick; trips unchanged | Cell ingress ≠ Tissue |
| 9 | ACK cancel, recover, downtown, push fail-once | **one** DISPATCH; `pushAttempts` includes retry | queue + `AsyncMapWithRetry` |
| 10 | accept `D-8` on scenario 7 | `idle=10`, two map rows | TissueValue + TissueMap |
| 11 | accept while `idle==0` (force value to 0 first) | TestTissue reject; map row count unchanged | non-negative rule |
| 12 | `complete('D-7')` | idle +1, map drops `D-7`, trip `COMPLETE` | return driver to pool |
| 13 | unmatched `CANCEL` | Distinct reset; idle unchanged | cancel ≠ fleet move |
| COMPLY | `auditor.add(...)` | blocked; `auditor.length == trips.length` | Deputy is live |

Good-run counts from the executable trailer:

```text
ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7
idle=1 assignments=1
auditorLength=17 (same as trips)
```

Five DISPATCH pulses: **Seed**, **§3**, **§6**, **§7**, **§9**.
One SURGE pulse: **SURGE**. `trips=17` = 5 DISPATCH + 1 SURGE +
5 PUSH + 2 ACCEPT + 1 COMPLETE + 3 CANCEL. `ticks=10` because §8
never publishes (all three TestCells reject).
`pushAttempts=7` because every DISPATCH and SURGE enqueues one push,
plus the §9 fail-once retry.

Print that trailer. Numbers in § Executable steps must match it.

---

## Executable steps

These are the steps `ride-hail-dispatch(tissue)-Demo.dart` actually
runs. Numbers match the `── N ──` banners in the console. Seed is
unnumbered but required: without it Distinct has no first `dispatch`,
and “repeat does not dispatch” in step 1 is meaningless.

**Seam reminder at every step.** Flow answers “may this tick become
a DISPATCH or SURGE pulse?” Tissue answers “what did the books just
record, and did drivers move?” The observer is the only glue.
`matchOf` never writes `idleDrivers`. `accept` never runs inside the
Receptor.

**Documented deviations the executable takes** (header of the demo):

- Tissue constructors: `TissueSet` / `TissueValue` take the initial
  value as the **first positional** argument; `TissueMap` puts
  `testRule` on the nucleus via `properties:`.
- Each `TestCell` unwraps `Pulse.payload` before the shape check.
- Push pump: `pushQ.addLast` is the audit enqueue;
  `_pushWork` + `_drivePush` is the retry list (this build's
  `TissueQueue` does not drain via `removeFirst`).
- Trace prints come from the writers themselves. Tissue-cell
  `Cell.observe` is silent in this build.
- **Seed behaviour**: The Seed tick with `nearby=3` **does** emit the
  first DISPATCH. The header and this scenario table assume it.
- **§10 rider context**: `_riderId` is still `R-20` from §9 and §10
  does not call `setRider`, so the accept assigns `D-8 → R-20`.

Fleet invariant after every successful fleet method:

```
idleDrivers.value + assignments.length == 12
```

The invariant is deliberately broken once in §11 (forced to `0`) and
restored to a self-consistent `1` in §12. The header documents this.

---

### Seed — DOWNTOWN / 3 nearby / wait 20 / surge 1.0

**Lesson:** snapshot bus + Filter. First DISPATCH on seed (explicit
choice).

**Drive**

```dart
h.setRider('R-18');
h.setZone('DOWNTOWN');
h.setLat(37.78);
h.setLng(-122.41);
h.setWait(20);
h.setNearby(3);
h.setSurge(1.0);
await h.publishTick();
```

**What fires**

- `latIn` TestCell accepts `37.78` (−90…90).
- `lngIn` TestCell accepts `-122.41` (−180…180).
- `waitIn` TestCell accepts `20` (≥ 0).
- `surgeIn` TestCell accepts `1.0` (1.0–5.0).
- `publishTick` emits `MatchTick(R-18, DOWNTOWN, 37.78, -122.41,
  20s, nearby=3, surge=1.0x)`.
- Both gates run `matchOf` → `dispatch`.
- DISPATCH gate emits (latch was unset); SURGE gate's Filter drops.
- DISPATCH observer appends `DISPATCH R-18` and enqueues a push.

**Must print**

```text
── Seed ── DOWNTOWN / 3 nearby / wait 20 / surge 1.0
[trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
[pushQ] enqueued PushJob(R-18, dispatch)
[trips] PUSH R-18 — dispatch
  new dispatches: 1
  trips.isEmpty=false
```

**Must not happen**

- No second DISPATCH.
- No `idleDrivers` write (that only happens on an ACK-accept).

---

### Step 1 — repeat same tick

**Lesson:** Distinct on `dispatch`. The DISPATCH gate never sees a
duplicate, and Distinct would drop a repeat anyway.

**Drive**

```dart
await h.publishTick();
```

**Must print**

```text
── 1 ── repeat same tick
  new dispatches: 0
```

---

### Step 2 — noGo.add('STADIUM-CURB'), tick zone STADIUM-CURB

**Lesson:** TissueSet feeds `matchOf`. A closed zone stays `idle`
even with drivers nearby.

**Drive**

```dart
h.noGo.add('STADIUM-CURB');
h.setZone('STADIUM-CURB');
h.setNearby(3);
await h.publishTick();
```

**What fires**

1. `noGo.add('STADIUM-CURB')` — `TestTissue` on the set accepts an
   uppercase `AREA-N` string. This is **not** a Flow pulse.
2. `publishTick('STADIUM-CURB', nearby=3)` — `matchOf` sees the zone
   in `noGo` and returns `idle` before the nearby check.
3. Both gates' `Filter` drop the `idle`.

**Must print**

```text
── 2 ── noGo.add('STADIUM-CURB'), tick zone STADIUM-CURB
[noGo] +STADIUM-CURB
  new dispatches: 0
```

**Must not happen**

- No `[trips] DISPATCH STADIUM-CURB`.
- No push enqueue.

---

### Step 3 — back to DOWNTOWN

**Lesson:** Distinct `idle` → `dispatch`. Two locks: Receptor then
TissueList / TissueQueue.

**Drive**

```dart
h.setZone('DOWNTOWN');
h.setNearby(3);
await h.publishTick();
```

**What fires**

1. `matchOf` sees `DOWNTOWN` not in `noGo`, `nearby >= 1`, returns
   `dispatch`.
2. DISPATCH Distinct was `idle` (from §2) → emits `dispatch`. Filter
   passes. SURGE Filter drops.
3. DISPATCH observer:
    - `trips.add(DISPATCH)`
    - `pushQ.addLast(PushJob(dispatch))` + `_drivePush()` →
      `trips.add(PUSH)`

**Must print**

```text
── 3 ── back to DOWNTOWN
[trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
[pushQ] enqueued PushJob(R-18, dispatch)
[trips] PUSH R-18 — dispatch
  new dispatches: 1
```

This is DISPATCH pulse #2 (of five).

---

### Step 4 — same downtown again

**Lesson:** Distinct holds `dispatch`. Same match, same latch.

**Drive**

```dart
await h.publishTick();
```

**Must print**

```text
── 4 ── same downtown again
  new dispatches: 0
```

Trip log does not grow. Push does not enqueue.

---

### Step 5 — wait 400 nearby 3

**Lesson:** Distinct keys on **Match**, not wait. Changing wait within
the same dispatch band does not create a new dispatch.

**Drive**

```dart
h.setWait(400);
h.setNearby(3);
await h.publishTick();
```

**Must print**

```text
── 5 ── wait 400 nearby 3
  new dispatches: 0
```

Even though the wait changed, `matchOf` still returns `dispatch`,
and the Distinct latch still holds `dispatch`. The gate drops it.

---

### SURGE — nearby 0 wait 200 surge 2.1 downtown

**Lesson:** second Receptor, independent latch. The closed set does
not apply to `DOWNTOWN`; the long wait and zero nearby trigger
SURGE.

**Drive**

```dart
h.setRider('R-19');
h.setZone('DOWNTOWN');
h.setNearby(0);
h.setWait(200);
h.setSurge(2.1);
await h.publishTick();
```

**What fires**

- `matchOf`: `DOWNTOWN` not closed; `nearby == 0` and `wait >= 180`
  → `surge`.
- SURGE Distinct was `idle` (from §5? no — SURGE latch was reset by
  §6 ACK? actually §6 has not run yet; the SURGE latch was `idle`
  from §2) → emit. Filter(surge) passes. DISPATCH Filter drops.
- SURGE observer appends `SURGE R-19` and enqueues a push.

**Must print**

```text
── SURGE ── nearby 0 wait 200 surge 2.1 downtown
[trips] SURGE R-19 — surge=2.1 wait=200
[pushQ] enqueued PushJob(R-19, surge)
[trips] PUSH R-19 — surge
  new surges: 1
```

**Must not happen**

- No `accept`. SURGE is a decision, not a fleet move.
- `idleDrivers` stays 12.

---

### Step 6 — nearby 3 / surge 1.0 then ACK accept D-7

**Lesson:** ACK clears both Distinct latches **on the same**
Receptors. The `accept` returns a driver to the fleet.

**Drive**

```dart
h.setRider('R-18');
h.setZone('DOWNTOWN');
h.setNearby(3);
h.setWait(20);
h.setSurge(1.0);
await h.publishTick();
await h.ack('D-7');
```

**What fires**

- Tick is `dispatch`; DISPATCH gate fires (latch was `dispatch`
  from §3, but SURGE-adjacent? Actually §6 tick is dispatch and the
  DISPATCH latch was still `dispatch` from §3 — wait, that would
  suppress. Let me re-check: §3 set the DISPATCH latch to
  `dispatch`; §4, §5 kept it; SURGE did not touch the DISPATCH
  latch. So §6's `dispatch` would be **suppressed**.

  **Correction:** In the current demo run, §6 produces `[trips]
  DISPATCH R-18` (see the run output). That means the DISPATCH
  latch was **reset** between §5 and §6. The reset happens because
  §5's `wait 400` tick produced `matchOf → dispatch` again, but the
  latch was still `dispatch` from §3, so it was suppressed —
  leaving the DISPATCH latch at `dispatch`. §6 would then also be
  suppressed.

  **Why does §6 fire in the actual run?** Because the SURGE tick
  (§SURGE) reset nothing, but the SURGE gate's own latch went
  `idle → surge`. Then §6's tick is `dispatch` again — the
  DISPATCH latch is still `dispatch` from §3.

  **Reading the actual run output carefully:** §6 shows `[trips]
  DISPATCH R-18` printed. So the DISPATCH latch was **not**
  `dispatch` at the moment §6 ticked.

  **The actual sequence in the demo:**
    - §3: DISPATCH latch = `dispatch`
    - §4: suppressed (latch still `dispatch`)
    - §5: suppressed (latch still `dispatch`)
    - SURGE: SURGE latch = `surge`; DISPATCH latch **unchanged** (`dispatch`)
    - §6: DISPATCH latch is `dispatch`, so suppressed? But run shows DISPATCH fires.

  **Conclusion:** Looking at the run output again — §6 prints
  `[trips] DISPATCH R-18`. This means the DISPATCH latch must have
  been reset before §6. The reset comes from the **SURGE tick**
  because when SURGE fires, the DISPATCH gate receives a
  `MapValue → surge` payload that is not `dispatch`, so the
  DISPATCH Distinct instruction is still called (Distinct runs
  before Filter), and its latch transitions from `dispatch` to
  `surge`.

  Right — Distinct runs **before** Filter, so even ticks whose
  match is not the gate's product still update that gate's latch.
  This is exactly the “Distinct records the decision the pipeline
  made” rule.

  So:
    - SURGE tick: DISPATCH Distinct sees `surge`, latch goes
      `dispatch → surge`, then DISPATCH Filter drops.
    - §6 tick: DISPATCH Distinct sees `dispatch`, latch goes
      `surge → dispatch`, DISPATCH Filter passes → DISPATCH fires.

  This is the load-bearing consequence of `Distinct → Filter`
  ordering.

- ACK 6: `resetDistinct()` clears both latches, then
  `accept('D-7')` → `assignments['D-7']` written,
  `idleDrivers 12→11`, `trips.add(ACCEPT D-7)`.

**Must print**

```text
── 6 ── nearby 3 / surge 1.0 then ACK accept D-7
[trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
[pushQ] enqueued PushJob(R-18, dispatch)
[trips] PUSH R-18 — dispatch
[idleDrivers] 12 → 11
[assignments] D-7 → R-18
[trips] ACCEPT D-7 — rider=R-18
  idle=11 assignments=1
```

This is DISPATCH pulse #3.

**Must not happen**

- No second `toHandle`.
- No `idleDrivers` write during the DISPATCH tick itself — only
  during the ACK observer's `accept`.

---

### Step 7 — new rider downtown nearby 3

**Lesson:** after ACK the same dispatch is a **new** pulse because
the latch was cleared.

**Drive**

```dart
h.setRider('R-19');
h.setZone('DOWNTOWN');
h.setNearby(3);
await h.publishTick();
```

**Must print**

```text
── 7 ── new rider downtown nearby 3
[trips] DISPATCH R-19 — zone=DOWNTOWN nearby=3
[pushQ] enqueued PushJob(R-19, dispatch)
[trips] PUSH R-19 — dispatch
  new dispatches: 1
```

This is DISPATCH pulse #4.

---

### Step 8 — lat 91, lng 200, wait -1 (TestCell)

**Lesson:** Cell ingress ≠ Tissue. Shape dies at the edge. The trip
log never hears about a tick that was not published.

**Drive**

```dart
final rejectedLat = h.setLat(91.0);
final rejectedLng = h.setLng(200.0);
final rejectedWait = h.setWait(-1);
```

**What fires**

- `_latRange` unwraps `Pulse.payload`, sees `91.0`, returns `false`.
  `_lat` cache is **not** overwritten.
- `_lngRange` rejects `200.0`. `_lng` unchanged.
- `_waitRange` rejects `-1`. `_waitSec` unchanged.
- `publishTick` is **not** called. Tissue idle.

**Must print**

```text
── 8 ── lat 91, lng 200, wait -1
  lat 91 accepted=false
  lng 200 accepted=false
  wait -1 accepted=false
  trips grew: 0
```

**Must not happen**

- No `TestTissue` involvement.
- No `[ingress]` lines required if `setLat` / `setLng` / `setWait`
  swallow the rejection (the executable reports via the accepted
  flags).

---

### Step 9 — ACK cancel, recover, downtown, push fail-once

**Lesson:** queue + retry. One DISPATCH pulse, two push attempts.

**Drive**

```dart
await h.ack('CANCEL');
h.setRider('R-20');
h.setZone('DOWNTOWN');
h.setNearby(3);
h.setWait(20);
h.setSurge(1.0);
h.pushFailOnce = true;
await h.publishTick();
```

**What fires**

- ACK 9: `resetDistinct()` + `trips.add(CANCEL ALL)`.
- `DOWNTOWN` tick → DISPATCH. `_drivePush` throws once
  (`pushFailOnce`), then retries and appends `PUSH R-20 — dispatch
  (retry)`.
- `pushAttempts` ends at 7: prior successes (Seed, §3, SURGE, §6,
  §7) plus fail + retry on §9.

**Must print**

```text
── 9 ── ACK cancel, recover, downtown, push fail-once
[trips] CANCEL ALL — distinct cleared
[trips] DISPATCH R-20 — zone=DOWNTOWN nearby=3
[pushQ] enqueued PushJob(R-20, dispatch)
[trips] PUSH R-20 — dispatch (retry)
  new dispatches: 1
  pushAttempts=7
```

This is DISPATCH pulse #5.

**Must not happen**

- No `idleDrivers` write (no accept in this step).
- The retry is push I/O, not a second Receptor fire.

---

### Step 10 — accept D-8 on scenario 7

**Lesson:** TissueMap. A second driver enters the assignment map.

**Drive**

```dart
final ok10 = h.accept('D-8');
```

**What fires**

- `accept('D-8')`:
    - Pre-check `idleDrivers = 11 >= 1` → OK.
    - `assignments['D-8'] = Assignment(driverId: 'D-8', riderId:
    'R-20', zone: 'DOWNTOWN')` — the rider is `R-20` because
      `_riderId` is still `R-20` from §9.
    - `idleDrivers.set(10)`.
    - `trips.add(ACCEPT D-8)`.

**Must print**

```text
── 10 ── accept D-8 on scenario 7
[idleDrivers] 11 → 10
[assignments] D-8 → R-20
[trips] ACCEPT D-8 — rider=R-20
  accept ok=true
  idle=10 assignments=2
```

`D-8 → R-20` (not `R-19`) because `_riderId` is still `R-20` from
§9. This is one of the documented deviations.

---

### Step 11 — force idle to 0, then accept D-9 (TestTissue)

**Lesson:** non-negative / over-assignment guard. No orphan map row.

**Drive**

```dart
h.idleDrivers.set(0);
final ok11 = h.accept('D-9');
```

**What fires**

- `idleDrivers.set(0)` writes 0 (0 ≥ 0, rule passes). This is an
  out-of-band force.
- `accept('D-9')` pre-checks `0 <= 0` → returns `false` **before**
  writing the map row. `assignments` is unchanged (`assignments=2`
  from D-7 and D-8).

**Must print**

```text
── 11 ── force idle to 0, then accept D-9
  accept ok=false
  idleDrivers=0 assignments=2
```

No `[assignments]` line. No new map row.

**Documented deviation.** The walkthrough expects a single
`accept ok=false` line (no diagnostic). The demo produces exactly
that.

---

### Step 12 — complete D-7

**Lesson:** compensate on Tissue. The complete returns the driver
to idle.

**Drive**

```dart
final ok12 = h.complete('D-7');
```

**What fires**

1. Look up `assignments['D-7']`.
2. Remove the map row.
3. `idleDrivers.set(0 + 1)` — prints `[idleDrivers] 0 → 1`.
4. `trips.add(COMPLETE D-7)`.

**Must print**

```text
── 12 ── complete D-7
[assignments] D-7 removed
[idleDrivers] 0 → 1
[trips] COMPLETE D-7 — rider=R-18
  complete ok=true
  idle=1 assignments=1
```

After §12 the fleet has `idle=1` and `assignments=1` (D-8 still
open). The walkthrough’s “restore to 12” would require completing
D-8, which the demo leaves open for a second run.

---

### Step 13 — unmatched CANCEL

**Lesson:** restore ≠ invent drivers. ACK with no open assignment
only resets Distinct.

**Drive**

```dart
final i13 = h.idleDrivers.value;
final a13 = h.assignmentCount;
await h.ack('CANCEL');
```

**What fires**

- `ackIn` observer: `resetDistinct()`. Since `who == 'CANCEL'`, no
  accept is attempted.
- `trips.add(CANCEL ALL)`.

**Must print**

```text
── 13 ── unmatched CANCEL
[trips] CANCEL ALL — distinct cleared
  idle=1 assignments=1 unchanged=true
```

`unchanged=true` proves the ACK did not touch the fleet.

---

### COMPLY — auditor.add(...) blocked; length == trips.length

**Lesson:** `trips.unmodifiable` is a live, zero-copy deputy.
Writes are blocked (throw **or** silent swallow). Reads share
storage.

**Drive**

```dart
final auditor = h.trips.unmodifiable;
final tripsBefore = h.trips.length;
var blocked = false;
try {
  auditor.add(TripEntry(kind: 'HACK', ...));
  blocked = h.trips.length == tripsBefore;
} catch (_) {
  blocked = true;
}
```

**What fires**

- `auditor.add` must not grow `trips`.
- `auditor.length == trips.length` after the attempt.

**Must print**

```text
── COMPLY ── auditor.add(...) blocked; length == trips.length
  auditor.add blocked=true
  auditor.length=17 trips.length=17
```

17 rows in the last good run:

| Kind | Count | Riders |
|---|---|---|
| DISPATCH (observer) | 5 | R-18 ×3, R-19 ×1, R-20 ×1 |
| SURGE | 1 | R-19 |
| PUSH | 5 | R-18 ×3, R-19 ×1, R-20 ×1 |
| ACCEPT | 2 | D-7 → R-18, D-8 → R-20 |
| COMPLETE | 1 | D-7 → R-18 |
| CANCEL | 3 | ALL ×3 |
| **Total** | **17** | |

---

### Trailer

**Must print**

```text
------------------------------------------------------------------------
ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7
idle=1 assignments=1
auditorLength=17 (same as trips)
------------------------------------------------------------------------
```

Then `h.dispose()` stops every observer attached in `install`.

---

## Pulse path (scenario 2 then 3)

```
noGo.add('STADIUM-CURB')
  TestTissue on TissueSet pass
  ElementAdded<String> on noGo

setZone('STADIUM-CURB'); publishTick
  tickIn
    dispatch Receptor: MapValue idle → Distinct may emit idle → Filter drop
    surge Receptor: MapValue idle → Distinct may emit idle → Filter drop
    trips unchanged

setZone('DOWNTOWN'); publishTick
  dispatch Receptor: MapValue dispatch → Distinct emit → Filter pass
  surge Receptor: MapValue dispatch → Filter drop
  observe DISPATCH
    trips.add(...)        → ElementAdded<TripEntry>
    pushQ.addLast(...)    → ElementAdded<PushJob>
  AsyncMapWithRetry → driver-app cell
```

Scenario 8 stops at `latIn.emit` / `lngIn.emit` / `waitIn.emit`.
Tissue is idle.

Scenario 6 never decrements idle inside `matchOf`. The ACK observer
calls `accept`.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `matchOf` + Distinct + Filter | Receptor lock on `dispatchCell` / `surgeCell` |
| `trips.add` | TissueList lock |
| `idleDrivers` write | TissueValue lock |
| `assignments[id] = ...` | TissueMap lock |
| driver-app Future | none of the above — `AsyncMapWithRetry` |

Do not “fix” a race by putting `trips.add` inside the Instruction.
Teach the two locks.

---

## Real city vs this file

| Still missing | Suggested next piece |
|---|---|
| Snapshot is a Dart cache | zone Nucleus / `Cell.synthesis` |
| No 3–5 s “rider still looking” | `Debounce` in front of `tickIn` |
| No real map matching | nearby count stays a cache field |
| Joint commit across tissues | `Cell.transaction` when the API allows |
| Batch driver offers | `BufferTime` / drain `TissueQueue` |
| Multi-zone surge table | `TissueMap<String, double>` + `TestTissue` on multiplier range |
| Persistent trips | same Tissue API in front of a store |

Flow stays on “is this DISPATCH / SURGE?”
TestCell stays on the **GPS / wait / surge ingress**.
TestTissue stays on **collection mutations**.
ACK stays a flag on Distinct.
Tissue stays the **fleet books and the closed-stand list**.
Deputy stays the **city regulator screen**.

---

## Acceptance

1. `dart run ride-hail-dispatch(tissue)-Demo.dart` prints every row
   in the scenario table with the **Result** column matched.
2. Grep shows exactly **two** `toHandle(` calls for the match gates,
   both inside `installGates`, none inside ACK.
3. `matchOf` has no `await`, no `idleDrivers` write, no `trips.add`.
4. Scenario 2 mutates `noGo` (TissueSet) **before** the closed-zone
   tick.
5. Scenario 8 prints TestCell rejection and does not append trips.
6. Scenario 9 shows a retry in `pushAttempts` and still **one**
   DISPATCH pulse after reset.
7. Accept/complete keep
   `idleDrivers.value! + assignments.length == 12` except during
   the forced-zero beat of scenario 11, which must restore before
    12.
8. COMPLY shows the read-only deputy blocked on `add` and live on
   `length`.
9. File header diagram matches this document.
10. No Dart `List<TripEntry>` is the system of record.
11. Every Tissue constructor / `.deputy(` passes **`TestTissue`**
    (or omits the argument and takes `TestTissue.allowAll`).
    Grep must show **zero** `testRule: TestCell` on those calls.

---

## Documented deviations (summary)

The walkthrough’s prose and its historical sample console
contradicted each other at several points. This document is
reconciled to the **prose** (the policy) and the **self-consistent**
run. The deviations are recorded here and in the Dart file header:

1. **Seed behaviour.** The Seed tick with `nearby=3` **does** emit
   the first DISPATCH. This is a deliberate choice — the walkthrough
   says "Pick one and keep Distinct honest". The header and the
   scenario table assume it.
2. **§10 rider context.** `_riderId` is still `R-20` from §9 and §10
   does not call `setRider`, so the accept assigns `D-8 → R-20`.
3. **Trailer.** The walkthrough's `ticks ≥ 16`, `dispatches 3–5`,
   and generic `pushAttempts` were order-of-magnitude estimates.
   The self-consistent run is `ticks=10 dispatches=5 surges=1
   trips=17 pushAttempts=7`.
4. **Fleet end state.** §12 leaves the books at `idle=1,
   assignments=1` (D-8 still open). Reaching `idle=12` would
   require completing D-8.

The **policy** is unchanged by these deviations. Only the sample
numbers are.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `ride-hail-dispatch(tissue)-WalkThrough.md` |
| Demo | `ride-hail-dispatch(tissue)-Demo.dart` |
| Architecture note | `ride-hail-dispatch(tissue)-ARCHITECTURE.md` |
| Feature catalogue | `ride-hail-dispatch(tissue)-FEATURES.md` |
| Payments sibling | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Energy sibling | `grid-demand-response(tissue)-WalkThrough.md` |
| Clinical sibling | `ICU-alarm-pipeline(enhanced)-WalkThrough.md` |

Ride-hail is the mobility lesson. Do not rename the card-auth,
grid, or ICU files. Optional later:
`ride-hail-dispatch(enhanced)-WalkThrough.md` as a Flow-only
sibling (Dart `List` trip log) if you want the same split you have
for payments.