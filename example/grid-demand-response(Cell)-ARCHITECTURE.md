# Architecture — grid demand-response (Cell variant)

**Companion to:** `grid-demand-response(Cell)-Demo.dart`
**Audience:** engineers extending the demo, and readers comparing it
with `grid-demand-response(tissue)-ARCHITECTURE.md`.

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

The Cell variant compresses the demand-response decision into a single
`GridDecisionInstruction` that extends `FlowInstructionBase` the way
`AsyncMap` does — policy, distinct-until-changed latch, and hold
filter all live inside the instruction and are reached through a
public API (`policyOf`, `lastDecision`, `reset`). The harness then
puts that instruction together with one stock `MapValue` using
`operator +`, which builds a `FlowInstructionChain`, and materialises
the chain into a Cell with `toHandle`. Tissue remains untouched by the
instruction: the SHED/WARN/ACK observers are the only glue between the
decision Cells and the feeder books.

---

## 2. Layering

```text
┌────────────────────────────────────────────────────────────────┐
│ Scenario driver (main)                                          │
│   setHz/setLoad/setSoc/setFeeder · publishTick · ack · applyShed│
└───────────────┬────────────────────────────────────────────────┘
                │
┌───────────────▼────────────────────────────────────────────────┐
│ Flow (package:cell_flow)                                        │
│   GridDecisionInstruction  ── encapsulated decision             │
│        + MapValue          ── chain projection                  │
│        = FlowInstructionChain                                   │
│        .toHandle(source: tickIn.cell)                           │
│             └─► shedCell / warnCell (Cells)                     │
└───────────────┬────────────────────────────────────────────────┘
                │  Cell.observe (the only glue)
┌───────────────▼────────────────────────────────────────────────┐
│ Tissue (package:cell_tissue)                                    │
│   events (append-only) · reserveMw (non-negative)               │
│   shedMap · protected · rtuQ (bounded)                          │
└────────────────────────────────────────────────────────────────┘
```

Two rules keep the layers honest:

1. The instruction may read `protected` but may write **no Tissue**.
2. The observers may write Tissue but may perform **no decision
   logic** — they only react to the `Action` the chain already chose.

---

## 3. Ownership matrix

| Concern | Owner | Notes |
|---|---|---|
| Hz / load / SOC shape | `TestCell` on `hzIn` / `loadIn` / `socIn` | reject at the edge |
| Tick snapshot | `publishTick` | the only `BayTick` factory |
| Decision policy | `GridDecisionInstruction.policyOf` | static, pure, clause-ordered |
| Distinct latch | `_GridGateState` inside the instruction | one latch per lane instance |
| Hold suppression | `GridDecisionInstruction` product filter | `action != pass` drops |
| Chain assembly | `installGates` | two `+` compositions, two `toHandle` |
| Latch reset | `GridDecisionInstruction.reset` | called only by the ACK observer |
| Event log integrity | `_eventAppendOnly` TestTissue | add-only |
| Reserve integrity | `_nonNegativeMw` TestTissue | value ≥ 0 |
| Shed shape | `_shedRule` TestTissue | droppedMw > 0 |
| Protected set | `_protectedRule` TestTissue | uppercase AREA-N |
| RTU retry | `_driveRtu` | single-shot retry |

---

## 4. Locking

| Domain | Lock | Covers | Does not cover |
|---|---|---|---|
| Decision | Receptor lock on `shedCell` / `warnCell` | instruction closure, latch, `MapValue` projection | any Tissue write |
| Books | Tissue lock on each collection | `events.add`, `shedMap[...]`, `reserveMw.set`, `rtuQ.addLast` | any decision logic |

A SHED pulse crosses two lock boundaries in sequence: the chain's
Receptor lock releases, then the observer takes the Tissue lock. The
latch inside `GridDecisionInstruction` is a plain Dart field guarded
by the Receptor lock; it is deliberately **not** a Cell or a Tissue,
so `reset()` is a synchronous assignment, not a graph rebuild.

The two lanes have independent latches by construction — two instances
of `GridDecisionInstruction`, each with its own `_GridGateState`. A
WARN does not clear the SHED latch and vice versa.

---

## 5. Failure semantics

| Failure | Behaviour |
|---|---|
| Hz / load / SOC out of shape | `Cell.ingress` rejects; cache keeps the last accepted value; `publishTick` refuses to publish |
| Repeated action | instruction latch drops the pulse before it reaches the chain's `MapValue` |
| Protected feeder in shed band | `policyOf` returns `hold` before any frequency check |
| RTU transient failure | `_driveRtu` retries once; both attempts count in `rtuAttempts` |
| Reserve insufficient | `applyShed` pre-checks and returns `false` before writing |
| Reserve write rejected | `applyShed` compensates by removing the map row |
| Restore without open shed | `restore` returns `false`; ACK `"ALL"` invents no MW |
| Council write attempt | `events.unmodifiable` blocks; COMPLY checks length parity |

The demo deliberately breaks the reserve invariant once (scenario 11)
to prove the `TestTissue` guard fires, then restores consistency in
scenario 12.

---

## 6. Extending the demo

### 6.1 A third product lane

Add `Action.review` to the enum, then:

1. `policyOf` gains a clause producing `Action.review`.
2. Create a third `GridDecisionInstruction(protected: …,
   pass: Action.review)`.
3. Chain it with the same shared `MapValue<GridDecision, Action>`.
4. Add the observer and counter.

The instruction class is unchanged — only the enum, the policy, and
the wiring change. That is the payoff of encapsulating the lane logic
in one instruction.

### 6.2 Policy variant without redeploying the graph

Because the instruction reads the live `protected` set, protecting a
new feeder is a Tissue write (`protected.add(...)`), not a graph
rebuild. The policy itself is static; changing the *bands* requires a
new instruction instance, which is the documented trade-off.

### 6.3 A single chain for both products

`GridDecisionInstruction` is parameterised by `pass`. A one-chain
variant could drop the `pass` parameter and emit every non-hold
decision, with the observers branching on `action`. That is a
legitimate alternative; this demo keeps two lanes so the independent
latches are visible.

### 6.4 `Cell.transaction` across the money writes

When the running `cell_tissue` build exposes a joint commit across
`TissueValue` + `TissueMap` + `TissueList`, replace the v1
try/compensate in `applyShed` / `restore` with a single
`Cell.transaction` block. Until then, stay on v1.

---

## 7. Anti-patterns

| Anti-pattern | Why it is wrong |
|---|---|
| `reserveMw.set(...)` inside `GridDecisionInstruction` | collapses the seam; the instruction must stay pure |
| `toHandle` called from the ACK observer | rebuilds the graph; ACK only calls `reset()` |
| `testRule: TestCell` on a Tissue constructor | wrong rule family; Tissue wants `TestTissue` |
| Latch stored in a `Cell`/`Tissue` | adds lock traffic and rebuild complexity for a one-field assignment |
| Reusing one instruction instance for both lanes | the two latches would collapse into one |
| Decision logic in the observers | the observers must only react to the chosen `Action` |

---

## 8. Reading order for newcomers

1. `GridDecisionInstruction` — the custom instruction and its public API.
2. `installGates` — where `+` builds the `FlowInstructionChain` and
   `toHandle` materialises it.
3. `policyOf` — the pure decision table.
4. `install` — ingresses, Tissue, observers.
5. `applyShed` / `restore` — the reserve protocol.
6. `main` — the scenario table.

---

## 9. See also

- `grid-demand-response(Cell)-WalkThrough.md` — the requirement.
- `grid-demand-response(Cell)-FEATURES.md` — feature catalogue.
- `grid-demand-response(tissue)-Demo.dart` — the Tissue-variant sibling.
- `card-auth-pipeline(Cell)-Demo.dart` — the custom-instruction template.
- `packages/cell_flow/lib/src/instruction/async_map.dart` — the
  `AsyncMap` pattern this instruction follows.
