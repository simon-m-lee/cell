# Walkthrough requirement — ride-hail dispatch (Cell variant)

**Demo:** `ride-hail-dispatch(Cell)-Demo.dart` (executable; this file is its requirement)
**Siblings:**
- `ride-hail-dispatch(tissue)-Demo.dart` — the Tissue-variant sibling
- `grid-demand-response(Cell)-Demo.dart` — energy (custom instruction template)
- `card-auth-pipeline(Cell)-Demo.dart` — payments
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical

**Industry:** ride-hailing / mobility dispatch (match a rider ping to a
driver, hold a surge banner, keep a trip ledger the city can audit)
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for a mobility demo that uses
**one custom FlowInstruction** for the match decision and **Tissue for
the fleet books**. The custom instruction must extend
`FlowInstructionBase` the way `AsyncMap` does in
`packages/cell_flow/lib/src/instruction/async_map.dart`, encapsulate
the policy + distinct latch + idle filter, and expose a public API
(`matchOf`, `lastDecision`, `reset`) used when turning the
instruction into a Cell. The demo must also put the custom
instruction together with a stock `MapValue` into a
`FlowInstructionChain` (via `operator +`) before `toHandle`.

Do not fold Tissue into the instruction. Do not fold Flow into the
trip log. The point of this file is the seam: the instruction
decides, the chain assembles, the observer glues.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why one custom instruction + one chain](#why-one-custom-instruction--one-chain)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
   - [Flow Cells](#flow-cells)
   - [The custom instruction](#the-custom-instruction)
   - [Tissue collections](#tissue-collections)
   - [Deputies](#deputies)
   - [Instruction](#instruction)
   - [Receptor](#receptor)
   - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [Fleet — TissueValue + TissueMap](#fleet--tissuevalue--tissuemap-not-inside-the-instruction)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (scenario 2 then 3)](#pulse-path-scenario-2-then-3)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real city vs this file](#real-city-vs-this-file)
13. [Acceptance](#acceptance)
14. [Name plate](#name-plate)

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

The custom instruction does **not** take a `TestCell` or a `TestTissue`
parameter. It takes the live no-go `Set<String>` and the product
`Match` it must pass.

---

## Why one custom instruction + one chain

The Tissue sibling (`ride-hail-dispatch(tissue)-Demo.dart`) builds
each gate from three ad-hoc pieces (`MapValue` + closure-Distinct +
`Filter`) with the latch state living in the harness. That works, but
the decision logic is scattered.

This variant compresses the essential logic into **one named
instruction**:

```dart
MatchDecisionInstruction(noGo: noGo, pass: Match.dispatch)
```

and then composes it with a stock instruction:

```dart
final dispatchChain = dispatchGate + toMatch;   // FlowInstructionChain
final dispatchHandle = dispatchChain.toHandle(source: tickIn.cell);
```

Why a chain at all, when the custom instruction already does the work?
Because the custom instruction emits the **rich** type `MatchDecision`
(tick + match), and the seam type that observers consume is the
**narrow** `Match`. The stock `MapValue<MatchDecision, Match>` is the
one-line projection that would otherwise pollute the custom
instruction. The `+` operator is the composition point: it builds a
`FlowInstructionChain` from the two instructions, and `toHandle`
materialises that chain into a single Cell.

---

## Design

```text
                         ┌─────────────────────────────────────────┐
                         │            RideHailDispatchHarness       │
                         │                                         │
  setLat/setLng/setWait ─► latIn/lngIn/waitIn (TestCell ingress)   │
  setSurge/setRider ────► surgeIn/riderIn (cache)                 │
  setZone/setNearby ────► zoneIn/nearbyIn (cache)                 │
                         │      │                                  │
                         │      ▼                                  │
                         │  publishTick() ──► tickIn (MatchTick bus)│
                         │      │                                  │
                         │      ├──► MatchDecisionInstruction(dispatch)
                         │      │        + MapValue(MatchDecision→Match)
                         │      │        └─► toHandle ──► dispatchCell
                         │      │                                  │
                         │      └──► MatchDecisionInstruction(surge)
                         │               + MapValue(MatchDecision→Match)
                         │               └─► toHandle ──► surgeCell│
                         │                                         │
                         │  Cell.observe(dispatchCell/surgeCell)    │
                         │      │                                  │
                         │      ▼                                  │
                         │  trips / pushQ / idleDrivers / assignments
                         └─────────────────────────────────────────┘
```

Flow owns the decision (inside the instruction). Tissue owns the books
(behind the observers). The observer is the only glue.

---

## Domain

| Type | Kind | Meaning |
|---|---|---|
| `Match` | `enum` | `idle`, `surge`, `dispatch` — the only type crossing the Flow→Tissue seam |
| `MatchTick` | `final class` | one complete snapshot: riderId, zone, lat, lng, waitSec, nearby, surgeX |
| `MatchDecision` | `final class` | the instruction's rich output: tick + match |
| `TripEntry` | `final class` | one append-only row in the trip ledger |
| `Assignment` | `final class` | one open driver→rider assignment |
| `PushJob` | `final class` | one outbound driver-app push job |

`MatchDecision` exists because the instruction must expose its work
before the chain narrows it. If the instruction emitted `Match`
directly, the harness would have no public handle on the tick the
decision was computed from, and the chain's `MapValue` would have
nothing to project.

---

## Parts

### Flow Cells

| Cell | Input parameter(s) | Output (`Pulse<type>`) | TestCell |
|---|---|---|---|
| `latIn` | `double` (−90.0…90.0) | `Pulse<double>` | `_latRange` |
| `lngIn` | `double` (−180.0…180.0) | `Pulse<double>` | `_lngRange` |
| `waitIn` | `int` (≥ 0) | `Pulse<int>` | `_waitRange` |
| `surgeIn` | `double` (1.0…5.0) | `Pulse<double>` | `_surgeRange` |
| `riderIn` | `String` | `Pulse<String>` | none |
| `zoneIn` | `String` | `Pulse<String>` | none |
| `nearbyIn` | `int` | `Pulse<int>` | none |
| `tickIn` | `MatchTick` | `Pulse<MatchTick>` | none |
| `ackIn` | `String` (driver id or `"CANCEL"`) | `Pulse<String>` | none |
| `dispatchCell` | — (materialised chain) | `Pulse<Match>` | `toHandle` default |
| `surgeCell` | — (materialised chain) | `Pulse<Match>` | `toHandle` default |

### The custom instruction

`MatchDecisionInstruction extends FlowInstructionBase<Cell, Pulse, Pulse>`
is the heart of this variant.

| API | Kind | Used by |
|---|---|---|
| `MatchDecisionInstruction({required Set<String> noGo, required Match pass})` | constructor | `installGates` |
| `static Match matchOf(MatchTick tick, Set<String> noGo)` | pure policy | the instruction itself; unit tests |
| `Match? get lastDecision` | latch state | the trailer |
| `Match get pass` | product | docs/debug |
| `Set<String> get noGo` | live set | docs/debug |
| `void reset()` | latch clear | the ACK observer |

Internal order per pulse: type-check → `matchOf` → distinct latch →
product filter → emit `Pulse<MatchDecision>`.

### Tissue collections

| Tissue | TestTissue | Rule |
|---|---|---|
| `trips` | `TissueList<TripEntry>` | append-only: allow `add`/`addAll`, deny `remove`/`clear`/`[]=` |
| `idleDrivers` | `TissueValue<int>` | value ≥ 0 |
| `assignments` | `TissueMap<String, Assignment>` | non-empty driver and rider ids |
| `noGo` | `TissueSet<String>` | uppercase string, length ≥ 3 |
| `pushQ` | `TissueQueue<PushJob>` | accepts every job (future rate-limit hook) |

### Deputies

| Deputy | TestTissue | Use |
|---|---|---|
| `trips.unmodifiable` | built-in read-only view | the city auditor in COMPLY |

### Instruction

The demo uses **two** custom instruction objects, plus one shared stock
instruction:

1. `MatchDecisionInstruction(noGo: noGo, pass: Match.dispatch)`
2. `MatchDecisionInstruction(noGo: noGo, pass: Match.surge)`
3. `MapValue<MatchDecision, Match>((d) => d.match)` — shared by both chains

Each `+` between (1) and (3), and (2) and (3), builds one
`FlowInstructionChain`. Two chains, two `toHandle` calls, two Cells.

### Receptor

`toHandle` wraps the chain in a `Receptor.instruction` and anchors it
in a `Nucleus` bound to `tickIn.cell`. The returned handle's `cell`
is the gate Cell the observers subscribe to.

### Operators the demo must actually call

| Operator | Where | Purpose |
|---|---|---|
| `Cell.ingress` | `install()` | 9 ingresses |
| `operator +` | `installGates()` | compose custom instruction + `MapValue` into a `FlowInstructionChain` |
| `FlowInstruction.toHandle` | `installGates()` | materialise each chain into a Cell |
| `Cell.observe` | `install()` | the only glue: gate Cell → Tissue writes |
| `TissueList.add` / `TissueValue.set` / `TissueMap[...]` / `TissueSet.add` / `TissueQueue.addLast` | writers | the books |

---

## Fleet — TissueValue + TissueMap (not inside the instruction)

`accept` and `complete` are **harness methods**, not instruction
logic. The instruction never touches drivers. The v1 write protocol:

```text
accept(driverId):
  1. pre-check idleDrivers.value > 0        (reject before any write)
  2. assignments[driverId] = Assignment(...) (TissueMap write)
  3. idleDrivers.set(before - 1)             (TissueValue write)
  4. on reject: assignments.remove(driverId) (compensate)

complete(driverId):
  1. look up assignments[driverId]           (no row → return false)
  2. assignments.remove(driverId)
  3. idleDrivers.set(before + 1)
  4. trips.add(COMPLETE ...)
```

Invariant after every successful pair:

```text
idleDrivers.value! + assignments.length == 12
```

Scenario 11 deliberately breaks the invariant (force idle to 0, then
attempt to accept) to prove the non-negative `TestTissue` rejects the
write; scenario 12 restores consistency (0 → 1).

---

## Implementation map

| WalkThrough part | Demo location |
|---|---|
| Domain types | `Match`, `MatchTick`, `MatchDecision`, `TripEntry`, `Assignment`, `PushJob` |
| Custom instruction | `MatchDecisionInstruction` (extends `FlowInstructionBase`) |
| Chain composition | `RideHailDispatchHarness.installGates` (`+`, `toHandle`) |
| Ingress + TestCell | `install()` — `latIn`/`lngIn`/`waitIn`/`surgeIn`/`riderIn`/`zoneIn`/`nearbyIn`/`tickIn`/`ackIn` |
| Tissue + TestTissue | `install()` — `trips`/`idleDrivers`/`assignments`/`noGo`/`pushQ` |
| Observers | `install()` — DISPATCH/SURGE/ACK `Cell.observe` |
| Fleet protocol | `accept` / `complete` |
| Push pump | `_drivePush` (retry-once over `_pushWork`) |
| Scenarios | `main()` seed + 13 scenarios + SURGE + COMPLY |
| Acceptance console | `main()` trailer |

---

## Scenarios

| Banner | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | DOWNTOWN / 3 nearby / wait 20 / surge 1.0 | `new dispatches: 1` | first DISPATCH on seed (explicit choice) |
| 1 | repeat same tick | `new dispatches: 0` | latch suppresses repeated `dispatch` |
| 2 | `noGo.add('STADIUM-CURB')`, tick there | `new dispatches: 0` | live no-go set feeds `matchOf` inside the instruction |
| 3 | back to DOWNTOWN | `new dispatches: 1` | `idle → dispatch` fires the DISPATCH lane |
| 4 | same downtown again | `new dispatches: 0` | latch suppresses repeated `dispatch` |
| 5 | wait 400 nearby 3 | `new dispatches: 0` | latch keys on `Match`, not wait |
| SURGE | nearby 0 wait 200 surge 2.1 | `new surges: 1` | second lane, independent latch |
| 6 | nearby 3 / surge 1.0 then ACK accept D-7 | `idle=11 assignments=1` | ACK calls `reset()` + `accept()` |
| 7 | new rider downtown nearby 3 | `new dispatches: 1` | fresh dispatch after reset |
| 8 | lat 91, lng 200, wait -1 | all `accepted=false`, `trips grew: 0` | TestCell rejects at ingress |
| 9 | ACK cancel, recover, downtown, push fail-once | `new dispatches: 1`, `pushAttempts=7` | retry-once push pump |
| 10 | accept D-8 on scenario 7 | `accept ok=true`, `idle=10 assignments=2` | second driver via TissueMap |
| 11 | force idle to 0, then accept D-9 | `accept ok=false` | non-negative TestTissue rejects |
| 12 | complete D-7 | `complete ok=true`, `idle=1 assignments=1` | complete returns driver to idle |
| 13 | unmatched CANCEL | `unchanged=true` | CANCEL invents nothing |
| COMPLY | auditor.add blocked | `auditor.length=17 trips.length=17` | read-only deputy is live |
| Trailer | — | `ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7` | final counts agree |

---

## Executable steps

`main()` performs, in order:

1. Print the banner.
2. `final h = RideHailDispatchHarness(); await h.install();`
3. Seed the caches and `publishTick()`.
4. Scenarios 1–5 on the DISPATCH lane.
5. SURGE scenario on the SURGE lane.
6. Scenarios 6–9 (ACK/accept/push retry).
7. Scenarios 10–12 (fleet protocol).
8. Scenario 13 and COMPLY.
9. Trailer, then `h.dispose()`.

Each scenario prints the exact lines listed in the Demo header's
"Expected console output". The trailer adds one line the Tissue sibling
does not have:

```text
dispatchGate.lastDecision=null surgeGate.lastDecision=null
```

which proves scenario 13's `ack('CANCEL')` cleared both instruction
latches through the public `reset()` API.

---

## Pulse path (scenario 2 then 3)

Scenario 2 — closed stand:

```text
noGo.add('STADIUM-CURB')      → TissueSet write (TestTissue passes)
setZone('STADIUM-CURB')
publishTick()                 → tickIn emits Pulse<MatchTick>(STADIUM-CURB)
dispatchGate instruction      → matchOf → noGo contains zone → idle
                              → latch idle, product filter drops idle
surgeGate instruction         → same, own latch, drops idle
dispatchCell/surgeCell        → no emission
```

Scenario 3 — back to DOWNTOWN:

```text
setZone('DOWNTOWN')
publishTick()                 → tickIn emits Pulse<MatchTick>(DOWNTOWN, nearby 3)
dispatchGate instruction      → matchOf → dispatch
                              → latch was idle, now dispatch → passes
                              → emits Pulse<MatchDecision>(dispatch, R-18)
MapValue<MatchDecision,Match> → Pulse<Match>(dispatch)
dispatchCell                  → emits to the DISPATCH observer
observer                      → trips.add(DISPATCH) + pushQ + _drivePush
```

The SURGE lane runs the same pulse through its own instruction: policy
returns `dispatch`, its latch records `dispatch`, and the product
filter drops it because `dispatch != surge`.

---

## Who owns the lock

| Domain | Lock | Covers | Does not cover |
|---|---|---|---|
| Decision | Receptor lock on `dispatchCell` / `surgeCell` | instruction closure, latch, chain projection | any Tissue write |
| Books | Tissue lock on each collection | `trips.add`, `assignments[...]`, `idleDrivers.set`, `pushQ.addLast` | any decision logic |

A DISPATCH pulse crosses two lock boundaries in sequence: the chain's
Receptor lock releases, then the observer takes the Tissue lock. The
latch state inside `MatchDecisionInstruction` is a plain Dart field
guarded by the Receptor lock — it is not a Cell, not a Tissue, and not
a `Box`. That is why `reset()` works without rebuilding the graph.

---

## Real city vs this file

| Real city | This file |
|---|---|
| GPS stream | `setLat` / `setLng` + `publishTick` |
| Driver inventory | `idleDrivers` + `assignments` |
| Closed stands / no-go zones | `noGo` TissueSet |
| Driver ACK | `ackIn` + `dispatchGate.reset()` / `surgeGate.reset()` |
| Push gateway (FCM/APNs) | `_drivePush` retry-once |
| City auditor | `trips.unmodifiable` |

---

## Acceptance

1. `dart analyze ride-hail-dispatch(Cell)-Demo.dart` reports no issues.
2. `dart run ride-hail-dispatch(Cell)-Demo.dart` prints the expected
   console exactly, including `dispatchGate.lastDecision=null`.
3. `MatchDecisionInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`.
4. Two `toHandle` calls exist, both in `installGates`.
5. Grep shows zero `testRule: TestCell` on Tissue constructors.
6. The instruction contains no Tissue write; the observers contain no
   decision logic.

---

## Name plate

| Artifact | File |
|---|---|
| Requirement | `ride-hail-dispatch(Cell)-WalkThrough.md` |
| Executable | `ride-hail-dispatch(Cell)-Demo.dart` |
| Architecture | `ride-hail-dispatch(Cell)-ARCHITECTURE.md` |
| Features | `ride-hail-dispatch(Cell)-FEATURES.md` |
