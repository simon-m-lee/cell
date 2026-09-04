// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Share Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that multicast / replay (Rx `share` family).
///
/// Several [Cell.observe] calls on the **same** [FlowHandle.cell]
/// already share one subscription. These operators add a **readable
/// replay buffer** so a late reader (or a later instruction) can see
/// what already flowed.
///
/// | Operator | Rx analogue | Buffer |
/// |---|---|---|
/// | [Share] | `share` | none (pass-through + count) |
/// | [ShareLatest] | `shareReplay(1)` | last typed value |
/// | [ShareReplay] | `shareReplay(n)` | last [size] values |
/// | [ShareReplayStart] | late subscriber | prefix the buffer, then live |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for share operators.
///
/// Called when an error occurs during type checking or buffer operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = ShareErrorHandler((error, stack) {
///   print('Share error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ShareErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper for type-safe payload extraction.
///
/// [_typedOrError] checks that the pulse payload matches the expected
/// type [S]. If it does, returns the pulse. If not, calls [onError]
/// and returns `null`.
///
/// ### Parameters:
/// - [pulse]: The incoming pulse to check.
/// - [onError]: Optional error handler for type mismatches.
///
/// ### Returns:
/// The pulse if the payload type matches, otherwise `null`.
Pulse? _typedOrError<S>(
    Pulse pulse, {
      ShareErrorHandler? onError,
    }) {
  final payload = pulse.payload;
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
}

/// Helper to create an output pulse with proper provenance.
Pulse<S> _out<S>(S value, Pulse trigger, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Live replay window. Not durable storage.
///
/// [ShareBuffer] holds a sliding window of recent values for replay
/// purposes. It maintains a fixed-size buffer and tracks how many
/// values have been seen.
///
/// ### When to use
/// Use [ShareBuffer] when you need to access recent values from a
/// shared flow. It's the internal buffer for [ShareLatest] and
/// [ShareReplay] operators.
///
/// ### How it works
/// 1. The [size] determines how many values are retained.
/// 2. [push] adds a value and maintains the window size.
/// 3. [values] provides access to the buffered values.
/// 4. [latest] returns the most recent value.
/// 5. [seen] tracks the total number of values pushed.
///
/// ### Non‑obvious
/// - **Sliding Window**: When the buffer exceeds [size], the oldest
///   values are removed.
/// - **Size 0**: If [size] is 0, no values are retained.
/// - **Size 1**: Equivalent to [ShareLatest] behavior.
/// - **Volatile**: The buffer is in-memory only, not persisted.
/// - **Shared Access**: Multiple observers can read the same buffer.
/// - **Not a Store**: This is not a database or cache.
///
/// ### Example: Accessing the Buffer
/// ```dart
/// final buffer = ShareBuffer<String>(size: 3);
/// buffer.push('a');
/// buffer.push('b');
/// buffer.push('c');
/// buffer.push('d');
/// print(buffer.values); // ['b', 'c', 'd']
/// print(buffer.latest); // 'd'
/// print(buffer.seen);   // 4
/// ```
///
/// ### Type Parameters:
/// - [S]: The type of values stored in the buffer.
///
/// ### See Also:
/// - [ShareLatest]: Uses a buffer of size 1.
/// - [ShareReplay]: Uses a buffer of configurable size.
/// - [ShareReplayStart]: Replays the buffer on first pulse.
class ShareBuffer<S> {
  /// Creates a buffer with the specified [size].
  ///
  /// If [size] is not provided, defaults to 1.
  ///
  /// ### Example
  /// ```dart
  /// final buffer = ShareBuffer<int>(size: 5);
  /// ```
  ShareBuffer({this.size = 1});

  /// The maximum number of values to retain.
  ///
  /// When the buffer exceeds this size, the oldest values are removed.
  final int size;

  /// The buffered values in insertion order.
  final List<S> values = <S>[];

  /// The total number of values pushed to this buffer.
  ///
  /// This counter increments on every [push] call, regardless of
  /// whether the value is retained in the buffer.
  int seen = 0;

  /// Pushes a value into the buffer.
  ///
  /// 1. Increments the [seen] counter.
  /// 2. Adds the value to the buffer.
  /// 3. Trims the buffer to the [size] limit.
  ///
  /// ### Example
  /// ```dart
  /// buffer.push(42);
  /// ```
  void push(S value) {
    seen++;
    values.add(value);
    while (size > 0 && values.length > size) {
      values.removeAt(0);
    }
  }

  /// Returns the most recent value in the buffer.
  ///
  /// Returns `null` if the buffer is empty.
  ///
  /// ### Example
  /// ```dart
  /// final latest = buffer.latest;
  /// if (latest != null) print(latest);
  /// ```
  S? get latest => values.isEmpty ? null : values.last;
}

// ─────────────────────────────────────────────────────────────
// Share - Pass-through Multicast
// ─────────────────────────────────────────────────────────────

/// Internal counter for [Share] to track how many pulses passed through.
class _Seen {
  int value = 0;
}

/// A [FlowInstruction] that marks a flow as shared/multicast without
/// buffering (Rx `share`).
///
/// [Share] is a pass-through operator that doesn't change values but
/// tracks how many typed pulses have flowed through. It's useful for
/// testing, dashboards, and debugging to verify that a source ran
/// exactly once.
///
/// ### When to use
/// Use [Share] when you need to verify that a shared source is
/// executed only once.
///
/// - **Testing**: Verifying that a source is executed exactly once.
/// - **Debugging**: Tracking pulse flow through a shared stream.
/// - **Monitoring**: Counting pulses for dashboards.
/// - **Auditing**: Tracking how many values passed through.
/// - **Validation**: Ensuring a source is not re-executed.
///
/// ### Comparison with Other Share Operators
/// | Operator | Buffer | Replay | Count |
/// |----------|--------|--------|-------|
/// | **Share** | None | No | Yes (seen) |
/// | **ShareLatest** | Size 1 | Yes | No |
/// | **ShareReplay** | Configurable | Yes | No |
/// | **ShareReplayStart** | Configurable | On first pulse | No |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. If the type matches, the pulse is passed through unchanged.
/// 3. The `seen` counter is incremented.
/// 4. The pulse gets the step `'Share'` for provenance.
///
/// ### Non‑obvious
/// - **Pass-through**: Values are not modified or buffered.
/// - **Counting**: The [seen] counter tracks typed pulses only.
/// - **Type Safety**: Only payloads matching type [S] are counted.
/// - **Provenance Preservation**: The pulse gets the `'Share'` step.
/// - **Multiple Observers**: Multiple observers share one subscription.
/// - **No Replay**: Late subscribers do not receive past values.
///
/// ### Example: Testing Shared Source
/// ```dart
/// final input = Cell.ingress<int>();
/// final share = Share<int>();
/// final shared = share.toHandle(source: input.cell);
///
/// // Multiple observers share one subscription
/// final obs1 = Cell.observe(source: shared.cell, effect: (p) => {});
/// final obs2 = Cell.observe(source: shared.cell, effect: (p) => {});
///
/// await input.emitAsync(42);
/// print(share.seen); // 1 (source executed once)
/// ```
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that counts typed pulses.
///
/// ### See Also:
/// - [ShareLatest]: For buffering the latest value.
/// - [ShareReplay]: For buffering multiple values.
/// - [ShareReplayStart]: For replaying the buffer on first pulse.
class Share<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Share({
    ShareErrorHandler? onError,
    dynamic user,
  }) : this._(_Seen(), onError, user);

  Share._(
      this._seen,
      ShareErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final seen = _seen;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        seen.value++;
        return typed.withStep('Share');
      };
    })(),
    user: user,
  );

  final _Seen _seen;

  /// The number of typed pulses that have passed through this share.
  ///
  /// This counter is incremented on every typed pulse, regardless of
  /// how many observers are attached.
  int get seen => _seen.value;
}

// ─────────────────────────────────────────────────────────────
// ShareLatest - Latest Value Replay
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that keeps the last typed value for replay
/// (Rx `shareReplay(1)`).
///
/// [ShareLatest] maintains a buffer of size 1 containing the most
/// recent value. Late subscribers can access the latest value via
/// the [buffer.latest] getter.
///
/// ### When to use
/// Use [ShareLatest] when you need to know the most recent value
/// from a shared flow.
///
/// - **UI State**: Displaying the latest state value.
/// - **Caching**: Caching the most recent API response.
/// - **Real-time Updates**: Showing the latest real-time data.
/// - **Initialization**: Getting the current value on subscription.
/// - **Debugging**: Inspecting the latest value.
///
/// ### Example: Latest Value Access
/// ```dart
/// final input = Cell.ingress<String>();
/// final latestOp = ShareLatest<String>();
/// final shared = latestOp.toHandle(source: input.cell);
///
/// // Late subscriber can access the latest value
/// await input.emitAsync('Hello');
/// print(latestOp.buffer.latest); // 'Hello'
///
/// await input.emitAsync('World');
/// print(latestOp.buffer.latest); // 'World'
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The payload is stored in the buffer.
/// 3. The pulse is passed through unchanged.
/// 4. The [buffer.latest] getter provides access to the most recent value.
/// 5. The pulse gets the step `'ShareLatest'` for provenance.
///
/// ### Non‑obvious
/// - **Buffer Size 1**: Only the most recent value is retained.
/// - **Mutable Buffer**: The buffer is mutable and shared.
/// - **No Replay**: The operator itself doesn't replay; it just stores.
/// - **External Access**: The buffer is accessible externally.
/// - **Provenance Preservation**: The pulse gets the `'ShareLatest'` step.
///
/// ### Parameters:
/// - [buffer]: **Shared Buffer.** Optional. Creates a new one if not provided.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that stores the latest value.
///
/// ### See Also:
/// - [Share]: For pass-through with counting.
/// - [ShareReplay]: For buffering multiple values.
/// - [ShareReplayStart]: For replaying the buffer on first pulse.
class ShareLatest<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ShareLatest({
    ShareBuffer<S>? buffer,
    ShareErrorHandler? onError,
    dynamic user,
  }) : this._(buffer ?? ShareBuffer<S>(size: 1), onError, user);

  ShareLatest._(
      this.buffer,
      ShareErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final buf = buffer;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        buf.push(typed.payload as S);
        return typed.withStep('ShareLatest');
      };
    })(),
    user: user,
  );

  /// The buffer containing the latest value.
  ///
  /// Use [buffer.latest] to access the most recent value.
  /// Use [buffer.values] to access the buffer contents.
  final ShareBuffer<S> buffer;
}

// ─────────────────────────────────────────────────────────────
// ShareReplay - Multi-Value Replay Buffer
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that keeps the last [size] typed values
/// (Rx `shareReplay`).
///
/// [ShareReplay] maintains a buffer of configurable size containing
/// the most recent values. Late subscribers can access the buffered
/// values via the [buffer.values] getter.
///
/// ### When to use
/// Use [ShareReplay] when you need to access a window of recent values
/// from a shared flow.
///
/// - **History**: Showing a history of recent values.
/// - **Audit Trail**: Tracking recent state changes.
/// - **Undo/Redo**: Supporting undo of recent operations.
/// - **Analytics**: Analyzing recent data points.
/// - **Debugging**: Inspecting recent values.
///
/// ### Example: Recent Values Access
/// ```dart
/// final input = Cell.ingress<int>();
/// final replayOp = ShareReplay<int>(size: 3);
/// final shared = replayOp.toHandle(source: input.cell);
///
/// await input.emitAsync(1);
/// await input.emitAsync(2);
/// await input.emitAsync(3);
/// await input.emitAsync(4);
///
/// print(replayOp.buffer.values); // [2, 3, 4]
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The payload is pushed into the buffer.
/// 3. The buffer maintains a sliding window of [size] values.
/// 4. The pulse is passed through unchanged.
/// 5. The [buffer.values] getter provides access to buffered values.
/// 6. The pulse gets the step `'ShareReplay'` for provenance.
///
/// ### Non‑obvious
/// - **Sliding Window**: The buffer maintains exactly [size] values.
/// - **Size 0**: If size is 0, no values are retained.
/// - **Mutable Buffer**: The buffer is mutable and shared.
/// - **No Replay**: The operator itself doesn't replay; it just stores.
/// - **External Access**: The buffer is accessible externally.
/// - **Provenance Preservation**: The pulse gets the `'ShareReplay'` step.
///
/// ### Parameters:
/// - [size]: **Buffer Size.** The number of values to retain.
///   Defaults to 16. Minimum value is 1.
/// - [buffer]: **Shared Buffer.** Optional. Creates a new one if not provided.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that stores recent values.
///
/// ### See Also:
/// - [Share]: For pass-through with counting.
/// - [ShareLatest]: For storing only the latest value.
/// - [ShareReplayStart]: For replaying the buffer on first pulse.
class ShareReplay<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ShareReplay({
    int size = 16,
    ShareBuffer<S>? buffer,
    ShareErrorHandler? onError,
    dynamic user,
  }) : this._(
    buffer ?? ShareBuffer<S>(size: size < 1 ? 1 : size),
    onError,
    user,
  );

  ShareReplay._(
      this.buffer,
      ShareErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final buf = buffer;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        buf.push(typed.payload as S);
        return typed.withStep('ShareReplay');
      };
    })(),
    user: user,
  );

  /// The buffer containing recent values.
  ///
  /// Use [buffer.values] to access the buffered values.
  /// Use [buffer.latest] to access the most recent value.
  final ShareBuffer<S> buffer;
}

// ─────────────────────────────────────────────────────────────
// ShareReplayStart - Replay Buffer on First Pulse
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that replays the buffer on the first typed pulse,
/// then forwards live values (late-subscriber approximation).
///
/// [ShareReplayStart] is useful for simulating a "late subscriber"
/// scenario where a new subscriber should receive the existing buffer
/// before seeing live values.
///
/// ### When to use
/// Use [ShareReplayStart] when you need to replay existing values to
/// a new subscriber before forwarding live values.
///
/// - **Late Subscribers**: Giving new subscribers the history.
/// - **Initialization**: Providing initial state to new flows.
/// - **State Restoration**: Restoring state from a buffer.
/// - **Testing**: Setting up test state from a buffer.
/// - **Migration**: Migrating state from one flow to another.
///
/// ### Example: Late Subscriber Simulation
/// ```dart
/// final buffer = ShareBuffer<String>(size: 3);
/// buffer.push('a');
/// buffer.push('b');
/// buffer.push('c');
///
/// final input = Cell.ingress<String>();
/// final start = ShareReplayStart<String>(buffer)
///     .toHandle(source: input.cell);
///
/// // First pulse replays the buffer then forwards the new value
/// await input.emitAsync('d');
/// // Outputs: a, b, c, d
/// ```
///
/// ### How it works
/// 1. On the first typed pulse:
///    a. The buffer is replayed (all buffered values are emitted).
///    b. The payload is pushed to the buffer.
///    c. If [includeCurrent] is `true`, the payload is also forwarded.
/// 2. On subsequent pulses:
///    a. The payload is pushed to the buffer.
///    b. The payload is forwarded.
/// 3. The buffer is shared and accessible externally.
///
/// ### Non‑obvious
/// - **Replay Once**: The buffer is replayed only on the first pulse.
/// - **Buffer Update**: The first pulse's value is added to the buffer.
/// - **Include Current**: [includeCurrent] controls whether the first
///   pulse's value is also forwarded.
/// - **Shared Buffer**: The buffer is shared and can be accessed externally.
/// - **Provenance Preservation**: Replayed values get the step
///   `'ShareReplayStart.replay'`, live values get `'ShareReplayStart'`.
/// - **Late Subscriber Simulation**: This approximates Rx's late
///   subscriber behavior where new subscribers get the history.
///
/// ### Parameters:
/// - [buffer]: **The Buffer to Replay.** Required. The buffer containing
///   the values to replay on the first pulse.
/// - [includeCurrent]: **Include Current Value.** If `true`, the first
///   pulse's value is also forwarded after the replay. Defaults to `true`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that replays the buffer on the first pulse.
///
/// ### See Also:
/// - [Share]: For pass-through with counting.
/// - [ShareLatest]: For storing only the latest value.
/// - [ShareReplay]: For storing recent values.
class ShareReplayStart<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ShareReplayStart(
      ShareBuffer<S> buffer, {
        bool includeCurrent = true,
        ShareErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var first = true;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (first) {
          first = false;
          for (final value in buffer.values) {
            future!(
              result: _out<S>(value, typed, cell, 'ShareReplayStart.replay'),
              token: token,
            );
          }
        }
        buffer.push(typed.payload as S);
        if (!includeCurrent) return null;
        return typed.withStep('ShareReplayStart');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Share] instruction and related operators
/// showing their behavior in various multicast and replay scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Share Operators Demo ──────────────────────────────────────
///
/// 1. Share - pass through
///    [Share] 1
///    [Share] 2
///    seen=2
///
/// 2. ShareLatest
///    [ShareLatest] a
///    [ShareLatest] b
///    latest=b
///
/// 3. ShareReplay - window 2
///    [ShareReplay] 1
///    [ShareReplay] 2
///    [ShareReplay] 3
///    buffer=[2, 3]
///
/// 4. ShareReplayStart - replay then live
///    [ShareReplayStart] 2
///    [ShareReplayStart] 3
///    [ShareReplayStart] 4
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
/// 1. **Share - Pass Through**: Shows the pass-through operator that
///    forwards all pulses unchanged while counting them. The `seen`
///    counter shows that 2 pulses passed through.
///
/// 2. **ShareLatest - Latest Value**: Shows the buffer storing only
///    the most recent value. After emitting `'a'` and `'b'`, the
///    latest value is `'b'`.
///
/// 3. **ShareReplay - Window**: Shows the sliding window buffer
///    retaining the last 2 values. After emitting 1, 2, 3, the buffer
///    contains `[2, 3]`.
///
/// 4. **ShareReplayStart - Replay Then Live**: Shows the buffer being
///    replayed on the first pulse. The buffer from the previous step
///    `[2, 3]` is replayed, then the new value `4` is forwarded.
///
/// ### Key Takeaways
/// - Share operators enable multicast sharing of a single source.
/// - Share counts pulses without buffering.
/// - ShareLatest stores only the most recent value.
/// - ShareReplay stores a sliding window of recent values.
/// - ShareReplayStart replays the buffer on the first pulse.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Buffers are accessible externally for inspection.
///
/// ### Note on Multicast
/// In the Cell framework, multiple [Cell.observe] calls on the same
/// [FlowHandle.cell] already share one subscription. These operators
/// add a **readable replay buffer** so a late reader can see what
/// already flowed.
Future<void> main() async {
  print('── Share Operators Demo ──────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Share - Pass Through
  // ─────────────────────────────────────────────────────────────────────
  print('1. Share - pass through');

  final a = Cell.ingress<int>();

  final share = Share<int>();
  final shared = share.toHandle(source: a.cell);

  final sObs = Cell.observe(
    source: shared.cell,
    effect: (Pulse p) => print('   [Share] ${p.payload}'),
  );

  await a.emitAsync(1);
  await a.emitAsync(2);

  print('   seen=${share.seen}');

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. ShareLatest - Latest Value
  // ─────────────────────────────────────────────────────────────────────
  print('2. ShareLatest');

  final b = Cell.ingress<String>();

  final latestOp = ShareLatest<String>();
  final latest = latestOp.toHandle(source: b.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [ShareLatest] ${p.payload}'),
  );

  await b.emitAsync('a');
  await b.emitAsync('b');

  print('   latest=${latestOp.buffer.latest}');

  lObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. ShareReplay - Window 2
  // ─────────────────────────────────────────────────────────────────────
  print('3. ShareReplay - window 2');

  final c = Cell.ingress<int>();

  final replayOp = ShareReplay<int>(size: 2);
  final replay = replayOp.toHandle(source: c.cell);

  final rObs = Cell.observe(
    source: replay.cell,
    effect: (Pulse p) => print('   [ShareReplay] ${p.payload}'),
  );

  await c.emitAsync(1);
  await c.emitAsync(2);
  await c.emitAsync(3);

  print('   buffer=${replayOp.buffer.values}');

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. ShareReplayStart - Replay Then Live
  // ─────────────────────────────────────────────────────────────────────
  print('4. ShareReplayStart - replay then live');

  final d = Cell.ingress<int>();

  // Use the buffer from the previous step which contains [2, 3]
  final start = ShareReplayStart<int>(replayOp.buffer)
      .toHandle(source: d.cell);

  final tObs = Cell.observe(
    source: start.cell,
    effect: (Pulse p) => print('   [ShareReplayStart] ${p.payload}'),
  );

  await d.emitAsync(4);

  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}