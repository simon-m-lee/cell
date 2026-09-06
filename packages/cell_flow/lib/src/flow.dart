// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../flow.dart';

/// The Transcription Orchestrator for the Cell framework, responsible for
/// converting (transcribing) external stimuli, persistent state, and logic
/// into reactive [Cell] topographies.
///
/// [Flow] acts as the **Administrative Facade** over the **Mitosis** reactive
/// layer. It provides a declarative, static API for building complex reactive
/// pipelines without manually instantiating [FlowInstruction] or [Receptor] objects.
///
/// ### When to use
/// Use [Flow] as your primary entry point for reactive orchestration:
///
/// - **Pipeline Creation**: Bridging external [Future]s or [Stream]s into cells.
/// - **Synchronous Logic**: Applying filters, maps, and scans.
/// - **Asynchronous Coordination**: Managing concurrency with `switchMap`, `mergeMap`, and `asyncMap`.
/// - **Temporal Control**: Implementing `debounce`, `throttle`, and `delay` logic.
/// - **Topological Routing**: Branching or partitioning signals through the graph.
///
/// ### How it works
/// 1. Every static method in [Flow] acts as a factory for a specific [FlowInstruction].
/// 2. When called, the method creates the instruction, binds it to the provided
///    `source` cell, and materializes a [FlowHandle].
/// 3. The [FlowHandle] provides access to the output `.cell` and an `.emit()`
///    mechanism, while managing the underlying receptor lifecycle.
/// 4. Transformations are optimized into flyweight receptors that execute
///    within the host cell's switching fabric.
///
/// ### Non‑obvious
/// - **Stateless Blueprint**: The methods in [Flow] are convenience wrappers. The
///   authoritative logic lives in the [FlowInstruction] classes.
/// - **Resource Management**: A [FlowHandle] is a managed resource. While cells
///   in Mitosis do not "complete", you should dispose of observers or handles to
///   prune branches when they are no longer needed.
/// - **Causal Integrity**: All operations in [Flow] preserve forensic metadata.
///   Incoming pulses are evolved (not replaced), maintaining a full trace of
///   the signal's journey across the topography.
///
/// ### See Also:
/// * [FlowInstruction]: The stateless blueprint for reactive logic.
/// * [FlowHandle]: The live instance of a flow pipeline.
/// * [Cell]: The underlying stateful node in the reactive graph.
abstract class Flow extends CellBase {
  // ─────────────────────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────────────────────

  /// Emits each value in [values] sequentially on the first pulse received
  /// from [source] (Rx `of`).
  ///
  /// [of] emits a fixed sequence of values one after another, in order,
  /// when the source cell first pulses. This is useful for initializing
  /// a stream with a known set of values before live data arrives.
  ///
  /// ### When to use
  /// Use [of] when you need to emit a fixed sequence of values on the
  /// first trigger.
  ///
  /// - **Initial Values**: Emitting initial values on startup.
  /// - **Test Data**: Emitting test data sequences.
  /// - **Configuration**: Emitting configuration values.
  /// - **Static Sequences**: Emitting static sequences.
  /// - **One-Time Setup**: Performing one-time setup sequences.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Each value in [values] is emitted in order.
  /// 3. Later pulses are ignored.
  /// 4. Each emitted value gets the step `'Of'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The sequence only plays on the first pulse.
  /// - **Synchronous Emission**: Values are emitted synchronously.
  /// - **No Completion**: Cells don't complete, but the instruction
  ///   stops emitting after all values are sent.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the emission.
  /// - [values]: **The Values to Emit.** The sequence of values to
  ///   emit on the first trigger.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the values to emit.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.of<String>(
  ///   start.cell,
  ///   values: ['init', 'ready', 'go'],
  /// );
  ///
  /// start.emit(null);
  /// // Outputs: init, ready, go
  /// ```
  ///
  /// ### See Also:
  /// - [fromIterable]: For emitting from an iterable.
  /// - [range]: For emitting a numeric range.
  /// - [repeat]: For emitting a repeated value.
  static FlowHandle of<T>(
      Cell source, {
        required Iterable<T> values,
      }) {
    return Of<T>(values).toHandle(source: source);
  }

  /// Emits each element of [iterable] on the first pulse received from
  /// [source] (Rx `from`).
  ///
  /// [fromIterable] is similar to [of] but takes an iterable source.
  /// It emits each element of the iterable in order on the first trigger.
  ///
  /// ### When to use
  /// Use [fromIterable] when you have an iterable source to emit.
  ///
  /// - **Iterable Sources**: Emitting from any iterable (List, Set, etc.).
  /// - **Dynamic Collections**: Emitting from collections that are
  ///   built dynamically.
  /// - **Data Loading**: Emitting loaded data sequences.
  /// - **Stream Conversion**: Converting iterables to pulses.
  /// - **Batch Processing**: Processing collections as sequences.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Each element of [iterable] is emitted in iteration order.
  /// 3. Later pulses are ignored.
  /// 4. Each emitted value gets the step `'FromIterable'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The sequence only plays on the first pulse.
  /// - **Iterable Order**: The iteration order of the iterable is used.
  /// - **Synchronous Emission**: Values are emitted synchronously.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the emission.
  /// - [iterable]: **The Iterable Source.** The iterable to emit elements from.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the elements to emit.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.fromIterable<String>(
  ///   start.cell,
  ///   iterable: ['a', 'b', 'c'],
  /// );
  ///
  /// start.emit(null);
  /// // Outputs: a, b, c
  /// ```
  ///
  /// ### See Also:
  /// - [of]: For emitting fixed values.
  /// - [range]: For emitting a numeric range.
  /// - [repeat]: For emitting a repeated value.
  static FlowHandle fromIterable<T>(
      Cell source, {
        required Iterable<T> iterable,
      }) {
    return FromIterable<T>(iterable).toHandle(source: source);
  }

  /// Emits a range of [count] integers starting from [start] on the first
  /// pulse received from [source] (Rx `range`).
  ///
  /// [range] emits a sequence of integers starting from [start] and
  /// incrementing by [step] for [count] times.
  ///
  /// ### When to use
  /// Use [range] when you need to emit a numeric range.
  ///
  /// - **Counters**: Emitting counter values.
  /// - **Indices**: Emitting index sequences.
  /// - **Test Data**: Emitting numeric test data.
  /// - **Loops**: Emitting loop iteration values.
  /// - **Paginations**: Emitting page numbers.
  /// - **ID Generation**: Emitting sequential IDs.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Values are emitted starting from [start].
  /// 3. Each value increases by [step].
  /// 4. [count] values are emitted.
  /// 5. Later pulses are ignored.
  /// 6. Each emitted value gets the step `'Range'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The range only plays on the first pulse.
  /// - **Step Control**: [step] controls the increment between values.
  /// - **Synchronous Emission**: Values are emitted synchronously.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the emission.
  /// - [start]: **Starting Value.** The first integer in the range.
  /// - [count]: **Number of Values.** How many integers to emit.
  /// - [step]: **Step Size.** The increment between values. Defaults to 1.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.range(
  ///   start.cell,
  ///   start: 3,
  ///   count: 5,
  /// );
  ///
  /// start.emit(null);
  /// // Outputs: 3, 4, 5, 6, 7
  /// ```
  ///
  /// ### Example: Range with Step
  /// ```dart
  /// final handle = Flow.range(
  ///   start.cell,
  ///   start: 2,
  ///   count: 5,
  ///   step: 2,
  /// );
  /// // Outputs: 2, 4, 6, 8, 10
  /// ```
  ///
  /// ### See Also:
  /// - [of]: For emitting fixed values.
  /// - [fromIterable]: For emitting from an iterable.
  /// - [repeat]: For emitting a repeated value.
  static FlowHandle range(
      Cell source, {
        required int start,
        required int count,
        int step = 1,
      }) {
    return Range(start, count, step: step).toHandle(source: source);
  }

  /// Emits the same [value], [count] times, on the first pulse received
  /// from [source].
  ///
  /// [repeat] emits the same value multiple times on the first trigger.
  /// This is useful for generating repeated signals.
  ///
  /// ### When to use
  /// Use [repeat] when you need to emit the same value multiple times.
  ///
  /// - **Heartbeats**: Emitting multiple heartbeat signals.
  /// - **Retry Signals**: Emitting multiple retry attempts.
  /// - **Test Data**: Emitting repeated test values.
  /// - **Pulses**: Generating multiple pulses.
  /// - **Acknowledgments**: Sending multiple acknowledgment signals.
  /// - **Alerts**: Emitting repeated alert signals.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. [value] is emitted [count] times.
  /// 3. Later pulses are ignored.
  /// 4. Each emitted value gets the step `'Repeat'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The sequence only plays on the first pulse.
  /// - **Same Value**: The same value is emitted each time.
  /// - **Synchronous Emission**: Values are emitted synchronously.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the emission.
  /// - [value]: **The Value to Repeat.** The value to emit multiple times.
  /// - [count]: **Number of Repetitions.** How many times to emit the value.
  ///   Defaults to 1.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the value to repeat.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.repeat<String>(
  ///   start.cell,
  ///   value: 'ping',
  ///   count: 3,
  /// );
  ///
  /// start.emit(null);
  /// // Outputs: ping, ping, ping
  /// ```
  ///
  /// ### See Also:
  /// - [of]: For emitting fixed values.
  /// - [fromIterable]: For emitting from an iterable.
  /// - [range]: For emitting a numeric range.
  static FlowHandle repeat<T>(
      Cell source, {
        required T value,
        int count = 1,
      }) {
    return Repeat<T>(value, count: count).toHandle(source: source);
  }

  /// Bridges a single [future] into the graph on the first pulse received
  /// from [source] (Rx `fromFuture`).
  ///
  /// [fromFuture] acts as an **Asynchronous One-Shot Loader** that awaits a
  /// single future and emits its result as a [Pulse]. It processes the first
  /// trigger and ignores subsequent triggers.
  ///
  /// ### When to use
  /// Use [fromFuture] when you need to load a single asynchronous value:
  ///
  /// - **Initial Configuration**: Loading app configuration or user profile
  /// - **One-Shot HTTP Calls**: Bridging a single API call into the graph
  /// - **Database Queries**: Loading a single record from the database
  /// - **File Loading**: Reading a single file asynchronously
  /// - **Initialization**: Loading initial state for a module
  /// - **Bridging Legacy APIs**: Converting `Future`-based APIs to Cell-Flow
  /// - **Lazy Loading**: Loading data on demand when first triggered
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. The [future] is awaited.
  /// 3. The result is emitted as a pulse.
  /// 4. If the future fails, an error pulse is emitted.
  /// 5. Later pulses are ignored.
  /// 6. Each emitted value gets the step `'FromFuture'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **One-Shot**: The instruction processes only the first trigger.
  /// - **Lazy Execution**: The future is not started until the first trigger
  ///   arrives. This prevents unnecessary work.
  /// - **Error Handling**: Errors are reported via [onError] and optionally
  ///   as error pulses with `type: 'error'`.
  /// - **Timeout**: Optional timeout can be applied to the future operation.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the future.
  /// - [future]: **The Future to Bridge.** The asynchronous operation to await.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the output payload from the future.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted value.
  ///
  /// ### Example
  /// ```dart
  /// final load = Cell.ingress<void>();
  ///
  /// final handle = Flow.fromFuture<String>(
  ///   load.cell,
  ///   future: api.fetchUserProfile('123'),
  /// );
  ///
  /// load.emit(null);
  /// // Outputs: UserProfile(id: 123, name: 'Alice')
  /// ```
  ///
  /// ### Example: With Timeout
  /// ```dart
  /// final handle = Flow.fromFuture<String>(
  ///   load.cell,
  ///   future: slowApiCall(),
  ///   timeout: Duration(seconds: 5),
  ///   onError: (error, stack) => print('Timeout: $error'),
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [deferFuture]: For creating a new future on each trigger.
  /// - [fromStream]: For bridging a continuous stream.
  static FlowHandle fromFuture<S>(
      Cell source, {
        required Future<S> future,
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return FromFuture<S>(
      future,
      timeout: timeout,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Executes [create] to start a new future on every pulse received from
  /// [source] (Rx `defer` for futures).
  ///
  /// [deferFuture] acts as an **Asynchronous Per-Trigger Loader**. Each
  /// trigger pulse starts a **new** `Future` from [create]. The trigger
  /// payload is passed through so the factory can depend on the stimulus.
  ///
  /// ### When to use
  /// Use [deferFuture] when you need a new future for each trigger:
  ///
  /// - **Per-Request Loading**: Loading data for each user request
  /// - **Dynamic Loading**: Loading data based on the trigger payload
  /// - **Refresh Operations**: Reloading data on each refresh trigger
  /// - **Lazy Evaluation**: Evaluating a future only when triggered
  /// - **Search Operations**: Performing a new search for each query
  /// - **Pagination**: Loading the next page on each trigger
  /// - **Form Submissions**: Submitting each form as a separate operation
  ///
  /// ### How it works
  /// 1. Each trigger pulse calls [create] with the pulse.
  /// 2. The [create] function returns a `Future<S>`.
  /// 3. The future is awaited (optionally under [timeout]).
  /// 4. Success emits `Pulse<S>` with step `DeferFuture`.
  /// 5. Failure is reported through [onError] and optionally an error pulse.
  /// 6. Results are emitted in input order (sequential processing).
  ///
  /// ### Non‑obvious
  /// - **Per-Trigger**: Each trigger starts a new future.
  /// - **Sequential**: The instruction processes inputs one at a time.
  ///   Each async operation must complete before the next starts.
  /// - **Payload Access**: The trigger payload is passed to [create] so
  ///   the future can depend on the stimulus.
  /// - **Error Handling**: Errors are reported via [onError] and optionally
  ///   as error pulses with `type: 'error'`.
  /// - **Timeout**: Optional timeout can be applied to each future operation.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers each future.
  /// - [create]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the output payload from the future.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final userIds = Cell.ingress<int>();
  ///
  /// final handle = Flow.deferFuture<UserProfile>(
  ///   userIds.cell,
  ///   create: (p) async => await api.fetchUser(p.payload as int),
  /// );
  ///
  /// userIds.emit(1); // Loads user 1
  /// userIds.emit(2); // Loads user 2
  /// ```
  ///
  /// ### See Also:
  /// - [fromFuture]: For one-shot future loading.
  /// - [asyncMap]: For mapping each value through an async function.
  static FlowHandle deferFuture<S>(
      Cell source, {
        required Future<S> Function(Pulse trigger) create,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return DeferFuture<S>(
      create,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Subscribes to [stream] on the first pulse received from [source]
  /// (Rx `fromStream`).
  ///
  /// [fromStream] bridges a Dart [Stream] into the reactive graph.
  /// It starts listening to the stream on the first trigger pulse and
  /// emits each event as a pulse.
  ///
  /// ### When to use
  /// Use [fromStream] when you want to bridge an existing Stream
  /// into the Cell graph.
  ///
  /// - **External Events**: Bridging external event streams.
  /// - **WebSocket**: Bridging WebSocket messages.
  /// - **File Watchers**: Bridging file system events.
  /// - **Timers**: Bridging periodic timers.
  /// - **Third-Party SDKs**: Bridging SDK event streams.
  /// - **Hardware Events**: Bridging hardware event streams.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the subscription.
  /// 2. The stream is listened to.
  /// 3. Each event is emitted as a pulse.
  /// 4. If the stream errors, an error pulse is emitted.
  /// 5. The instruction stops after the first trigger.
  /// 6. Each emitted event gets the step `'FromStream'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The stream only starts on the first trigger.
  /// - **Single Subscription**: Only one subscription is created.
  /// - **Error Handling**: Stream errors are caught and reported.
  /// - **Provenance Preservation**: Each emitted event preserves the
  ///   source cell, type, and priority from the trigger pulse.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers the subscription.
  /// - [stream]: **The Stream Source.** The stream to bridge into the
  ///   reactive graph.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
  ///   pulse on stream error. Defaults to `true`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the stream events.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final connect = Cell.ingress<void>();
  ///
  /// final handle = Flow.fromStream<int>(
  ///   connect.cell,
  ///   stream: Stream.periodic(Duration(seconds: 1), (i) => i),
  /// );
  ///
  /// connect.emit(null);
  /// // Outputs: 0, 1, 2, 3, ...
  /// ```
  ///
  /// ### See Also:
  /// - [deferStream]: For creating a new stream on each trigger.
  /// - [fromFuture]: For bridging a single future.
  static FlowHandle fromStream<S>(
      Cell source, {
        required Stream<S> stream,
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return FromStream<S>(
      stream,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Executes [create] to subscribe to a new stream on every pulse received
  /// from [source] (Rx `defer` for streams).
  ///
  /// [deferStream] is similar to [fromStream] but creates a new stream
  /// subscription on each trigger pulse.
  ///
  /// ### When to use
  /// Use [deferStream] when you need a fresh stream on each trigger.
  ///
  /// - **Lazy Initialization**: Creating streams lazily on demand.
  /// - **Fresh State**: Getting fresh state from a stream each time.
  /// - **Per-Trigger**: Different streams for different triggers.
  /// - **Resource Management**: Managing stream resources per trigger.
  /// - **Dynamic Sources**: Creating streams dynamically.
  ///
  /// ### How it works
  /// 1. Each trigger pulse calls [create] to get a new stream.
  /// 2. The stream is listened to.
  /// 3. Each event is emitted as a pulse.
  /// 4. If the stream errors, an error pulse is emitted.
  /// 5. Each emitted event gets the step `'DeferStream'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **New Stream Each Time**: A fresh stream is created on each trigger.
  /// - **Lazy Creation**: The stream is created when triggered.
  /// - **Error Handling**: Stream errors are caught and reported.
  ///
  /// ### Parameters:
  /// - [source]: **The Trigger Source.** The cell that triggers each stream.
  /// - [create]: **Stream Factory.** Called on each trigger to create
  ///   a new stream.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the stream events.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final trigger = Cell.ingress<void>();
  ///
  /// final handle = Flow.deferStream<int>(
  ///   trigger.cell,
  ///   create: () => Stream.periodic(Duration(seconds: 1), (i) => i).take(3),
  /// );
  ///
  /// trigger.emit(null); // Creates and listens to a new stream
  /// trigger.emit(null); // Creates and listens to a new stream
  /// ```
  ///
  /// ### See Also:
  /// - [fromStream]: For a single stream subscription.
  /// - [deferFuture]: For creating a new future on each trigger.
  static FlowHandle deferStream<S>(
      Cell source, {
        required Stream<S> Function() create,
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return DeferStream<S>(
      create,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Transform
  // ─────────────────────────────────────────────────────────────

  /// Projects each incoming payload through the [project] function (Rx `map`).
  ///
  /// [map] is a **Static Transformation Handle**. It evaluates a projection
  /// function for every incoming pulse and forwards the transformed result.
  ///
  /// ### When to use
  /// Use [map] as your primary tool for data conversion and normalization:
  ///
  /// - **Data Conversion**: Changing one data type to another (e.g., `int` to `String`).
  /// - **Normalization**: Trimming strings, formatting numbers, or mapping enum values.
  /// - **Data Enrichment**: Adding calculated fields to a data model.
  /// - **Filtering by Mapping**: Returning the same value but updated (e.g., `user.copyWith(...)`).
  ///
  /// ### How it works
  /// 1. Every incoming pulse is type-checked against the source type [S].
  /// 2. If the payload matches, the [project] closure is executed synchronously.
  /// 3. The return value is wrapped in a new [Pulse] and propagated downstream.
  /// 4. Forensic metadata, including the source cell and trace history, is preserved.
  ///
  /// ### Non‑obvious
  /// - **Atomic Transformation**: The mapping happens within the reactive wave, ensuring
  ///   downstream observers see the transformed value immediately.
  /// - **Error Suppression**: If [project] throws an exception, the pulse is dropped
  ///   to prevent graph corruption, and the error is reported via [onError].
  /// - **Stateless**: The operator maintains no internal state between pulses.
  ///
  /// ### When to use
  /// Use [map] when you need to transform each value in a stream.
  ///
  /// - **Data Transformation**: Converting data from one format to another.
  /// - **Data Enrichment**: Enriching data with additional information.
  /// - **Data Cleaning**: Cleaning or sanitizing data.
  /// - **Data Projection**: Projecting a subset of data.
  /// - **Type Conversion**: Converting between types.
  /// - **Formatting**: Formatting values for display.
  /// - **Computation**: Computing derived values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [project] is called with the payload.
  /// 3. The result is emitted as a typed pulse.
  /// 4. If [project] throws an error, the pulse is dropped.
  /// 5. The emitted pulse gets the step `'MapValue'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Type Safety**: Input type [S] and output type [T] are separate.
  /// - **Error Handling**: If [project] throws, the pulse is dropped.
  /// - **Provenance Preservation**: The emitted pulse preserves the
  ///   source cell, type, and priority from the trigger pulse.
  /// - **Synchronous Transformation**: [project] is synchronous.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **Transformation Function.** Called with each typed
  ///   payload, returns the transformed value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.map<int, int>(
  ///   input.cell,
  ///   project: (n) => n * 2,
  /// );
  ///
  /// input.emit(5);  // -> 10
  /// input.emit(7);  // -> 14
  /// ```
  ///
  /// ### See Also:
  /// - [mapTo]: For mapping to a constant value.
  /// - [mapWithIndex]: For indexed mapping.
  /// - [mapNotNull]: For dropping null results.
  /// - [mapWhen]: For conditional mapping.
  static FlowHandle map<S, T>(
      Cell source, {
        required T Function(S value) project,
        MapErrorHandler? onError,
      }) {
    return MapValue<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Alias of [map] using the MapValue name.
  static FlowHandle mapValue<S, T>(
      Cell source, {
        required T Function(S value) project,
        MapErrorHandler? onError,
      }) {
    return map<S, T>(source, project: project, onError: onError);
  }

  /// Emits the constant [value] for every pulse received from [source] (Rx `mapTo`).
  ///
  /// [mapTo] is a specialized mapping operator that always emits the
  /// same constant value, regardless of the input. This is useful for
  /// converting any input into a fixed output.
  ///
  /// ### When to use
  /// Use [mapTo] when you need to map any input to a constant value.
  ///
  /// - **Event Conversion**: Converting any event to a specific event.
  /// - **Signal Generation**: Generating a fixed signal on any input.
  /// - **Toggle**: Converting any input to a toggle signal.
  /// - **Trigger**: Converting any input to a trigger signal.
  /// - **Mapping to Void**: Mapping any input to a void signal.
  /// - **Default Responses**: Always responding with a fixed value.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, the constant [value] is emitted.
  /// 3. The input value is ignored (only the type is checked).
  /// 4. The emitted pulse gets the step `'MapTo'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Input Ignored**: The input value is not used in the output.
  /// - **Type Check**: The type is still checked to ensure proper typing.
  /// - **Constant Output**: The same value is emitted for every input.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [value]: **Constant Value.** The value to emit for every input.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload (for type checking).
  /// - [T]: The type of the constant output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted values.
  ///
  /// ### Example
  /// ```dart
  /// final clicks = Cell.ingress<void>();
  ///
  /// final handle = Flow.mapTo<void, String>(
  ///   clicks.cell,
  ///   value: 'ping',
  /// );
  ///
  /// clicks.emit(null); // -> ping
  /// clicks.emit(null); // -> ping
  /// ```
  ///
  /// ### See Also:
  /// - [map]: For transforming inputs.
  /// - [mapWithIndex]: For indexed mapping.
  static FlowHandle mapTo<S, T>(
      Cell source, {
        required T value,
        MapErrorHandler? onError,
      }) {
    return MapTo<S, T>(value, onError: onError).toHandle(source: source);
  }

  /// Projects each payload along with its 0-based index.
  ///
  /// [mapWithIndex] is similar to [map] but the transformation
  /// function receives the index of each value in the sequence.
  ///
  /// ### When to use
  /// Use [mapWithIndex] when your transformation depends on the
  /// position of the value.
  ///
  /// - **Position Tracking**: Including position in the output.
  /// - **ID Generation**: Generating IDs based on position.
  /// - **Progress Tracking**: Tracking progress through a sequence.
  /// - **Offset Calculation**: Calculating offsets based on position.
  /// - **Enumeration**: Enumerating items in a sequence.
  /// - **Pattern Generation**: Generating patterns based on index.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [project] is called with the payload and index.
  /// 3. The index starts at 0 and increments on each typed pulse.
  /// 4. The result is emitted as a typed pulse.
  /// 5. If [project] throws an error, the pulse is dropped.
  /// 6. The emitted pulse gets the step `'MapWithIndex'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Index Type**: The index is a 0-based integer.
  /// - **Typed Only**: Only typed pulses increment the index.
  /// - **Error Handling**: If [project] throws, the pulse is dropped
  ///   and the index is not incremented.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **Indexed Transformation Function.** Called with each
  ///   typed payload and its index, returns the transformed value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed values.
  ///
  /// ### Example
  /// ```dart
  /// final items = Cell.ingress<String>();
  ///
  /// final handle = Flow.mapWithIndex<String, String>(
  ///   items.cell,
  ///   project: (item, index) => 'Item #${index + 1}: $item',
  /// );
  ///
  /// items.emit('Apple');  // -> Item #1: Apple
  /// items.emit('Banana'); // -> Item #2: Banana
  /// ```
  ///
  /// ### See Also:
  /// - [map]: For standard mapping.
  /// - [mapTo]: For constant mapping.
  /// - [mapNotNull]: For dropping null results.
  static FlowHandle mapWithIndex<S, T>(
      Cell source, {
        required T Function(S value, int index) project,
        MapErrorHandler? onError,
      }) {
    return MapWithIndex<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Projects each payload and suppresses the pulse if the result is `null`.
  ///
  /// [mapNotNull] is similar to [map] but the transformation
  /// function can return `null`, which will be dropped (not emitted).
  ///
  /// ### When to use
  /// Use [mapNotNull] when you want to skip values that don't meet a
  /// criteria by returning `null`.
  ///
  /// - **Filtering with Transformation**: Filter and transform in one step.
  /// - **Optional Values**: Only emitting when a value is present.
  /// - **Validation**: Skipping invalid values.
  /// - **Conditional Mapping**: Only mapping valid values.
  /// - **Data Cleaning**: Skipping null or invalid data.
  /// - **Optional Extraction**: Extracting optional fields.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [project] is called with the payload.
  /// 3. If [project] returns `null`, the pulse is dropped.
  /// 4. If [project] returns a non-null value, it's emitted.
  /// 5. If [project] throws an error, the pulse is dropped.
  /// 6. The emitted pulse gets the step `'MapNotNull'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Null Dropping**: `null` results are dropped silently.
  /// - **Type Safety**: The output type [T] is non-nullable.
  /// - **Error Handling**: If [project] throws, the pulse is dropped.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **Optional Transformation Function.** Called with each
  ///   typed payload, returns `T?` or `null` to drop.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload (non-nullable).
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.mapNotNull<int, int>(
  ///   input.cell,
  ///   project: (n) => n.isEven ? n : null,
  /// );
  ///
  /// input.emit(1); // dropped
  /// input.emit(2); // -> 2
  /// input.emit(3); // dropped
  /// input.emit(4); // -> 4
  /// ```
  ///
  /// ### See Also:
  /// - [map]: For standard mapping.
  /// - [mapWhen]: For conditional mapping.
  static FlowHandle mapNotNull<S, T>(
      Cell source, {
        required T? Function(S value) project,
        MapErrorHandler? onError,
      }) {
    return MapNotNull<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Project only when [test] is true.
  ///
  /// [mapWhen] combines filtering and mapping into a single operation.
  /// Values that pass the test are mapped; values that fail are dropped.
  ///
  /// ### When to use
  /// Use [mapWhen] when you want to filter and map in one step.
  ///
  /// - **Filter and Transform**: Filtering and transforming in one pass.
  /// - **Conditional Mapping**: Only mapping values that meet criteria.
  /// - **Data Validation**: Validating and transforming data.
  /// - **Type Safety**: Ensuring values meet criteria before mapping.
  /// - **Data Cleaning**: Cleaning data while transforming.
  /// - **Selective Processing**: Processing only certain values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [test] is called with the payload.
  /// 3. If [test] returns `false`, the pulse is dropped.
  /// 4. If [test] returns `true`, [project] is called with the payload.
  /// 5. The result is emitted as a typed pulse.
  /// 6. If [test] or [project] throws an error, the pulse is dropped.
  /// 7. The emitted pulse gets the step `'MapWhen'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Two Steps**: Test then project (both synchronous).
  /// - **Dropping**: If [test] fails, the pulse is dropped.
  /// - **Error Handling**: If [test] or [project] throws, the pulse is dropped.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Called with each typed payload,
  ///   returns `true` to map, `false` to drop.
  /// - [project]: **Transformation Function.** Called with each typed
  ///   payload that passes [test], returns the transformed value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.mapWhen<int, String>(
  ///   input.cell,
  ///   test: (n) => n.isEven,
  ///   project: (n) => 'even-$n',
  /// );
  ///
  /// input.emit(1); // dropped
  /// input.emit(2); // -> even-2
  /// input.emit(3); // dropped
  /// input.emit(4); // -> even-4
  /// ```
  ///
  /// ### See Also:
  /// - [map]: For standard mapping.
  /// - [mapNotNull]: For dropping null results.
  static FlowHandle mapWhen<S, T>(
      Cell source, {
        required bool Function(S value) test,
        required T Function(S value) project,
        MapErrorHandler? onError,
      }) {
    return MapWhen<S, T>(test, project, onError: onError).toHandle(source: source);
  }

  /// [MapWhen] under the MapValue name.
  static FlowHandle mapValueIf<S, T>(
      Cell source, {
        required bool Function(S value) test,
        required T Function(S value) project,
        MapErrorHandler? onError,
      }) {
    return MapValueIf<S, T>(test, project, onError: onError)
        .toHandle(source: source);
  }

  /// Project, or [orElse] when [project] throws.
  ///
  /// [mapValueOr] provides graceful error handling by allowing a
  /// fallback value when the mapping function fails.
  ///
  /// ### When to use
  /// Use [mapValueOr] when your mapping function may throw and you
  /// want to provide a fallback value.
  ///
  /// - **Division by Zero**: Handling division by zero gracefully.
  /// - **Data Parsing**: Parsing data with fallback on parse errors.
  /// - **API Responses**: Handling malformed API responses.
  /// - **Type Casting**: Safe type casting with fallback.
  /// - **Calculations**: Calculations that may fail.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [project] is called with the payload.
  /// 3. If [project] succeeds, the result is emitted.
  /// 4. If [project] throws an error, [orElse] is called with the
  ///    value and the error.
  /// 5. If [orElse] succeeds, the result is emitted with step
  ///    `'MapValueOr.orElse'`.
  /// 6. If [orElse] throws, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **Two-Level Error Handling**: Errors in [project] go to [orElse].
  /// - **Errors in [orElse]**: If [orElse] throws, the pulse is dropped.
  /// - **Provenance Preservation**: Fallback emissions get the step
  ///   `'MapValueOr.orElse'` to distinguish them.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **Transformation Function.** Called with each typed
  ///   payload, returns the transformed value.
  /// - [orElse]: **Fallback Function.** Called with the value and error
  ///   when [project] throws, returns the fallback value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.mapValueOr<int, int>(
  ///   input.cell,
  ///   project: (n) => n == 0 ? throw StateError('zero') : 10 ~/ n,
  ///   orElse: (_, __) => 0,
  /// );
  ///
  /// input.emit(0); // -> 0 (fallback)
  /// input.emit(5); // -> 2
  /// ```
  ///
  /// ### See Also:
  /// - [map]: For standard mapping.
  /// - [mapNotNull]: For dropping null results.
  static FlowHandle mapValueOr<S, T>(
      Cell source, {
        required T Function(S value) project,
        required T Function(S value, Object error) orElse,
        MapErrorHandler? onError,
      }) {
    return MapValueOr<S, T>(
      project,
      orElse: orElse,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Payload is a [Map]; project each value.
  ///
  /// [mapValues] is a specialized operator for transforming the values
  /// of a map payload.
  ///
  /// ### When to use
  /// Use [mapValues] when you have a map payload and want to transform
  /// its values.
  ///
  /// - **Data Transformation**: Transforming values in a map.
  /// - **Data Enrichment**: Enriching map values.
  /// - **Type Conversion**: Converting map value types.
  /// - **Data Cleaning**: Cleaning map values.
  /// - **Formatting**: Formatting map values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked to ensure it's a `Map`.
  /// 2. For each entry in the map, [project] is called with the value.
  /// 3. A new map is created with the same keys and transformed values.
  /// 4. The new map is emitted.
  /// 5. If [project] throws an error, the pulse is dropped.
  /// 6. The emitted pulse gets the step `'MapValues'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Map Payload Required**: The payload must be a `Map`.
  /// - **Keys Preserved**: The keys remain unchanged.
  /// - **Type Safety**: Generic over key type [K], value type [V],
  ///   and result type [R].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the map payloads.
  /// - [project]: **Value Transformation Function.** Called with each
  ///   map value, returns the transformed value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [K]: The type of the map keys.
  /// - [V]: The type of the map values.
  /// - [R]: The type of the transformed values.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed maps.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<Map<String, int>>();
  ///
  /// final handle = Flow.mapValues<String, int, int>(
  ///   input.cell,
  ///   project: (n) => n * 2,
  /// );
  ///
  /// input.emit({'a': 1, 'b': 2}); // -> {'a': 2, 'b': 4}
  /// ```
  ///
  /// ### See Also:
  /// - [mapKeys]: For transforming map keys.
  static FlowHandle mapValues<K, V, R>(
      Cell source, {
        required R Function(V value) project,
        MapErrorHandler? onError,
      }) {
    return MapValues<K, V, R>(project, onError: onError)
        .toHandle(source: source);
  }

  /// Payload is a [Map]; project each key.
  ///
  /// [mapKeys] is a specialized operator for transforming the keys
  /// of a map payload.
  ///
  /// ### When to use
  /// Use [mapKeys] when you have a map payload and want to transform
  /// its keys.
  ///
  /// - **Key Transformation**: Transforming map keys.
  /// - **Key Type Conversion**: Converting map key types.
  /// - **Key Normalization**: Normalizing map keys (e.g., lowercase).
  /// - **Key Filtering**: Filtering map keys.
  /// - **Key Mapping**: Mapping keys to different values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked to ensure it's a `Map`.
  /// 2. For each entry in the map, [project] is called with the key.
  /// 3. A new map is created with transformed keys and the same values.
  /// 4. The new map is emitted.
  /// 5. If [project] throws an error, the pulse is dropped.
  /// 6. The emitted pulse gets the step `'MapKeys'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Map Payload Required**: The payload must be a `Map`.
  /// - **Values Preserved**: The values remain unchanged.
  /// - **Type Safety**: Generic over key type [K], value type [V],
  ///   and result key type [R].
  /// - **Key Collisions**: If two keys map to the same value, the last
  ///   one wins (standard Map behavior).
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the map payloads.
  /// - [project]: **Key Transformation Function.** Called with each
  ///   map key, returns the transformed key.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [K]: The type of the input map keys.
  /// - [V]: The type of the map values.
  /// - [R]: The type of the transformed keys.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the transformed maps.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<Map<String, int>>();
  ///
  /// final handle = Flow.mapKeys<String, int, String>(
  ///   input.cell,
  ///   project: (key) => key.toLowerCase(),
  /// );
  ///
  /// input.emit({'A': 1, 'B': 2}); // -> {'a': 1, 'b': 2}
  /// ```
  ///
  /// ### See Also:
  /// - [mapValues]: For transforming map values.
  static FlowHandle mapKeys<K, V, R>(
      Cell source, {
        required R Function(K key) project,
        MapErrorHandler? onError,
      }) {
    return MapKeys<K, V, R>(project, onError: onError).toHandle(source: source);
  }

  /// Extracts the value at [key] from a [Map] payload (Rx `pluck`).
  ///
  /// [pluck] extracts a single field from each payload using the
  /// provided [key]. The extracted value is emitted as a typed pulse.
  ///
  /// ### When to use
  /// Use [pluck] when you need to extract a single field from a
  /// complex payload.
  ///
  /// - **Data Extraction**: Extracting fields from API responses.
  /// - **Field Access**: Accessing properties of objects.
  /// - **Data Transformation**: Extracting values for further processing.
  /// - **Filtering**: Extracting fields for filtering logic.
  /// - **Mapping**: Mapping complex objects to simple values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is read using [key].
  /// 2. The extracted value is type-checked to ensure it matches [T].
  /// 3. If successful, the value is emitted as a typed pulse.
  /// 4. If extraction fails, [onError] is called and the pulse is dropped.
  /// 5. The pulse gets the step `'Pluck'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Type Safety**: The extracted value must match type [T].
  /// - **Error Handling**: Missing keys or type mismatches drop the pulse.
  /// - **Source Types**: Supports Map, List/Iterable, and objects with `[]`.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the payloads.
  /// - [key]: **The Key to Extract.** The field name or index to look up.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The expected type of the extracted value.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the extracted values.
  ///
  /// ### Example
  /// ```dart
  /// final users = Cell.ingress<Map<String, Object>>();
  ///
  /// final handle = Flow.pluck<String>(
  ///   users.cell,
  ///   key: 'name',
  /// );
  ///
  /// users.emit({'id': 1, 'name': 'Alice'}); // -> Alice
  /// users.emit({'id': 2, 'name': 'Bob'});   // -> Bob
  /// ```
  ///
  /// ### See Also:
  /// - [pluckOr]: For extraction with default values.
  /// - [pluckAll]: For extracting multiple fields.
  /// - [pluckPath]: For extracting nested fields.
  static FlowHandle pluck<T>(
      Cell source, {
        required Object key,
        PluckErrorHandler? onError,
      }) {
    return Pluck<T>(key, onError: onError).toHandle(source: source);
  }

  /// Pluck with [orElse] when the field is missing.
  ///
  /// [pluckOr] is similar to [pluck] but provides a default value when
  /// the field is missing or has the wrong type.
  ///
  /// ### When to use
  /// Use [pluckOr] when you need to extract a field but want to
  /// provide a default value on failure.
  ///
  /// - **Optional Fields**: Extracting optional fields with defaults.
  /// - **Graceful Degradation**: Providing defaults on missing data.
  /// - **Fallback Values**: Using fallback values on errors.
  /// - **Data Cleaning**: Cleaning missing data with defaults.
  /// - **Default Configuration**: Using default configuration values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is read using [key].
  /// 2. If the value exists and matches type [T], it's emitted.
  /// 3. If the value is missing or has the wrong type, [orElse] is emitted.
  /// 4. The default value always matches type [T].
  /// 5. The pulse gets the step `'PluckOr'` (or `'PluckOr.orElse'` for defaults).
  ///
  /// ### Non‑obvious
  /// - **Always Emits**: A value is always emitted (success or default).
  /// - **Type Safety**: The default must match type [T].
  /// - **Error Handling**: Errors are caught and the default is used.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the payloads.
  /// - [key]: **The Key to Extract.** The field name or index to look up.
  /// - [orElse]: **Default Value.** The value to emit on failure.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The expected type of the extracted value and the default.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the extracted values.
  ///
  /// ### Example
  /// ```dart
  /// final users = Cell.ingress<Map<String, Object>>();
  ///
  /// final handle = Flow.pluckOr<String>(
  ///   users.cell,
  ///   key: 'city',
  ///   orElse: 'Unknown',
  /// );
  ///
  /// users.emit({'id': 1, 'name': 'Alice', 'city': 'NYC'}); // -> NYC
  /// users.emit({'id': 2, 'name': 'Bob'});                  // -> Unknown
  /// ```
  ///
  /// ### See Also:
  /// - [pluck]: For simple field extraction.
  /// - [pluckAll]: For extracting multiple fields.
  /// - [pluckPath]: For extracting nested fields.
  static FlowHandle pluckOr<T>(
      Cell source, {
        required Object key,
        required T orElse,
        PluckErrorHandler? onError,
      }) {
    return PluckOr<T>(key, orElse: orElse, onError: onError)
        .toHandle(source: source);
  }

  /// Pluck several keys into a [Map].
  ///
  /// [pluckAll] extracts multiple fields from each payload and returns
  /// them as a map. This is useful when you need several fields at once.
  ///
  /// ### When to use
  /// Use [pluckAll] when you need to extract multiple fields from a
  /// payload.
  ///
  /// - **Data Projection**: Projecting multiple fields from an object.
  /// - **Data Transformation**: Creating a subset of fields.
  /// - **API Responses**: Extracting specific fields from API responses.
  /// - **Data Aggregation**: Aggregating multiple fields.
  /// - **View Models**: Creating view models from data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is read for each key in [keys].
  /// 2. For each key, the value is extracted.
  /// 3. If [useOrElse] is `true`, missing keys get [orElse].
  /// 4. If [useOrElse] is `false`, missing keys trigger [onError].
  /// 5. The collected key-value pairs are emitted as a map.
  /// 6. The pulse gets the step `'PluckAll'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Map Output**: The output is always a `Map<Object, Object?>`.
  /// - **Partial Success**: Even if some keys fail, successful ones are
  ///   included in the output.
  /// - **Error Handling**: Missing keys can either use defaults or trigger
  ///   error handlers.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the payloads.
  /// - [keys]: **The Keys to Extract.** An iterable of field names or indices.
  /// - [orElse]: **Default Value.** Used when [useOrElse] is `true`.
  /// - [useOrElse]: **Use Default.** If `true`, missing keys get [orElse].
  ///   If `false`, missing keys trigger [onError]. Defaults to `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the extracted maps.
  ///
  /// ### Example
  /// ```dart
  /// final users = Cell.ingress<Map<String, Object>>();
  ///
  /// final handle = Flow.pluckAll(
  ///   users.cell,
  ///   keys: ['id', 'name', 'email'],
  /// );
  ///
  /// users.emit({
  ///   'id': 1,
  ///   'name': 'Alice',
  ///   'email': 'alice@example.com',
  ///   'extra': 'ignored'
  /// });
  /// // -> {id: 1, name: Alice, email: alice@example.com}
  /// ```
  ///
  /// ### See Also:
  /// - [pluck]: For single field extraction.
  /// - [pluckOr]: For single field extraction with default.
  /// - [pluckPath]: For nested field extraction.
  static FlowHandle pluckAll(
      Cell source, {
        required Iterable<Object> keys,
        Object? orElse,
        bool useOrElse = false,
        PluckErrorHandler? onError,
      }) {
    return PluckAll(
      keys,
      orElse: orElse,
      useOrElse: useOrElse,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Walk a nested [path].
  ///
  /// [pluckPath] navigates nested structures by following a sequence
  /// of keys. This allows extracting deeply nested fields from complex
  /// objects.
  ///
  /// ### When to use
  /// Use [pluckPath] when you need to extract a deeply nested field
  /// from a complex object.
  ///
  /// - **Deep Navigation**: Extracting deeply nested values.
  /// - **JSON Traversal**: Navigating JSON responses.
  /// - **Object Graph**: Traversing object graphs.
  /// - **Nested Data**: Extracting data from nested structures.
  /// - **Data Unwrapping**: Unwrapping nested data containers.
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is used as the starting point.
  /// 2. For each key in [path], the current value is read using that key.
  /// 3. The value becomes the new current value for the next key.
  /// 4. After all keys are processed, the final value is emitted.
  /// 5. If any step fails, [onError] is called and the pulse is dropped.
  /// 6. If [useOrElse] is `true`, [orElse] is emitted on failure.
  /// 7. The pulse gets the step `'PluckPath'` (or `'PluckPath.orElse'` for defaults).
  ///
  /// ### Non‑obvious
  /// - **Path Traversal**: The path is walked left to right.
  /// - **Any Step Failure**: If any step in the path fails, the whole
  ///   extraction fails.
  /// - **Type Safety**: The final value must match type [T].
  /// - **Error Handling**: Missing keys or type mismatches can trigger
  ///   error handlers or fallbacks.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the payloads.
  /// - [path]: **The Navigation Path.** An iterable of keys to follow.
  /// - [orElse]: **Default Value.** Used when [useOrElse] is `true`.
  /// - [useOrElse]: **Use Default.** If `true`, missing path steps get
  ///   [orElse]. If `false`, missing steps trigger [onError]. Defaults
  ///   to `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The expected type of the final extracted value.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the extracted values.
  ///
  /// ### Example
  /// ```dart
  /// final users = Cell.ingress<Map<String, Object>>();
  ///
  /// final handle = Flow.pluckPath<String>(
  ///   users.cell,
  ///   path: ['user', 'profile', 'name'],
  /// );
  ///
  /// users.emit({
  ///   'user': {
  ///     'profile': {
  ///       'name': 'Alice',
  ///       'age': 30
  ///     }
  ///   }
  /// });
  /// // -> Alice
  /// ```
  ///
  /// ### See Also:
  /// - [pluck]: For single field extraction.
  /// - [pluckOr]: For single field extraction with default.
  /// - [pluckAll]: For extracting multiple fields.
  static FlowHandle pluckPath<T>(
      Cell source, {
        required Iterable<Object> path,
        T? orElse,
        bool useOrElse = false,
        PluckErrorHandler? onError,
      }) {
    return PluckPath<T>(
      path,
      orElse: orElse,
      useOrElse: useOrElse,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Applies an [accumulate] function over the pulses, emitting each
  /// intermediate result (Rx `scan`).
  ///
  /// [scan] acts as a **Seedless Accumulator**. The first typed value becomes
  /// the seed and is **not** emitted. Every later value is combined with the
  /// running total and the new total is emitted.
  ///
  /// ### When to use
  /// Use [scan] when you need to accumulate values over time:
  ///
  /// - **Running Totals**: Computing a running sum, average, or count
  /// - **Reducers**: When the first sample itself is the starting amount
  /// - **State Machines**: Tracking state transitions over time
  /// - **Data Aggregation**: Aggregating data from a stream
  /// - **Progressive Enrichment**: Building a result incrementally
  /// - **Event Sourcing**: Building an aggregate from a stream of events
  ///
  /// ### How it works
  /// 1. The first typed pulse becomes the accumulator and is stored.
  /// 2. The first pulse is **not** emitted.
  /// 3. For each subsequent pulse, [accumulate] is called with the
  ///    current accumulator and the new value.
  /// 4. The result becomes the new accumulator and is emitted.
  ///
  /// ### Non‑obvious
  /// - **No Seed**: The first value is used as the seed and not emitted.
  /// - **Silent First**: The instruction is silent on the first pulse.
  /// - **State Persistence**: The accumulator is maintained across pulses.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [accumulate]: **The Accumulation Function.** Takes the current
  ///   accumulator and the new value, returns the new accumulator.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload from the source cell.
  /// - [A]: The type of the accumulator state.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the accumulated values.
  ///
  /// ### Example
  /// ```dart
  /// final nums = Cell.ingress<int>();
  ///
  /// final handle = Flow.scan<int, int>(
  ///   nums.cell,
  ///   accumulate: (acc, n) => acc + n,
  /// );
  ///
  /// nums.emit(1); // No output (becomes seed)
  /// nums.emit(2); // -> 3
  /// nums.emit(3); // -> 6
  /// // Result: `[3, 6]`
  /// ```
  ///
  /// ### See Also:
  /// - [reduce]: For using an explicit seed value.
  /// - [pairwise]: For emitting adjacent pairs.
  static FlowHandle scan<S, A>(
      Cell source, {
        required A Function(A acc, S value) accumulate,
      }) {
    return Scan<S, A>(accumulate).toHandle(source: source);
  }

  /// Similar to [scan], but uses an explicit [seed] value to initialize
  /// the accumulator.
  ///
  /// [reduce] acts as a **Seeded Accumulator**. The seed is combined with
  /// the first typed value, so the first pulse already emits an accumulated
  /// result.
  ///
  /// ### When to use
  /// Use [reduce] when:
  /// - You want to provide an explicit initial state
  /// - You want the first pulse to emit a result
  /// - You're implementing a running total starting from a known base
  /// - You're building a state machine with an initial state
  ///
  /// ### How it works
  /// 1. The [seed] is stored as the initial accumulator.
  /// 2. For each pulse, [accumulate] is called with the current
  ///    accumulator and the new value.
  /// 3. The result becomes the new accumulator and is emitted.
  ///
  /// ### Non‑obvious
  /// - **Explicit Seed**: The seed is provided as a parameter.
  /// - **First Pulse Emits**: The first pulse always emits a result.
  /// - **State Persistence**: The accumulator is maintained across pulses.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [seed]: **The Initial State.** The starting value of the accumulator.
  /// - [accumulate]: **The Accumulation Function.** Takes the current
  ///   accumulator and the new value, returns the new accumulator.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload from the source cell.
  /// - [A]: The type of the accumulator state.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the accumulated values.
  ///
  /// ### Example
  /// ```dart
  /// final nums = Cell.ingress<int>();
  ///
  /// final handle = Flow.reduce<int, int>(
  ///   nums.cell,
  ///   seed: 0,
  ///   accumulate: (acc, n) => acc + n,
  /// );
  ///
  /// nums.emit(1); // -> 1
  /// nums.emit(2); // -> 3
  /// nums.emit(3); // -> 6
  /// // Result: `[1, 3, 6]`
  /// ```
  ///
  /// ### See Also:
  /// - [scan]: For seedless accumulation.
  /// - [pairwise]: For emitting adjacent pairs.
  static FlowHandle reduce<S, A>(
      Cell source, {
        required A seed,
        required A Function(A acc, S value) accumulate,
      }) {
    return Reduce<S, A>(seed, accumulate).toHandle(source: source);
  }

  /// Emits a tuple of the `(previous, current)` payloads for every pulse
  /// after the first.
  ///
  /// [pairwise] acts as a **Sliding Window of Size 2**. It maintains a sliding
  /// window of the last two values and emits them as a pair for each consecutive
  /// pair in the stream.
  ///
  /// ### When to use
  /// Use [pairwise] when you need to compare adjacent values:
  ///
  /// - **Deltas**: Computing `current - previous` for change detection
  /// - **Edge Detection**: Detecting direction changes or state transitions
  /// - **Trend Analysis**: Comparing a reading to the one before it
  /// - **Change Detection**: Detecting when a value changes
  /// - **Motion Detection**: Detecting movement based on position changes
  /// - **Signal Processing**: Computing derivatives or differences
  ///
  /// ### How it works
  /// 1. The first typed pulse is stored and **not** emitted.
  /// 2. For each subsequent pulse, the previous value and the current value
  ///    are emitted as a pair `(previous, current)`.
  /// 3. The current value becomes the previous value for the next pair.
  ///
  /// ### Non‑obvious
  /// - **Sliding Window**: Only the last two values are kept.
  /// - **First Pulse Silent**: The first pulse is not emitted.
  /// - **State Persistence**: Only the previous value is stored (O(1) memory).
  /// - **Order Preservation**: Results are emitted in input order.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload from the source cell.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the emitted pairs.
  ///
  /// ### Example
  /// ```dart
  /// final ticks = Cell.ingress<int>();
  ///
  /// final handle = Flow.pairwise<int>(ticks.cell);
  ///
  /// ticks.emit(1); // No output (stored)
  /// ticks.emit(2); // -> (1, 2)
  /// ticks.emit(3); // -> (2, 3)
  /// // Result: `[(1, 2), (2, 3)]`
  /// ```
  ///
  /// ### See Also:
  /// - [scan]: For accumulating values over time.
  /// - [reduce]: For explicit seed accumulation.
  static FlowHandle pairwise<S>(Cell source) {
    return Pairwise<S>().toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Async transform
  // ─────────────────────────────────────────────────────────────

  /// Maps each payload through an asynchronous [mapper].
  ///
  /// [asyncMap] processes pulses **sequentially**. If a new pulse arrives while a
  /// mapper is still running, it is queued until the previous one completes.
  ///
  /// ### When to use
  /// Use [asyncMap] when you need to perform I/O or heavy computation where
  /// order must be strictly preserved.
  /// - **Database Writes**: Ensuring records are saved in order.
  /// - **API Requests**: When the server requires sequential processing.
  ///
  /// ### How it works
  /// 1. Incoming pulses are added to an internal queue.
  /// 2. The [mapper] is called for the first item in the queue.
  /// 3. The instruction waits for the resulting [Future] to resolve.
  /// 4. Once resolved, the next item in the queue is processed.
  ///
  /// ### Non‑obvious
  /// - **Backpressure**: Rapid inputs will cause the queue to grow.
  /// - **Serialization**: Guaranteed to process only one future at a time.
  /// - **Error Isolation**: A failure in one mapper does not stop the queue.
  ///
  /// [asyncMap] is the foundational asynchronous mapping operator. It
  /// processes inputs one at a time, waiting for each async operation
  /// to complete before starting the next.
  ///
  /// ### When to use
  /// Use [asyncMap] when you need to perform async operations on each
  /// value and order matters.
  ///
  /// - **Network Requests**: Making sequential API calls.
  /// - **Database Operations**: Sequential database queries.
  /// - **File I/O**: Reading/writing files sequentially.
  /// - **Data Enrichment**: Enriching data with async sources.
  /// - **Image Processing**: Processing images sequentially.
  /// - **Encryption/Decryption**: Applying async crypto operations.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [mapper].
  /// 2. The async operation is awaited.
  /// 3. The result is emitted.
  /// 4. Inputs are queued while processing.
  /// 5. If [mapper] throws an error, it's reported and the instruction
  ///    continues with the next input.
  /// 6. Each emitted value gets the step `'AsyncMap'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Sequential Processing**: Operations run one after another.
  /// - **Queueing**: Inputs are queued while processing.
  /// - **No Cancellation**: Previous operations are not cancelled.
  /// - **Error Isolation**: Errors don't stop the queue.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final ids = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncMap<int, User>(
  ///   ids.cell,
  ///   mapper: (id) async => await api.getUser(id),
  /// );
  ///
  /// ids.emit(1); // -> User 1
  /// ids.emit(2); // -> User 2 (after User 1 completes)
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMapConcurrent]: For concurrent mapping.
  /// - [asyncMapLatest]: For latest-only mapping.
  static FlowHandle asyncMap<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMap<S, T>(mapper, onError: onError).toHandle(source: source);
  }

  /// Similar to [asyncMap], but processes pulses **concurrently** as they arrive.
  ///
  /// [asyncMapConcurrent] processes inputs concurrently, emitting
  /// results as they complete. Order is not preserved.
  ///
  /// ### When to use
  /// Use [asyncMapConcurrent] when you want maximum throughput and
  /// order doesn't matter.
  ///
  /// - **Parallel Processing**: Processing multiple items in parallel.
  /// - **Throughput**: Maximizing throughput.
  /// - **Independent Operations**: When operations are independent.
  /// - **Batch Processing**: Processing batches in parallel.
  /// - **API Calls**: Making parallel API calls.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [mapper] immediately.
  /// 2. Multiple async operations run concurrently.
  /// 3. Results are emitted as they complete.
  /// 4. Order is not preserved.
  /// 5. If [mapper] throws an error, it's reported independently.
  ///
  /// ### Non‑obvious
  /// - **Unordered**: Results are emitted in completion order.
  /// - **Unlimited Concurrency**: All operations start immediately.
  /// - **No Queuing**: No queuing; operations start immediately.
  /// - **Error Isolation**: Errors are reported independently.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final ids = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncMapConcurrent<int, User>(
  ///   ids.cell,
  ///   mapper: (id) async => await api.getUser(id),
  /// );
  ///
  /// ids.emit(1); // Starts fetching
  /// ids.emit(2); // Starts fetching (parallel)
  /// // Results arrive in completion order
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping.
  /// - [asyncMapLatest]: For latest-only mapping.
  static FlowHandle asyncMapConcurrent<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapConcurrent<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Similar to [asyncMap], but only processes the **latest** pulse.
  ///
  /// Any in-flight asynchronous work is abandoned when a new pulse arrives.
  ///
  /// [asyncMapLatest] only emits results from the most recent operation.
  /// Previous in-flight operations are cancelled (dropped).
  ///
  /// ### When to use
  /// Use [asyncMapLatest] when you only care about the most recent
  /// operation.
  ///
  /// - **Search-as-you-type**: Only the latest search query matters.
  /// - **Real-time Updates**: Only the most recent update is relevant.
  /// - **User Input**: Only the latest user input matters.
  /// - **Selection Changes**: Only the latest selection matters.
  /// - **Navigation**: Only the latest route matters.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [mapper].
  /// 2. A new generation ID is assigned to each trigger.
  /// 3. Any previous in-flight operation is cancelled.
  /// 4. Only the result from the latest generation is emitted.
  /// 5. If [mapper] throws an error, it's reported only for the current
  ///    generation.
  ///
  /// ### Non‑obvious
  /// - **Generation Tracking**: Each operation gets a unique ID.
  /// - **Silent Cancellation**: Cancelled operations don't emit errors.
  /// - **Latest Only**: Only the most recent operation emits values.
  /// - **Error Isolation**: Only errors from the current generation are
  ///   reported.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final query = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncMapLatest<String, Result>(
  ///   query.cell,
  ///   mapper: (q) async => await api.search(q),
  /// );
  ///
  /// query.emit('dart');     // Starts search
  /// query.emit('flutter');  // Cancels previous, starts new search
  /// // Only 'flutter' results are emitted
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping.
  /// - [asyncMapConcurrent]: For concurrent mapping.
  static FlowHandle asyncMapLatest<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapLatest<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Async map with a 0-based index.
  ///
  /// [asyncMapWithIndex] is similar to [asyncMap] but the mapping
  /// function receives the index of each value in the sequence.
  ///
  /// ### When to use
  /// Use [asyncMapWithIndex] when your transformation depends on the
  /// position of the value.
  ///
  /// - **Position Tracking**: Including position in the output.
  /// - **ID Generation**: Generating IDs based on position.
  /// - **Progress Tracking**: Tracking progress through a sequence.
  /// - **Offset Calculation**: Calculating offsets based on position.
  /// - **Enumeration**: Enumerating items in a sequence.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [mapper] with the payload and index.
  /// 2. The index starts at 0 and increments on each typed pulse.
  /// 3. Results are emitted sequentially.
  /// 4. If [mapper] throws an error, it's reported and the instruction
  ///    continues with the next input.
  /// 5. The index is only incremented on successful completions.
  ///
  /// ### Non‑obvious
  /// - **Index Type**: The index is a 0-based integer.
  /// - **Typed Only**: Only typed pulses increment the index.
  /// - **Sequential**: Operations run one after another.
  /// - **Error Handling**: If [mapper] throws, the index is not incremented.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Indexed Mapping Function.** Called with each typed
  ///   payload and its index, returns a `FutureOr<T>`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final items = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncMapWithIndex<String, String>(
  ///   items.cell,
  ///   mapper: (item, index) async => 'Item #${index + 1}: $item',
  /// );
  ///
  /// items.emit('Apple');  // -> Item #1: Apple
  /// items.emit('Banana'); // -> Item #2: Banana
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping without index.
  /// - [mapWithIndex]: For synchronous indexed mapping.
  static FlowHandle asyncMapWithIndex<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value, int index) mapper,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapWithIndex<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Retry the mapper up to [count] extra times.
  ///
  /// [asyncMapWithRetry] retries failed operations up to [count] times
  /// before giving up.
  ///
  /// ### When to use
  /// Use [asyncMapWithRetry] when operations may fail transiently.
  ///
  /// - **Unreliable Services**: API calls may fail transiently.
  /// - **Network Operations**: Network errors should be retried.
  /// - **Rate Limiting**: Operations that may be rate-limited.
  /// - **Database Operations**: Transactions that may conflict.
  /// - **External Dependencies**: Operations that depend on external systems.
  ///
  /// ### How it works
  /// 1. Each operation is attempted up to [count] times.
  /// 2. If all retries fail, the error is reported.
  /// 3. The instruction continues with the next input.
  /// 4. Each emitted value gets the step `'AsyncMapWithRetry'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Total Attempts**: The operation may run `count + 1` times.
  /// - **No Delay**: Retries are immediate.
  /// - **Error Reporting**: Only the final failure is reported.
  /// - **Sequential**: Operations run one after another.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [count]: **Maximum Retry Attempts.** Defaults to 3.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final requests = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncMapWithRetry<String, String>(
  ///   requests.cell,
  ///   mapper: (url) async => await http.get(url).then((r) => r.body),
  ///   count: 3,
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping.
  /// - [retry]: For general retry logic.
  static FlowHandle asyncMapWithRetry<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        int count = 3,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapWithRetry<S, T>(mapper, count: count, onError: onError)
        .toHandle(source: source);
  }

  /// Time-box one projection.
  ///
  /// [asyncMapWithTimeout] ensures that async operations complete within
  /// a specified time limit, throwing an error if they exceed it.
  ///
  /// ### When to use
  /// Use [asyncMapWithTimeout] when operations must complete quickly.
  ///
  /// - **Time-Sensitive Operations**: Operations that must complete quickly.
  /// - **User Experience**: Preventing hanging operations.
  /// - **Service Level Agreements**: Enforcing response time limits.
  /// - **Resource Protection**: Preventing resource exhaustion.
  ///
  /// ### How it works
  /// 1. Each operation is started with a timeout.
  /// 2. If the operation exceeds [duration], a [TimeoutException] is thrown.
  /// 3. The error is reported via [onError].
  /// 4. The instruction continues with the next input.
  ///
  /// ### Non‑obvious
  /// - **Timer Precision**: Timers are based on the event loop.
  /// - **Cancellation**: Timed-out operations are cancelled.
  /// - **Error Reporting**: Timeouts are reported via [onError].
  /// - **Sequential**: Operations run one after another.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [duration]: **Timeout Duration.** Required. Operations exceeding
  ///   this time will be cancelled.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final requests = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncMapWithTimeout<String, String>(
  ///   requests.cell,
  ///   mapper: (url) async => await http.get(url).then((r) => r.body),
  ///   duration: Duration(seconds: 5),
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping.
  /// - [timeout]: For idle timeout.
  static FlowHandle asyncMapWithTimeout<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        required Duration duration,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapWithTimeout<S, T>(
      mapper,
      duration: duration,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Emit [fallback] when the mapper throws.
  ///
  /// [asyncMapWithFallback] provides a safety net for async operations
  /// that may fail, ensuring that a value is always emitted.
  ///
  /// ### When to use
  /// Use [asyncMapWithFallback] when you want to provide a default
  /// value on error.
  ///
  /// - **Graceful Degradation**: Providing a default on failure.
  /// - **Caching**: Serving stale cached data on failure.
  /// - **Offline Support**: Providing offline defaults.
  /// - **Resilience**: Preventing failures from propagating.
  ///
  /// ### How it works
  /// 1. Each operation is attempted.
  /// 2. If successful, the result is emitted.
  /// 3. If the operation fails, [fallback] is emitted instead.
  /// 4. The instruction always emits a value.
  ///
  /// ### Non‑obvious
  /// - **Always Emits**: A value is always emitted (success or fallback).
  /// - **Error Isolation**: Errors are caught and handled gracefully.
  /// - **Type Safety**: The fallback must return the same type [T].
  /// - **Sequential**: Operations run one after another.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [mapper]: **Mapping Function.** Called with each typed payload,
  ///   returns a `FutureOr<T>`.
  /// - [fallback]: **Fallback Value.** Emitted when the mapping fails.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final requests = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncMapWithFallback<String, String>(
  ///   requests.cell,
  ///   mapper: (url) async => await api.fetch(url),
  ///   fallback: 'Cached data',
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [asyncMap]: For sequential mapping.
  /// - [asyncMapWithRetry]: For retry logic.
  static FlowHandle asyncMapWithFallback<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        required T fallback,
        AsyncMapErrorHandler? onError,
      }) {
    return AsyncMapWithFallback<S, T>(
      mapper,
      fallback: fallback,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flatten an inner sequence per payload (Dart `asyncExpand`).
  ///
  /// [asyncExpand] processes inputs one at a time, waiting for each
  /// inner sequence to complete before starting the next. This ensures
  /// strict ordering but may be slower for long-running operations.
  ///
  /// ### When to use
  /// Use [asyncExpand] when you need to preserve order and process
  /// operations sequentially.
  ///
  /// - **Order Matters**: When output order must match input order.
  /// - **Resource Constraints**: When resources are limited.
  /// - **Sequential Processing**: When operations must run one after another.
  /// - **Transaction Ordering**: When transactions must be ordered.
  /// - **File Processing**: Processing files in order.
  /// - **API Calls**: Making sequential API calls.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [expand] function.
  /// 2. The inner sequence is drained completely.
  /// 3. Only after completion does the next input start.
  /// 4. Values are emitted in the order of input.
  /// 5. If [expand] throws an error, the error is reported and the
  ///    instruction continues with the next input.
  ///
  /// ### Non‑obvious
  /// - **Strict Ordering**: Output order matches input order.
  /// - **Queueing**: Inputs are queued while processing.
  /// - **No Cancellation**: Previous operations are not cancelled.
  /// - **Error Isolation**: Errors don't stop the queue.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [expand]: **Expansion Function.** Takes an input value and returns
  ///   a `FutureOr<Object?>` that can be drained (Future, Stream, Iterable,
  ///   or value).
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final ids = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncExpand<int, User>(
  ///   ids.cell,
  ///   expand: (id) async => await api.getUser(id),
  /// );
  ///
  /// ids.emit(1); // -> User 1
  /// ids.emit(2); // -> User 2 (after User 1 completes)
  /// ```
  ///
  /// ### See Also:
  /// - [asyncExpandConcurrent]: For concurrent flattening.
  /// - [asyncExpandLatest]: For latest-only flattening.
  /// - [asyncExpandExhaust]: For exhaust flattening.
  static FlowHandle asyncExpand<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) expand,
        ExpandErrorHandler? onError,
      }) {
    return AsyncExpand<S, T>(expand, onError: onError).toHandle(source: source);
  }

  /// Concurrent flatten.
  ///
  /// [asyncExpandConcurrent] processes inputs concurrently, emitting
  /// results as they complete. Order is not preserved.
  ///
  /// ### When to use
  /// Use [asyncExpandConcurrent] when you want maximum throughput and
  /// order doesn't matter.
  ///
  /// - **Parallel Processing**: Processing multiple items in parallel.
  /// - **Throughput**: Maximizing throughput.
  /// - **Independent Operations**: When operations are independent.
  /// - **Batch Processing**: Processing batches in parallel.
  /// - **API Calls**: Making parallel API calls.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [expand] function immediately.
  /// 2. Multiple inner sequences run concurrently.
  /// 3. Results are emitted as they complete.
  /// 4. Order is not preserved.
  /// 5. If [expand] throws an error, it's reported independently.
  ///
  /// ### Non‑obvious
  /// - **Unordered**: Results are emitted in completion order.
  /// - **Unlimited Concurrency**: All operations start immediately.
  /// - **No Queuing**: No queuing; operations start immediately.
  /// - **Error Isolation**: Errors are reported independently.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [expand]: **Expansion Function.** Takes an input value and returns
  ///   a `FutureOr<Object?>` that can be drained.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final ids = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncExpandConcurrent<int, User>(
  ///   ids.cell,
  ///   expand: (id) async => await api.getUser(id),
  /// );
  ///
  /// ids.emit(1); // Starts fetching
  /// ids.emit(2); // Starts fetching (parallel)
  /// // Results arrive in completion order
  /// ```
  ///
  /// ### See Also:
  /// - [asyncExpand]: For sequential flattening.
  /// - [asyncExpandLatest]: For latest-only flattening.
  /// - [asyncExpandExhaust]: For exhaust flattening.
  static FlowHandle asyncExpandConcurrent<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) expand,
        ExpandErrorHandler? onError,
      }) {
    return AsyncExpandConcurrent<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Switch flatten — drop the previous inner.
  ///
  /// [asyncExpandLatest] only emits values from the most recent inner
  /// sequence. Previous sequences are cancelled (dropped) when a new
  /// trigger arrives.
  ///
  /// ### When to use
  /// Use [asyncExpandLatest] when you only care about the most recent
  /// operation.
  ///
  /// - **Search-as-you-type**: Only the latest search query matters.
  /// - **Real-time Updates**: Only the most recent update is relevant.
  /// - **Navigation**: Only the latest route matters.
  /// - **User Input**: Only the latest user input matters.
  /// - **Selection Changes**: Only the latest selection matters.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [expand] function.
  /// 2. A new generation ID is assigned to each trigger.
  /// 3. Any previous inner sequence is cancelled (dropped).
  /// 4. Only values from the most recent generation are emitted.
  /// 5. If [expand] throws an error, it's reported only for the current
  ///    generation.
  ///
  /// ### Non‑obvious
  /// - **Generation Tracking**: Each operation gets a unique ID.
  /// - **Silent Cancellation**: Cancelled operations don't emit errors.
  /// - **Latest Only**: Only the most recent operation emits values.
  /// - **Error Isolation**: Only errors from the current generation are
  ///   reported.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [expand]: **Expansion Function.** Takes an input value and returns
  ///   a `FutureOr<Object?>` that can be drained.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final query = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncExpandLatest<String, Result>(
  ///   query.cell,
  ///   expand: (q) async => await api.search(q),
  /// );
  ///
  /// query.emit('dart');     // Starts search
  /// query.emit('flutter');  // Cancels previous, starts new search
  /// // Only 'flutter' results are emitted
  /// ```
  ///
  /// ### See Also:
  /// - [asyncExpand]: For sequential flattening.
  /// - [asyncExpandConcurrent]: For concurrent flattening.
  /// - [asyncExpandExhaust]: For exhaust flattening.
  static FlowHandle asyncExpandLatest<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) expand,
        ExpandErrorHandler? onError,
      }) {
    return AsyncExpandLatest<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Exhaust flatten — ignore while busy.
  ///
  /// [asyncExpandExhaust] ignores (drops) new triggers while an inner
  /// sequence is still running. This prevents overlapping operations.
  ///
  /// ### When to use
  /// Use [asyncExpandExhaust] when you want to ignore new inputs while
  /// processing.
  ///
  /// - **Rate Limiting**: Ignoring rapid inputs while processing.
  /// - **Debouncing**: Ignoring inputs during processing.
  /// - **Resource Protection**: Preventing resource exhaustion.
  /// - **Single Operation**: Ensuring only one operation runs at a time.
  /// - **Throttling**: Throttling inputs while busy.
  ///
  /// ### How it works
  /// 1. The first incoming pulse triggers the [expand] function.
  /// 2. While the inner sequence is running, new triggers are dropped.
  /// 3. When the inner sequence completes, the next trigger is accepted.
  /// 4. If [expand] throws an error, the busy flag is cleared.
  ///
  /// ### Non‑obvious
  /// - **Dropping**: New triggers are silently dropped while busy.
  /// - **Single Operation**: Only one operation runs at a time.
  /// - **No Queuing**: No queuing; dropped triggers are lost.
  /// - **Error Clearing**: Errors clear the busy flag.
  /// - **Drop First**: The first trigger is always processed.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [expand]: **Expansion Function.** Takes an input value and returns
  ///   a `FutureOr<Object?>` that can be drained.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final clicks = Cell.ingress<String>();
  ///
  /// final handle = Flow.asyncExpandExhaust<String, Result>(
  ///   clicks.cell,
  ///   expand: (input) async {
  ///     await processInput(input);
  ///     return Result(input);
  ///   },
  /// );
  ///
  /// clicks.emit('first');   // -> Result(first)
  /// clicks.emit('second');  // ignored (busy)
  /// clicks.emit('third');   // ignored (busy)
  /// // Only 'first' is processed
  /// ```
  ///
  /// ### See Also:
  /// - [asyncExpand]: For sequential flattening.
  /// - [asyncExpandConcurrent]: For concurrent flattening.
  /// - [asyncExpandLatest]: For latest-only flattening.
  static FlowHandle asyncExpandExhaust<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) expand,
        ExpandErrorHandler? onError,
      }) {
    return AsyncExpandExhaust<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Async running fold (queued).
  ///
  /// [asyncFold] is the foundational asynchronous fold operator. It
  /// maintains an accumulator that is updated by an async function
  /// for each input, processing inputs sequentially.
  ///
  /// ### When to use
  /// Use [asyncFold] when you need to maintain state across values
  /// with asynchronous updates.
  ///
  /// - **Running Totals**: Summing values as they arrive.
  /// - **String Concatenation**: Building strings incrementally.
  /// - **State Aggregation**: Aggregating state from async operations.
  /// - **Data Processing**: Processing data with async transformations.
  /// - **Caching**: Maintaining a cache with async updates.
  /// - **Batch Processing**: Processing batches with async logic.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The [accumulate] function is called with the current accumulator
  ///    and the payload.
  /// 3. The new accumulator value is stored in the snapshot.
  /// 4. The new value is emitted.
  /// 5. Steps are processed sequentially (queue).
  /// 6. If [accumulate] throws an error, it's reported and the instruction
  ///    continues with the next input.
  ///
  /// ### Non‑obvious
  /// - **Sequential Processing**: Steps run one after another.
  /// - **Queueing**: Inputs are queued while processing.
  /// - **No Cancellation**: Previous operations are not cancelled.
  /// - **Error Isolation**: Errors don't stop the queue.
  /// - **Snapshot Access**: The snapshot can be read externally.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [seed]: **Initial State.** The starting accumulator value.
  /// - [accumulate]: **Accumulation Function.** Called with the current
  ///   accumulator and the payload, returns the new accumulator.
  /// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
  ///   not provided.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [A]: The type of the accumulator and output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the accumulated values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncFold<int, int>(
  ///   input.cell,
  ///   seed: 0,
  ///   accumulate: (acc, n) async => acc + n,
  /// );
  ///
  /// input.emit(5);  // -> 5
  /// input.emit(3);  // -> 8
  /// input.emit(7);  // -> 15
  /// ```
  ///
  /// ### See Also:
  /// - [asyncReduce]: For seedless accumulation.
  /// - [Flow.asyncFoldLatest]: For latest-only accumulation.
  /// - [Flow.asyncFoldExhaust]: For exhaust accumulation.
  static FlowHandle asyncFold<S, A>(
      Cell source, {
        required A seed,
        required FutureOr<A> Function(A acc, S value) accumulate,
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
      }) {
    return AsyncFold<S, A>(
      seed,
      accumulate,
      snapshot: snapshot,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Similar to [asyncFold], but only processes the **latest** pulse.
  ///
  /// Any in-flight asynchronous work is abandoned when a new pulse arrives.
  ///
  /// ### When to use
  /// Use [asyncFoldLatest] when you want to maintain state across values
  /// but only care about the result of the most recent input.
  ///
  /// - **Search Suggestions**: Accumulating search history where only the
  ///   latest query's state matters.
  /// - **UI State**: Tracking state where rapid updates should cancel
  ///   stale computations.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [accumulate] function.
  /// 2. A new generation ID is assigned to each trigger.
  /// 3. Any previous asynchronous accumulation is abandoned.
  /// 4. The result of the latest successful accumulation is emitted.
  ///
  /// ### Non‑obvious
  /// - **Generation Tracking**: Each operation gets a unique ID to prevent
  ///   stale updates.
  /// - **State Persistence**: The snapshot is updated only by the latest
  ///   generation.
  static FlowHandle asyncFoldLatest<S, A>(
      Cell source, {
        required A seed,
        required FutureOr<A> Function(A acc, S value) accumulate,
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
      }) {
    return AsyncFoldLatest<S, A>(
      seed,
      accumulate,
      snapshot: snapshot,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Similar to [asyncFold], but ignores new triggers while an inner
  /// accumulation is already running.
  ///
  /// ### When to use
  /// Use [asyncFoldExhaust] when you want to prevent overlapping state updates.
  ///
  /// - **Submit Buttons**: Preventing multiple form submissions from
  ///   corrupting the accumulated state.
  /// - **Resource Locking**: Ensuring a state update finishes before
  ///   accepting the next.
  ///
  /// ### How it works
  /// 1. The first incoming pulse starts the [accumulate] function.
  /// 2. While the accumulation is running, new triggers are dropped.
  /// 3. When the accumulation completes, the next trigger is accepted.
  static FlowHandle asyncFoldExhaust<S, A>(
      Cell source, {
        required A seed,
        required FutureOr<A> Function(A acc, S value) accumulate,
        FoldSnapshot<A>? snapshot,
        FoldErrorHandler? onError,
      }) {
    return AsyncFoldExhaust<S, A>(
      seed,
      accumulate,
      snapshot: snapshot,
      onError: onError,
    ).toHandle(source: source);
  }

  /// First value is the seed; later values accumulate.
  ///
  /// [asyncReduce] is similar to [asyncFold] but the seed is the first
  /// value, not a separate seed parameter.
  ///
  /// ### When to use
  /// Use [asyncReduce] when you want the first value to be the seed.
  ///
  /// - **Running Totals**: Summing values as they arrive (no explicit seed).
  /// - **First Value**: Using the first value as the starting point.
  /// - **Data Processing**: Processing data with async transformations.
  /// - **State Aggregation**: Aggregating state from async operations.
  /// - **Reduction**: Reducing a sequence of values.
  ///
  /// ### How it works
  /// 1. The first typed pulse becomes the seed and is emitted immediately.
  /// 2. Subsequent pulses are accumulated using the [accumulate] function.
  /// 3. Steps are processed sequentially (queue).
  /// 4. If [accumulate] throws an error, it's reported and the instruction
  ///    continues with the next input.
  ///
  /// ### Non‑obvious
  /// - **First Value as Seed**: The first value is emitted as the seed.
  /// - **No Seed Parameter**: No explicit seed is required.
  /// - **Sequential Processing**: Steps run one after another.
  /// - **Queueing**: Inputs are queued while processing.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [accumulate]: **Accumulation Function.** Called with the current
  ///   accumulator and the payload, returns the new accumulator.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input and output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the accumulated values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.asyncReduce<int>(
  ///   input.cell,
  ///   accumulate: (acc, n) async => acc + n,
  /// );
  ///
  /// input.emit(5);  // -> 5 (seed)
  /// input.emit(3);  // -> 8
  /// input.emit(7);  // -> 15
  /// ```
  ///
  /// ### See Also:
  /// - [asyncFold]: For seeded accumulation.
  static FlowHandle asyncReduce<S>(
      Cell source, {
        required FutureOr<S> Function(S acc, S value) accumulate,
        FoldErrorHandler? onError,
      }) {
    return AsyncReduce<S>(accumulate, onError: onError).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────────────────────

  /// Only forwards payloads that satisfy the [test] predicate (Rx `filter`).
  ///
  /// [filter] keeps pulses whose payload satisfies a synchronous
  /// predicate. Type mismatches are dropped and reported via [onError].
  ///
  /// ### When to use
  /// Use [filter] when you need to remove values from a stream.
  ///
  /// - **Validation**: Keeping only valid values.
  /// - **Range Checks**: Keeping values within a range.
  /// - **Noise Reduction**: Removing unwanted values.
  /// - **Data Cleaning**: Cleaning dirty data.
  /// - **Conditional Processing**: Processing only certain values.
  /// - **Privacy**: Removing sensitive data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The [test] predicate is called with the payload.
  /// 3. If [test] returns `true`, the pulse is forwarded.
  /// 4. If [test] returns `false`, the pulse is dropped.
  /// 5. If [test] throws an error, the pulse is dropped.
  /// 6. Forwarded pulses get the step `'Filter'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Synchronous Predicate**: The predicate must be synchronous.
  /// - **Type Safety**: Only typed payloads are considered.
  /// - **Error Handling**: Errors in the predicate drop the pulse.
  /// - **Order Preservation**: Results are emitted in input order.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Returns `true` to keep the value.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the filtered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.filter<int>(
  ///   input.cell,
  ///   test: (n) => n % 2 == 0,
  /// );
  ///
  /// input.emit(1); // dropped
  /// input.emit(2); // -> 2
  /// input.emit(3); // dropped
  /// input.emit(4); // -> 4
  /// ```
  ///
  /// ### See Also:
  /// - [mapWhen]: For conditional mapping.
  /// - [takeWhile]: For taking until a condition fails.
  static FlowHandle filter<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    return Filter<S>(test).toHandle(source: source);
  }

  /// Only forwards the first [count] pulses received from [source].
  ///
  /// [take] acts as a **Count-Based Taker**. It forwards the first N values
  /// from the stream and then stops forwarding.
  ///
  /// ### When to use
  /// Use [take] when you need to limit the number of values:
  ///
  /// - **Prefetch**: Getting the first page of results
  /// - **Sampling**: Taking a sample of data
  /// - **Capping**: Capping a burst of events
  /// - **Testing**: Testing with a fixed number of values
  /// - **Pagination**: Implementing "take N" operations
  /// - **Limiting**: Limiting the number of processed items
  /// - **Preview**: Showing a preview of data
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. A counter tracks how many values have been taken.
  /// 3. If the counter is less than [count], the pulse passes through.
  /// 4. If the counter reaches [count], the stream closes and all subsequent
  ///    pulses are dropped.
  /// 5. Results are emitted in input order.
  ///
  /// ### Non‑obvious
  /// - **Terminal State**: Once the count is reached, the stream closes.
  /// - **State Persistence**: The instruction maintains a counter.
  /// - **Order Preservation**: Results are emitted in the same order as inputs.
  /// - **No Completion Signal**: The source cell is not completed.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [count]: **The Number of Values to Take.** Must be >= 0.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the taken values.
  ///
  /// ### Example
  /// ```dart
  /// final ticks = Cell.ingress<int>();
  ///
  /// final handle = Flow.take<int>(ticks.cell, count: 3);
  ///
  /// ticks.emit(1); // passes through
  /// ticks.emit(2); // passes through
  /// ticks.emit(3); // passes through
  /// ticks.emit(4); // dropped
  /// // Result: `[1, 2, 3]`
  /// ```
  ///
  /// ### See Also:
  /// - [takeWhile]: For conditional taking.
  /// - [takeUntil]: For event-based taking.
  static FlowHandle take<S>(
      Cell source, {
        required int count,
      }) {
    return Take<S>(count).toHandle(source: source);
  }

  /// Take while [test] is true.
  ///
  /// [takeWhile] acts as a **Conditional Prefix Taker**. It forwards values
  /// from the beginning of the stream while a condition is true, and stops
  /// forwarding when the condition fails.
  ///
  /// ### When to use
  /// Use [takeWhile] when you need to take values until a condition fails.
  ///
  /// - **Conditional Streaming**: Taking values based on a condition.
  /// - **State Machine Transitions**: Tracking state machine transitions.
  /// - **Limiting**: Limiting based on conditions.
  /// - **Early Termination**: Implementing early termination.
  /// - **Prefix Extraction**: Taking a prefix based on a condition.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The predicate is evaluated.
  /// 3. If the predicate returns `true`, the value passes through.
  /// 4. If the predicate returns `false`, the stream closes.
  /// 5. The failing value is not emitted (unless `inclusive`).
  ///
  /// ### Non‑obvious
  /// - **Terminal State**: Once the predicate returns `false`, the stream
  ///   closes and no further values are emitted.
  /// - **State Persistence**: The instruction maintains an `open` flag.
  /// - **Order Preservation**: Results are emitted in the same order as inputs.
  /// - **Error Handling**: Errors in the predicate close the stream.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **The Taking Predicate.** Returns `true` to continue
  ///   taking values. When it returns `false`, the stream closes.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the taken values.
  ///
  /// ### Example
  /// ```dart
  /// final numbers = Cell.ingress<int>();
  ///
  /// final handle = Flow.takeWhile<int>(
  ///   numbers.cell,
  ///   test: (n) => n < 5,
  /// );
  ///
  /// numbers.emit(1); // passes through
  /// numbers.emit(2); // passes through
  /// numbers.emit(3); // passes through
  /// numbers.emit(4); // passes through
  /// numbers.emit(5); // closes the stream (not emitted)
  /// // Result: `[1, 2, 3, 4]`
  /// ```
  ///
  /// ### See Also:
  /// - [take]: For count-based taking.
  /// - [takeUntil]: For event-based taking.
  static FlowHandle takeWhile<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    return TakeWhile<S>(test).toHandle(source: source);
  }

  /// Take until [notifier] pulses.
  ///
  /// [takeUntil] acts as an **Event-Based Taker**. It forwards values from
  /// the source until the [notifier] cell emits a pulse.
  ///
  /// ### When to use
  /// Use [takeUntil] when you need to take values until an event occurs.
  ///
  /// - **Conditional Streaming**: Taking values until an event.
  /// - **Stop Trigger**: Stopping on a stop signal.
  /// - **Gate Pattern**: Implementing a gate.
  /// - **User Action**: Stopping on user action.
  /// - **Timeout**: Implementing a timeout with a notifier.
  ///
  /// ### How it works
  /// 1. The instruction observes the [notifier] cell.
  /// 2. Initially, all values from the source are forwarded.
  /// 3. When the [notifier] emits a value, the stream closes.
  /// 4. After the notifier emits, all subsequent source values are dropped.
  ///
  /// ### Non‑obvious
  /// - **State**: The instruction maintains an `open` flag.
  /// - **Once Closed**: The stream cannot be opened again.
  /// - **First Value**: The notifier's value is not passed through.
  /// - **Memory Efficiency**: Only a boolean flag is stored.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [notifier]: **The Closing Event Source.** The cell that triggers the
  ///   stream closing when it emits a value.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the taken values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  /// final stop = Cell.ingress<void>();
  ///
  /// final handle = Flow.takeUntil<int>(
  ///   source.cell,
  ///   notifier: stop.cell,
  /// );
  ///
  /// source.emit(1); // passes through
  /// source.emit(2); // passes through
  /// stop.emit(null); // closes the stream
  /// source.emit(3); // dropped
  /// // Result: `[1, 2]`
  /// ```
  ///
  /// ### See Also:
  /// - [takeWhile]: For conditional taking.
  /// - [take]: For count-based taking.
  static FlowHandle takeUntil<S>(
      Cell source, {
        required Cell notifier,
      }) {
    return TakeUntil<S>(notifier).toHandle(source: source);
  }

  /// Suppresses the first [count] pulses received from [source].
  ///
  /// [skip] acts as a **Count-Based Skipper**. It drops the first N values
  /// from the stream and forwards all subsequent values.
  ///
  /// ### When to use
  /// Use [skip] when you need to ignore the first N values:
  ///
  /// - **Initialization Data**: Skipping initial loading states
  /// - **Headers**: Ignoring headers or metadata
  /// - **Seed Values**: Skipping seed values
  /// - **Pagination**: Starting after a certain number of items
  /// - **Testing**: Skipping setup values in tests
  /// - **Stream Prefix**: Ignoring the beginning of a stream
  /// - **Warm-up**: Skipping initial warm-up data
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. A counter tracks how many values have been skipped.
  /// 3. If the counter is less than [count], the pulse is skipped.
  /// 4. If the counter reaches [count], all subsequent values pass through.
  /// 5. Results are emitted in input order.
  ///
  /// ### Non‑obvious
  /// - **Opening State**: Once the count is reached, the stream opens.
  /// - **State Persistence**: The instruction maintains a counter.
  /// - **Order Preservation**: Results are emitted in the same order as inputs.
  /// - **Memory Efficiency**: Only an integer counter is stored.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [count]: **The Number of Values to Skip.** Must be >= 0.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the remaining values.
  ///
  /// ### Example
  /// ```dart
  /// final ticks = Cell.ingress<int>();
  ///
  /// final handle = Flow.skip<int>(ticks.cell, count: 2);
  ///
  /// ticks.emit(1); // skipped
  /// ticks.emit(2); // skipped
  /// ticks.emit(3); // passes through
  /// ticks.emit(4); // passes through
  /// // Result: `[3, 4]`
  /// ```
  ///
  /// ### See Also:
  /// - [skipWhile]: For conditional skipping.
  /// - [skipUntil]: For event-based skipping.
  static FlowHandle skip<S>(
      Cell source, {
        required int count,
      }) {
    return Skip<S>(count).toHandle(source: source);
  }

  /// Skip while [test] is true.
  ///
  /// [skipWhile] acts as a **Conditional Prefix Skipper**. It skips values
  /// from the beginning of the stream while a condition is true, and once
  /// the condition fails, it forwards all subsequent values.
  ///
  /// ### When to use
  /// Use [skipWhile] when you need to skip initial values until a condition
  /// is met.
  ///
  /// - **Conditional Skipping**: Skipping values until a condition.
  /// - **State Machine Transitions**: Tracking state machine transitions.
  /// - **Warm-up Period**: Skipping warm-up data.
  /// - **Threshold**: Starting after a threshold is met.
  /// - **Conditional Prefix**: Skipping a conditional prefix.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The predicate is evaluated.
  /// 3. If the predicate returns `true`, the value is skipped.
  /// 4. If the predicate returns `false`, the stream is opened and all
  ///    subsequent values pass through.
  /// 5. Results are emitted in input order.
  ///
  /// ### Non‑obvious
  /// - **Opening State**: Once the predicate returns `false`, the stream is
  ///   opened and all subsequent values pass through.
  /// - **State Persistence**: The instruction maintains a `skipping` flag.
  /// - **Order Preservation**: Results are emitted in the same order as inputs.
  /// - **Error Handling**: Errors in the predicate are reported via [onError].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **The Skipping Predicate.** Returns `true` to continue
  ///   skipping values. When it returns `false`, the stream opens.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the remaining values.
  ///
  /// ### Example
  /// ```dart
  /// final nums = Cell.ingress<int>();
  ///
  /// final handle = Flow.skipWhile<int>(
  ///   nums.cell,
  ///   test: (n) => n < 5,
  /// );
  ///
  /// nums.emit(1); // skipped
  /// nums.emit(2); // skipped
  /// nums.emit(3); // skipped
  /// nums.emit(4); // skipped
  /// nums.emit(5); // opens the stream
  /// nums.emit(6); // passes through
  /// // Result: `[5, 6]`
  /// ```
  ///
  /// ### See Also:
  /// - [skip]: For count-based skipping.
  /// - [skipUntil]: For event-based skipping.
  static FlowHandle skipWhile<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    return SkipWhile<S>(test).toHandle(source: source);
  }

  /// Skip until [notifier] pulses.
  ///
  /// [skipUntil] acts as an **Event-Based Skipper**. It skips all values
  /// from the source until the [notifier] cell emits a pulse. Once the
  /// notifier emits, all subsequent values are forwarded.
  ///
  /// ### When to use
  /// Use [skipUntil] when you need to skip values until an event occurs.
  ///
  /// - **Conditional Streaming**: Skipping values until an event.
  /// - **Start Trigger**: Starting on a start signal.
  /// - **Gate Pattern**: Implementing a gate.
  /// - **User Action**: Starting on user action.
  /// - **Initialization**: Waiting for initialization.
  ///
  /// ### How it works
  /// 1. The instruction observes the [notifier] cell.
  /// 2. Initially, all values from the source are skipped.
  /// 3. When the [notifier] emits a value, the stream opens.
  /// 4. After the notifier emits, all subsequent source values pass through.
  ///
  /// ### Non‑obvious
  /// - **State**: The instruction maintains an `open` flag.
  /// - **Once Opened**: The stream cannot be closed again.
  /// - **First Value**: The notifier's value is not passed through.
  /// - **Memory Efficiency**: Only a boolean flag is stored.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [notifier]: **The Opening Event Source.** The cell that triggers the
  ///   stream opening when it emits a value.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the remaining values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  /// final ready = Cell.ingress<void>();
  ///
  /// final handle = Flow.skipUntil<int>(
  ///   source.cell,
  ///   notifier: ready.cell,
  /// );
  ///
  /// source.emit(1); // skipped
  /// source.emit(2); // skipped
  /// ready.emit(null); // opens the stream
  /// source.emit(3); // passes through
  /// source.emit(4); // passes through
  /// // Result: `[3, 4]`
  /// ```
  ///
  /// ### See Also:
  /// - [skipWhile]: For conditional skipping.
  /// - [skip]: For count-based skipping.
  static FlowHandle skipUntil<S>(
      Cell source, {
        required Cell notifier,
      }) {
    return SkipUntil<S>(notifier).toHandle(source: source);
  }

  /// Suppresses pulses if their payload is identical to the previous payload.
  ///
  /// [skipRepeated] is similar to [distinct] but with different semantics:
  /// the first value is also skipped if it equals the seed.
  ///
  /// ### When to use
  /// Use [skipRepeated] when you need to skip consecutive duplicates.
  ///
  /// - **Noise Reduction**: Reducing noise from repeated values.
  /// - **Change Detection**: Detecting when a value changes.
  /// - **Redundant Events**: Filtering out redundant events.
  /// - **Debouncing**: A simpler form of debouncing.
  ///
  /// ### How it works
  /// 1. The first typed pulse is stored and **not** emitted.
  /// 2. For each subsequent pulse, if the payload equals the previous,
  ///    it's skipped.
  /// 3. If the payload is different, it's emitted and becomes the new
  ///    previous value.
  ///
  /// ### Non‑obvious
  /// - **Consecutive Only**: Only back-to-back duplicates are skipped.
  /// - **No Initial Emission**: The first value is always skipped.
  /// - **State Persistence**: The instruction maintains the previous value.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the filtered values.
  ///
  /// ### Example
  /// ```dart
  /// final ticks = Cell.ingress<int>();
  ///
  /// final handle = Flow.skipRepeated<int>(ticks.cell);
  ///
  /// ticks.emit(1); // skipped (first value)
  /// ticks.emit(1); // skipped (duplicate)
  /// ticks.emit(2); // passes through
  /// ticks.emit(2); // skipped (duplicate)
  /// ticks.emit(3); // passes through
  /// // Result: [2, 3]
  /// ```
  ///
  /// ### See Also:
  /// - [distinct]: For global deduplication.
  /// - [skipWhen]: For conditional skipping.
  static FlowHandle skipRepeated<S>(Cell source) {
    return SkipRepeated<S>().toHandle(source: source);
  }

  /// Drop values while [test] is true.
  ///
  /// [skipWhen] acts as a **Per-Value Skipper**. Unlike [skipWhile], this
  /// evaluates the predicate independently on every pulse.
  ///
  /// ### When to use
  /// Use [skipWhen] when you need to skip values based on a condition.
  ///
  /// - **Conditional Skipping**: Skipping values based on a condition.
  /// - **Filtering**: Skipping values that meet a condition.
  /// - **Noise Reduction**: Skipping noisy values.
  /// - **Data Cleaning**: Skipping dirty data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The predicate is evaluated.
  /// 3. If the predicate returns `true`, the value is skipped.
  /// 4. If the predicate returns `false`, the value passes through.
  /// 5. Results are emitted in input order.
  ///
  /// ### Non‑obvious
  /// - **Per-Value**: The predicate is evaluated for each value independently.
  /// - **Stateless**: The instruction maintains no state.
  /// - **Order Preservation**: Results are emitted in the same order as inputs.
  /// - **Memory Efficiency**: No state is stored.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **The Skipping Predicate.** Returns `true` to skip the value.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the remaining values.
  ///
  /// ### Example
  /// ```dart
  /// final numbers = Cell.ingress<int>();
  ///
  /// final handle = Flow.skipWhen<int>(
  ///   numbers.cell,
  ///   test: (n) => n % 2 == 0,
  /// );
  ///
  /// numbers.emit(1); // passes through
  /// numbers.emit(2); // skipped
  /// numbers.emit(3); // passes through
  /// numbers.emit(4); // skipped
  /// numbers.emit(5); // passes through
  /// // Result: `[1, 3, 5]`
  /// ```
  ///
  /// ### See Also:
  /// - [skipWhile]: For conditional prefix skipping.
  /// - [filter]: For passing when a condition is true.
  static FlowHandle skipWhen<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    return SkipWhen<S>(test).toHandle(source: source);
  }

  /// Suppresses pulses that have been seen before (globally or consecutively
  /// depending on configuration).
  ///
  /// [distinct] acts as a **Global Duplicate Filter**. It keeps track of all
  /// values that have ever been emitted and drops any value that has been seen
  /// before, regardless of position.
  ///
  /// ### When to use
  /// Use [distinct] when you need to ensure each value is emitted only once.
  ///
  /// - **Unique Items**: Processing unique items from a stream.
  /// - **Set-Like Deduplication**: Implementing set-like deduplication.
  /// - **Event Tracking**: Tracking unique events.
  /// - **ID Deduplication**: Deduplicating IDs.
  /// - **Data Cleaning**: Removing duplicates from a stream.
  ///
  /// ### How it works
  /// 1. Each typed pulse's payload is extracted.
  /// 2. The payload is compared to all previously seen values using `equals`.
  /// 3. If a match is found, the pulse is dropped.
  /// 4. If no match is found, the pulse passes through and the value is stored.
  ///
  /// ### Memory Considerations
  /// - **O(n) Memory**: The instruction stores all seen values in a list.
  /// - **Unbounded Growth**: Memory grows with the number of unique values.
  /// - **Use [skipRepeated]** when only consecutive repeats matter to avoid
  ///   unbounded memory growth.
  ///
  /// ### Non‑obvious
  /// - **Global Scope**: Any previously seen value is dropped, even if it
  ///   appeared long ago.
  /// - **Memory Growth**: The instruction stores all seen values, so memory
  ///   grows with the number of unique values.
  /// - **Custom Comparator**: Providing an `equals` function allows for
  ///   custom comparison logic.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the filtered values.
  ///
  /// ### Example
  /// ```dart
  /// final nums = Cell.ingress<int>();
  ///
  /// final handle = Flow.distinct<int>(nums.cell);
  ///
  /// nums.emit(1); // passes through
  /// nums.emit(2); // passes through
  /// nums.emit(1); // dropped
  /// nums.emit(3); // passes through
  /// nums.emit(2); // dropped
  /// // Result: `[1, 2, 3]`
  /// ```
  ///
  /// ### See Also:
  /// - [skipRepeated]: For consecutive-only deduplication.
  /// - [filter]: For general filtering.
  static FlowHandle distinct<S>(Cell source) {
    return Distinct<S>().toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Flatten
  // ─────────────────────────────────────────────────────────────

  /// Maps each payload to an inner sequence and flattens them **sequentially**
  /// (Rx `concatMap`).
  ///
  /// [concatMap] acts as a **Sequential Flattener**. Each incoming trigger
  /// is transformed into an inner sequence, and the items are emitted in order.
  /// Each inner sequence finishes before the next starts.
  ///
  /// ### When to use
  /// Use [concatMap] when you need to flatten sequences in order:
  ///
  /// - **Multi-Phase Workflows**: Each trigger starts a workflow that must
  ///   complete before the next starts.
  /// - **Unrolling Lists/Streams**: Expanding a list of items per command.
  /// - **Ordered Processing**: When the order of results must match the
  ///   order of triggers.
  /// - **Resource Constraints**: When you want to limit concurrent operations.
  /// - **File Processing**: Processing files one at a time.
  /// - **Database Transactions**: Sequential transactions.
  ///
  /// ### How it works
  /// 1. Each trigger pulse's payload is extracted and type-checked.
  /// 2. The [project] function is called with the payload.
  /// 3. The [project] returns an inner sequence (Stream, Future, Iterable, or value).
  /// 4. The inner sequence is drained recursively, emitting each item.
  /// 5. The next trigger is queued and only starts when the current sequence completes.
  /// 6. Results are emitted in input order.
  ///
  /// ### Supported Inner Types
  /// The [project] can return any of the following:
  /// - **`Stream`**: Each event in the stream is emitted sequentially.
  /// - **`Future`**: The single value is emitted when the future completes.
  /// - **`Iterable`**: Each element is emitted in order.
  /// - **[T]**: The value itself is emitted directly.
  /// - **`null`**: No emission (the pulse is dropped).
  /// - **Nested combinations**: `Future<Iterable<T>>`, etc., are recursively expanded.
  ///
  /// ### Non‑obvious
  /// - **Strict Sequencing**: The instruction processes inputs one at a time.
  ///   Each sequence must complete before the next starts.
  /// - **Queueing**: If triggers arrive while a sequence is in progress,
  ///   they are queued in FIFO order.
  /// - **Error Handling**: Errors in the [project] or during draining are
  ///   reported via [onError].
  /// - **Backpressure**: The instruction processes inputs sequentially,
  ///   automatically providing backpressure.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **The Flattening Logic.** Takes an input value and returns
  ///   an inner sequence (Stream, Future, Iterable, or value).
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final orders = Cell.ingress<String>();
  ///
  /// final handle = Flow.concatMap<String, String>(
  ///   orders.cell,
  ///   project: (id) async* {
  ///     yield '$id:created';
  ///     yield '$id:paid';
  ///     yield '$id:shipped';
  ///   },
  /// );
  ///
  /// orders.emit('ORD-1');
  /// // -> ORD-1:created, ORD-1:paid, ORD-1:shipped
  /// orders.emit('ORD-2');
  /// // starts after ORD-1 completes
  /// ```
  ///
  /// ### See Also:
  /// - [mergeMap]: For concurrent flattening.
  /// - [switchMap]: For latest-only flattening.
  /// - [exhaustMap]: For exhaust flattening.
  static FlowHandle concatMap<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) project,
      }) {
    return ConcatMap<S, T>(project).toHandle(source: source);
  }

  /// Play static inners after the first pulse (Rx `concat`).
  ///
  /// [concat] concatenates a fixed list of inners (lists, futures,
  /// streams, or values) in order, emitting all values from each inner
  /// before moving to the next.
  ///
  /// ### When to use
  /// Use [concat] when you have a fixed list of sequences to play
  /// in order.
  ///
  /// - **Sequence Concatenation**: Playing multiple sequences in order.
  /// - **Predefined Workflows**: Executing predefined steps.
  /// - **Static Data Sources**: Combining static data sources.
  /// - **Initialization**: Initializing multiple resources in order.
  /// - **Test Data**: Combining test data sequences.
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Each inner in [inners] is drained in order.
  /// 3. All values from each inner are emitted.
  /// 4. The instruction stops after all inners are played.
  ///
  /// ### Non‑obvious
  /// - **Fixed Inners**: The inners are fixed at construction time.
  /// - **First Pulse Only**: The instruction only arms on the first pulse.
  /// - **Sequential**: Inners are played one after another.
  /// - **Error Isolation**: Errors in one inner don't stop the next.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the trigger.
  /// - [inners]: **Fixed Inners.** The sequences to play in order.
  ///   Each inner can be a `List`, `Future`, `Stream`, or raw value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the concatenated values.
  ///
  /// ### Example
  /// ```dart
  /// final arm = Cell.ingress<void>();
  ///
  /// final handle = Flow.concat<String>(
  ///   arm.cell,
  ///   inners: [
  ///     ['a', 'b'],
  ///     ['c'],
  ///   ],
  /// );
  ///
  /// arm.emit(null);
  /// // Outputs: a, b, c
  /// ```
  ///
  /// ### See Also:
  /// - [concatMap]: For per-trigger sequences.
  /// - [concatAll]: For dynamic sequence concatenation.
  static FlowHandle concat<T>(
      Cell source, {
        required Iterable<Object?> inners,
        ConcatErrorHandler? onError,
      }) {
    return Concat<T>(inners, onError: onError).toHandle(source: source);
  }

  /// Each payload is an inner, queued (Rx `concatAll`).
  ///
  /// [concatAll] treats each source payload as an inner sequence and
  /// plays them in arrival order. This is useful when the sequences
  /// are dynamically generated.
  ///
  /// ### When to use
  /// Use [concatAll] when each source payload is a sequence to play
  /// in order.
  ///
  /// - **Dynamic Sequences**: When sequences are generated dynamically.
  /// - **Stream of Streams**: Concatenating a stream of streams.
  /// - **Queue Processing**: Processing queued items sequentially.
  /// - **Request/Response**: Concatenating responses in order.
  /// - **Lazy Loading**: Loading data sequentially on demand.
  ///
  /// ### How it works
  /// 1. Each source pulse adds its payload to a queue.
  /// 2. The queue is processed one inner at a time.
  /// 3. All values from each inner are emitted.
  /// 4. If the queue is empty, the instruction waits.
  ///
  /// ### Non‑obvious
  /// - **Dynamic Payloads**: The inners come from the source payloads.
  /// - **Queueing**: Inners are queued and processed in order.
  /// - **Sequential**: Inners are played one after another.
  /// - **Error Isolation**: Errors in one inner don't stop the next.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the concatenated values.
  ///
  /// ### Example
  /// ```dart
  /// final lists = Cell.ingress<List<int>>();
  ///
  /// final handle = Flow.concatAll<int>(lists.cell);
  ///
  /// lists.emit([1, 2]); // -> 1, 2
  /// lists.emit([3]);    // -> 3
  /// // Outputs: 1, 2, 3
  /// ```
  ///
  /// ### See Also:
  /// - [concat]: For static sequence concatenation.
  /// - [concatMap]: For per-trigger mapping.
  static FlowHandle concatAll<T>(Cell source) {
    return ConcatAll<T>().toHandle(source: source);
  }

  /// Last item of each inner.
  ///
  /// [concatLatest] processes each inner and only emits its last item.
  ///
  /// ### When to use
  /// Use [concatLatest] when you only need the last item from each
  /// sequence.
  ///
  /// - **Last Value**: Getting the last value from each source.
  /// - **Tail Extraction**: Extracting the tail of each sequence.
  /// - **Final State**: Getting the final state from each source.
  /// - **Completion**: Getting the completion value from each sequence.
  /// - **Aggregation**: Getting the last value for aggregation.
  ///
  /// ### How it works
  /// 1. Each source pulse adds its payload to a queue.
  /// 2. The queue is processed one inner at a time.
  /// 3. The inner is fully drained and collected.
  /// 4. The last typed value of type [T] is emitted.
  ///
  /// ### Non‑obvious
  /// - **Last Only**: Only the last item of each inner is emitted.
  /// - **Full Drain**: The entire inner is drained to find the last.
  /// - **Type Filtering**: Only values of type [T] are considered.
  /// - **Memory Usage**: Drains the full inner into memory.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the last values.
  ///
  /// ### Example
  /// ```dart
  /// final lists = Cell.ingress<List<String>>();
  ///
  /// final handle = Flow.concatLatest<String>(lists.cell);
  ///
  /// lists.emit(['a', 'b', 'c']); // -> c
  /// lists.emit(['d', 'e']);      // -> e
  /// ```
  ///
  /// ### See Also:
  /// - [concatAll]: For all items of each inner.
  static FlowHandle concatLatest<T>(Cell source) {
    return ConcatLatest<T>().toHandle(source: source);
  }

  /// Maps each payload to an inner sequence and flattens them **concurrently**
  /// (Rx `mergeMap`).
  ///
  /// [mergeMap] maps each incoming value to an inner sequence and emits values
  /// from all inner sequences as they complete, with optional concurrency control.
  ///
  /// ### When to use
  /// Use [mergeMap] when you need to process multiple async operations
  /// concurrently and don't need to cancel previous operations.
  ///
  /// - **Parallel HTTP Calls**: Making multiple independent API calls.
  /// - **Batch Processing**: Processing multiple items concurrently.
  /// - **Background Tasks**: Running multiple background operations.
  /// - **Data Enrichment**: Enriching multiple items in parallel.
  /// - **File Operations**: Reading/writing multiple files concurrently.
  /// - **Image Processing**: Processing images in parallel.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [project] function.
  /// 2. The [project] returns an inner sequence.
  /// 3. The inner sequence is drained asynchronously.
  /// 4. Values are emitted as they complete (unordered).
  /// 5. All inners run to completion (no cancellation).
  ///
  /// ### Non‑obvious
  /// - **Unordered Output**: Results are emitted in completion order.
  /// - **Concurrency**: All operations start immediately.
  /// - **No Cancellation**: Previous operations are not cancelled.
  /// - **Error Isolation**: Errors in one operation don't affect others.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **The Flattening Logic.** Takes an input value and returns
  ///   an inner sequence.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final ids = Cell.ingress<int>();
  ///
  /// final handle = Flow.mergeMap<int, User>(
  ///   ids.cell,
  ///   project: (id) async => await api.getUser(id),
  /// );
  ///
  /// ids.emit(1); // Starts fetching
  /// ids.emit(2); // Starts fetching (parallel)
  /// // Results arrive in completion order
  /// ```
  ///
  /// ### See Also:
  /// - [concatMap]: For sequential flattening.
  /// - [switchMap]: For latest-only flattening.
  /// - [exhaustMap]: For exhaust flattening.
  static FlowHandle mergeMap<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) project,
      }) {
    return MergeMap<S, T>(project).toHandle(source: source);
  }

  /// Maps each payload to an inner sequence and always switches to the
  /// **latest** one (Rx `switchMap`).
  ///
  /// [switchMap] is a powerful flattening operator that "cancels" the previous
  /// inner sequence whenever a new source pulse arrives.
  ///
  /// ### When to use
  /// Use [switchMap] for scenarios where only the most recent request is relevant:
  /// - **Search-as-you-type**: Cancel stale API calls when the user keeps typing.
  /// - **Navigation**: Stop loading data for the previous page when the user moves.
  ///
  /// ### How it works
  /// 1. A new source pulse triggers the [project] function.
  /// 2. The resulting inner sequence (Future/Stream) is subscribed to.
  /// 3. Any previous active inner sequence is immediately abandoned/cancelled.
  /// 4. Only values from the current (latest) inner are emitted.
  ///
  /// ### Non‑obvious
  /// - **Generation ID**: Internally uses incrementing IDs to ignore stale results.
  /// - **Cancellation**: For Streams, it cancels the subscription. For Futures,
  ///   it ignores the result.
  ///
  /// [switchMap] acts as a **Latest-Only Flattener**. A new trigger
  /// cancels emission from the previous inner sequence.
  ///
  /// ### When to use
  /// Use [switchMap] when you only care about the most recent operation:
  ///
  /// - **Search-as-you-type**: Only the latest search query matters
  /// - **Real-time Filtering**: Only the most recent filter applies
  /// - **Navigation**: Only the latest route matters
  /// - **Form Validation**: Only the latest input should be validated
  /// - **Live Updates**: Only the most recent update is relevant
  /// - **Selection Changes**: Only the latest selection should be processed
  /// - **Tab Switching**: Only the latest tab's data should be loaded
  ///
  /// ### How it works
  /// 1. Each trigger pulse starts a new inner sequence with a unique ID.
  /// 2. If a new trigger arrives while a sequence is in flight, the previous
  ///    sequence's ID is marked as stale.
  /// 3. Only the sequence with the current ID can emit results.
  /// 4. Stale sequences' items are silently dropped.
  ///
  /// ### Non‑obvious
  /// - **Silent Cancellation**: Cancelled sequences do not throw exceptions.
  ///   They simply don't emit results.
  /// - **Generation ID Tracking**: Each sequence gets a unique ID. Only the
  ///   sequence with the current ID can emit.
  /// - **Memory Safety**: The state only holds the current generation ID.
  /// - **Error Handling**: Only errors from the latest sequence are reported.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **The Flattening Logic.** Takes an input value and returns
  ///   an inner sequence.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final searchInput = Cell.ingress<String>();
  ///
  /// final handle = Flow.switchMap<String, Result>(
  ///   searchInput.cell,
  ///   project: (q) async => await api.search(q),
  /// );
  ///
  /// searchInput.emit('dart');  // Starts search
  /// searchInput.emit('flutter'); // Cancels previous, starts new
  /// // Only 'flutter' results are emitted
  /// ```
  ///
  /// ### See Also:
  /// - [concatMap]: For sequential flattening.
  /// - [mergeMap]: For concurrent flattening.
  /// - [exhaustMap]: For exhaust flattening.
  static FlowHandle switchMap<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) project,
      }) {
    return SwitchMap<S, T>(project).toHandle(source: source);
  }

  /// Maps each payload to an inner sequence, but ignores new ones while a
  /// sequence is already active (Rx `exhaustMap`).
  ///
  /// [exhaustMap] acts as a **First-Wins Flattener**. Triggers that arrive
  /// while an inner sequence is running are dropped.
  ///
  /// ### When to use
  /// Use [exhaustMap] when you need to prevent overlapping operations:
  ///
  /// - **Submit/Save Buttons**: Prevent double-submission
  /// - **Form Submission**: Prevent duplicate form submissions
  /// - **Idempotent Operations**: Operations that should only run once at a time
  /// - **Rate Limiting**: You want to limit the rate of operations
  /// - **Resource Protection**: You want to prevent resource exhaustion
  /// - **Button Click Prevention**: Prevent double-click issues
  /// - **API Calls**: Prevent concurrent API calls
  /// - **File Uploads**: Prevent overlapping uploads
  ///
  /// ### How it works
  /// 1. The first trigger starts an inner sequence.
  /// 2. While the sequence is in flight, all subsequent triggers are dropped.
  /// 3. When the sequence completes, the instruction is ready for the next trigger.
  /// 4. Results are emitted from the first sequence.
  ///
  /// ### Non‑obvious
  /// - **Drop While Busy**: Triggers while busy are silently dropped.
  /// - **One at a Time**: Only one sequence can be in flight at a time.
  /// - **Error Handling**: Errors are reported via [onError].
  /// - **Causal Provenance**: Every emitted result is wrapped as an
  ///   [EvolvedPulse], preserving the forensic history.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [project]: **The Flattening Logic.** Takes an input value and returns
  ///   an inner sequence.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the flattened values.
  ///
  /// ### Example
  /// ```dart
  /// final clicks = Cell.ingress<void>();
  ///
  /// final handle = Flow.exhaustMap<void, String>(
  ///   clicks.cell,
  ///   project: (_) async* {
  ///     await submitForm();
  ///     yield 'Submitted!';
  ///   },
  /// );
  ///
  /// clicks.emit(null); // Starts submission
  /// clicks.emit(null); // Dropped (busy)
  /// // Only the first submission is processed
  /// ```
  ///
  /// ### See Also:
  /// - [concatMap]: For sequential flattening.
  /// - [mergeMap]: For concurrent flattening.
  /// - [switchMap]: For latest-only flattening.
  static FlowHandle exhaustMap<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) project,
      }) {
    return ExhaustMap<S, T>(project).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Combine
  // ─────────────────────────────────────────────────────────────

  /// Forward source and [others] (Rx `mergeWith`).
  ///
  /// [mergeWith] acts as a **Source Merger**. It combines the bound source
  /// cell with additional cells, forwarding pulses from all of them in an
  /// interleaved fashion.
  ///
  /// ### When to use
  /// Use [mergeWith] when you need to combine multiple sources:
  ///
  /// - **UI Events**: Combine clicks from several widgets
  /// - **Data Sources**: Merge a local cache Cell with a network Cell
  /// - **Multiple Inputs**: Combine events from different input devices
  /// - **Feature Flags**: Merge different feature streams
  /// - **Real-time Data**: Combine real-time data from multiple sources
  /// - **User Actions**: Merge different user actions into one stream
  /// - **Sensors**: Combine readings from multiple sensors
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Observers are started on all [others] cells.
  /// 3. The bound source pulse passes through (if `forwardSource` is true).
  /// 4. Pulses from [others] are forwarded with step `MergeWith.other`.
  ///
  /// ### Non‑obvious
  /// - **Interleaved**: Pulses from different sources are interleaved.
  /// - **Order Preservation**: Within each source, order is preserved.
  /// - **Error Handling**: Type errors are reported via [onError].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [others]: **The Additional Cells.** Cells to merge with the source.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the merged values.
  ///
  /// ### Example
  /// ```dart
  /// final button1 = Cell.ingress<int>();
  /// final button2 = Cell.ingress<int>();
  ///
  /// final handle = Flow.mergeWith<int>(
  ///   button1.cell,
  ///   others: [button2.cell],
  /// );
  ///
  /// button1.emit(1);
  /// button2.emit(2);
  /// // Outputs: 1, 2 (interleaved)
  /// ```
  ///
  /// ### See Also:
  /// - [merge]: For merging extra sources only.
  /// - [mergeAll]: For flattening inner sequences.
  static FlowHandle mergeWith<T>(
      Cell source, {
        required List<Cell> others,
      }) {
    return MergeWith<T>(others).toHandle(source: source);
  }

  /// Merge extra [sources]; [source] only arms `future`.
  ///
  /// [merge] acts as a **Multi-Source Merger**. The bound source is only
  /// used to arm the instruction.
  ///
  /// ### When to use
  /// Use [merge] when:
  /// - You want to merge multiple cells into one stream
  /// - The arming pulse should not be forwarded
  /// - You're using a dedicated gate to start the merge
  /// - You're combining events from multiple sources
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction.
  /// 2. Observers are started on all [sources] cells.
  /// 3. Pulses from all [sources] are forwarded with step `Merge`.
  /// 4. The arming pulse is not forwarded (by default).
  ///
  /// ### Non‑obvious
  /// - **Arming Only**: The first source pulse is only used to arm.
  /// - **Interleaved**: Pulses from different sources are interleaved.
  /// - **No Source Forwarding**: The arming pulse is not forwarded.
  /// - **Error Handling**: Type errors are reported via [onError].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the trigger.
  /// - [sources]: **The Cells to Merge.** Cells whose pulses will be forwarded.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the merged values.
  ///
  /// ### Example
  /// ```dart
  /// final gate = Cell.ingress<void>();
  /// final left = Cell.ingress<int>();
  /// final right = Cell.ingress<int>();
  ///
  /// final handle = Flow.merge<int>(
  ///   gate.cell,
  ///   sources: [left.cell, right.cell],
  /// );
  ///
  /// gate.emit(null); // arms only
  /// left.emit(10); // emitted
  /// right.emit(20); // emitted
  /// // Result: `[10, 20]`
  /// ```
  ///
  /// ### See Also:
  /// - [mergeWith]: For merging source with others.
  /// - [mergeAll]: For flattening inner sequences.
  static FlowHandle merge<T>(
      Cell source, {
        required List<Cell> sources,
      }) {
    return Merge<T>(sources).toHandle(source: source);
  }

  /// Payload is an inner to merge (Rx `mergeAll`).
  ///
  /// [mergeAll] acts as a **Concurrent Flattener**. Each payload is treated
  /// as an inner sequence, and all sequences are flattened concurrently.
  ///
  /// ### When to use
  /// Use [mergeAll] when:
  /// - The payload itself is a sequence to flatten
  /// - You want to flatten nested structures concurrently
  /// - You're implementing concurrent batch processing
  /// - You're merging streams from a list
  /// - You're flattening nested lists
  ///
  /// ### Supported Payload Types
  /// The payload can be any of the following:
  /// - **`Stream`**: Each event in the stream is emitted.
  /// - **`Future`**: The single value is emitted.
  /// - **`Iterable`**: Each element is emitted.
  /// - **[T]**: The value itself is emitted directly.
  /// - **`null`**: No emission.
  /// - **Nested combinations**: Recursively expanded.
  ///
  /// ### Non‑obvious
  /// - **Concurrent**: Inner sequences are processed concurrently.
  /// - **Interleaved**: Emissions from different sequences are interleaved.
  /// - **No Order Guarantee**: Results are emitted in completion order.
  /// - **Error Handling**: Errors are reported via [onError].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the merged values.
  ///
  /// ### Example
  /// ```dart
  /// final batches = Cell.ingress<Object>();
  ///
  /// final handle = Flow.mergeAll<String>(
  ///   batches.cell,
  /// );
  ///
  /// batches.emit(['a', 'b']); // emits 'a', 'b'
  /// batches.emit(['x']);     // emits 'x' (interleaved)
  /// // Result: `['a', 'x', 'b']` (order may vary)
  /// ```
  ///
  /// ### See Also:
  /// - [mergeWith]: For merging cells.
  /// - [concatAll]: For sequential flattening.
  static FlowHandle mergeAll<T>(
      Cell source, {
        MergeErrorHandler? onError,
      }) {
    return MergeAll<T>(onError: onError).toHandle(source: source);
  }

  /// Zip [source] with [others] by index (Rx `zipWith`).
  ///
  /// [zipWith] pairs values from the bound source with values from
  /// other cells by index. A value is emitted when all sources have
  /// produced a value at the same ordinal position.
  ///
  /// ### When to use
  /// Use [zipWith] when you need to combine values from multiple
  /// sources by index.
  ///
  /// - **Combining Streams**: Combining multiple data streams.
  /// - **Synchronization**: Synchronizing events from different sources.
  /// - **Data Alignment**: Aligning data from different sources.
  /// - **Join Operations**: Joining data from multiple sources.
  /// - **Correlation**: Correlating events from different sources.
  /// - **Multi-source Aggregation**: Aggregating data from multiple sources.
  ///
  /// ### How it works
  /// 1. Each source has a queue of pending values.
  /// 2. When a value arrives, it's added to the corresponding queue.
  /// 3. If every queue has at least one value:
  ///    a. One value is removed from each queue.
  ///    b. The values are combined using [project].
  ///    c. The result is emitted.
  /// 4. The slowest source determines the emission rate.
  ///
  /// ### Non‑obvious
  /// - **Index Pairing**: Values are paired by position (index).
  /// - **Queueing**: Values are queued until all sources have a value.
  /// - **Synchronization**: The slowest source determines the emission rate.
  /// - **Memory Usage**: Queues hold values until all sources have one.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [others]: **Other Sources.** The cells to zip with the bound source.
  /// - [project]: **Projection Function.** Optional. Combines the row
  ///   of values into the output type. If not provided, the row is
  ///   emitted as a List.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [R]: The type of the output value.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the zipped values.
  ///
  /// ### Example
  /// ```dart
  /// final left = Cell.ingress<int>();
  /// final right = Cell.ingress<String>();
  ///
  /// final handle = Flow.zipWith<String>(
  ///   left.cell,
  ///   others: [right.cell],
  ///   project: (row) => '${row[0]}-${row[1]}',
  /// );
  ///
  /// left.emit(1);
  /// right.emit('a'); // -> '1-a'
  /// ```
  ///
  /// ### See Also:
  /// - [zip]: For zipping extra sources with an arm.
  /// - [zipAll]: For zipping values from a single source by count.
  /// - [combineLatestWith]: For combining the latest values.
  static FlowHandle zipWith<R>(
      Cell source, {
        required List<Cell> others,
        R Function(List<Object?> row)? project,
        ZipErrorHandler? onError,
      }) {
    return ZipWith<R>(
      others,
      project: project,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Zip extra [sources]; [source] arms `future`.
  ///
  /// [zip] is similar to [zipWith] but the bound source is only used
  /// to arm the zip operation.
  ///
  /// ### When to use
  /// Use [zip] when you need to arm a zip operation with a separate
  /// trigger and zip multiple other sources.
  ///
  /// - **Multiple Sources**: Zipping multiple sources together.
  /// - **Triggered Zipping**: Starting zip on a trigger.
  /// - **Synchronization**: Synchronizing multiple sources.
  /// - **Data Alignment**: Aligning data from multiple sources.
  ///
  /// ### How it works
  /// 1. The bound source arms the zip on its first pulse.
  /// 2. Each extra source has a queue of pending values.
  /// 3. When a value arrives from a source, it's added to its queue.
  /// 4. If every queue has at least one value, one value is removed
  ///    from each queue and the row is emitted.
  ///
  /// ### Non‑obvious
  /// - **Arm Only**: The bound source only arms the zip; its payload
  ///   is not included in the zipped output.
  /// - **Index Pairing**: Values are paired by position (index).
  /// - **Queueing**: Values are queued until all sources have a value.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the trigger.
  /// - [sources]: **Sources to Zip.** The cells to zip together.
  /// - [project]: **Projection Function.** Optional. Combines the row
  ///   of values into the output type.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [R]: The type of the output value.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the zipped values.
  ///
  /// ### Example
  /// ```dart
  /// final arm = Cell.ingress<void>();
  /// final a = Cell.ingress<int>();
  /// final b = Cell.ingress<int>();
  ///
  /// final handle = Flow.zip<List<Object?>>(
  ///   arm.cell,
  ///   sources: [a.cell, b.cell],
  /// );
  ///
  /// arm.emit(null); // Arms the zip
  /// a.emit(10);
  /// b.emit(20); // -> [10, 20]
  /// ```
  ///
  /// ### See Also:
  /// - [zipWith]: For zipping the source with other cells.
  /// - [zipAll]: For zipping values from a single source by count.
  static FlowHandle zip<R>(
      Cell source, {
        required List<Cell> sources,
        R Function(List<Object?> row)? project,
        ZipErrorHandler? onError,
      }) {
    return Zip<R>(
      sources,
      project: project,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Pack [width] source values into a list.
  ///
  /// [zipAll] is the simplest zip operator. It collects values from a
  /// single source into batches of [width] and emits them as a list.
  ///
  /// ### When to use
  /// Use [zipAll] when you want to collect values from a single source
  /// into batches by count.
  ///
  /// - **Batching**: Batching values into fixed-size lists.
  /// - **Chunking**: Chunking data into chunks of a fixed size.
  /// - **Pagination**: Creating pages of data.
  /// - **Collection**: Collecting values into groups.
  /// - **Aggregation**: Aggregating values into lists.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The payload is added to the current row.
  /// 3. When the row reaches [width], it's emitted as a list.
  /// 4. The row is cleared.
  ///
  /// ### Non‑obvious
  /// - **Batching**: Values are batched by count.
  /// - **Single Source**: Only one source is used.
  /// - **No Overlap**: Each value appears in exactly one batch.
  /// - **Memory Usage**: Only holds up to [width] values at a time.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [width]: **Batch Size.** The number of values in each batch.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the batches.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.zipAll<int>(
  ///   input.cell,
  ///   width: 3,
  /// );
  ///
  /// input.emit(1); // no output
  /// input.emit(2); // no output
  /// input.emit(3); // -> [1, 2, 3]
  /// input.emit(4); // no output
  /// input.emit(5); // no output
  /// input.emit(6); // -> [4, 5, 6]
  /// ```
  ///
  /// ### See Also:
  /// - [zipWith]: For zipping the source with other cells.
  /// - [zip]: For zipping extra sources with an arm.
  /// - [bufferCount]: For more flexible count-based buffering.
  static FlowHandle zipAll<T>(
      Cell source, {
        required int width,
        ZipErrorHandler? onError,
      }) {
    return ZipAll<T>(width, onError: onError).toHandle(source: source);
  }

  /// Combines the latest value from [source] with the latest values from
  /// [others] whenever any of them emit.
  ///
  /// [combineLatestWith] acts as a **Multi-Source Combiner**. It combines the
  /// latest values from the bound source and all other cells into a single
  /// output using a custom [combine] function.
  ///
  /// ### When to use
  /// Use [combineLatestWith] when you need to combine multiple reactive sources:
  ///
  /// - **Form Validation**: Combining multiple form fields into a validation state
  /// - **UI State**: Combining user preferences and data to compute UI state
  /// - **Real-time Dashboards**: Combining multiple data streams
  /// - **Dependency Tracking**: Combining values from different dependencies
  /// - **Feature Flags**: Combining multiple feature flags
  /// - **Filtering**: Combining filter criteria from multiple controls
  /// - **Search**: Combining search query with filters
  ///
  /// ### How it works
  /// 1. The first source pulse arms the instruction and provides the source value.
  /// 2. Observers are started on all [others] cells.
  /// 3. Once all cells have at least one value, the [combine] function is called.
  /// 4. The result is emitted as a [Pulse].
  /// 5. Whenever any cell updates, the [combine] function is called again.
  ///
  /// ### Non‑obvious
  /// - **All Must Have Value**: Emission only happens after all cells have
  ///   at least one value.
  /// - **Latest Values**: Always uses the most recent value from each cell.
  /// - **Any Update Triggers**: Any cell update triggers a new combination.
  /// - **Source Arming**: The first source pulse is required to arm.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [others]: **The Additional Cells.** Cells to combine with the source.
  /// - [combine]: **The Combination Function.** Takes the source value and a
  ///   list of latest values from others, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  /// - [R]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the combined values.
  ///
  /// ### Example
  /// ```dart
  /// final username = Cell.ingress<String>();
  /// final password = Cell.ingress<String>();
  ///
  /// final handle = Flow.combineLatestWith<String, bool>(
  ///   username.cell,
  ///   others: [password.cell],
  ///   combine: (username, latest) =>
  ///       username.isNotEmpty && (latest.single as String).isNotEmpty,
  /// );
  ///
  /// username.emit('user'); // No emission (password not set)
  /// password.emit('pass'); // Emits true
  /// username.emit('');     // Emits false
  /// ```
  ///
  /// ### See Also:
  /// - [withLatestFrom]: For source-driven combination.
  /// - [zipWith]: For index-based pairing.
  static FlowHandle combineLatestWith<S, R>(
      Cell source, {
        required List<Cell> others,
        required R Function(S sourceValue, List<Object?> latest) combine,
        CombineErrorHandler? onError,
      }) {
    return CombineLatestWith<S, R>(
      others,
      combine,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Combines the latest value from [source] with the latest values from
  /// [others] only when [source] emits (Rx `withLatestFrom`).
  ///
  /// [withLatestFrom] acts as a **Source-Driven Combiner**. It only emits when
  /// the source updates, using the latest values from the other cells at that
  /// moment.
  ///
  /// ### When to use
  /// Use [withLatestFrom] when:
  /// - You want to combine the source with the latest values of others
  /// - You only want to emit when the source updates
  /// - You're implementing a "sample on source" pattern
  /// - You're driving updates from one primary source
  /// - You're pairing user actions with the latest state
  /// - You're implementing a command pattern with state
  ///
  /// ### How it works
  /// 1. Observers are started on all [others] cells to track their latest values.
  /// 2. When the bound source pulses, the [combine] function is called with
  ///    the source value and the latest values from [others].
  /// 3. If any other cell has not yet produced a value, the source pulse is dropped.
  /// 4. The result is emitted as a [Pulse].
  ///
  /// ### Non‑obvious
  /// - **Source-Driven**: Only source updates trigger emission.
  /// - **Latest Values**: Uses the latest values from others at the time of
  ///   source update.
  /// - **Drop on Miss**: Source pulses are dropped if any other cell has no value.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [others]: **The Additional Cells.** Cells to sample the latest values from.
  /// - [combine]: **The Combination Function.** Takes the source value and a
  ///   list of latest values from others, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  /// - [R]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the combined values.
  ///
  /// ### Example
  /// ```dart
  /// final actions = Cell.ingress<String>();
  /// final state = Cell.ingress<AppState>();
  ///
  /// final handle = Flow.withLatestFrom<String, Processed>(
  ///   actions.cell,
  ///   others: [state.cell],
  ///   combine: (action, latest) =>
  ///       Processed(action: action, state: latest.single as AppState),
  /// );
  ///
  /// // Only emits when actions emit, using the latest state
  /// await state.emitAsync(initialState);
  /// await actions.emitAsync('update'); // emits processed action
  /// ```
  ///
  /// ### See Also:
  /// - [combineLatestWith]: For any-update-driven combination.
  /// - [zipWith]: For index-based pairing.
  static FlowHandle withLatestFrom<S, R>(
      Cell source, {
        required List<Cell> others,
        required R Function(S sourceValue, List<Object?> latest) combine,
        CombineErrorHandler? onError,
      }) {
    return WithLatestFrom<S, R>(
      others,
      combine,
      onError: onError,
    ).toHandle(source: source);
  }

  /// First inner to emit wins (Rx `race`).
  ///
  /// [race] acts as a **Competitive Selector**. Multiple competitors are
  /// started concurrently, and the first one to produce a value of type [T]
  /// wins. All other competitors are ignored.
  ///
  /// ### When to use
  /// Use [race] when you have multiple sources of the same data and you want
  /// the fastest one:
  ///
  /// - **Fastest Response**: You want the fastest response from multiple sources
  /// - **Redundant Services**: You have redundant services for reliability
  /// - **Cache vs Network**: You want to race cache against network
  /// - **Multiple APIs**: You want to try multiple APIs in parallel
  /// - **Fallback Sources**: You want to try primary then fallback
  /// - **Load Balancing**: You want to pick the fastest replica
  /// - **Performance Optimization**: You want to minimize latency
  /// - **Reliability**: You want to tolerate failures from individual sources
  ///
  /// ### Supported Competitor Types
  /// Each competitor can be any of the following:
  /// - `Stream<T>`: The first event in the stream wins.
  /// - `Future<T>`: The future's value wins.
  /// - `Iterable<T>`: The first element wins.
  /// - `T`: The value itself wins immediately.
  /// - `null`: The competitor is ignored (no emission).
  /// - **Nested combinations**: Recursively expanded.
  ///
  /// ### Non‑obvious
  /// - **One-Shot**: The race is started on the first trigger only.
  /// - **Concurrent**: All competitors are started concurrently.
  /// - **First Value Wins**: Only the first value from any competitor is emitted.
  /// - **Streams are Cancelled**: Streams that lose are cancelled.
  /// - **Error Handling**: Errors are reported via [onError].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the trigger.
  /// - [competitors]: **The Competitors.** An iterable of sources to race.
  ///
  /// ### Type Parameters:
  /// - [T]: The type of the output payload from the winner.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the winner's value.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.race<String>(
  ///   start.cell,
  ///   competitors: [
  ///     Future.delayed(Duration(milliseconds: 40), () => 'slow'),
  ///     Future.delayed(Duration(milliseconds: 5), () => 'fast'),
  ///   ],
  /// );
  ///
  /// start.emit(null); // Emits 'fast'
  /// ```
  static FlowHandle race<T>(
      Cell source, {
        required List<Object?> competitors,
      }) {
    return Race<T>(competitors).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Time
  // ─────────────────────────────────────────────────────────────

  /// Shift every value by [duration] (Rx `delay`).
  ///
  /// [delay] is the fundamental delay operator. It delays each pulse
  /// by a fixed duration before forwarding it.
  ///
  /// ### When to use
  /// Use [delay] when you need to introduce a fixed time delay
  /// between receiving a pulse and forwarding it.
  ///
  /// - **Debouncing**: Delaying actions to avoid rapid triggers.
  /// - **Animation**: Delaying UI updates for animation timing.
  /// - **Throttling**: Introducing latency for rate limiting.
  /// - **Synchronization**: Synchronizing with external timing.
  /// - **Testing**: Simulating network latency.
  /// - **User Experience**: Adding deliberate delays for UX.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. A timer is started for [duration].
  /// 3. When the timer fires, the pulse is forwarded.
  /// 4. The pulse gets the step `'Delay'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Fixed Delay**: The delay is the same for all pulses.
  /// - **No Cancellation**: Previous delays are not cancelled.
  /// - **Provenance Preservation**: The forwarded pulse preserves the
  ///   source cell, type, and priority from the trigger pulse.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Delay Duration.** The time to wait before
  ///   forwarding each pulse.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the delayed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.delay<int>(
  ///   input.cell,
  ///   duration: Duration(milliseconds: 500),
  /// );
  ///
  /// input.emit(42); // Will be emitted after 500ms
  /// ```
  ///
  /// ### See Also:
  /// - [delayWithSelector]: For payload-dependent delay.
  /// - [delayWhen]: For notifier-based delay.
  /// - [delayLatest]: For trailing delay.
  static FlowHandle delay<S>(
      Cell source, {
        required Duration duration,
        DelayErrorHandler? onError,
      }) {
    return Delay<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Per-value delay.
  ///
  /// [delayWithSelector] is similar to [delay] but the delay duration
  /// is computed from the payload value.
  ///
  /// ### When to use
  /// Use [delayWithSelector] when the delay depends on the payload.
  ///
  /// - **Priority-Based Delay**: Higher priority values get shorter delays.
  /// - **Size-Based Delay**: Larger items get longer delays.
  /// - **Type-Based Delay**: Different types get different delays.
  /// - **Conditional Delay**: Delay based on payload conditions.
  /// - **Adaptive Delay**: Delay adapts to payload characteristics.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. [durationOf] is called with the payload.
  /// 3. A timer is started for the computed duration.
  /// 4. When the timer fires, the pulse is forwarded.
  ///
  /// ### Non‑obvious
  /// - **Payload-Dependent**: The delay is computed from the payload.
  /// - **Error Handling**: If [durationOf] throws, the pulse is dropped.
  /// - **Provenance Preservation**: The forwarded pulse preserves the
  ///   source cell, type, and priority from the trigger pulse.
  /// - **Synchronous Extraction**: [durationOf] is synchronous.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [durationOf]: **Duration Selector.** Called with each typed
  ///   payload, returns the delay duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the delayed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<String>();
  ///
  /// final handle = Flow.delayWithSelector<String>(
  ///   input.cell,
  ///   durationOf: (str) => Duration(milliseconds: str.length * 10),
  /// );
  ///
  /// input.emit('a');    // 10ms delay
  /// input.emit('hello'); // 50ms delay
  /// ```
  ///
  /// ### See Also:
  /// - [delay]: For fixed delay.
  /// - [delayWhen]: For notifier-based delay.
  /// - [delayLatest]: For trailing delay.
  static FlowHandle delayWithSelector<S>(
      Cell source, {
        required Duration Function(S value) durationOf,
        DelayErrorHandler? onError,
      }) {
    return DelayWithSelector<S>(durationOf, onError: onError)
        .toHandle(source: source);
  }

  /// Wait for [when] before forwarding (Rx `delayWhen`).
  ///
  /// [delayWhen] is a flexible delay operator that can wait for a
  /// Duration, a Future, or the first event of a Stream.
  ///
  /// ### When to use
  /// Use [delayWhen] when the delay depends on an external notifier.
  ///
  /// - **External Events**: Waiting for external events before forwarding.
  /// - **Async Conditions**: Waiting for async conditions to complete.
  /// - **Stream Signals**: Waiting for the first stream event.
  /// - **Complex Timing**: Coordinating with complex timing signals.
  /// - **Synchronization**: Synchronizing with external processes.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. [when] is called with the payload to get a notifier.
  /// 3. The notifier is awaited:
  ///    - `Duration`: uses `Future.delayed`
  ///    - `Future`: awaits the future
  ///    - `Stream`: waits for the first event
  ///    - `null`: returns immediately
  /// 4. When the notifier completes, the pulse is forwarded.
  ///
  /// ### Non‑obvious
  /// - **Flexible Notifier**: Supports Duration, Future, Stream, null.
  /// - **Async Wait**: The wait is asynchronous.
  /// - **Error Handling**: If [when] throws or the notifier errors,
  ///   the error is reported.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [when]: **Notifier Factory.** Called with each typed payload,
  ///   returns a Duration, Future, Stream, or null to wait for.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the delayed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<String>();
  ///
  /// final handle = Flow.delayWhen<String>(
  ///   input.cell,
  ///   when: (_) => Future.delayed(Duration(seconds: 1)),
  /// );
  ///
  /// // Emits after the Future completes
  /// ```
  ///
  /// ### See Also:
  /// - [delay]: For fixed delay.
  /// - [delayWithSelector]: For payload-dependent delay.
  /// - [delayLatest]: For trailing delay.
  static FlowHandle delayWhen<S>(
      Cell source, {
        required FutureOr<Object?> Function(S value) when,
        DelayErrorHandler? onError,
      }) {
    return DelayWhen<S>(when, onError: onError).toHandle(source: source);
  }

  /// Only the latest value after [duration] (trailing delay).
  ///
  /// [delayLatest] is similar to [delay] but when a new pulse arrives,
  /// it cancels the pending delayed pulse. Only the latest pulse is
  /// delivered.
  ///
  /// ### When to use
  /// Use [delayLatest] when you only care about the latest value
  /// after a delay.
  ///
  /// - **Search-as-you-type**: Only the latest search query matters.
  /// - **Real-time Updates**: Only the most recent update is relevant.
  /// - **User Input**: Only the latest user input matters.
  /// - **Selection Changes**: Only the latest selection matters.
  /// - **Debouncing with Reset**: Debouncing with cancellation on new input.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. A timer is started for [duration].
  /// 3. If a new pulse arrives before the timer fires, the previous
  ///    timer is cancelled.
  /// 4. Only the latest pulse is delivered.
  ///
  /// ### Non‑obvious
  /// - **Cancellation**: Previous timers are cancelled on new pulses.
  /// - **Latest Only**: Only the latest pulse is delivered.
  /// - **Trailing**: The delay is trailing (after the last pulse).
  /// - **Generation Tracking**: Each pulse gets a generation ID to
  ///   determine if it's still current.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Delay Duration.** The time to wait before
  ///   forwarding the latest pulse.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the delayed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<String>();
  ///
  /// final handle = Flow.delayLatest<String>(
  ///   input.cell,
  ///   duration: Duration(milliseconds: 300),
  /// );
  ///
  /// input.emit('a'); // Cancelled by 'b'
  /// input.emit('b'); // Cancelled by 'c'
  /// input.emit('c'); // Delivered after 300ms
  /// ```
  ///
  /// ### See Also:
  /// - [delay]: For fixed delay.
  /// - [delayWithSelector]: For payload-dependent delay.
  /// - [delayWhen]: For notifier-based delay.
  static FlowHandle delayLatest<S>(
      Cell source, {
        required Duration duration,
        DelayErrorHandler? onError,
      }) {
    return DelayLatest<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Delays the emission of pulses until [duration] has passed since the
  /// last pulse (Rx `debounce`).
  ///
  /// [debounce] acts as a **Silence-Based Emitter**. It waits for a specified
  /// period of inactivity before emitting the latest value. Each new value
  /// resets the timer.
  ///
  /// ### When to use
  /// Use [debounce] when you need to wait for stability before emitting:
  ///
  /// - **Search-as-you-type**: Wait for the user to stop typing
  /// - **Resize / Scroll End**: Respond after the user finishes resizing
  /// - **Form Validation**: Validate after the user stops editing
  /// - **Auto-Save**: Save after the user stops making changes
  /// - **Window Resize**: Respond after the user stops resizing
  /// - **User Input**: Wait for the user to finish an action
  /// - **Idle Detection**: Detect periods of inactivity
  /// - **Noise Reduction**: Reduce noise from rapid events
  /// - **Debouncing API Calls**: Prevent excessive API calls
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The timer is reset to the full [duration] on each new value.
  /// 3. When the timer completes without interruption, the latest value is emitted.
  /// 4. Only the final value in each burst is emitted.
  ///
  /// ### Non‑obvious
  /// - **Silence Window**: The timer resets on every new pulse.
  /// - **Pending Value**: Only the most recent value is emitted.
  /// - **State Persistence**: The instruction maintains the pending value and timer.
  /// - **Order Preservation**: Only the final value in each burst is emitted.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **The Silence Window.** The period of inactivity required
  ///   before emission.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the debounced values.
  ///
  /// ### Example
  /// ```dart
  /// final search = Cell.ingress<String>();
  ///
  /// final handle = Flow.debounce<String>(
  ///   search.cell,
  ///   duration: Duration(milliseconds: 300),
  /// );
  ///
  /// search.emit('h');
  /// search.emit('he');
  /// search.emit('hel');
  /// search.emit('hell');
  /// search.emit('hello');
  /// // after 300ms, emits 'hello'
  /// ```
  ///
  /// ### See Also:
  /// - [throttle]: For rate limiting.
  /// - [sample]: For sampling on notifier.
  static FlowHandle debounce<S>(
      Cell source, {
        required Duration duration,
      }) {
    return Debounce<S>(duration).toHandle(source: source);
  }

  /// Limits the rate of emissions by enforcing a silent window of [duration]
  /// after a pulse.
  ///
  /// [throttle] acts as a **Rate Limiter** with fixed time windows. It controls
  /// the emission rate by allowing at most one value per time window, with
  /// configurable leading and trailing emissions.
  ///
  /// ### When to use
  /// Use [throttle] when you need to limit the rate of emissions:
  ///
  /// - **Scroll Events**: Limiting scroll events to prevent UI jank
  /// - **API Rate Limiting**: Enforcing API call rate limits
  /// - **Sensor Data**: Limiting sensor readings to a manageable rate
  /// - **UI Events**: Limiting resize, mousemove, or drag events
  /// - **Network Requests**: Preventing excessive network requests
  /// - **Resource Protection**: Protecting resources from overload
  /// - **Real-time Updates**: Controlling update frequency
  /// - **Telemetry**: Limiting telemetry emissions
  ///
  /// ### Throttle Modes
  /// - **Leading Only** (`leading: true, trailing: false`): Emit first value,
  ///   ignore rest during window.
  /// - **Trailing Only** (`leading: false, trailing: true`): Emit last value
  ///   after window, skip first.
  /// - **Both** (`leading: true, trailing: true`): Emit first and last.
  /// - **Neither** (`leading: false, trailing: false`): No emissions during window.
  ///
  /// ### Non‑obvious
  /// - **Fixed Windows**: Windows are fixed duration and do not reset.
  /// - **Leading Emission**: The first pulse in a window is emitted immediately.
  /// - **Trailing Emission**: The last pulse in a window is emitted when the
  ///   window closes.
  /// - **Pending Value**: Only the most recent value in the window is kept.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **The Time Window.** The minimum time between emissions.
  /// - [leading]: **Leading Emission.** If `true`, emit the first value immediately.
  /// - [trailing]: **Trailing Emission.** If `true`, emit the last value after
  ///   the window.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the throttled values.
  ///
  /// ### Example
  /// ```dart
  /// final scrollEvents = Cell.ingress<ScrollEvent>();
  ///
  /// final handle = Flow.throttle<ScrollEvent>(
  ///   scrollEvents.cell,
  ///   duration: Duration(milliseconds: 100),
  ///   leading: true,
  ///   trailing: true,
  /// );
  ///
  /// // Emits first scroll event immediately, then last after 100ms
  /// ```
  ///
  /// ### See Also:
  /// - [debounce]: For silence-based emission.
  /// - [sample]: For sampling on notifier.
  static FlowHandle throttle<S>(
      Cell source, {
        required Duration duration,
        bool leading = true,
        bool trailing = false,
      }) {
    return Throttle<S>(
      duration,
      leading: leading,
      trailing: trailing,
    ).toHandle(source: source);
  }

  /// Latest source value when [notifier] pulses.
  ///
  /// [sample] holds the latest source value and only emits it when the
  /// notifier pulses. If no new values have arrived since the last
  /// emission, the notifier pulse is ignored.
  ///
  /// ### When to use
  /// Use [sample] when you want to emit the latest value at specific
  /// times defined by a notifier.
  ///
  /// - **UI Updates**: Emitting the latest state on a timer or animation frame.
  /// - **Throttled Output**: Outputting the latest value at a fixed rate.
  /// - **Event Sampling**: Sampling events on a separate signal.
  /// - **Real-time Dashboards**: Updating dashboards at a fixed rate.
  /// - **Sensor Data**: Sampling sensor data at a fixed rate.
  ///
  /// ### How it works
  /// 1. Each source pulse is type-checked and stored as the pending value.
  /// 2. When the [notifier] cell pulses:
  ///    a. If there's a pending value, it's emitted.
  ///    b. The pending value is cleared.
  ///    c. If no pending value, nothing is emitted.
  ///
  /// ### Non‑obvious
  /// - **Pending Only**: Values are only emitted if they arrived since
  ///   the last emission.
  /// - **Ignored Ticks**: Notifier ticks with no pending value are ignored.
  /// - **Latest Only**: Only the latest value is held; older values are
  ///   overwritten.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [notifier]: **Notifier Cell.** The cell that triggers sampling.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the sampled values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  /// final tick = Cell.ingress<void>();
  ///
  /// final handle = Flow.sample<int>(
  ///   source.cell,
  ///   notifier: tick.cell,
  /// );
  ///
  /// source.emit(1);
  /// source.emit(2);
  /// tick.emit(null); // -> 2
  /// source.emit(3);
  /// // tick.emit(null); // -> 3
  /// ```
  ///
  /// ### See Also:
  /// - [sampleTime]: For time-based sampling.
  /// - [audit]: For audit on notifier.
  static FlowHandle sample<S>(
      Cell source, {
        required Cell notifier,
        SampleErrorHandler? onError,
      }) {
    return Sample<S>(notifier, onError: onError).toHandle(source: source);
  }

  /// Latest source value every [period].
  ///
  /// [sampleTime] is similar to [sample] but the sampling is driven by
  /// a periodic timer instead of a notifier cell.
  ///
  /// ### When to use
  /// Use [sampleTime] when you want to sample the latest value at a
  /// fixed interval.
  ///
  /// - **UI Throttling**: Throttling UI updates to a fixed frame rate.
  /// - **Sensor Sampling**: Sampling sensor data at a fixed rate.
  /// - **Heartbeat**: Emitting the latest state on a heartbeat.
  /// - **Real-time Dashboards**: Updating dashboards at a fixed rate.
  /// - **Performance**: Reducing update frequency for performance.
  ///
  /// ### How it works
  /// 1. The first source pulse starts the timer.
  /// 2. Each source pulse updates the pending value.
  /// 3. Every [period], the timer fires:
  ///    a. If there's a pending value, it's emitted.
  ///    b. The pending value is cleared.
  /// 4. The timer continues indefinitely.
  ///
  /// ### Non‑obvious
  /// - **Lazy Start**: The timer starts on the first pulse.
  /// - **Continuous Timer**: The timer runs until the instruction is disposed.
  /// - **Pending Only**: Values are only emitted if they arrived since
  ///   the last emission.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [period]: **Sampling Period.** The interval between samples.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the sampled values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  ///
  /// final handle = Flow.sampleTime<int>(
  ///   source.cell,
  ///   period: Duration(milliseconds: 100),
  /// );
  ///
  /// source.emit(1);
  /// source.emit(2);
  /// // After 100ms: -> 2
  /// ```
  ///
  /// ### See Also:
  /// - [sample]: For notifier-based sampling.
  /// - [interval]: For emitting values at a fixed interval.
  static FlowHandle sampleTime<S>(
      Cell source, {
        required Duration period,
        SampleErrorHandler? onError,
      }) {
    return SampleTime<S>(period, onError: onError).toHandle(source: source);
  }

  /// After a source value, emit it on the next [notifier] pulse.
  ///
  /// [audit] is similar to [sample] but the audit is triggered by the
  /// notifier after a source pulse has arrived.
  ///
  /// ### When to use
  /// Use [audit] when you want to audit a value after a source pulse
  /// and wait for a notifier to confirm.
  ///
  /// - **Confirmation**: Waiting for a confirmation before emitting.
  /// - **Gate Control**: Emitting only when a gate signal arrives.
  /// - **Synchronization**: Synchronizing emission with a notifier.
  /// - **Validation**: Validating values before emission.
  /// - **Conditional Emission**: Emitting only under certain conditions.
  ///
  /// ### How it works
  /// 1. Each source pulse is type-checked and stored as the pending value.
  /// 2. The `waiting` flag is set to true.
  /// 3. When the [notifier] cell pulses:
  ///    a. If `waiting` is true, the pending value is emitted.
  ///    b. The pending value is cleared.
  ///    c. The `waiting` flag is set to false.
  /// 4. If no source pulse has arrived since the last audit, the
  ///    notifier pulse is ignored.
  ///
  /// ### Non‑obvious
  /// - **Waiting Flag**: The waiting flag tracks if a source pulse
  ///   has arrived since the last audit.
  /// - **One-Time Audit**: Each source pulse can only be audited once.
  /// - **Ignored Ticks**: Notifier ticks with no waiting are ignored.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [notifier]: **Notifier Cell.** The cell that triggers the audit.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the audited values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  /// final gate = Cell.ingress<void>();
  ///
  /// final handle = Flow.audit<int>(
  ///   source.cell,
  ///   notifier: gate.cell,
  /// );
  ///
  /// source.emit(1);
  /// source.emit(2);
  /// gate.emit(null); // -> 2
  /// // gate.emit(null); // ignored (no pending)
  /// ```
  ///
  /// ### See Also:
  /// - [sample]: For sampling on notifier.
  /// - [auditTime]: For time-based audit.
  static FlowHandle audit<S>(
      Cell source, {
        required Cell notifier,
        SampleErrorHandler? onError,
      }) {
    return Audit<S>(notifier, onError: onError).toHandle(source: source);
  }

  /// Emit the latest value [duration] after a source move.
  ///
  /// [auditTime] is similar to "debounce of the latest value after it
  /// moved". It waits for a period of silence after the last pulse
  /// before emitting the latest value.
  ///
  /// ### When to use
  /// Use [auditTime] when you want to wait for a period of silence
  /// after the last pulse before emitting.
  ///
  /// - **Debouncing**: Debouncing the latest value after activity stops.
  /// - **Stabilization**: Waiting for values to stabilize.
  /// - **Rate Limiting**: Limiting the rate of emissions.
  /// - **Idle Detection**: Detecting idle periods.
  /// - **User Input**: Waiting for user to stop typing.
  ///
  /// ### How it works
  /// 1. Each source pulse is type-checked and stored as the pending value.
  /// 2. If there's already a scheduled timer, it's not reset (one-shot).
  /// 3. After [duration], the pending value is emitted.
  /// 4. The timer is a one-shot, not periodic.
  ///
  /// ### Non‑obvious
  /// - **One-Shot Timer**: The timer fires once and stops.
  /// - **No Reset**: Unlike debounce, the timer is not reset on new pulses.
  /// - **Latest in Window**: The latest value in the window is emitted.
  /// - **Scheduled Flag**: Prevents multiple timers from running.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Audit Duration.** The time to wait after a source
  ///   pulse before emitting the latest value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the source payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the audited values.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.ingress<int>();
  ///
  /// final handle = Flow.auditTime<int>(
  ///   source.cell,
  ///   duration: Duration(milliseconds: 100),
  /// );
  ///
  /// source.emit(1);
  /// source.emit(2);
  /// // After 100ms: -> 2
  /// ```
  ///
  /// ### See Also:
  /// - [audit]: For audit on notifier.
  /// - [debounce]: For resetting the timer on each pulse.
  static FlowHandle auditTime<S>(
      Cell source, {
        required Duration duration,
        SampleErrorHandler? onError,
      }) {
    return AuditTime<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Idle timeout after the last pulse.
  ///
  /// [timeout] is the standard timeout operator. It starts a timer on
  /// the first pulse and resets it on every subsequent pulse. If the
  /// timer expires, a [TimeoutException] is emitted as an error pulse.
  ///
  /// ### When to use
  /// Use [timeout] when you need to detect idle periods in a stream.
  ///
  /// - **Idle Detection**: Detecting user inactivity.
  /// - **Connection Timeout**: Detecting network connection timeouts.
  /// - **Heartbeat Monitoring**: Detecting missing heartbeats.
  /// - **Response Timeout**: Detecting slow responses.
  /// - **Session Timeout**: Detecting session expiration.
  /// - **Resource Cleanup**: Cleaning up idle resources.
  ///
  /// ### How it works
  /// 1. The first typed pulse starts the timer.
  /// 2. Each subsequent typed pulse resets the timer.
  /// 3. If the timer expires, a timeout error is emitted.
  /// 4. The error pulse has type `'error'` for routing.
  /// 5. The clock is closed after the first timeout.
  ///
  /// ### Non‑obvious
  /// - **Single Timeout**: The clock closes after the first timeout.
  /// - **Reset Behavior**: Timer resets on every typed pulse.
  /// - **Error Type**: The error is a [TimeoutException].
  /// - **Type Safety**: The instruction is generic over [S].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Timeout Duration.** The maximum gap between pulses
  ///   before a timeout is triggered.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
  ///   pulse on timeout. Defaults to `true`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the values and timeouts.
  ///
  /// ### Example
  /// ```dart
  /// final userActivity = Cell.ingress<String>();
  ///
  /// final handle = Flow.timeout<String>(
  ///   userActivity.cell,
  ///   duration: Duration(seconds: 5),
  ///   onError: (error, stack) => print('User idle: $error'),
  /// );
  ///
  /// // After 5 seconds of inactivity, emits a TimeoutException
  /// ```
  ///
  /// ### See Also:
  /// - [timeoutWithFallback]: For fallback on timeout.
  /// - [timeout]: For overall deadline from first pulse.
  static FlowHandle timeout<S>(
      Cell source, {
        required Duration duration,
        TimeoutErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return Timeout<S>(
      duration,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Timeout with a fallback value.
  ///
  /// [timeoutWithFallback] is similar to [timeout] but emits a fallback
  /// value instead of an error on timeout.
  ///
  /// ### When to use
  /// Use [timeoutWithFallback] when you want to provide a default value
  /// on timeout instead of an error.
  ///
  /// - **Default Values**: Providing default values on timeout.
  /// - **Graceful Degradation**: Degrading gracefully on timeouts.
  /// - **Cached Data**: Using cached data on timeout.
  /// - **Placeholder Values**: Using placeholder values.
  /// - **Offline Mode**: Emitting offline mode values.
  ///
  /// ### How it works
  /// 1. Same as [timeout] but with fallback value.
  /// 2. On timeout, [fallback] is emitted instead of an error.
  /// 3. If [once] is `true`, the fallback is emitted only once.
  /// 4. If [once] is `false`, the fallback is emitted on every timeout.
  ///
  /// ### Non‑obvious
  /// - **Once vs Continuous**: [once] controls whether the fallback is
  ///   emitted repeatedly.
  /// - **No Error**: No error pulse is emitted.
  /// - **Provenance Preservation**: The fallback pulse preserves the
  ///   source cell, type, and priority from the trigger pulse.
  /// - **Type Safety**: The fallback must match the payload type [S].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Timeout Duration.** The maximum gap between pulses.
  /// - [fallback]: **Fallback Value.** The value to emit on timeout.
  /// - [once]: **Emit Once.** If `true`, the fallback is emitted only
  ///   once. If `false`, it's emitted on every timeout. Defaults to `true`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the values and fallbacks.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.timeoutWithFallback<int>(
  ///   input.cell,
  ///   duration: Duration(seconds: 2),
  ///   fallback: -1,
  /// );
  ///
  /// // On timeout, emits -1 instead of an error
  /// ```
  ///
  /// ### See Also:
  /// - [timeout]: For standard timeout with error.
  /// - [timeout]: For custom error on timeout.
  static FlowHandle timeoutWithFallback<S>(
      Cell source, {
        required Duration duration,
        required S fallback,
        bool once = false,
      }) {
    return TimeoutWithFallback<S>(
      duration,
      fallback: fallback,
      once: once,
    ).toHandle(source: source);
  }

  /// Periodic ticks after the first pulse.
  ///
  /// [interval] is the foundational clock operator. It starts a timer when
  /// the first source pulse arrives and emits an incrementing counter at
  /// each tick.
  ///
  /// ### When to use
  /// Use [interval] when you need a periodic stream of sequential integers.
  ///
  /// - **Polling**: Periodically checking for updates.
  /// - **Heartbeats**: Sending regular "I'm alive" signals.
  /// - **Frame Counters**: Counting animation frames or update cycles.
  /// - **Timers**: Implementing countdowns or time tracking.
  /// - **Scheduled Tasks**: Running tasks at regular intervals.
  /// - **Testing**: Simulating time-based events.
  /// - **Rate Limiting**: Implementing token bucket algorithms.
  /// - **Metrics**: Counting events per time window.
  ///
  /// ### How it works
  /// 1. The first source pulse **arms** the clock.
  /// 2. A `Timer.periodic` is started with the specified [period].
  /// 3. On each tick, the current `tick` value is emitted.
  /// 4. The `tick` counter increments by 1 each emission.
  ///
  /// ### Non‑obvious
  /// - **Arming on First Pulse**: The clock starts on the first pulse, not
  ///   on creation. This allows lazy initialization.
  /// - **No Initial Emission**: Unlike Rx, there's no `0` emission at the
  ///   start. The first emission is after [period] has elapsed.
  /// - **Memory Safety**: The timer is cancelled when the instruction is
  ///   disposed.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the trigger.
  /// - [period]: **The Tick Interval.** The duration between each emission.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the periodic ticks.
  ///
  /// ### Example
  /// ```dart
  /// final start = Cell.ingress<void>();
  ///
  /// final handle = Flow.interval(
  ///   start.cell,
  ///   period: Duration(seconds: 1),
  /// );
  ///
  /// start.emit(null);
  /// // Outputs: 0, 1, 2, 3, ... every second
  /// ```
  ///
  /// ### See Also:
  /// - [interval]: For custom value emission.
  /// - [interval]: For stateful interval emissions.
  static FlowHandle interval(
      Cell source, {
        required Duration period,
      }) {
    return Interval(period).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Collect
  // ─────────────────────────────────────────────────────────────

  /// Collects payloads into a list and emits it once it reaches [size] (Rx `bufferCount`).
  ///
  /// Collects payloads into a list and emits it once it reaches [size] (Rx `bufferCount`).
  ///
  /// [bufferCount] is a **Count-Based Aggregator**. It batches incoming pulses into
  /// fixed-size lists. It supports both tumbling (non-overlapping) and sliding
  /// (overlapping) windows.
  ///
  /// ### When to use
  /// Use [bufferCount] to group items for batch processing:
  ///
  /// - **Batch API Calls**: Gathering N requests to send in one network call.
  /// - **Sliding Windows**: Computing moving averages or looking at the last N events.
  /// - **Data Chunking**: Breaking a high-frequency stream into manageable blocks.
  /// - **Pairwise Logic**: Use `size: 2, skip: 1` to process consecutive pairs.
  ///
  /// ### Skip Behavior
  /// | Skip | Behavior | Example (size=3) |
  /// |------|----------|------------------|
  /// | `skip == size` | Tumbling (no overlap) | `[1, 2, 3]`, `[4, 5, 6]` |
  /// | `skip < size` | Overlapping | `[1, 2, 3]`, `[2, 3, 4]`, `[3, 4, 5]` |
  /// | `skip > size` | Gaps (items skipped) | `[1, 2, 3]`, `[5, 6, 7]` (4 skipped) |
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked against [S].
  /// 2. The payload is added to an internal buffer.
  /// 3. Once the buffer length reaches [size], a copy of the buffer is emitted as a `List<S>`.
  /// 4. The buffer is then shifted by [skip] (which defaults to [size]).
  /// 5. If `skip` == `size`, the buffer is cleared completely (tumbling).
  /// 6. If `skip` < `size`, the last `size - skip` elements are kept (sliding).
  ///
  /// ### Non‑obvious
  /// - **Lazy Emission**: No pulse is emitted until at least [size] pulses have arrived.
  /// - **Memory Usage**: The operator holds a maximum of [size] elements in memory.
  /// - **Overlapping Windows**: If [skip] is less than [size], elements will appear in
  ///   multiple output lists.
  /// - **Gaps**: If [skip] is greater than [size], some incoming elements will be
  ///   discarded between buffers.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [size]: **Window Size.** The number of elements to include in each buffer.
  /// - [skip]: **Stride.** How many items to skip before starting a new
  ///   buffer. Defaults to [size] (tumbling).
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the buffered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// // Tumbling window of 3
  /// final handle = Flow.bufferCount<int>(
  ///   input.cell,
  ///   size: 3,
  /// );
  ///
  /// input.emit(1); // No output
  /// input.emit(2); // No output
  /// input.emit(3); // -> [1, 2, 3]
  /// input.emit(4); // No output
  /// input.emit(5); // No output
  /// input.emit(6); // -> [4, 5, 6]
  /// ```
  ///
  /// ### See Also:
  /// - [bufferTime]: For time-based buffering.
  /// - [bufferWhen]: For trigger-based buffering.
  static FlowHandle bufferCount<S>(
      Cell source, {
        required int size,
        int? skip,
        BufferErrorHandler? onError,
      }) {
    return BufferCount<S>(size, skip: skip, onError: onError)
        .toHandle(source: source);
  }

  /// Periodically flushes the collected payloads into a list and emits it (Rx `bufferTime`).
  ///
  /// [bufferTime] batches incoming values into time-based buffers.
  /// The clock starts on the first typed pulse and flushes the buffer
  /// every [duration].
  ///
  /// ### When to use
  /// Use [bufferTime] when you need to batch values by time.
  ///
  /// - **Rate Limiting**: Limiting the rate of processed items.
  /// - **Time-Based Batching**: Grouping items by time interval.
  /// - **Sliding Windows**: Implementing sliding time windows.
  /// - **Throttling**: Throttling processing to a fixed rate.
  /// - **Metrics**: Aggregating metrics over time.
  /// - **Logging**: Batching log entries by time.
  ///
  /// ### How it works
  /// 1. The first typed pulse starts the timer.
  /// 2. Each pulse's payload is added to the buffer.
  /// 3. Every [duration], the buffer is emitted as a list.
  /// 4. The buffer is cleared after emission.
  /// 5. If [emitEmpty] is `false`, empty buffers are skipped.
  ///
  /// ### Non‑obvious
  /// - **Lazy Start**: The timer starts on the first pulse, not on
  ///   instruction creation.
  /// - **Continuous**: The timer continues indefinitely until disposed.
  /// - **Empty Skip**: [emitEmpty] controls whether empty buffers are
  ///   emitted.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Buffer Duration.** The time interval for each buffer.
  /// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
  ///   emitted as empty lists. Defaults to `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the buffered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.bufferTime<int>(
  ///   input.cell,
  ///   duration: Duration(seconds: 1),
  ///   emitEmpty: false,
  /// );
  ///
  /// // Emits accumulated values every second
  /// // Outputs: `[1, 2]`, `[3, 4]`, `[5]`
  /// ```
  ///
  /// ### See Also:
  /// - [bufferCount]: For count-based buffering.
  /// - [bufferWhen]: For trigger-based buffering.
  static FlowHandle bufferTime<S>(
      Cell source, {
        required Duration duration,
        bool emitEmpty = false,
        BufferErrorHandler? onError,
      }) {
    return BufferTime<S>(
      duration,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flush when [closer] pulses.
  ///
  /// [bufferWhen] batches incoming values until an external trigger
  /// pulses, then emits the accumulated values as a list.
  ///
  /// ### When to use
  /// Use [bufferWhen] when you need to batch values based on external
  /// triggers.
  ///
  /// - **Manual Batching**: Batching on user action or button click.
  /// - **Event-Driven**: Batching on specific events.
  /// - **Request/Response**: Batching until a response arrives.
  /// - **Conditional Batching**: Batching when a condition is met.
  /// - **Interactive Batching**: Batching based on user interaction.
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is added to the buffer.
  /// 2. When the [closer] cell emits a pulse:
  ///    a. The buffer is emitted as a list.
  ///    b. The buffer is cleared.
  /// 3. If [emitEmpty] is `true`, empty buffers are emitted.
  /// 4. The closer can be triggered multiple times.
  ///
  /// ### Non‑obvious
  /// - **Multiple Closes**: The closer can be triggered repeatedly.
  /// - **Continuous Batching**: After a close, batching continues.
  /// - **Empty Control**: [emitEmpty] controls empty buffer emission.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [closer]: **Closer Cell.** The cell that triggers buffer emission
  ///   when it pulses.
  /// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
  ///   emitted as empty lists. Defaults to `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the buffered values.
  ///
  /// ### Example
  /// ```dart
  /// final items = Cell.ingress<String>();
  /// final flush = Cell.ingress<void>();
  ///
  /// final handle = Flow.bufferWhen<String>(
  ///   items.cell,
  ///   closer: flush.cell,
  /// );
  ///
  /// items.emit('a'); // buffered
  /// items.emit('b'); // buffered
  /// flush.emit(null); // -> ['a', 'b']
  /// ```
  ///
  /// ### See Also:
  /// - [bufferCount]: For count-based buffering.
  /// - [bufferTime]: For time-based buffering.
  static FlowHandle bufferWhen<S>(
      Cell source, {
        required Cell closer,
        bool emitEmpty = false,
        BufferErrorHandler? onError,
      }) {
    return BufferWhen<S>(
      closer,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Close the buffer when [test] is true.
  ///
  /// [bufferWithPredicate] batches incoming values until the predicate
  /// returns `true`, then emits the accumulated values as a list.
  ///
  /// ### When to use
  /// Use [bufferWithPredicate] when you need to batch based on a
  /// condition.
  ///
  /// - **Conditional Batching**: Batching when a condition is met.
  /// - **Data Validation**: Batching until validation passes.
  /// - **State Changes**: Batching on state changes.
  /// - **Thresholds**: Batching when thresholds are reached.
  /// - **Pattern Detection**: Batching when patterns are detected.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The [test] predicate is called with the payload.
  /// 3. If [test] returns `false`, the value is added to the buffer.
  /// 4. If [test] returns `true`:
  ///    a. If [includeTrigger] is `true`, the value is added.
  ///    b. The buffer is emitted as a list.
  ///    c. The buffer is cleared.
  ///
  /// ### Non‑obvious
  /// - **Trigger Inclusion**: [includeTrigger] controls whether the
  ///   triggering value is included in the buffer.
  /// - **Empty Skip**: Empty buffers are not emitted.
  /// - **Predicate Evaluation**: The predicate is evaluated on each value.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Called with each typed payload,
  ///   returns `true` to close the buffer.
  /// - [includeTrigger]: **Include Trigger Value.** If `true`, the value
  ///   that triggers the close is included in the buffer. Defaults to `true`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the buffered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.bufferWithPredicate<int>(
  ///   input.cell,
  ///   test: (n) => n.isEven,
  /// );
  ///
  /// input.emit(1); // buffered
  /// input.emit(2); // -> [1, 2] (even triggers flush)
  /// input.emit(3); // buffered
  /// input.emit(4); // -> [3, 4]
  /// ```
  ///
  /// ### See Also:
  /// - [bufferCount]: For count-based buffering.
  /// - [bufferTime]: For time-based buffering.
  static FlowHandle bufferWithPredicate<S>(
      Cell source, {
        required bool Function(S value) test,
        bool includeTrigger = true,
        BufferErrorHandler? onError,
      }) {
    return BufferWithPredicate<S>(
      test,
      includeTrigger: includeTrigger,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flush on count **or** duration.
  ///
  /// [bufferWithTimeAndCount] combines time-based and count-based
  /// buffering. The buffer flushes when either condition is met.
  ///
  /// ### When to use
  /// Use [bufferWithTimeAndCount] when you need to flush on time
  /// or count, whichever comes first.
  ///
  /// - **Maximum Latency**: Ensuring buffers don't get too old.
  /// - **Maximum Size**: Ensuring buffers don't get too large.
  /// - **Hybrid Batching**: Batching with both time and size constraints.
  /// - **Resource Management**: Managing buffer memory and latency.
  /// - **Performance**: Balancing throughput and latency.
  ///
  /// ### How it works
  /// 1. The first typed pulse starts the timer.
  /// 2. Each pulse's payload is added to the buffer.
  /// 3. If the buffer reaches [count], it flushes immediately.
  /// 4. If [duration] elapses, it flushes (even if count not reached).
  /// 5. The buffer is cleared after each flush.
  /// 6. The timer resets after each flush.
  ///
  /// ### Non‑obvious
  /// - **Two Triggers**: Either time or count can trigger a flush.
  /// - **Timer Reset**: The timer resets after each flush.
  /// - **Count Priority**: Count triggers flush immediately.
  /// - **Distinct Steps**: Different provenance steps for time and count.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Time Limit.** The maximum time between flushes.
  /// - [count]: **Size Limit.** The maximum number of items in a buffer.
  /// - [emitEmpty]: **Emit Empty Buffers.** If `true`, empty buffers are
  ///   emitted as empty lists. Defaults to `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the buffered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.bufferWithTimeAndCount<int>(
  ///   input.cell,
  ///   duration: Duration(seconds: 1),
  ///   count: 10,
  /// );
  ///
  /// // Flushes every second OR when 10 items accumulate
  /// ```
  ///
  /// ### See Also:
  /// - [bufferCount]: For count-based buffering.
  /// - [bufferTime]: For time-based buffering.
  static FlowHandle bufferWithTimeAndCount<S>(
      Cell source, {
        required Duration duration,
        required int count,
        bool emitEmpty = false,
        BufferErrorHandler? onError,
      }) {
    return BufferWithTimeAndCount<S>(
      duration: duration,
      count: count,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Window by count (list payload).
  ///
  /// [windowCount] is similar to [bufferCount] but emits windows as lists.
  ///
  /// ### When to use
  /// Use [windowCount] when you need to batch values by count and
  /// emit the batch as a list.
  ///
  /// - **Batching**: Grouping items for batch processing.
  /// - **Pagination**: Collecting items into pages.
  /// - **Chunking**: Splitting data into chunks.
  /// - **Aggregation**: Aggregating a fixed number of items.
  /// - **Buffering**: Buffering items for efficient processing.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The payload is added to the current window buffer.
  /// 3. When the buffer reaches [size], the window is emitted.
  /// 4. The buffer is cleared or advanced by [skip].
  ///
  /// | Skip | Behavior | Example (size=3) |
  /// |------|----------|------------------|
  /// | `skip == size` | Tumbling (no overlap) | `[1, 2, 3]`, `[4, 5, 6]` |
  /// | `skip < size` | Overlapping | `[1, 2, 3]`, `[2, 3, 4]`, `[3, 4, 5]` |
  /// | `skip > size` | Gaps (items skipped) | `[1, 2, 3]`, `[5, 6, 7]` (4 skipped) |
  ///
  /// ### Non‑obvious
  /// - **Tumbling Default**: [skip] defaults to [size] (no overlap).
  /// - **Overlap**: When [skip] < [size], windows overlap.
  /// - **Gaps**: When [skip] > [size], some items are skipped.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [size]: **Window Size.** The number of items in each window.
  /// - [skip]: **Skip Count.** How many items to advance for the next
  ///   window. Defaults to [size] (tumbling).
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the windows.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.windowCount<int>(
  ///   input.cell,
  ///   size: 3,
  /// );
  ///
  /// input.emit(1); // No output
  /// input.emit(2); // No output
  /// input.emit(3); // -> [1, 2, 3]
  /// ```
  ///
  /// ### See Also:
  /// - [windowTime]: For time-based windows.
  /// - [bufferCount]: For count-based buffering.
  static FlowHandle windowCount<S>(
      Cell source, {
        required int size,
        int? skip,
      }) {
    return WindowCount<S>(size, skip: skip).toHandle(source: source);
  }

  /// Window by time.
  ///
  /// [windowTime] is similar to [bufferTime] but emits windows as lists.
  ///
  /// ### When to use
  /// Use [windowTime] when you need to batch values by time and
  /// emit the batch as a list.
  ///
  /// - **Rate Limiting**: Limiting the rate of processed items.
  /// - **Time-Based Batching**: Grouping items by time interval.
  /// - **Sliding Windows**: Implementing sliding time windows.
  /// - **Throttling**: Throttling processing to a fixed rate.
  /// - **Metrics**: Aggregating metrics over time.
  /// - **Logging**: Batching log entries by time.
  ///
  /// ### How it works
  /// 1. The first typed pulse starts the timer.
  /// 2. Each pulse's payload is added to the buffer.
  /// 3. Every [duration], the buffer is emitted as a list.
  /// 4. The buffer is cleared after emission.
  /// 5. If [emitEmpty] is `false`, empty windows are skipped.
  ///
  /// ### Non‑obvious
  /// - **Lazy Start**: The timer starts on the first pulse.
  /// - **Continuous**: The timer continues indefinitely.
  /// - **Empty Skip**: [emitEmpty] controls whether empty windows are
  ///   emitted.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [duration]: **Window Duration.** The time interval for each window.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the windows.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.windowTime<int>(
  ///   input.cell,
  ///   duration: Duration(seconds: 1),
  /// );
  ///
  /// // Emits accumulated values every second
  /// ```
  ///
  /// ### See Also:
  /// - [windowCount]: For count-based windows.
  /// - [bufferTime]: For time-based buffering.
  static FlowHandle windowTime<S>(
      Cell source, {
        required Duration duration,
      }) {
    return WindowTime<S>(duration).toHandle(source: source);
  }

  /// Tag each value with [keyOf] (Rx `groupBy` flattened).
  ///
  /// [groupBy] transforms each value into a [Grouped] record containing
  /// both the original value and its group key.
  ///
  /// ### When to use
  /// Use [groupBy] when you need to tag values with group information
  /// without aggregating them.
  ///
  /// - **Categorization**: Tagging items with their category.
  /// - **Group Context**: Preserving group information for downstream.
  /// - **Partitioning**: Preparing values for group-based processing.
  /// - **Classification**: Classifying items into groups.
  /// - **Filtering by Group**: Filtering based on group membership.
  /// - **Group-Aware Processing**: Processing values with group context.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [keyOf] is called with the payload.
  /// 3. The key and value are wrapped in a [Grouped] record.
  /// 4. The [Grouped] record is emitted.
  /// 5. If [keyOf] throws an error, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **No State**: No state is maintained between pulses.
  /// - **Per-Item Emit**: Emits one [Grouped] for each input.
  /// - **Key Extraction**: [keyOf] is called for each value.
  /// - **Type Safety**: Generic over value type [S] and key type [K].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [keyOf]: **Key Extraction Function.** Called with each typed
  ///   payload, returns the group key.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [K]: The type of the group key.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the grouped values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.groupBy<int, String>(
  ///   input.cell,
  ///   keyOf: (n) => n.isEven ? 'even' : 'odd',
  /// );
  ///
  /// input.emit(1); // -> Grouped(odd, 1)
  /// input.emit(2); // -> Grouped(even, 2)
  /// ```
  ///
  /// ### See Also:
  /// - [groupCollect]: For collecting values by group.
  /// - [groupByCount]: For batching values by group.
  static FlowHandle groupBy<S, K>(
      Cell source, {
        required K Function(S value) keyOf,
        GroupErrorHandler? onError,
      }) {
    return GroupBy<S, K>(keyOf, onError: onError).toHandle(source: source);
  }

  /// Running `Map<K, List<S>>`.
  ///
  /// [groupCollect] accumulates values into groups and emits the
  /// complete map after every pulse.
  ///
  /// ### When to use
  /// Use [groupCollect] when you need a running snapshot of all
  /// grouped values.
  ///
  /// - **Real-time Dashboard**: Showing real-time group summaries.
  /// - **Aggregation**: Aggregating values by group over time.
  /// - **State Monitoring**: Monitoring grouped state.
  /// - **Caching**: Maintaining a cache of grouped values.
  /// - **Batch Processing**: Preparing batches by group.
  /// - **Reporting**: Generating reports on grouped data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [keyOf] is called with the payload.
  /// 3. The value is added to the group's list in the internal map.
  /// 4. The current map is emitted as a snapshot.
  /// 5. If [keyOf] throws an error, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **Stateful**: Maintains a map of all groups.
  /// - **Running Snapshot**: Emits the complete map after every pulse.
  /// - **Snapshot Copy**: The emitted map is a copy (not the internal map).
  /// - **Monotonic Growth**: Groups only grow; values are never removed.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [keyOf]: **Key Extraction Function.** Called with each typed
  ///   payload, returns the group key.
  /// - [groups]: **Initial Groups Map.** Optional. Use this to seed
  ///   the groups or to access the map externally.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [K]: The type of the group key.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the grouped maps.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.groupCollect<int, String>(
  ///   input.cell,
  ///   keyOf: (n) => n.isEven ? 'even' : 'odd',
  /// );
  ///
  /// input.emit(1); // -> {odd: [1]}
  /// input.emit(2); // -> {odd: [1], even: [2]}
  /// ```
  ///
  /// ### See Also:
  /// - [groupBy]: For tagging values with group keys.
  /// - [groupByCount]: For batching values by group.
  static FlowHandle groupCollect<S, K>(
      Cell source, {
        required K Function(S value) keyOf,
        Map<K, List<S>>? groups,
        GroupErrorHandler? onError,
      }) {
    return GroupCollect<S, K>(
      keyOf,
      groups: groups,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Emit a group's list when it hits [size].
  ///
  /// [groupByCount] accumulates values by group and emits the list
  /// when a group reaches the specified size. The group is then cleared.
  ///
  /// ### When to use
  /// Use [groupByCount] when you need to batch values by group
  /// and emit when a batch is full.
  ///
  /// - **Batch Processing**: Processing items in batches by group.
  /// - **Chunking**: Chunking values by group.
  /// - **Pagination**: Paginating grouped items.
  /// - **Bulk Operations**: Performing bulk operations by group.
  /// - **Rate Limiting**: Limiting processing by group.
  /// - **Windowed Processing**: Processing windows of grouped data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [keyOf] is called with the payload.
  /// 3. The value is added to the group's list.
  /// 4. If the list reaches [size], it's emitted as a [Grouped] record.
  /// 5. The group is cleared from the internal map.
  ///
  /// ### Non‑obvious
  /// - **Stateful**: Maintains groups until they reach the size.
  /// - **Clear on Emit**: Groups are removed after emission.
  /// - **Per-Group Batching**: Each group batches independently.
  /// - **Incomplete Groups**: Groups that never reach the size are kept.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [keyOf]: **Key Extraction Function.** Called with each typed
  ///   payload, returns the group key.
  /// - [size]: **Batch Size.** The number of items required to emit.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [K]: The type of the group key.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the grouped batches.
  ///
  /// ### Example
  /// ```dart
  /// final words = Cell.ingress<String>();
  ///
  /// final handle = Flow.groupByCount<String, String>(
  ///   words.cell,
  ///   keyOf: (word) => word[0].toUpperCase(),
  ///   size: 3,
  /// );
  ///
  /// words.emit('apple');   // no output
  /// words.emit('apricot'); // no output
  /// words.emit('avocado'); // -> Grouped(A, [apple, apricot, avocado])
  /// ```
  ///
  /// ### See Also:
  /// - [groupBy]: For tagging values with group keys.
  /// - [groupCollect]: For accumulating values by group.
  static FlowHandle groupByCount<S, K>(
      Cell source, {
        required K Function(S value) keyOf,
        required int size,
        GroupErrorHandler? onError,
      }) {
    return GroupByCount<S, K>(keyOf, size, onError: onError)
        .toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Partition / route
  // ─────────────────────────────────────────────────────────────

  /// Routes pulses based on whether they satisfy the [test] predicate.
  ///
  /// [partition] transforms each value into a [Split] record containing
  /// both the original value and a boolean indicating whether it passed
  /// the predicate.
  ///
  /// ### When to use
  /// Use [partition] when you need to tag values with match information
  /// without separating them.
  ///
  /// - **Categorization**: Tagging items as matching or not.
  /// - **Match Context**: Preserving match information for downstream.
  /// - **Conditional Processing**: Processing based on match status.
  /// - **Classification**: Classifying items into two categories.
  /// - **Filtering by Status**: Filtering based on match status.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [test] is called with the payload.
  /// 3. The result and value are wrapped in a [Split] record.
  /// 4. The [Split] record is emitted.
  /// 5. If [test] throws an error, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **No State**: No state is maintained between pulses.
  /// - **Per-Item Emit**: Emits one [Split] for each input.
  /// - **Predicate Evaluation**: [test] is called for each value.
  /// - **Type Safety**: Generic over value type [S].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Called with each typed payload,
  ///   returns `true` if the value matches the condition.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the partitioned values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.partition<int>(
  ///   input.cell,
  ///   test: (n) => n.isEven,
  /// );
  ///
  /// input.emit(1); // -> Split(matched: false, value: 1)
  /// input.emit(2); // -> Split(matched: true, value: 2)
  /// ```
  ///
  /// ### See Also:
  /// - [partitionMap]: For mapping matched/unmatched values differently.
  /// - [partitionOnly]: For filtering by match status.
  static FlowHandle partition<S>(
      Cell source, {
        required bool Function(S value) test,
        PartitionErrorHandler? onError,
      }) {
    return Partition<S>(test, onError: onError).toHandle(source: source);
  }

  /// Map matched / unmatched with different projectors.
  ///
  /// [partitionMap] is similar to [partition] but instead of emitting
  /// a [Split] record, it applies different mapping functions to
  /// matched and unmatched values.
  ///
  /// ### When to use
  /// Use [partitionMap] when you need to transform matched and
  /// unmatched values differently.
  ///
  /// - **Conditional Formatting**: Formatting values based on predicate.
  /// - **Different Processing**: Processing matched/unmatched differently.
  /// - **Type Conversion**: Converting to different types based on status.
  /// - **Labeling**: Labeling values based on match status.
  /// - **Data Enrichment**: Enriching values differently based on status.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [test] is called with the payload.
  /// 3. If [test] returns `true`, [thenMap] is called with the value.
  /// 4. If [test] returns `false`, [elseMap] is called with the value.
  /// 5. The result is emitted.
  /// 6. If [test], [thenMap], or [elseMap] throws, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **No State**: No state is maintained between pulses.
  /// - **Per-Item Emit**: Emits one value for each input.
  /// - **Different Mappers**: Two different mapping functions.
  /// - **Type Safety**: Generic over value type [S] and output type [T].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Called with each typed payload,
  ///   returns `true` for matched values.
  /// - [thenMap]: **Matched Mapper.** Called with values where [test]
  ///   returns `true`.
  /// - [elseMap]: **Unmatched Mapper.** Called with values where [test]
  ///   returns `false`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the mapped values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.partitionMap<int, String>(
  ///   input.cell,
  ///   test: (n) => n.isEven,
  ///   thenMap: (n) => 'even-$n',
  ///   elseMap: (n) => 'odd-$n',
  /// );
  ///
  /// input.emit(1); // -> odd-1
  /// input.emit(2); // -> even-2
  /// ```
  ///
  /// ### See Also:
  /// - [partition]: For tagging values with match status.
  /// - [partitionOnly]: For filtering by match status.
  static FlowHandle partitionMap<S, T>(
      Cell source, {
        required bool Function(S value) test,
        required T Function(S value) thenMap,
        required T Function(S value) elseMap,
        PartitionErrorHandler? onError,
      }) {
    return PartitionMap<S, T>(
      test,
      thenMap: thenMap,
      elseMap: elseMap,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Keep only the matching side.
  ///
  /// [partitionOnly] is a filtering operator that only passes values
  /// that match the predicate.
  ///
  /// ### When to use
  /// Use [partitionOnly] when you only want values that match (or don't
  /// match) a predicate.
  ///
  /// - **Filtering**: Filtering values by a condition.
  /// - **Positive Filtering**: Keeping only matching values.
  /// - **Negative Filtering**: Keeping only non-matching values.
  /// - **Validation**: Passing only valid values.
  /// - **Data Cleaning**: Keeping only clean data.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [test] is called with the payload.
  /// 3. If [test] returns [matched] (default `true`), the value is emitted.
  /// 4. If [test] returns the opposite, the value is dropped.
  /// 5. If [test] throws an error, the pulse is dropped.
  ///
  /// ### Non‑obvious
  /// - **No State**: No state is maintained between pulses.
  /// - **Filtering**: Only values matching the condition are emitted.
  /// - **Inverse Filtering**: With [matched] `false`, keeps non-matching values.
  /// - **Type Safety**: Generic over value type [S].
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **Predicate Function.** Called with each typed payload,
  ///   returns `true` for values to be considered.
  /// - [matched]: **Filter Mode.** If `true`, keeps values where [test]
  ///   returns `true`. If `false`, keeps values where [test] returns
  ///   `false`. Defaults to `true`.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the filtered values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.partitionOnly<int>(
  ///   input.cell,
  ///   test: (n) => n.isEven,
  /// );
  ///
  /// input.emit(1); // dropped
  /// input.emit(2); // -> 2
  /// input.emit(3); // dropped
  /// input.emit(4); // -> 4
  /// ```
  ///
  /// ### See Also:
  /// - [partition]: For tagging values with match status.
  /// - [partitionMap]: For mapping matched/unmatched values differently.
  static FlowHandle partitionOnly<S>(
      Cell source, {
        required bool Function(S value) test,
        bool matched = true,
        PartitionErrorHandler? onError,
      }) {
    return PartitionOnly<S>(
      test,
      matched: matched,
      onError: onError,
    ).toHandle(source: source);
  }

  /// A binary router that chooses between [thenMap] and [elseMap] based on
  /// [test] (Rx `iif`).
  ///
  /// [iif] acts as a **Conditional Router**. It evaluates a predicate on the
  /// payload and routes the pulse to either the [thenMap] or [elseMap]
  /// transformation path.
  ///
  /// ### When to use
  /// Use [iif] when you need to branch based on a boolean condition:
  ///
  /// - **Success vs Error**: Different handling for success and error payloads
  /// - **Feature Flags**: Different transformations based on feature flags
  /// - **Cheap vs Expensive**: Different processing for cheap vs expensive operations
  /// - **Validation**: Different handling for valid vs invalid inputs
  /// - **Type Checking**: Different handling based on payload type
  /// - **State-Dependent Logic**: Different behavior based on application state
  /// - **User Roles**: Different transformations for admin vs regular users
  /// - **Environment**: Different behavior based on environment (dev vs prod)
  ///
  /// ### How it works
  /// 1. Each incoming pulse's payload is extracted and type-checked.
  /// 2. The [test] predicate is evaluated on the payload.
  /// 3. If the predicate returns `true`, the [thenMap] function is called.
  /// 4. If the predicate returns `false`, the [elseMap] function is called.
  /// 5. The result is emitted as a [Pulse].
  /// 6. The instruction preserves causal provenance.
  ///
  /// ### Non‑obvious
  /// - **Binary Branch**: Only two paths are available: then and else.
  /// - **Type Safety**: The instruction is generic over [S] (input) and
  ///   [T] (output), ensuring compile-time type safety.
  /// - **Error Handling**: Errors in the predicate or mappers are reported
  ///   via [onError].
  /// - **Synchronous Execution**: The instruction executes synchronously.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [test]: **The Condition.** Returns `true` for the [thenMap] path.
  /// - [thenMap]: **The Then Transformation.** Called when [test] is true.
  /// - [elseMap]: **The Else Transformation.** Called when [test] is false.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the routed values.
  ///
  /// ### Example
  /// ```dart
  /// final status = Cell.ingress<int>();
  ///
  /// final handle = Flow.iif<int, String>(
  ///   status.cell,
  ///   test: (code) => code < 400,
  ///   thenMap: (c) => 'ok-$c',
  ///   elseMap: (c) => 'err-$c',
  /// );
  ///
  /// status.emit(200); // -> ok-200
  /// status.emit(404); // -> err-404
  /// ```
  ///
  /// ### See Also:
  /// - [partition]: For tagging with match status.
  /// - [iif]: For multi-path routing.
  static FlowHandle iif<S, T>(
      Cell source, {
        required bool Function(S value) test,
        required T Function(S value) thenMap,
        required T Function(S value) elseMap,
      }) {
    return Iif<S, T>(
      test,
      thenMap: thenMap,
      elseMap: elseMap,
    ).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Control / multicast / side effect
  // ─────────────────────────────────────────────────────────────

  /// Prepends the given [value] to the sequence before any pulses from
  /// [source] are emitted (Rx `startWith`).
  ///
  /// [startWith] emits the provided [value] on the first typed pulse,
  /// then forwards subsequent pulses from the source.
  ///
  /// ### When to use
  /// Use [startWith] when you need to provide an initial value before
  /// the stream starts emitting.
  ///
  /// - **Initial State**: Providing an initial value for UI state.
  /// - **Placeholder**: Providing a placeholder before data arrives.
  /// - **Loading State**: Showing a loading indicator before data loads.
  /// - **Default Values**: Providing default values.
  /// - **Splash Screens**: Showing a splash screen before content.
  /// - **Empty States**: Showing an empty state before data arrives.
  ///
  /// ### How it works
  /// 1. The first typed pulse triggers the prefix emission.
  /// 2. The [value] is emitted first.
  /// 3. Then the pulse is forwarded.
  /// 4. If [replaceFirst] is `true`, the original pulse is dropped.
  /// 5. Each emitted value gets the step `'StartWith'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **First Trigger Only**: The prefix is emitted only on the first pulse.
  /// - **Replace First**: [replaceFirst] controls whether the original
  ///   pulse is dropped.
  /// - **Provenance Preservation**: The emitted value preserves the
  ///   source cell, type, and priority from the trigger pulse.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [value]: **The Value to Prefix.** The value to emit before the stream.
  /// - [replaceFirst]: **Replace First.** If `true`, the first source pulse
  ///   is replaced by the prefix. If `false`, the prefix is emitted in
  ///   addition to the first pulse. Defaults to `false`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the prefixed values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.startWith<int>(
  ///   input.cell,
  ///   value: 0,
  /// );
  ///
  /// input.emit(1); // -> 0, 1
  /// input.emit(2); // -> 2
  /// ```
  ///
  /// ### See Also:
  /// - [startWith]: For prefixing multiple values.
  /// - [startWith]: For dynamic prefixing.
  static FlowHandle startWith<S>(
      Cell source, {
        required S value,
        bool replaceFirst = false,
      }) {
    return StartWith<S>(value, replaceFirst: replaceFirst)
        .toHandle(source: source);
  }

  /// Multicasts the same pulses to all observers (Rx `share`).
  ///
  /// [share] marks a flow as shared/multicast without buffering.
  ///
  /// ### When to use
  /// Use [share] when you want to share a subscription among multiple
  /// observers.
  ///
  /// - **Resource Sharing**: Sharing a single subscription among many views.
  /// - **Performance**: Reducing duplicate work.
  /// - **Testing**: Verifying that a source is executed exactly once.
  /// - **Debugging**: Tracking pulse flow through a shared stream.
  /// - **Monitoring**: Counting pulses for dashboards.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, the pulse is passed through unchanged.
  /// 3. The `seen` counter is incremented.
  /// 4. The pulse gets the step `'Share'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Pass-through**: Values are not modified or buffered.
  /// - **Counting**: The `seen` counter tracks typed pulses only.
  /// - **Type Safety**: Only payloads matching type [S] are counted.
  /// - **Multiple Observers**: Multiple observers share one subscription.
  /// - **No Replay**: Late subscribers do not receive past values.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the shared values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.share<int>(input.cell);
  ///
  /// // Multiple observers share one subscription
  /// final obs1 = Cell.observe(source: handle.cell, effect: (p) => {});
  /// final obs2 = Cell.observe(source: handle.cell, effect: (p) => {});
  /// ```
  ///
  /// ### See Also:
  /// - [shareReplay]: For sharing with a replay buffer.
  /// - [share]: For sharing only the latest value.
  static FlowHandle share<S>(Cell source) {
    return Share<S>().toHandle(source: source);
  }

  /// Share with a replay buffer.
  ///
  /// [shareReplay] maintains a buffer of configurable size containing
  /// the most recent values.
  ///
  /// ### When to use
  /// Use [shareReplay] when you need to access a window of recent values
  /// from a shared flow.
  ///
  /// - **History**: Showing a history of recent values.
  /// - **Audit Trail**: Tracking recent state changes.
  /// - **Undo/Redo**: Supporting undo of recent operations.
  /// - **Analytics**: Analyzing recent data points.
  /// - **Debugging**: Inspecting recent values.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. The payload is pushed into the buffer.
  /// 3. The buffer maintains a sliding window of [size] values.
  /// 4. The pulse is passed through unchanged.
  /// 5. The `buffer.values` getter provides access to buffered values.
  ///
  /// ### Non‑obvious
  /// - **Sliding Window**: The buffer maintains exactly [size] values.
  /// - **Size 0**: If size is 0, no values are retained.
  /// - **Mutable Buffer**: The buffer is mutable and shared.
  /// - **External Access**: The buffer is accessible externally.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [size]: **Buffer Size.** The number of values to retain.
  ///   Defaults to 1.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the shared values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.shareReplay<int>(
  ///   input.cell,
  ///   size: 3,
  /// );
  ///
  /// input.emit(1);
  /// input.emit(2);
  /// input.emit(3);
  /// input.emit(4);
  /// // Buffer contains `[2, 3, 4]`
  /// ```
  ///
  /// ### See Also:
  /// - [share]: For sharing without buffering.
  /// - [share]: For sharing only the latest value.
  static FlowHandle shareReplay<S>(
      Cell source, {
        int size = 1,
      }) {
    return ShareReplay<S>(size: size).toHandle(source: source);
  }

  /// Retry a failing inner.
  ///
  /// [retry] executes the [task] and retries it up to [count] times
  /// if it fails.
  ///
  /// ### When to use
  /// Use [retry] when you need a simple retry mechanism with a fixed
  /// number of attempts.
  ///
  /// - **Network Requests**: Retrying flaky API calls.
  /// - **Database Operations**: Retrying transient database errors.
  /// - **File I/O**: Retrying file operations that may fail temporarily.
  /// - **External Services**: Retrying calls to unreliable services.
  /// - **Rate Limiting**: Retrying after rate limit errors.
  /// - **Transient Failures**: Handling temporary failures gracefully.
  ///
  /// ### How it works
  /// 1. Each incoming pulse triggers the [task].
  /// 2. If the task succeeds, the result is emitted.
  /// 3. If the task fails, the error is caught.
  /// 4. The [count] determines how many retry attempts are made.
  /// 5. The task may run `count + 1` times total.
  /// 6. If [emitErrorPulse] is `true`, an error pulse is emitted
  ///    when all retries fail.
  ///
  /// ### Non‑obvious
  /// - **Total Attempts**: The task runs up to `count + 1` times.
  /// - **No Delay**: Retries are immediate.
  /// - **Error Swallowing**: Errors are caught and don't crash the flow.
  /// - **Error Pulse**: The error pulse has type `'error'` for routing.
  /// - **Provenance Preservation**: Success and error pulses preserve
  ///   the source cell, type, and priority from the trigger pulse.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [task]: **The Task to Execute.** Takes an input value and returns
  ///   a `FutureOr<T>` that may fail.
  /// - [count]: **Maximum Retry Attempts.** Defaults to 3.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
  ///   pulse when all retries fail. Defaults to `true`.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the input payload.
  /// - [T]: The type of the output payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the retried values.
  ///
  /// ### Example
  /// ```dart
  /// final userIds = Cell.ingress<int>();
  ///
  /// final handle = Flow.retry<int, UserProfile>(
  ///   userIds.cell,
  ///   task: (id) async => await api.getUser(id),
  ///   count: 3,
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [retry]: For conditional retry logic.
  /// - [retry]: For retries with a fixed delay.
  /// - [retry]: For retries with exponential backoff.
  static FlowHandle retry<S, T>(
      Cell source, {
        required RetryTask<S, T> task,
        int count = 3,
        RetryErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    return Retry<S, T>(
      task,
      count: count,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Executes a side effect [onValue] for every pulse without modifying the
  /// sequence (Rx `tap`).
  ///
  /// [tap] is the simplest side effect operator. It executes a callback
  /// for each typed pulse without modifying the pulse.
  ///
  /// ### When to use
  /// Use [tap] when you need to perform a side effect on each value
  /// without changing the stream.
  ///
  /// - **Logging**: Logging values as they flow through.
  /// - **Debugging**: Printing values for debugging.
  /// - **Analytics**: Tracking events for analytics.
  /// - **Metrics**: Collecting metrics on values.
  /// - **External Effects**: Triggering external side effects.
  /// - **Validation**: Validating values with side effects.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [onValue] is called with the payload.
  /// 3. If [onValue] throws an error, the pulse is dropped.
  /// 4. If [onValue] succeeds, the pulse is passed through unchanged.
  /// 5. The pulse gets the step `'Tap'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **Error Handling**: If [onValue] throws, the pulse is dropped.
  /// - **Pass-through**: The pulse is not modified.
  /// - **Type Safety**: Only typed payloads trigger the callback.
  /// - **Provenance Preservation**: The pulse gets the `'Tap'` step.
  /// - **Synchronous Callback**: [onValue] is synchronous.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [onValue]: **Side Effect Callback.** Called with each typed
  ///   payload. If it throws, the pulse is dropped.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the tapped values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<int>();
  ///
  /// final handle = Flow.tap<int>(
  ///   input.cell,
  ///   onValue: (value) => print('Value: $value'),
  /// );
  ///
  /// input.emit(42); // Prints: Value: 42
  /// ```
  ///
  /// ### See Also:
  /// - [tapAll]: For side effects on all pulses.
  /// - [tapWithIndex]: For indexed side effects.
  static FlowHandle tap<S>(
      Cell source, {
        required void Function(S value) onValue,
        TapErrorHandler? onError,
      }) {
    return Tap<S>(onValue, onError: onError).toHandle(source: source);
  }

  /// Tap every pulse, including wrong types.
  ///
  /// [tapAll] is similar to [tap] but the callback receives the full
  /// [Pulse] object, not just the payload.
  ///
  /// ### When to use
  /// Use [tapAll] when you need to perform side effects on every pulse,
  /// including those that don't match the expected type.
  ///
  /// - **Logging**: Logging all pulses including errors.
  /// - **Debugging**: Debugging pulse flow including type mismatches.
  /// - **Monitoring**: Monitoring all pulses for metrics.
  /// - **Auditing**: Auditing all pulses including invalid ones.
  /// - **Tracing**: Tracing pulse flow through the system.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is passed to [onPulse] directly.
  /// 2. No type checking is performed.
  /// 3. If [onPulse] throws an error, the pulse is dropped.
  /// 4. If [onPulse] succeeds, the pulse is passed through unchanged.
  /// 5. The pulse gets the step `'TapAll'` for provenance.
  ///
  /// ### Non‑obvious
  /// - **No Type Check**: The callback receives all pulses.
  /// - **Full Pulse Access**: The callback receives the full [Pulse] object.
  /// - **Error Handling**: If [onPulse] throws, the pulse is dropped.
  /// - **Provenance Preservation**: The pulse gets the `'TapAll'` step.
  /// - **Synchronous Callback**: [onPulse] is synchronous.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [onPulse]: **Side Effect Callback.** Called with each pulse.
  ///   If it throws, the pulse is dropped.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the tapped values.
  ///
  /// ### Example
  /// ```dart
  /// final input = Cell.ingress<Object>();
  ///
  /// final handle = Flow.tapAll(
  ///   input.cell,
  ///   onPulse: (pulse) => print('Pulse: ${pulse.payload}'),
  /// );
  ///
  /// input.emit(42); // Logs typed pulse
  /// input.emit('hello'); // Logs typed pulse
  /// ```
  ///
  /// ### See Also:
  /// - [tap]: For typed side effects.
  /// - [tapWithIndex]: For indexed side effects.
  static FlowHandle tapAll(
      Cell source, {
        required void Function(Pulse pulse) onPulse,
        TapErrorHandler? onError,
      }) {
    return TapAll(onPulse, onError: onError).toHandle(source: source);
  }

  /// Tap with a 0-based index.
  ///
  /// [tapWithIndex] is similar to [tap] but the callback receives the
  /// index of each value in the sequence.
  ///
  /// ### When to use
  /// Use [tapWithIndex] when you need the index of each value in your
  /// side effect.
  ///
  /// - **Position Tracking**: Tracking the position of values.
  /// - **Progress Reporting**: Reporting progress through a sequence.
  /// - **Index-Based Logging**: Logging with index information.
  /// - **Sequence Debugging**: Debugging sequence order.
  /// - **Batch Processing**: Tracking batch position.
  ///
  /// ### How it works
  /// 1. Each incoming pulse is type-checked.
  /// 2. If the type matches, [onValue] is called with the payload and index.
  /// 3. The index starts at 0 and increments on each typed pulse.
  /// 4. If [onValue] throws an error, the pulse is dropped.
  /// 5. If [onValue] succeeds, the pulse is passed through unchanged.
  /// 6. The index is incremented after the callback.
  ///
  /// ### Non‑obvious
  /// - **Index Type**: The index is a 0-based integer.
  /// - **Typed Only**: Only typed pulses increment the index.
  /// - **Error Handling**: If [onValue] throws, the pulse is dropped
  ///   and the index is not incremented.
  /// - **Provenance Preservation**: The pulse gets the `'TapWithIndex'` step.
  /// - **Synchronous Callback**: [onValue] is synchronous.
  ///
  /// ### Parameters:
  /// - [source]: **The Source Cell.** The cell providing the input values.
  /// - [onValue]: **Indexed Side Effect Callback.** Called with each
  ///   typed payload and its index. If it throws, the pulse is dropped.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  ///
  /// ### Type Parameters:
  /// - [S]: The type of the payload.
  ///
  /// ### Returns:
  /// A [FlowHandle] that can be used to observe the tapped values.
  ///
  /// ### Example
  /// ```dart
  /// final items = Cell.ingress<Item>();
  ///
  /// final handle = Flow.tapWithIndex<Item>(
  ///   items.cell,
  ///   onValue: (item, index) {
  ///     print('Processing item ${index + 1}');
  ///   },
  /// );
  /// ```
  ///
  /// ### See Also:
  /// - [tap]: For simple side effects.
  /// - [tapAll]: For side effects on all pulses.
  static FlowHandle tapWithIndex<S>(
      Cell source, {
        required void Function(S value, int index) onValue,
        TapErrorHandler? onError,
      }) {
    return TapWithIndex<S>(onValue, onError: onError).toHandle(source: source);
  }
}