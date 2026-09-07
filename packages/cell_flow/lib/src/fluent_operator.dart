// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_flow.dart';

/// Synthesizes a **Fluent Topographical Ingress**—a specialized orchestration
/// extension designed to initiate pulse evolution directly from a [Cell].
///
/// [CellFlowOperators] serves as the primary entry point for constructing
/// reactive pipelines. By extending the [Cell] primitive, it allows for a
/// declarative, chainable syntax that transforms stateful pulses into
/// dynamic topographical branches.
///
/// Instead of nesting static factories:
/// ```dart
/// Flow.map<int, String>(
///   Flow.filter<int>(source, test: (n) => n > 0).cell,
///   project: (n) => '$n',
/// );
/// ```
///
/// You can synthesize the topography fluently:
/// ```dart
/// source
///     .filter<int>(test: (n) => n > 0)
///     .map<int, String>(project: (n) => '$n');
/// ```
///
/// ### When to use
/// - **Pipeline Initiation**: Starting a new sequence of instructions
///   anchored to a specific stateful stimulus origin.
/// - **Readability**: Reducing the cognitive load of deeply nested
///   orchestration logic.
/// - **Topographical Exploration**: Rapidly prototyping evolution paths
///   from existing cells.
///
/// ### How it works
/// 1. **Anchor Identification**: The extension identifies the [Cell]
///    as the **Stimulus Origin** for all subsequent evolution.
/// 2. **Factory Delegation**: Each operator delegates materialization
///    to the authoritative [Flow] static factories.
/// 3. **Handle Materialization**: Every method returns a [FlowHandle],
///    which provides both the **Anchor Node** (via the `cell` field) and
///    the **Signal Ingress** controls (`emit`, `emitAsync`, and `ingest`).
///
/// ### Non‑obvious
/// - **Stateless Blueprinting**: The operators themselves do not store
///   state; they merely define the blueprint for how pulses should
///   traverse the newly created topographical branch.
/// - **Chain Continuation**: Once a [FlowHandle] is returned, further
///   evolution is managed by the sibling [FlowOperators] extension.
///
/// ### See Also
/// * [Flow]: The authoritative registry of orchestration factories.
/// * [FlowOperators]: Extensions for continuing evolution from a handle.
/// * [FlowHandle]: The materialized interface for topographical ingress.
extension CellFlowOperators on Cell {

  /// Synthesizes a **Fixed Sequence Bridge** from a provided collection.
  ///
  /// This operator initiates a topography branch that immediately evolves
  /// the contents of [values] as individual stimuli. It transforms a static
  /// collection into a sequence of pulses anchored to the current cell,
  /// effectively seeding the new branch with initial data.
  ///
  /// ### When to use
  /// - **Topographical Seeding**: Providing a starting set of data that
  ///   should be processed immediately upon branch materialization.
  /// - **Collection Flattening**: Converting a standard [Iterable] into
  ///   a reactive sequence of pulses for downstream evolution.
  /// - **Static Injection**: Injecting a known set of payloads into the
  ///   graph without requiring external ingress.
  ///
  /// ### How it works
  /// 1. **Stimulus Initiation**: The operator triggers upon materialization
  ///    relative to the source cell.
  /// 2. **Iterative Evolution**: The bridge iterates through the [values]
  ///    collection synchronously.
  /// 3. **Pulse Materialization**: Each item in the collection is
  ///    emitted as a distinct pulse, preserving the order of the source.
  ///
  /// ### Non‑obvious
  /// - **Synchronous Exhaustion**: The entire collection is materialized
  ///   immediately. If the collection is large and the topography is
  ///   complex, this may block the current execution frame.
  /// - **One-Time Trigger**: Once the initial sequence is evolved, the
  ///   bridge remains idle unless the source cell triggers a re-ingress.
  ///
  /// ### Parameters:
  /// - [values]: The **Static Payload Collection** to be evolved as pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the newly established evolution branch.
  FlowHandle of<T>({required Iterable<T> values}) =>
      Flow.of<T>(this, values: values);

  /// Synthesizes an **Iterative Pulse Bridge** from a dynamic iterable.
  ///
  /// This operator treats the provided [iterable] as a sequence of potential
  /// stimuli to be materialized into the topography. Every time the source
  /// cell ingress occurs, the bridge iterates through the collection and
  /// evolves each element as a distinct pulse.
  ///
  /// ### When to use
  /// - **Dynamic Sequencing**: Transforming a collection that may change
  ///   between materializations into a reactive pulse stream.
  /// - **Generator Integration**: Bridging a lazy `Iterable` or generator
  ///   function into the reactive graph.
  /// - **Batch Evolution**: Processing multiple items as a single burst
  ///   triggered by a specific cell state change.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The bridge awaits a trigger pulse from
  ///     the source cell.
  /// 2. **Iterative Materialization**: Upon ingress, the [iterable] is
  ///    traversed, converting each payload into a new stimulus.
  /// 3. **Pulse Evolution**: Each payload is emitted sequentially,
  ///    inheriting the priority and provenance of the trigger pulse,
  ///    tagged with the `'FromIterable'` step.
  ///
  /// ### Non‑obvious
  /// - **Synchronous Blocking**: The iteration occurs synchronously. If the
  ///   [iterable] is extremely large or infinite, it will block the
  ///   reactive engine's evolution cycle.
  /// - **Pulse Distinction**: Every item in the iterable results in a unique
  ///   pulse; they are not batched into a single downstream materialization.
  ///
  /// ### Parameters:
  /// - [iterable]: The **Dynamic Sequence** of payloads to be evolved.
  ///
  /// ### Returns:
  /// A [FlowHandle] providing the anchor node for the iterative branch.
  ///
  /// ### See Also
  /// * [of]: For materializing fixed, static collections.
  /// * [range]: For generating a sequence of integer stimuli.
  FlowHandle fromIterable<T>({required Iterable<T> iterable}) =>
      Flow.fromIterable<T>(this, iterable: iterable);

  /// Synthesizes a **Counted Pulse Generator**—a specialized bridge
  /// designed to evolve a sequence of arithmetic integers.
  ///
  /// [range] transforms a single trigger stimulus from the source cell into
  /// a deterministic sequence of pulses. It is commonly used to initiate
  /// loops or coordinate indexed materializations within the topography.
  ///
  /// ### When to use
  /// - **Indexed Iteration**: Triggering a set number of operations in
  ///   response to a state change.
  /// - **Synthetic Burst Generation**: Seeding a topography branch with
  ///   a specific sequence of numeric payloads.
  /// - **Pagination Logic**: Generating offsets or page numbers for
  ///   downstream evolution gates.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The bridge awaits a trigger pulse from
  ///    the source cell.
  /// 2. **Arithmetic Generation**: Upon ingress, the orchestrator
  ///    calculates a sequence starting at [start], iterating [count] times,
  ///    incrementing by [step].
  /// 3. **Pulse Evolution**: Each integer is materialized as a new pulse,
  ///    inheriting the provenance and priority of the trigger.
  ///
  /// ### Non‑obvious
  /// - **Immediate Exhaustion**: The entire range is evolved synchronously.
  ///   For extremely large counts, this will occupy the execution frame
  ///   until completion.
  /// - **Directional Step**: The [step] can be negative to evolve a
  ///   descending sequence.
  ///
  /// ### Parameters:
  /// - [start]: The **Initial Payload** of the sequence.
  /// - [count]: The total **Materialization Count**.
  /// - [step]: The **Arithmetic Increment** between pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored generator node.
  ///
  /// ### See Also
  /// * [repeat]: For evolving the same payload multiple times.
  /// * [fromIterable]: For evolving pulses from a dynamic collection.
  FlowHandle range({required int start, required int count, int step = 1}) =>
      Flow.range(this, start: start, count: count, step: step);

  /// Synthesizes a **Recursive Stimulus Bridge**—a specialized generator
  /// designed to evolve the same payload multiple times.
  ///
  /// [repeat] transforms a single trigger from the source cell into a
  /// burst of identical pulses. It is typically used for seeding
  /// parallel topography branches or generating redundant signals for
  /// coordination logic.
  ///
  /// ### When to use
  /// - **Redundant Materialization**: Evolving the same state multiple
  ///   times to trigger independent downstream branches.
  /// - **Synthetic Burst Generation**: Simulating high-frequency ingress
  ///   by repeating a single test payload.
  /// - **State Echoing**: Re-materializing a pulse after a specific interval
  ///   or event in the topography.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The bridge awaits a trigger pulse from
  ///    the source cell.
  /// 2. **Recursive Generation**: Upon ingress, the orchestrator ignores
  ///    the trigger payload and prepares [count] instances of [value].
  /// 3. **Pulse Evolution**: Each instance is materialized as a new pulse,
  ///    inheriting the provenance and priority of the trigger, tagged
  ///    with the `'Repeat'` step.
  ///
  /// ### Non‑obvious
  /// - **Payload Override**: Unlike [range], which derives its values from
  ///   a start point, [repeat] completely ignores the trigger stimulus
  ///   payload in favor of the provided [value].
  /// - **Synchronous Emission**: All [count] pulses are evolved
  ///   synchronously within the same execution frame.
  ///
  /// ### Parameters:
  /// - [value]: The **Fixed Payload** to be materialized.
  /// - [count]: The total number of **Evolution Cycles**.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored recursive node.
  ///
  /// ### See Also
  /// * [range]: For evolving a sequence of unique integer stimuli.
  /// * [of]: For evolving a static collection of different payloads.
  FlowHandle repeat<T>({required T value, int count = 1}) =>
      Flow.repeat<T>(this, value: value, count: count);

  /// Synthesizes a **Temporal Resource Bridge** from a [Future].
  ///
  /// This operator anchors the topography to the eventual resolution
  /// of an asynchronous operation, materializing a pulse when the
  /// future completes. It bridges the boundary between one-off
  /// asynchronous tasks and the persistent reactive evolution of the graph.
  ///
  /// ### When to use
  /// - **Async Seeding**: Materializing state from a database query or
  ///   network request to seed a topography branch.
  /// - **Boundary Crossing**: Integrating standard `async/await` logic
  ///   into a fluent evolution pipeline.
  /// - **Deferred Evolution**: Triggering a pulse that only materializes
  ///   after a specific asynchronous prerequisite is satisfied.
  ///
  /// ### How it works
  /// 1. **Bridge Activation**: The operator intercepts a trigger pulse
  ///    from the source cell.
  /// 2. **Asynchronous Attachment**: The orchestrator attaches to the
  ///    provided [future] and monitors its resolution state.
  /// 3. **Temporal Monitoring**: If a [timeout] is defined, the bridge
  ///    starts a safety timer to bound the evolution window.
  /// 4. **Materialization**: Upon successful completion, the result is
  ///    emitted as a new pulse, tagged with the `'FromFuture'` step.
  /// 5. **Error Propagation**: If the future fails or times out, the
  ///    [onError] handler is invoked and the error is optionally
  ///    materialized as an error pulse.
  ///
  /// ### Non‑obvious
  /// - **Single Pulse Lifecycle**: This bridge materializes exactly
  ///   one pulse per trigger. It does not stay active for subsequent
  ///   results unless re-triggered by the source.
  /// - **Timeout Preemption**: Providing a [timeout] ensures the
  ///   topography does not hang indefinitely on a stalled resource.
  ///
  /// ### Type Parameters
  /// * [S]: **Stimulus Payload Type**. The type of data yielded by
  ///   the successful resolution of the future.
  ///
  /// ### Parameters:
  /// - [future]: The **Materialization Source**—the asynchronous
  ///   task to be bridged.
  /// - [timeout]: The **Safety Boundary** for the evolution window.
  /// - [onError]: The **Failure Orchestrator** invoked upon rejection.
  /// - [emitErrorPulse]: If true, failures are evolved into the
  ///   topography as error-tagged pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] providing the anchor node for the asynchronous branch.
  ///
  /// ### See Also
  /// * [fromStream]: For anchoring to continuous asynchronous sources.
  /// * [AsyncMap]: For mapping existing pulses through async operations.
  FlowHandle fromFuture<S>({
    required Future<S> future,
    Duration? timeout,
    FutureErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.fromFuture<S>(
        this,
        future: future,
        timeout: timeout,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  /// Synthesizes a **Continuous Pulse Bridge** from a [Stream].
  ///
  /// This operator establishes a persistent, asynchronous link to an external
  /// data source, materializing each stream event as a new pulse within
  /// the topography. It allows the graph to react to live, ongoing evolution
  /// emitted by external actors.
  ///
  /// ### When to use
  /// - **Event Integration**: Anchoring a topography branch to UI event
  ///   buses, socket streams, or system notifications.
  /// - **Reactive Bridging**: Integrating existing `dart:async` Streams
  ///   into the Mitosis evolution framework.
  /// - **Persistent Ingress**: Scenarios where a single trigger should
  ///   open a long-lived gateway for multiple stimuli.
  ///
  /// ### How it works
  /// 1. **Bridge Subscription**: The operator intercepts a trigger pulse
  ///    from the source cell and subscribes to the provided [stream].
  /// 2. **Signal Monitoring**: The bridge remains active, monitoring the
  ///    stream for data, errors, or termination signals.
  /// 3. **Materialization**: Every data event from the stream is emitted
  ///    as a new pulse, inheriting the priority of the original trigger
  ///    and tagged with the `'FromStream'` step.
  /// 4. **Error Handling**: Stream errors are intercepted. Depending on
  ///    [emitErrorPulse], they are either evolved as error-tagged pulses
  ///    or silenced after the [onError] callback.
  ///
  /// ### Non‑obvious
  /// - **Lifecycle Synchronization**: The bridge automatically cancels the
  ///   stream subscription if the anchored node is disposed or if a
  ///   new trigger pulse re-activates the gate.
  /// - **Backpressure**: This bridge performs immediate materialization;
  ///   downstream nodes should use `buffer` or `throttle` if the stream
  ///   frequency exceeds evolution capacity.
  ///
  /// ### Type Parameters
  /// * [S]: **Stimulus Payload Type**. The type of data yielded by
  ///   the continuous stream source.
  ///
  /// ### Parameters:
  /// - [stream]: The **Continuous Materialization Source** to be bridged.
  /// - [onError]: The **Failure Orchestrator** invoked upon stream errors.
  /// - [emitErrorPulse]: If true, stream errors are evolved into the
  ///   topography as error-tagged pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] providing the anchor node for the continuous branch.
  ///
  /// ### See Also
  /// * [fromFuture]: For anchoring to one-off asynchronous tasks.
  /// * [AsyncExpand]: For mapping pulses into persistent inner streams.
  FlowHandle fromStream<S>({
    required Stream<S> stream,
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.fromStream<S>(
        this,
        stream: stream,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  /// Materializes a **Projective Evolution Gate**—a fundamental instruction
  /// designed to transform stimulus payloads as they traverse the topography.
  ///
  /// [map] (analogous to Rx `map`) intercepts every incoming pulse from the
  /// source cell and applies a synchronous [project] function to its payload.
  /// The resulting value is then evolved into a new pulse and propagated
  /// downstream.
  ///
  /// ### When to use
  /// - **Data Normalization**: Converting raw stimuli (e.g., JSON strings)
  ///   into typed models or domain objects.
  /// - **View Logic**: Transforming internal state into UI-ready
  ///   representations (e.g., formatting a `DateTime` into a localized string).
  /// - **Topographical Filtering**: Returning specific properties from
  ///   complex objects to simplify downstream logic.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The gate intercepts a pulse originating
  ///    from the source cell.
  /// 2. **Projective Evolution**: The [project] orchestrator is invoked
  ///    synchronously with the pulse payload.
  /// 3. **Pulse Materialization**: The result of the projection is wrapped
  ///    in a new pulse, inheriting the **Provenance** of the original
  ///    trigger and tagged with the `'Map'` step.
  ///
  /// ### Non‑obvious
  /// - **Synchronous Integrity**: The projection occurs within the same
  ///   execution frame as the ingress. Heavy logic here will block the
  ///   reactive engine's evolution cycle.
  /// - **Type Integrity**: If the projection throws an error, the
  ///   evolution is aborted, and the error is routed to the [onError]
  ///   orchestrator.
  ///
  /// ### Type Parameters
  /// * [S]: **Source Stimulus Type**. The type of the payload arriving
  ///   at the gate.
  /// * [T]: **Evolved Materialization Type**. The type of the payload
  ///   exiting the gate.
  ///
  /// ### Parameters:
  /// - [project]: The **Evolution Orchestrator** defining the transformation.
  /// - [onError]: The **Failure Orchestrator** invoked if the transformation
  ///   violates topographical integrity.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored transformation node.
  ///
  /// ### See Also
  /// * [AsyncMap]: For projections involving asynchronous evolution.
  /// * [Filter]: For conditional evolution without transformation.
  FlowHandle map<S, T>({
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.map<S, T>(this, project: project, onError: onError);

  /// Materializes a **Predicate Integrity Gate**—a specialized orchestration
  /// instruction designed to conditionally permit pulse evolution.
  ///
  /// [filter] (analogous to Rx `filter`) evaluates every incoming pulse
  /// from the source cell against a synchronous [test]. If the integrity
  /// rule is satisfied, the pulse is materialized downstream; otherwise,
  /// the evolution path for that specific stimulus is aborted.
  ///
  /// ### When to use
  /// - **Noise Suppression**: Blocking redundant, invalid, or "zero-value"
  ///   stimuli from congesting the topography.
  /// - **Conditional Branching**: Ensuring only specific payloads (e.g.,
  ///   authenticated user events or positive integers) traverse a
  ///   particular topographical branch.
  /// - **State-Based Gating**: Preventing evolution when the payload
  ///   does not meet current business requirements.
  ///
  /// ### How it works
  /// 1. **Stimulus Evaluation**: The gate intercepts a pulse originating
  ///    from the source cell and extracts its payload.
  /// 2. **Integrity Check**: The [test] orchestrator is invoked
  ///    synchronously to determine if the payload satisfies the rule.
  /// 3. **Conditional Materialization**:
  ///    - If `true`: The original pulse is propagated to downstream synapses.
  ///    - If `false`: The pulse is discarded, and no evolution occurs
  ///      for this stimulus.
  ///
  /// ### Non‑obvious
  /// - **Provenance Preservation**: Unlike `map`, which creates a new
  ///   evolved pulse, [filter] passes the *exact* original stimulus forward.
  ///   This preserves the original source, priority, and trace history
  ///   without modification.
  /// - **Synchronous Efficiency**: The check occurs in the ingress frame.
  ///   Logic within [test] should be high-performance to avoid stalling
  ///   the reactive engine.
  ///
  /// ### Type Parameters
  /// * [S]: **Stimulus Payload Type**. The type of the payload arriving
  ///   at the gate for evaluation.
  ///
  /// ### Parameters:
  /// - [test]: The **Integrity Rule**—a predicate determining if a pulse
  ///   may proceed through the gate.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored filtering node.
  ///
  /// ### See Also
  /// * [map]: For transforming payloads without discarding them.
  FlowHandle filter<S>({required bool Function(S value) test}) =>
      Flow.filter<S>(this, test: test);

  /// Materializes a **Passive Observation Gate**—a specialized orchestration
  /// instruction designed to perform side-effects without altering pulse evolution.
  ///
  /// [tap] (analogous to Rx `tap` or `do`) intercepts every incoming pulse from
  /// the source cell and executes the provided [onValue] logic. Unlike `map`,
  /// it does not transform the payload; the original stimulus is propagated
  /// downstream exactly as it arrived.
  ///
  /// ### When to use
  /// - **Forensic Logging**: Auditing pulse data as it traverses a specific
  ///   topographical branch without interfering with downstream logic.
  /// - **External Synchronization**: Triggering side-effects in non-reactive
  ///   systems, such as tracking analytics or updating global state.
  /// - **Evolution Debugging**: Inserting observation points to inspect the
  ///   state of pulses at various stages of a pipeline.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The gate intercepts a pulse originating
  ///    from the source cell.
  /// 2. **Observation Logic**: The [onValue] orchestrator is invoked
  ///    synchronously with the pulse payload.
  /// 3. **Provenance Preservation**: The original pulse—maintaining its
  ///    full trace history, source, and priority—is propagated to
  ///    downstream synapses.
  ///
  /// ### Non‑obvious
  /// - **Synchronous Blocking**: The side-effect occurs within the same
  ///   execution frame as the ingress. Heavy logic here will block the
  ///   reactive engine's evolution cycle.
  /// - **Integrity Safeguard**: If the observation logic throws an error,
  ///   the evolution is aborted, and the error is routed to the [onError]
  ///   orchestrator.
  ///
  /// ### Type Parameters
  /// * [S]: **Stimulus Payload Type**. The type of the payload arriving
  ///   at the gate for observation.
  ///
  /// ### Parameters:
  /// - [onValue]: The **Observation Logic** defining the side-effect.
  /// - [onError]: The **Failure Orchestrator** invoked if the side-effect
  ///   violates topographical integrity.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored observation node.
  ///
  /// ### See Also
  /// * [map]: For transforming payloads during evolution.
  /// * [filter]: For conditionally permitting pulse evolution.
  FlowHandle tap<S>({
    required void Function(S value) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tap<S>(this, onValue: onValue, onError: onError);
}

/// Synthesizes a **Fluent Topographical Continuation**—a specialized orchestration
/// extension designed to chain pulse evolution from an existing [FlowHandle].
///
/// [FlowOperators] allows the topography to grow linearly and declaratively.
/// It captures the [Cell] anchored to the current handle and uses it as the
/// **Stimulus Origin** for the next instruction in the pipeline.
///
/// ### When to use
/// - **Pipeline Composition**: Building complex evolution chains by
///   sequentially applying transformations, filters, and async gates.
/// - **Branching Logic**: Continuing the evolution of a materialized pulse
///   path into more specific topographical sub-structures.
///
/// ### How it works
/// 1. **Anchor Extraction**: The extension accesses the internal `cell`
///    of the [FlowHandle].
/// 2. **Instruction Binding**: It binds a new orchestration instruction
///    to that cell, creating a new downstream node.
/// 3. **Handle Materialization**: Returns a new [FlowHandle] representing
///     the next stage of the topography.
///
/// ### Non‑obvious
/// - **Stateless Continuation**: Chaining operators does not preserve
///   transient pulse state; each step defines a new, stateless logic gate
///   within the graph.
/// - **Provenance Flow**: Provenance data and priorities automatically
///   traverse these chained gates unless an operator explicitly
///   intercepts or resets them.
///
/// ### See Also
/// * [CellFlowOperators]: The entry point for starting a pipeline from a Cell.
/// * [FlowHandle]: The materialized interface for topographical ingress.
extension FlowOperators on FlowHandle {
  Cell get _src => cell;

  // ── transform ──────────────────────────────────────────────

  /// Materializes a **Projective Evolution Gate**—an instruction designed
  /// to transform stimulus payloads.
  ///
  /// ### Parameters:
  /// - [project]: The **Evolution Orchestrator** defining the transformation.
  /// - [onError]: Invoked if the transformation violates integrity.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored transformation node.
  FlowHandle map<S, T>({
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.map<S, T>(_src, project: project, onError: onError);

  /// Materializes a **Static Projective Gate**—an instruction that
  /// transforms every stimulus into a constant [value].
  ///
  /// ### Parameters:
  /// - [value]: The **Fixed Materialization** payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the constant projection node.
  FlowHandle mapTo<S, T>({
    required T value,
    MapErrorHandler? onError,
  }) =>
      Flow.mapTo<S, T>(_src, value: value, onError: onError);

  /// Materializes an **Indexed Projective Gate**—an instruction that
  /// transforms payloads using their cumulative arrival index.
  ///
  /// ### Parameters:
  /// - [project]: Logic receiving the payload and its **Pulse Sequence ID**.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the indexed evolution node.
  FlowHandle mapWithIndex<S, T>({
    required T Function(S value, int index) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapWithIndex<S, T>(_src, project: project, onError: onError);

  /// Materializes a **Filtering Projective Gate**—an instruction that
  /// transforms payloads and aborts evolution if the result is `null`.
  ///
  /// ### Parameters:
  /// - [project]: Logic defining the evolution or suppression.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the null-aware transformation node.
  FlowHandle mapNotNull<S, T>({
    required T? Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapNotNull<S, T>(_src, project: project, onError: onError);

  /// Materializes a **Guarded Projective Gate**—an instruction that
  /// only applies transformation to pulses satisfying a [test].
  ///
  /// ### Parameters:
  /// - [test]: The **Integrity Rule** for the projection.
  /// - [project]: The **Evolution Orchestrator**.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the guarded node.
  FlowHandle mapWhen<S, T>({
    required bool Function(S value) test,
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapWhen<S, T>(_src, test: test, project: project, onError: onError);

  /// Materializes a **Keyed Extraction Gate**—an instruction designed
  /// to extract a specific property [key] from a Map-like payload.
  ///
  /// ### Parameters:
  /// - [key]: The property identifier to extract.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the keyed materialization node.
  FlowHandle pluck<T>({required Object key, PluckErrorHandler? onError}) =>
      Flow.pluck<T>(_src, key: key, onError: onError);

  /// Materializes a **Keyed Extraction Gate** with a fallback [orElse]
  /// value if the key is missing.
  ///
  /// ### Parameters:
  /// - [key]: The property identifier to extract.
  /// - [orElse]: The **Default Materialization** payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the safe keyed node.
  FlowHandle pluckOr<T>({
    required Object key,
    required T orElse,
    PluckErrorHandler? onError,
  }) =>
      Flow.pluckOr<T>(_src, key: key, orElse: orElse, onError: onError);

  /// Materializes a **Deep Extraction Gate**—an instruction designed
  /// to traverse a [path] of nested Map-like payloads.
  ///
  /// ### Parameters:
  /// - [path]: An iterable of keys defining the extraction route.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the deep path evolution node.
  FlowHandle pluckPath<T>({
    required Iterable<Object> path,
    T? orElse,
    bool useOrElse = false,
    PluckErrorHandler? onError,
  }) =>
      Flow.pluckPath<T>(
        _src,
        path: path,
        orElse: orElse,
        useOrElse: useOrElse,
        onError: onError,
      );

  /// Materializes an **Accumulative Evolution Gate**—an instruction
  /// that folds stimulus history into a stateful result.
  ///
  /// ### Parameters:
  /// - [accumulate]: Logic combining the previous state with the new stimulus.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the stateful scan node.
  FlowHandle scan<S, A>({required A Function(A acc, S value) accumulate}) =>
      Flow.scan<S, A>(_src, accumulate: accumulate);

  /// Materializes an **Accumulative Evolution Gate** seeded with
  /// an initial [seed] value.
  ///
  /// ### Parameters:
  /// - [seed]: The initial **Topographical State**.
  /// - [accumulate]: The state-evolution logic.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the seeded reduction node.
  FlowHandle reduce<S, A>({
    required A seed,
    required A Function(A acc, S value) accumulate,
  }) =>
      Flow.reduce<S, A>(_src, seed: seed, accumulate: accumulate);

  /// Materializes a **Binary Temporal Bridge**—an instruction that
  /// pairs the current stimulus with its immediate predecessor.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving pulses as `List<S>` of size 2.
  FlowHandle pairwise<S>() => Flow.pairwise<S>(_src);

  // ── async ──────────────────────────────────────────────────

  // ── async ──────────────────────────────────────────────────

  /// Materializes a **Sequential Temporal Gate**—an instruction that
  /// maps payloads through asynchronous evolution one by one.
  ///
  /// ### Parameters:
  /// - [mapper]: The **Async Evolution Orchestrator**.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the sequential async node.
  FlowHandle asyncMap<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMap<S, T>(_src, mapper: mapper, onError: onError);

  /// Materializes a **Concurrent Temporal Gate**—an instruction that
  /// maps payloads through async evolution without waiting for completion.
  ///
  /// ### Parameters:
  /// - [mapper]: The **Concurrent Evolution Orchestrator**.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the multi-lane async node.
  FlowHandle asyncMapConcurrent<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMapConcurrent<S, T>(_src, mapper: mapper, onError: onError);

  /// Materializes a **Preemptive Temporal Gate**—an instruction that
  /// cancels previous async evolutions when a new stimulus arrives.
  ///
  /// ### Parameters:
  /// - [mapper]: The **Latest-Only Evolution Orchestrator**.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the preemptive async node.
  FlowHandle asyncMapLatest<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMapLatest<S, T>(_src, mapper: mapper, onError: onError);

  /// Materializes a **Recursive Temporal Gate**—an instruction that
  /// maps a payload to a sequence of asynchronous materializations.
  ///
  /// ### Parameters:
  /// - [expand]: Factory producing a Stream, Future, or Iterable.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the flattened async branch.
  FlowHandle asyncExpand<S, T>({
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) =>
      Flow.asyncExpand<S, T>(_src, expand: expand, onError: onError);

  /// Materializes an **Asynchronous Accumulation Gate**—an instruction
  /// that folds stimuli into state via async logic.
  ///
  /// ### Parameters:
  /// - [seed]: Initial state.
  /// - [accumulate]: Async state-evolution logic.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the async fold node.
  FlowHandle asyncFold<S, A>({
    required A seed,
    required FutureOr<A> Function(A acc, S value) accumulate,
    FoldSnapshot<A>? snapshot,
    FoldErrorHandler? onError,
  }) =>
      Flow.asyncFold<S, A>(
        _src,
        seed: seed,
        accumulate: accumulate,
        snapshot: snapshot,
        onError: onError,
      );

  // ── filter ─────────────────────────────────────────────────

  /// Materializes a **Predicate Integrity Gate**—an instruction that
  /// conditionally permits pulse evolution based on a [test].
  FlowHandle filter<S>({required bool Function(S value) test}) =>
      Flow.filter<S>(_src, test: test);

  /// Materializes a **Counted Materialization Gate**—an instruction
  /// that only allows the first [count] pulses to evolve.
  FlowHandle take<S>({required int count}) => Flow.take<S>(_src, count: count);

  /// Materializes a **Conditional Lifecycle Gate**—an instruction that
  /// evolves pulses as long as the [test] integrity rule is met.
  FlowHandle takeWhile<S>({required bool Function(S value) test}) =>
      Flow.takeWhile<S>(_src, test: test);

  /// Materializes a **Boundary Lifecycle Gate**—an instruction that
  /// terminates evolution once the [notifier] cell materializes a pulse.
  FlowHandle takeUntil<S>({required Cell notifier}) =>
      Flow.takeUntil<S>(_src, notifier: notifier);

  /// Materializes a **Displacement Gate**—an instruction that
  /// ignores the first [count] stimuli.
  FlowHandle skip<S>({required int count}) => Flow.skip<S>(_src, count: count);

  /// Materializes a **Conditional Displacement Gate**—an instruction
  /// that ignores pulses until the [test] rule is violated.
  FlowHandle skipWhile<S>({required bool Function(S value) test}) =>
      Flow.skipWhile<S>(_src, test: test);

  /// Materializes a **Boundary Displacement Gate**—an instruction
  /// that ignores pulses until the [notifier] cell emits a signal.
  FlowHandle skipUntil<S>({required Cell notifier}) =>
      Flow.skipUntil<S>(_src, notifier: notifier);

  /// Materializes a **Redundancy Suppression Gate**—an instruction
  /// that ignores a pulse if its payload matches the immediate predecessor.
  FlowHandle skipRepeated<S>() => Flow.skipRepeated<S>(_src);

  /// Materializes a **Uniqueness Gate**—an instruction that ignores
  /// any payload that has already traversed the gate in the past.
  FlowHandle distinct<S>() => Flow.distinct<S>(_src);

  // ── flatten ────────────────────────────────────────────────

  /// Materializes a **Sequential Evolution Flattener**—an instruction
  /// that flattens nested sequences while maintaining strict order.
  FlowHandle concatMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.concatMap<S, T>(_src, project: project);

  /// Materializes a **Higher-Order Flattener**—an instruction that
  /// treats incoming payloads as sequences and flattens them sequentially.
  FlowHandle concatAll<T>() => Flow.concatAll<T>(_src);

  /// Materializes a **Concurrent Evolution Flattener**—an instruction
  /// that flattens nested sequences as they arrive, without ordering.
  FlowHandle mergeMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.mergeMap<S, T>(_src, project: project);

  /// Materializes a **Preemptive Evolution Flattener**—an instruction
  /// where new inner sequences cancel the evolution of existing ones.
  FlowHandle switchMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.switchMap<S, T>(_src, project: project);

  /// Materializes an **Exclusive Evolution Flattener**—an instruction
  /// that ignores new stimuli while an inner sequence is evolving.
  FlowHandle exhaustMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.exhaustMap<S, T>(_src, project: project);

  // ── combine ────────────────────────────────────────────────

  /// Materializes a **Multi-Source Convergence Bridge**—an instruction
  /// that relays pulses from this handle and all [others].
  FlowHandle mergeWith<T>({required List<Cell> others}) =>
      Flow.mergeWith<T>(_src, others: others);

  /// Materializes a **Higher-Order Convergence Bridge**—an instruction
  /// that flattens a sequence of cells into a single merged branch.
  FlowHandle mergeAll<T>({MergeErrorHandler? onError}) =>
      Flow.mergeAll<T>(_src, onError: onError);

  /// Materializes a **Synchronized Synthesis Bridge**—an instruction
  /// that waits for all sources to emit before producing a combined pulse.
  FlowHandle zipWith<R>({
    required List<Cell> others,
    R Function(List<Object?> row)? project,
    ZipErrorHandler? onError,
  }) =>
      Flow.zipWith<R>(_src, others: others, project: project, onError: onError);

  /// Materializes a **Stateful Synthesis Bridge**—an instruction
  /// that combines the current stimulus with the latest state of [others].
  FlowHandle combineLatestWith<S, R>({
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) =>
      Flow.combineLatestWith<S, R>(
        _src,
        others: others,
        combine: combine,
        onError: onError,
      );

  /// Materializes a **Sampling Synthesis Bridge**—an instruction that
  /// takes the latest state from [others] only when this handle emits.
  FlowHandle withLatestFrom<S, R>({
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) =>
      Flow.withLatestFrom<S, R>(
        _src,
        others: others,
        combine: combine,
        onError: onError,
      );

  // ── time ───────────────────────────────────────────────────

  /// Materializes a **Temporal Displacement Bridge**—an instruction that
  /// shifts the materialization of pulses by a specific duration.
  ///
  /// ### Parameters:
  /// - [duration]: The **Temporal Offset** for pulse evolution.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the delayed evolution node.
  FlowHandle delay<S>({required Duration duration}) =>
      Flow.delay<S>(_src, duration: duration);

  /// Materializes a **Dynamic Temporal Bridge**—an instruction that shifts the
  /// materialization of pulses based on the resolution of a secondary evolution.
  ///
  /// ### Parameters:
  /// - [when]: The **Temporal Selector**—a closure returning the resource
  ///   that signals the end of the delay.
  /// - [onError]: The **Failure Orchestrator** invoked if the selector or
  ///   boundary violates integrity.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the dynamically delayed evolution node.
  FlowHandle delayWhen<S>({
    required FutureOr<Object?> Function(S value) when,
    DelayErrorHandler? onError,
  }) =>
      Flow.delayWhen<S>(_src, when: when, onError: onError);

  /// Materializes a **Silence Gate**—an instruction that only permits
  /// evolution after a period of topographical silence.
  ///
  /// ### Parameters:
  /// - [duration]: The **Silence Threshold** required for materialization.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the debounced evolution node.
  FlowHandle debounce<S>({required Duration duration}) =>
      Flow.debounce<S>(_src, duration: duration);

  /// Materializes a **Frequency Control Gate**—an instruction that
  /// limits evolution to a specific temporal window.
  ///
  /// ### Parameters:
  /// - [duration]: The **Sampling Window** duration.
  /// - [leading]: If true, evolves the first pulse in the window.
  /// - [trailing]: If true, evolves the last pulse in the window.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the throttled evolution node.
  FlowHandle throttle<S>({
    required Duration duration,
    bool leading = true,
    bool trailing = false,
  }) =>
      Flow.throttle<S>(_src, duration: duration, leading: leading, trailing: trailing);

  /// Materializes a **Boundary Sampling Gate**—an instruction that evolves
  /// the latest stimulus from the source only when the [notifier] cell pulses.
  ///
  /// This operator creates a temporal bottleneck, ensuring that downstream
  /// evolution is governed by the cadence of an external **Boundary Anchor**.
  ///
  /// ### Parameters:
  /// - [notifier]: The **Boundary Anchor** triggering the sample.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the anchored sampling node.
  FlowHandle sample<S>({
    required Cell notifier,
    SampleErrorHandler? onError,
  }) =>
      Flow.sample<S>(_src, notifier: notifier, onError: onError);

  /// Materializes a **Periodic Sampling Gate**—an instruction that evolves
  /// the latest stimulus at fixed temporal intervals.
  ///
  /// ### Parameters:
  /// - [period]: The **Temporal Cadence** for materialization.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the interval-based sampling node.
  FlowHandle sampleTime<S>({
    required Duration period,
    SampleErrorHandler? onError,
  }) =>
      Flow.sampleTime<S>(_src, period: period, onError: onError);

  /// Materializes a **Temporal Audit Gate**—an instruction that evolves
  /// the *most recent* stimulus within a sliding temporal window.
  ///
  /// Unlike [throttle], which prioritizes the start of a window, [auditTime]
  /// ensures the absolute latest state is captured after the [duration] passes.
  ///
  /// ### Parameters:
  /// - [duration]: The **Audit Window** duration.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the audited evolution node.
  FlowHandle auditTime<S>({
    required Duration duration,
    SampleErrorHandler? onError,
  }) =>
      Flow.auditTime<S>(_src, duration: duration, onError: onError);

  /// Materializes a **Temporal Integrity Gate**—an instruction that
  /// aborts evolution if a stimulus does not arrive within a window.
  ///
  /// ### Parameters:
  /// - [duration]: The **Maximum Latency** permitted between pulses.
  /// - [onError]: The **Failure Orchestrator** invoked upon violation.
  /// - [emitErrorPulse]: If true, timeouts are evolved as error pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the timeout-guarded node.
  FlowHandle timeout<S>({
    required Duration duration,
    TimeoutErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.timeout<S>(
        _src,
        duration: duration,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  /// Materializes a **Periodic Pulse Bridge**—an instruction that
  /// generates a sequential integer stimulus at every [period].
  ///
  /// ### Parameters:
  /// - [period]: The **Bridge Cadence**.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the periodic generator node.
  FlowHandle interval({required Duration period}) =>
      Flow.interval(_src, period: period);

  // ── collect ────────────────────────────────────────────────

  /// Materializes a **Quantized Collection Flattener**—an instruction that gathers stimulus payloads into a List of a fixed size.
  ///
  /// ### Parameters:
  /// - [size]: The **Quantization Threshold** defining how many pulses to collect before materializing.
  /// - [skip]: The **Pulse Offset** for starting the next collection.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving pulses as `List<S>`.
  FlowHandle bufferCount<S>({
    required int size,
    int? skip,
    BufferErrorHandler? onError,
  }) =>
      Flow.bufferCount<S>(_src, size: size, skip: skip, onError: onError);

  /// Materializes a **Temporal Collection Flattener**—an instruction that gathers stimuli into a List based on sliding time windows.
  ///
  /// ### Parameters:
  /// - [duration]: The **Temporal Window** for collection.
  /// - [emitEmpty]: If true, evolves an empty list when the window expires without stimuli.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving pulses as `List<S>`.
  FlowHandle bufferTime<S>({
    required Duration duration,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
  }) =>
      Flow.bufferTime<S>(
        _src,
        duration: duration,
        emitEmpty: emitEmpty,
        onError: onError,
      );

  /// Materializes a **Topographical Window Flattener**—an instruction that partitions the source into multiple sub-cell sequences.
  ///
  /// ### Parameters:
  /// - [size]: The **Window Capacity** for each sub-cell.
  /// - [skip]: The **Pulse Offset** for opening the next window.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving pulses as `Cell<S>`.
  FlowHandle windowCount<S>({required int size, int? skip}) =>
      Flow.windowCount<S>(_src, size: size, skip: skip);

  /// Materializes a **Topographical Demultiplexer**—an instruction that branches the topography based on a calculated [keyOf].
  ///
  /// ### Parameters:
  /// - [keyOf]: The **Branching Orchestrator** defining how to group stimuli.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving grouped `FlowHandle` branches.
  FlowHandle groupBy<S, K>({
    required K Function(S value) keyOf,
    GroupErrorHandler? onError,
  }) =>
      Flow.groupBy<S, K>(_src, keyOf: keyOf, onError: onError);

  /// Materializes a **Binary Integrity Demultiplexer**—an instruction that splits the topography into two branches based on a [test].
  ///
  /// ### Parameters:
  /// - [test]: The **Integrity Rule** determining the branch destination.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] evolving a Record containing the `match` and `complement` handles.
  FlowHandle partition<S>({
    required bool Function(S value) test,
    PartitionErrorHandler? onError,
  }) =>
      Flow.partition<S>(_src, test: test, onError: onError);

// ── control ────────────────────────────────────────────────

  /// Materializes a **Topographical Seeding Gate**—an instruction that evolves an initial [value] immediately upon materialization.
  ///
  /// ### Parameters:
  /// - [value]: The **Initial Stimulus** payload.
  /// - [replaceFirst]: If true, the seed replaces the source's first materialized pulse.
  ///
  /// ### Returns:
  /// A [FlowHandle] seeded with the provided payload.
  FlowHandle startWith<S>({required S value, bool replaceFirst = false}) =>
      Flow.startWith<S>(_src, value: value, replaceFirst: replaceFirst);

  /// Materializes a **Synaptic Multiplexer**—an instruction that allows multiple downstream branches to share a single evolution cycle.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the shared evolution node.
  FlowHandle share<S>() => Flow.share<S>(_src);

  /// Materializes a **Stateful Synaptic Multiplexer**—an instruction that replays the last [size] pulses to new downstream synapses.
  ///
  /// ### Parameters:
  /// - [size]: The **Replay Depth** of the materialization buffer.
  ///
  /// ### Returns:
  /// A [FlowHandle] providing the shared, stateful ingress point.
  FlowHandle shareReplay<S>({int size = 1}) =>
      Flow.shareReplay<S>(_src, size: size);

  /// Materializes a **Fault Tolerance Bridge**—an instruction that attempts to re-initiate a failing evolution task.
  ///
  /// ### Parameters:
  /// - [task]: The **Async Evolution Task** to be executed.
  /// - [count]: The maximum number of **Recovery Attempts**.
  /// - [onError]: The **Failure Orchestrator** invoked when all retries are exhausted.
  /// - [emitErrorPulse]: If true, terminal failures are evolved as error pulses.
  ///
  /// ### Returns:
  /// A [FlowHandle] representing the resilient evolution branch.
  FlowHandle retry<S, T>({
    required RetryTask<S, T> task,
    int count = 3,
    RetryErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.retry<S, T>(
        _src,
        task: task,
        count: count,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  /// Materializes a **Passive Observation Gate**—an instruction that performs side-effects without altering pulse evolution.
  ///
  /// ### Parameters:
  /// - [onValue]: The **Observation Logic** executed during evolution.
  /// - [onError]: Invoked if the observation logic violates integrity.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the observed topography branch.
  FlowHandle tap<S>({
    required void Function(S value) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tap<S>(_src, onValue: onValue, onError: onError);

  /// Materializes a **Forensic Observation Gate**—an instruction that exposes the full [Pulse] container for metadata auditing.
  ///
  /// ### Parameters:
  /// - [onPulse]: Logic for auditing **Provenance** and payload metadata.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the audited topography branch.
  FlowHandle tapAll({
    required void Function(Pulse pulse) onPulse,
    TapErrorHandler? onError,
  }) =>
      Flow.tapAll(_src, onPulse: onPulse, onError: onError);

  /// Materializes an **Indexed Observation Gate**—an instruction that performs side-effects using the pulse's sequence index.
  ///
  /// ### Parameters:
  /// - [onValue]: Observation logic receiving the payload and its **Pulse Sequence ID**.
  /// - [onError]: The **Failure Orchestrator** for integrity violations.
  ///
  /// ### Returns:
  /// A [FlowHandle] for the indexed observation node.
  FlowHandle tapWithIndex<S>({
    required void Function(S value, int index) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tapWithIndex<S>(_src, onValue: onValue, onError: onError);

}
