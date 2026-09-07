// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core StartWith Operators
// ─────────────────────────────────────────────────────────────

/// Error handler callback for startWith operators.
///
/// Called when an error occurs during prefix emission, such as
/// errors in seed factories or type mismatches.
///
/// ### Example
/// ```dart
/// final errorHandler = StartWithErrorHandler((error, stack) {
///   print('StartWith error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef StartWithErrorHandler = void Function(Object error, StackTrace? stackTrace);

// ─────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────

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
      StartWithErrorHandler? onError,
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
///
/// Creates a new [Pulse] with the given [value], preserving the source,
/// type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [value]: The payload value for the new pulse.
/// - [trigger]: The source pulse providing provenance metadata.
/// - [cell]: Optional cell to use as the source.
/// - [step]: The trace step to add for provenance.
///
/// ### Returns:
/// A new [Pulse] with preserved provenance.
Pulse<S> _out<S>(S value, Pulse trigger, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// Helper to emit multiple values via continuation.
///
/// [_emitAll] emits a sequence of values as pulses using the provided
/// continuation callback. Each value gets the same provenance step.
///
/// ### Parameters:
/// - [values]: The values to emit.
/// - [trigger]: The source pulse providing provenance metadata.
/// - [cell]: Optional cell to use as the source.
/// - [step]: The trace step to add for provenance.
/// - [future]: The continuation callback.
/// - [token]: The continuation token.
void _emitAll<S>(
    Iterable<S> values,
    Pulse trigger,
    Cell? cell,
    String step,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
    ) {
  for (final value in values) {
    future?.call(
      result: _out<S>(value, trigger, cell, step),
      token: token,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StartWith - Single-Value Prefix
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits a single seed value on the first
/// typed pulse, then forwards the source (Rx `startWith`).
///
/// [StartWith] acts as a **Single-Value Prefixer**. It emits the
/// provided [seed] value on the first typed pulse, then forwards
/// all subsequent source values unchanged.
///
/// ### When to use
/// Use [StartWith] when you need to prefix a stream with a single
/// initial value.
///
/// - **Initial State**: Providing an initial value before the stream starts.
/// - **Placeholder**: Showing a placeholder before data arrives.
/// - **Loading State**: Showing a loading indicator before content loads.
/// - **Default Values**: Providing default values.
/// - **Splash Screens**: Showing a splash screen before content.
/// - **Empty States**: Showing an empty state before data arrives.
/// - **Cached Data**: Emitting cached data before fresh data.
/// - **Configuration**: Emitting default configuration values.
///
/// ### Choosing Between StartWith Variants
/// - **Use [StartWith]** for **Single Value**: When you only need one
///   prefix value.
/// - **Use [StartWithValue]** for **Single Value (Alias)**: Same as
///   [StartWith], provided for naming consistency.
/// - **Use [StartWithMany]** for **Multiple Values**: When you need
///   multiple prefix values in order.
/// - **Use [StartWithFactory]** for **Dynamic Prefix**: When the prefix
///   depends on the first payload.
///
/// ### Comparison with Other Operators
/// | Operator | Prefix | Source | Replace First |
/// |----------|--------|--------|---------------|
/// | **StartWith** | Single value | Forwarded | Optional |
/// | **StartWithValue** | Single value | Forwarded | Optional |
/// | **StartWithMany** | Multiple values | Forwarded | Optional |
/// | **StartWithFactory** | Dynamic values | Forwarded | Optional |
///
/// ### How it works
/// 1. The first typed pulse triggers the instruction.
/// 2. The [seed] value is emitted as a pulse.
/// 3. If [replaceFirst] is `false`, the source pulse is forwarded.
/// 4. If [replaceFirst] is `true`, the source pulse is dropped.
/// 5. All subsequent pulses are forwarded unchanged.
/// 6. The seed emission gets the step `'StartWith.seed'`.
/// 7. Source emissions get the step `'StartWith'`.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The prefix is emitted only on the first pulse.
/// - **Replace First**: [replaceFirst] controls whether the original
///   pulse is dropped.
/// - **Provenance Preservation**: The emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **Sync/Async**: Uses future-based emission for flexibility.
/// - **No Late Subscribers**: The prefix is not re-emitted for late
///   subscribers.
///
/// ### Example: Single Prefix
/// ```dart
/// final input = Cell.ingress<int>();
/// final startWith = StartWith<int>(0)
///     .toHandle(source: input.cell);
///
/// input.emit(42); // -> 0, 42
/// input.emit(100); // -> 100
/// ```
///
/// ### Example: Replace First
/// ```dart
/// final input = Cell.ingress<int>();
/// final startWith = StartWith<int>(0, replaceFirst: true)
///     .toHandle(source: input.cell);
///
/// input.emit(42); // -> 0 (42 is dropped)
/// input.emit(100); // -> 100
/// ```
///
/// ### Parameters:
/// - [seed]: **The Prefix Value.** The value to emit on the first pulse.
/// - [replaceFirst]: **Replace First Source.** If `true`, the first source
///   pulse is dropped. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that prefixes a single value.
///
/// ### See Also:
/// - [StartWithValue]: Alias of StartWith.
/// - [StartWithMany]: For multiple prefix values.
/// - [StartWithFactory]: For dynamic prefix values.
class StartWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Single-Value Prefixer**—a specialized instruction
  /// that emits a seed value on the first pulse.
  ///
  /// [StartWith] acts as a **Single-Value Prefixer**. It emits the
  /// provided [seed] value on the first typed pulse, then forwards
  /// all subsequent source values unchanged.
  ///
  /// ### How it works
  /// 1. **First Pulse**: On the first typed pulse:
  ///    a. The [seed] is emitted with the step `'StartWith.seed'`.
  ///    b. If [replaceFirst] is `false`, the source pulse is forwarded.
  ///    c. If [replaceFirst] is `true`, the source pulse is dropped.
  /// 2. **Subsequent Pulses**: All subsequent pulses are forwarded
  ///    with the step `'StartWith'`.
  /// 3. **Error Handling**: If the type doesn't match, [onError] is called.
  ///
  /// ### Parameters
  /// - [seed]: **The Prefix Value.** Emitted on the first pulse.
  /// - [replaceFirst]: **Replace First.** Drops the first source pulse.
  /// - [onError]: **Integrity Handler.** Called on type mismatches.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Default Value Provider
  /// ```dart
  /// // Provides a default value before the first real value
  /// val defaultValue = StartWith<String>(
  ///   'Loading...',
  ///   user: 'Default-Provider'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [StartWithValue]: Alias of StartWith.
  /// - [StartWithMany]: For multiple prefix values.
  /// - [StartWithFactory]: For dynamic prefix values.
  StartWith(
      S seed, {
        bool replaceFirst = false,
        StartWithErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var first = true;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (first) {
          first = false;
          future!(
            result: _out<S>(seed, typed, cell, 'StartWith.seed'),
            token: token,
          );
          if (replaceFirst) return null;
        }
        return typed.withStep('StartWith');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// StartWithValue - Single-Value Prefix (Alias)
// ─────────────────────────────────────────────────────────────

/// Alias of [StartWith] for naming consistency.
///
/// [StartWithValue] is a convenience alias for [StartWith] that
/// emphasizes the "value" aspect of the prefix. It behaves exactly
/// the same as [StartWith].
///
/// ### When to use
/// Use [StartWithValue] when you want to be explicit that you're
/// prefixing with a value (as opposed to a factory or many values).
///
/// ### Example
/// ```dart
/// final input = Cell.ingress<int>();
/// val startWithValue = StartWithValue<int>(0)
///     .toHandle(source: input.cell);
/// ```
///
/// ### See Also:
/// - [StartWith]: The primary implementation.
/// - [StartWithMany]: For multiple prefix values.
/// - [StartWithFactory]: For dynamic prefix values.
class StartWithValue<S> extends StartWith<S> {
  /// Creates a [StartWithValue] instruction.
  ///
  /// ### Parameters:
  /// - [value]: **The Prefix Value.** Emitted on the first pulse.
  /// - [replaceFirst]: **Replace First.** Drops the first source pulse.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata.
  ///
  /// ### Example
  /// ```dart
  /// val startWithValue = StartWithValue<int>(
  ///   0,
  ///   replaceFirst: true,
  ///   user: 'Value-Prefixer'
  /// );
  /// ```
  StartWithValue(
      super.value, {
        super.replaceFirst,
        super.onError,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// StartWithMany - Multiple-Value Prefix
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that emits multiple seed values in order on the
/// first typed pulse, then forwards the source (Rx `startWith` of several).
///
/// [StartWithMany] acts as a **Multiple-Value Prefixer**. It emits the
/// provided [seeds] values in order on the first typed pulse, then
/// forwards all subsequent source values unchanged.
///
/// ### When to use
/// Use [StartWithMany] when you need to prefix a stream with multiple
/// initial values in a specific order.
///
/// - **Multiple Initial Values**: Providing several initial values.
/// - **Setup Sequence**: Emitting a sequence of setup values.
/// - **Configuration**: Emitting configuration values.
/// - **Test Data**: Emitting test data sequences.
/// - **History**: Emitting historical values before live data.
/// - **Multi-step Initialization**: Setting up multiple state pieces.
/// - **Cached History**: Replaying cached history before live data.
/// - **Batch Initialization**: Initializing with a batch of values.
///
/// ### How it works
/// 1. The first typed pulse triggers the instruction.
/// 2. Each value in [seeds] is emitted in order.
/// 3. If [replaceFirst] is `false`, the source pulse is forwarded.
/// 4. If [replaceFirst] is `true`, the source pulse is dropped.
/// 5. All subsequent pulses are forwarded unchanged.
/// 6. Each seed emission gets the step `'StartWithMany.seed'`.
/// 7. Source emissions get the step `'StartWithMany'`.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The prefix is emitted only on the first pulse.
/// - **Order Preserved**: Seeds are emitted in the order provided.
/// - **Replace First**: [replaceFirst] controls whether the original
///   pulse is dropped.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **No Late Subscribers**: The prefix is not re-emitted for late
///   subscribers.
///
/// ### Example: Multiple Prefix Values
/// ```dart
/// final input = Cell.ingress<int>();
/// val startWithMany = StartWithMany<int>([1, 2, 3])
///     .toHandle(source: input.cell);
///
/// input.emit(42); // -> 1, 2, 3, 42
/// input.emit(100); // -> 100
/// ```
///
/// ### Example: Setup Sequence
/// ```dart
/// final commands = Cell.ingress<Command>();
/// val setup = StartWithMany<Command>([
///   InitCommand(),
///   LoadConfigCommand(),
///   ConnectCommand(),
/// ]).toHandle(source: commands.cell);
/// ```
///
/// ### Parameters:
/// - [seeds]: **The Prefix Values.** The values to emit in order on
///   the first pulse.
/// - [replaceFirst]: **Replace First Source.** If `true`, the first source
///   pulse is dropped. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that prefixes multiple values.
///
/// ### See Also:
/// - [StartWith]: For a single prefix value.
/// - [StartWithValue]: Alias of StartWith.
/// - [StartWithFactory]: For dynamic prefix values.
class StartWithMany<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Multiple-Value Prefixer**—a specialized instruction
  /// that emits multiple seed values in order on the first pulse.
  ///
  /// [StartWithMany] acts as a **Multiple-Value Prefixer**. It emits the
  /// provided [seeds] values in order on the first typed pulse, then
  /// forwards all subsequent source values unchanged.
  ///
  /// ### How it works
  /// 1. **First Pulse**: On the first typed pulse:
  ///    a. Each seed is emitted with the step `'StartWithMany.seed'`.
  ///    b. If [replaceFirst] is `false`, the source pulse is forwarded.
  ///    c. If [replaceFirst] is `true`, the source pulse is dropped.
  /// 2. **Subsequent Pulses**: All subsequent pulses are forwarded
  ///    with the step `'StartWithMany'`.
  /// 3. **Error Handling**: If the type doesn't match, [onError] is called.
  ///
  /// ### Parameters
  /// - [seeds]: **The Prefix Values.** Emitted in order on the first pulse.
  /// - [replaceFirst]: **Replace First.** Drops the first source pulse.
  /// - [onError]: **Integrity Handler.** Called on type mismatches.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: History Replayer
  /// ```dart
  /// // Replays history before live data
  /// val historyReplayer = StartWithMany<Event>(
  ///   cachedHistory,
  ///   user: 'History-Replayer'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [StartWith]: For a single prefix value.
  /// - [StartWithValue]: Alias of StartWith.
  /// - [StartWithFactory]: For dynamic prefix values.
  StartWithMany(
      Iterable<S> seeds, {
        bool replaceFirst = false,
        StartWithErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var first = true;
      final prefix = List<S>.from(seeds);
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (first) {
          first = false;
          _emitAll(prefix, typed, cell, 'StartWithMany.seed', future, token);
          if (replaceFirst) return null;
        }
        return typed.withStep('StartWithMany');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// StartWithFactory - Dynamic Prefix from Payload
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that computes the prefix from the first payload
/// via [seedOf] (Rx lazy `startWith`).
///
/// [StartWithFactory] acts as a **Dynamic Prefixer**. It computes the
/// prefix values from the first payload using the [seedOf] factory
/// function, then forwards all subsequent source values unchanged.
///
/// ### When to use
/// Use [StartWithFactory] when:
/// - The prefix depends on the first payload
/// - You need dynamic prefix values
/// - You want lazy computation of the prefix
/// - The prefix is expensive to compute and should only be computed
///   when needed
/// - You need context-aware prefix values
/// - The prefix should be based on the first value received
///
/// ### How it works
/// 1. The first typed pulse triggers the instruction.
/// 2. The [seedOf] function is called with the first payload.
/// 3. The returned values are emitted in order.
/// 4. If [replaceFirst] is `false`, the source pulse is forwarded.
/// 5. If [replaceFirst] is `true`, the source pulse is dropped.
/// 6. All subsequent pulses are forwarded unchanged.
/// 7. Each seed emission gets the step `'StartWithFactory.seed'`.
/// 8. Source emissions get the step `'StartWithFactory'`.
///
/// ### Non‑obvious
/// - **First Trigger Only**: The prefix is emitted only on the first pulse.
/// - **Dynamic Computation**: The prefix is computed from the first payload.
/// - **Lazy**: The factory is only called when the first pulse arrives.
/// - **Replace First**: [replaceFirst] controls whether the original
///   pulse is dropped.
/// - **Error Handling**: Errors in the factory are reported via [onError].
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
/// - **No Late Subscribers**: The prefix is not re-emitted for late
///   subscribers.
///
/// ### Example: Context-Aware Prefix
/// ```dart
/// final input = Cell.ingress<String>();
/// val factory = StartWithFactory<String>((first) => [
///   'pre-$first',
///   'double-${first}$first',
/// ]).toHandle(source: input.cell);
///
/// input.emit('hello'); // -> pre-hello, double-hellohello, hello
/// input.emit('world'); // -> world
/// ```
///
/// ### Example: Cache-Aware Prefix
/// ```dart
/// final requests = Cell.ingress<String>();
/// val cached = StartWithFactory<String>((query) => [
///   cache.get(query) ?? 'Loading...',
/// ]).toHandle(source: requests.cell);
/// ```
///
/// ### Parameters:
/// - [seedOf]: **Prefix Factory.** Takes the first payload and returns
///   the prefix values to emit.
/// - [replaceFirst]: **Replace First Source.** If `true`, the first source
///   pulse is dropped. Defaults to `false`.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [S]: The type of the payload.
///
/// ### Returns:
/// A [FlowInstruction] that computes dynamic prefix values.
///
/// ### See Also:
/// - [StartWith]: For a single prefix value.
/// - [StartWithValue]: Alias of StartWith.
/// - [StartWithMany]: For multiple prefix values.
class StartWithFactory<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Dynamic Prefixer**—a specialized instruction that
  /// computes the prefix from the first payload.
  ///
  /// [StartWithFactory] acts as a **Dynamic Prefixer**. It computes the
  /// prefix values from the first payload using the [seedOf] factory
  /// function, then forwards all subsequent source values unchanged.
  ///
  /// ### How it works
  /// 1. **First Pulse**: On the first typed pulse:
  ///    a. The [seedOf] factory is called with the payload.
  ///    b. Each returned value is emitted with `'StartWithFactory.seed'`.
  ///    c. If [replaceFirst] is `false`, the source pulse is forwarded.
  ///    d. If [replaceFirst] is `true`, the source pulse is dropped.
  /// 2. **Subsequent Pulses**: All subsequent pulses are forwarded
  ///    with the step `'StartWithFactory'`.
  /// 3. **Error Handling**: If the type doesn't match or the factory
  ///    throws, [onError] is called.
  ///
  /// ### Parameters
  /// - [seedOf]: **Prefix Factory.** Computes prefix from the first payload.
  /// - [replaceFirst]: **Replace First.** Drops the first source pulse.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Cache-Aware Prefixer
  /// ```dart
  /// // Shows cached data first, then fresh data
  /// val cacheAware = StartWithFactory<String>(
  ///   (query) => [cache.get(query) ?? 'Loading...'],
  ///   user: 'Cache-Aware'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [StartWith]: For a single prefix value.
  /// - [StartWithValue]: Alias of StartWith.
  /// - [StartWithMany]: For multiple prefix values.
  StartWithFactory(
      Iterable<S> Function(S first) seedOf, {
        bool replaceFirst = false,
        StartWithErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var first = true;
      return (pulse, {cell, user, future, token}) {
        final typed = _typedOrError<S>(pulse, onError: onError);
        if (typed == null) return null;
        if (first) {
          first = false;
          try {
            final prefix = seedOf(typed.payload as S);
            _emitAll(
              prefix,
              typed,
              cell,
              'StartWithFactory.seed',
              future,
              token,
            );
          } catch (e, stack) {
            onError?.call(e, stack);
            return null;
          }
          if (replaceFirst) return null;
        }
        return typed.withStep('StartWithFactory');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [StartWith] instruction and related operators
/// showing their behavior in various prefix scenarios.
///
/// ### Expected console output:
/// ```text
/// ── StartWith Operators Demo ──────────────────────────────────
///
/// 1. StartWith
///    [StartWith] seed
///    [StartWith] a
///    [StartWith] b
///
/// 2. StartWithValue
///    [StartWithValue] 0
///    [StartWithValue] 1
///
/// 3. StartWithMany
///    [StartWithMany] x
///    [StartWithMany] y
///    [StartWithMany] z
///
/// 4. StartWithFactory
///    [StartWithFactory] pre-hi
///    [StartWithFactory] hi
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
/// 1. **StartWith - Single Prefix**: Shows a single prefix value
///    emitted before the source values. `seed` is emitted first,
///    followed by `a` and `b`.
///
/// 2. **StartWithValue - Single Prefix (Alias)**: Shows the alias
///    with the same behavior. `0` is emitted before `1`.
///
/// 3. **StartWithMany - Multiple Prefix Values**: Shows multiple
///    prefix values emitted in order. `x` and `y` are emitted
///    before `z`.
///
/// 4. **StartWithFactory - Dynamic Prefix**: Shows the factory
///    computing prefix values from the first payload. `pre-hi` is
///    computed from `hi` and emitted before `hi`.
///
/// ### Key Takeaways
/// - StartWith operators emit prefix values on the first pulse only.
/// - StartWith emits a single prefix value.
/// - StartWithMany emits multiple prefix values in order.
/// - StartWithFactory computes prefix values from the first payload.
/// - The `replaceFirst` option controls whether the first source pulse
///   is dropped.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Prefix values get distinct provenance steps.
/// - Choose the right operator for your use case:
///   - Single value → StartWith or StartWithValue
///   - Multiple values → StartWithMany
///   - Dynamic values → StartWithFactory
///
/// ### Note on Source Behavior
/// The source cell continues to emit after the prefix. The prefix is
/// only emitted on the first pulse, not on every pulse.
Future<void> main() async {
  print('── StartWith Operators Demo ──────────────────────────────────\n');

  print('1. StartWith');
  final letters = Cell.ingress<String>();
  final started = StartWith<String>('seed').toHandle(source: letters.cell);
  final sObs = Cell.observe(
    source: started.cell,
    effect: (Pulse p) => print('   [StartWith] ${p.payload}'),
  );
  await letters.emitAsync('a');
  await letters.emitAsync('b');
  sObs.stop();
  print('');

  print('2. StartWithValue');
  final nums = Cell.ingress<int>();
  final valued = StartWithValue<int>(0).toHandle(source: nums.cell);
  final vObs = Cell.observe(
    source: valued.cell,
    effect: (Pulse p) => print('   [StartWithValue] ${p.payload}'),
  );
  await nums.emitAsync(1);
  vObs.stop();
  print('');

  print('3. StartWithMany');
  final rest = Cell.ingress<String>();
  final many = StartWithMany<String>(['x', 'y']).toHandle(source: rest.cell);
  final mObs = Cell.observe(
    source: many.cell,
    effect: (Pulse p) => print('   [StartWithMany] ${p.payload}'),
  );
  await rest.emitAsync('z');
  mObs.stop();
  print('');

  print('4. StartWithFactory');
  final words = Cell.ingress<String>();
  final factory = StartWithFactory<String>((first) => ['pre-$first'])
      .toHandle(source: words.cell);
  final fObs = Cell.observe(
    source: factory.cell,
    effect: (Pulse p) => print('   [StartWithFactory] ${p.payload}'),
  );
  await words.emitAsync('hi');
  fObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}