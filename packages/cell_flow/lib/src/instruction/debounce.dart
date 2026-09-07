// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

/// Flow instructions that wait for silence or a clock (Rx `debounce` family).
///
/// | Operator | Rx analogue | Emits |
/// |---|---|---|
/// | [Debounce] | `debounceTime` | last value after [duration] of silence |
/// | [DebounceLeading] | leading + trailing debounce | first immediately, last after silence |
/// | [DebounceLeadingOnly] | leading debounce | first of a burst only |
/// | [DebounceWith] | `debounce` | last value after a per-item duration |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for debounce operators.
///
/// Called when an error occurs during debounce operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = DebounceErrorHandler((error, stack) {
///   print('Debounce error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef DebounceErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      DebounceErrorHandler? onError,
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

/// Helper to add a step to a pulse's trace.
Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

/// Helper to create an output pulse with proper provenance.
Pulse<S> _fromPayload<S>(S value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}

// ─────────────────────────────────────────────────────────────
// Debounce - Standard Silence Gate
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the last value after a period
/// of silence (Rx `debounceTime`).
///
/// [Debounce] acts as a **Temporal Silence Gate**. It monitors the stimulus
/// stream and delays materialization until the topography has been silent
/// for a specific [duration]. If a new stimulus arrives before the interval
/// elapses, the previous pending pulse is discarded, ensuring only the
/// "settled" state is propagated.
///
/// ### When to use
/// Use [Debounce] when you need to wait for stability before emitting.
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
/// ### Choosing Between Debounce Variants
/// - **Use [Debounce]** for **Standard Debounce**: When you only care about
///   the final value after a period of silence.
/// - **Use [DebounceLeading]** for **First + Last**: When you need immediate
///   response AND the final settled value.
/// - **Use [DebounceLeadingOnly]** for **First Only**: When you only care
///   about the first value of a burst.
/// - **Use [DebounceWith]** for **Dynamic Duration**: When the silence
///   duration depends on the payload.
///
/// ### Comparison with Other Operators
/// | Operator | Emits | Timer Reset | Use Case |
/// |----------|-------|-------------|----------|
/// | **Debounce** | Last value | On every pulse | Search, auto-save |
/// | **DebounceLeading** | First + Last | On every pulse | Responsive + settling |
/// | **DebounceLeadingOnly** | First only | On every pulse | Click prevention |
/// | **DebounceWith** | Last value | On every pulse | Dynamic timing |
/// | **Throttle** | First at intervals | Fixed window | Rate limiting |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked.
/// 2. The timer is reset to the full [duration] on each new value.
/// 3. When the timer completes without interruption, the latest value is emitted.
/// 4. Only the final value in each burst is emitted.
/// 5. Each emitted value gets the step `'Debounce'` for provenance.
///
/// ### Non‑obvious
/// - **Silence Window**: The timer resets on every new pulse.
/// - **Pending Value**: Only the most recent value is emitted.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Order Preservation**: Only the final value in each burst is emitted.
/// - **Zero-Duration**: If [duration] is zero, the gate acts as a
///   microtask-deferred relay rather than a true silence gate.
/// - **Temporal Discontinuity**: The time of emission is shifted by exactly
///   [duration] from the arrival of the last received pulse.
///
/// ### Example: Search-as-you-type
/// ```dart
/// final search = Cell.ingress<String>();
///
/// final debounced = Debounce<String>(
///   Duration(milliseconds: 300),
/// ).toHandle(source: search.cell);
///
/// search.emit('h');
/// search.emit('he');
/// search.emit('hel');
/// search.emit('hell');
/// search.emit('hello');
/// // after 300ms silence, emits 'hello'
/// ```
///
/// ### Parameters:
/// - [duration]: **The Silence Window.** The period of inactivity required
///   before emission.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that debounces values.
///
/// ### See Also:
/// - [DebounceLeading]: For immediate + trailing emission.
/// - [DebounceLeadingOnly]: For leading-only emission.
/// - [DebounceWith]: For dynamic silence duration.
/// - [Throttle]: For rate limiting.
class Debounce<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a standard debounce instruction.
  ///
  /// ### Parameters:
  /// - [duration]: The silence window required before emission.
  /// - [onError]: Optional error handler for type mismatches.
  /// - [user]: Optional user metadata.
  Debounce(
      Duration duration, {
        DebounceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _GateState<S>();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;

        state.pending = typed.payload as S;
        state.pendingPulse = typed;
        state.timer?.cancel();
        state.timer = Timer(duration, () {
          final value = state.pending;
          final src = state.pendingPulse;
          state.clearPending();
          if (value == null || src == null) return;
          future!(
            result: _fromPayload(value, src, cell, 'Debounce'),
            token: token,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DebounceLeading - First + Trailing Debounce
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the first pulse immediately,
/// then the last pulse after silence (leading + trailing debounce).
///
/// [DebounceLeading] combines "leading" and "trailing" edge evolution. The
/// first pulse of a burst is materialized immediately to ensure
/// responsiveness, while subsequent pulses are gated until a [duration] of
/// silence is observed, at which point the final pulse of the burst is emitted.
///
/// ### When to use
/// Use [DebounceLeading] when you need immediate response AND the final value.
///
/// - **Search with Preview**: Show immediate results AND final results.
/// - **Form Validation**: Validate on first change AND after typing stops.
/// - **User Interaction**: Respond instantly AND settle later.
/// - **UI Feedback**: Show immediate feedback AND final state.
/// - **Responsive Interactions**: Respond to first action instantly.
///
/// ### Example: Responsive Search
/// ```dart
/// final input = Cell.ingress<String>();
///
/// val responsive = DebounceLeading<String>(
///   Duration(milliseconds: 300),
/// ).toHandle(source: input.cell);
///
/// input.emit('d');     // Emits immediately (leading)
/// input.emit('da');    // Resets timer
/// input.emit('dar');   // Resets timer
/// input.emit('dart');  // Resets timer, then emits after 300ms (trailing)
/// ```
///
/// ### How it works
/// 1. **Leading Materialization**: The first stimulus bypasses the timer
///    and is emitted immediately as a leading pulse.
/// 2. **Silence Monitoring**: The gate enters a "busy" state where new
///    pulses reset the silence timer.
/// 3. **Trailing Materialization**: Once the timer elapses, the most
///    recent pulse is emitted as the trailing pulse.
/// 4. **Provenance Preservation**: Emitted pulses are tagged with
///    `'DebounceLeading.leading'` or `'DebounceLeading.trailing'`.
///
/// ### Non‑obvious
/// - **Single-Pulse Bursts**: If only one pulse arrives and no others follow
///   within the duration, it is emitted only as a leading pulse; the trailing
///   materialization is suppressed to prevent duplicates.
///
/// ### Parameters:
/// - [duration]: The silence window required before trailing emission.
/// - [onError]: Optional error handler for type mismatches.
/// - [user]: Optional user metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits leading and trailing values.
///
/// ### See Also:
/// - [Debounce]: For standard silence gating without the leading edge.
/// - [DebounceLeadingOnly]: To capture only the start of a burst.
class DebounceLeading<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a leading + trailing debounce instruction.
  ///
  /// ### Parameters:
  /// - [duration]: The silence window required before trailing emission.
  /// - [onError]: Optional error handler for type mismatches.
  /// - [user]: Optional user metadata.
  DebounceLeading(
      Duration duration, {
        DebounceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _GateState<S>();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;

        final timerActive = state.timer?.isActive == true;
        if (!timerActive) {
          state.clearPending();
          future!(
            result: _mark(typed, 'DebounceLeading.leading'),
            token: token,
          );
          state.timer = Timer(duration, () {
            state.timer = null;
          });
          return null;
        }

        state.pending = typed.payload as S;
        state.pendingPulse = typed;
        state.timer?.cancel();
        state.timer = Timer(duration, () {
          final value = state.pending;
          final src = state.pendingPulse;
          state.clearPending();
          state.timer = null;
          if (value == null || src == null) return;
          future!(
            result: _fromPayload(
              value,
              src,
              cell,
              'DebounceLeading.trailing',
            ),
            token: token,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DebounceLeadingOnly - Leading-Only Debounce
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only the first pulse of a burst
/// (leading-only debounce).
///
/// [DebounceLeadingOnly] (similar to a lock-out timer) materializes the first
/// stimulus of a burst immediately and then suppresses all subsequent
/// pulses until a [duration] of silence has occurred. It effectively
/// ignores the "noise" following an initial action.
///
/// ### When to use
/// Use [DebounceLeadingOnly] when you only care about the first value.
///
/// - **Action Lock-out**: Preventing double-submission of forms.
/// - **Event Throttling**: Responding to the first stimulus only.
/// - **Button Clicks**: Ignoring rapid subsequent clicks.
/// - **API Calls**: Preventing duplicate API calls.
/// - **Navigation**: Responding to first navigation only.
///
/// ### Example: Form Submission
/// ```dart
/// final clicks = Cell.ingress<void>();
///
/// val submit = DebounceLeadingOnly<void>(
///   Duration(seconds: 1),
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Emits immediately
/// clicks.emit(null); // Ignored (within silence window)
/// clicks.emit(null); // Ignored (within silence window)
/// // After 1s silence, the next click is emitted
/// ```
///
/// ### How it works
/// 1. **Initial Materialization**: The first stimulus is emitted instantly.
/// 2. **Refractory Period**: The gate becomes opaque to all stimuli until
///    the silence timer elapses.
/// 3. **Silence Reset**: Unlike a standard throttle, every suppressed pulse
///    re-arms the silence timer, extending the lock-out period.
///
/// ### Non‑obvious
/// - **Silence Requirements**: If pulses continue to arrive faster than
///   [duration], the gate may remain locked indefinitely.
/// - **Provenance Preservation**: Emitted pulses are tagged with
///   `'DebounceLeadingOnly'`.
///
/// ### Parameters:
/// - [duration]: The lock-out interval.
/// - [onError]: Optional error handler for type mismatches.
/// - [user]: Optional user metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits only the first value of each burst.
///
/// ### See Also:
/// - [DebounceLeading]: For immediate + trailing emission.
/// - [Debounce]: For standard silence gating.
/// - [ThrottleLeading]: For time-window based lock-out rather than silence.
class DebounceLeadingOnly<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a leading-only debounce instruction.
  ///
  /// ### Parameters:
  /// - [duration]: The lock-out interval.
  /// - [onError]: Optional error handler for type mismatches.
  /// - [user]: Optional user metadata.
  DebounceLeadingOnly(
      Duration duration, {
        DebounceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _GateState<S>();
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;

        if (state.timer?.isActive == true) return null;

        state.timer = Timer(duration, () {
          state.timer = null;
        });
        return _mark(typed, 'DebounceLeadingOnly');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// DebounceWith - Dynamic Duration Debounce
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction where each stimulus determines its own
/// silence duration (Rx `debounce` with selector).
///
/// [DebounceWith] evaluates a [durationOf] closure for every incoming pulse.
/// This allows the topography to adjust its settling time dynamically based
/// on the payload's complexity or content.
///
/// ### When to use
/// Use [DebounceWith] when the silence duration depends on the payload.
///
/// - **Adaptive Latency**: Waiting longer for complex payloads.
/// - **Priority-Based Gating**: Shorter for high-priority pulses.
/// - **Content-Based Timing**: Longer for large content.
/// - **Size-Based Debounce**: Adjusting based on payload size.
/// - **Type-Based Timing**: Different timings for different types.
///
/// ### Example: Variable Latency
/// ```dart
/// final input = Cell.ingress<Data>();
///
/// val dynamic = DebounceWith<Data>(
///   (data) => Duration(milliseconds: data.isHeavy ? 1000 : 100),
/// ).toHandle(source: input.cell);
/// ```
///
/// ### How it works
/// 1. **Dynamic Evaluation**: The [durationOf] orchestrator is invoked
///    for every incoming payload.
/// 2. **Generation Tracking**: Internal IDs ensure that only the
///    materialization matching the most recent stimulus occurs.
/// 3. **Materialization**: Occurs after the per-item silence duration has passed.
/// 4. **Provenance Preservation**: Emitted pulses are tagged with
///    `'DebounceWith'`.
///
/// ### Non‑obvious
/// - **Execution Context**: The [durationOf] closure is executed synchronously
///   upon pulse arrival; heavy logic here will block the reactive engine.
/// - **Generation Tracking**: Each pulse gets a generation ID to prevent
///   stale emissions.
///
/// ### Parameters:
/// - [durationOf]: A function that returns the silence duration for each payload.
/// - [onError]: Optional error handler for type mismatches or duration errors.
/// - [user]: Optional user metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that debounces with dynamic timing.
///
/// ### See Also:
/// - [Debounce]: For static temporal silence gating.
/// - [ThrottleWith]: For dynamic sampling windows.
class DebounceWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a dynamic debounce instruction.
  ///
  /// ### Parameters:
  /// - [durationOf]: A function that returns the silence duration for each payload.
  /// - [onError]: Optional error handler for type mismatches or duration errors.
  /// - [user]: Optional user metadata.
  DebounceWith(
      Duration Function(S value) durationOf, {
        DebounceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _GateState<S>();
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final payload = typed.payload as S;

        Duration wait;
        try {
          wait = durationOf(payload);
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }

        state.pending = payload;
        state.pendingPulse = typed;
        state.timer?.cancel();
        final id = ++generation;
        state.timer = Timer(wait, () {
          if (id != generation) return;
          final value = state.pending;
          final src = state.pendingPulse;
          state.clearPending();
          if (value == null || src == null) return;
          future!(
            result: _fromPayload(value, src, cell, 'DebounceWith'),
            token: token,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for debounce operators.
///
/// Stores the pending value, pending pulse, and active timer.
class _GateState<S> {
  /// The pending value waiting for emission.
  S? pending;

  /// The pending pulse waiting for emission.
  Pulse? pendingPulse;

  /// The active timer for the silence window.
  Timer? timer;

  /// Clears pending values and cancels the timer.
  void clearPending() {
    pending = null;
    pendingPulse = null;
    timer?.cancel();
    timer = null;
  }
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the debounce family.
///
/// ### Expected console output:
/// ```text
/// ── Debounce Operators Demo ───────────────────────────────────
///
/// 1. Debounce - last after silence
///    [Debounce] hello
///
/// 2. DebounceLeading - first then last
///    [DebounceLeading] 1
///    [DebounceLeading] 3
///
/// 3. DebounceLeadingOnly - first of burst
///    [DebounceLeadingOnly] 1
///
/// 4. DebounceWith - per-value wait
///    [DebounceWith] go
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
/// 1. **Debounce - Last After Silence**: Shows standard debounce where
///    only the final value 'hello' is emitted after 60ms of silence.
///    Intermediate values 'h' and 'he' are dropped.
///
/// 2. **DebounceLeading - First Then Last**: Shows leading + trailing
///    debounce where the first value '1' is emitted immediately, and
///    the last value '3' is emitted after 50ms of silence. Value '2'
///    is dropped.
///
/// 3. **DebounceLeadingOnly - First of Burst**: Shows leading-only
///    debounce where only the first value '1' is emitted. Values '2'
///    and '3' are dropped while the timer is active.
///
/// 4. **DebounceWith - Per-Value Wait**: Shows dynamic debounce where
///    the value 'wait' (80ms) is dropped because 'go' (20ms) arrives
///    and completes its shorter silence window first. Only 'go' is emitted.
///
/// ### Key Takeaways
/// - Debounce waits for silence, then emits the last value.
/// - DebounceLeading emits first value immediately, then last after silence.
/// - DebounceLeadingOnly emits only the first value of a burst.
/// - DebounceWith uses payload-dependent silence duration.
/// - All operators preserve causal provenance via EvolvedPulse.
///
/// ### Note on Timing
/// The demo uses short delays (15-80ms) for quick execution. In production,
/// you would typically use longer durations (100-500ms) for debouncing.
Future<void> main() async {
  print('── Debounce Operators Demo ───────────────────────────────────\n');

  print('1. Debounce - last after silence');
  final search = Cell.ingress<String>();
  final debounced = Debounce<String>(const Duration(milliseconds: 60))
      .toHandle(source: search.cell);
  final dObs = Cell.observe(
    source: debounced.cell,
    effect: (Pulse p) => print('   [Debounce] ${p.payload}'),
  );
  await search.emitAsync('h');
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await search.emitAsync('he');
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await search.emitAsync('hello');
  await Future<void>.delayed(const Duration(milliseconds: 90));
  dObs.stop();
  print('');

  print('2. DebounceLeading - first then last');
  final burst = Cell.ingress<int>();
  final lead = DebounceLeading<int>(const Duration(milliseconds: 50))
      .toHandle(source: burst.cell);
  final lObs = Cell.observe(
    source: lead.cell,
    effect: (Pulse p) => print('   [DebounceLeading] ${p.payload}'),
  );
  await burst.emitAsync(1);
  await burst.emitAsync(2);
  await burst.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  lObs.stop();
  print('');

  print('3. DebounceLeadingOnly - first of burst');
  final taps = Cell.ingress<int>();
  final only = DebounceLeadingOnly<int>(const Duration(milliseconds: 50))
      .toHandle(source: taps.cell);
  final oObs = Cell.observe(
    source: only.cell,
    effect: (Pulse p) => print('   [DebounceLeadingOnly] ${p.payload}'),
  );
  await taps.emitAsync(1);
  await taps.emitAsync(2);
  await taps.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  oObs.stop();
  print('');

  print('4. DebounceWith - per-value wait');
  final words = Cell.ingress<String>();
  final keyed = DebounceWith<String>(
        (s) => Duration(milliseconds: s == 'wait' ? 80 : 20),
  ).toHandle(source: words.cell);
  final wObs = Cell.observe(
    source: keyed.cell,
    effect: (Pulse p) => print('   [DebounceWith] ${p.payload}'),
  );
  await words.emitAsync('wait');
  await Future<void>.delayed(const Duration(milliseconds: 25));
  await words.emitAsync('go');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  wObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}