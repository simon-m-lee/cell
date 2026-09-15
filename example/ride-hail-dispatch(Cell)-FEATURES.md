# Features — ride-hail dispatch (Cell variant)

**Companion to:** `ride-hail-dispatch(Cell)-Demo.dart`
**Audience:** operators and reviewers evaluating what the demo
demonstrates and what it deliberately leaves out.

---

## Contents

1. [Feature catalogue](#1-feature-catalogue)
   - [Custom FlowInstruction](#11-custom-flowinstruction)
   - [FlowInstructionChain composition](#12-flowinstructionchain-composition)
   - [Sensor ingress (TestCell)](#13-sensor-ingress-testcell)
   - [Decision policy](#14-decision-policy)
   - [Distinct latches](#15-distinct-latches)
   - [Books (Tissue)](#16-books-tissue)
   - [Fleet protocol](#17-fleet-protocol)
   - [Push pump](#18-push-pump)
   - [Compliance deputy](#19-compliance-deputy)
2. [Scenario catalogue](#2-scenario-catalogue)
3. [What the demo does not do (deliberately)](#3-what-the-demo-does-not-do-deliberately)
4. [Operator cheat sheet](#4-operator-cheat-sheet)
5. [Acceptance checklist](#5-acceptance-checklist)
6. [See also](#6-see-also)

---

## 1. Feature catalogue

### 1.1 Custom FlowInstruction

| Feature | Where | Behaviour |
|---|---|---|
| Single instruction per lane | `MatchDecisionInstruction` | Extends `FlowInstructionBase<Cell, Pulse, Pulse>`, like `AsyncMap` |
| Encapsulated policy | `matchOf` | static, pure, clause-ordered; reads only `MatchTick` + no-go set |
| Encapsulated latch | `_MatchGateState` | distinct-until-changed on `Match` |
| Encapsulated idle filter | product filter | `match != pass` drops the pulse |
| Rich emission | `Pulse<MatchDecision>` | carries tick + match before the chain narrows it |
| Public API | `matchOf` / `lastDecision` / `reset` / `pass` / `noGo` | used when turning the instruction into a Cell |
| Two instances, two latches | `dispatchGate` / `surgeGate` | independent DISPATCH and SURGE suppression |

### 1.2 FlowInstructionChain composition

| Feature | Where | Behaviour |
|---|---|---|
| `operator +` composition | `installGates` | `MatchDecisionInstruction + MapValue` builds one `FlowInstructionChain` |
| Stock instruction reuse | `toMatch` | one `MapValue<MatchDecision, Match>` shared by both lanes |
| Materialisation | `toHandle(source: tickIn.cell)` | chain becomes a Cell; two `toHandle` calls total |
| No rebuild on ACK | ACK observer | calls `reset()`, never `toHandle` again |

### 1.3 Sensor ingress (TestCell)

| Feature | Where | Behaviour |
|---|---|---|
| Latitude shape validation | `_latRange` on `latIn` | rejects outside −90…90; coerces `num` to double |
| Longitude shape validation | `_lngRange` on `lngIn` | rejects outside −180…180 |
| Wait shape validation | `_waitRange` on `waitIn` | rejects negative; requires `int` |
| Surge shape validation | `_surgeRange` on `surgeIn` | rejects outside 1.0…5.0 |
| Pulse unwrapping | every `TestCell` rule | rule reads `Pulse.payload`, not the wrapper |
| Cache-on-accept | `setLat` / `setLng` / `setWait` / `setSurge` | rejected values do not overwrite the cache |
| Pre-flight guards | `publishTick` | re-checks shape before emitting, so scenario 8 can report without publishing |
| Zero-delay drain | `publishTick` / `ack` | awaits `Duration.zero` so the observer chain drains |

### 1.4 Decision policy

| Feature | Where | Behaviour |
|---|---|---|
| Pure match evaluation | `MatchDecisionInstruction.matchOf` | no `await`, no I/O, no state, no driver writes |
| No-go zone hold | first clause | `t.zone in noGo` → `idle` before any nearby check |
| Long-wait surge | second clause | `nearby == 0` and `wait >= 180` → `surge` |
| High-multiplier surge | third clause | `surgeX >= 1.8` → `surge` |
| Dispatch | fourth clause | `nearby >= 1` → `dispatch` |
| Default idle | final clause | everything else → `idle` |
| Ordering guarantee | clause order | a closed stand is never dispatched, even with drivers nearby |

### 1.5 Distinct latches

| Feature | Where | Behaviour |
|---|---|---|
| Per-lane latches | `_MatchGateState` per instance | a SURGE does not clear the DISPATCH latch and vice versa |
| Distinct-before-filter | instruction order | `dispatch → idle → dispatch` fires twice |
| Latch captures every match | instruction order | including `idle` and the other lane's product |
| ACK reset | `MatchDecisionInstruction.reset` | clears the latch without rebuilding the graph |
| Public read-back | `lastDecision` | trailer prints `null` after scenario 13's CANCEL |

### 1.6 Books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Append-only trip ledger | `_tripAppendOnly` on `trips` | `add`/`addAll` allowed; `remove`/`clear`/`[]=` denied |
| Non-negative idle count | `_nonNegativeInt` on `idleDrivers` | any write that would go negative is rejected |
| Assignment shape | `_assignmentRule` on `assignments` | non-empty driver and rider ids |
| No-go zone shape | `_noGoRule` on `noGo` | uppercase string, length ≥ 3 |
| Bounded push queue | `pushQ` with `capacity: 32` | overflow drops oldest |
| Initial population is silent | every Tissue | seed does not append to `trips` |
| Cache of last tick | `_currentTick` | observers correlate the decision with rider and zone |

### 1.7 Fleet protocol

| Feature | Where | Behaviour |
|---|---|---|
| Over-assignment pre-check | `accept` | rejects before writing the map row |
| Compensating write | `accept` | map row removed if the idle write rejects |
| Complete-by-driver | `complete` | looks up by driver id; returns the driver to idle |
| No-op complete | `complete` returns `false` | ACK `"CANCEL"` does not invent drivers |
| Fleet invariant | trailer | `idle + assignments == 12`, documented break in §11/§12 |

### 1.8 Push pump

| Feature | Where | Behaviour |
|---|---|---|
| Single-shot retry | `_drivePush` | retries once on failure |
| Retry counter | `pushAttempts` | counts both attempts |
| Fail-once injection | `pushFailOnce` | scenario 9 flips it on |
| Audit-side enqueue | `pushQ.addLast` | every job appears as `ElementAdded<PushJob>` |
| Working list | `_pushWork` | drives the pump (this build does not drain `TissueQueue`) |
| Both lanes enqueue | DISPATCH and SURGE observers | every DISPATCH and SURGE enqueues a push job |

### 1.9 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Live read-only view | `trips.unmodifiable` | zero-copy projection |
| Write block | COMPLY scenario | `auditor.add` does not grow `trips` |
| Length parity | COMPLY scenario | `auditor.length == trips.length` after the attempted write |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | first DISPATCH on seed | `new dispatches: 1` |
| 1 | latch suppresses repeated `dispatch` | `new dispatches: 0` |
| 2 | live no-go set feeds `matchOf` | `[noGo] +STADIUM-CURB`, `new dispatches: 0` |
| 3 | `idle → dispatch` fires DISPATCH lane | `new dispatches: 1` |
| 4 | latch suppresses repeated `dispatch` | `new dispatches: 0` |
| 5 | latch keys on `Match`, not wait | `new dispatches: 0` |
| SURGE | second lane, independent latch | `new surges: 1` |
| 6 | ACK calls `reset()` + `accept()` | `idle=11 assignments=1` |
| 7 | fresh dispatch after reset | `new dispatches: 1` |
| 8 | TestCell rejects at ingress | `accepted=false` ×3, `trips grew: 0` |
| 9 | push retry-once | `new dispatches: 1`, `pushAttempts=7` |
| 10 | second driver via TissueMap | `accept ok=true`, `idle=10 assignments=2` |
| 11 | non-negative TestTissue rejects | `accept ok=false` |
| 12 | complete returns driver to idle | `complete ok=true`, `idle=1 assignments=1` |
| 13 | CANCEL invents nothing | `unchanged=true` |
| COMPLY | read-only deputy is live | `auditor.length=17 trips.length=17` |
| Trailer | final counts | `ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7` |

---

## 3. What the demo does not do (deliberately)

- **No spatial index** — `nearby` is a cached integer, not a geospatial
  query.
- **No dynamic surge pricing** — the multiplier is an input, not a
  computed price.
- **No multi-zone routing** — `zone` is carried but not routed.
- **No persistent ledger** — Tissue collections are in-memory.
- **No joint-commit transaction** — the v1 compensate protocol stands
  in until `Cell.transaction` is available across the three fleet
  writes.
- **No third product lane** — the instruction class supports it; the
  demo exercises only DISPATCH and SURGE.

---

## 4. Operator cheat sheet

| You want to | Call / read |
|---|---|
| Publish a rider tick | `setLat` / `setLng` / `setWait` / `setSurge` / `setRider` / `setZone` / `setNearby` then `await publishTick()` |
| Close a stand | `h.noGo.add('STADIUM-CURB')` |
| Acknowledge / accept | `await h.ack('D-7')` (named driver) or `await h.ack('CANCEL')` (latch only) |
| Read the idle count | `h.idleDrivers.value` |
| Count open assignments | `h.assignmentCount` |
| Read the decision latch | `h.dispatchGate.lastDecision` / `h.surgeGate.lastDecision` |
| Read the audit log | `h.trips.unmodifiable` (read-only) |

---

## 5. Acceptance checklist

1. `dart analyze ride-hail-dispatch(Cell)-Demo.dart` — no issues.
2. `dart run ride-hail-dispatch(Cell)-Demo.dart` — prints the
   expected console exactly.
3. `MatchDecisionInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`.
4. Two `toHandle` calls, both in `installGates`.
5. Two `MatchDecisionInstruction` instances with independent latches.
6. Zero `testRule: TestCell` on Tissue constructors.
7. Zero Tissue writes inside `MatchDecisionInstruction`.
8. Zero decision logic inside the observers.
9. Trailer prints
   `dispatchGate.lastDecision=null surgeGate.lastDecision=null` after
   scenario 13.

---

## 6. See also

- `ride-hail-dispatch(Cell)-WalkThrough.md` — the requirement.
- `ride-hail-dispatch(Cell)-ARCHITECTURE.md` — layering and locking.
- `ride-hail-dispatch(tissue)-Demo.dart` — the Tissue-variant sibling.
- `grid-demand-response(Cell)-Demo.dart` — the energy custom-instruction sibling.
