// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that wait for silence or a clock (Rx `debounce` family).
///
/// These operators control the timing of emissions by waiting for periods of
/// silence or by sampling at fixed intervals. They are essential for handling
/// high-frequency events and reducing noise in reactive streams.
///
/// | Operator | Rx analogue | Emits |
/// |---|---|---|
/// | [Debounce] | `debounceTime` | last value after [duration] of silence |
/// | [DebounceLeading] | leading + trailing debounce | first immediately, last after silence |
/// | [DebounceLeadingOnly] | leading debounce | first of a burst only |
/// | [DebounceWith] | `debounce` | last value after a per-item duration |
/// | [AuditTime] | `auditTime` | last value at the end of each window |
/// | [SampleTime] | `sampleTime` | last value on a fixed period |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef DebounceErrorHandler = void Function(Object error, StackTrace? stackTrace);

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
// Debounce
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the last value after a period of
/// silence (Rx `debounceTime`).
///
/// [Debounce] acts as a **Silence-Based Emitter**. It waits for a specified
/// period of inactivity before emitting the latest value. Each new value
/// resets the timer, ensuring that only the final value after a burst of
/// activity is emitted.
///
/// ### When to use
/// Use [Debounce] when you need to wait for stability before emitting:
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
/// - **Stabilizing Sensor Data**: Wait for sensor data to stabilize
///
/// ### Choosing Between Debounce Patterns
/// - **Use [Debounce]** for **Trailing-Only Debounce**: When you only care
///   about the final value after a burst.
/// - **Use [DebounceLeading]** for **Leading + Trailing**: When you want
///   immediate feedback and a final value after silence.
/// - **Use [DebounceLeadingOnly]** for **Leading-Only**: When you only care
///   about the first value of a burst.
/// - **Use [DebounceWith]** for **Per-Item Duration**: When each value
///   needs its own silence window.
/// - **Use [AuditTime]** for **Window-Based**: When you want the last value
///   at the end of a fixed window.
/// - **Use [SampleTime]** for **Periodic Sampling**: When you want the last
///   value on a fixed schedule.
///
/// ### Comparison with Other Operators
/// | Operator | Behavior | Use Case |
/// |----------|----------|----------|
/// | **Debounce** | Last after silence | Search, validation |
/// | **DebounceLeading** | First + last | Immediate feedback |
/// | **DebounceLeadingOnly** | First only | Click prevention |
/// | **DebounceWith** | Per-item duration | Variable delays |
/// | **AuditTime** | Last in window | Periodic updates |
/// | **SampleTime** | Last on tick | Fixed-rate sampling |
/// | **Throttle** | First in window | Rate limiting |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked against [S].
/// 2. The timer is reset to the full [duration] on each new value.
/// 3. When the timer completes without interruption, the latest value is emitted.
/// 4. The instruction preserves causal provenance.
/// 5. Only the final value in each burst is emitted.
/// 6. The instruction maintains the pending value and timer state.
///
/// ### Non‑obvious
/// - **Silence Window**: The timer resets on every new pulse.
/// - **Pending Value**: Only the most recent value is emitted.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Order Preservation**: Only the final value in each burst is emitted.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
/// - **Composability**: Can be chained with other operators.
/// - **Backpressure**: The instruction provides natural backpressure by
///   discarding intermediate values.
///
/// ### Example: Search Input
/// ```dart
/// final search = Cell.ingress<String>();
/// final debounced = Debounce<String>(
///   Duration(milliseconds: 300)
/// ).toHandle(source: search.cell);
///
/// search.emit('h');    // resets timer
/// search.emit('he');   // resets timer
/// search.emit('hel');  // resets timer
/// search.emit('hell'); // resets timer
/// search.emit('hello'); // resets timer
/// // after 300ms, emits 'hello'
/// ```
///
/// ### Example: Auto-Save
/// ```dart
/// final document = Cell.ingress<Document>();
/// final autoSave = Debounce<Document>(
///   Duration(seconds: 2)
/// ).toHandle(source: document.cell);
///
/// document.emit(updatedDoc); // resets timer
/// // after 2 seconds of silence, auto-save triggers
/// ```
///
/// ### Example: Form Validation
/// ```dart
/// final formData = Cell.ingress<FormData>();
/// final validated = Debounce<FormData>(
///   Duration(milliseconds: 500)
/// ).toHandle(source: formData.cell);
/// ```
///
/// ### Parameters:
/// - [duration]: **The Silence Window.** The period of inactivity required
///   before emission.
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
/// - [DebounceLeading]: For immediate leading emission with trailing debounce.
/// - [DebounceLeadingOnly]: For only the first value of a burst.
/// - [DebounceWith]: For per-item silence windows.
/// - [AuditTime]: For window-based emissions.
/// - [SampleTime]: For periodic sampling.
/// - [Throttle]: For rate limiting.
class Debounce<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Debounce] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Silence Window.** The period of inactivity required
  ///   before emission.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final debounce = Debounce<String>(
  ///   Duration(milliseconds: 300),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// DebounceLeading
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the first pulse of a burst immediately,
/// then the last pulse after [duration] of silence.
///
/// [DebounceLeading] acts as a **Leading + Trailing Debouncer**. It provides
/// immediate feedback for the first action in a burst, then waits for silence
/// before emitting the final value.
///
/// ### When to use
/// Use [DebounceLeading] when:
/// - You need immediate feedback on the first action
/// - You're implementing button debouncing with immediate response
/// - You want responsive UI interactions
/// - You're doing two-stage debouncing
/// - You need fast first response, controlled subsequent
/// - You're handling user actions that need immediate feedback
/// - You're implementing click handling with debounce
/// - You're building real-time search with instant first result
///
/// ### How it works
/// 1. The first pulse is emitted immediately.
/// 2. A timer starts for the [duration].
/// 3. Subsequent pulses during the timer are buffered.
/// 4. When the timer completes, the last buffered pulse is emitted.
/// 5. The cycle repeats for the next burst.
/// 6. Results are emitted with immediate first, then debounced.
/// 7. The instruction preserves causal provenance.
///
/// ### DebounceLeading vs Debounce
/// | Feature | DebounceLeading | Debounce |
/// |---------|-----------------|----------|
/// | **First Pulse** | Emitted immediately | Delayed |
/// | **Subsequent** | Debounced | Debounced |
/// | **Responsiveness** | High | Delayed |
/// | **Use Case** | Buttons, immediate feedback | Search, validation |
///
/// ### Non‑obvious
/// - **Leading Emission**: The first pulse is always emitted immediately.
/// - **Trailing Emission**: The last pulse in a burst is emitted after silence.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Order Preservation**: Only the first and last values in each burst are
///   emitted.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
///
/// ### Example: Button Click Handling
/// ```dart
/// final clicks = Cell.ingress<void>();
/// final debounced = DebounceLeading<void>(
///   Duration(seconds: 1)
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // emits immediately
/// clicks.emit(null); // debounced
/// clicks.emit(null); // debounced
/// // after 1 second of silence, emits the last click
/// ```
///
/// ### Example: Form Input with Immediate Validation
/// ```dart
/// final formInput = Cell.ingress<String>();
/// val debouncedInput = DebounceLeading<String>(
///   Duration(milliseconds: 500)
/// ).toHandle(source: formInput.cell);
///
/// formInput.emit('a'); // emits immediately
/// formInput.emit('ab'); // debounced
/// // after 500ms, emits 'ab'
/// ```
///
/// ### Parameters:
/// - [duration]: **The Debounce Window.** The silence period after the
///   leading emission.
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
/// - [Debounce]: For standard debouncing.
/// - [DebounceLeadingOnly]: For only the first value.
/// - [Throttle]: For rate limiting.
class DebounceLeading<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DebounceLeading] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Debounce Window.** The silence period after the
  ///   leading emission.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final debounceLeading = DebounceLeading<void>(
  ///   Duration(seconds: 1),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// DebounceLeadingOnly
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only the first pulse of a burst
/// (lodash `leading: true, trailing: false`).
///
/// [DebounceLeadingOnly] acts as a **Leading-Only Debouncer**. It emits the
/// first pulse of a burst immediately and drops all subsequent pulses until
/// the silence window has passed.
///
/// ### When to use
/// Use [DebounceLeadingOnly] when:
/// - You only care about the first action in a burst
/// - You're implementing click prevention
/// - You want to prevent double-submission
/// - You're implementing rate limiting on the first action
/// - You're handling button clicks
/// - You're implementing a one-shot trigger
/// - You're preventing duplicate requests
/// - You're implementing a toggle action
///
/// ### How it works
/// 1. The first pulse in a burst is emitted immediately.
/// 2. A timer starts for the [duration].
/// 3. All subsequent pulses during the timer are dropped.
/// 4. When the timer completes, the instruction is ready for the next burst.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Leading-Only**: Only the first pulse in each burst is emitted.
/// - **Drop While Active**: Subsequent pulses are dropped while the timer is running.
/// - **State Persistence**: The instruction maintains only the timer state.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the timer is stored.
///
/// ### Example: Button Click Prevention
/// ```dart
/// final clicks = Cell.ingress<void>();
/// val onlyFirst = DebounceLeadingOnly<void>(
///   Duration(seconds: 1)
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // emits immediately
/// clicks.emit(null); // dropped (timer active)
/// clicks.emit(null); // dropped (timer active)
/// // after 1 second, the next click will emit
/// ```
///
/// ### Example: Toggle Action
/// ```dart
/// final toggles = Cell.ingress<bool>();
/// val toggleOnce = DebounceLeadingOnly<bool>(
///   Duration(milliseconds: 300)
/// ).toHandle(source: toggles.cell);
/// ```
///
/// ### Parameters:
/// - [duration]: **The Silence Window.** The period during which subsequent
///   pulses are dropped.
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
/// - [Debounce]: For trailing-only debounce.
/// - [DebounceLeading]: For leading + trailing debounce.
/// - [Throttle]: For rate limiting.
class DebounceLeadingOnly<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DebounceLeadingOnly] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Silence Window.** The period during which subsequent
  ///   pulses are dropped.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final debounceLeadingOnly = DebounceLeadingOnly<void>(
  ///   Duration(seconds: 1),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// DebounceWith
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that uses a per-item silence window
/// (Rx `debounce`).
///
/// [DebounceWith] acts as a **Dynamic Debouncer**. Each value chooses its
/// own silence window via [durationOf], allowing for variable debounce
/// times based on the payload.
///
/// ### When to use
/// Use [DebounceWith] when:
/// - Different values need different debounce times
/// - You're implementing context-aware debouncing
/// - You're handling variable-rate events
/// - You're processing data with different priorities
/// - You're implementing adaptive debouncing
/// - You're handling events with different urgency levels
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [durationOf] function is called with the payload to get the
///    silence window for this specific value.
/// 3. The timer is reset with the computed duration.
/// 4. When the timer completes, the latest value is emitted.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Per-Item Duration**: Each value can have a different silence window.
/// - **Dynamic Timing**: The debounce time adapts to the payload.
/// - **Error Handling**: Errors in [durationOf] are reported via [onError].
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Variable Debounce
/// ```dart
/// final inputs = Cell.ingress<String>();
/// val debounced = DebounceWith<String>(
///   (s) => Duration(milliseconds: s.length * 50)
/// ).toHandle(source: inputs.cell);
///
/// inputs.emit('a'); // waits 50ms
/// inputs.emit('hello'); // waits 250ms
/// ```
///
/// ### Example: Priority-Based Debounce
/// ```dart
/// final events = Cell.ingress<{String type, int priority}>();
/// val priorityDebounce = DebounceWith<({String type, int priority})>(
///   (e) => Duration(milliseconds: e.priority == 1 ? 50 : 200)
/// ).toHandle(source: events.cell);
/// ```
///
/// ### Parameters:
/// - [durationOf]: **The Duration Provider.** Takes the payload and returns
///   the silence window for that specific value.
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
/// - [Debounce]: For fixed-duration debounce.
/// - [DebounceLeading]: For leading + trailing debounce.
/// - [DebounceLeadingOnly]: For leading-only debounce.
class DebounceWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DebounceWith] instruction with the specified [durationOf].
  ///
  /// ### Parameters:
  /// - [durationOf]: **The Duration Provider.** Takes the payload and returns
  ///   the silence window for that specific value.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final debounceWith = DebounceWith<String>(
  ///   (s) => Duration(milliseconds: s.length * 50),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
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
// AuditTime
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the last value at the end of each
/// recurring window (Rx `auditTime`).
///
/// [AuditTime] acts as a **Window-Based Emitter**. A new window starts
/// with the first pulse, and the last value seen during that window is
/// emitted when the window closes. A new window starts on the next pulse.
///
/// ### When to use
/// Use [AuditTime] when:
/// - You want to sample the last value in each time window
/// - You're implementing periodic updates
/// - You're collecting the latest state at regular intervals
/// - You're implementing rate-limited updates
/// - You're doing periodic reporting
/// - You're implementing a heartbeat with the latest data
///
/// ### How it works
/// 1. The first pulse starts a timer for the [duration].
/// 2. All pulses during the window update the pending value.
/// 3. When the timer completes, the last value is emitted.
/// 4. The next pulse starts a new window.
/// 5. The instruction preserves causal provenance.
///
/// ### AuditTime vs Debounce
/// | Feature | AuditTime | Debounce |
/// |---------|-----------|----------|
/// | **Behavior** | Fixed windows | Reset on each pulse |
/// | **Window** | Fixed [duration] | Reset on each pulse |
/// | **Use Case** | Periodic sampling | Wait for silence |
///
/// ### Non‑obvious
/// - **Fixed Windows**: The window duration is fixed and does not reset
///   on each pulse.
/// - **Last Value**: Only the last value in each window is emitted.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
///
/// ### Example: Periodic Updates
/// ```dart
/// final events = Cell.ingress<int>();
/// val audited = AuditTime<int>(
///   Duration(seconds: 1)
/// ).toHandle(source: events.cell);
///
/// events.emit(1); // starts window
/// events.emit(2); // updates pending
/// events.emit(3); // updates pending
/// // after 1 second, emits 3
/// // next event starts new window
/// ```
///
/// ### Example: Telemetry Sampling
/// ```dart
/// final telemetry = Cell.ingress<Metric>();
/// val sampled = AuditTime<Metric>(
///   Duration(seconds: 5)
/// ).toHandle(source: telemetry.cell);
/// ```
///
/// ### Parameters:
/// - [duration]: **The Window Duration.** The length of each sampling window.
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
/// - [Debounce]: For silence-based emission.
/// - [SampleTime]: For fixed-period sampling.
/// - [Throttle]: For rate limiting.
class AuditTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [AuditTime] instruction with the specified [duration].
  ///
  /// ### Parameters:
  /// - [duration]: **The Window Duration.** The length of each sampling window.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final auditTime = AuditTime<int>(
  ///   Duration(seconds: 1),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  AuditTime(
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
        if (state.timer?.isActive == true) return null;

        state.timer = Timer(duration, () {
          final value = state.pending;
          final src = state.pendingPulse;
          state.clearPending();
          if (value == null || src == null) return;
          future!(
            result: _fromPayload(value, src, cell, 'AuditTime'),
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
// SampleTime
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits the last value seen since the previous
/// tick on a fixed period (Rx `sampleTime`).
///
/// [SampleTime] acts as a **Periodic Sampler**. On every [period], it emits
/// the last value seen since the previous tick. If no values were seen, nothing
/// is emitted.
///
/// ### When to use
/// Use [SampleTime] when:
/// - You want to sample the latest value at a fixed rate
/// - You're implementing a heartbeat with the latest data
/// - You're doing periodic reporting
/// - You're implementing real-time dashboards
/// - You're collecting metrics at fixed intervals
/// - You're implementing animation frames
/// - You're doing fixed-rate sampling of sensor data
///
/// ### How it works
/// 1. The first pulse starts a periodic timer.
/// 2. Each pulse updates the pending value.
/// 3. On each timer tick, the pending value is emitted.
/// 4. The pending value is cleared after emission.
/// 5. The instruction preserves causal provenance.
///
/// ### SampleTime vs AuditTime
/// | Feature | SampleTime | AuditTime |
/// |---------|------------|-----------|
/// | **Start** | First pulse starts periodic timer | First pulse starts a one-shot timer |
/// | **Emission** | On every tick | At the end of each window |
/// | **Window** | Overlapping | Non-overlapping |
/// | **Use Case** | Fixed-rate sampling | Window-based sampling |
///
/// ### Non‑obvious
/// - **Periodic Timer**: The timer runs continuously once started.
/// - **Fixed Rate**: Emissions occur at a fixed rate regardless of input.
/// - **No Emission**: If no values were seen, nothing is emitted.
/// - **State Persistence**: The instruction maintains the pending value and timer.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the pending value and timer are stored.
///
/// ### Example: Fixed-Rate Dashboard Updates
/// ```dart
/// final sensorData = Cell.ingress<SensorReading>();
/// val sampled = SampleTime<SensorReading>(
///   Duration(milliseconds: 100)
/// ).toHandle(source: sensorData.cell);
///
/// // Emits the latest reading every 100ms
/// ```
///
/// ### Example: Animation Frame
/// ```dart
/// final positions = Cell.ingress<Point>();
/// val animation = SampleTime<Point>(
///   Duration(milliseconds: 16) // ~60fps
/// ).toHandle(source: positions.cell);
/// ```
///
/// ### Parameters:
/// - [period]: **The Sampling Period.** The interval between emissions.
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
/// - [AuditTime]: For window-based sampling.
/// - [Debounce]: For silence-based emission.
/// - [Throttle]: For rate limiting.
class SampleTime<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SampleTime] instruction with the specified [period].
  ///
  /// ### Parameters:
  /// - [period]: **The Sampling Period.** The interval between emissions.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final sampleTime = SampleTime<int>(
  ///   Duration(milliseconds: 100),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SampleTime(
      Duration period, {
        DebounceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _GateState<S>();
      var armed = false;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;

        state.pending = typed.payload as S;
        state.pendingPulse = typed;

        if (armed) return null;
        armed = true;
        state.timer = Timer.periodic(period, (_) {
          final value = state.pending;
          final src = state.pendingPulse;
          state.pending = null;
          state.pendingPulse = null;
          if (value == null || src == null) return;
          future!(
            result: _fromPayload(value, src, cell, 'SampleTime'),
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
class _GateState<S> {
  S? pending;
  Pulse? pendingPulse;
  Timer? timer;

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

/// A demonstration of the [Debounce] instruction and related operators
/// showing their behavior in various timing scenarios.
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
/// 5. AuditTime - last of the window
///    [AuditTime] 3
///
/// 6. SampleTime - last at the tick
///    [SampleTime] 2
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
/// 1. **Debounce - last after silence**: Shows trailing-only debounce.
///    Only the final value after a period of silence is emitted.
///    Intermediate values are dropped.
///
/// 2. **DebounceLeading - first then last**: Shows leading + trailing
///    debounce. The first value is emitted immediately, and the last
///    value is emitted after silence.
///
/// 3. **DebounceLeadingOnly - first of burst**: Shows leading-only debounce.
///    Only the first value of a burst is emitted; subsequent values are
///    dropped.
///
/// 4. **DebounceWith - per-value wait**: Shows dynamic debounce with
///    per-item duration. Each value has its own silence window.
///
/// 5. **AuditTime - last of the window**: Shows window-based sampling.
///    The last value in each window is emitted when the window closes.
///
/// 6. **SampleTime - last at the tick**: Shows fixed-period sampling.
///    The last value seen since the previous tick is emitted on each tick.
///
/// ### Key Takeaways
/// - All debounce operators use timers to control emissions.
/// - Debounce emits only after silence (trailing).
/// - DebounceLeading emits first immediately, then after silence.
/// - DebounceLeadingOnly emits only the first of a burst.
/// - DebounceWith allows per-value dynamic timing.
/// - AuditTime samples at the end of fixed windows.
/// - SampleTime samples at fixed intervals.
/// - All operators preserve causal provenance via EvolvedPulse.
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

  print('5. AuditTime - last of the window');
  final auditIn = Cell.ingress<int>();
  final audited = AuditTime<int>(const Duration(milliseconds: 50))
      .toHandle(source: auditIn.cell);
  final aObs = Cell.observe(
    source: audited.cell,
    effect: (Pulse p) => print('   [AuditTime] ${p.payload}'),
  );
  await auditIn.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await auditIn.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await auditIn.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  aObs.stop();
  print('');

  print('6. SampleTime - last at the tick');
  final sampleIn = Cell.ingress<int>();
  final sampled = SampleTime<int>(const Duration(milliseconds: 40))
      .toHandle(source: sampleIn.cell);
  final sObs = Cell.observe(
    source: sampled.cell,
    effect: (Pulse p) => print('   [SampleTime] ${p.payload}'),
  );
  await sampleIn.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await sampleIn.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  sObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}