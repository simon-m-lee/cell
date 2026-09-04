// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Reduce Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that keep a **volatile in-memory accumulator**
/// (Rx `scan` / `startWith` / reducer family).
///
/// Named `reduce`, not `state`: nothing here is persisted, hydrated,
/// or shared across process restarts. It is the current fold of this
/// flow only.
///
/// | Operator | Rx analogue | Holds |
/// |---|---|---|
/// | [Reduce] | `scan` + seed | reducer output |
/// | [ReduceSelect] | `map` | projected slice |
/// | [ReduceMachine] | `scan` of events | transition table |
///
/// [Reduce.snapshot] and [ReduceMachine.snapshot] can be read between
/// pulses. They are not a store.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for reduce operators.
///
/// Called when an error occurs during reduction or projection.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = ReduceErrorHandler((error, stack) {
///   print('Reduce error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ReduceErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Helper to create an output pulse with proper provenance.
Pulse<A> _out<A>(A value, Pulse trigger, Cell? cell, String step) {
  return Pulse<A>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Type-safe payload extraction with error handling.
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
      ReduceErrorHandler? onError,
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

/// Volatile snapshot of a running fold. Not durable storage.
///
/// [ReduceSnapshot] holds the current value and generation count of a
/// reduce operation. It is the in-memory state of the flow, not a
/// persistent store.
///
/// ### When to use
/// Use [ReduceSnapshot] to access the current state of a [Reduce] or
/// [ReduceMachine] instruction between pulses. You can read the
/// [value] and [generation] at any time.
///
/// ### How it works
/// 1. The [value] is updated on each pulse.
/// 2. The [generation] is incremented on each update.
/// 3. The snapshot is shared between the instruction and external code.
/// 4. You can read the snapshot at any time to inspect the current state.
///
/// ### Non‑obvious
/// - **Volatile**: The snapshot is not persisted across process restarts.
/// - **In-Memory**: The state lives only in the current process.
/// - **Shared State**: The snapshot is mutable and shared with the instruction.
/// - **Generation Tracking**: The [generation] helps detect updates.
/// - **Not a Store**: This is not a database or cache. Use [Cell.state] for
///   persistent state.
///
/// ### Example: Inspecting State
/// ```dart
/// final snapshot = ReduceSnapshot<int>(0);
/// final reduce = Reduce<int, int>(
///   0,
///   (acc, n) => acc + n,
///   snapshot: snapshot,
/// ).toHandle(source: input.cell);
///
/// // Later, inspect the state
/// print('Current sum: ${snapshot.value}');
/// print('Updates: ${snapshot.generation}');
/// ```
///
/// ### Type Parameters:
/// - [A]: The type of the accumulated value.
///
/// ### See Also:
/// - [Reduce]: For basic reduction with a snapshot.
/// - [ReduceMachine]: For event-driven reduction with a snapshot.
class ReduceSnapshot<A> {
  /// Creates a snapshot with an initial [value].
  ReduceSnapshot(this.value);

  /// The current accumulated value.
  A value;

  /// The number of times the value has been updated.
  int generation = 0;
}

// ─────────────────────────────────────────────────────────────
// Reduce - Seeded Reducer
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maintains a running accumulator,
/// updating it with each typed payload and emitting the new value
/// (Rx `scan` + seed).
///
/// [Reduce] is the foundational reduction operator. It takes a [seed]
/// value and a [reduce] function that combines the current accumulator
/// with each incoming payload to produce a new accumulator value.
///
/// ### When to use
/// Use [Reduce] when you need to maintain a running total or
/// accumulated state across a stream of values.
///
/// - **Running Totals**: Summing numbers as they arrive.
/// - **String Concatenation**: Building strings incrementally.
/// - **List Accumulation**: Collecting items into a list.
/// - **State Aggregation**: Aggregating state from multiple events.
/// - **Statistics**: Computing running averages, min, max, etc.
/// - **Data Transformation**: Accumulating transformed data.
/// - **Caching**: Maintaining a cache of recent values.
/// - **Batching**: Collecting items into batches.
///
/// ### Choosing Between Reduce Variants
/// - **Use [Reduce]** for **Full Accumulation**: When you need the
///   complete accumulated state.
/// - **Use [ReduceSelect]** for **Projection**: When you only need a
///   slice of the accumulated state.
/// - **Use [ReduceMachine]** for **Event-Driven State**: When your
///   state transitions depend on event types.
///
/// ### Comparison with Other Operators
/// | Operator | Holds State | Emits | Persisted |
/// |----------|-------------|-------|-----------|
/// | **Reduce** | Yes | Each update | No (volatile) |
/// | **Cell.state** | Yes | Each update | Optional |
/// | **ReduceSelect** | No (projects) | Each update | No |
/// | **ReduceMachine** | Yes | Each update | No |
///
/// ### How it works
/// 1. Each incoming pulse is type-checked to ensure it matches [S].
/// 2. The [reduce] function is called with the current accumulator
///    and the payload.
/// 3. The new accumulator value is stored in the [snapshot].
/// 4. The [generation] counter is incremented.
/// 5. The new value is emitted as a pulse.
/// 6. The [snapshot] can be read at any time to inspect the state.
///
/// ### Non‑obvious
/// - **Volatile State**: The state is in-memory only. It is not
///   persisted across process restarts.
/// - **Type Safety**: The instruction is generic over [S] (input type)
///   and [A] (accumulator type), ensuring compile-time type safety.
/// - **Error Handling**: Errors in [reduce] are caught and reported
///   via [onError], and the pulse is dropped.
/// - **Generation Tracking**: The [generation] counter increments on
///   each update, allowing external code to detect changes.
/// - **Shared Snapshot**: The [snapshot] is mutable and shared with
///   the instruction, allowing external inspection.
/// - **Provenance Preservation**: Every emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Reduction**: The [reduce] function is synchronous.
///   For asynchronous accumulation, use [MergeScan].
///
/// ### Example: Running Sum
/// ```dart
/// final numberInput = Cell.ingress<int>();
///
/// final sum = Reduce<int, int>(
///   0,
///   (acc, n) => acc + n,
/// ).toHandle(source: numberInput.cell);
///
/// Cell.observe(
///   source: sum.cell,
///   effect: (pulse) => print('Sum: ${pulse.payload}'),
/// );
///
/// numberInput.emit(5);  // -> Sum: 5
/// numberInput.emit(3);  // -> Sum: 8
/// numberInput.emit(7);  // -> Sum: 15
/// ```
///
/// ### Example: String Concatenation
/// ```dart
/// final words = Cell.ingress<String>();
///
/// final sentence = Reduce<String, String>(
///   '',
///   (acc, word) => acc.isEmpty ? word : '$acc $word',
/// ).toHandle(source: words.cell);
///
/// words.emit('Hello');   // -> Hello
/// words.emit('World');   // -> Hello World
/// words.emit('!');       // -> Hello World !
/// ```
///
/// ### Example: List Accumulation
/// ```dart
/// final items = Cell.ingress<int>();
///
/// final list = Reduce<int, List<int>>(
///   [],
///   (acc, item) => [...acc, item],
/// ).toHandle(source: items.cell);
///
/// items.emit(1);  // -> [1]
/// items.emit(2);  // -> [1, 2]
/// items.emit(3);  // -> [1, 2, 3]
/// ```
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting accumulator value.
/// - [reduce]: **Reduction Function.** Takes the current accumulator
///   and the payload, returns the new accumulator.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided. Use this to access the state externally.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [A]: The type of the accumulator and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maintains a running accumulator.
///
/// ### See Also:
/// - [ReduceSelect]: For projecting a slice of the state.
/// - [ReduceMachine]: For event-driven state transitions.
/// - [MergeScan]: For asynchronous accumulation with concurrency.
/// - [Cell.state]: For persistent state storage.
class Reduce<S, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Reduce(
      A seed,
      A Function(A acc, S value) reduce, {
        ReduceSnapshot<A>? snapshot,
        ReduceErrorHandler? onError,
        dynamic user,
      }) : this._(reduce, snapshot ?? ReduceSnapshot<A>(seed), onError, user);

  Reduce._(
      A Function(A acc, S value) reduce,
      this.snapshot,
      ReduceErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final snap = snapshot;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        try {
          snap.value = reduce(snap.value, typed.payload as S);
          snap.generation++;
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        return _out<A>(snap.value, typed, cell, 'Reduce');
      };
    })(),
    user: user,
  );

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [generation] from outside
  /// the instruction.
  final ReduceSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// ReduceSelect - Projected Slice
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that projects each payload through a [select]
/// function (Rx `map`).
///
/// [ReduceSelect] is a lightweight projection operator that transforms
/// each incoming payload without maintaining state. It's useful for
/// extracting a field from a complex object or applying a simple
/// transformation.
///
/// ### When to use
/// Use [ReduceSelect] when you need to extract or transform a value
/// from each incoming payload.
///
/// - **Field Extraction**: Getting a field from a map or object.
/// - **Data Transformation**: Applying a simple transformation.
/// - **Type Conversion**: Converting between types.
/// - **Formatting**: Formatting values for display.
/// - **Filtering by Projection**: Selecting a subset of data.
/// - **Data Mapping**: Mapping between domain models.
///
/// ### Example: Field Extraction
/// ```dart
/// final users = Cell.ingress<Map<String, Object>>();
///
/// final names = ReduceSelect<Map<String, Object>, Object>(
///   (user) => user['name']!,
/// ).toHandle(source: users.cell);
///
/// users.emit({'id': 1, 'name': 'Alice'}); // -> Alice
/// users.emit({'id': 2, 'name': 'Bob'});   // -> Bob
/// ```
///
/// ### Example: Type Conversion
/// ```dart
/// final strings = Cell.ingress<String>();
///
/// final lengths = ReduceSelect<String, int>(
///   (str) => str.length,
/// ).toHandle(source: strings.cell);
///
/// strings.emit('Hello');  // -> 5
/// strings.emit('World');  // -> 5
/// strings.emit('!');      // -> 1
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked to ensure it matches [S].
/// 2. The [select] function is called with the payload.
/// 3. The result is emitted as a pulse.
/// 4. No state is maintained (unlike [Reduce]).
///
/// ### Non‑obvious
/// - **Stateless**: Unlike [Reduce], no state is maintained.
/// - **Type Safety**: The instruction is generic over [S] (input type)
///   and [T] (output type), ensuring compile-time type safety.
/// - **Error Handling**: Errors in [select] are caught and reported
///   via [onError], and the pulse is dropped.
/// - **Provenance Preservation**: Every emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Performance**: This is a lightweight operation with minimal overhead.
/// - **Synchronous Projection**: The [select] function is synchronous.
///
/// ### Parameters:
/// - [select]: **Projection Function.** Takes the payload and returns
///   the projected value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload after projection.
///
/// ### Returns:
/// A [FlowInstruction] that projects each payload.
///
/// ### See Also:
/// - [Reduce]: For maintaining state.
/// - [ReduceMachine]: For event-driven state.
/// - [Map]: For simple mapping (not yet implemented).
class ReduceSelect<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ReduceSelect(
      T Function(S value) select, {
        ReduceErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      try {
        return _out<T>(
          select(typed.payload as S),
          typed,
          cell,
          'ReduceSelect',
        );
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// ReduceMachine - Event-Driven State Machine
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that maintains state via event-driven
/// transitions (Rx `scan` of events).
///
/// [ReduceMachine] is a state machine reducer where each incoming
/// event triggers a transition function that updates the state. It's
/// like [Reduce] but specialized for event-driven state management.
///
/// ### When to use
/// Use [ReduceMachine] when your state transitions depend on event
/// types and you want to model a state machine.
///
/// - **UI State Management**: Managing UI state from user events.
/// - **Game State**: Updating game state from player actions.
/// - **Protocol State**: Maintaining protocol state from messages.
/// - **Workflow State**: Tracking workflow progress from events.
/// - **Authentication State**: Managing auth state from login/logout.
/// - **Feature Flags**: Toggling features based on events.
/// - **Form State**: Managing form state from user input.
/// - **Navigation State**: Managing navigation from route events.
///
/// ### Example: Counter with Events
/// ```dart
/// final events = Cell.ingress<String>();
///
/// final counter = ReduceMachine<String, int>(
///   0,
///   (acc, event) {
///     switch (event) {
///       case 'inc': return acc + 1;
///       case 'dec': return acc - 1;
///       case 'reset': return 0;
///       default: return acc;
///     }
///   },
/// ).toHandle(source: events.cell);
///
/// events.emit('inc');   // -> 1
/// events.emit('inc');   // -> 2
/// events.emit('dec');   // -> 1
/// events.emit('reset'); // -> 0
/// ```
///
/// ### Example: Login State Machine
/// ```dart
/// final events = Cell.ingress<AuthEvent>();
///
/// final auth = ReduceMachine<AuthEvent, AuthState>(
///   AuthState.unauthenticated(),
///   (state, event) {
///     return switch (event) {
///       LoginEvent e => state.copyWith(isLoggedIn: true, user: e.user),
///       LogoutEvent _ => AuthState.unauthenticated(),
///       RefreshEvent _ => state.copyWith(lastRefresh: DateTime.now()),
///     };
///   },
/// ).toHandle(source: events.cell);
/// ```
///
/// ### Example: Feature Toggle
/// ```dart
/// final events = Cell.ingress<String>();
///
/// final features = ReduceMachine<String, Set<String>>(
///   {},
///   (state, event) {
///     if (event.startsWith('enable:')) {
///       return {...state, event.replaceFirst('enable:', '')};
///     }
///     if (event.startsWith('disable:')) {
///       return {...state}..remove(event.replaceFirst('disable:', ''));
///     }
///     return state;
///   },
/// ).toHandle(source: events.cell);
///
/// events.emit('enable:dark_mode');   // -> {dark_mode}
/// events.emit('enable:notifications'); // -> {dark_mode, notifications}
/// events.emit('disable:dark_mode');  // -> {notifications}
/// ```
///
/// ### How it works
/// 1. Each incoming pulse is type-checked to ensure it matches [E].
/// 2. The [transition] function is called with the current state and
///    the event payload.
/// 3. The new state is stored in the [snapshot].
/// 4. The [generation] counter is incremented.
/// 5. The new state is emitted (unless [emitIfUnchanged] is `false`
///    and the state hasn't changed).
///
/// ### Non‑obvious
/// - **Event-First Design**: The instruction is designed for event-driven
///   state management where events drive transitions.
/// - **Emit Control**: [emitIfUnchanged] controls whether to emit when
///   the state doesn't change. Default is `true`.
/// - **Type Safety**: The instruction is generic over [E] (event type)
///   and [A] (state type), ensuring compile-time type safety.
/// - **Error Handling**: Errors in [transition] are caught and reported
///   via [onError], and the pulse is dropped.
/// - **Shared Snapshot**: The [snapshot] can be read externally to
///   inspect the current state.
/// - **Provenance Preservation**: Every emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Synchronous Transition**: The [transition] function is synchronous.
///   For asynchronous transitions, use [MergeScan].
///
/// ### Parameters:
/// - [seed]: **Initial State.** The starting state value.
/// - [transition]: **Transition Function.** Takes the current state
///   and the event, returns the new state.
/// - [snapshot]: **Shared Snapshot.** Optional. Creates a new one if
///   not provided.
/// - [emitIfUnchanged]: **Emit on No Change.** If `true`, emits even
///   when the state doesn't change. Defaults to `true`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [E]: The type of the input event payload.
/// - [A]: The type of the state and output payload.
///
/// ### Returns:
/// A [FlowInstruction] that maintains event-driven state.
///
/// ### See Also:
/// - [Reduce]: For basic reduction.
/// - [ReduceSelect]: For projecting a slice.
/// - [MergeScan]: For asynchronous accumulation with concurrency.
/// - [Cell.state]: For persistent state storage.
class ReduceMachine<E, A> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ReduceMachine(
      A seed,
      A Function(A acc, E event) transition, {
        ReduceSnapshot<A>? snapshot,
        bool emitIfUnchanged = true,
        ReduceErrorHandler? onError,
        dynamic user,
      }) : this._(
    transition,
    snapshot ?? ReduceSnapshot<A>(seed),
    emitIfUnchanged,
    onError,
    user,
  );

  ReduceMachine._(
      A Function(A acc, E event) transition,
      this.snapshot,
      bool emitIfUnchanged,
      ReduceErrorHandler? onError,
      dynamic user,
      ) : super(
    (() {
      final snap = snapshot;
      return (pulse, {cell, user}) {
        final typed = _typedOrError<E>(pulse, onError: onError);
        if (typed == null) return null;
        final previous = snap.value;
        try {
          snap.value = transition(previous, typed.payload as E);
          snap.generation++;
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
        if (!emitIfUnchanged && snap.value == previous) return null;
        return _out<A>(snap.value, typed, cell, 'ReduceMachine');
      };
    })(),
    user: user,
  );

  /// The shared snapshot containing the current state.
  ///
  /// Use this to access the [value] and [generation] from outside
  /// the instruction.
  final ReduceSnapshot<A> snapshot;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Reduce] instruction and related operators
/// showing their behavior in various accumulation scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Reduce Operators Demo ─────────────────────────────────────
///
/// 1. Reduce - running sum
///    [Reduce] 1
///    [Reduce] 3
///    snapshot=3 gen=2
///
/// 2. ReduceSelect - field
///    [ReduceSelect] Ann
///
/// 3. ReduceMachine - counter events
///    [ReduceMachine] 1
///    [ReduceMachine] 0
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
/// 1. **Reduce - Running Sum**: Shows the basic reduction operator
///    maintaining a running sum. Each value is added to the accumulator
///    and emitted. The snapshot shows the current state and generation.
///
/// 2. **ReduceSelect - Field Extraction**: Shows projection of a field
///    from a complex object. The name field is extracted from the map
///    payload and emitted.
///
/// 3. **ReduceMachine - Counter Events**: Shows event-driven state
///    management. The `inc` event increments the counter, the `dec`
///    event decrements it. Each event triggers a state transition.
///
/// ### Key Takeaways
/// - Reduce maintains a running accumulator with snapshot access.
/// - ReduceSelect projects values without maintaining state.
/// - ReduceMachine implements event-driven state machines.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Snapshots provide external access to the current state.
/// - Generation counters help detect state changes.
/// - [emitIfUnchanged] controls emission on no-change transitions.
///
/// ### Note on Volatility
/// Reduce operators maintain **volatile in-memory state** only. This
/// state is not persisted, hydrated, or shared across process restarts.
/// Use [Cell.state] for persistent state storage.
Future<void> main() async {
  print('── Reduce Operators Demo ─────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Reduce - Running Sum
  // ─────────────────────────────────────────────────────────────────────
  print('1. Reduce - running sum');

  final nums = Cell.ingress<int>();

  final reduce = Reduce<int, int>(
    0,
        (acc, n) => acc + n,
  );

  final sums = reduce.toHandle(source: nums.cell);

  final rObs = Cell.observe(
    source: sums.cell,
    effect: (Pulse p) => print('   [Reduce] ${p.payload}'),
  );

  await nums.emitAsync(1);
  await nums.emitAsync(2);

  print('   snapshot=${reduce.snapshot.value} gen=${reduce.snapshot.generation}');

  rObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. ReduceSelect - Field Extraction
  // ─────────────────────────────────────────────────────────────────────
  print('2. ReduceSelect - field');

  final rows = Cell.ingress<Map<String, Object>>();

  final names = ReduceSelect<Map<String, Object>, Object>(
        (m) => m['name']!,
  ).toHandle(source: rows.cell);

  final sObs = Cell.observe(
    source: names.cell,
    effect: (Pulse p) => print('   [ReduceSelect] ${p.payload}'),
  );

  await rows.emitAsync({'id': 1, 'name': 'Ann'});

  sObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. ReduceMachine - Counter Events
  // ─────────────────────────────────────────────────────────────────────
  print('3. ReduceMachine - counter events');

  final events = Cell.ingress<String>();

  final machine = ReduceMachine<String, int>(
    0,
        (acc, event) {
      return switch (event) {
        'inc' => acc + 1,
        'dec' => acc - 1,
        _ => acc,
      };
    },
  ).toHandle(source: events.cell);

  final mObs = Cell.observe(
    source: machine.cell,
    effect: (Pulse p) => print('   [ReduceMachine] ${p.payload}'),
  );

  await events.emitAsync('inc');
  await events.emitAsync('dec');

  mObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}