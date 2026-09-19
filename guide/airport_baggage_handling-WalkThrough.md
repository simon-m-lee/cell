# Walkthrough requirement — airport baggage handling (Cell variant)

**Demo:** `airport-baggage-handling(Cell)-Demo.dart` (executable; this file is its requirement)

**Industry:** airport operations — baggage flow monitoring for departing bags
(the thing terminal duty managers actually do during the morning bank:
watch bags from check-in to aircraft hold, spot jams before they become
missed bags, keep an incident log the airline liaison can audit).
Think Heathrow T2 / Schiphol / Changi baggage control room, not a
passenger-facing bag-tracking app.

**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for an airport ops demo that
uses **one custom FlowInstruction** for the risk/warn decision and
**Tissue for the incident books**. The custom instruction must extend
`FlowInstructionBase` the way `AsyncMap` does in
`packages/cell_flow/lib/src/instruction/async_map.dart`, encapsulate
the policy + distinct latch + hold filter, and expose a public API
(`riskOf`, `lastDecision`, `reset`) used when turning the
instruction into a Cell. The demo must also put the custom
instruction together with a stock `MapValue` into a
`FlowInstructionChain` (via `operator +`) before `toHandle`.

Do not fold Tissue into the instruction. Do not fold Flow into the
incident log. The point of this file is the seam: the instruction
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
6. [Reserve — TissueValue + TissueMap](#reserve--tissuevalue--tissuemap-not-inside-the-instruction)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (scenario 2 then 3)](#pulse-path-scenario-2-then-3)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real desk vs this file](#real-desk-vs-this-file)
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
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | bag tag ≥ 10 chars, flight non-empty, weight 0–5000 g |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only incidents, non-negative bag count, belt codes |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for Safety & Compliance |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

The custom instruction does **not** take a `TestCell` or a `TestTissue`
parameter. It takes the live `guardedFlights` `Set<String>` and the
product `RiskLevel` it must pass.

---

## Why one custom instruction + one chain

The Tissue sibling builds each gate from three ad-hoc pieces
(`MapValue` + closure-Distinct + `Filter`) with the latch state living
in the harness. That works, but the decision logic is scattered.

This variant compresses the essential logic into **one named
instruction**:

```dart
BaggageRiskInstruction(guardedFlights: guardedFlights, pass: RiskLevel.atRisk)
```

and then composes it with a stock instruction:

```dart
final atRiskChain = riskGate + toRiskLevel;   // FlowInstructionChain
final atRiskHandle = atRiskChain.toHandle(source: tickIn.cell);
```

Why a chain at all, when the custom instruction already does the work?
Because the custom instruction emits the **rich** type `BaggageDecision`
(tick + risk level), and the seam type that observers consume is the
**narrow** `RiskLevel`. The stock `MapValue<BaggageDecision, RiskLevel>`
is the one-line projection that would otherwise pollute the custom
instruction. The `+` operator is the composition point: it builds a
`FlowInstructionChain` from the two instructions, and `toHandle`
materialises that chain into a single Cell.

---

## Design

```text
                         ┌─────────────────────────────────────────┐
                         │       AirportBaggageHarness             │
                         │                                         │
  setTag/setFlight/setPos► tagIn/flightIn/posIn (TestCell ingress) │
  setBelt/setWeight/setTerm► beltIn/weightIn/termIn (cache)         │
                         │      │                                  │
                         │      ▼                                  │
                         │  publishTick() ──► tickIn (BagTick bus)  │
                         │      │                                  │
                         │      ├──► BaggageRiskInstruction(atRisk) │
                         │      │        + MapValue(Decision→Risk)  │
                         │      │        └─► toHandle ──► atRiskCell│
                         │      │                                  │
                         │      └──► BaggageRiskInstruction(warn)   │
                         │               + MapValue(Decision→Risk)  │
                         │               └─► toHandle ──► warnCell │
                         │                                         │
                         │  Cell.observe(atRiskCell/warnCell)       │
                         │      │                                  │
                         │      ▼                                  │
                         │  events / alertQ / bagCount / incidentMap│
                         └─────────────────────────────────────────┘
```

Flow owns the decision (inside the instruction). Tissue owns the books
(behind the observers). The observer is the only glue.

---

## Domain

| Type | Kind | Meaning |
|---|---|---|
| `RiskLevel` | `enum` | `none`, `warn`, `atRisk` — the only type crossing the Flow→Tissue seam |
| `BagTick` | `final class` | one complete snapshot: tag, flight, position, belt, weightG, terminal, minRemaining |
| `BaggageDecision` | `final class` | the instruction's rich output: tick + riskLevel |
| `BaggageEvent` | `final class` | one append-only row in the incident log |
| `Incident` | `final class` | one open incident: belt + affectedBags + atRiskFlights |
| `AlertJob` | `final class` | one outbound supervisor alert job: belt + action |

`BaggageDecision` exists because the instruction must expose its work
before the chain narrows it. If the instruction emitted `RiskLevel`
directly, the harness would have no public handle on the tick the
decision was computed from, and the chain's `MapValue` would have
nothing to project.

---

## Parts

### Flow Cells

| Cell | Input parameter(s) | Output (`Pulse<type>`) | TestCell |
|---|---|---|---|
| `tagIn` | `String` (≥ 10 chars) | `Pulse<String>` | `_tagShape` |
| `flightIn` | `String` (non-empty) | `Pulse<String>` | `_flightShape` |
| `posIn` | `String` (non-empty) | `Pulse<String>` | none |
| `beltIn` | `String` | `Pulse<String>` | none |
| `weightIn` | `int` (0–5000 g) | `Pulse<int>` | `_weightRange` |
| `termIn` | `String` | `Pulse<String>` | none |
| `tickIn` | `BagTick` | `Pulse<BagTick>` | none |
| `ackIn` | `String` (belt id or `"ALL"`) | `Pulse<String>` | none |
| `atRiskCell` | — (materialised chain) | `Pulse<RiskLevel>` | `toHandle` default |
| `warnCell` | — (materialised chain) | `Pulse<RiskLevel>` | `toHandle` default |

### The custom instruction

`BaggageRiskInstruction extends FlowInstructionBase<Cell, Pulse, Pulse>`
is the heart of this variant.

| API | Kind | Used by |
|---|---|---|
| `BaggageRiskInstruction({required Set<String> guardedFlights, required RiskLevel pass})` | constructor | `installGates` |
| `static RiskLevel riskOf(BagTick tick, Set<String> guardedFlights)` | pure policy | the instruction itself; unit tests |
| `RiskLevel? get lastDecision` | latch state | the trailer |
| `RiskLevel get pass` | product | docs/debug |
| `Set<String> get guardedFlights` | live set | docs/debug |
| `void reset()` | latch clear | the ACK observer |

Internal order per pulse: type-check → `riskOf` → distinct latch →
product filter → emit `Pulse<BaggageDecision>`.

### Tissue collections

| Tissue | TestTissue | Rule |
|---|---|---|
| `events` | `TissueList<BaggageEvent>` | append-only: allow `add`/`addAll`, deny `remove`/`clear`/`[]=` |
| `bagCount` | `TissueValue<int>` | value ≥ 0 |
| `incidentMap` | `TissueMap<String, Incident>` | affectedBags > 0 and non-empty belt |
| `guardedFlights` | `TissueSet<String>` | uppercase `FLIGHT-N` style |
| `alertQ` | `TissueQueue<AlertJob>` | accepts every job (future rate-limit hook) |

### Deputies

| Deputy | TestTissue | Use |
|---|---|---|
| `events.unmodifiable` | built-in read-only view | Safety & Compliance in COMPLY |

### Instruction

The demo uses **two** instruction objects in total, plus one shared
stock instruction:

1. `BaggageRiskInstruction(guardedFlights: guardedFlights, pass: RiskLevel.atRisk)`
2. `BaggageRiskInstruction(guardedFlights: guardedFlights, pass: RiskLevel.warn)`
3. `MapValue<BaggageDecision, RiskLevel>((d) => d.riskLevel)` — shared by both chains

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

## Reserve — TissueValue + TissueMap (not inside the instruction)

`raiseAlert` and `closeIncident` are **harness methods**, not instruction
logic. The instruction never touches bag counts. The v1 write protocol:

```text
raiseAlert(belt, affectedBags, flightsAtRisk):
  1. pre-check bagCount.value >= affectedBags      (reject before any write)
  2. incidentMap[belt] = Incident(...)             (TissueMap write)
  3. bagCount.set(before - affectedBags)           (TissueValue write)
  4. on reject: incidentMap.remove(belt)           (compensate)

closeIncident(belt):
  1. look up incidentMap[belt]                     (no row → return false)
  2. incidentMap.remove(belt)
  3. bagCount.set(before + affectedBags)
  4. events.add(INCIDENT-CLOSE ...)
```

Invariant after every successful pair:

```text
bagCount.value! + sum(incidentMap.values.affectedBags) == 45000
```

Scenario 11 deliberately breaks the invariant (force bagCount to 10,
then attempt to raise 50) to prove the non-negative `TestTissue`
rejects the write; scenario 12 restores consistency (10 → 60).

---

## Implementation map

| WalkThrough part | Demo location |
|---|---|
| Domain types | `RiskLevel`, `BagTick`, `BaggageDecision`, `BaggageEvent`, `Incident`, `AlertJob` |
| Custom instruction | `BaggageRiskInstruction` (extends `FlowInstructionBase`) |
| Chain composition | `AirportBaggageHarness.installGates` (`+`, `toHandle`) |
| Ingress + TestCell | `install()` — `tagIn`/`flightIn`/`posIn`/`beltIn`/`weightIn`/`termIn`/`tickIn`/`ackIn` |
| Tissue + TestTissue | `install()` — `events`/`bagCount`/`incidentMap`/`guardedFlights`/`alertQ` |
| Observers | `install()` — AT-RISK/WARN/ACK `Cell.observe` |
| Reserve protocol | `raiseAlert` / `closeIncident` |
| Alert pump | `_driveAlert` (retry-once over `_alertWork`) |
| Scenarios | `main()` steps 1–13 + WARN + COMPLY |
| Acceptance console | `main()` trailer |

---

## Scenarios

| Banner | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | BA123 / INT-14 / 420 bags / 60 min | `events.isEmpty=true` | chain drops `none`; initial Tissue is silent |
| 1 | repeat the same tick | `new atRisk: 0` | distinct latch suppresses repeated `none` |
| 2 | `guardedFlights.add('VIP-1')`, 25 min on VIP-1 | `new atRisk: 0` | live guarded set feeds `riskOf` inside the instruction |
| 3 | 25 min on INT-14 | `new atRisk: 1`, `alertQ.length=1` | `none → atRisk` fires the AT-RISK lane |
| 4 | 25 min again | `new atRisk: 0` | latch suppresses repeated `atRisk` |
| 5 | 22 min (still at-risk band) | `new atRisk: 0` | latch keys on `RiskLevel`, not minutes |
| WARN | 35 min / belt JAM-3 / 200 bags | `new warns: 1` | second lane, independent latch |
| 6 | 60 min then ACK close INT-14 | `bagCount=45000 incidents=0` | ACK calls `reset()` + `closeIncident()` |
| 7 | 25 min on INT-14 | `new atRisk: 1` | fresh alert after reset |
| 8 | tag `"123"`, flight `""`, weight `6000` | all `accepted=false`, `events grew: 0` | TestCell rejects at ingress |
| 9 | ACK, recover, 25 min, alert fail-once | `new atRisk: 1`, `alertAttempts=5` | retry-once alert pump |
| 10 | close INT-14, ACK, 25 min on INT-15 | `new atRisk: 1`, `openIncidents=1` | second belt via TissueMap |
| 11 | force bagCount to 10, then raise 50 | `raiseAlert ok=false` | non-negative TestTissue rejects |
| 12 | close INT-15 | `closeIncident ok=true`, `bagCount=60` | close returns bags |
| 13 | ACK without an open incident | `unchanged=true` | ACK `"ALL"` invents no bags |
| COMPLY | council.add blocked | `council.length=19 events.length=19` | read-only deputy is live |
| Trailer | — | `ticks=12 atRisk=4 warns=1 events=19 alertAttempts=6` | final counts agree |

---

## Executable steps

`main()` performs, in order:

1. Print the banner.
2. `final h = AirportBaggageHarness(); await h.install();`
3. Seed the caches and `publishTick()`.
4. Scenarios 1–5 on the AT-RISK lane.
5. WARN scenario on the WARN lane.
6. Scenarios 6–10 (ACK/close/alert/second belt).
7. Scenarios 11–12 (bagCount guard and close).
8. Scenario 13 and COMPLY.
9. Trailer, then `h.dispose()`.

Each scenario prints the exact lines listed in the Demo header's
"Expected console output". The trailer adds one line the Tissue sibling
does not have:

```text
atRiskGate.lastDecision=null warnGate.lastDecision=null
```

which proves scenario 13's `ack('ALL')` cleared both instruction
latches through the public `reset()` API.

---

## Pulse path (scenario 2 then 3)

Scenario 2 — guarded flight:

```text
guardedFlights.add('VIP-1')   → TissueSet write (TestTissue passes)
setFlight('VIP-1'), setMinRemaining(25)
publishTick()                 → tickIn emits Pulse<BagTick>(VIP-1, 25)
atRiskGate instruction        → riskOf → guardedFlights contains VIP-1 → none
                              → latch none, product filter drops none
warnGate instruction          → same, own latch, drops none
atRiskCell/warnCell           → no emission
```

Scenario 3 — unguarded belt in the at-risk band:

```text
setFlight('INT-14')
publishTick()                 → tickIn emits Pulse<BagTick>(INT-14, 25)
atRiskGate instruction        → riskOf → atRisk
                              → latch was none, now atRisk → passes
                              → emits Pulse<BaggageDecision>(atRisk, INT-14)
MapValue<BaggageDecision,RiskLevel> → Pulse<RiskLevel>(atRisk)
atRiskCell                    → emits to the AT-RISK observer
observer                      → events.add(AT-RISK) + alertQ + _driveAlert + raiseAlert
```

The WARN lane runs the same pulse through its own instruction: policy
returns `atRisk`, its latch records `atRisk`, and the product filter
drops it because `atRisk != warn`.

---

## Who owns the lock

| Domain | Lock | Covers | Does not cover |
|---|---|---|---|
| Decision | Receptor lock on `atRiskCell` / `warnCell` | instruction closure, latch, chain projection | any Tissue write |
| Books | Tissue lock on each collection | `events.add`, `incidentMap[...]`, `bagCount.set`, `alertQ.addLast` | any decision logic |

An AT-RISK pulse crosses two lock boundaries in sequence: the chain's
Receptor lock releases, then the observer takes the Tissue lock. The
latch state inside `BaggageRiskInstruction` is a plain Dart field
guarded by the Receptor lock — it is not a Cell, not a Tissue, and not
a `Box`. That is why `reset()` works without rebuilding the graph.

---

## Real desk vs this file

| Real desk | This file |
|---|---|
| Belt control feed | `setPosition` + `publishTick` |
| Interruptible bag count | `incidentMap` + `bagCount` |
| Guarded flight register | `guardedFlights` TissueSet |
| Supervisor ACK | `ackIn` + `atRiskGate.reset()` / `warnGate.reset()` |
| Alert (radio/tablet) | `_driveAlert` retry-once |
| Safety & Compliance | `events.unmodifiable` |

---

## Acceptance

1. `dart analyze airport-baggage-handling(Cell)-Demo.dart` reports no issues.
2. `dart run airport-baggage-handling(Cell)-Demo.dart` prints the expected
   console exactly, including `atRiskGate.lastDecision=null`.
3. `BaggageRiskInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`.
4. Two `toHandle` calls exist, both in `installGates`.
5. Grep shows zero `testRule: TestCell` on Tissue constructors.
6. The instruction contains no Tissue write; the observers contain no
   decision logic.

---

## Name plate

| Artifact | File |
|---|---|
| Requirement | `airport-baggage-handling(Cell)-WalkThrough.md` |
| Executable | `airport-baggage-handling(Cell)-Demo.dart` |
| Architecture | `airport-baggage-handling(Cell)-ARCHITECTURE.md` |
| Features | `airport-baggage-handling(Cell)-FEATURES.md` |