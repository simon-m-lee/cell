// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Sample/Audit Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that emit a **held** value on a sampler
/// (Rx `sample` / `audit` family).
///
/// | Operator | When it emits | Which value |
/// |---|---|---|
/// | [Sample] | [notifier] pulses | latest source since last emit |
/// | [SampleTime] | every [period] | latest source in that window |
/// | [Audit] | after [notifier] following a source | that source value |
/// | [AuditTime] | [duration] after a source pulse | last source in that silence |
///
/// [Sample] ignores notifier ticks while nothing new has arrived.
/// [AuditTime] is "debounce of the latest value after it moved".
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for sample/audit operators.
///
/// Called when an error occurs during sampling or auditing operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = SampleErrorHandler((error, stack) {
///   print('Sample error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef SampleErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
      SampleErrorHandler? onError,
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

/// Internal state for async emission.
///
/// [_Emit] stores the continuation callback and token for operators
/// that emit asynchronously.
class _Emit {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
}

// ─────────────────────────────────────────────────────────────
// Sample - Emit Latest on Notifier Pulse
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits the latest source value whenever
/// [notifier] pulses, if one is pending (Rx `sample`).
///
/// [Sample] holds the latest source value and only emits it when the
/// notifier pulses. If no new values have arrived since the last
/// emission, the notifier pulse is ignored.
///
/// ### When to use
/// Use [Sample] when you want to emit the latest value at specific
/// times defined by a notifier.
///
/// - **UI Updates**: Emitting the latest state on a timer or animation frame.
/// - **Throttled Output**: Outputting the latest value at a fixed rate.
/// - **Event Sampling**: Sampling events on a separate signal.
/// - **Real-time Dashboards**: Updating dashboards at a fixed rate.
/// - **Sensor Data**: Sampling sensor data at a fixed rate.
///
/// ### Choosing Between Sample/Audit Variants
/// - **Use [Sample]** for **Notifier-Based Sampling**: When the
///   sampling time is controlled by a notifier cell.
/// - **Use [SampleTime]** for **Time-Based Sampling**: When the
///   sampling happens at a fixed interval.
/// - **Use [Audit]** for **Audit on Notifier**: When you wait for a
///   notifier after a source pulse.
/// - **Use [AuditTime]** for **Time-Based Audit**: When you wait for
///   a duration after a source pulse.
///
/// ### Comparison with Other Operators
/// | Operator | Trigger | Emits | Holds |
/// |----------|---------|-------|-------|
/// | **Sample** | Notifier pulse | Latest if pending | Yes |
/// | **SampleTime** | Timer tick | Latest if pending | Yes |
/// | **Audit** | Notifier after source | Source value | Yes (one) |
/// | **AuditTime** | Duration after source | Latest in window | Yes (one) |
///
/// ### How it works
/// 1. Each source pulse is type-checked and stored as the pending value.
/// 2. When the [notifier] cell pulses:
///    a. If there's a pending value, it's emitted.
///    b. The pending value is cleared.
///    c. If no pending value, nothing is emitted.
/// 3. Each emitted value gets the step `'Sample'` for provenance.
///
/// ### Non‑obvious
/// - **Pending Only**: Values are only emitted if they arrived since
///   the last emission.
/// - **Ignored Ticks**: Notifier ticks with no pending value are ignored.
/// - **Latest Only**: Only the latest value is held; older values are
///   overwritten.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Example: Sampling on Notifier
/// ```dart
/// final source = Cell.ingress<int>();
/// final tick = Cell.ingress<void>();
///
/// final sampled = Sample<int>(tick.cell).toHandle(source: source.cell);
///
/// source.emit(1);
/// source.emit(2);
/// tick.emit(null); // -> 2
/// source.emit(3);
/// // tick.emit(null); // -> 3
/// ```
///
/// ### Parameters:
/// - [notifier]: **Notifier Cell.** The cell that triggers sampling.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
///
/// ### Returns:
/// A [FlowInstruction] that samples on notifier pulses.
///
/// ### See Also:
/// - [SampleTime]: For time-based sampling.
/// - [Audit]: For audit on notifier.
/// - [AuditTime]: For time-based audit.
class Sample<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Sample(
      Cell notifier, {
        SampleErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      Pulse? pending;
      var armed = false;

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed != null) pending = typed;
        if (!armed) {
          armed = true;
          Cell.observe(
            source: notifier,
            effect: (Pulse _) {
              final held = pending;
              if (held == null) return;
              pending = null;
              emit.future?.call(
                result: held.withStep('Sample'),
                token: emit.token,
              );
            },
          );
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// SampleTime - Time-Based Sampling
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits the latest source value every
/// [period] after the first pulse (Rx `sample` with time).
///
/// [SampleTime] is similar to [Sample] but the sampling is driven by
/// a periodic timer instead of a notifier cell.
///
/// ### When to use
/// Use [SampleTime] when you want to sample the latest value at a
/// fixed interval.
///
/// - **UI Throttling**: Throttling UI updates to a fixed frame rate.
/// - **Sensor Sampling**: Sampling sensor data at a fixed rate.
/// - **Heartbeat**: Emitting the latest state on a heartbeat.
/// - **Real-time Dashboards**: Updating dashboards at a fixed rate.
/// - **Performance**: Reducing update frequency for performance.
///
/// ### Example: Periodic Sampling
/// ```dart
/// final source = Cell.ingress<int>();
///
/// final sampled = SampleTime<int>(
///   Duration(milliseconds: 100),
/// ).toHandle(source: source.cell);
///
/// source.emit(1);
/// source.emit(2);
/// // After 100ms: -> 2
/// source.emit(3);
/// // After 100ms: -> 3
/// ```
///
/// ### How it works
/// 1. The first source pulse starts the timer.
/// 2. Each source pulse updates the pending value.
/// 3. Every [period], the timer fires:
///    a. If there's a pending value, it's emitted.
///    b. The pending value is cleared.
/// 4. The timer continues indefinitely.
/// 5. Each emitted value gets the step `'SampleTime'` for provenance.
///
/// ### Non‑obvious
/// - **Lazy Start**: The timer starts on the first pulse.
/// - **Continuous Timer**: The timer runs until the instruction is disposed.
/// - **Pending Only**: Values are only emitted if they arrived since
///   the last emission.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [period]: **Sampling Period.** The interval between samples.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
///
/// ### Returns:
/// A [FlowInstruction] that samples at a fixed interval.
///
/// ### See Also:
/// - [Sample]: For notifier-based sampling.
/// - [Audit]: For audit on notifier.
/// - [AuditTime]: For time-based audit.
/// - [Interval]: For emitting values at a fixed interval.
class SampleTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  SampleTime(
      Duration period, {
        SampleErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      Pulse? pending;
      var armed = false;

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed != null) pending = typed;
        if (!armed) {
          armed = true;
          Timer.periodic(period, (_) {
            final held = pending;
            if (held == null) return;
            pending = null;
            emit.future?.call(
              result: held.withStep('SampleTime'),
              token: emit.token,
            );
          });
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Audit - Audit on Notifier
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that after a source pulse, waits for the next
/// [notifier] pulse and emits the latest source (Rx `audit`).
///
/// [Audit] is similar to [Sample] but the audit is triggered by the
/// notifier after a source pulse has arrived.
///
/// ### When to use
/// Use [Audit] when you want to audit a value after a source pulse
/// and wait for a notifier to confirm.
///
/// - **Confirmation**: Waiting for a confirmation before emitting.
/// - **Gate Control**: Emitting only when a gate signal arrives.
/// - **Synchronization**: Synchronizing emission with a notifier.
/// - **Validation**: Validating values before emission.
/// - **Conditional Emission**: Emitting only under certain conditions.
///
/// ### Example: Audit on Gate
/// ```dart
/// final source = Cell.ingress<int>();
/// final gate = Cell.ingress<void>();
///
/// final audited = Audit<int>(gate.cell).toHandle(source: source.cell);
///
/// source.emit(1);
/// source.emit(2);
/// gate.emit(null); // -> 2
/// // gate.emit(null); // ignored (no pending)
/// ```
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
/// 5. Each emitted value gets the step `'Audit'` for provenance.
///
/// ### Non‑obvious
/// - **Waiting Flag**: The waiting flag tracks if a source pulse
///   has arrived since the last audit.
/// - **One-Time Audit**: Each source pulse can only be audited once.
/// - **Ignored Ticks**: Notifier ticks with no waiting are ignored.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [notifier]: **Notifier Cell.** The cell that triggers the audit.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
///
/// ### Returns:
/// A [FlowInstruction] that audits on notifier.
///
/// ### See Also:
/// - [Sample]: For sampling on notifier.
/// - [SampleTime]: For time-based sampling.
/// - [AuditTime]: For time-based audit.
class Audit<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Audit(
      Cell notifier, {
        SampleErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      Pulse? pending;
      var waiting = false;
      var armed = false;

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed != null) {
          pending = typed;
          waiting = true;
        }
        if (!armed) {
          armed = true;
          Cell.observe(
            source: notifier,
            effect: (Pulse _) {
              if (!waiting) return;
              final held = pending;
              if (held == null) return;
              waiting = false;
              pending = null;
              emit.future?.call(
                result: held.withStep('Audit'),
                token: emit.token,
              );
            },
          );
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// AuditTime - Time-Based Audit
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that after a source pulse, waits [duration]
/// then emits the latest value seen in that window (Rx `auditTime`).
///
/// [AuditTime] is similar to "debounce of the latest value after it
/// moved". It waits for a period of silence after the last pulse
/// before emitting the latest value.
///
/// ### When to use
/// Use [AuditTime] when you want to wait for a period of silence
/// after the last pulse before emitting.
///
/// - **Debouncing**: Debouncing the latest value after activity stops.
/// - **Stabilization**: Waiting for values to stabilize.
/// - **Rate Limiting**: Limiting the rate of emissions.
/// - **Idle Detection**: Detecting idle periods.
/// - **User Input**: Waiting for user to stop typing.
///
/// ### Example: Audit Time
/// ```dart
/// final source = Cell.ingress<int>();
///
/// final audited = AuditTime<int>(
///   Duration(milliseconds: 100),
/// ).toHandle(source: source.cell);
///
/// source.emit(1);
/// source.emit(2);
/// // After 100ms: -> 2 (latest in window)
/// ```
///
/// ### How it works
/// 1. Each source pulse is type-checked and stored as the pending value.
/// 2. If there's already a scheduled timer, it's not reset (one-shot).
/// 3. After [duration], the pending value is emitted.
/// 4. The timer is a one-shot, not periodic.
/// 5. Each emitted value gets the step `'AuditTime'` for provenance.
///
/// ### Non‑obvious
/// - **One-Shot Timer**: The timer fires once and stops.
/// - **No Reset**: Unlike debounce, the timer is not reset on new pulses.
/// - **Latest in Window**: The latest value in the window is emitted.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Scheduled Flag**: Prevents multiple timers from running.
///
/// ### Parameters:
/// - [duration]: **Audit Duration.** The time to wait after a source
///   pulse before emitting the latest value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
///
/// ### Returns:
/// A [FlowInstruction] that audits after a duration.
///
/// ### See Also:
/// - [Sample]: For sampling on notifier.
/// - [SampleTime]: For time-based sampling.
/// - [Audit]: For audit on notifier.
/// - [Debounce]: For resetting the timer on each pulse.
class AuditTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AuditTime(
      Duration duration, {
        SampleErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final emit = _Emit();
      Pulse? pending;
      var scheduled = false;

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        pending = typed;
        if (scheduled) return null;
        scheduled = true;
        Future<void>.delayed(duration, () {
          scheduled = false;
          final held = pending;
          pending = null;
          if (held == null) return;
          emit.future?.call(
            result: held.withStep('AuditTime'),
            token: emit.token,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Sample] instruction and related operators
/// showing their behavior in various sampling and auditing scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Sample / Audit Operators Demo ─────────────────────────────
///
/// 1. Sample
///    [Sample] 2
///
/// 2. SampleTime
///    [SampleTime] 2
///
/// 3. Audit
///    [Audit] 1
///
/// 4. AuditTime
///    [AuditTime] 2
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
/// 1. **Sample - Notifier-Based Sampling**: Shows sampling on a
///    notifier pulse. Values 1 and 2 are emitted, but only the latest
///    (2) is sampled when the notifier pulses.
///
/// 2. **SampleTime - Time-Based Sampling**: Shows periodic sampling.
///    Values 1 and 2 are emitted, and after the period, the latest (2)
///    is sampled.
///
/// 3. **Audit - Audit on Notifier**: Shows auditing on a notifier.
///    The source emits 1, and when the notifier pulses, 1 is emitted.
///
/// 4. **AuditTime - Time-Based Audit**: Shows auditing after a
///    duration. Values 1 and 2 are emitted, and after the duration,
///    the latest (2) is emitted.
///
/// ### Key Takeaways
/// - Sample emits the latest value on notifier pulses.
/// - SampleTime samples at a fixed interval.
/// - Audit waits for a notifier after a source pulse.
/// - AuditTime waits for a duration after a source pulse.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Sample ignores ticks with no pending value.
/// - AuditTime is a "debounce of the latest value after it moved".
///
/// ### Note on Timing
/// The demo uses short delays (30-60ms) for quick execution. In
/// production, you would typically use longer durations for
/// sampling and auditing.
Future<void> main() async {
  print('── Sample / Audit Operators Demo ─────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Sample - Notifier-Based Sampling
  // ─────────────────────────────────────────────────────────────────────
  print('1. Sample');

  final src = Cell.ingress<int>();
  final tick = Cell.ingress<void>();

  final sampled = Sample<int>(tick.cell).toHandle(source: src.cell);

  final sObs = Cell.observe(
    source: sampled.cell,
    effect: (Pulse p) => print('   [Sample] ${p.payload}'),
  );

  await src.emitAsync(1);
  await src.emitAsync(2);
  await tick.emitAsync(null);

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. SampleTime - Time-Based Sampling
  // ─────────────────────────────────────────────────────────────────────
  print('2. SampleTime');

  final timed = Cell.ingress<int>();

  final periodic = SampleTime<int>(
    const Duration(milliseconds: 40),
  ).toHandle(source: timed.cell);

  final tObs = Cell.observe(
    source: periodic.cell,
    effect: (Pulse p) => print('   [SampleTime] ${p.payload}'),
  );

  await timed.emitAsync(1);
  await timed.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 60));

  tObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. Audit - Audit on Notifier
  // ─────────────────────────────────────────────────────────────────────
  print('3. Audit');

  final aSrc = Cell.ingress<int>();
  final gate = Cell.ingress<void>();

  final audited = Audit<int>(gate.cell).toHandle(source: aSrc.cell);

  final aObs = Cell.observe(
    source: audited.cell,
    effect: (Pulse p) => print('   [Audit] ${p.payload}'),
  );

  await aSrc.emitAsync(1);
  await gate.emitAsync(null);

  aObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. AuditTime - Time-Based Audit
  // ─────────────────────────────────────────────────────────────────────
  print('4. AuditTime');

  final bSrc = Cell.ingress<int>();

  final auditedT = AuditTime<int>(
    const Duration(milliseconds: 30),
  ).toHandle(source: bSrc.cell);

  final atObs = Cell.observe(
    source: auditedT.cell,
    effect: (Pulse p) => print('   [AuditTime] ${p.payload}'),
  );

  await bSrc.emitAsync(1);
  await bSrc.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 50));

  atObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}