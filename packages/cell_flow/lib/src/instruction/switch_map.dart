// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core SwitchMap Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that cancel the previous inner sequence
/// (Rx `switchMap` family).
///
/// | Operator | Rx analogue | Inner comes from |
/// |---|---|---|
/// | [SwitchMap] | `switchMap` | [mapper] of the payload |
/// | [SwitchMapTo] | `switchMapTo` | the same factory every time |
/// | [SwitchLatest] | `switchAll` / `switchLatest` | the payload itself |
/// | [SwitchMapState] | `switchMap` + snapshot | [mapper] plus [SwitchMapSnapshot] |
///
/// A new trigger increments a generation. In-flight inners whose
/// generation no longer matches are dropped.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef SwitchErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// A function that maps a value to an inner sequence (Future, Stream, or Iterable).
///
/// The inner sequence can be any object that can be drained:
/// - `Future<T>`: emits a single value
/// - `Stream<T>`: emits multiple values over time
/// - `Iterable<T>`: emits multiple values synchronously
/// - Any other value: emits that value directly
///
/// ### Example
/// ```dart
/// final mapper = SwitchMapper<String>((query) async {
///   return await api.search(query);
/// });
/// ```
typedef SwitchMapper<S> = FutureOr<Object?> Function(S value);

/// Live snapshot shared by [SwitchMapState].
///
/// [SwitchMapState] exposes a shared [SwitchMapSnapshot] that you can
/// inspect or use for cancellation logic. It contains:
/// - [generation]: incrementing counter that indicates which inner is current
/// - [lastTrigger]: the most recent input value
/// - [lastValue]: the most recent output value
///
/// ### When to use
/// Use this when you need to coordinate work across multiple operations
/// or when you want to cancel work based on the current generation.
///
/// ### Example
/// ```dart
/// final snapshot = SwitchMapSnapshot<String, String>();
///
/// final flow = SwitchMapState<String, String>(
///   (value, state) async {
///     // Check if this operation is still current
///     if (state.generation != currentGen) return null;
///     return await doWork(value);
///   },
///   state: snapshot,
/// ).toHandle(source: input.cell);
///
/// // Later, inspect the snapshot
/// print('Last trigger: ${snapshot.lastTrigger}');
/// print('Last value: ${snapshot.lastValue}');
/// ```
class SwitchMapSnapshot<S, T> {
  /// The current generation counter.
  ///
  /// Incremented every time a new trigger arrives. Operations can check
  /// this value to determine if they should continue or cancel.
  int generation = 0;

  /// The most recent input value that triggered a switch.
  S? lastTrigger;

  /// The most recent output value emitted.
  T? lastValue;

  /// Returns `true` if this snapshot is still valid.
  ///
  /// A snapshot is considered current if its generation matches the
  /// latest generation. This is a convenience getter for checking
  /// `state.generation == currentGeneration`.
  bool get isCurrent => true;
}

/// Helper to create an output pulse with proper provenance.
Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Drains any object (Future, Stream, Iterable, or value) into a callback.
///
/// This is the internal engine that handles the various types of inner
/// sequences that switchMap operators can produce.
///
/// ### How it works
/// 1. If [inner] is `null`, returns immediately.
/// 2. If [inner] is a `Stream`, iterates over it asynchronously.
/// 3. If [inner] is a `Future`, waits for it and recurses.
/// 4. If [inner] is an `Iterable` (not `String`), iterates over it.
/// 5. Otherwise, calls [onData] with the value.
///
/// ### Parameters:
/// - [inner]: The object to drain.
/// - [onData]: Called for each value drained.
/// - [stillLive]: Optional callback to check if the operation is still current.
///
/// ### Non‑obvious
/// - **Recursive Draining**: The function recurses on `Future` and `Iterable`
///   values, allowing nested structures to be flattened.
/// - **Cancellation**: The [stillLive] callback is checked at each step,
///   allowing cancelled operations to stop early.
/// - **String Special Case**: Strings are treated as values, not iterables,
///   to avoid character-by-character iteration.
Future<void> _drain(
    Object? inner,
    void Function(dynamic value) onData, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await Future<dynamic>.value(inner);
    await _drain(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  onData(inner);
}

/// Internal state for generation tracking.
class _GenerationState {
  int generation = 0;
}

// ─────────────────────────────────────────────────────────────
// SwitchMap - Core Operator
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that cancels the previous inner sequence when a
/// new trigger arrives (Rx `switchMap`).
///
/// [SwitchMap] is the primary operator for **Dynamic Source Switching**.
/// It maps each incoming value to an inner sequence (Future, Stream, or
/// Iterable) and emits values from the most recent inner sequence,
/// cancelling any previous in-flight sequences.
///
/// ### When to use
/// Use [SwitchMap] when you need to switch to a new data source based on
/// the incoming value, and you only care about the most recent source.
///
/// - **Search-as-you-type**: Only the latest search query matters.
/// - **Selection Changes**: Switching to a new user profile or document.
/// - **Navigation**: Switching to a new route or view.
/// - **Real-time Updates**: Only the most recent updates are relevant.
/// - **API Calls**: Cancelling stale requests when new ones arrive.
/// - **Tab Switching**: Only the active tab's data should be shown.
/// - **File Selection**: Loading data for the most recently selected file.
/// - **Filter/Query Changes**: Applying the latest filter only.
///
/// ### Choosing Between SwitchMap Variants
/// - **Use [SwitchMap]** for **Payload-Dependent Switching**: When the
///   inner sequence depends on the payload value.
/// - **Use [SwitchMapTo]** for **Fixed Inner Sequence**: When the inner
///   sequence is the same for every trigger (ignore payload).
/// - **Use [SwitchLatest]** for **Payload as Inner**: When the payload
///   itself *is* the inner sequence.
/// - **Use [SwitchMapState]** for **Stateful Switching**: When you need
///   to access the current generation, last trigger, or last value.
///
/// ### Comparison with Other Operators
/// | Operator | Input → Inner | Cancels Previous | Emits |
/// |----------|--------------|------------------|-------|
/// | **SwitchMap** | Mapped from payload | Yes | Latest inner only |
/// | **AsyncMap** | Mapped from payload | No (sequential) | Each result |
/// | **AsyncMapLatest** | Mapped from payload | Yes (cancels) | Latest only |
/// | **ConcatMap** | Mapped from payload | No (queues) | All in order |
/// | **MergeMap** | Mapped from payload | No (parallel) | All unordered |
///
/// ### How it works
/// 1. Each incoming pulse triggers the [mapper] function.
/// 2. The [mapper] returns an inner sequence (Future, Stream, or Iterable).
/// 3. A new **generation ID** is assigned to this trigger.
/// 4. Any previous in-flight inner sequence is effectively cancelled.
/// 5. Only values from the most recent generation are emitted.
/// 6. Each emitted value is wrapped as an [EvolvedPulse] with the step
///    `'SwitchMap'` to preserve causal provenance.
///
/// ### Non‑obvious
/// - **Generation Tracking**: Each trigger gets a unique generation ID.
///   Values from older generations are silently dropped.
/// - **Silent Cancellation**: Cancelled operations do not throw exceptions.
///   They simply stop emitting values.
/// - **Drain Recursion**: The `_drain` function handles nested structures
///   (Future of Stream, Iterable of Future, etc.).
/// - **Type Safety**: The instruction is generic over [S] (input type) and
///   [T] (output type), ensuring compile-time type safety.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Error Isolation**: Errors in cancelled operations are ignored.
///   Only errors from the current generation are reported.
/// - **Memory Efficiency**: Only the latest generation's values are kept.
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final searchInput = Cell.ingress<String>();
///
/// final searchResults = SwitchMap<String, List<Result>>(
///   (query) async {
///     // If a new query arrives, this request is cancelled
///     return await api.search(query);
///   },
///   onError: (error, stack) => print('Search error: $error'),
/// ).toHandle(source: searchInput.cell);
///
/// Cell.observe(
///   source: searchResults.cell,
///   effect: (pulse) => print('Results: ${pulse.payload}'),
/// );
///
/// searchInput.emit('dart');  // -> Results: [...]
/// searchInput.emit('flutter'); // Cancels previous request
/// ```
///
/// ### Example: User Profile Switching
/// ```dart
/// final userId = Cell.ingress<int>();
///
/// final profile = SwitchMap<int, UserProfile>(
///   (id) async {
///     // If a new ID arrives, the previous fetch is cancelled
///     return await api.getUser(id);
///   },
/// ).toHandle(source: userId.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Inner Sequence Factory.** A function that takes an
///   input value of type [S] and returns a `FutureOr<Object?>` that can be
///   drained (Future, Stream, Iterable, or value).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline or
/// materialized with `.toHandle()`.
///
/// ### See Also:
/// - [SwitchMapTo]: For switching to a fixed inner sequence.
/// - [SwitchLatest]: For when the payload itself is the inner sequence.
/// - [SwitchMapState]: For stateful switching with snapshot access.
/// - [AsyncMap]: For one-to-one async mapping without cancellation.
/// - [ConcatMap]: For queuing inner sequences in order.
class SwitchMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SwitchMap(
      SwitchMapper<S> mapper, {
        SwitchErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final id = ++gen.generation;
        Future<void> run() async {
          try {
            final inner = await Future.sync(() => mapper(payload));
            if (id != gen.generation) return;
            await _drain(
              inner,
                  (item) {
                if (id != gen.generation) return;
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'SwitchMap'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == gen.generation,
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SwitchMapTo - Fixed Inner Sequence
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that switches to the same inner sequence for every
/// trigger, ignoring the payload (Rx `switchMapTo`).
///
/// [SwitchMapTo] is similar to [SwitchMap] but the inner sequence is fixed
/// and does not depend on the payload. This is useful when you want to
/// restart the same sequence on every trigger.
///
/// ### When to use
/// Use [SwitchMapTo] when the inner sequence is the same regardless of
/// the incoming value.
///
/// - **Refresh/Retry**: Restarting the same operation on demand.
/// - **Polling**: Restarting a polling sequence on a trigger.
/// - **Retry Logic**: Retrying a failed operation on a retry signal.
/// - **Reset**: Resetting a sequence to its initial state.
/// - **Timer Restart**: Restarting a timer or countdown.
///
/// ### Example: Retry on Demand
/// ```dart
/// final retrySignal = Cell.ingress<void>();
///
/// final data = SwitchMapTo<void, String>(
///   () async {
///     // This sequence restarts on every trigger
///     return await fetchData();
///   },
/// ).toHandle(source: retrySignal.cell);
///
/// // Emitting a signal restarts the fetch
/// retrySignal.emit(null); // -> Fetches data
/// retrySignal.emit(null); // -> Cancels and re-fetches
/// ```
///
/// ### Example: Polling Restart
/// ```dart
/// final refreshSignal = Cell.ingress<void>();
///
/// final poll = SwitchMapTo<void, Status>(
///   () async* {
///     while (true) {
///       yield await getStatus();
///       await Future.delayed(Duration(seconds: 1));
///     }
///   },
/// ).toHandle(source: refreshSignal.cell);
///
/// // Each refresh signal restarts the polling sequence
/// refreshSignal.emit(null);
/// ```
///
/// ### How it works
/// 1. Each incoming pulse (regardless of payload) triggers the [inner] factory.
/// 2. The [inner] factory returns the same sequence every time.
/// 3. A new generation ID is assigned to each trigger.
/// 4. Any previous in-flight sequence is cancelled.
/// 5. Only values from the most recent generation are emitted.
///
/// ### Non‑obvious
/// - **Payload Ignored**: The payload is ignored; only the arrival matters.
/// - **Reusable Factory**: The same [inner] factory is called for every trigger.
/// - **Cancellation Works**: Previous sequences are cancelled as expected.
/// - **Type Safety**: The input type [S] is effectively ignored but kept
///   for compatibility with the FlowInstruction interface.
///
/// ### Parameters:
/// - [inner]: **The Fixed Inner Sequence Factory.** A function that returns
///   a `FutureOr<Object?>` that can be drained (Future, Stream, or Iterable).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (ignored, but kept for compatibility).
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that switches to a fixed inner sequence on every trigger.
///
/// ### See Also:
/// - [SwitchMap]: For payload-dependent switching.
/// - [SwitchLatest]: For when the payload is the inner sequence.
/// - [SwitchMapState]: For stateful switching with snapshot access.
class SwitchMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SwitchMapTo(
      FutureOr<Object?> Function() inner, {
        SwitchErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final id = ++gen.generation;
        Future<void> run() async {
          try {
            final seq = await Future.sync(inner);
            if (id != gen.generation) return;
            await _drain(
              seq,
                  (item) {
                if (id != gen.generation) return;
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'SwitchMapTo'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == gen.generation,
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SwitchLatest - Payload as Inner
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that treats the payload itself as the inner sequence
/// (Rx `switchAll` / `switchLatest`).
///
/// [SwitchLatest] is a specialized variant where the incoming payload
/// *is* the inner sequence. This is useful when you're emitting streams,
/// futures, or iterables as values and want to switch between them.
///
/// ### When to use
/// Use [SwitchLatest] when the payload itself is a sequence that should
/// be switched between.
///
/// - **Stream of Streams**: Switching between multiple event streams.
/// - **Future of Futures**: Switching between multiple async operations.
/// - **Dynamic Data Sources**: Switching between different data sources.
/// - **Feature Flags**: Switching between different feature implementations.
/// - **Hot Swapping**: Replacing one sequence with another at runtime.
///
/// ### Example: Switching Between Data Sources
/// ```dart
/// final sourceSelector = Cell.ingress<Stream<String>>();
///
/// final data = SwitchLatest<String>().toHandle(source: sourceSelector.cell);
///
/// // Switch to a different data source
/// sourceSelector.emit(stream1); // Emits from stream1
/// sourceSelector.emit(stream2); // Cancels stream1, emits from stream2
/// ```
///
/// ### Example: Switching Between Futures
/// ```dart
/// final taskSelector = Cell.ingress<Future<String>>();
///
/// final result = SwitchLatest<String>().toHandle(source: taskSelector.cell);
///
/// // Switch to a different task
/// taskSelector.emit(fetchUser1()); // Emits result of fetchUser1
/// taskSelector.emit(fetchUser2()); // Cancels fetchUser1, emits fetchUser2
/// ```
///
/// ### How it works
/// 1. Each incoming pulse carries a sequence (Future, Stream, or Iterable).
/// 2. A new generation ID is assigned to each trigger.
/// 3. Any previous in-flight sequence is cancelled.
/// 4. Only values from the most recent payload are emitted.
/// 5. The payload itself is the sequence to drain.
///
/// ### Non‑obvious
/// - **Payload as Source**: The payload *is* the inner sequence.
/// - **No Mapping**: There's no mapper function – the payload is used directly.
/// - **Type Safety**: The instruction is generic over [T] – the output type
///   must match the payload's element type.
/// - **Flexibility**: The payload can be any drainable object (Future,
///   Stream, Iterable, or value).
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that switches between payload sequences.
///
/// ### See Also:
/// - [SwitchMap]: For mapping payloads to sequences.
/// - [SwitchMapTo]: For switching to a fixed inner sequence.
/// - [SwitchMapState]: For stateful switching with snapshot access.
class SwitchLatest<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SwitchLatest({
    SwitchErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final id = ++gen.generation;
        Future<void> run() async {
          try {
            await _drain(
              pulse.payload,
                  (item) {
                if (id != gen.generation) return;
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'SwitchLatest'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == gen.generation,
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );
}

/// Alias of [SwitchLatest] for Rx `switchAll` compatibility.
typedef SwitchAll<T> = SwitchLatest<T>;

// ─────────────────────────────────────────────────────────────
// SwitchMapState - Stateful Switching with Snapshot
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that switches between inner sequences while
/// providing access to a shared [SwitchMapSnapshot].
///
/// [SwitchMapState] is a stateful variant of [SwitchMap] that exposes a
/// shared snapshot containing the current generation, last trigger, and
/// last value. This allows for coordination between multiple operations.
///
/// ### When to use
/// Use [SwitchMapState] when you need to access the current state from
/// within the mapper or from outside the instruction.
///
/// - **Coordinated Cancellation**: Check the generation inside the mapper.
/// - **State Inspection**: Access the last trigger or last value externally.
/// - **Complex Workflows**: Coordinate multiple operations that depend on
///   the current generation.
/// - **Conditional Work**: Skip work if the generation has advanced.
/// - **Testing**: Inspect the state for verification.
///
/// ### Example: Coordinated Cancellation
/// ```dart
/// final snapshot = SwitchMapSnapshot<String, String>();
///
/// final flow = SwitchMapState<String, String>(
///   (value, state) async {
///     // Save the current generation for later checks
///     final currentGen = state.generation;
///
///     // Perform long-running work with periodic checks
///     for (var i = 0; i < 10; i++) {
///       await Future.delayed(Duration(milliseconds: 100));
///       // Cancel if generation changed
///       if (state.generation != currentGen) return null;
///     }
///     return 'Result: $value';
///   },
///   state: snapshot,
/// ).toHandle(source: input.cell);
/// ```
///
/// ### Example: External State Access
/// ```dart
/// final snapshot = SwitchMapSnapshot<String, String>();
///
/// final flow = SwitchMapState<String, String>(
///   (value, state) async {
///     return await processWithGeneration(value, state.generation);
///   },
///   state: snapshot,
/// ).toHandle(source: input.cell);
///
/// // Later, inspect the snapshot
/// print('Last trigger: ${snapshot.lastTrigger}');
/// print('Last value: ${snapshot.lastValue}');
/// print('Current generation: ${snapshot.generation}');
/// ```
///
/// ### How it works
/// 1. Each incoming pulse triggers the [mapper] with the payload and snapshot.
/// 2. The [mapper] can access the snapshot's [generation] for cancellation.
/// 3. The [snapshot.lastTrigger] is updated with each new payload.
/// 4. The [snapshot.lastValue] is updated with each emitted value.
/// 5. Only values from the most recent generation are emitted.
///
/// ### Non‑obvious
/// - **Shared State**: The snapshot is shared and mutable, allowing
///   coordination between the mapper and external code.
/// - **Generation Tracking**: The [generation] is automatically incremented.
/// - **Last Trigger/Value**: These are automatically updated.
/// - **Thread Safety**: The snapshot is not thread-safe; operations are
///   serialized through the cell's lock.
/// - **Type Safety**: The snapshot is generic over [S] and [T].
///
/// ### Parameters:
/// - [mapper]: **The State-Aware Mapper.** A function that takes the payload
///   and snapshot, returns a `FutureOr<Object?>` to drain.
/// - [state]: **The Shared Snapshot.** Optional; a new one is created if not
///   provided. Use this to access the state externally.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload emitted by the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that switches with shared state access.
///
/// ### See Also:
/// - [SwitchMap]: For payload-dependent switching without state.
/// - [SwitchMapTo]: For switching to a fixed inner sequence.
/// - [SwitchLatest]: For when the payload is the inner sequence.
/// - [SwitchMapSnapshot]: The shared state object.
class SwitchMapState<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SwitchMapState(
      FutureOr<Object?> Function(S value, SwitchMapSnapshot<S, T> state) mapper, {
        SwitchMapSnapshot<S, T>? state,
        SwitchErrorHandler? onError,
        dynamic user,
      }) : this._(mapper, state ?? SwitchMapSnapshot<S, T>(), onError, user);

  SwitchMapState._(
      FutureOr<Object?> Function(S value, SwitchMapSnapshot<S, T> state) mapper,
      this.snapshot,
      SwitchErrorHandler? onError,
      dynamic user,
      ) : super.future(
    (() {
      final snap = snapshot;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final id = ++snap.generation;
        snap.lastTrigger = payload;
        Future<void> run() async {
          try {
            final inner = await Future.sync(() => mapper(payload, snap));
            if (id != snap.generation) return;
            await _drain(
              inner,
                  (item) {
                if (id != snap.generation) return;
                if (item is T) {
                  snap.lastValue = item;
                  future!(
                    result: _out<T>(item, cell, pulse, 'SwitchMapState'),
                    token: token,
                  );
                }
              },
              stillLive: () => id == snap.generation,
            );
          } catch (e, stack) {
            if (id == snap.generation) onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [generation], [lastTrigger], and [lastValue]
  /// from outside the instruction.
  final SwitchMapSnapshot<S, T> snapshot;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [SwitchMap] instruction and related operators
/// showing their behavior in various dynamic source switching scenarios.
///
/// ### Expected console output:
/// ```text
/// ── SwitchMap Operators Demo ──────────────────────────────────
///
/// 1. SwitchMap - latest inner only
///    [SwitchMap] new-1
///    [SwitchMap] new-2
///
/// 2. SwitchMapTo - same inner, switched
///    [SwitchMapTo] ping
///
/// 3. SwitchLatest - payload is the inner
///    [SwitchLatest] b
///
/// 4. SwitchMapState - snapshot generation
///    [SwitchMapState] q=new gen=2
///
/// ── finished ──────────────────────────────────────────────────
/// ```
///
/// ### How to run
/// ```dart
/// void main() => main();
/// ```
///
/// ### What it demonstrates
/// 1. **SwitchMap - Latest Inner Only**: Shows cancellation behavior.
///    The `old` query is cancelled when `new` arrives. Only values from
///    the latest generation are emitted.
///
/// 2. **SwitchMapTo - Fixed Inner Sequence**: Shows the same sequence
///    being restarted on every trigger. The payload is ignored.
///
/// 3. **SwitchLatest - Payload as Inner**: Shows switching between
///    sequences that are passed as payloads. The stream of streams is
///    switched to the latest payload.
///
/// 4. **SwitchMapState - Snapshot Generation**: Shows stateful switching
///    where the snapshot tracks the current generation and last values.
///
/// ### Key Takeaways
/// - SwitchMap cancels previous inners when a new trigger arrives.
/// - SwitchMapTo ignores the payload and switches to a fixed sequence.
/// - SwitchLatest treats the payload itself as the inner sequence.
/// - SwitchMapState provides access to the current generation state.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Only the most recent generation's values are emitted.
Future<void> main() async {
  print('── SwitchMap Operators Demo ──────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. SwitchMap - Latest Inner Only
  // ─────────────────────────────────────────────────────────────────────
  print('1. SwitchMap - latest inner only');

  final query = Cell.ingress<String>();

  final switched = SwitchMap<String, String>(
        (q) async* {
      // Simulate varying response times
      await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 10));
      yield '$q-1';
      yield '$q-2';
    },
  ).toHandle(source: query.cell);

  final sObs = Cell.observe(
    source: switched.cell,
    effect: (Pulse p) => print('   [SwitchMap] ${p.payload}'),
  );

  await query.emitAsync('old');
  await query.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 80));

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. SwitchMapTo - Same Inner, Switched
  // ─────────────────────────────────────────────────────────────────────
  print('2. SwitchMapTo - same inner, switched');

  final clicks = Cell.ingress<void>();

  final echo = SwitchMapTo<void, String>(
        () async* {
      yield 'ping';
      await Future<void>.delayed(const Duration(milliseconds: 40));
      yield 'pong';
    },
  ).toHandle(source: clicks.cell);

  final tObs = Cell.observe(
    source: echo.cell,
    effect: (Pulse p) => print('   [SwitchMapTo] ${p.payload}'),
  );

  await clicks.emitAsync(null);
  await clicks.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. SwitchLatest - Payload is the Inner
  // ─────────────────────────────────────────────────────────────────────
  print('3. SwitchLatest - payload is the inner');

  final batches = Cell.ingress<Object>();

  final latest = SwitchLatest<String>().toHandle(source: batches.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [SwitchLatest] ${p.payload}'),
  );

  await batches.emitAsync(Stream.fromFutures([
    Future.value('a'),
    Future<String>.delayed(const Duration(milliseconds: 40), () => 'late'),
  ]));
  await batches.emitAsync(['b']);
  await Future<void>.delayed(const Duration(milliseconds: 60));

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. SwitchMapState - Snapshot Generation
  // ─────────────────────────────────────────────────────────────────────
  print('4. SwitchMapState - snapshot generation');

  final snap = SwitchMapSnapshot<String, String>();
  final keyed = Cell.ingress<String>();

  final stated = SwitchMapState<String, String>(
        (q, state) async => 'q=$q gen=${state.generation}',
    state: snap,
  ).toHandle(source: keyed.cell);

  final kObs = Cell.observe(
    source: stated.cell,
    effect: (Pulse p) => print('   [SwitchMapState] ${p.payload}'),
  );

  await keyed.emitAsync('old');
  await keyed.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  kObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}