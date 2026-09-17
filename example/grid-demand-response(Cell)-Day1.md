# Walkthrough requirement — grid demand-response (Cell variant)

**Demo:** `grid-demand-response(Cell)-Demo.dart` (executable; this file is its requirement)
**Siblings:**
- `grid-demand-response(tissue)-Demo.dart` — the Tissue-variant sibling
- `card-auth-pipeline(Cell)-Demo.dart` — payments (custom instruction template)
- `ride-hail-dispatch(tissue)-Demo.dart` — mobility
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical

**Industry:** electric power — transmission-desk demand response
(the thing grid operators actually do when system frequency sags:
shed interruptible load, protect hospitals, restore after the
operator ACK). Think ERCOT / National Grid / CAISO control room,
not a smart-thermostat app.
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for an energy-ops demo that
uses **one custom FlowInstruction** for the shed/warn decision and
**Tissue for the feeder books**. The custom instruction must extend
`FlowInstructionBase` the way `AsyncMap` does in
`packages/cell_flow/lib/src/instruction/async_map.dart`, encapsulate
the policy + distinct latch + hold filter, and expose a public API
(`policyOf`, `lastDecision`, `reset`) used when turning the
instruction into a Cell. The demo must also put the custom
instruction together with a stock `MapValue` into a
`FlowInstructionChain` (via `operator +`) before `toHandle`.

Do not fold Tissue into the instruction. Do not fold Flow into the
event log. The point of this file is the seam: the instruction
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
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | Hz 49.00–51.00, MW ≥ 0, SOC 0–100 |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only events, non-negative reserve MW, feeder ids |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for the reliability council |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

The custom instruction does **not** take a `TestCell` or a `TestTissue`
parameter. It takes the live protected `Set<String>` and the product
`Action` it must pass.

---

## Why one custom instruction + one chain

The Tissue sibling (`grid-demand-response(tissue)-Demo.dart`) builds
each gate from three ad-hoc pieces (`MapValue` + closure-Distinct +
`Filter`) with the latch state living in the harness. That works, but
the decision logic is scattered.

This variant compresses the essential logic into **one named
instruction**:

```dart
GridDecisionInstruction(protected: protected, pass: Action.shed)
```

and then composes it with a stock instruction:

```dart
final shedChain = shedGate + toAction;      // FlowInstructionChain
final shedHandle = shedChain.toHandle(source: tickIn.cell);
```

Why a chain at all, when the custom instruction already does the work?
Because the custom instruction emits the **rich** type `GridDecision`
(tick + action), and the seam type that observers consume is the
**narrow** `Action`. The stock `MapValue<GridDecision, Action>` is the
one-line projection that would otherwise pollute the custom
instruction. The `+` operator is the composition point: it builds a
`FlowInstructionChain` from the two instructions, and `toHandle`
materialises that chain into a single Cell.

---

## Design

```text
                         ┌─────────────────────────────────────────┐
                         │            GridDemandResponseHarness     │
                         │                                         │
  setHz/setLoad/setSoc ──► hzIn/loadIn/socIn (TestCell ingress)    │
  setArea/setFeeder ────► areaIn/feederIn (cache)                  │
                         │      │                                  │
                         │      ▼                                  │
                         │  publishTick() ──► tickIn (BayTick bus)  │
                         │      │                                  │
                         │      ├──► GridDecisionInstruction(shed)  │
                         │      │        + MapValue(GridDecision→Action)
                         │      │        └─► toHandle ──► shedCell  │
                         │      │                                  │
                         │      └──► GridDecisionInstruction(warn)  │
                         │               + MapValue(GridDecision→Action)
                         │               └─► toHandle ──► warnCell  │
                         │                                         │
                         │  Cell.observe(shedCell/warnCell)         │
                         │      │                                  │
                         │      ▼                                  │
                         │  events / rtuQ / reserveMw / shedMap     │
                         └─────────────────────────────────────────┘
```

Flow owns the decision (inside the instruction). Tissue owns the books
(behind the observers). The observer is the only glue.

---

## Domain

| Type | Kind | Meaning |
|---|---|---|
| `Action` | `enum` | `hold`, `warn`, `shed` — the only type crossing the Flow→Tissue seam |
| `BayTick` | `final class` | one complete snapshot: area, feeder, hz, loadMw, soc |
| `GridDecision` | `final class` | the instruction's rich output: tick + action |
| `GridEvent` | `final class` | one append-only row in the event log |
| `Shed` | `final class` | one open shed: feeder + droppedMw |
| `RtuJob` | `final class` | one outbound RTU job: feeder + action |

`GridDecision` exists because the instruction must expose its work
before the chain narrows it. If the instruction emitted `Action`
directly, the harness would have no public handle on the tick the
decision was computed from, and the chain's `MapValue` would have
nothing to project.

---

## Parts

### Flow Cells

| Cell | Input parameter(s) | Output (`Pulse<type>`) | TestCell |
|---|---|---|---|
| `hzIn` | `double` (49.00–51.00) | `Pulse<double>` | `_hzRange` |
| `loadIn` | `int` (≥ 0) | `Pulse<int>` | `_loadRange` |
| `socIn` | `int` (0–100) | `Pulse<int>` | `_socRange` |
| `areaIn` | `String` | `Pulse<String>` | none |
| `feederIn` | `String` | `Pulse<String>` | none |
| `tickIn` | `BayTick` | `Pulse<BayTick>` | none |
| `ackIn` | `String` (feeder id or `"ALL"`) | `Pulse<String>` | none |
| `shedCell` | — (materialised chain) | `Pulse<Action>` | `toHandle` default |
| `warnCell` | — (materialised chain) | `Pulse<Action>` | `toHandle` default |

### The custom instruction

`GridDecisionInstruction extends FlowInstructionBase<Cell, Pulse, Pulse>`
is the heart of this variant.

| API | Kind | Used by |
|---|---|---|
| `GridDecisionInstruction({required Set<String> protected, required Action pass})` | constructor | `installGates` |
| `static Action policyOf(BayTick tick, Set<String> protected)` | pure policy | the instruction itself; unit tests |
| `Action? get lastDecision` | latch state | the trailer |
| `Action get pass` | product | docs/debug |
| `Set<String> get protected` | live set | docs/debug |
| `void reset()` | latch clear | the ACK observer |

Internal order per pulse: type-check → `policyOf` → distinct latch →
product filter → emit `Pulse<GridDecision>`.

### Tissue collections

| Tissue | TestTissue | Rule |
|---|---|---|
| `events` | `TissueList<GridEvent>` | append-only: allow `add`/`addAll`, deny `remove`/`clear`/`[]=` |
| `reserveMw` | `TissueValue<int>` | value ≥ 0 |
| `shedMap` | `TissueMap<String, Shed>` | `droppedMw > 0` and non-empty feeder |
| `protected` | `TissueSet<String>` | uppercase `AREA-N` style |
| `rtuQ` | `TissueQueue<RtuJob>` | accepts every job (future rate-limit hook) |

### Deputies

| Deputy | TestTissue | Use |
|---|---|---|
| `events.unmodifiable` | built-in read-only view | the reliability council in COMPLY |

### Instruction

The demo uses **two** instruction objects in total, plus one shared
stock instruction:

1. `GridDecisionInstruction(protected: protected, pass: Action.shed)`
2. `GridDecisionInstruction(protected: protected, pass: Action.warn)`
3. `MapValue<GridDecision, Action>((d) => d.action)` — shared by both chains

Each `+` between (1) and (3), and (2) and (3), builds one
`FlowInstructionChain`. Two chains, two `toHandle` calls, two Cells.

### Receptor

`toHandle` wraps the chain in a `Receptor.instruction` and anchors it
in a `Nucleus` bound to `tickIn.cell`. The returned handle's `cell`
is the gate Cell the observers subscribe to.

### Operators the demo must actually call

| Operator | Where | Purpose |
|---|---|---|
| `Cell.ingress` | `install()` | 7 ingresses |
| `operator +` | `installGates()` | compose custom instruction + `MapValue` into a `FlowInstructionChain` |
| `FlowInstruction.toHandle` | `installGates()` | materialise each chain into a Cell |
| `Cell.observe` | `install()` | the only glue: gate Cell → Tissue writes |
| `TissueList.add` / `TissueValue.set` / `TissueMap[...]` / `TissueSet.add` / `TissueQueue.addLast` | writers | the books |

---

## Reserve — TissueValue + TissueMap (not inside the instruction)

`applyShed` and `restore` are **harness methods**, not instruction
logic. The instruction never touches MW. The v1 write protocol:

```text
applyShed(feeder, mw):
  1. pre-check reserveMw.value >= mw        (reject before any write)
  2. shedMap[feeder] = Shed(...)             (TissueMap write)
  3. reserveMw.set(before - mw)              (TissueValue write)
  4. on reject: shedMap.remove(feeder)       (compensate)

restore(feeder):
  1. look up shedMap[feeder]                 (no row → return false)
  2. shedMap.remove(feeder)
  3. reserveMw.set(before + droppedMw)
  4. events.add(RESTORE ...)
```

Invariant after every successful pair:

```text
reserveMw.value! + sum(shedMap.values.droppedMw) == 800
```

Scenario 11 deliberately breaks the invariant (force reserve to 30,
then attempt to shed 50) to prove the non-negative `TestTissue`
rejects the write; scenario 12 restores consistency (30 → 80).

---

## Implementation map

| WalkThrough part | Demo location |
|---|---|
| Domain types | `Action`, `BayTick`, `GridDecision`, `GridEvent`, `Shed`, `RtuJob` |
| Custom instruction | `GridDecisionInstruction` (extends `FlowInstructionBase`) |
| Chain composition | `GridDemandResponseHarness.installGates` (`+`, `toHandle`) |
| Ingress + TestCell | `install()` — `hzIn`/`loadIn`/`socIn`/`areaIn`/`feederIn`/`tickIn`/`ackIn` |
| Tissue + TestTissue | `install()` — `events`/`reserveMw`/`shedMap`/`protected`/`rtuQ` |
| Observers | `install()` — SHED/WARN/ACK `Cell.observe` |
| Reserve protocol | `applyShed` / `restore` |
| RTU pump | `_driveRtu` (retry-once over `_rtuWork`) |
| Scenarios | `main()` steps 1–13 + WARN + COMPLY |
| Acceptance console | `main()` trailer |

---

## Scenarios

| Banner | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | 50.00 / INT-14 / 420 / 60 | `events.isEmpty=true` | chain drops `hold`; initial Tissue is silent |
| 1 | repeat the same tick | `new sheds: 0` | distinct latch suppresses repeated `hold` |
| 2 | `protected.add('HOSP-1')`, 49.70 on HOSP-1 | `new sheds: 0` | live protected set feeds `policyOf` inside the instruction |
| 3 | 49.70 on INT-14 | `new sheds: 1`, `rtuQ.length=1` | `hold → shed` fires the SHED lane |
| 4 | 49.70 again | `new sheds: 0` | latch suppresses repeated `shed` |
| 5 | 49.72 (still shed band) | `new sheds: 0` | latch keys on `Action`, not Hz |
| WARN | 49.85 / SOC 10 / load 600 | `new warns: 1` | second lane, independent latch |
| 6 | 50.00 then ACK restore INT-14 | `reserveMw=800 openSheds=0` | ACK calls `reset()` + `restore()` |
| 7 | 49.70 on INT-14 | `new sheds: 1` | fresh shed after reset |
| 8 | Hz 48.0, load -10, SOC 101 | all `accepted=false`, `events grew: 0` | TestCell rejects at ingress |
| 9 | ACK, recover, 49.70, RTU fail-once | `new sheds: 1`, `rtuAttempts=5` | retry-once RTU pump |
| 10 | restore, ACK, 49.70 on INT-15 | `new sheds: 1`, `openSheds=1` | second feeder via TissueMap |
| 11 | force reserve to 30, then SHED 50 | `applyShed ok=false` | non-negative TestTissue rejects |
| 12 | restore INT-15 | `restore ok=true`, `reserveMw=80` | restore returns MW |
| 13 | ACK without an open shed | `unchanged=true` | ACK `"ALL"` invents no MW |
| COMPLY | council.add blocked | `council.length=19 events.length=19` | read-only deputy is live |
| Trailer | — | `ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6` | final counts agree |

---

## Executable steps

`main()` performs, in order:

1. Print the banner.
2. `final h = GridDemandResponseHarness(); await h.install();`
3. Seed the caches and `publishTick()`.
4. Scenarios 1–5 on the SHED lane.
5. WARN scenario on the WARN lane.
6. Scenarios 6–10 (ACK/restore/RTU/second feeder).
7. Scenarios 11–12 (reserve guard and restore).
8. Scenario 13 and COMPLY.
9. Trailer, then `h.dispose()`.

Each scenario prints the exact lines listed in the Demo header's
"Expected console output". The trailer adds one line the Tissue sibling
does not have:

```text
shedGate.lastDecision=null warnGate.lastDecision=null
```

which proves scenario 13's `ack('ALL')` cleared both instruction
latches through the public `reset()` API.

---

## Pulse path (scenario 2 then 3)

Scenario 2 — protected feeder:

```text
protected.add('HOSP-1')       → TissueSet write (TestTissue passes)
setFeeder('HOSP-1'), setHz(49.70)
publishTick()                 → tickIn emits Pulse<BayTick>(HOSP-1, 49.70)
shedGate instruction          → policyOf → protected contains HOSP-1 → hold
                              → latch hold, product filter drops hold
warnGate instruction          → same, own latch, drops hold
shedCell/warnCell             → no emission
```

Scenario 3 — unprotected feeder in the shed band:

```text
setFeeder('INT-14')
publishTick()                 → tickIn emits Pulse<BayTick>(INT-14, 49.70)
shedGate instruction          → policyOf → shed
                              → latch was hold, now shed → passes
                              → emits Pulse<GridDecision>(shed, INT-14)
MapValue<GridDecision,Action> → Pulse<Action>(shed)
shedCell                      → emits to the SHED observer
observer                      → events.add(SHED) + rtuQ + _driveRtu + applyShed
```

The WARN lane runs the same pulse through its own instruction: policy
returns `shed`, its latch records `shed`, and the product filter drops
it because `shed != warn`.

---

## Who owns the lock

| Domain | Lock | Covers | Does not cover |
|---|---|---|---|
| Decision | Receptor lock on `shedCell` / `warnCell` | instruction closure, latch, chain projection | any Tissue write |
| Books | Tissue lock on each collection | `events.add`, `shedMap[...]`, `reserveMw.set`, `rtuQ.addLast` | any decision logic |

A SHED pulse crosses two lock boundaries in sequence: the chain's
Receptor lock releases, then the observer takes the Tissue lock. The
latch state inside `GridDecisionInstruction` is a plain Dart field
guarded by the Receptor lock — it is not a Cell, not a Tissue, and not
a `Box`. That is why `reset()` works without rebuilding the graph.

---

## Real desk vs this file

| Real desk | This file |
|---|---|
| SCADA Hz stream | `setHz` + `publishTick` |
| Interruptible load programme | `shedMap` + `reserveMw` |
| Protected feeder register | `protected` TissueSet |
| Shift-lead ACK | `ackIn` + `shedGate.reset()` / `warnGate.reset()` |
| RTU (DNP3) | `_driveRtu` retry-once |
| Reliability council | `events.unmodifiable` |

---

## Acceptance

1. `dart analyze grid-demand-response(Cell)-Demo.dart` reports no issues.
2. `dart run grid-demand-response(Cell)-Demo.dart` prints the expected
   console exactly, including `shedGate.lastDecision=null`.
3. `GridDecisionInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`.
4. Two `toHandle` calls exist, both in `installGates`.
5. Grep shows zero `testRule: TestCell` on Tissue constructors.
6. The instruction contains no Tissue write; the observers contain no
   decision logic.

---

## Name plate

| Artifact | File |
|---|---|
| Requirement | `grid-demand-response(Cell)-WalkThrough.md` |
| Executable | `grid-demand-response(Cell)-Demo.dart` |
| Architecture | `grid-demand-response(Cell)-ARCHITECTURE.md` |
| Features | `grid-demand-response(Cell)-FEATURES.md` |
