# DEMO_GUIDE.md

# Cell Framework Demo Guide

## From Core Primitives to Real-World Applications

A comprehensive guide to understanding the Cell Framework through the executable examples in `/example`, organized from fundamental concepts to complex real-world applications.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Demo Learning Path](#demo-learning-path)
4. [Level 1: Foundation Primitives](#level-1-foundation-primitives)
5. [Level 2: Temporal & Signal Control](#level-2-temporal--signal-control)
6. [Level 3: Async, Routing & Composition](#level-3-async-routing--composition)
7. [Level 4: Governance & Atomicity](#level-4-governance--atomicity)
8. [Level 5: Real-World Applications](#level-5-real-world-applications)
9. [Operator Reference](#operator-reference)
10. [Combining Patterns](#combining-patterns)
11. [Common Pitfalls](#common-pitfalls)
12. [Next Steps](#next-steps)

---

## Introduction

The Cell Framework provides a reactive programming model where **Cells** hold state and topology, **Pulses** carry immutable signals, **Receptors/Instructions** transform those signals, and **Synapses** distribute them downstream. This guide walks you through every demo in `/example` — from `Cell.state` to bank transfers and aircraft turnarounds.

### What You'll Learn

- How to use each core API correctly
- When to choose one cell type or operator over another
- How to compose cells into pipelines and domain systems
- How to build production-ready applications with transactions and governance
- Common patterns and anti-patterns

### The Three-Layer Architecture

Every demo follows the same architectural pattern:

| Layer | Responsibility | Examples |
|-------|----------------|----------|
| **Cell** | Holds state, owns topology, validates signals | `Cell.state`, `Cell.ingress`, `Cell.open` |
| **Receptor / Instruction** | Transforms, filters, routes, enforces policy | `Receptor`, `Instruction`, `Cell.derive`, `Cell.distinct` |
| **Observer / Synapses** | Side effects, propagation, logging | `Cell.observe`, `Synapses`, `Cell.hub` |

**The Golden Rule:** Cells hold state and topology. Receptors transform pulses. Observers handle side effects. Transactions move state atomically. Never mix these responsibilities.

---

## Core Concepts

### What is a Cell?

A Cell is a reactive node that:

- Holds state (`Cell.state`)
- Accepts external input (`Cell.ingress`)
- Broadcasts changes to downstream observers (`Synapses`)
- Validates incoming data (`TestCell`)
- Can be projected (`Cell.derive`) and governed (`Cell.governed`, `EphemeralPolicy`)

```dart
// A simple state cell
final counter = Cell.state<int>(initial: 0);

// A state cell with evolution logic
final bounded = Cell.state<int>(
  initial: 0,
  evolve: (host, pulse) => Pulse((host.value + (pulse.payload as int? ?? 0)).clamp(0, 100)),
);

counter.update(1);
print(counter.cell.value); // 1
```

### What is a Pulse?

A Pulse is an immutable message that carries:

- **Payload**: the actual data
- **Type**: semantic category for routing
- **Priority**: execution urgency
- **Context**: provenance metadata
- **Trace**: transformation history
- **Policy**: optional ephemeral lifecycle governance

```dart
final pulse = Pulse.governed<String>(
  payload: 'Hello, World!',
  type: 'message',
  priority: 60,
  context: PulseContext.userAction(
    actor: 'user_123',
    reason: 'Sending message',
  ),
);
```

### What is a Receptor?

A Receptor is the cell's "input logic controller". It runs a pipeline:

```
preProcess → instruction → postProcess
```

and decides what happens to each incoming pulse. `Instruction` is the reusable unit of transformation logic.

```dart
final receptor = Receptor(
  (cell, pulse, {user}) {
    final value = pulse.payload as int;
    return value > 0 ? Pulse(value * 2) : null; // null drops the pulse
  },
);
```

### What is a Transaction?

`Cell.transaction` / `Cell.txApply` provide atomic multi-cell updates with staging, savepoints, compensation, and rollback.

```dart
final tx = Cell.txApply();
await tx.execute(participants: [alice, bob], body: (tx) {
  alice.apply(alice.setValue, positionalArguments: [70], tx: tx,
      compensate: alice.setValue, compensatePositional: [100]);
  bob.apply(bob.setValue, positionalArguments: [80], tx: tx,
      compensate: bob.setValue, compensatePositional: [50]);
});
```

---

## Demo Learning Path

```
Level 1: Foundation Primitives (Start Here)
├── state_demo.dart         — Cell.state
├── ingress_demo.dart       — Cell.ingress
├── observe_demo.dart       — Cell.observe
├── derive_demo.dart        — Cell.derive
└── distinct_demo.dart      — Cell.distinct

Level 2: Temporal & Signal Control
├── stability_search_demo.dart — Cell.debounce
├── throttle_demo.dart         — Cell.throttle
└── valve_demo.dart            — Cell.valve

Level 3: Async, Routing & Composition
├── async_map_demo.dart    — Cell.asyncMap
├── hub_demo.dart          — Cell.hub
└── synthesis_demo.dart    — SynthesisCell

Level 4: Governance & Atomicity
├── open_cell_demo.dart              — Cell.open
├── sanitized_demo.dart              — Cell.sanitized
├── instruction_pipeline_walkthrough.dart — Instruction
├── receptor_pipeline_walkthrough.dart     — Receptor
├── transaction_demo.dart            — Cell.transaction
└── atomic_multi_update.dart         — Cell.txApply

Level 5: Real-World Applications
├── hotel-front-desk-checkin-Demo.dart — Hospitality front desk
└── aircraft-gate-turnaround-Demo.dart — Airline gate turnaround
```

---

## Level 1: Foundation Primitives

### 1. Cell.state — Persistent State

**File:** `state_demo.dart`

**What it does:** Creates a persistent state atom that can be read and updated, optionally with evolution logic.

**When to use:** Any time you need to store and manage mutable state.

```dart
final counter = Cell.state<int>(initial: 0);

Cell.observe(
  source: counter.cell,
  effect: (pulse) => print('[Counter] value = ${pulse.payload}'),
);

counter.update(1);
counter.update(5);
counter.update(42);
```

**Key Insight:** The `evolve` function defines how state changes. It receives the current value and the incoming pulse, and returns the new value. Handles (`counter`) are controllers; `.cell` is the reactive node.

---

### 2. Cell.ingress — Input Gateway

**File:** `ingress_demo.dart`

**What it does:** Creates an entry point for external events to enter the reactive graph, with optional refinement.

**When to use:** UI events, network callbacks, hardware interrupts.

```dart
final searchGate = Cell.ingress<String>(
  refine: (value) => value.trim().isNotEmpty ? value.trim() : null,
);

Cell.observe(
  source: searchGate.cell,
  effect: (pulse) => print('Search: ${pulse.payload}'),
);

searchGate.emit('  Hello World  '); // accepted, trimmed
searchGate.emit('   ');              // rejected by refine
await searchGate.emitAsync('Dart Reactive');
```

**Key Insight:** Ingress cells are stateless — they only relay events. `refine` sanitizes or rejects input before it enters the graph. For persistent state, use `Cell.state`.

---

### 3. Cell.observe — Side Effects

**File:** `observe_demo.dart`

**What it does:** Creates a terminal observer that executes side effects when a pulse arrives.

**When to use:** UI updates, logging, database writes, network requests.

```dart
final uiObserver = Cell.observe(
  source: counter.cell,
  effect: (pulse) => print('[UI] setState → count = ${pulse.payload}'),
);

final lifecycleObserver = Cell.observe(
  source: counter.cell,
  effect: (pulse) => print('[Audit] ${pulse.trace}'),
);

lifecycleObserver.stop(); // detach
lifecycleObserver.start(); // re-attach
```

**Key Insight:** Observers are terminal — they don't propagate pulses. They're for side effects only.

---

### 4. Cell.derive — Functional Projections

**File:** `derive_demo.dart`

**What it does:** Creates a derived cell whose value is a pure projection of a source cell, with causal tracing.

**When to use:** Data formatting, type conversion, chained projections, read models.

```dart
final profile = Cell.state<Map<String, dynamic>>(
  initial: {'name': 'ada lovelace', 'email': 'ada@example.com', 'age': 36},
);

final displayName = Cell.derive<Pulse, Pulse>(
  source: profile.cell,
  project: (pulse) => Pulse((pulse.payload as Map)['name'].toString().toUpperCase()),
  type: 'user.displayName',
);

profile.update({'name': 'ada lovelace', 'email': 'ada@example.com', 'age': 36});
```

**Key Insight:** Derive is pure — it doesn't mutate the source, it creates a new reactive node. The `type` tag enables pattern-based routing downstream.

---

### 5. Cell.distinct — Noise Reduction

**File:** `distinct_demo.dart`

**What it does:** Removes consecutive duplicate values, with optional custom equality.

**When to use:** Sensor noise reduction, change detection, deduplication.

```dart
final status = Cell.ingress<String>();
final distinctStatus = Cell.distinct(status.cell);

Cell.observe(
  source: distinctStatus.cell,
  effect: (pulse) => print('[Status] ${pulse.payload}'),
);

status.emit('idle');
status.emit('idle');   // suppressed
status.emit('loading');
status.emit('loading'); // suppressed
status.emit('done');
```

**Key Insight:** Distinct compares only consecutive values. For a custom notion of equality (e.g., temperature within 0.2°C), pass an `equals` function.

---

## Level 2: Temporal & Signal Control

### 6. Cell.debounce — Input Stabilization

**File:** `stability_search_demo.dart`

**What it does:** Waits for a period of silence before emitting the latest value.

**When to use:** Search-as-you-type, auto-save, form validation, resize events.

```dart
final queries = Cell.ingress<String>();
final stableQuery = Cell.debounce(
  queries.cell,
  Duration(milliseconds: 80),
);

Cell.observe(
  source: stableQuery.cell,
  effect: (pulse) => print('[API] GET /search?q=${pulse.payload}'),
);

queries.emit('c');
queries.emit('ca');
queries.emit('cat');
queries.emit('cats'); // only this triggers the API after 80ms silence
```

**Key Insight:** Without debounce, every keystroke triggers work. With debounce, only the final value after silence is processed.

---

### 7. Cell.throttle — Rate Limiting

**File:** `throttle_demo.dart`

**What it does:** Limits the frequency of emissions to a maximum rate, with leading/trailing control.

**When to use:** Scroll events, high-frequency sensors, click prevention.

```dart
final rawSensor = Cell.state<int>(initial: 0);
final throttledSensor = Cell.throttle(
  rawSensor.cell,
  Duration(milliseconds: 120),
  leading: true,
  trailing: false,
);

rawSensor.update(1); // emitted immediately (leading)
rawSensor.update(2); // suppressed
rawSensor.update(3); // suppressed
```

**Debounce vs Throttle:**

| | Debounce | Throttle |
|---|---|---|
| Behavior | Wait for silence → last value | Limit rate → first value then periodic |
| Use case | Search, auto-save | Scroll, sensor streams |

---

### 8. Cell.valve — Conditional Propagation

**File:** `valve_demo.dart`

**What it does:** Demonstrates conditional signal propagation — circuit breaker, gate control, rate limiting — built with `Cell.fromNucleus` and a custom receptor.

**When to use:** Feature flags, kill switches, circuit breakers, rate limiters.

```dart
// A custom valve built on Cell.fromNucleus with a custom receptor.
final valve = createValve(
  policy: (event) => event.priority >= 8,
);

final highPriorityObs = Cell.observe(
  source: valve.cell,
  effect: (pulse) => print('[High] ${pulse.payload}'),
);

eventSource.emit(SystemEvent(priority: 9)); // passes
eventSource.emit(SystemEvent(priority: 2)); // dropped
```

**Key Insight:** A valve is just a receptor that returns `null` to drop pulses. You can build powerful gates without any special framework class.

---

## Level 3: Async, Routing & Composition

### 9. Cell.asyncMap — Concurrent Background Tasks

**File:** `async_map_demo.dart`

**What it does:** Maps each value through an async function with configurable concurrency (`latestOnly`, `sequential`).

**When to use:** API calls, database queries, file I/O.

```dart
final userIds = Cell.ingress<int>();
final profiles = Cell.asyncMap<int, Map<String, dynamic>>(
  userIds.cell,
  mapper: (id) async => await fetchUser(id),
  concurrency: 0, // 0 = unlimited parallel
);

final searchResults = Cell.asyncMap<String, List<String>>(
  query.cell,
  mapper: (q) async => await search(q),
  latestOnly: true, // cancel stale searches
);
```

**Key Insight:** Three strategies in one API: parallel (`concurrency: 0`), sequential (`sequential: true`), latest-wins (`latestOnly: true`). Use `latestOnly` for search-as-you-type.

---

### 10. Cell.hub — Pattern Matching & Multicast

**File:** `hub_demo.dart`

**What it does:** Routes pulses by exact type or pattern, ordered by priority, to multiple handlers.

**When to use:** Command routing, event buses, priority queues.

```dart
final hub = Cell.hub(
  routes: [
    HubRoute(
      pattern: HubPattern.exact('auth.login'),
      priority: 100,
      handler: (pulse) => print('[Auth] received: ${pulse.payload}'),
    ),
    HubRoute(
      pattern: HubPattern.prefix('user.'),
      priority: 50,
      handler: (pulse) => print('[User] ${pulse.payload}'),
    ),
  ],
);

hub.emit(Pulse('user=alice', type: 'auth.login'));
hub.emit(Pulse('name=Bob', type: 'user.profile.update'));
```

**Key Insight:** Priority ordering means exact high-priority matches win; patterns allow catch-all routing. Multicast fans one pulse out to multiple matched handlers.

---

### 11. SynthesisCell — Information Convergence

**File:** `synthesis_demo.dart`

**What it does:** Aggregates multiple source cells into a single unified stream.

**When to use:** Dashboards, multi-sensor aggregation, form validation, environment status.

```dart
final tempHandle = Cell.state<double>(initial: 21.5);
final humHandle = Cell.state<double>(initial: 40.0);
final pressHandle = Cell.state<double>(initial: 1013.25);

final synthesis = SynthesisCell(
  sources: [tempHandle.cell, humHandle.cell, pressHandle.cell],
  combine: (latest) => EnvironmentStatus(
    temperature: latest[0] as double,
    humidity: latest[1] as double,
    pressure: latest[2] as double,
  ),
);
```

**Key Insight:** Synthesis is the framework's primary mechanism for **Information Convergence** — turning a set of disparate cells into a single logical unit.

---

## Level 4: Governance & Atomicity

### 12. Cell.open — Manual Injection & Dynamic Topology

**File:** `open_cell_demo.dart`

**What it does:** Creates an **Imperative Gateway** — an entry point that isn't locked to a single source, with runtime `link`/`unlink`.

**When to use:** Dynamic topology, module boundaries, testing, manual signal injection.

```dart
final gate = Cell.open(
  testRule: TestCell.allowAll,
  receptor: Receptor((cell, pulse, {user}) {
    print('[Gate] received payload=${pulse.payload} type=${pulse.type}');
    return pulse;
  }),
);

final logger = Cell.open(
  receptor: Receptor((cell, pulse, {user}) {
    print('[Logger] ${pulse.payload}');
    return pulse;
  }),
);

gate.link(logger.cell);
gate.emit(Pulse('PING', type: 'system.ping'));
gate.unlink(logger.cell);
```

**Key Insight:** `Cell.open` lets you push data into the network manually and change who is listening at runtime — the bridge to external systems.

---

### 13. Cell.sanitized — PII Redaction & Audit

**File:** `sanitized_demo.dart`

**What it does:** Creates a governed view that redacts sensitive payload fields based on sensitivity, with audit trails.

**When to use:** PII protection, compliance, privacy-preserving views.

```dart
final rawIngress = Cell.ingress<Map<String, dynamic>>();
final safeView = Cell.sanitized<Pulse>(
  rawIngress.cell,
  policy: SanitizePolicy(
    redact: (payload, sensitivity) { /* redact PII fields */ },
  ),
);

Cell.observe(
  source: safeView.cell,
  effect: (pulse) => print('[UI] safe payload = ${pulse.payload}'),
);

Cell.observe(
  source: safeView.cell,
  effect: (pulse) => print('[Audit] ${pulse.trace}'),
);
```

**Key Insight:** Sanitization happens at the cell boundary — consumers of `safeView` never see the raw payload, and the audit observer records provenance.

---

### 14. Instruction Pipeline — E-Commerce Order Validation

**File:** `instruction_pipeline_walkthrough.dart`

**What it does:** Builds a data-processing pipeline with `Instruction` — pre-process, core instruction, post-process.

**When to use:** Multi-stage transformation, validation/enrichment pipelines.

```dart
final validateOrder = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
  final order = pulse.payload as Map;
  return order['total'] != null ? pulse : null;
});

final enrichOrder = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
  final order = Map<String, dynamic>.from(pulse.payload as Map);
  order['status'] = 'validated';
  return Pulse(order);
});

final pipeline = Instruction.chain([validateOrder, enrichOrder]);
```

**Key Insight:** Instructions are pure, reusable logic units. `Instruction.chain` composes them sequentially with short-circuiting on `null`.

---

### 15. Receptor Pipeline — Document Workflow Automation

**File:** `receptor_pipeline_walkthrough.dart`

**What it does:** Builds a robust document management pipeline with `Receptor` — pre-process, rule, post-process.

**When to use:** Workflow automation, multi-stage document processing.

```dart
final documentReceptor = Receptor.pipeline(
  preProcess: Instruction((p, {cell, user}) {
    print('Pre-processing document...');
    return p;
  }),
  instruction: Instruction((p, {cell, user}) {
    print('Processing document...');
    return p;
  }),
  postProcess: Instruction((p, {cell, user}) {
    print('Post-processing document...');
    return p;
  }),
);
```

**Key Insight:** Receptors orchestrate the full signal path; Instructions are the stages. A cell with a pipeline receptor becomes a complete processing node.

---

### 16. Cell.transaction — Atomic Multi-Cell Updates

**File:** `transaction_demo.dart`

**What it does:** Atomic multi-cell updates with isolation, savepoints, and rollback.

**When to use:** Bank transfers, inventory updates, any multi-cell consistency requirement.

```dart
final tx = Cell.transaction(participants: [alice, bob, inventory]);

final savepoint = tx.savepoint();
tx.stage(alice.setValue, [60]);
tx.stage(bob.setValue, [90]);
tx.rollback(to: savepoint); // undo speculative stages

await tx.commit(); // apply all staged changes atomically
```

**Key Insight:** `transaction` is the explicit multi-cell API: `stage` → `savepoint` → `rollback` → `commit`. `txApply` (next demo) wraps the same engine with compensation.

---

### 17. Cell.txApply — Bank Transfer & Compensation

**File:** `atomic_multi_update.dart`

**What it does:** `Cell.txApply` stages multiple `apply(...)` calls into one atomic commit with compensation functions.

**When to use:** Atomic multi-step updates with automatic rollback/compensation.

```dart
final tx = Cell.txApply();
await tx.execute(participants: [alice, bob], body: (tx) {
  alice.apply(alice.setValue, positionalArguments: [70], tx: tx,
      compensate: alice.setValue, compensatePositional: [100]);
  bob.apply(bob.setValue, positionalArguments: [80], tx: tx,
      compensate: bob.setValue, compensatePositional: [50]);
});
```

**Key Insight:** Compensations undo already-committed stages if a later stage fails. This is the foundation for resilient multi-node consistency.

---

## Level 5: Real-World Applications

### 18. Hotel Front-Desk Check-In — Hospitality

**File:** `hotel-front-desk-checkin-Demo.dart` (+ `hotel-front-desk-checkin-WalkThrough.md`)

**What it demonstrates:** A complete Cell-core property management flow: look up a reservation, refuse a dirty/occupied room, encode a key, post a folio, and undo the key if the encoder jams.

**Key components:**

1. **Reservation lookup** — `Cell.state` + `Cell.derive` + `TestCell`
2. **Room state machine** — named state cells (`clean`, `occupied`) gating check-in
3. **Key encoding** — transactional `apply` with compensation on encoder failure
4. **Folio posting** — atomic state update after successful check-in
5. **PII handling** — `Cell.sanitized` for guest data

**Architecture:**

```
Reservation Lookup
      │
      ▼
[Cell] reservation + TestCell(valid)
      │
      ▼
[Cell] room state (clean / occupied)
      │
      ├─ refuse if dirty or occupied
      │
      ▼
[Tx] encode key + post folio (atomic)
      │
      ├─ success → checked-in
      └─ encoder jam → compensate (undo key)
```

**Key Lessons:**

1. The system of record is **named state Cells**, not a collection type.
2. `Cell.derive` + `TestCell` + `Cell.distinct` replace `Flow.filter` for the core tier.
3. Use `Cell.state<List<…>>` only as a local harness printer — or print from `Cell.observe`.
4. Hardware steps after the atomic commit need a **new transaction** to compensate.

---

### 19. Aircraft Gate Turnaround — Airline Ramp

**File:** `aircraft-gate-turnaround-Demo.dart` (+ `aircraft-gate-turnaround-WalkThrough.md`)

**What it demonstrates:** The twenty-five-minute ramp turnaround — fuel the wing, dock the jetbridge, close the doors, pull the chocks, call for push — implemented with Cell core only.

**Key components:**

1. **Named state cells** — `doors`, `chocks`, `fuelKg`, `status`
2. **Atomic invariant pair** — `doors closed + chocks off + status = pushing`
3. **Side channels** — FIDS text and fuel kg are observations, not the lock
4. **Pushback gate** — a governed cell that refuses push if doors are open or chocks are on

**Architecture:**

```
Doors cell        Chocks cell
     │                 │
     └────────┬────────┘
              ▼
   [Cell] Pushback Gate (doors closed && chocks off)
              │
              ▼
   [Tx] status = pushing + FIDS update (atomic)
```

**Key Lessons:**

1. You cannot push an aircraft with a door open.
2. You cannot leave the chocks on after a cleared push.
3. Fuel kg and FIDS text are side channels, not the lock.
4. Groups 1–4 plus Atomic from `package:cell` are enough for a real turn — no Flow, no Tissue.

---

## Operator Reference

### Creation & State

| Operator | Purpose | Demo |
|----------|---------|------|
| `Cell.state` | Persistent state atom | `state_demo.dart` |
| `Cell.ingress` | External input gateway | `ingress_demo.dart` |
| `Cell.open` | Manual injection + dynamic topology | `open_cell_demo.dart` |
| `Cell.governed` | Governed cell with ephemeral policy | used in debounce/valve |
| `Cell.fromNucleus` | Custom nucleus construction | `valve_demo.dart` |

### Observation & Projection

| Operator | Purpose | Demo |
|----------|---------|------|
| `Cell.observe` | Terminal side-effect observer | `observe_demo.dart` |
| `Cell.derive` | Functional projection | `derive_demo.dart` |
| `Cell.distinct` | Consecutive duplicate suppression | `distinct_demo.dart` |
| `SynthesisCell` | Multi-source aggregation | `synthesis_demo.dart` |

### Temporal Control

| Operator | Purpose | Demo |
|----------|---------|------|
| `Cell.debounce` | Emit after silence | `stability_search_demo.dart` |
| `Cell.throttle` | Rate limiting | `throttle_demo.dart` |
| `Cell.valve` | Conditional propagation / circuit breaker | `valve_demo.dart` |

### Async & Routing

| Operator | Purpose | Demo |
|----------|---------|------|
| `Cell.asyncMap` | Async mapping (parallel/sequential/latest) | `async_map_demo.dart` |
| `Cell.hub` | Pattern matching + priority + multicast | `hub_demo.dart` |
| `Cell.sanitized` | PII redaction + audit | `sanitized_demo.dart` |

### Transformation & Governance

| Operator | Purpose | Demo |
|----------|---------|------|
| `Instruction` | Reusable transformation unit | `instruction_pipeline_walkthrough.dart` |
| `Instruction.chain` | Sequential instruction pipeline | `instruction_pipeline_walkthrough.dart` |
| `Receptor` | Cell input logic controller | `receptor_pipeline_walkthrough.dart` |
| `Receptor.pipeline` | preProcess → instruction → postProcess | `receptor_pipeline_walkthrough.dart` |

### Atomicity

| Operator | Purpose | Demo |
|----------|---------|------|
| `Cell.transaction` | Multi-cell staging/savepoints/rollback | `transaction_demo.dart` |
| `Cell.txApply` | Compensation-based atomic apply | `atomic_multi_update.dart` |

---

## Combining Patterns

### Pattern 1: Search-as-you-type

```dart
final queries = Cell.ingress<String>();
final stableQuery = Cell.debounce(queries.cell, Duration(milliseconds: 80));
final results = Cell.asyncMap<String, List<String>>(
  stableQuery.cell,
  mapper: (q) async => await search(q),
  latestOnly: true, // cancel stale requests
);
Cell.observe(source: results.cell, effect: (pulse) => render(pulse.payload));
```

### Pattern 2: Governed sensor pipeline

```dart
final rawSensor = Cell.state<int>(initial: 0);
final throttled = Cell.throttle(rawSensor.cell, Duration(milliseconds: 120), leading: true);
final distinct = Cell.distinct(throttled.cell);
Cell.observe(source: distinct.cell, effect: (pulse) => updateUI(pulse.payload));
```

### Pattern 3: Atomic write with compensation

```dart
final tx = Cell.txApply();
await tx.execute(participants: [primary, secondary], body: (tx) {
  primary.apply(primary.setValue, positionalArguments: [newValue], tx: tx,
      compensate: primary.setValue, compensatePositional: [oldValue]);
  secondary.apply(secondary.setValue, positionalArguments: [newValue], tx: tx,
      compensate: secondary.setValue, compensatePositional: [oldValue]);
});
```

### Pattern 4: Hub-and-spoke routing

```dart
final hub = Cell.hub(routes: [
  HubRoute(pattern: HubPattern.exact('auth.login'), priority: 100, handler: authHandler),
  HubRoute(pattern: HubPattern.prefix('user.'), priority: 50, handler: userHandler),
  HubRoute(pattern: HubPattern.any, priority: 0, handler: fallbackHandler),
]);
```

---

## Common Pitfalls

1. **Mixing side effects into state cells.** Keep `Cell.state.evolve` pure; side effects belong in `Cell.observe`.
2. **Forgetting to await async emission.** `emit` is synchronous; `emitAsync` and `Cell.asyncMap` need `await` when ordering matters.
3. **Stacking handles instead of resetting.** One receptor per logical gateway — don't chain `toHandle` repeatedly.
4. **Reaching for collections when named cells suffice.** In the core tier, the system of record is **named state cells**, not list/set types.
5. **Ignoring compensation.** Hardware/network steps after a commit need a new transaction with a compensation path.
6. **Over-filtering before `distinct`.** Order matters: `distinct` first, then `filter`, otherwise `none`/idle states never arrive.
7. **Blocking the main isolate.** Use `Cell.asyncMap` / `emitAsync` for I/O, not synchronous work in receptors.

---

## Next Steps

1. **Run the demos.** Every file in `/example` is executable:
   ```bash
   dart run example/state_demo.dart
   dart run example/atomic_multi_update.dart
   ```
2. **Read the walkthroughs.** `hotel-front-desk-checkin-WalkThrough.md` and `aircraft-gate-turnaround-WalkThrough.md` explain the domain reasoning behind the two real-world demos.
3. **Study the tests.** `packages/cell/test/test_*.dart` contains contract-level coverage for every API used in the examples.
4. **Extend the patterns.** Combine `Cell.derive` + `TestCell` + `Cell.distinct` for your own domain gates, and use `Cell.txApply` for every multi-node write.
5. **Cross-package.** When you need stream/collection operators, move up to `package:cell_flow` (Flow operators) and `package:cell_tissue` (reactive collections) — both are built on these core primitives.
