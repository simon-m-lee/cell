# Features — grid demand-response (Cell variant)

**Companion to:** `grid-demand-response(Cell)-Demo.dart`
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
   - [Reserve protocol](#17-reserve-protocol)
   - [RTU pump](#18-rtu-pump)
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
| Single instruction per lane | `GridDecisionInstruction` | Extends `FlowInstructionBase<Cell, Pulse, Pulse>`, like `AsyncMap` |
| Encapsulated policy | `policyOf` | static, pure, clause-ordered; reads only `BayTick` + protected set |
| Encapsulated latch | `_GridGateState` | distinct-until-changed on `Action` |
| Encapsulated hold filter | product filter | `action != pass` drops the pulse |
| Rich emission | `Pulse<GridDecision>` | carries tick + action before the chain narrows it |
| Public API | `policyOf` / `lastDecision` / `reset` / `pass` / `protected` | used when turning the instruction into a Cell |
| Two instances, two latches | `shedGate` / `warnGate` | independent SHED and WARN suppression |

### 1.2 FlowInstructionChain composition

| Feature | Where | Behaviour |
|---|---|---|
| `operator +` composition | `installGates` | `GridDecisionInstruction + MapValue` builds one `FlowInstructionChain` |
| Stock instruction reuse | `toAction` | one `MapValue<GridDecision, Action>` shared by both lanes |
| Materialisation | `toHandle(source: tickIn.cell)` | chain becomes a Cell; two `toHandle` calls total |
| No rebuild on ACK | ACK observer | calls `reset()`, never `toHandle` again |

### 1.3 Sensor ingress (TestCell)

| Feature | Where | Behaviour |
|---|---|---|
| Hz shape validation | `_hzRange` on `hzIn` | rejects < 49.00 or > 51.00; coerces `num` to double |
| Load shape validation | `_loadRange` on `loadIn` | rejects negative MW; requires `int` |
| SOC shape validation | `_socRange` on `socIn` | rejects < 0 or > 100; requires `int` |
| Pulse unwrapping | every `TestCell` rule | rule reads `Pulse.payload`, not the wrapper |
| Cache-on-accept | `setHz` / `setLoad` / `setSoc` | rejected values do not overwrite the cache |
| Pre-flight guards | `publishTick` | re-checks shape before emitting, so scenario 8 can report without publishing |
| Zero-delay drain | `publishTick` / `ack` | awaits `Duration.zero` so the observer chain drains |
| Hz formatting | `_fmtHz` | pins Hz to two decimals |

### 1.4 Decision policy

| Feature | Where | Behaviour |
|---|---|---|
| Pure action evaluation | `GridDecisionInstruction.policyOf` | no `await`, no I/O, no state, no MW writes |
| Protected feeder hold | first clause | `t.feeder in protected` → `hold` before any frequency check |
| Shed band | second clause | `Hz < 49.80` → `shed` |
| Warn band (frequency) | third clause | `49.80 ≤ Hz < 49.90` → `warn` |
| Warn band (SOC/load) | fourth clause | `SOC < 15` and `load > 500` → `warn` |
| Default hold | final clause | everything else → `hold` |
| Ordering guarantee | clause order | a protected feeder is never shed, even in the shed band |

### 1.5 Distinct latches

| Feature | Where | Behaviour |
|---|---|---|
| Per-lane latches | `_GridGateState` per instance | a WARN does not clear the SHED latch and vice versa |
| Distinct-before-filter | instruction order | `hold → shed → hold → shed` fires twice |
| Latch captures every action | instruction order | including `hold` and the other lane's product |
| ACK reset | `GridDecisionInstruction.reset` | clears the latch without rebuilding the graph |
| Public read-back | `lastDecision` | trailer prints `null` after scenario 13's ACK |

### 1.6 Books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Append-only event log | `_eventAppendOnly` on `events` | `add`/`addAll` allowed; `remove`/`clear`/`[]=` denied |
| Non-negative reserve | `_nonNegativeMw` on `reserveMw` | any write that would go negative is rejected |
| Shed shape validation | `_shedRule` on `shedMap` | `droppedMw > 0` and non-empty feeder id |
| Protected feeder shape | `_protectedRule` on `protected` | uppercase `AREA-N` string |
| Bounded RTU queue | `rtuQ` with `capacity: 32` | overflow drops oldest |
| Initial population is silent | every Tissue | seed does not append to `events` |
| Cache of last tick | `_currentTick` | observers correlate the decision with feeder and Hz |

### 1.7 Reserve protocol

| Feature | Where | Behaviour |
|---|---|---|
| NSF pre-check | `applyShed` | rejects before writing the map row |
| Compensating write | `applyShed` | map row removed if the reserve write rejects |
| Restore-by-feeder | `restore` | looks up by feeder id; returns MW to the pool |
| No-op restore | `restore` returns `false` | ACK `"ALL"` does not invent MW |
| Reserve invariant | trailer | `reserve + sum(dropped) == 800`, documented break in §11/§12 |
| Fixed shed MW | `shedMw = 50` | keeps arithmetic simple |

### 1.8 RTU pump

| Feature | Where | Behaviour |
|---|---|---|
| Single-shot retry | `_driveRtu` | retries once on failure |
| Retry counter | `rtuAttempts` | counts both attempts |
| Fail-once injection | `rtuFailOnce` | scenario 9 flips it on |
| Audit-side enqueue | `rtuQ.addLast` | every job appears as `ElementAdded<RtuJob>` |
| Working list | `_rtuWork` | drives the pump (this build does not drain `TissueQueue`) |
| Both lanes enqueue | SHED and WARN observers | every SHED and WARN enqueues an RTU job |

### 1.9 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Live read-only view | `events.unmodifiable` | zero-copy projection |
| Write block | COMPLY scenario | `council.add` does not grow `events` |
| Length parity | COMPLY scenario | `council.length == events.length` after the attempted write |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | chain drops `hold`; silent initial population | `events.isEmpty=true` |
| 1 | latch suppresses repeated `hold` | `new sheds: 0` |
| 2 | live protected set feeds `policyOf` | `[protected] +HOSP-1`, `new sheds: 0` |
| 3 | `hold → shed` fires SHED lane | `new sheds: 1` |
| 4 | latch suppresses repeated `shed` | `new sheds: 0` |
| 5 | latch keys on `Action`, not Hz | `new sheds: 0` |
| WARN | second lane, independent latch | `new warns: 1` |
| 6 | ACK calls `reset()` + `restore()` | `reserveMw=800 openSheds=0` |
| 7 | fresh shed after reset | `new sheds: 1` |
| 8 | TestCell rejects at ingress | `accepted=false` ×3, `events grew: 0` |
| 9 | RTU retry-once | `new sheds: 1`, `rtuAttempts=5` |
| 10 | second feeder via TissueMap | `new sheds: 1`, `openSheds=1` |
| 11 | non-negative TestTissue rejects | `applyShed ok=false` |
| 12 | restore returns MW | `restore ok=true`, `reserveMw=80` |
| 13 | ACK `"ALL"` invents no MW | `unchanged=true` |
| COMPLY | read-only deputy is live | `council.length=19 events.length=19` |
| Trailer | final counts | `ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6` |

---

## 3. What the demo does not do (deliberately)

- **No async policy** — `policyOf` is synchronous. A real desk would
  add telemetry latency, but this demo keeps the instruction pure.
- **No variable shed MW** — every shed drops 50 MW. Real dispatch sizes
  the shed from `Δf × droop × load`.
- **No multi-area routing** — `area` is carried but not routed.
- **No persistent ledger** — Tissue collections are in-memory.
- **No joint-commit transaction** — the v1 compensate protocol stands
  in until `Cell.transaction` is available across the three money
  writes.
- **No third product lane** — the instruction class supports it; the
  demo exercises only SHED and WARN.

---

## 4. Operator cheat sheet

| You want to | Call / read |
|---|---|
| Publish a grid tick | `setHz` / `setLoad` / `setSoc` / `setFeeder` then `await publishTick()` |
| Protect a feeder | `h.protected.add('HOSP-1')` |
| Acknowledge / restore | `await h.ack('INT-14')` (named) or `await h.ack('ALL')` (latch only) |
| Read the reserve | `h.reserveMw.value` |
| Count open sheds | `h.openShedsCount` |
| Read the decision latch | `h.shedGate.lastDecision` / `h.warnGate.lastDecision` |
| Read the audit log | `h.events.unmodifiable` (read-only) |

---

## 5. Acceptance checklist

1. `dart analyze grid-demand-response(Cell)-Demo.dart` — no issues.
2. `dart run grid-demand-response(Cell)-Demo.dart` — prints the
   expected console exactly.
3. `GridDecisionInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`.
4. Two `toHandle` calls, both in `installGates`.
5. Two `GridDecisionInstruction` instances with independent latches.
6. Zero `testRule: TestCell` on Tissue constructors.
7. Zero Tissue writes inside `GridDecisionInstruction`.
8. Zero decision logic inside the observers.
9. Trailer prints `shedGate.lastDecision=null warnGate.lastDecision=null`
   after scenario 13.

---

## 6. See also

- `grid-demand-response(Cell)-WalkThrough.md` — the requirement.
- `grid-demand-response(Cell)-ARCHITECTURE.md` — layering and locking.
- `grid-demand-response(tissue)-Demo.dart` — the Tissue-variant sibling.
- `card-auth-pipeline(Cell)-Demo.dart` — the custom-instruction template.
