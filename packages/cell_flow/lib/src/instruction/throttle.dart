// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that cap emission rate (Rx `throttle` family).
///
/// These operators limit the rate of emissions by creating fixed time windows.
/// Unlike [Debounce], a throttle **opens a window** on the first pulse
/// and does not reset that window on later pulses. This ensures a steady
/// maximum emission rate.
///
/// | Operator | Rx analogue | Window |
/// |---|---|---|
/// | [Throttle] | `throttleTime` | leading and/or trailing |
/// | [ThrottleLeading] | leading-only | first pulse of each window |
/// | [ThrottleTrailing] | trailing-only | last pulse when the window closes |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef ThrottleErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
    Pulse pulse, {
      ThrottleErrorHandler? onError,
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

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

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
// Throttle
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that rate-limits to at most one leading and/or
/// trailing value per [duration] (Rx `throttleTime`).
///
/// [Throttle] acts as a **Rate Limiter** with fixed time windows. It controls
/// the emission rate by allowing at most one value per time window, with
/// configurable leading and trailing emissions.
///
/// ### When to use
/// Use [Throttle] when you need to limit the rate of emissions:
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
/// ### Choosing Between Throttle Patterns
/// - **Use [Throttle]** for **Leading + Trailing**: When you want both
///   the first and last values in each window.
/// - **Use [ThrottleLeading]** for **Leading-Only**: When you only care
///   about the first value in each window.
/// - **Use [ThrottleTrailing]** for **Trailing-Only**: When you only care
///   about the last value in each window.
///
/// ### Comparison with Debounce
/// | Feature | Throttle | Debounce |
/// |---------|----------|----------|
/// | **Window** | Fixed (doesn't reset) | Reset on each pulse |
/// | **Emission** | At window boundaries | After silence |
/// | **Use Case** | Rate limiting | Wait for stability |
/// | **First Value** | May emit immediately | Never emits immediately |
///
/// ### How it works
/// 1. A window starts with the first pulse (or when the previous window ends).
/// 2. The first pulse in a window is emitted immediately (if [leading] is true).
/// 3. Subsequent pulses in the window update the pending value.
/// 4. When the window closes, the pending value is emitted (if [trailing] is true).
/// 5. The next window starts with the next pulse.
/// 6. The instruction preserves causal provenance.
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
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Order Preservation**: Results are emitted in the order of arrival
///   within each window.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
///
/// ### Example: Scroll Event Throttling
/// ```dart
/// final scrollEvents = Cell.ingress<ScrollEvent>();
/// val throttled = Throttle<ScrollEvent>(
///   Duration(milliseconds: 100),
///   leading: true,
///   trailing: true,
/// ).toHandle(source: scrollEvents.cell);
///
/// // Emits first scroll event immediately, then last after 100ms
/// ```
///
/// ### Example: API Rate Limiting
/// ```dart
/// final requests = Cell.ingress<Request>();
/// val rateLimited = Throttle<Request>(
///   Duration(seconds: 1),
///   leading: true,
///   trailing: false,
/// ).toHandle(source: requests.cell);
///
/// // Emits only the first request per second
/// ```
///
/// ### Parameters:
/// - [duration]: **The Time Window.** The minimum time between emissions.
/// - [leading]: **Leading Emission.** If `true`, emit the first value immediately.
/// - [trailing]: **Trailing Emission.** If `true`, emit the last value after
///   the window.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ThrottleLeading]: For leading-only throttling.
/// - [ThrottleTrailing]: For trailing-only throttling.
/// - [Debounce]: For silence-based emission.
/// - [FilterByTime]: For time-based filtering.
class Throttle<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Throttle] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Time Window.** The minimum time between emissions.
  /// - [leading]: **Leading Emission.** If `true`, emit the first value immediately.
  /// - [trailing]: **Trailing Emission.** If `true`, emit the last value after
  ///   the window.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val throttle = Throttle<int>(
  ///   Duration(milliseconds: 100),
  ///   leading: true,
  ///   trailing: true,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Throttle(
      Duration duration, {
        bool leading = true,
        bool trailing = true,
        ThrottleErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _WindowState<S>();

      void armTrailing(
          void Function({required Pulse? result, required dynamic token})?
          future,
          dynamic token,
          Cell? cell,
          ) {
        if (!trailing) return;
        state.timer?.cancel();
        final elapsed = state.openedAt == null
            ? duration
            : DateTime.now().difference(state.openedAt!);
        final remaining =
        elapsed >= duration ? duration : duration - elapsed;
        state.timer = Timer(remaining, () {
          final value = state.pending;
          final src = state.pendingPulse;
          state.clearPending();
          if (value == null || src == null || future == null) return;
          state.openedAt = DateTime.now();
          future(
            result: _fromPayload(value, src, cell, 'Throttle.trailing'),
            token: token,
          );
        });
      }

      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        final payload = typed.payload as S;
        final now = DateTime.now();

        if (state.openedAt == null ||
            now.difference(state.openedAt!) >= duration) {
          state.openedAt = now;
          state.clearPending();
          if (leading) {
            if (trailing) armTrailing(future, token, cell);
            return _mark(typed, 'Throttle.leading');
          }
          state.pending = payload;
          state.pendingPulse = typed;
          armTrailing(future, token, cell);
          return null;
        }

        if (trailing) {
          state.pending = payload;
          state.pendingPulse = typed;
          if (state.timer?.isActive != true) {
            armTrailing(future, token, cell);
          }
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ThrottleLeading
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only the first pulse of each window
/// (lodash `leading: true, trailing: false`).
///
/// [ThrottleLeading] acts as a **Leading-Only Rate Limiter**. It emits
/// the first pulse in each time window and drops all subsequent pulses
/// until the window closes.
///
/// ### When to use
/// Use [ThrottleLeading] when:
/// - You only care about the first action in each window
/// - You're implementing click prevention with rate limiting
/// - You want to prevent spam but keep responsiveness
/// - You're implementing a "once per window" pattern
/// - You're rate limiting with immediate feedback
/// - You're implementing a throttle for UI actions
/// - You're preventing duplicate submissions with a cooldown
///
/// ### How it works
/// 1. The first pulse in a window is emitted immediately.
/// 2. All subsequent pulses in the window are dropped.
/// 3. When the window closes, the next pulse starts a new window.
/// 4. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Leading-Only**: Only the first pulse in each window is emitted.
/// - **Drop While Active**: Subsequent pulses are dropped while the window
///   is open.
/// - **State Persistence**: The instruction maintains the window state.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the window state is stored.
///
/// ### Example: Button Click Throttle
/// ```dart
/// final clicks = Cell.ingress<void>();
/// val throttled = ThrottleLeading<void>(
///   Duration(seconds: 1)
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // emits immediately
/// clicks.emit(null); // dropped (window open)
/// clicks.emit(null); // dropped (window open)
/// // after 1 second, the next click will emit
/// ```
///
/// ### Parameters:
/// - [duration]: **The Time Window.** The cooldown period after each emission.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Throttle]: For leading + trailing throttling.
/// - [ThrottleTrailing]: For trailing-only throttling.
/// - [DebounceLeadingOnly]: For leading-only debounce.
class ThrottleLeading<S> extends Throttle<S> {
  /// Creates a [ThrottleLeading] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Time Window.** The cooldown period after each emission.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val throttleLeading = ThrottleLeading<void>(
  ///   Duration(seconds: 1),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ThrottleLeading(
      super.duration, {
        super.onError,
        super.user,
      }) : super(
    leading: true,
    trailing: false,
  );
}

// ─────────────────────────────────────────────────────────────
// ThrottleTrailing
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only the last pulse of each window
/// (Rx trailing `throttleTime`).
///
/// [ThrottleTrailing] acts as a **Trailing-Only Rate Limiter**. It skips
/// the first pulse in each window and emits the last pulse when the window
/// closes.
///
/// ### When to use
/// Use [ThrottleTrailing] when:
/// - You only care about the final value in each window
/// - You're implementing periodic sampling
/// - You're collecting the latest state at regular intervals
/// - You're implementing rate-limited updates with trailing values
/// - You're doing periodic reporting of the latest value
/// - You're implementing a heartbeat with the latest data
/// - You're reducing frequency while preserving the latest value
///
/// ### How it works
/// 1. The first pulse in a window starts the window but is not emitted.
/// 2. Subsequent pulses in the window update the pending value.
/// 3. When the window closes, the pending value is emitted.
/// 4. The next pulse starts a new window.
/// 5. The instruction preserves causal provenance.
///
/// ### Comparison with AuditTime
/// | Feature | ThrottleTrailing | AuditTime |
/// |---------|------------------|-----------|
/// | **Window** | Fixed | Fixed |
/// | **Emission** | Last in window | Last in window |
/// | **Use Case** | Rate limiting | Periodic sampling |
/// | **First Pulse** | Not emitted | Not emitted |
///
/// ### Non‑obvious
/// - **Trailing-Only**: Only the last pulse in each window is emitted.
/// - **Silent First**: The first pulse in a window is not emitted.
/// - **Pending Value**: Only the most recent value in the window is kept.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
///
/// ### Example: Periodic Sampling
/// ```dart
/// final sensorData = Cell.ingress<SensorReading>();
/// val sampled = ThrottleTrailing<SensorReading>(
///   Duration(milliseconds: 100)
/// ).toHandle(source: sensorData.cell);
///
/// // Emits the latest reading every 100ms
/// // First reading in each window is skipped
/// ```
///
/// ### Parameters:
/// - [duration]: **The Time Window.** The interval between emissions.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Throttle]: For leading + trailing throttling.
/// - [ThrottleLeading]: For leading-only throttling.
/// - [AuditTime]: For window-based sampling.
class ThrottleTrailing<S> extends Throttle<S> {
  /// Creates a [ThrottleTrailing] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Time Window.** The interval between emissions.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val throttleTrailing = ThrottleTrailing<int>(
  ///   Duration(milliseconds: 100),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ThrottleTrailing(
      super.duration, {
        super.onError,
        super.user,
      }) : super(
    leading: false,
    trailing: true,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for throttle operators.
class _WindowState<S> {
  S? pending;
  Pulse? pendingPulse;
  Timer? timer;
  DateTime? openedAt;

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

/// A demonstration of the [Throttle] instruction and related operators
/// showing their behavior in various rate limiting scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Throttle Operators Demo ───────────────────────────────────
///
/// 1. Throttle - leading + trailing
///    [Throttle] 1
///    [Throttle] 3
///
/// 2. ThrottleLeading - first of window
///    [ThrottleLeading] 1
///
/// 3. ThrottleTrailing - last of window
///    [ThrottleTrailing] 3
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
/// 1. **Throttle - leading + trailing**: Shows full throttling behavior.
///    The first value is emitted immediately, and the last value is emitted
///    after the window closes. `1, 2, 3` → `1, 3`
///
/// 2. **ThrottleLeading - first of window**: Shows leading-only throttling.
///    Only the first value in each window is emitted. `1, 2, 3` → `1`
///
/// 3. **ThrottleTrailing - last of window**: Shows trailing-only throttling.
///    Only the last value in each window is emitted. `1, 2, 3` → `3`
///
/// ### Key Takeaways
/// - Throttle uses fixed windows that do not reset on each pulse.
/// - Leading emits the first value immediately.
/// - Trailing emits the last value when the window closes.
/// - ThrottleLeading emits only the first value.
/// - ThrottleTrailing emits only the last value.
/// - Throttle (with both) emits the first and last.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Throttle Operators Demo ───────────────────────────────────\n');

  print('1. Throttle - leading + trailing');
  final a = Cell.ingress<int>();
  final both = Throttle<int>(const Duration(milliseconds: 50))
      .toHandle(source: a.cell);
  final bObs = Cell.observe(
    source: both.cell,
    effect: (Pulse p) => print('   [Throttle] ${p.payload}'),
  );
  await a.emitAsync(1);
  await a.emitAsync(2);
  await a.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  bObs.stop();
  print('');

  print('2. ThrottleLeading - first of window');
  final b = Cell.ingress<int>();
  final lead = ThrottleLeading<int>(const Duration(milliseconds: 50))
      .toHandle(source: b.cell);
  final lObs = Cell.observe(
    source: lead.cell,
    effect: (Pulse p) => print('   [ThrottleLeading] ${p.payload}'),
  );
  await b.emitAsync(1);
  await b.emitAsync(2);
  await b.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  lObs.stop();
  print('');

  print('3. ThrottleTrailing - last of window');
  final c = Cell.ingress<int>();
  final trail = ThrottleTrailing<int>(const Duration(milliseconds: 50))
      .toHandle(source: c.cell);
  final tObs = Cell.observe(
    source: trail.cell,
    effect: (Pulse p) => print('   [ThrottleTrailing] ${p.payload}'),
  );
  await c.emitAsync(1);
  await c.emitAsync(2);
  await c.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}