# Cell Framework — Feature Catalog

**Package:** `cell`  
**Version:** `1.0.0-rc.1` (RC / Mitosis Release Candidate)  
**SDK:** Dart `>=3.5.0 <4.0.0`  
**License:** MIT or Apache-2.0  
**Author:** Lee Man Hoi Simon (see [`AUTHORS`](AUTHORS))  
**Location:** `packages/cell`

This document is a complete, categorized inventory of features in the **cell** package — the foundation layer of the Cell Framework. Use it to decide whether Cell covers a requirement, which operator to reach for, and what is opt-in versus on by default.

It is derived from the public API in `lib/` and the guides in `guide/`. If a guide and the source disagree, **the source is current**. Test contracts live in [`TEST_VERIFICATION.md`](TEST_VERIFICATION.md).

---

## Table of Contents

1. [What Cell Is](#1-what-cell-is)
2. [Status and Boundaries](#2-status-and-boundaries)
3. [Progressive Disclosure](#3-progressive-disclosure)
4. [Core Reactive Primitives](#4-core-reactive-primitives)
5. [Standard Entry Operators](#5-standard-entry-operators)
6. [Additional Cell Factories](#6-additional-cell-factories)
7. [Cell Instance API](#7-cell-instance-api)
8. [OpenCell](#8-opencell)
9. [ValueCell and State Storage](#9-valuecell-and-state-storage)
10. [Pulse System](#10-pulse-system)
11. [Receptor and Instruction Pipelines](#11-receptor-and-instruction-pipelines)
12. [Synapses and Propagation](#12-synapses-and-propagation)
13. [Validation](#13-validation)
14. [Transactions](#14-transactions)
15. [Governance and Security](#15-governance-and-security)
16. [Lifecycle Policies](#16-lifecycle-policies)
17. [Concurrency and Locks](#17-concurrency-and-locks)
18. [Async and Stream Integration](#18-async-and-stream-integration)
19. [Nucleus and Hydration](#19-nucleus-and-hydration)
20. [Internal Utilities](#20-internal-utilities)
21. [Ecosystem Packages](#21-ecosystem-packages)
22. [Documentation and Examples](#22-documentation-and-examples)
23. [Use-Case Decision Matrix](#23-use-case-decision-matrix)
24. [Known Gaps](#24-known-gaps)
25. [Quick Reference](#25-quick-reference)

---

## 1. What Cell Is

Cell is a reactive state-management library for Dart. A **cell** is a node in a directed graph. A **pulse** is the immutable message that moves a change through that graph. Operators (`Cell.state`, `Cell.observe`, …) wire nodes together.

The design intent, compared with opaque stream-of-values libraries:

- State changes can carry **causal history** (trace, parent chain, source).
- **Validation** is a first-class gate (`TestCell`), not a callback you remember to call.
- Restricted views are **proxies**, not copies (`Cell.deputy()`, `cell.unmodifiable`).
- **When** observers are notified is a framework concern (`PropagationPolicy`), not ad-hoc `Timer` code.
- Multi-cell consistency has two explicit mechanisms: buffered writes (`Cell.transaction`) and staged commands with compensation (`Cell.txApply`).

Nothing is authorized, redacted, TTL-limited, or audited unless you pass a rule. Defaults are pass-through and allow-all.

---

## 2. Status and Boundaries

**RC (Release Candidate).** Package version `1.0.0-rc.1`. Public APIs for cells, pulses, operators, transactions, integrity gates, context, deputy, and commons are exercised end-to-end. Breaking changes remain possible before a versioned 1.0 stable, but they should follow documented contracts rather than silent private-API drift.

| Claim | Reality |
|-------|---------|
| Published on pub.dev | Not published. Depend from source / git. |
| Production-ready | No. No independent security or correctness audit. |
| Regulatory compliance (GDPR, HIPAA, PCI-DSS) | Metadata fields exist so *you* can attach classification, purpose, and actor. Cell does not implement or certify compliance. |
| `Context.describe('…')` | Stores a description string. It is not a legal basis, retention schedule, or audit log. |
| Unit tests | **1115** tests in **20** files named `test_*.dart` (not `*_test.dart`). Last full run **1115 passed**. Bare `dart test` finds nothing — pass explicit files. See [`TEST_VERIFICATION.md`](TEST_VERIFICATION.md). |
| Line coverage | **95.9%** of instrumented `lib/` (3397 / 3541). Measured coverage, not a production-readiness certificate. |

Dependencies: `uuid`, `synchronized`, `meta`.

---

## 3. Progressive Disclosure

Four concentric tiers. You only learn a tier when you need it.

| Tier | What you use | When |
|------|----------------|------|
| **1. Entry** | The Core 16 operators | Day-to-day application code. Zero knowledge of Receptor / TestCell / Context / Synapses required. |
| **2. Composition** | Custom `Receptor` / `Instruction`, `Synapses` + `PropagationPolicy` | Built-in operator behavior is not enough. |
| **3. Governance** | `TestCell`, `Context`, `DeputyContext`, `PulseContext` | Explicit rules about who can do what. Off by default. |
| **4. Internal** | `Nucleus`, `Cell.governed`, `Cell.fromNucleus`, policy internals | Extending the framework, custom operators, high-integrity nodes. |

If a Tier 1 operator required Nucleus knowledge to use correctly, that would be a design smell.

---

## 4. Core Reactive Primitives

| Primitive | Role |
|-----------|------|
| **`Cell`** | Node that holds state or relays signals. Validates incoming changes and broadcasts accepted ones. |
| **`OpenCell`** | Cell with a public `emit` / `ingest` / `link` surface for imperative injection and dynamic topology. |
| **`ValueCell<V>`** | Stateful cell with a persistent `Box<V>`. Returned by `Cell.state`. |
| **`Pulse<P>`** | Immutable signal: payload, type tag, priority, optional provenance, iterable over its own trace. |
| **`Receptor`** | Transformation pipeline a cell runs incoming pulses through. |
| **`Instruction`** | Single stage (or chain of stages) inside a receptor. |
| **`Synapses`** | Observer registry and distribution mechanism, with pluggable propagation strategies. |
| **`TestCell` / `TestRule`** | Validation gate for mutations, links, pulses, and `apply` actions. Combine with `+`. |
| **`Context` / `DeputyContext` / `PulseContext`** | Optional metadata: domain, authority, provenance. Attached at cell, deputy, or pulse level. |
| **`Nucleus`** | Immutable configuration bundle a cell wraps: receptor, test rule, context, synapses, optional lock and bind. |

### Update cycle

Every accepted change, regardless of which operator produced it, goes through the same cycle:

1. **Validate** against the cell’s `TestCell`.
2. **Transform** through the `Receptor` pipeline.
3. **Commit** under the cell’s `Lock` (when present).
4. **Broadcast** via `Synapses` to observers.

### Identity

A cell obtained via `deputy` or `unmodifiable` is a **proxy**, not a copy. It shares the principal’s storage and lock.

```dart
cell == cell.deputy()  // true — interchangeable in Set / Map
```

What differs is what each is *permitted* to do, never what data it holds. Deputy rules are **additive-only**: they can only narrow permissions.

---

## 5. Standard Entry Operators

The documented **Core 16** — ordered for a learning path: get data in → hold state → react → shape streams → go async → combine → isolate writes.

Each works with defaults: `Receptor.passThrough`, `TestCell.allowAll`, `Context.system`, `Synapses.enabled`.

### Phase 1 — Get data in, hold state, react

#### 1. `Cell.state<V>()`

Persistent mutable state atom.

```dart
static StateHandle<V> state<V>({
  V? initial,
  Pulse<V>? Function(ValueCell<V> host, Pulse input)? evolve,
})
```

| | |
|---|---|
| **Returns** | `StateHandle<V>`: `cell`, `update(V?)`, `updateAsync(V?)`, `ingest(Pulse<V>, {serializedCompletion})` |
| **Behavior** | `initial` is written directly to storage (bypasses evolve). `evolve` returning `null` rejects the update. State cells allocate their own lock by default. |
| **Use when** | Counters, settings, profiles, form fields, any retained value you read and update. |

#### 2. `Cell.ingress<I>()`

Stateless event gateway. No retained value.

```dart
static IngressHandle<I> ingress<I>({
  Pulse<I?>? Function(Cell host, Pulse<I> input)? refine,
  EphemeralPolicy? ephemeralPolicy,
  Cell? source,
  Context context = Context.system,
  Receptor receptor = Receptor.passThrough,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
  bool forceLock = false,
})
```

| | |
|---|---|
| **Returns** | `IngressHandle<I>`: `cell`, `emit(I)`, `emitAsync(I)`, `ingest(Pulse<I>, {serializedCompletion})` |
| **Behavior** | `refine` may transform or drop (`null`). `ingest(..., serializedCompletion: true)` awaits the whole downstream cascade. |
| **Use when** | Button clicks, WebSocket messages, sensors, tests, any imperative event that should enter the graph. |

#### 3. `Cell.observe<P>()`

Terminal side-effect sink. Does not propagate further.

```dart
static EgressHandle<P> observe<P extends Pulse>({
  required Cell source,
  required void Function(P pulse) effect,
  bool initiallyStarted = true,
})
```

| | |
|---|---|
| **Returns** | `EgressHandle<P>`: `cell`, `start()`, `stop()` |
| **Behavior** | `stop()` pauses effects without unlinking. Create dormant with `initiallyStarted: false`. |
| **Use when** | UI rebuilds, logging, persistence, analytics, hardware commands. |

#### 4. `Cell.derive<I, O>()`

Pure 1-to-1 projection. Stateless.

```dart
static Cell derive<I extends Pulse, O extends Pulse>({
  required Cell source,
  required O Function(I input) project,
})
```

| | |
|---|---|
| **Behavior** | Result is an `EvolvedPulse` (causal lineage preserved). `project` returning `null` suppresses the signal. |
| **Use when** | View-models, formatting, type conversion, extracting a field, implicit filtering. |

### Phase 2 — Shape streams

#### 5. `Cell.debounce()`

Emit after a silence window (Rx `debounceTime`).

```dart
static Cell debounce(Cell source, Duration duration, {bool leading = false, EphemeralPolicy? ephemeralPolicy})
```

| | |
|---|---|
| **Behavior** | Each new pulse resets the timer. Only the latest value is emitted after `duration` of quiet. `leading: true` also emits the first pulse of a burst immediately. A hosted `ephemeralPolicy` uses a governed output receptor; reclaim cancels a pending timer. |
| **Use when** | Search-as-you-type, autosave, form validation, resize handlers. |

#### 6. `Cell.distinct()`

Skip consecutive duplicate **payloads**.

```dart
static Cell distinct(Cell source, {bool Function(dynamic previous, dynamic next)? equals})
```

| | |
|---|---|
| **Behavior** | First pulse always passes. Sequence `1, 2, 1` emits three times. Comparison is payload-scoped; timestamps / trace are ignored. Default equality is `==`. |
| **Use when** | Avoid redundant rebuilds, skip identical sensor heartbeats, suppress no-op transitions. |

#### 7. `Cell.throttle()`

Cap emission frequency.

```dart
static Cell throttle(
  Cell source,
  Duration duration, {
  bool leading = true,
  bool trailing = false,
})
```

| | |
|---|---|
| **Behavior** | Default: first pulse immediate, rest of the window dropped. `trailing: true` also emits the last pulse when the window ends. |
| **Use when** | Scroll / pointer sampling, API rate limits, ~60 fps UI, sensor downsampling. |

### Phase 3 — Go async

#### 8. `Cell.asyncMap<S, T>()`

Map each payload to a `Future<T>` with concurrency control.

```dart
static Cell asyncMap<S, T>(
  Cell source,
  Future<T> Function(S value) mapper, {
  int concurrency = 0,
  bool latestOnly = false,
  bool exhaust = false,
})
```

| Mode | How |
|------|-----|
| **Parallel** | `concurrency: 0` (default) — all futures run; results may complete out of order. |
| **Sequential** | `concurrency: 1` — wait for the current future before starting the next. |
| **Limited** | `concurrency: N` — at most N in flight. |
| **Switch** | `latestOnly: true` — ignore results of superseded futures. |
| **Exhaust** | `exhaust: true` — ignore upstream while a future is in flight. |

Failed futures terminate that signal (they do not enter the graph). Lineage is preserved across the async boundary via `EvolvedPulse`.

**Use when:** HTTP, DB, heavy compute, ID → profile enrichment.

#### 9. `Cell.fromFuture<T>()`

Bridge a one-shot `Future` into a cell. Emits at most once.

```dart
static Cell fromFuture<T>(Future<T> future)
```

| | |
|---|---|
| **Behavior** | Success emits the value. Failures emit a pulse with `type: 'error'` and the error as payload. Invalidating the cell before completion discards the result. The cell stays alive after emission unless you invalidate it. |
| **Use when** | Config load, one-shot API, adapting an existing `async` API. |

#### 10. `Cell.fromStream<T>()`

Bridge a Dart `Stream` into a cell.

```dart
static Cell fromStream<T>(Stream<T> stream, {bool cancelOnError = false})
```

| | |
|---|---|
| **Behavior** | No replay of past events. Default: stream errors are ignored. `cancelOnError: true` tears down the subscription on error. |
| **Caveat** | The subscription is cancelled on cell invalidation / GC. Pass `ephemeralPolicy` when you need an explicit TTL or event-budget teardown. |
| **Use when** | WebSockets, file watchers, `Stream.periodic`, third-party SDK streams. |

#### 11. `Cell.switchMap<S, T>()`

Follow the latest inner **cell** produced by a mapper.

```dart
static Cell switchMap<S, T>(Cell source, Cell Function(S value) mapper)
```

| | |
|---|---|
| **Behavior** | Does **not** emit the source value. Unlinks the previous inner cell automatically. Silent until the current inner cell emits. |
| **Use when** | Selected user / tab / locale → active upstream. Contrast with `asyncMap`, which maps to a `Future`, not a `Cell`. |

### Phase 4 — Combine and route

#### 12. `Cell.synthesis<P>()`

Aggregate several sources into one consensus pulse.

```dart
static Cell synthesis<P extends Pulse>(
  Iterable<Cell> sources, {
  required P? Function(Iterable<Cell> cells, Pulse emit) aggregator,
})
```

| | |
|---|---|
| **Behavior** | Fires when **any** source emits. Aggregator sees all sources plus the triggering pulse. Returning `null` suppresses. If sources update inside one `Cell.transaction`, the aggregator fires once at commit (no intermediate glitch). |
| **Use when** | Forms, dashboards, multi-sensor fusion, “enable submit when all fields valid”. |

#### 13. `Cell.hub()`

Route by `Pulse.type` to named spokes.

```dart
static HubHandle hub({
  Map<String, Pulse? Function(Cell cell, Pulse pulse, {dynamic user})>? spokes,
  Map<DeputyContext, Receptor>? governedSpokes,
  List<SpokeRegistration>? registrations,
  HubRouting routing = HubRouting.exact,
  bool multicast = false,
  String? fallback,
  Synapses Function(String role)? distribution,
  void Function(Pulse pulse)? relay,
  Cell? source,
})
```

**Routing modes (`HubRouting`):**

| Mode | Match |
|------|--------|
| `exact` | `Pulse.type` equals spoke key |
| `prefix` | Longest prefix wins |
| `pattern` | `*` and `?` wildcards |
| `multicast` | Every matching spoke |

`SpokeRegistration` adds priority, custom `match`, handler **or** receptor, and optional `DeputyContext` per spoke. Higher priority is evaluated first. Custom `relay` bypasses default routing.

**Returns** `HubHandle`: `root`, `spokes`, `emit`, `emitAsync`, `ingest`.

**Use when:** Event buses, command dispatch, WebSocket demux, telemetry fan-out.

#### 14. `Cell.sanitized<P>()`

Redact payloads at or above a sensitivity threshold. Source cell is unchanged.

```dart
static Cell sanitized<P extends Pulse>(
  Cell source, {
  required P Function(P pulse) redact,
  Sensitivity minSensitivity = Sensitivity.confidential,
})
```

Missing sensitivity is treated as `Sensitivity.public` (no redaction). Redacted pulses are `EvolvedPulse` instances (lineage kept).

**Use when:** UI / log / telemetry views of PII or credentials. This is a building block, not a compliance program.

### Phase 5 — Orchestration

#### 15. `Cell.transaction()`

Multi-cell buffered writes. Locks are taken at **commit**, not for the whole `begin`…`commit` window.

```dart
static TransactionScope transaction([
  TransactionOptions options = const TransactionOptions(),
])
```

See [Transactions](#14-transactions).

#### 16. `Cell.open()` / `Cell.txApply()`

`Cell.open` is the Core-16 entry for manual topology (see [OpenCell](#8-opencell)). `Cell.txApply` stages `cell.apply(...)` calls with compensation (see [Transactions](#14-transactions)).

---

## 6. Additional Cell Factories

These exist on `Cell` but sit outside (or beside) the Core 16 numbering.

### `Cell.valve<P>()`

Conditional gate. Implemented.

```dart
static Cell valve<P extends Pulse>(
  Cell source,
  bool Function(P pulse) gate, {
  Synapses synapses = Synapses.enabled,
})
```

`true` forwards the original pulse; `false` drops it before synapses (debounce timers etc. never start). Stateless — no memory of the last passed value (use `distinct` for history).

**Use when:** Auth gates, feature flags, empty-query suppression, maintenance-mode pruning.

> Older README text said valve was unimplemented. The factory exists in `lib/src/cell.dart` and `example/valve_demo.dart`.

### `Cell()` — generic constructor

Stateless relay / custom processor.

```dart
factory Cell({
  Cell? bind,
  Receptor receptor,   // default passThrough
  TestCell testRule,   // default allowAll
  Synapses synapses,   // default enabled
})
```

Prefer `state` / `ingress` for application code. Use this for custom relays.

### `Cell.governed()`

All governance parameters explicit. No silent system fallback for context.

```dart
factory Cell.governed({
  EphemeralPolicy? ephemeralPolicy,
  Context context,
  Cell? bind,
  Receptor receptor,
  TestCell testRule,
  Synapses synapses,
  bool forceLock,
})
```

Governed cells participate in a **reciprocal handshake**: pulse and receptor scrutinize each other’s context; either side can neutralize the pulse.

**Use when:** TTL, authority tiers, or a dedicated lock. Not for typical app state.

### `Cell.fromNucleus(Nucleus)`

Hydrate a live cell from a nucleus blueprint.

If the nucleus is already activated it is **cloned** so two cells do not share activation state. Lock, receptor, test rule, context, synapses, and hosted `ephemeralPolicy` are inherited. Bind is linked after hydration; a failed link still leaves the cell initialized.

**Use when:** Reconstructing from a blueprint, cloning behavior, framework-level infrastructure. Application code should rarely need this.

### `OpenCell.perform()`

Open cell bound to a source, running a `perform` function on each injected pulse.

```dart
static OpenCell perform(
  Cell source,
  Pulse? Function(Cell on, Pulse pulse, {dynamic user}) perform, {
  dynamic user,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
})
```

---

## 7. Cell Instance API

Every cell exposes:

| Member | Purpose |
|--------|---------|
| `validate` | The cell’s `TestCell` |
| `context` | Operational `Context` (immutable for that instance) |
| `isTerminal` | No outgoing broadcast (e.g. observe sinks) |
| `isInvalidated` | Hosted `EphemeralPolicy` has started teardown (`Nucleus.isInvalidated` / `Cell.isInvalidated` follow that policy; a deputy without its own policy follows the principal) |
| `isGoverned` | Managed by an explicit policy / context perimeter |
| `deputy({context, testRule, ephemeralPolicy, synapses})` | Capability-narrowed proxy; contextual lineage required (`context.parent == this.context`, or `DeputyContext.system` as root) |
| `unmodifiable` | Read-only deputy (`TestCell.readOnly`; empty `modifiable`) |
| `apply(function, {positionalArguments, namedArguments, tx, compensate, …})` | Command-pattern gateway. Function must be in `modifiable`. Returns `null` if the integrity gate rejects. |
| `modifiable` | Whitelist of functions `apply` may invoke |
| `async` | `ModifiableAsync` wrapper — operations scheduled through the cell lock, results as `Future` |

Deputy creation is a no-op (returns `this`) if requested parameters match the current configuration.

---

## 8. OpenCell

`OpenCell` extends `Cell` with a public injection / topology surface.

| Member | Purpose |
|--------|---------|
| `emit(Pulse)` | Inject a pulse (still validated; an async `testRule` is awaited) |
| `ingest(Pulse, {serializedCompletion})` | Async ingestion; `serializedCompletion: true` waits for graph stability |
| `link(Cell)` | Attach a downstream observer; returns an unlinker, or `null` if rejected |
| `deputy(...)` | Returns an `OpenCell` deputy (typed) |
| `async` | `OpenCellAsync` — non-blocking `emit` / `ingest` (with or without a lock) |
| `modifiable` | Whitelist includes `emit`, `ingest`, `link`, and `apply` |

Factories: `OpenCell()`, `OpenCell.governed()`, `Cell.open()`, `OpenCell.perform()`.

Even “open” cells are not backdoors: `testRule` and `context` still apply to emit and link.

---

## 9. ValueCell and State Storage

`ValueCell<V>` is the concrete stateful type behind `Cell.state`.

- Storage is a `Box<V>` shared with deputies (zero-copy).
- `ValueNucleus` forces a lock by default (unlike a generic `Nucleus`). `ValueNucleus.from` / `ValueNucleus.evolve` pair an `Instruction` (or custom receptor) with `postProcessRule`.
- `ValueCell.postProcessRule` is the commitment instruction that writes `pulse.payload` into the box. Custom receptors must include it or state will not persist — prefer `ValueCell.receptor(...)` which pre-wires that rule.
- `ValueCell.terminal` holds state with `Synapses.disabled` (no broadcast).
- `UnmodifiableValueCell<V>` is the read-only view; a nested `Cell` payload is projected as `unmodifiable`.
- `ValueCellAsync<V>` is the async wrapper (`async.state` / `updateAsync`).

`StateHandle<V>` fields: `cell`, `update`, `updateAsync`, `ingest`.

---

## 10. Pulse System

### Construction

| Factory | Use |
|---------|-----|
| `Pulse(payload, {type, source, priority, step})` | Ungoverned pulse. Still has timestamp and trace. Default context is `PulseContext.system`. |
| `Pulse.governed({policy, context, payload, type, source, step, priority, onComplete, onError, onProgress})` | TTL / hop limits, provenance, lifecycle callbacks. Callbacks are inherited through `evolve`. |
| `Pulse.batch(pulses, …)` | Flat `CollectivePulse` — atomic bundle, not a causal chain. |

Default priority is `20` (0–100, higher = more urgent). Suggested bands: 0–20 background, 21–50 routine, 51–80 user, 81–95 critical, 96–100 emergency.

### Types

| Type | Meaning |
|------|---------|
| `Pulse<P>` | Iterable over its lineage; `Comparable` |
| `EvolvedPulse<P>` | Child of another pulse; payload inherited from root (not copied) |
| `CollectivePulse<P>` | Bundle; `payload` is `Iterable<Pulse<P>>` |
| `UnmodifiablePulse<P>` | Frozen view |
| `PulseShell` | Defensive proxy; receivers must pass `scrutinize` before seeing the kernel |

### Properties and operations

| Member | Purpose |
|--------|---------|
| `payload` | Data (walks to root for evolved pulses) |
| `type` | Semantic tag used by hubs |
| `source` | Originating cell |
| `priority` | Urgency |
| `timestamp` | Creation time |
| `context` | `PulseContext` |
| `policy` | Optional `PulseEphemeralPolicy` |
| `trace` | Step breadcrumbs |
| `root` / `parent` | Lineage |
| `isComposite` / `isInvalidated` / `isGoverned` | Flags |
| `withStep(String)` | Append a trace step |
| `evolve(...)` | New child pulse with inherited payload / callbacks |
| `scrutinize(receptor, …)` | Reciprocal handshake; `null` = neutralized |
| `shell` | `PulseShell` wrapper |
| `unmodifiable` | Frozen view |

### Fluent extensions (`PulseExtension` and `PulseIterableExtension`)

The `cell` package provides two primary extension groups to manipulate individual signals and collections of signals fluently while preserving their causal lineage and provenance.

#### 1. `extension PulseExtension`
Applied directly to an instance of `Pulse<P>`.

| Method | Signature | Purpose |
|--------------------|-----------|---------|
| `map<T>` | `Pulse<T> map<T>(T Function(P payload) mapper)` | Transforms the payload of this pulse into a new type `T` while preserving its causal history and lineage. |
| `attach` | `Pulse<P> attach(dynamic context)` | Returns a new version of this pulse with updated context metadata attached without altering its core payload. |
| `tap` | `Pulse<P> tap(void Function(P payload) action)` | Executes a side-effect action using the current payload and returns this pulse instance for fluent chaining (peeking). |
| `cast<T>` | `Pulse<T> cast<T>()` | Re-casts the pulse payload to type `T` at runtime while maintaining causal history and type safety. |

#### 2. `extension PulseIterableExtension`
Applied to an `Iterable<Pulse>` collection to manage atomic batching, flattening, and bulk transformations.

| Method | Signature | Purpose |
|--------------------|-----------|---------|
| `batch` | `Pulse batch()` | Aggregates multiple signals into a single, flat `CollectivePulse` for atomic batching. |
| `flatten` | `Iterable<Pulse> flatten()` | Recursively flattens any nested `CollectivePulse` structures into a linear sequence of simple pulses. |
| `withStep` | `Iterable<Pulse> withStep(String step)` | Appends a diagnostic stage to the causal trace of every pulse in the collection simultaneously. |
| `attach` | `Iterable<Pulse> attach(dynamic context)` | Returns a new collection of pulses, each with the provided context metadata attached. |
| `mapEach<T>` | `Iterable<Pulse<T>> mapEach<T>(T Function(dynamic payload) mapper)` | Transforms the payload of every pulse in the collection while preserving their individual causal traces. |

> **Note on Usage:** Because `Pulse` implements `Iterable`, standard iterable methods can sometimes conflict or shadow. The framework uses explicit extension structuring to ensure clean separation between single-pulse operations (`PulseExtension`) and collection operations (`PulseIterableExtension`).

### Sensitivity (on pulse / deputy context)

`public` < `internal` < `private` < `confidential` < `restricted` < `secret`

Used by `Cell.sanitized` and by rules you write. Not a legal classification by itself.

---

## 11. Receptor and Instruction Pipelines

### Receptor

| Factory | Purpose |
|---------|---------|
| `Receptor.passThrough` | Singleton no-op (default) |
| `Receptor((cell, pulse, {user}) => …)` | Closure receptor |
| `Receptor.instruction(Instruction, {user})` | Wrap one instruction |
| `Receptor.pipeline({instruction, preProcess, postProcess, reaction, init, user, isGoverned})` | Three-stage pipeline, optional reaction / init / governance |

`Receptor.async` (`ReceptorAsync`) runs the same pipeline without blocking the caller. Exceptions in an instruction are caught; the last good pulse is kept so a pipeline does not crash the graph.

### Instruction

| Factory | Purpose |
|---------|---------|
| `Instruction((pulse, {cell, user}) => …)` | Sync stage; `null` drops the signal |
| `Instruction.future((pulse, {cell, user, future, token}) => …)` | Suspend (`return null`), resume later via `future(result:, token:)` |
| `Instruction.chain(instructions, {user, strategy})` | Sequential (or custom-strategy) composition |

`Instruction.future` is the primitive behind debounce / throttle / delay-style operators. If the host cell is disposed before resume, the continuation is a no-op.

`InstructionChain` is itself an `Instruction`, so chains nest.

Walkthroughs: `example/receptor_pipeline_walkthrough.dart`, `example/instruction_pipeline_walkthrough.dart`.

---

## 12. Synapses and Propagation

### Synapses

| Factory / constant | Purpose |
|--------------------|---------|
| `Synapses.enabled` | Default. Flyweight; a real registry is allocated per cell. |
| `Synapses.disabled` | Terminal: `call` is no-op; `link` / `unlink` return `false`. Shared singleton. |
| `Synapses({policy, downstreams, filter, relay})` | Custom network |

| Method | Purpose |
|--------|---------|
| `call(pulse)` | Broadcast (framework-invoked) |
| `link(cell, {downstreamCell})` | Add observer (validated; deputies ≡ principals) |
| `unlink(cell, {downstreamCell})` | Remove observer |
| `async` | `AsyncSynapses` — non-blocking broadcast + async cycle checker |

A custom `relay` **replaces** sequential broadcast; you must deliver pulses yourself.

Cycle detection: a looping branch is silently terminated.

### FilterRule

Outgoing-pulse filter, chainable with `+` or `FilterRule.chain`. Returning `null` drops the pulse. Optional custom `strategy`. A chained `parent` is stored as `_record.parent` and actually runs.

### PropagationStrategy

Configured via `PropagationPolicy` on a synapse (independent of which operator produced the pulse).

| Strategy | Behavior |
|----------|----------|
| `immediate` | Default. Sync, same stack frame. |
| `async` | Next microtask / event-loop turn. |
| `batched` | Buffer until `batchSize` or time window; deliver as a collection. |
| `buffered` | Lossless time-window queue; flush as one composite event. |
| `debounced` | Trailing edge after `debounceTime` silence. |
| `throttled` | Leading edge, then drop until `throttleTime`. |
| `audit` | Trailing-edge sample at a fixed interval (freshest value). |
| `exhaust` | Drop new pulses while a previous one is still in flight. |
| `sample` | Heartbeat of the **first** captured pulse on `throttleTime`. Later ticks of that same instance are typically dropped by the cycle checker (observers usually see one delivery). Unlinking the last observer cancels `Timer.periodic` so it does not leak. |
| `resilient` | Circuit breaker on downstream failures. |
| `debounceLeading` | First pulse immediate, then silence window. |
| `retry` | Re-attempt failed downstream delivery (`batchSize` = max retries). |
| `persistent` | Newly linked observers receive the last pulse. |

### PropagationPolicy

```dart
PropagationPolicy({
  PropagationStrategy strategy,  // default immediate
  Duration debounceTime,         // default 150 ms
  Duration throttleTime,
  int batchSize,
})
```

Policy is per-synapse and immutable. Unused parameters for a given strategy are ignored.

---

## 13. Validation

### TestCell

| Built-in | Meaning |
|----------|---------|
| `TestCell.allowAll` | Singleton pass (`TestPasses`) — default |
| `TestCell.readOnly` | Blocks mutations |

Custom:

```dart
TestCell<C>((object, {host, arguments, user}) => /* FutureOr<bool> */)
TestCell.chain([rule1, rule2, …], {parent, strategy})
TestRule<C>((object, {host, arguments, user}) => /* FutureOr<bool> */)
TestRule.chain([rule1, rule2, …], {parent, strategy})
```

- Combine with `+`. Default strategy is **fail-fast**.
- Async rules (`Future<bool>`) make the whole chain wait, including a parent after this rule passes.
- Parent is evaluated **after** this rule passes (inheritance).
- A custom `strategy` replaces sequential evaluation (e.g. “any of these”).
- `TestRule` is the base integrity gate; `TestCell` extends it and orchestrates pulses, links, and `apply` actions. Equality / `hashCode` follow the flyweight record.

Specialized rule types: `TestPulseRule`, `TestLinkRule`, `TestActionRule`. `TestCell` implements all three (pulses, links, `apply` actions). `TestCell.action` validates positional **and** named arguments via `call`.

Deputies **layer** rules on the principal; they cannot widen authority.

### TestRule metadata (code-gen helpers)

Used by higher packages (`cell_organ` / `cell_ontogeny`) as annotations / reusable predicates:

| Type | Purpose |
|------|---------|
| `DefaultValue` | Compile-time default for generated fields |
| `MaxLength` | String / collection length |
| `ValueRange` | Numeric range |
| `EntryPattern` | Regex / pattern match |
| `Values` | Allow-list |
| `EmailPattern` | Email-shaped strings |
| `WebsiteUrlPattern` | URL-shaped strings |

---

## 14. Transactions

Two distinct mechanisms. Do not treat them as two syntaxes for the same thing.

### `Cell.transaction` — buffered value writes

```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
  timeout: Duration(seconds: 5),
  onEvent: (e) => print(e),
));
await tx.begin([from, to]);
final a = tx.read(from);
tx.update(from, a - 50);
tx.update(to, tx.read(to) + 50);
await tx.commit();
```

| Feature | Detail |
|---------|--------|
| **Pattern** | Stage `update` / `read`; apply together at commit |
| **Locks** | Held **only during commit** |
| **Savepoints** | `tx.savepoint()` + `rollback(savepoint: sp)` for partial undo |
| **Validation** | At commit: each cell’s `testRule` **and** optional `TransactionOptions.validate` |
| **Reentrant** | Not reentrant — commit or rollback before starting another |

**IsolationLevel**

| Level | Guarantee |
|-------|-----------|
| `readCommitted` (default) | Reads live values. Fastest. Lost-update possible if you read-then-write. |
| `repeatableRead` | Snapshot at `begin`. Commit aborts with `TransactionConflictException` if a participant changed. Does not prevent phantom reads on collections. |
| `serializable` | Repeatable read + read-set tracking + a global commit gate (total order). Safest, most expensive. |

**LockOrdering:** `byHashCode` (default, deadlock-safe), `insertion` (only safe if every tx uses the same order), `explicit` (custom comparator).

**Events:** `TransactionBegun`, `TransactionUpdated`, `TransactionCommitted`, `TransactionRolledBack`, `TransactionTimedOut`.

**Exceptions:** `TransactionValidationException`, `TransactionConflictException` (retry from `begin`), `TransactionTimeoutException`. Failed validation / conflict / timeout **auto-rollback**.

**Options:** `isolation`, `ordering`, `comparator`, `timeout`, `validate`, `apply` (replaces default write path), `onEvent`.

### `Cell.txApply` — staged `apply()` + compensation (saga)

```dart
final tx = Cell.txApply(TxApplyOptions(stopOnFirstFailure: true));
await tx.begin([cell1, cell2]);
cell1.apply(fn1, tx: tx, compensate: undo1);
cell2.apply(fn2, tx: tx, compensate: undo2);
await tx.commit();
```

| Feature | Detail |
|---------|--------|
| **Pattern** | Stage whitelisted function calls, not raw values |
| **Compensation** | Per-step undo; optional retry / backoff |
| **Reentrancy** | Nested `txApply` joins the parent scope |
| **Observers** | See the **final** graph state, not intermediate applies |

**CompensationErrorPolicy:** `bestEffort`, `failFast`, `collectThenThrow`.

**TxApplyOptions:** `onEvent`, `stopOnFirstFailure`, `comparator`, `compensateIfNotExecuted`, `compensationErrorPolicy`, `onCompensationFailures`, `compensationMaxAttempts`, `compensationBackoff`, `isRetryableCompensationError`.

**Events:** `TxApplyBegun`, `TxApplyStaged`, `TxApplyCommitted`, `TxApplyRolledBack`, `TxApplyRejected`, `TxApplyCompensationFailed`, `TxApplyCompensationRetry`.

**Exceptions:** `TxApplyException`, `TxApplyCompensationException`. `ApplyRejected` is the sentinel returned when a staged apply is denied.

Use **transaction** when coordinating cell *state*. Use **txApply** when coordinating *side-effecting functions* that need an undo path.

---

## 15. Governance and Security

All of this is **opt-in**. Defaults: `Context.system`, `DeputyContext.system`, `PulseContext.system`, `TestCell.allowAll`.

### Three parallel vocabularies

| Enum | Lives on | Role |
|------|----------|------|
| `Ontology` | `Context` | What the **node** is (domain, taxonomy, topology, version, …) |
| `Mandate` | `DeputyContext` | What a **proxy** may do (authority, role, clearance, isolation, …) |
| `Provenance` | `PulseContext` | Who / why / how a **signal** was produced (actor, reason, purpose, …) |

Static pillars cannot be changed via `evolve`. Evolvable dimensions can.

### Context (node identity)

**Factories**

| Factory | Typical use |
|---------|-------------|
| `Context.system` | Root / default |
| `Context.describe(String)` | Prose → stored description (not a compliance program) |
| `Context({…})` | Explicit ontology fields |
| `Context.fromEntries(...)` | Build from `GovernanceEntry` list |
| `Context.core` | Infrastructure node |
| `Context.module` | Application / business module |
| `Context.secureEnclave` | High-constraint perimeter |
| `Context.publicInterface` | External-facing surface |
| `Context.shieldedCortex` | Isolated reasoning / sensitive core |
| `Context.receptor` | Transformation-node tagging |
| `Context.integrityGate` | Validator-node tagging |
| `Context.homeostasis` | Self-maintenance node |
| `Context.sandbox` | Untrusted / experimental |
| `Context.auditLog` | Audit-oriented node |
| `Context.transientTask` | Short-lived work |
| `Context.deputy` / `Context.pulse` | Produce a `DeputyContext` / `PulseContext` from a base |

Ontology fields include: `type`, `identity`, `domains`, `dataSources`, `taxonomy`, `topology`, `version`, `subDomains`, `stakeholders`, `constraints`, `isNot`, `compliances`, `partOf`, `others`.

### DeputyContext (capability narrowing)

**Preset factories:** `observer`, `delegate`, `sandbox`, `intervention`, `janitor`, `architect`, `auditor`, `ambassador`, `shielded`, `gatekeeper`, `homeostasis`.

**Clearance** (ordinal, `authorizes`): `observational` < `minimal` < `standard` < `administrative` < `privileged` < `unrestricted`.

**Isolation:** `shared`, `scoped`, `restricted`, `sandboxed`, `total` — blast radius of a deputy (sandbox mutations are not committed to the principal).

Also: `Sovereignty`, `AuditLevel` (`none` … `full`), `ReasoningStrategy` (`manual`, `deterministic`, `probabilistic`, …), `PriorityTier`, `Sensitivity`.

Lineage: a deputy context must descend from the current context (`parent` chain). Jumping trees throws `AssertionError`.

### PulseContext (signal provenance)

**Factories:** `regulated`, `homeostasis`, `systemInternal`, `userAction`, `complianceAudit`, `aiInference`, `selfCorrection`, `infrastructureChange`, `securityIntervention`, `telemetry`, `inference`, `collaboration`, `hypothesis`, `instruction`.

Typical fields: actor, reason, purpose, sensitivity, strategy, trace identifiers. `Identity.next()` issues UUID v4 ids.

These attach metadata that **your** `TestCell` rules can read. The framework does not automatically enforce “purpose limitation” or write an audit log.

---

## 16. Lifecycle Policies

### EphemeralPolicy (cell TTL)

Attached to a cell / nucleus.

| Knob | Effect |
|------|--------|
| `duration` | TTL from **first interaction** (not construction) |
| `eventLimit` | Invalidate after N counted events |
| `onEvent` | Your counter logic (usage, errors, custom matches) |
| `onInvalidate` | Cleanup hook; return `true` to confirm |

A negative event count from `onEvent` ignores that event. The policy is stored on the nucleus inheritable record; after reclaim, `policy.isInvalidated`, `Nucleus.isInvalidated`, and `Cell.isInvalidated` are all `true`. An unused hosted policy stays live.

### PulseEphemeralPolicy (pulse TTL / hops)

| Knob | Effect |
|------|--------|
| `duration` | Pulse TTL (timer starts on first hop) |
| `hopLimit` | Max node traversals |
| `onEvent` | Called per hop; may update or reset `hops` |
| `onInvalidate` | Called when the pulse dies |

---

## 17. Concurrency and Locks

- Each cell **may** hold a `Lock` from `package:synchronized` (re-exported).
- The four-step update cycle runs inside that lock when present.
- `forceLock: true` on governed / open / ingress factories allocates a dedicated lock.
- Value cells get a lock by default.
- Sharing a nucleus lock groups cells into one atomic domain.

```dart
Future<T> withLocks<T>(Iterable<Lock?> locks, Future<T> Function() body)
Future<T> withCellLocks<T>(
  Iterable<Cell> cells,
  Future<T> Function() body, {
  int Function(Cell a, Cell b)? order,
})
```

Locks are acquired in deterministic order (default: `hashCode`) and released LIFO. `null` locks are skipped. Re-entrant locks are safe on the same isolate.

Async counterparts exist throughout so async callers are not a weaker path: `ReceptorAsync`, `AsyncSynapses`, `ValueCellAsync`, `OpenCellAsync`, `ModifiableAsync`.

The library is isolate-compatible in the Dart sense (no shared-memory mutation across isolates). It does not magically share cells across isolates.

---

## 18. Async and Stream Integration

| Feature | API |
|---------|-----|
| One-shot Future | `Cell.fromFuture` |
| Continuous Stream | `Cell.fromStream` |
| Async map | `Cell.asyncMap` (`concurrency`, `latestOnly`, `exhaust`) |
| Dynamic inner cell | `Cell.switchMap` |
| Await full cascade | `ingest(..., serializedCompletion: true)` on ingress / hub / state / open |
| Async observe / apply | `cell.async`, `receptor.async`, `synapses.async` |
| Instruction resume | `Instruction.future` + token |

Hybrid return types are `FutureOr<T>` where an operation may be sync or async depending on locks and rules.

---

## 19. Nucleus and Hydration

`Nucleus` is the immutable blueprint a cell wraps.

| Factory | Purpose |
|---------|---------|
| `Nucleus({…})` | Root blueprint; bitmask stores only non-defaults, including `ephemeralPolicy` (inheritable bit 8) |
| `Nucleus.evolve({principal, …})` | Prototype inheritance; `bind` is **not** inherited |
| `Nucleus.empty()` | Flyweight zero-state (`Nucleolus` singleton) |
| `Nucleus.create` / typed helpers | Custom cell types |

`Inheritable` / `InheritableHandle` support property resolution up the principal chain. `Nucleolus` is the empty root (`isInvalidated` is always `false`). `Nucleus.isInvalidated` follows a hosted `EphemeralPolicy`; clones copy that policy.

Activate with `Cell.fromNucleus`. Prefer `Cell.deputy` over manual `Nucleus.evolve` in application code.

---

## 20. Internal Utilities

Exported from `package:cell/cell.dart` (via `commons.dart` and related):

| Type | Purpose |
|------|---------|
| `Lock` | Re-exported from `synchronized` |
| `Box<T>` / `SyncBox<T>` / `FinalBox<T>` | Storage cells use internally |
| `SyncSet`, `QueueList`, `AsyncQueueList` | Locked / deque collections |
| `PriorityQueue`, `AsyncPriorityQueue`, `SyncQueue` | Ordered queues for propagation |
| `CycleChecker` / `SyncCycleChecker` | Graph cycle detection |
| `Unmodifiable` / `Async<C>` | Marker mixins |
| `FunctionObject` / `TypeObject` / `FunctionTypeObject` | Reflection helpers for `apply` |
| `SymbolConverter` | JSON conversion for `Symbol` |
| `SynthesisCell` | Concrete multi-source cell used by `Cell.synthesis` |

These are public because operators and higher packages need them. Application code should not reach for them unless building infrastructure.

---

## 21. Ecosystem Packages

Cell is the foundation. Sibling packages in this repo:

| Package | Layer | What it adds |
|---------|-------|----------------|
| **cell** (this) | Cell | Nodes, pulses, Core operators, governance, transactions |
| **cell_tissue** | Tissue | Grouped cells: list / map / set / queue / value collections with collective events |
| **cell_organ** | Organ | Relatable models: one/many relations, blend, cascade, entity fields |
| **cell_flow** | Flow | 79 uniquely named instruction operators on `Flow` (33 files under `lib/src/instruction/`); fluent chaining; `zip` / `combineLatest` in `nucleus/` |
| **cell_memory** | Memory | Persistence / stored models, columns, store operations |
| **cell_ontogeny** | Ontogeny | Code generation for models, interfaces, and references |

If you need Rx-style combinators (`merge`, `zip`, `window`, `scan`), look in **cell_flow**, not in this package.

Flutter: no dedicated widgets. Bind with `Cell.observe` (or any adapter) and call `setState` / notify your existing state library.

---

## 22. Documentation and Examples

### Guides (`guide/`)

| File | Topic |
|------|--------|
| `HowTo-Start.md` | Getting started |
| `HowTo-16_Essential_Operators.md` | Core operators, learning path |
| `HowTo-Instruction.md` | Instruction stages |
| `HowTo-Receptor.md` | Transformation pipelines |
| `HowTo-Synapses.md` | Linking, filters, propagation |
| `HowTo-TestCell.md` | Validation |
| `HowTo-Pulse.md` | Signals |
| `HowTo-PulseContext.md` | Pulse provenance |
| `HowTo-PulseEphemeralPolicy.md` | Pulse TTL / hops |
| `HowTo-Context.md` | Node identity |
| `HowTo-DeputyContext.md` | Restricted views |
| `HowTo-EphemeralPolicy.md` | Cell TTL / event budget |
| `HowTo-PropagationPolicy.md` | Delivery timing |
| `HowTo-Nucleus.md` | Blueprints |
| `HowTo-Transaction.md` | Buffered multi-cell writes |
| `HowTo-TransactionOnApply.md` | Staged apply + compensation |
| `HowTo-Advanced.md` | Index of optional machinery |

Also: `README.md` (overview + status), `ARCHITECTURE.md` (design intent), `TEST_VERIFICATION.md` (test inventory and measured `lib/` coverage), `KNOWN_ISSUES.md` (RC gaps).

Generate API docs: `dart doc .`  
Categories include Getting Started, Core, Core 16 Operators, Transactions, Governance, Advanced, and the primitive-specific topics.

### Runnable examples (`example/`)

| File | Demonstrates |
|------|----------------|
| `state_demo.dart` | `Cell.state` |
| `ingress_demo.dart` | `Cell.ingress` |
| `observe_demo.dart` | Side effects / start-stop |
| `derive_demo.dart` | Projections |
| `distinct_demo.dart` | Duplicate suppression |
| `throttle_demo.dart` | Rate limiting |
| `stability_search_demo.dart` | Debounced search |
| `async_map_demo.dart` | Concurrent async map |
| `synthesis_demo.dart` | Multi-source aggregation |
| `hub_demo.dart` | Routing |
| `sanitized_demo.dart` | Redaction |
| `valve_demo.dart` | Conditional gate |
| `open_cell_demo.dart` | Manual topology |
| `transaction_demo.dart` | Buffered transactions |
| `atomic_multi_update.dart` | `txApply` / compensation |
| `receptor_pipeline_walkthrough.dart` | Receptor pipelines |
| `instruction_pipeline_walkthrough.dart` | Instruction chains |

Some dartdoc comments still point at examples that are not in this package (`from_future_demo`, `from_stream_demo`, `switch_map_demo`, `stream_bridge_demo`). Related demos live under `packages/cell_flow/example/`.

### Tests (`test/`)

Files are named `test_*.dart`, not `*_test.dart`. Therefore:

- `dart test` with no path finds **no tests**
- `dart test test` is a name filter, not a directory
- Pass explicit files (see [`TEST_VERIFICATION.md`](TEST_VERIFICATION.md))

**1115** tests in **20** files. Last full run: **1115 passed / 0 failed / 0 skipped**. Measured `lib/` line coverage: **95.9%** (3397 / 3541). Suites cover Cell (including `valve` and `OpenCell.perform`), Pulse (`PulseExtension.map` / `cast` via `PulseExtension(pulse)`), Nucleus (`isInvalidated` follows a hosted `EphemeralPolicy`), Receptor (`pipeline` reaction / `isGoverned` / `PulseShell`), Instruction, Synapses (`FilterRule` parent/`fromRecord`, `PropagationStrategy.sample`), TestCell / TestRule, Context / DeputyContext / PulseContext, commons, `transaction`, `txApply`, and operator phases 1–4.

```bash
dart analyze lib
# PowerShell — all suites:
dart test @(Get-ChildItem test/test_*.dart | ForEach-Object { "test/$($_.Name)" })
dart format .
dart doc .
```

---

## 23. Use-Case Decision Matrix

### Use this package when you need

| Requirement | Feature |
|-------------|---------|
| Persistent reactive state | `Cell.state` + optional `TestCell` |
| Imperative events into a graph | `Cell.ingress` |
| UI / logging / persistence side effects | `Cell.observe` |
| Projections / view-models | `Cell.derive` |
| Multi-field forms / dashboards | `Cell.synthesis` |
| Multi-cell atomic writes | `Cell.transaction` |
| Side-effecting steps with undo | `Cell.txApply` |
| HTTP / DB with cancel-previous | `Cell.asyncMap(latestOnly: true)` |
| Follow a selected inner source | `Cell.switchMap` |
| Bridge `Future` / `Stream` | `fromFuture` / `fromStream` |
| Typed event routing | `Cell.hub` |
| Rate / silence control | `throttle` / `debounce` / synapse `PropagationPolicy` |
| Conditional flow | `Cell.valve` or `derive` returning `null` |
| Read-only or scoped handles | `unmodifiable` / `deputy` |
| Redacted egress views | `Cell.sanitized` |
| Provenance on signals | `PulseContext`, `withStep`, evolved pulses |
| Plugin / module boundary | `Cell.open` |
| Custom operator | `Nucleus` + `Instruction` + `Cell.fromNucleus` |
| Deadlock-free multi-lock | `withCellLocks` |

### Prefer something else when you only need

| Need | Simpler option |
|------|----------------|
| A counter or a couple of flags | `ValueNotifier`, a variable |
| Basic Flutter form state | Provider, Riverpod, or the widget itself |
| A simple event bus | `StreamController` |
| One API call | A `Future` |
| Rx combinators (merge, zip, window, scan) | **cell_flow**, or `dart:async` / RxDart |
| Battle-tested production SM today | A published, audited library |

### Complexity vs. fit

- **Small UI:** Provider / Riverpod / `setState` is less machinery.
- **Medium:** Cell is worth it if you already want validation, deputies, or transactions.
- **Complex / regulated-adjacent:** Cell’s provenance, TestCell, and transactions are the point — still bring your own legal and operational controls.

---

## 24. Known Gaps

Honest list, so this catalog does not over-promise:

1. **RC APIs** — operator lists and guide names have moved; treat Core 16 numbering as a learning order, not a stability guarantee.
2. **`fromStream` teardown** — the subscription is cancelled on invalidation / GC; attach `ephemeralPolicy` when you need an explicit TTL or event budget.
3. **Guides vs. code** — still being reconciled. Prefer this file + source over stale comments (e.g. “HowTo-17_Essential_Operators”). HowTo examples may mention private `_nucleus`; the unit tests use public APIs only.
4. **Valve** — implemented (`Cell.valve`, `example/valve_demo.dart`, tests). Generated `doc/api/` HTML may still lag until `dart doc` is regenerated.
5. **No pub.dev, no audit, no compliance certification.**
6. **Transaction / compensation internals** have not been independently reviewed end-to-end. Treat as RC for money/inventory until you have your own review.
7. **Remaining lower `lib/` line coverage** — `context.dart` 90.3%, `internal/pulse.dart` 90.4%, `receptor.dart` 90.5% (InstructionChainMixin). Leftover lines are mostly combinatorial flyweight arms (see `TEST_VERIFICATION.md`).

---

## 25. Quick Reference

### Operators at a glance

| Operator | Kind | Returns | One-line |
|----------|------|---------|----------|
| `state` | Entry | `StateHandle<V>` | Persistent state |
| `ingress` | Entry | `IngressHandle<I>` | Manual events |
| `observe` | Entry | `EgressHandle<P>` | Side effects |
| `derive` | Entry | `Cell` | Pure projection |
| `debounce` | Shape | `Cell` | After silence |
| `distinct` | Shape | `Cell` | Skip consecutive dupes |
| `throttle` | Shape | `Cell` | Max frequency |
| `valve` | Shape | `Cell` | Predicate gate |
| `asyncMap` | Async | `Cell` | `Future` per item |
| `fromFuture` | Async | `Cell` | One-shot Future |
| `fromStream` | Async | `Cell` | Stream bridge |
| `switchMap` | Async | `Cell` | Latest inner cell |
| `synthesis` | Combine | `Cell` | Fan-in / consensus |
| `hub` | Combine | `HubHandle` | Route by type |
| `sanitized` | Combine | `Cell` | Redact by sensitivity |
| `open` | Topology | `OpenCell` | Manual emit / link |
| `transaction` | Orchestrate | `TransactionScope` | Buffered multi-write |
| `txApply` | Orchestrate | `ApplyTransactionScope` | Staged apply + undo |
| `Cell()` / `governed` / `fromNucleus` | Low-level | `Cell` | Custom / infra |

### Transaction comparison

| | `Cell.transaction` | `Cell.txApply` |
|--|--------------------|----------------|
| Stages | Values (`update` / `read`) | Commands (`apply`) |
| Undo | Rollback / savepoints | Per-step `compensate` |
| Locks | Commit-time | Participant coordination |
| Nested | Not reentrant | Joins parent |
| Best for | Money, stock, form commit | Sagas, side effects |

### Governance defaults

| Type | Default | Required? |
|------|---------|-----------|
| `Context` | `Context.system` | No |
| `DeputyContext` | `DeputyContext.system` | No |
| `PulseContext` | `PulseContext.system` | No |
| `TestCell` | `TestCell.allowAll` | No |
| `EphemeralPolicy` | none | No |
| `PulseEphemeralPolicy` | none | No |
| `PropagationPolicy` | `immediate` | No |

### Design patterns (mapped)

| Pattern | Where |
|---------|--------|
| Observer | Cell ↔ Synapses |
| Command | Pulse; `Cell.apply` + `modifiable` |
| Proxy | Deputy / unmodifiable |
| Strategy | Receptor, TestCell, Synapses, PropagationStrategy |
| Chain of Responsibility | Instruction / TestCell / FilterRule `+` |
| Unit of Work | `Cell.transaction` |
| Saga | `Cell.txApply` |
| Mediator | `Cell.hub` |
| Guard | TestCell |
| Decorator | Operator chaining |
| Prototype | `Nucleus.evolve` |
| Flyweight | `Synapses.enabled/disabled`, `Context.system`, empty nucleus |

---
