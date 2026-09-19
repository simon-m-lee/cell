# DEMO_GUIDE-Mitosis.md (Mitosis Edition)

# (Cell + Flow + Tissue) Demo Guide — Mitosis Edition

## From Reactive Cells to a Single Composed Instruction

A comprehensive guide to the **decision side** of the Cell Framework:
how a requirement paragraph becomes a Cell, how Instructions are
composed into a `FlowInstructionChain`, and how the `(Cell)` demos in
the umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>) directory relate to their `(tissue)`
counterparts in [`packages/cell_tissue/example/`](<https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example>).

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Purpose of the (Cell) Counterparts](#the-purpose-of-the-cell-counterparts)
3. [Core Concepts](#core-concepts)
4. [Mitosis Learning Path](#mitosis-learning-path)
5. [Level 1: Cell Ingress and Pulse](#level-1-cell-ingress-and-pulse)
6. [Level 2: Stock Instructions and Chains](#level-2-stock-instructions-and-chains)
7. [Level 3: Custom Instruction — Extending FlowInstructionBase](#level-3-custom-instruction--extending-flowinstructionbase)
8. [Level 4: Chain → Cell — toHandle and the Public API](#level-4-chain--cell--tohandle-and-the-public-api)
9. [Level 5: Real-World Applications](#level-5-real-world-applications)
10. [Cell / Flow Instruction Reference](#cell--flow-instruction-reference)
11. [Combining Patterns](#combining-patterns)
12. [Common Pitfalls](#common-pitfalls)
13. [Next Steps](#next-steps)

---

## Introduction

The Cell Framework provides a reactive programming model where **Cells**
hold state, **Pulses** carry signals, **Flow** orchestrates decisions,
and **Tissue** keeps governed books. The umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>) directory
holds the **Mitosis (Cell) editions** of the demos whose **Tissue
editions** live in [`packages/cell_tissue/example/`](<https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example>).

### What You'll Learn

- What the `(Cell)` counterparts are **for**, and how they differ from
  the `(tissue)` originals.
- How to compose stock Instructions with `operator +` into one
  `FlowInstructionChain`.
- How to extend `FlowInstructionBase` with a single custom Instruction
  that encapsulates policy + latch + filter, the way `AsyncMap` does.
- How `toHandle` materialises the blueprint into a live Cell, and which
  public API the harness uses around that moment.
- The golden rule and the two-lock discipline, unchanged from the
  Tissue edition.

### The Two Subsystem Split

Every demo follows the same architectural pattern:

| Subsystem | Responsibility | Examples |
|-----------|----------------|----------|
| **Flow** | Decision, interpretation, transformation | `MapValue`, `DistinctUntilChanged`, `Filter`, `Tap`, custom instructions |
| **Tissue** | Durable state, validation, audit trail | `TissueList`, `TissueValue`, `TissueMap` |

**The Golden Rule:** Flow decides. Tissue records. The observer is the
only glue. Never mix these responsibilities.

**TestCell vs TestTissue — do not swap:**

| Host | Rule type | Parameter |
|------|-----------|-----------|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` |

`TestCell` is the integrity rule on a **Cell** (shape of an incoming
pulse). `TestTissue` is the integrity rule on a **Tissue** (shape of a
mutation, a member, a value write). Grep for `testRule: TestCell` on a
Tissue constructor: zero hits.

---

## The Purpose of the (Cell) Counterparts

The `(tissue)` demos in [`packages/cell_tissue/example/`](<https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example>) teach the
**books side**: Tissue collections, `TestTissue` rules, deputies, and
the money/fleet/reserve write protocols. Their `(Cell)` counterparts in
the umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>) directory exist to teach the **decision side**
of the very same seam:

> **The `(Cell)` demos are not replacements. They are the same seam,
> same scenarios, and same books — viewed from the instruction side of
> the Flow layer.**

Specifically:

| Tissue edition (in [`packages/cell_tissue/example/`](<https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example>)) | Cell edition (in umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>)) | Purpose of the Cell edition |
|---|---|---|
| [`card-auth-pipeline(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/card-auth-pipeline(tissue)-Demo.dart>) | [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) | Demonstrates the **stock-operator chain**: `MapValue + DistinctUntilChanged + Filter + Tap + MapValue` composed into **one `FlowInstructionChain`**, materialised once with `toHandle`. The whole risk gate is one reusable blueprint; the books stay in the `Tap` side effect and observers. |
| [`grid-demand-response(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/grid-demand-response(tissue)-Demo.dart>) | [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>) | Demonstrates the **custom instruction**: `GridDecisionInstruction extends FlowInstructionBase` encapsulates type-check, `policyOf`, the distinct latch, and the hold filter in one class, exactly like `AsyncMap`; it is chained with a stock `MapValue` and materialised with `toHandle`. Public API: `policyOf`, `lastDecision`, `reset`, `pass`, `protected`. |
| [`ride-hail-dispatch(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/ride-hail-dispatch(tissue)-Demo.dart>) | [`ride-hail-dispatch(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/ride-hail-dispatch(Cell)-Demo.dart>) | Demonstrates the **custom instruction** in a second domain: `MatchDecisionInstruction` encapsulates `matchOf`, the distinct latch, and the idle filter; chained with `MapValue<MatchDecision, Match>`; public API: `matchOf`, `lastDecision`, `reset`, `pass`, `noGo`. |

What moved from the `(tissue)` edition to the `(Cell)` edition:

| In the `(tissue)` edition | In the `(Cell)` edition |
|---|---|
| `MapValue(policy) + closure-Distinct + Filter` with latch fields on the harness | One `GridDecisionInstruction` / `MatchDecisionInstruction` holding policy + latch + filter inside |
| Ad-hoc gate closures owned by the harness | A named, reusable instruction class with a public API |
| The decision logic is scattered across `installGates` and latch helpers | The decision logic reads as one sentence: `GridDecisionInstruction(protected: …, pass: Action.shed)` |
| The seam is demonstrated from the books outward | The seam is demonstrated from the instruction inward |

What **did not** change: the Tissue collections, the `TestTissue`
rules, the observers, the reserve/fleet protocols, the scenario table,
and the trailer counts. That is deliberate — a reader can diff the two
editions and see exactly what the Cell edition adds: **a custom
Instruction, composed into a FlowInstructionChain, turned into a Cell
at last.**

---

## Core Concepts

### What is a Cell?

A Cell is the atomic reactive node. It holds state, validates incoming
pulses with `TestCell`, and propagates evolved pulses downstream.
Ingress Cells are created with `Cell.ingress<T>()`; handle Cells are
created when an instruction chain is materialised with `toHandle`.

```dart
final hzIn = Cell.ingress<double>(testRule: _hzRange);  // ingress Cell
hzIn.emit(49.70);                                        // Pulse<double> in
```

### What is a Pulse?

A Pulse is the signal that travels the graph. It carries a `payload`,
`source`, `type`, `priority`, and a provenance `step`. Users care about
one surface: **what goes into each Cell (parameters) and what comes out
(`Pulse<type>`)**.

```dart
Cell.observe(source: shedCell, effect: (Pulse p) {
  if (p.payload == Action.shed) { /* write the books */ }
});
```

### What is an Instruction?

An Instruction is a **stateless blueprint** that describes how a pulse
is transformed or filtered. It is independent of any source Cell.

- `MapValue` — Rx `map`.
- `DistinctUntilChanged` — Rx `distinctUntilChanged`.
- `Filter` — Rx `filter`.
- `Tap` — Rx `tap` / `do`.

### What is a FlowInstructionChain?

A `FlowInstructionChain` is what `operator +` builds when you compose
Instructions:

```dart
final chain = MapValue<BayTick, GridDecision>(decide)
            + MapValue<GridDecision, Action>((d) => d.action);
```

Each `+` returns a `FlowInstruction`; the whole expression is **one
chain**. The chain is still only a blueprint — nothing runs until
`toHandle` materialises it.

### What is FlowInstructionBase?

`FlowInstructionBase<Cell, Pulse, Pulse>` is the base class for custom
Instructions. `AsyncMap` in
[`async_map.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/lib/src/instruction/async_map.dart>) is the canonical
template: the essential logic lives inside the instruction, and the
class exposes a public API that the caller uses when turning the
instruction into a Cell.

### What is toHandle?

`toHandle(source: cell)` compiles a blueprint into a live Cell bound to
a source. It returns a `FlowHandle` record whose `.cell` is the
observable output Cell:

```dart
final handle = chain.toHandle(source: tickIn.cell);
final gateCell = handle.cell;   // the Cell observers subscribe to
```

Exactly **one** `toHandle` per lane. ACK resets never call `toHandle`
again.

---

## Mitosis Learning Path

```
Level 1: Cell Ingress and Pulse (Start Here)
├── Cell.ingress        - the input parameter surface
├── Pulse.payload       - the output Pulse<type>
└── TestCell            - shape validation at the edge

Level 2: Stock Instructions and Chains
├── MapValue            - Rx map
├── Filter              - Rx filter
├── DistinctUntilChanged- Rx distinctUntilChanged
├── Tap                 - Rx tap / do
└── operator +          - builds a FlowInstructionChain

Level 3: Custom Instruction — Extending FlowInstructionBase
├── encapsulate policy  - pure decision inside the class
├── encapsulate latch   - distinct state per instruction instance
├── encapsulate filter  - product lane suppression
└── public API          - policyOf / matchOf, lastDecision, reset

Level 4: Chain → Cell — toHandle and the Public API
├── + stock projection  - narrow the rich output to the seam type
├── toHandle(source:)   - materialise the chain into a Cell
└── harness access      - reset() on ACK, lastDecision in the trailer

Level 5: Real-World Applications
├── Card Auth           - stock-operator chain (payments)
├── Ride-Hail Dispatch  - custom MatchDecisionInstruction (mobility)
└── Grid Demand-Response- custom GridDecisionInstruction (energy)
```

---

## Level 1: Cell Ingress and Pulse

### 1. Cell.ingress — the Input Parameter Surface

**What it does:** Creates an ingress Cell with an optional `TestCell`
shape rule.

**When to use:** Every sensor, command, or ACK that enters the demo.

```dart
final hzIn = Cell.ingress<double>(
  testRule: TestCell<Cell>((value, {host, arguments, user}) {
    final v = value is Pulse ? value.payload : value;
    return v is num && v >= 49.00 && v <= 51.00;
  }),
);
```

**Key Insight:** The ingress wraps the raw input in a `Pulse` before
the rule runs, so the rule unwraps `Pulse.payload` first. The input
parameter type (`double`) and the emitted `Pulse<double>` are the
user-facing contract.

### 2. Pulse.payload — the Output Surface

**What it does:** Carries the typed payload a downstream observer reads.

**When to use:** Every observer on a gate Cell.

```dart
Cell.observe(source: shedCell, effect: (Pulse pulse) {
  if (pulse.payload == Action.shed) { /* ... */ }
});
```

**Key Insight:** Users care about inputs (parameters) and outputs
(`Pulse<type>`). The WalkThrough `Parts` table, the Demo header, and
the FEATURES rows all state this surface.

---

## Level 2: Stock Instructions and Chains

### 3. MapValue — Rx map

```dart
final toAction = MapValue<GridDecision, Action>((d) => d.action);
```

### 4. Filter — Rx filter

```dart
Filter<Action>((a) => a == Action.shed);
```

### 5. DistinctUntilChanged — Rx distinctUntilChanged

```dart
DistinctUntilChanged<CardAuthRecord>(
  equals: (a, b) => a.decision == b.decision,
);
```

### 6. Tap — Rx tap / do

```dart
Tap<CardAuthRecord>((r) {
  if (r.decision == Decision.decline) { /* write the books */ }
});
```

### 7. operator + — Builds a FlowInstructionChain

```dart
final cardAuth = MapValue<AuthAttempt, CardAuthRecord>(snapshot)
               + DistinctUntilChanged<CardAuthRecord>(byDecision)
               + Filter<CardAuthRecord>(declineOrStepUp)
               + Tap<CardAuthRecord>(writeBooks)
               + MapValue<CardAuthRecord, Decision>(emitDecision);
```

**Key Insight:** Each `+` returns a `FlowInstruction`, so the whole
expression is **one `FlowInstructionChain`** — a reusable blueprint
with no live Cell yet. This is the [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>)
pattern.

---

## Level 3: Custom Instruction — Extending FlowInstructionBase

### 8. The AsyncMap Template

`AsyncMap` (in [`async_map.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/lib/src/instruction/async_map.dart>))
extends `FlowInstructionBase<Cell, Pulse, Pulse>`, puts the mapping
logic inside the class, and exposes its constructor parameters as the
public surface. The `(Cell)` demos follow the same template for a
**synchronous** gate:

```dart
final class GridDecisionInstruction
    extends FlowInstructionBase<Cell, Pulse, Pulse> {
  factory GridDecisionInstruction({
    required Set<String> protected,
    required Action pass,
    dynamic user,
  }) {
    final state = _GridGateState();
    return GridDecisionInstruction._(protected, pass, state, user);
  }

  GridDecisionInstruction._(
    Set<String> protected,
    Action pass,
    _GridGateState state,
    dynamic user,
  )   : _protected = protected,
        _pass = pass,
        _state = state,
        super(_build(protected, pass, state), user: user);

  static Pulse? Function(Pulse pulse, {Cell? cell, dynamic user}) _build(
    Set<String> protected,
    Action pass,
    _GridGateState state,
  ) {
    return (pulse, {cell, user}) {
      final tick = pulse.payload;
      if (tick is! BayTick) return null;         // type check
      final action = policyOf(tick, protected);  // policy
      if (state.last == action) return null;     // distinct latch
      state.last = action;
      if (action != pass) return null;           // product filter
      return Pulse<GridDecision>(
        GridDecision(tick: tick, action: action),
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'GridDecision.${pass.name}',
      );
    };
  }

  static Action policyOf(BayTick tick, Set<String> protected) { /* ... */ }
  Action? get lastDecision => _state.last;
  Action get pass => _pass;
  Set<String> get protected => _protected;
  void reset() => _state.last = null;
}
```

**Key Insight:** One class encapsulates type-check, policy, latch, and
filter. Two instances (`pass: Action.shed` and `pass: Action.warn`)
give two independent lanes without duplicating the logic.

### 9. Ride-Hail Variant

`MatchDecisionInstruction` is the same template in the mobility domain:

```dart
MatchDecisionInstruction(noGo: noGo, pass: Match.dispatch);
MatchDecisionInstruction(noGo: noGo, pass: Match.surge);
```

with `static Match matchOf(MatchTick tick, Set<String> noGo)` as the
pure policy.

**Key Insight:** The policy stays pure and static. The live
`protected` / `noGo` TissueSet is passed in at construction and read on
every pulse, so ops can mutate the set at runtime without redeploying
the graph.

---

## Level 4: Chain → Cell — toHandle and the Public API

### 10. Compose the Custom Instruction with a Stock Projection

The custom instruction emits the **rich** type (`GridDecision` /
`MatchDecision`). The seam type is the **narrow** `Action` / `Match`.
A shared stock `MapValue` performs that projection:

```dart
final toAction = MapValue<GridDecision, Action>((d) => d.action);
final shedChain = shedGate + toAction;      // FlowInstructionChain
final shedHandle = shedChain.toHandle(source: tickIn.cell);
shedCell = shedHandle.cell;
```

**Key Insight:** The `+` is the composition point, `toHandle` is the
materialisation point, and the returned Cell is what observers
subscribe to. Two lanes, two chains, two `toHandle` calls.

### 11. The Public API Around toHandle

| API | Used when |
|---|---|
| `policyOf` / `matchOf` | unit-testing the decision with a bare tick and a plain `Set` |
| `lastDecision` | reading the latch state in the trailer |
| `reset()` | ACK authority clears the latch without rebuilding the graph |
| `pass` / `protected` / `noGo` | docs, debug, and reuse of the blueprint |

The ACK observer calls `reset()`; it never calls `toHandle` again. The
trailer prints `lastDecision` to prove the reset happened.

---

## Level 5: Real-World Applications

### 12. Card Auth — Payments (stock-operator chain)

**File:** [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) (umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>))

**What it demonstrates:** The whole risk gate as one
`FlowInstructionChain` of **stock** Rx operators —
`MapValue + DistinctUntilChanged + Filter + Tap + MapValue` —
materialised once. The books are written from the `Tap` side effect and
the observers.

**Key Lessons:**

1. Stock operators mean less code.
2. Stock `DistinctUntilChanged` holds its own internal previous value
   and cannot be reset externally; the scenario sequence is arranged so
   this does not change the visible output (documented deviation).
3. Exactly one `toHandle` for the gate; ACK still never re-materialises.
4. Tissue books and money methods are unchanged from the `(tissue)`
   edition.

### 13. Grid Demand-Response — Energy (custom instruction)

**File:** [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>) (umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>))

**What it demonstrates:** `GridDecisionInstruction extends
FlowInstructionBase` encapsulating `policyOf`, the distinct latch, and
the hold filter; chained with `MapValue<GridDecision, Action>`; two
lanes (SHED / WARN); public API `policyOf` / `lastDecision` / `reset`.

**Key Lessons:**

1. One instruction reads as one sentence:
   `GridDecisionInstruction(protected: …, pass: Action.shed)`.
2. Distinct-before-filter lives inside the instruction, so
   `hold → shed → hold → shed` fires twice.
3. The instruction reads `protected` but never writes Tissue.
4. Reserve invariant and compensation ladder are unchanged.

### 14. Ride-Hail Dispatch — Mobility (custom instruction)

**File:** [`ride-hail-dispatch(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/ride-hail-dispatch(Cell)-Demo.dart>) (umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>))

**What it demonstrates:** `MatchDecisionInstruction` encapsulating
`matchOf`, the distinct latch, and the idle filter; chained with
`MapValue<MatchDecision, Match>`; two lanes (DISPATCH / SURGE); public
API `matchOf` / `lastDecision` / `reset`.

**Key Lessons:**

1. The custom instruction template ports across domains by renaming the
   domain types and rewriting the policy.
2. The no-go `TissueSet` is a live policy input, not a const.
3. The push pump, fleet protocol, and auditor deputy are unchanged from
   the `(tissue)` edition.

---

## Cell / Flow Instruction Reference

### Stock Instructions Used

| Instruction | Rx analogue | Used in |
|---|---|---|
| `MapValue<S, T>` | `map` | every `(Cell)` demo |
| `DistinctUntilChanged<S>` | `distinctUntilChanged` | [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) |
| `Filter<S>` | `filter` | [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) |
| `Tap<S>` | `tap` / `do` | [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) |

### Custom Instructions

| Class | Domain | Encapsulates | Public API |
|---|---|---|---|
| `GridDecisionInstruction` | Energy | type-check, `policyOf`, latch, hold filter | `policyOf`, `lastDecision`, `reset`, `pass`, `protected` |
| `MatchDecisionInstruction` | Mobility | type-check, `matchOf`, latch, idle filter | `matchOf`, `lastDecision`, `reset`, `pass`, `noGo` |

### Chain Materialisation

| Step | API | Notes |
|---|---|---|
| Compose | `operator +` | builds a `FlowInstructionChain` |
| Materialise | `toHandle(source: cell)` | returns `FlowHandle`; `.cell` is the output Cell |
| Observe | `Cell.observe(source: gateCell, ...)` | the only glue to Tissue |
| Reset | `instruction.reset()` | ACK path; never `toHandle` again |

---

## Combining Patterns

### Pattern: Stock-Operator Gate

```dart
final gate = MapValue<AuthAttempt, CardAuthRecord>(snapshot)
           + DistinctUntilChanged<CardAuthRecord>(byDecision)
           + Filter<CardAuthRecord>(actionable)
           + Tap<CardAuthRecord>(writeBooks)
           + MapValue<CardAuthRecord, Decision>(emitDecision);

final cell = gate.toHandle(source: attemptIn.cell).cell;
```

Use when the stock operators cover the policy and you accept their
internal state semantics.

### Pattern: Custom Instruction + Stock Projection

```dart
final shedGate = GridDecisionInstruction(
  protected: protected,
  pass: Action.shed,
);

final chain = shedGate + MapValue<GridDecision, Action>((d) => d.action);
final shedCell = chain.toHandle(source: tickIn.cell).cell;
```

Use when the policy + latch + filter should be one named, reusable
class with an externally resettable latch.

### Pattern: Two Lanes, Two Latches, One Shared Projection

```dart
final toMatch = MapValue<MatchDecision, Match>((d) => d.match);
final dispatchChain = dispatchGate + toMatch;  // lane 1
final surgeChain = surgeGate + toMatch;        // lane 2 (shared projection)
```

Use for two-product demos. The shared `MapValue` is stateless, so
reusing it across lanes is safe.

### Pattern: ACK Resets the Instruction, Not the Graph

```dart
Cell.observe(source: ackIn.cell, effect: (pulse) {
  shedGate.reset();
  warnGate.reset();
  // optionally restore / accept
});
```

Never call `toHandle` from the observer.

---

## Common Pitfalls

| Anti-pattern | Why it breaks the lesson |
|--------------|--------------------------|
| Writing Tissue inside the custom instruction | Collapses the seam; the instruction must stay pure Flow. |
| Scattering the policy across `MapValue` closures in the harness | The `(Cell)` edition exists to encapsulate it in one instruction. |
| Calling `toHandle` from the ACK observer | Doubles every downstream effect. ACK calls `reset()`. |
| Reusing one instruction instance for both lanes | The two latches collapse into one. |
| Returning the narrow seam type directly from the custom instruction | The chain's `MapValue` then has nothing to project; emit the rich type (`GridDecision` / `MatchDecision`). |
| Storing the latch in a `Cell`/`Tissue` | Adds lock traffic and rebuild complexity for a one-field assignment. |
| Using a boolean for two products | Two products need two lanes; a boolean cannot express the middle state. |
| Passing `TestCell` to a Tissue constructor | Wrong rule family; Tissue wants `TestTissue`. |
| Holding the Receptor lock across a Tissue write | Violates the two-lock discipline. |
| Making `policyOf` / `matchOf` async | Purity is the lesson; async reads belong at ingress. |

---

## Next Steps

### For Dart Developers New to Cell

1. Read the `(Cell)` header of [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>).
2. Read `GridDecisionInstruction` in isolation — it is pure.
3. Trace one SHED from `setHz` through the chain to `events.add`.
4. Diff it against [`grid-demand-response(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/grid-demand-response(tissue)-Demo.dart>) to see what
   moved from harness closures into the instruction.

### For Framework Extenders

1. Read [`async_map.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/lib/src/instruction/async_map.dart>) — the
   `FlowInstructionBase` template.
2. Read [`flow_core.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/lib/src/flow_core.dart>) — `toHandle`,
   `FlowHandle`, and the `+` composition.
3. Read [`map.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/lib/src/instruction/map.dart>) — the sync
   instruction closure contract.
4. Write a custom Instruction for your own policy.

### For Domain Porters

1. Pick the closest `(Cell)` sibling.
2. Rename the domain types (`BayTick` / `MatchTick` → `YourTick`).
3. Rewrite the policy (`policyOf` / `matchOf` → `yourPolicy`).
4. Keep the seam: one custom instruction per product lane, one stock
   `MapValue` projection, one `toHandle` per lane, one observer per
   gate, one `TestTissue` per collection.
5. Keep the two-lock discipline and the golden rule.

### Sibling Demos

| Cell edition (umbrella [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>)) | Tissue edition ([`packages/cell_tissue/example/`](<https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example>)) | Domain |
|------|--------|------|
| [`card-auth-pipeline(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-Demo.dart>) | [`card-auth-pipeline(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/card-auth-pipeline(tissue)-Demo.dart>) | Payments — stock-operator chain |
| [`ride-hail-dispatch(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/ride-hail-dispatch(Cell)-Demo.dart>) | [`ride-hail-dispatch(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/ride-hail-dispatch(tissue)-Demo.dart>) | Mobility — custom `MatchDecisionInstruction` |
| [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>) | [`grid-demand-response(tissue)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/grid-demand-response(tissue)-Demo.dart>) | Energy — custom `GridDecisionInstruction` |

### Companion Documents

For each demo, the following companions exist:

| Document | Purpose |
|----------|---------|
| `*-Demo.dart` | Executable implementation |
| `*-WalkThrough.md` | Requirement document and scenario contract |
| `*-ARCHITECTURE.md` | Layering, ownership, locking, failure semantics, anti-patterns |
| `*-FEATURES.md` | Operator catalogue and feature index |

Read them in this order:

1. **This file** — the guide in ten minutes.
2. **`*-Demo.dart`** — skim the class doc, then read the custom
   instruction and the gate installation.
3. **`*-WalkThrough.md`** — the requirement and the scenario contract.
4. **`*-FEATURES.md`** — the operator catalogue.
5. **`*-ARCHITECTURE.md`** — the layering and ownership note.

---

*End of DEMO_GUIDE-Mitosis.md (Mitosis Edition).*
