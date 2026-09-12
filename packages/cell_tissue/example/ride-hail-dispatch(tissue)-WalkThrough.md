# Walkthrough requirement — ride-hail dispatch (Flow + Tissue)

**Suggested demo:** `ride-hail-dispatch(tissue)-Demo.dart`  
**Siblings (same graph, other industries):**  
- `card-auth-pipeline(tissue)-WalkThrough.md` — payments books  
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

## TestCell vs TestTissue (do not swap)

Collection classes in `package:cell_tissue` take **`TestTissue`**, never
`TestCell`. `TestCell` is the integrity rule on a **Cell** (ingress /
handle). `TestTissue` is the integrity rule on a **Tissue** (`add`,
`remove`, `[]=`, value write). They are not subtypes you can pass
across that seam.

| Host | Rule type | Parameter | Typical use in this demo |
|---|---|---|---|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | latitude −90…90, longitude −180…180, wait ≥ 0 |
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

1. Impossible coordinates must die at the **sensor**, not inside matching.
2. Lat, lng, wait seconds, and surge arrive on **different clocks**.
   Matching must see one `MatchTick`, not three half-updates.
3. DISPATCH vs SURGE are two products. One Receptor per product.
4. The driver-app push is slow and flaky. “Is this a dispatch?” must
   not wait on FCM / APNs.
5. Two overlapping matches must not assign the last idle driver twice.
6. The city regulator may watch the trip log and must not `remove` a row.

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
| `dispatchHandle.cell` | `toHandle` | DISPATCH only |
| `surgeHandle.cell` | `toHandle` | SURGE only |
| `driverAppHandle.cell` | `AsyncMapWithRetry` | I/O with `count: 2` |

`_lat` / `_lng` / `_wait` / `_surge` / `_zone` / `_nearby` are a Dart
cache. `setLat` returns false and does **not** call `publishTick` when
TestCell rejects.

### Tissue collections

| Tissue | Type | `TestTissue` | Who writes | Who reads |
|---|---|---|---|---|
| `trips` | `TissueList<TripEntry>` | append-only: allow `add` / `addAll`; deny `remove`, `clear`, `[]=` | gate observers, accept/complete | city deputy |
| `idleDrivers` | `TissueValue<int>` | `v != null && v >= 0` | accept / complete / cancel | dispatcher board |
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
| `MapValue<MatchTick, Match>` | `matchOf(tick, noGo.toSet())` |
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

## Fleet count — TissueValue + TissueMap, not inside matchOf

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
| `accept` / `complete` / `cancelUnmatched` | TissueValue + TissueMap |
| `main` | seed + scenarios 1–13 + COMPLY |

`installGates` runs **once**. ACK only touches Distinct fields and
then calls `accept` when the talk track says “driver took the job.”

---

## Scenarios (what the last good run must show)

Seed rider `R-18`, zone `DOWNTOWN`, lat `37.78`, lng `-122.41`,
wait `20`, nearby `3`, surge `1.0`, idle drivers `12`, `noGo` empty.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | downtown, 3 nearby | one tick, **no** DISPATCH if you treat seed as idle-stable — **or** first DISPATCH if nearby≥1. Pick one and keep Distinct honest: seed as `nearby=3` **does** emit the first DISPATCH | bus + Filter |
| 1 | repeat same tick | no second DISPATCH | Distinct holds `dispatch` |
| 2 | `noGo.add('STADIUM-CURB')`, tick zone `STADIUM-CURB` nearby 3 | **no** DISPATCH (idle); optional ledger skip | TissueSet feeds `matchOf` |
| 3 | back to DOWNTOWN | **DISPATCH** after recover | Distinct `idle`→`dispatch` |
| 4–5 | same downtown again, then wait 400 with nearby 3 | **no** new DISPATCH | Distinct holds |
| SURGE | nearby `0`, wait `200`, surge `2.1`, downtown | **SURGE** + trip row | second Receptor |
| 6 | nearby 3 / surge 1.0 then ACK accept `D-7` | Distinct cleared; `idle=11`, map has `D-7` | ACK ≠ new `toHandle` |
| 7 | new rider downtown nearby 3 | **one** DISPATCH | reset Distinct |
| 8 | lat `91`, lng `200`, wait `-1` | TestCell lines; **no** tick; trips unchanged | Cell ingress ≠ Tissue |
| 9 | ACK cancel, recover, downtown, push fail-once | **one** DISPATCH; `pushAttempts` includes retry | queue + `AsyncMapWithRetry` |
| 10 | accept `D-7` already done in 6; accept `D-8` on scenario 7 | `idle=10`, two map rows | TissueValue + TissueMap |
| 11 | accept while `idle==0` (force value to 0 first if needed) | TestTissue reject; map row count unchanged | non-negative rule |
| 12 | `complete('D-7')` | idle +1, map drops `D-7`, trip `COMPLETE` | return driver to pool |
| 13 | unmatched `CANCEL` | Distinct reset; idle unchanged | cancel ≠ fleet move |
| COMPLY | `auditor.add(...)` | blocked; `auditor.length == trips.length` | Deputy is live |

Be explicit in the demo header which seed behaviour you chose (first
DISPATCH on seed vs seed as idle). Counts below assume **seed emits
the first DISPATCH**, scenarios 3 and 7 emit two more after recover /
ACK.

Good-run counts (order of magnitude): ticks ≥ 16, dispatches 3–5,
surges 1, trip rows ≥ 7 plus ACCEPT/COMPLETE. `pushAttempts` can be
higher if the first driver-app call throws.

Print a trailer:

```text
ticks=… dispatches=… surges=… trips=… pushAttempts=…
idle=11 assignments=1
auditorLength=… (same as trips)
```

Adjust the trailer to the actual end state after 12–13 (idle back
toward 12 if you completed the open assignment).

---

## Pulse path (scenario 2 then 3)

```
noGo.add('STADIUM-CURB')
  TestTissue on TissueSet pass
  ElementAdded<String> on noGo

setZone('STADIUM-CURB'); publishTick
  tickIn
    dispatch Receptor: MapValue idle → Distinct may emit idle → Filter drop
    surge Receptor: Filter drop
    trips unchanged

setZone('DOWNTOWN'); publishTick
  dispatch Receptor: MapValue dispatch → Distinct emit → Filter pass
  observe DISPATCH
    trips.add(...)        → ElementAdded<TripEntry>
    pushQ.addLast(...)    → ElementAdded<PushJob>
  AsyncMapWithRetry → driver-app cell
```

Scenario 8 stops at `latIn.emit` / `lngIn.emit`. Tissue is idle.

Scenario 6 never decrements idle inside `matchOf`. The ACK observer
calls `accept`.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `matchOf` + Distinct + Filter | Receptor lock on dispatch / surge handle |
| `trips.add` | TissueList lock |
| `idleDrivers` write | TissueValue lock |
| `assignments[id] = ...` | TissueMap lock |
| driver-app Future | none of the above — `AsyncMapWithRetry` |

Do not “fix” a race by putting `trips.add` inside the Instruction.

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

## Acceptance (the demo is done when)

1. `dart run ride-hail-dispatch(tissue)-Demo.dart` prints every row
   in the scenario table with the **Result** column matched.
2. Grep shows exactly **two** `toHandle(` calls for the match gates,
   both inside `installGates`, none inside ACK.
3. `matchOf` has no `await`, no `idleDrivers` write, no `trips.add`.
4. Scenario 2 mutates `noGo` (TissueSet) **before** the closed-zone tick.
5. Scenario 8 prints TestCell rejection and does not append trips.
6. Scenario 9 shows a retry in `pushAttempts` and still **one**
   DISPATCH pulse after reset.
7. Accept/complete keep
   `idleDrivers.value! + assignments.length == 12` except during the
   forced-zero beat of scenario 11, which must restore before 12.
8. COMPLY shows the read-only deputy blocked on `add` and live on
   `length`.
9. File header diagram matches this document.
10. No Dart `List<TripEntry>` is the system of record.
11. Every Tissue constructor / `.deputy(` passes **`TestTissue`**
    (or omits the argument and takes `TestTissue.allowAll`).
    Grep must show **zero** `testRule: TestCell` on those calls.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `ride-hail-dispatch(tissue)-WalkThrough.md` |
| Demo to implement next | `ride-hail-dispatch(tissue)-Demo.dart` |
| Payments sibling (already written) | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Clinical sibling | `ICU-alarm-pipeline(enhanced)-WalkThrough.md` |

Ride-hail is the mobility lesson. Do not rename the card-auth or ICU
files. Optional later: `ride-hail-dispatch(enhanced)-WalkThrough.md`
as a Flow-only sibling (Dart `List` trip log) if you want the same
split you have for payments.
