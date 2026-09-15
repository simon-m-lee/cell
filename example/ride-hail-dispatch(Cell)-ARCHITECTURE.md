# Architecture — ride-hail dispatch (Cell variant)

**Companion to:** `ride-hail-dispatch(Cell)-Demo.dart`
**Audience:** engineers extending the demo, and readers comparing it
with `ride-hail-dispatch(tissue)-ARCHITECTURE.md`.

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

The Cell variant compresses the ride-hail match decision into a single
`MatchDecisionInstruction` that extends `FlowInstructionBase` the way
`AsyncMap` does — policy, distinct-until-changed latch, and idle
filter all live inside the instruction and are reached through a
public API (`matchOf`, `lastDecision`, `reset`). The harness then puts
that instruction together with one stock `MapValue` using
`operator +`, which builds a `FlowInstructionChain`, and materialises
the chain into a Cell with `toHandle`. Tissue remains untouched by the
instruction: the DISPATCH/SURGE/ACK observers are the only glue
between the decision Cells and the fleet books.

---

## 2. Layering

```text
┌────────────────────────────────────────────────────────────────┐
│ Scenario driver (main)                                          │
│   setLat/setLng/setWait/setSurge/setRider/setZone/setNearby    │
│   publishTick · ack · accept · complete                         │
└───────────────┬────────────────────────────────────────────────┘
                │
┌───────────────▼────────────────────────────────────────────────┐
│ Flow (package:cell_flow)                                        │
│   MatchDecisionInstruction  ── encapsulated match decision      │
│        + MapValue           ── chain projection                 │
│        = FlowInstructionChain                                   │
│        .toHandle(source: tickIn.cell)                           │
│             └─► dispatchCell / surgeCell (Cells)                │
└───────────────┬────────────────────────────────────────────────┘
                │  Cell.observe (the only glue)
┌───────────────▼────────────────────────────────────────────────┐
│ Tissue (package:cell_tissue)                                    │
│   trips (append-only) · idleDrivers (non-negative)              │
│   assignments · noGo · pushQ (bounded)                          │
└────────────────────────────────────────────────────────────────┘
```

Two rules keep the layers honest:

1. The instruction may read `noGo` but may write **no Tissue**.
2. The observers may write Tissue but may perform **no decision
   logic** — they only react to the `Match` the chain already chose.

---

## 3. Ownership matrix

| Concern | Owner | Notes |
|---|---|---|
| Lat / lng / wait / surge shape | `TestCell` on `latIn` / `lngIn` / `waitIn` / `surgeIn` | reject at the edge |
| Tick snapshot | `publishTick` | the only `MatchTick` factory |
| Match policy | `MatchDecisionInstruction.matchOf` | static, pure, clause-ordered |
| Distinct latch | `_MatchGateState` inside the instruction | one latch per lane instance |
| Idle suppression | `MatchDecisionInstruction` product filter | `match != pass` drops |
| Chain assembly | `installGates` | two `+` compositions, two `toHandle` |
| Latch reset | `MatchDecisionInstruction.reset` | called only by the ACK observer |
| Trip log integrity | `_tripAppendOnly` TestTissue | add-only |
| Idle count integrity | `_nonNegativeInt` TestTissue | value ≥ 0 |
| Assignment shape | `_assignmentRule` TestTissue | non-empty driver and rider ids |
| No-go zone set | `_noGoRule` TestTissue | uppercase, length ≥ 3 |
| Push retry | `_drivePush` | single-shot retry |

---

## 4. Locking

| Domain | Lock | Covers | Does not cover |
|---|---|---|---|
| Decision | Receptor lock on `dispatchCell` / `surgeCell` | instruction closure, latch, `MapValue` projection | any Tissue write |
| Books | Tissue lock on each collection | `trips.add`, `assignments[...]`, `idleDrivers.set`, `pushQ.addLast` | any decision logic |

A DISPATCH pulse crosses two lock boundaries in sequence: the chain's
Receptor lock releases, then the observer takes the Tissue lock. The
latch inside `MatchDecisionInstruction` is a plain Dart field guarded
by the Receptor lock; it is deliberately **not** a Cell or a Tissue,
so `reset()` is a synchronous assignment, not a graph rebuild.

The two lanes have independent latches by construction — two instances
of `MatchDecisionInstruction`, each with its own `_MatchGateState`. A
SURGE does not clear the DISPATCH latch and vice versa.

---

## 5. Failure semantics

| Failure | Behaviour |
|---|---|
| Lat / lng / wait / surge out of shape | `Cell.ingress` rejects; cache keeps the last accepted value; `publishTick` refuses to publish |
| Repeated match | instruction latch drops the pulse before it reaches the chain's `MapValue` |
| Closed stand in dispatch conditions | `matchOf` returns `idle` before any nearby check |
| Push transient failure | `_drivePush` retries once; both attempts count in `pushAttempts` |
| No idle drivers | `accept` pre-checks and returns `false` before writing |
| Idle write rejected | `accept` compensates by removing the map row |
| Complete without assignment | `complete` returns `false`; ACK `"CANCEL"` invents no drivers |
| Auditor write attempt | `trips.unmodifiable` blocks; COMPLY checks length parity |

The demo deliberately breaks the fleet invariant once (scenario 11) to
prove the `TestTissue` guard fires, then restores consistency in
scenario 12.

---

## 6. Extending the demo

### 6.1 A third product lane

Add `Match.waitlist` to the enum, then:

1. `matchOf` gains a clause producing `Match.waitlist`.
2. Create a third `MatchDecisionInstruction(noGo: …,
   pass: Match.waitlist)`.
3. Chain it with the same shared `MapValue<MatchDecision, Match>`.
4. Add the observer and counter.

The instruction class is unchanged — only the enum, the policy, and
the wiring change. That is the payoff of encapsulating the lane logic
in one instruction.

### 6.2 Policy variant without redeploying the graph

Because the instruction reads the live `noGo` set, closing a stand is
a Tissue write (`noGo.add(...)`), not a graph rebuild. The policy
itself is static; changing the *thresholds* requires a new instruction
instance, which is the documented trade-off.

### 6.3 A single chain for both products

`MatchDecisionInstruction` is parameterised by `pass`. A one-chain
variant could drop the `pass` parameter and emit every non-idle match,
with the observers branching on `match`. That is a legitimate
alternative; this demo keeps two lanes so the independent latches are
visible.

### 6.4 `Cell.transaction` across the fleet writes

When the running `cell_tissue` build exposes a joint commit across
`TissueValue` + `TissueMap` + `TissueList`, replace the v1
try/compensate in `accept` / `complete` with a single
`Cell.transaction` block. Until then, stay on v1.

---

## 7. Anti-patterns

| Anti-pattern | Why it is wrong |
|---|---|
| `idleDrivers.set(...)` inside `MatchDecisionInstruction` | collapses the seam; the instruction must stay pure |
| `toHandle` called from the ACK observer | rebuilds the graph; ACK only calls `reset()` |
| `testRule: TestCell` on a Tissue constructor | wrong rule family; Tissue wants `TestTissue` |
| Latch stored in a `Cell`/`Tissue` | adds lock traffic and rebuild complexity for a one-field assignment |
| Reusing one instruction instance for both lanes | the two latches would collapse into one |
| Decision logic in the observers | the observers must only react to the chosen `Match` |

---

## 8. Reading order for newcomers

1. `MatchDecisionInstruction` — the custom instruction and its public API.
2. `installGates` — where `+` builds the `FlowInstructionChain` and
   `toHandle` materialises it.
3. `matchOf` — the pure decision table.
4. `install` — ingresses, Tissue, observers.
5. `accept` / `complete` — the fleet protocol.
6. `main` — the scenario table.

---

## 9. See also

- `ride-hail-dispatch(Cell)-WalkThrough.md` — the requirement.
- `ride-hail-dispatch(Cell)-FEATURES.md` — feature catalogue.
- `ride-hail-dispatch(tissue)-Demo.dart` — the Tissue-variant sibling.
- `grid-demand-response(Cell)-Demo.dart` — the energy custom-instruction sibling.
- `packages/cell_flow/lib/src/instruction/async_map.dart` — the
  `AsyncMap` pattern this instruction follows.
