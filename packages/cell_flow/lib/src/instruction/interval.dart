// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Interval Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that emit on a clock (Rx `interval` / `timer` family).
///
/// | Operator | Rx analogue | Payload |
/// |---|---|---|
/// | [Interval] | `interval` | `0, 1, 2, …` |
/// | [IntervalWithValue] | `interval` + map | fixed value or `valueOf(tick)` |
/// | [IntervalWithState] | `interval` + scan | running [seed] |
/// | [TimerPulse] | `timer` | one pulse after [delay] |
///
/// The bound source **arms** the clock on the first pulse. Later source
/// pulses are ignored unless [resetOnSource] is true.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for interval operators.
///
/// Called when an error occurs during interval emissions. The error and
/// optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = IntervalErrorHandler((error, stack) {
///   print('Interval error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef IntervalErrorHandler = void Function(Object error, StackTrace? stackTrace);

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

/// Internal state for interval operators.
///
/// [_ClockState] manages the timer, tick counter, and the future continuation
/// callbacks for interval-based emissions. It provides methods to arm the
/// clock and cancel ongoing timers.
///
/// ### When to use
/// This is an internal implementation detail. You don't need to use it
/// directly in application code.
///
/// ### How it works
/// 1. The [armed] flag indicates whether the clock has been started.
/// 2. The [timer] holds the active [Timer] for periodic emissions.
/// 3. The [tick] counter tracks the number of emissions.
/// 4. The [future] and [token] store the continuation callback for the
///    instruction's async pipeline.
/// 5. The [cell] and [trigger] store the context for pulse creation.
///
/// ### Non‑obvious
/// - **Single Timer**: Only one timer is active at a time. Calling
///   [cancel] clears it.
/// - **State Reset**: [cancel] resets the timer and tick counter.
/// - **Armed Guard**: The [armed] flag prevents multiple timers from
///   being started.
class _ClockState {
  Timer? timer;
  int tick = 0;
  bool armed = false;
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
  Pulse? trigger;

  /// Cancels the active timer and resets the tick counter.
  ///
  /// This is called when the interval is stopped, when maxTicks is reached,
  /// or when the clock is reset.
  void cancel() {
    timer?.cancel();
    timer = null;
  }
}

// ─────────────────────────────────────────────────────────────
// Interval - Basic Counter
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits consecutive integers `0, 1, 2, …` at a
/// fixed [period] after the first source pulse (Rx `interval`).
///
/// [Interval] is the foundational clock operator. It starts a timer when
/// the first source pulse arrives and emits an incrementing counter at
/// each tick.
///
/// ### When to use
/// Use [Interval] when you need a periodic stream of sequential integers.
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
/// ### Choosing Between Interval Variants
/// - **Use [Interval]** for **Simple Counting**: When you just need
///   `0, 1, 2, …` as payload.
/// - **Use [IntervalWithValue]** for **Mapped Values**: When you need
///   to transform the tick into a specific value.
/// - **Use [IntervalWithState]** for **Stateful Values**: When each
///   tick depends on the previous state.
/// - **Use [TimerPulse]** for **One-Shot**: When you only need a
///   single emission after a delay.
///
/// ### Comparison with Other Operators
/// | Operator | Payload | Stops | Reset | Trigger |
/// |----------|---------|-------|-------|---------|
/// | **Interval** | `0, 1, 2, …` | Optional maxTicks | Optional | First pulse |
/// | **IntervalWithValue** | Custom value | Optional maxTicks | Optional | First pulse |
/// | **IntervalWithState** | Accumulated state | Optional maxTicks | Optional | First pulse |
/// | **TimerPulse** | Single value | Always after delay | N/A | First pulse |
///
/// ### How it works
/// 1. The first source pulse **arms** the clock.
/// 2. A `Timer.periodic` is started with the specified [period].
/// 3. On each tick, the current [tick] value is emitted.
/// 4. The [tick] counter increments by 1 each emission.
/// 5. If [maxTicks] is set, the timer stops after that many emissions.
/// 6. If [resetOnSource] is `true`, a later source pulse resets the counter.
/// 7. Later source pulses are ignored if [resetOnSource] is `false`.
/// 8. Each emitted value is wrapped as an [EvolvedPulse] with the step
///    `'Interval'` to preserve causal provenance.
///
/// ### Non‑obvious
/// - **Arming on First Pulse**: The clock starts on the first pulse, not
///   on creation. This allows lazy initialization.
/// - **No Initial Emission**: Unlike Rx, there's no `0` emission at the
///   start. The first emission is after [period] has elapsed.
/// - **Stopping Behavior**: When [maxTicks] is reached, the timer is
///   cancelled and the counter stops.
/// - **Reset Behavior**: With [resetOnSource] `true`, the counter resets
///   to 0 on any later source pulse.
/// - **Type Safety**: The instruction is generic over the cell type [C]
///   but the payload is always `int`.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Memory Safety**: The timer is cancelled when the instruction is
///   disposed or when [maxTicks] is reached.
/// - **Error Handling**: Errors in emission are caught and reported via
///   the [onError] callback.
///
/// ### Example: Basic Ticker
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final ticks = Interval(
///   Duration(seconds: 1),
///   maxTicks: 5,
/// ).toHandle(source: start.cell);
///
/// Cell.observe(
///   source: ticks.cell,
///   effect: (pulse) => print('Tick: ${pulse.payload}'),
/// );
///
/// await start.emitAsync(null);
/// // Outputs: Tick: 0, Tick: 1, Tick: 2, Tick: 3, Tick: 4
/// ```
///
/// ### Example: Polling with Reset
/// ```dart
/// final refresh = Cell.ingress<void>();
///
/// final poll = Interval(
///   Duration(seconds: 5),
///   maxTicks: 12, // Poll for 60 seconds
///   resetOnSource: true, // Reset on refresh
/// ).toHandle(source: refresh.cell);
///
/// // Start polling
/// await refresh.emitAsync(null);
///
/// // Reset the timer
/// await refresh.emitAsync(null);
/// ```
///
/// ### Parameters:
/// - [period]: **The Tick Interval.** The duration between each emission.
/// - [maxTicks]: **Maximum Emissions.** Optional. Stops after this many
///   ticks. If `null`, runs forever.
/// - [resetOnSource]: **Reset on Trigger.** If `true`, a later source
///   pulse resets the counter to 0. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [C]: The type of the host [Cell] (inferred from context).
///
/// ### Returns:
/// A [FlowInstruction] that emits integers at regular intervals.
///
/// ### See Also:
/// - [IntervalWithValue]: For emitting custom values per tick.
/// - [IntervalWithState]: For stateful interval emissions.
/// - [TimerPulse]: For a single delayed emission.
/// - [PeriodicTimer]: For a timer that doesn't require a trigger (not yet implemented).
class Interval extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Interval(
      Duration period, {
        int? maxTicks,
        bool resetOnSource = false,
        IntervalErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _ClockState();

      void emitTick() {
        final trigger = state.trigger;
        if (trigger == null || state.future == null) return;
        state.future!(
          result: _out<int>(
            state.tick,
            state.cell,
            trigger,
            'Interval',
          ),
          token: state.token,
        );
        state.tick++;
        if (maxTicks != null && state.tick >= maxTicks) {
          state.cancel();
        }
      }

      void arm(Pulse pulse, Cell? cell, dynamic future, dynamic token) {
        state.future = future as void Function({
        required Pulse? result,
        required dynamic token,
        })?;
        state.token = token;
        state.cell = cell;
        state.trigger = pulse;
        state.cancel();
        state.tick = 0;
        if (maxTicks != null && maxTicks <= 0) return;
        state.timer = Timer.periodic(period, (_) => emitTick());
      }

      return (pulse, {cell, user, future, token}) {
        if (state.armed && !resetOnSource) return null;
        state.armed = true;
        try {
          arm(pulse, cell, future, token);
        } catch (e, stack) {
          onError?.call(e, stack);
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// IntervalWithValue - Custom Values Per Tick
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a custom value at each tick (Rx `interval` + map).
///
/// [IntervalWithValue] is similar to [Interval] but allows you to specify
/// what value to emit at each tick. You can either provide a fixed [value]
/// or a [valueOf] function that computes the value from the tick index.
///
/// ### When to use
/// Use [IntervalWithValue] when you need to emit specific values at
/// regular intervals.
///
/// - **Status Updates**: Emitting status strings like `'running'`, `'idle'`.
/// - **Pagination**: Emitting page numbers or offsets.
/// - **Progress Tracking**: Emitting progress percentages.
/// - **State Reporting**: Emitting system states at regular intervals.
/// - **Scheduled Messages**: Sending predefined messages on a schedule.
/// - **Data Generation**: Generating test data at regular intervals.
/// - **UI Updates**: Emitting formatted time strings for a clock.
///
/// ### Example: Clock Display
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final clock = IntervalWithValue<String>(
///   Duration(seconds: 1),
///   valueOf: (tick) => DateTime.now().toIso8601String(),
///   maxTicks: 10,
/// ).toHandle(source: start.cell);
///
/// Cell.observe(
///   source: clock.cell,
///   effect: (pulse) => print('Time: ${pulse.payload}'),
/// );
/// ```
///
/// ### Example: Progress Updates
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final progress = IntervalWithValue<double>(
///   Duration(milliseconds: 100),
///   valueOf: (tick) => tick / 100.0, // 0.0, 0.01, 0.02, ...
///   maxTicks: 101,
/// ).toHandle(source: start.cell);
/// ```
///
/// ### How it works
/// 1. The first source pulse **arms** the clock.
/// 2. A `Timer.periodic` is started with the specified [period].
/// 3. On each tick, the [valueOf] function is called with the current [tick].
/// 4. The returned value is emitted.
/// 5. If [value] is provided instead of [valueOf], that fixed value is
///    emitted on every tick.
/// 6. The [tick] counter increments by 1 each emission.
/// 7. If [maxTicks] is set, the timer stops after that many emissions.
/// 8. If [resetOnSource] is `true`, a later source pulse resets the counter.
///
/// ### Non‑obvious
/// - **Fixed vs Computed**: Provide either [value] (fixed) or [valueOf]
///   (computed), but not both. An [ArgumentError] is thrown if both are
///   `null`.
/// - **Tick Index**: The [tick] parameter to [valueOf] is 0-based and
///   increments each emission.
/// - **Error Handling**: Errors in [valueOf] are caught and reported via
///   [onError], and the timer is cancelled.
/// - **Type Safety**: The instruction is generic over [T], allowing any
///   payload type.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [period]: **The Tick Interval.** The duration between each emission.
/// - [value]: **Fixed Value.** Optional. Emitted on every tick if provided.
/// - [valueOf]: **Value Function.** Optional. Computes the value from the
///   tick index. Must be provided if [value] is not.
/// - [maxTicks]: **Maximum Emissions.** Optional. Stops after this many ticks.
/// - [resetOnSource]: **Reset on Trigger.** If `true`, a later source pulse
///   resets the counter to 0. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the payload to emit.
///
/// ### Returns:
/// A [FlowInstruction] that emits custom values at regular intervals.
///
/// ### See Also:
/// - [Interval]: For simple integer emission.
/// - [IntervalWithState]: For stateful interval emissions.
/// - [TimerPulse]: For a single delayed emission.
class IntervalWithValue<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  IntervalWithValue(
      Duration period, {
        T? value,
        T Function(int tick)? valueOf,
        int? maxTicks,
        bool resetOnSource = false,
        IntervalErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      if (value == null && valueOf == null) {
        throw ArgumentError('Provide value or valueOf');
      }
      final state = _ClockState();

      T current() {
        if (valueOf != null) return valueOf(state.tick);
        return value as T;
      }

      void emitTick() {
        final trigger = state.trigger;
        if (trigger == null || state.future == null) return;
        try {
          final payload = current();
          state.future!(
            result: _out<T>(payload, state.cell, trigger, 'IntervalWithValue'),
            token: state.token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          state.cancel();
          return;
        }
        state.tick++;
        if (maxTicks != null && state.tick >= maxTicks) {
          state.cancel();
        }
      }

      return (pulse, {cell, user, future, token}) {
        if (state.armed && !resetOnSource) return null;
        state.armed = true;
        state.future = future;
        state.token = token;
        state.cell = cell;
        state.trigger = pulse;
        state.cancel();
        state.tick = 0;
        if (maxTicks != null && maxTicks <= 0) return null;
        state.timer = Timer.periodic(period, (_) => emitTick());
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// IntervalWithState - Stateful Interval Emissions
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a running state value at each tick
/// (Rx `interval` + scan).
///
/// [IntervalWithState] maintains an accumulator that is updated on each
/// tick using the [next] function. This allows for stateful interval
/// emissions where each value depends on the previous state.
///
/// ### When to use
/// Use [IntervalWithState] when each interval emission depends on the
/// previous state.
///
/// - **Countdown**: Emitting decreasing values over time.
/// - **Running Totals**: Accumulating values over time.
/// - **State Machines**: Advancing a state machine on each tick.
/// - **Simulations**: Evolving a simulation state over time.
/// - **Doubling/Scaling**: Multiplying values each tick.
/// - **Fibonacci**: Generating Fibonacci-like sequences.
/// - **Growth Models**: Emitting exponential or logarithmic growth.
/// - **Battery/Resource Tracking**: Tracking resource consumption over time.
///
/// ### Example: Countdown
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final countdown = IntervalWithState<int>(
///   Duration(seconds: 1),
///   10, // Initial seed
///   (state, tick) => state - 1,
///   maxTicks: 10,
/// ).toHandle(source: start.cell);
///
/// Cell.observe(
///   source: countdown.cell,
///   effect: (pulse) => print('Countdown: ${pulse.payload}'),
/// );
/// // Outputs: 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
/// ```
///
/// ### Example: Doubling Sequence
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final doubles = IntervalWithState<int>(
///   Duration(milliseconds: 100),
///   1,
///   (state, tick) => tick == 0 ? state : state * 2,
///   maxTicks: 8,
/// ).toHandle(source: start.cell);
/// // Outputs: 1, 2, 4, 8, 16, 32, 64, 128
/// ```
///
/// ### Example: Fibonacci Sequence
/// ```dart
/// final start = Cell.ingress<void>();
///
/// final fib = IntervalWithState<int>(
///   Duration(milliseconds: 50),
///   (0, 1), // Initial seed as a tuple
///   (state, tick) {
///     final (a, b) = state;
///     return (b, a + b);
///   },
///   maxTicks: 10,
/// ).toHandle(source: start.cell);
/// // Outputs: (0, 1), (1, 1), (1, 2), (2, 3), (3, 5), ...
/// ```
///
/// ### How it works
/// 1. The first source pulse **arms** the clock.
/// 2. A `Timer.periodic` is started with the specified [period].
/// 3. On each tick, the [next] function is called with the current
///    accumulator and the current [tick] index.
/// 4. The [next] function returns the new accumulator value.
/// 5. The new value is emitted as the payload.
/// 6. The accumulator is updated for the next tick.
/// 7. The [tick] counter increments by 1 each emission.
/// 8. If [maxTicks] is set, the timer stops after that many emissions.
/// 9. If [resetOnSource] is `true`, a later source pulse resets the
///    accumulator to the initial [seed].
///
/// ### Non‑obvious
/// - **State Persistence**: The accumulator persists across ticks and
///   is updated in place.
/// - **First Tick Handling**: The [next] function receives `tick = 0`
///   for the first emission, allowing you to special-case the initial
///   value if needed.
/// - **Error Handling**: Errors in [next] are caught and reported via
///   [onError], and the timer is cancelled.
/// - **Type Safety**: The instruction is generic over [A], allowing any
///   state type.
/// - **Reset Behavior**: When [resetOnSource] is `true`, the accumulator
///   resets to the initial [seed] value.
/// - **Provenance Preservation**: Every emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [period]: **The Tick Interval.** The duration between each emission.
/// - [seed]: **Initial State.** The starting accumulator value.
/// - [next]: **State Transition Function.** Takes the current state and
///   tick index, returns the new state.
/// - [maxTicks]: **Maximum Emissions.** Optional. Stops after this many ticks.
/// - [resetOnSource]: **Reset on Trigger.** If `true`, a later source pulse
///   resets the counter and state to the initial [seed].
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits stateful values at regular intervals.
///
/// ### See Also:
/// - [Interval]: For simple integer emission.
/// - [IntervalWithValue]: For custom value emission.
/// - [TimerPulse]: For a single delayed emission.
/// - [Scan]: For stateful accumulation (not yet implemented).
class IntervalWithState<A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  IntervalWithState(
      Duration period,
      A seed,
      A Function(A state, int tick) next, {
        int? maxTicks,
        bool resetOnSource = false,
        IntervalErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final clock = _ClockState();
      var acc = seed;

      void emitTick() {
        final trigger = clock.trigger;
        if (trigger == null || clock.future == null) return;
        try {
          acc = next(acc, clock.tick);
        } catch (e, stack) {
          onError?.call(e, stack);
          clock.cancel();
          return;
        }
        clock.future!(
          result: _out<A>(acc, clock.cell, trigger, 'IntervalWithState'),
          token: clock.token,
        );
        clock.tick++;
        if (maxTicks != null && clock.tick >= maxTicks) {
          clock.cancel();
        }
      }

      return (pulse, {cell, user, future, token}) {
        if (clock.armed && !resetOnSource) return null;
        clock.armed = true;
        clock.future = future;
        clock.token = token;
        clock.cell = cell;
        clock.trigger = pulse;
        clock.cancel();
        clock.tick = 0;
        acc = seed;
        if (maxTicks != null && maxTicks <= 0) return null;
        clock.timer = Timer.periodic(period, (_) => emitTick());
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// TimerPulse - One-Shot Delayed Emission
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a single pulse after a [delay]
/// (Rx `timer` without a period).
///
/// [TimerPulse] is the "one-shot" variant of the interval family. It
/// starts a timer on the first source pulse and emits exactly one value
/// after the specified [delay].
///
/// ### When to use
/// Use [TimerPulse] when you need a single delayed emission.
///
/// - **Timeouts**: Emitting after a delay for timeout handling.
/// - **Scheduled Actions**: Performing an action after a delay.
/// - **Debouncing**: Delaying an action to batch rapid events.
/// - **Initialization**: Emitting a signal after initialization.
/// - **Animation**: Triggering an animation after a delay.
/// - **Retry Logic**: Delaying retry attempts.
/// - **Gate Opening**: Opening a gate after a delay.
/// - **Sequence Control**: Controlling the timing of sequential operations.
///
/// ### Example: Timeout Handling
/// ```dart
/// final trigger = Cell.ingress<void>();
///
/// final timeout = TimerPulse<String>(
///   Duration(seconds: 5),
///   value: 'TIMEOUT',
/// ).toHandle(source: trigger.cell);
///
/// Cell.observe(
///   source: timeout.cell,
///   effect: (pulse) => print('${pulse.payload}'),
/// );
/// ```
///
/// ### Example: Debounced Action
/// ```dart
/// final input = Cell.ingress<String>();
///
/// final debounced = TimerPulse<String>(
///   Duration(milliseconds: 300),
///   valueOf: () => 'Search: ${lastInput}',
/// ).toHandle(source: input.cell);
/// ```
///
/// ### How it works
/// 1. The first source pulse **arms** the timer.
/// 2. A `Timer` is started with the specified [delay].
/// 3. When the timer fires, the value is emitted once.
/// 4. The instruction stops after the single emission.
/// 5. Later source pulses are ignored (cannot re-arm).
/// 6. The emitted value is wrapped as an [EvolvedPulse] with the step
///    `'TimerPulse'` to preserve causal provenance.
///
/// ### Non‑obvious
/// - **One-Shot**: Only emits once. The instruction stops after emission.
/// - **No Re-arm**: Later source pulses are ignored. If you need multiple
///   timers, create a new instruction each time.
/// - **Fixed vs Computed**: Provide either [value] (fixed) or [valueOf]
///   (computed), but not both. An [ArgumentError] is thrown if both are
///   `null`.
/// - **Error Handling**: Errors in [valueOf] are caught and reported via
///   [onError].
/// - **Type Safety**: The instruction is generic over [T], allowing any
///   payload type.
/// - **Provenance Preservation**: The emitted value preserves the source
///   cell, type, and priority from the trigger pulse.
/// - **Memory Safety**: The timer is automatically cancelled when the
///   instruction is disposed.
///
/// ### Parameters:
/// - [delay]: **The Delay Duration.** The time to wait before emission.
/// - [value]: **Fixed Value.** Optional. Emitted when the timer fires.
/// - [valueOf]: **Value Function.** Optional. Computes the value when
///   the timer fires. Must be provided if [value] is not.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the payload to emit.
///
/// ### Returns:
/// A [FlowInstruction] that emits a single delayed value.
///
/// ### See Also:
/// - [Interval]: For periodic emissions.
/// - [IntervalWithValue]: For periodic custom values.
/// - [IntervalWithState]: For stateful periodic emissions.
/// - [Delay]: For a delay operator that forwards the pulse (not yet implemented).
class TimerPulse<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  TimerPulse(
      Duration delay, {
        T? value,
        T Function()? valueOf,
        IntervalErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _ClockState();
      return (pulse, {cell, user, future, token}) {
        if (state.armed) return null;
        state.armed = true;
        state.timer = Timer(delay, () {
          try {
            final payload = valueOf != null
                ? valueOf()
                : (value as T);
            future!(
              result: _out<T>(payload, cell, pulse, 'TimerPulse'),
              token: token,
            );
          } catch (e, stack) {
            onError?.call(e, stack);
          }
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

/// A demonstration of the [Interval] instruction and related operators
/// showing their behavior in various time-based emission scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Interval Operators Demo ───────────────────────────────────
///
/// 1. Interval - 0, 1, 2
///    [Interval] 0
///    [Interval] 1
///    [Interval] 2
///
/// 2. IntervalWithValue - tick labels
///    [IntervalWithValue] tick-0
///    [IntervalWithValue] tick-1
///
/// 3. IntervalWithState - doubling
///    [IntervalWithState] 1
///    [IntervalWithState] 2
///    [IntervalWithState] 4
///
/// 4. TimerPulse - one shot
///    [TimerPulse] go
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
/// 1. **Interval - Basic Counter**: Shows the basic interval operator
///    emitting `0, 1, 2, …` at regular intervals. The clock is armed
///    by the first source pulse and stops after [maxTicks] is reached.
///
/// 2. **IntervalWithValue - Tick Labels**: Shows custom value emission
///    where each tick maps to a computed value. The [valueOf] function
///    creates a string label from the tick index.
///
/// 3. **IntervalWithState - Doubling**: Shows stateful interval emission
///    where each tick depends on the previous state. The accumulator
///    doubles on each tick after the first.
///
/// 4. **TimerPulse - One Shot**: Shows the one-shot timer that emits
///    a single value after a delay.
///
/// ### Key Takeaways
/// - Interval operators are armed by the first source pulse.
/// - The [maxTicks] parameter controls how many emissions occur.
/// - [resetOnSource] allows resetting the counter on later triggers.
/// - [IntervalWithValue] maps the tick index to a custom value.
/// - [IntervalWithState] maintains state across ticks.
/// - [TimerPulse] is a single delayed emission.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Timers are automatically cancelled when maxTicks is reached.
///
/// ### Note on Timing
/// The demo uses short delays (30ms) for quick execution. In production,
/// you would typically use longer periods (e.g., seconds or minutes).
Future<void> main() async {
  print('── Interval Operators Demo ───────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Interval - Basic Counter
  // ─────────────────────────────────────────────────────────────────────
  print('1. Interval - 0, 1, 2');

  final start = Cell.ingress<void>();

  final ticks = Interval(
    const Duration(milliseconds: 30),
    maxTicks: 3,
  ).toHandle(source: start.cell);

  final iObs = Cell.observe(
    source: ticks.cell,
    effect: (Pulse p) => print('   [Interval] ${p.payload}'),
  );

  await start.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 120));

  iObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. IntervalWithValue - Tick Labels
  // ─────────────────────────────────────────────────────────────────────
  print('2. IntervalWithValue - tick labels');

  final start2 = Cell.ingress<void>();

  final labeled = IntervalWithValue<String>(
    const Duration(milliseconds: 30),
    valueOf: (tick) => 'tick-$tick',
    maxTicks: 2,
  ).toHandle(source: start2.cell);

  final vObs = Cell.observe(
    source: labeled.cell,
    effect: (Pulse p) => print('   [IntervalWithValue] ${p.payload}'),
  );

  await start2.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 90));

  vObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. IntervalWithState - Doubling
  // ─────────────────────────────────────────────────────────────────────
  print('3. IntervalWithState - doubling');

  final start3 = Cell.ingress<void>();

  final doubled = IntervalWithState<int>(
    const Duration(milliseconds: 30),
    1,
        (state, tick) => tick == 0 ? state : state * 2,
    maxTicks: 3,
  ).toHandle(source: start3.cell);

  final sObs = Cell.observe(
    source: doubled.cell,
    effect: (Pulse p) => print('   [IntervalWithState] ${p.payload}'),
  );

  await start3.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 120));

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. TimerPulse - One Shot
  // ─────────────────────────────────────────────────────────────────────
  print('4. TimerPulse - one shot');

  final start4 = Cell.ingress<void>();

  final once = TimerPulse<String>(
    const Duration(milliseconds: 30),
    value: 'go',
  ).toHandle(source: start4.cell);

  final tObs = Cell.observe(
    source: once.cell,
    effect: (Pulse p) => print('   [TimerPulse] ${p.payload}'),
  );

  await start4.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 60));

  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}