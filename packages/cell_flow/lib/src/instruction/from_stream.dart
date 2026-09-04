// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core FromStream Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that bridge [Stream]s into the Cell graph
/// (Rx `from(Stream)` / `fromEventPattern` family).
///
/// [Cell.fromStream] is the standalone source. These instructions start
/// when the bound handle is pulsed.
///
/// | Operator | Starts | Emits |
/// |---|---|---|
/// | [FromStream] | first trigger | every event, one subscription |
/// | [DeferStream] | every trigger | a new stream each time |
/// | [ConcatFromStream] | queued | events in trigger order |
/// | [MergeFromStream] | parallel | events as they arrive |
/// | [SwitchFromStream] | latest | current stream only |
/// | [MapToStream] | typed payload | mapped stream events |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for fromStream operators.
///
/// Called when an error occurs during stream operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = StreamErrorHandler((error, stack) {
///   print('Stream error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef StreamErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper to create a success pulse with proper provenance.
Pulse<S> _ok<S>(S value, Cell? cell, Pulse trigger, String step) {
  return Pulse<S>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Helper to create an error pulse with proper provenance.
Pulse _err(Object error, Cell? cell, Pulse trigger, String step) {
  return Pulse(
    error,
    source: cell ?? trigger.source,
    type: 'error',
    priority: trigger.priority,
    step: step,
  );
}

/// Helper to handle failure with error reporting.
///
/// [_fail] centralizes error handling for stream operators.
/// It reports the error via [onError] and optionally emits an error pulse.
///
/// ### Parameters:
/// - [error]: The error that occurred.
/// - [stack]: The stack trace.
/// - [onError]: Error handler callback.
/// - [emitErrorPulse]: Whether to emit an error pulse.
/// - [future]: The continuation callback.
/// - [token]: The continuation token.
/// - [cell]: The host cell.
/// - [trigger]: The trigger pulse.
/// - [step]: The provenance step for the error pulse.
void _fail({
  required Object error,
  StackTrace? stack,
  required StreamErrorHandler? onError,
  required bool emitErrorPulse,
  required void Function({required Pulse? result, required dynamic token})? future,
  required dynamic token,
  required Cell? cell,
  required Pulse trigger,
  required String step,
}) {
  onError?.call(error, stack);
  if (emitErrorPulse && future != null) {
    future(result: _err(error, cell, trigger, step), token: token);
  }
}

// ─────────────────────────────────────────────────────────────
// FromStream - Single Stream Subscription
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that subscribes to [source] on the first
/// trigger (Rx `from(Stream)`).
///
/// [FromStream] bridges a Dart [Stream] into the reactive graph.
/// It starts listening to the stream on the first trigger pulse and
/// emits each event as a pulse.
///
/// ### When to use
/// Use [FromStream] when you want to bridge an existing Stream
/// into the Cell graph.
///
/// - **External Events**: Bridging external event streams.
/// - **WebSocket**: Bridging WebSocket messages.
/// - **File Watchers**: Bridging file system events.
/// - **Timers**: Bridging periodic timers.
/// - **Third-Party SDKs**: Bridging SDK event streams.
/// - **Hardware Events**: Bridging hardware event streams.
///
/// ### Choosing Between FromStream Variants
/// - **Use [FromStream]** for **Single Subscription**: When you want
///   one subscription that starts on the first trigger.
/// - **Use [DeferStream]** for **New Subscription Each Time**: When
///   you want a new stream each trigger.
/// - **Use [ConcatFromStream]** for **Ordered Streams**: When you
///   want to play streams in order.
/// - **Use [MergeFromStream]** for **Concurrent Streams**: When you
///   want to listen to all streams at once.
/// - **Use [SwitchFromStream]** for **Latest Stream**: When you only
///   care about the latest stream.
/// - **Use [MapToStream]** for **Mapped Streams**: When you want to
///   map payloads to streams.
///
/// ### Comparison with Other Operators
/// | Operator | Subscription | Starts | Multiple |
/// |----------|--------------|--------|----------|
/// | **FromStream** | Single | First trigger | No |
/// | **DeferStream** | New each time | Each trigger | Yes |
/// | **ConcatFromStream** | Queued | Each trigger | Yes (queued) |
/// | **MergeFromStream** | Concurrent | Each trigger | Yes (parallel) |
/// | **SwitchFromStream** | Latest | Each trigger | No (cancels) |
/// | **MapToStream** | Mapped | Each trigger | Yes (queued) |
///
/// ### How it works
/// 1. The first trigger pulse arms the subscription.
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
/// - **Memory Management**: The subscription is managed automatically.
///
/// ### Example: Bridging a Timer Stream
/// ```dart
/// final arm = Cell.ingress<void>();
///
/// final tickStream = Stream.periodic(Duration(seconds: 1), (i) => i);
/// final ticks = FromStream<int>(tickStream).toHandle(source: arm.cell);
///
/// arm.emit(null); // Starts the timer
/// // Emits 0, 1, 2, ... every second
/// ```
///
/// ### Example: WebSocket Messages
/// ```dart
/// final connect = Cell.ingress<void>();
///
/// final messages = FromStream<String>(webSocket.stream)
///     .toHandle(source: connect.cell);
///
/// connect.emit(null); // Starts listening to WebSocket
/// ```
///
/// ### Parameters:
/// - [source]: **The Stream Source.** The stream to bridge into the
///   reactive graph.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true`, emits an error
///   pulse on stream error. Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that bridges a stream into the graph.
///
/// ### See Also:
/// - [DeferStream]: For creating a new stream on each trigger.
/// - [ConcatFromStream]: For playing streams in order.
/// - [MergeFromStream]: For listening to streams in parallel.
/// - [SwitchFromStream]: For switching to the latest stream.
/// - [MapToStream]: For mapping payloads to streams.
class FromStream<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  FromStream(
      Stream<S> source, {
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      var started = false;
      return (pulse, {cell, user, future, token}) {
        if (started) return null;
        started = true;
        Future<void> run() async {
          try {
            await for (final event in source) {
              future!(
                result: _ok<S>(event, cell, pulse, 'FromStream'),
                token: token,
              );
            }
          } catch (e, stack) {
            _fail(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'FromStream.error',
            );
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
// DeferStream - New Stream Each Trigger
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that creates a new stream on each trigger
/// (Rx `defer(() => from(stream))`).
///
/// [DeferStream] is similar to [FromStream] but creates a new stream
/// subscription on each trigger pulse.
///
/// ### When to use
/// Use [DeferStream] when you need a fresh stream on each trigger.
///
/// - **Lazy Initialization**: Creating streams lazily on demand.
/// - **Fresh State**: Getting fresh state from a stream each time.
/// - **Per-Trigger**: Different streams for different triggers.
/// - **Resource Management**: Managing stream resources per trigger.
/// - **Dynamic Sources**: Creating streams dynamically.
///
/// ### Example: Deferred Stream
/// ```dart
/// final trigger = Cell.ingress<void>();
///
/// final deferred = DeferStream<int>(
///   () => Stream.periodic(Duration(seconds: 1), (i) => i).take(3),
/// ).toHandle(source: trigger.cell);
///
/// trigger.emit(null); // Creates and listens to a new stream
/// trigger.emit(null); // Creates and listens to a new stream
/// ```
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
/// - **Provenance Preservation**: Each emitted event preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Memory Management**: Each stream is managed independently.
///
/// ### Parameters:
/// - [create]: **Stream Factory.** Called on each trigger to create
///   a new stream.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that creates a new stream on each trigger.
///
/// ### See Also:
/// - [FromStream]: For a single stream subscription.
/// - [ConcatFromStream]: For playing streams in order.
/// - [MergeFromStream]: For listening to streams in parallel.
/// - [SwitchFromStream]: For switching to the latest stream.
class DeferStream<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DeferStream(
      Stream<S> Function() create, {
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void> run() async {
        try {
          await for (final event in create()) {
            future!(
              result: _ok<S>(event, cell, pulse, 'DeferStream'),
              token: token,
            );
          }
        } catch (e, stack) {
          _fail(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'DeferStream.error',
          );
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ConcatFromStream - Ordered Stream Concatenation
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where each trigger payload is treated as a
/// [Stream] and played in order.
///
/// [ConcatFromStream] queues streams from trigger payloads and plays
/// them one after another.
///
/// ### When to use
/// Use [ConcatFromStream] when you have streams as payloads and want
/// to play them in order.
///
/// - **Stream of Streams**: Concatenating a stream of streams.
/// - **Ordered Processing**: Processing streams in order.
/// - **Queue Management**: Managing a queue of streams.
/// - **Sequential Streaming**: Streaming data sequentially.
/// - **Resource Management**: Managing stream resources sequentially.
///
/// ### Example: Stream of Streams
/// ```dart
/// final streams = Cell.ingress<Stream<int>>();
///
/// final concat = ConcatFromStream<int>().toHandle(source: streams.cell);
///
/// streams.emit(Stream.fromIterable([1, 2])); // -> 1, 2
/// streams.emit(Stream.fromIterable([3]));    // -> 3
/// // Outputs: 1, 2, 3
/// ```
///
/// ### How it works
/// 1. Each trigger payload must be a `Stream<S>`.
/// 2. Streams are queued and played one after another.
/// 3. All events from each stream are emitted.
/// 4. If a stream errors, an error pulse is emitted.
/// 5. Each emitted event gets the step `'ConcatFromStream'` for provenance.
///
/// ### Non‑obvious
/// - **Payload Must Be Stream**: The payload must be a `Stream<S>`.
/// - **Ordered**: Streams are played in arrival order.
/// - **Queueing**: Streams are queued while playing.
/// - **Error Handling**: Stream errors are caught and reported.
/// - **Provenance Preservation**: Each emitted event preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that concatenates streams in order.
///
/// ### See Also:
/// - [FromStream]: For a single stream subscription.
/// - [DeferStream]: For creating a new stream on each trigger.
/// - [MergeFromStream]: For listening to streams in parallel.
/// - [SwitchFromStream]: For switching to the latest stream.
class ConcatFromStream<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatFromStream({
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
    dynamic user,
  }) : super.future(
    (() {
      final queue = <Stream<S>>[];
      var busy = false;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! Stream<S>) {
          _fail(
            error: FormatException(
              'Expected Stream<$S>, got ${payload.runtimeType}',
            ),
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'ConcatFromStream.error',
          );
          return null;
        }
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final stream = queue.removeAt(0);
            try {
              await for (final event in stream) {
                future!(
                  result: _ok<S>(event, cell, pulse, 'ConcatFromStream'),
                  token: token,
                );
              }
            } catch (e, stack) {
              _fail(
                error: e,
                stack: stack,
                onError: onError,
                emitErrorPulse: emitErrorPulse,
                future: future,
                token: token,
                cell: cell,
                trigger: pulse,
                step: 'ConcatFromStream.error',
              );
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// MergeFromStream - Concurrent Stream Listening
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that subscribes to every trigger stream at once.
///
/// [MergeFromStream] listens to all streams from trigger payloads
/// concurrently, emitting events as they arrive.
///
/// ### When to use
/// Use [MergeFromStream] when you have streams as payloads and want
/// to listen to them all at once.
///
/// - **Concurrent Streaming**: Listening to multiple streams in parallel.
/// - **Stream of Streams**: Merging a stream of streams.
/// - **Parallel Processing**: Processing streams concurrently.
/// - **Real-time Aggregation**: Aggregating events from multiple streams.
/// - **Event Collection**: Collecting events from multiple sources.
///
/// ### Example: Concurrent Streams
/// ```dart
/// final streams = Cell.ingress<Stream<int>>();
///
/// final merged = MergeFromStream<int>().toHandle(source: streams.cell);
///
/// streams.emit(Stream.periodic(Duration(milliseconds: 10), (i) => 1));
/// streams.emit(Stream.periodic(Duration(milliseconds: 15), (i) => 2));
/// // Emits events from both streams as they arrive
/// ```
///
/// ### How it works
/// 1. Each trigger payload must be a `Stream<S>`.
/// 2. All streams are listened to concurrently.
/// 3. Events are emitted as they arrive from any stream.
/// 4. If a stream errors, an error pulse is emitted.
/// 5. Each emitted event gets the step `'MergeFromStream'` for provenance.
///
/// ### Non‑obvious
/// - **Payload Must Be Stream**: The payload must be a `Stream<S>`.
/// - **Concurrent**: All streams are listened to in parallel.
/// - **Unordered**: Events are emitted in arrival order.
/// - **Error Handling**: Stream errors are caught and reported.
/// - **Provenance Preservation**: Each emitted event preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that merges streams concurrently.
///
/// ### See Also:
/// - [FromStream]: For a single stream subscription.
/// - [DeferStream]: For creating a new stream on each trigger.
/// - [ConcatFromStream]: For playing streams in order.
/// - [SwitchFromStream]: For switching to the latest stream.
class MergeFromStream<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MergeFromStream({
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
    dynamic user,
  }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! Stream<S>) {
        _fail(
          error: FormatException(
            'Expected Stream<$S>, got ${payload.runtimeType}',
          ),
          onError: onError,
          emitErrorPulse: emitErrorPulse,
          future: future,
          token: token,
          cell: cell,
          trigger: pulse,
          step: 'MergeFromStream.error',
        );
        return null;
      }
      Future<void> run() async {
        try {
          await for (final event in payload) {
            future!(
              result: _ok<S>(event, cell, pulse, 'MergeFromStream'),
              token: token,
            );
          }
        } catch (e, stack) {
          _fail(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'MergeFromStream.error',
          );
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SwitchFromStream - Latest Stream Only
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where a new trigger stream cancels the
/// previous subscription (latest only).
///
/// [SwitchFromStream] switches to the latest stream, cancelling any
/// previous stream subscription.
///
/// ### When to use
/// Use [SwitchFromStream] when you only care about the latest stream.
///
/// - **Source Switching**: Switching between data sources.
/// - **Latest Data**: Only the most recent data source matters.
/// - **Hot Swapping**: Hot swapping data streams.
/// - **Real-time Updates**: Switching to the latest update stream.
/// - **Dynamic Selection**: Dynamically selecting a data source.
///
/// ### Example: Latest Stream
/// ```dart
/// final streams = Cell.ingress<Stream<String>>();
///
/// final switched = SwitchFromStream<String>().toHandle(source: streams.cell);
///
/// streams.emit(Stream.periodic(Duration(milliseconds: 10), (_) => 'old'));
/// streams.emit(Stream.fromIterable(['new']));
/// // Only 'new' is emitted (old stream is cancelled)
/// ```
///
/// ### How it works
/// 1. Each trigger payload must be a `Stream<S>`.
/// 2. The current stream subscription is cancelled.
/// 3. The new stream is listened to.
/// 4. Only events from the latest stream are emitted.
/// 5. Each emitted event gets the step `'SwitchFromStream'` for provenance.
///
/// ### Non‑obvious
/// - **Payload Must Be Stream**: The payload must be a `Stream<S>`.
/// - **Cancellation**: Previous streams are cancelled on new triggers.
/// - **Latest Only**: Only the latest stream emits events.
/// - **Generation Tracking**: Each stream gets a generation ID.
/// - **Error Handling**: Errors are reported only for the current stream.
/// - **Provenance Preservation**: Each emitted event preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that switches to the latest stream.
///
/// ### See Also:
/// - [FromStream]: For a single stream subscription.
/// - [DeferStream]: For creating a new stream on each trigger.
/// - [ConcatFromStream]: For playing streams in order.
/// - [MergeFromStream]: For listening to streams in parallel.
class SwitchFromStream<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SwitchFromStream({
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
    dynamic user,
  }) : super.future(
    (() {
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! Stream<S>) {
          _fail(
            error: FormatException(
              'Expected Stream<$S>, got ${payload.runtimeType}',
            ),
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'SwitchFromStream.error',
          );
          return null;
        }
        final id = ++generation;
        Future<void> run() async {
          try {
            await for (final event in payload) {
              if (id != generation) return;
              future!(
                result: _ok<S>(event, cell, pulse, 'SwitchFromStream'),
                token: token,
              );
            }
          } catch (e, stack) {
            if (id != generation) return;
            _fail(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'SwitchFromStream.error',
            );
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
// MapToStream - Map Payload to Stream
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maps a typed payload to a [Stream] and
/// flattens it sequentially.
///
/// [MapToStream] maps each typed payload to a stream and plays the
/// stream events sequentially.
///
/// ### When to use
/// Use [MapToStream] when you need to map payloads to streams and
/// play them in order.
///
/// - **Data Fetching**: Fetching data as streams from IDs.
/// - **Stream Transformation**: Transforming payloads to streams.
/// - **Lazy Loading**: Loading data lazily as streams.
/// - **Resource Management**: Managing stream resources.
/// - **Dynamic Streaming**: Creating streams dynamically from payloads.
///
/// ### Example: Mapping to Stream
/// ```dart
/// final ids = Cell.ingress<int>();
///
/// final data = MapToStream<int, String>(
///   (id) => Stream.fromIterable(['$id-1', '$id-2']),
/// ).toHandle(source: ids.cell);
///
/// ids.emit(1); // -> 1-1, 1-2
/// ids.emit(2); // -> 2-1, 2-2 (after first stream completes)
/// ```
///
/// ### How it works
/// 1. Each trigger payload is mapped to a stream.
/// 2. Streams are queued and played one after another.
/// 3. All events from each stream are emitted.
/// 4. If a stream errors, an error pulse is emitted.
/// 5. Each emitted event gets the step `'MapToStream'` for provenance.
///
/// ### Non‑obvious
/// - **Sequential**: Streams are played one after another.
/// - **Queueing**: Streams are queued while playing.
/// - **Error Handling**: Stream errors are caught and reported.
/// - **Provenance Preservation**: Each emitted event preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Type Safety**: Generic over input type [S] and output type [T].
///
/// ### Parameters:
/// - [project]: **Stream Projection.** Called with each typed payload,
///   returns a `Stream<T>`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** Defaults to `true`.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the stream events.
///
/// ### Returns:
/// A [FlowInstruction] that maps payloads to streams.
///
/// ### See Also:
/// - [FromStream]: For a single stream subscription.
/// - [DeferStream]: For creating a new stream on each trigger.
/// - [ConcatFromStream]: For playing streams in order.
/// - [MergeFromStream]: For listening to streams in parallel.
/// - [SwitchFromStream]: For switching to the latest stream.
class MapToStream<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  MapToStream(
      Stream<T> Function(S value) project, {
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final queue = <S>[];
      var busy = false;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          _fail(
            error: FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'MapToStream.error',
          );
          return null;
        }
        queue.add(payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final next = queue.removeAt(0);
            try {
              await for (final event in project(next)) {
                future!(
                  result: _ok<T>(event, cell, pulse, 'MapToStream'),
                  token: token,
                );
              }
            } catch (e, stack) {
              _fail(
                error: e,
                stack: stack,
                onError: onError,
                emitErrorPulse: emitErrorPulse,
                future: future,
                token: token,
                cell: cell,
                trigger: pulse,
                step: 'MapToStream.error',
              );
            }
          }
          busy = false;
        }

        pump();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [FromStream] instruction and related operators
/// showing their behavior in various stream bridging scenarios.
///
/// ### Expected console output:
/// ```text
/// ── FromStream Operators Demo ─────────────────────────────────
///
/// 1. FromStream
///    [FromStream] 1
///    [FromStream] 2
///
/// 2. DeferStream
///    [DeferStream] a
///
/// 3. ConcatFromStream
///    [ConcatFromStream] 1
///    [ConcatFromStream] 2
///    [ConcatFromStream] 3
///
/// 4. SwitchFromStream
///    [SwitchFromStream] new
///
/// 5. MapToStream
///    [MapToStream] x-1
///    [MapToStream] x-2
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
/// 1. **FromStream - Single Subscription**: Shows a single stream
///    subscription that starts on the first trigger. The stream
///    [1, 2] is bridged into the graph.
///
/// 2. **DeferStream - New Stream Each Trigger**: Shows a new stream
///    created on each trigger. The stream ['a'] is created and
///    bridged on trigger.
///
/// 3. **ConcatFromStream - Ordered Streams**: Shows streams played
///    in order. [1, 2] and [3] are concatenated to produce 1, 2, 3.
///
/// 4. **SwitchFromStream - Latest Stream**: Shows switching to the
///    latest stream. The 'old' stream is cancelled when 'new' arrives,
///    so only 'new' is emitted.
///
/// 5. **MapToStream - Mapped Streams**: Shows mapping payloads to
///    streams. 'x' is mapped to ['x-1', 'x-2'] and emitted.
///
/// ### Key Takeaways
/// - FromStream bridges a single stream into the graph.
/// - DeferStream creates a new stream on each trigger.
/// - ConcatFromStream plays streams in arrival order.
/// - MergeFromStream listens to streams in parallel.
/// - SwitchFromStream switches to the latest stream.
/// - MapToStream maps payloads to streams.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Error pulses are emitted on stream errors.
///
/// ### Note on Stream Types
/// These operators bridge Dart Streams into the Cell graph. They
/// work with any stream type (broadcast, single-subscription, etc.)
/// and handle errors gracefully.
Future<void> main() async {
  print('── FromStream Operators Demo ─────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. FromStream - Single Subscription
  // ─────────────────────────────────────────────────────────────────────
  print('1. FromStream');

  final arm = Cell.ingress<void>();

  final from = FromStream<int>(
    Stream.fromIterable([1, 2]),
  ).toHandle(source: arm.cell);

  final fObs = Cell.observe(
    source: from.cell,
    effect: (Pulse p) => print('   [FromStream] ${p.payload}'),
  );

  await arm.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  fObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. DeferStream - New Stream Each Trigger
  // ─────────────────────────────────────────────────────────────────────
  print('2. DeferStream');

  final dArm = Cell.ingress<void>();

  final defer = DeferStream<String>(
        () => Stream.fromIterable(['a']),
  ).toHandle(source: dArm.cell);

  final dObs = Cell.observe(
    source: defer.cell,
    effect: (Pulse p) => print('   [DeferStream] ${p.payload}'),
  );

  await dArm.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  dObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. ConcatFromStream - Ordered Streams
  // ─────────────────────────────────────────────────────────────────────
  print('3. ConcatFromStream');

  final streams = Cell.ingress<Stream<int>>();

  final concat = ConcatFromStream<int>().toHandle(source: streams.cell);

  final cObs = Cell.observe(
    source: concat.cell,
    effect: (Pulse p) => print('   [ConcatFromStream] ${p.payload}'),
  );

  await streams.emitAsync(Stream.fromIterable([1, 2]));
  await streams.emitAsync(Stream.fromIterable([3]));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. SwitchFromStream - Latest Stream
  // ─────────────────────────────────────────────────────────────────────
  print('4. SwitchFromStream');

  final sw = Cell.ingress<Stream<String>>();

  final latest = SwitchFromStream<String>().toHandle(source: sw.cell);

  final sObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [SwitchFromStream] ${p.payload}'),
  );

  await sw.emitAsync(
    Stream<String>.periodic(const Duration(milliseconds: 40), (_) => 'old'),
  );
  await sw.emitAsync(Stream.fromIterable(['new']));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. MapToStream - Mapped Streams
  // ─────────────────────────────────────────────────────────────────────
  print('5. MapToStream');

  final keys = Cell.ingress<String>();

  final mapped = MapToStream<String, String>(
        (s) => Stream.fromIterable(['$s-1', '$s-2']),
  ).toHandle(source: keys.cell);

  final mObs = Cell.observe(
    source: mapped.cell,
    effect: (Pulse p) => print('   [MapToStream] ${p.payload}'),
  );

  await keys.emitAsync('x');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  mObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}