// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

/// Flow instructions that combine the latest values of several Cells
/// (Rx `combineLatest` family).
///
/// These operators combine the latest values from multiple cells into a
/// single output. They only emit when all sources have produced at least
/// one value, and then emit whenever any source updates with the latest
/// values from all sources.
///
/// | Operator | Rx analogue | Emits when |
/// |---|---|---|
/// | [CombineLatestWith] | `combineLatest` / `combineLatestWith` | any source or other updates, after every Cell has a value |
/// | [CombineLatest] | `combineLatest` | any extra Cell updates (bound source only arms) |
/// | [WithLatestFrom] | `withLatestFrom` | the bound source updates, using the latest others |
/// | [CombineLatest2] | `combineLatest` of two | either Cell updates |
///
/// Arm [CombineLatest] / [CombineLatestWith] with one `emitAsync` on
/// the bound handle so `future` is available for later other-Cell
/// pulses.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef CombineErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse<R> _out<R>(R value, Pulse trigger, Cell? cell, String step) {
  return Pulse<R>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

class _EmitState {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
}

class _LatestSlot {
  Object? value;
  bool has = false;
}

// ─────────────────────────────────────────────────────────────
// CombineLatestWith
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that combines the bound source with the latest
/// values of [others] (Rx `combineLatestWith`).
///
/// [CombineLatestWith] acts as a **Multi-Source Combiner**. It combines the
/// latest values from the bound source and all other cells into a single
/// output using a custom [combine] function.
///
/// ### When to use
/// Use [CombineLatestWith] when you need to combine multiple reactive sources:
///
/// - **Form Validation**: Combining multiple form fields into a validation state
/// - **UI State**: Combining user preferences and data to compute UI state
/// - **Real-time Dashboards**: Combining multiple data streams
/// - **Dependency Tracking**: Combining values from different dependencies
/// - **Feature Flags**: Combining multiple feature flags
/// - **Filtering**: Combining filter criteria from multiple controls
/// - **Search**: Combining search query with filters
/// - **Pagination**: Combining page and page size
///
/// ### Choosing Between Combine Patterns
/// - **Use [CombineLatestWith]** for **Source + Others**: When you want to
///   combine the bound source with additional cells.
/// - **Use [CombineLatest]** for **Extra Cells Only**: When the bound source
///   is only used to arm the instruction.
/// - **Use [WithLatestFrom]** for **Source-Driven**: When you only want to
///   emit when the source updates.
/// - **Use [CombineLatest2]** for **Typed Pair**: When you have exactly two
///   typed cells to combine.
///
/// ### Comparison with Other Operators
/// | Operator | Sources | Arming | Emit Trigger |
/// |----------|---------|--------|--------------|
/// | **CombineLatestWith** | Source + others | Source | Any update |
/// | **CombineLatest** | Others only | Arming gate | Any update |
/// | **WithLatestFrom** | Source + others | Source | Source only |
/// | **CombineLatest2** | Source + other | Source | Any update |
/// | **Merge** | Multiple | Source | Any emission |
///
/// ### How it works
/// 1. The first source pulse arms the instruction and provides the source value.
/// 2. Observers are started on all [others] cells.
/// 3. Once all cells (source and others) have at least one value, the
///    [combine] function is called.
/// 4. The result is emitted as a [Pulse].
/// 5. Whenever any cell updates, the [combine] function is called again.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **All Must Have Value**: Emission only happens after all cells have
///   at least one value.
/// - **Latest Values**: Always uses the most recent value from each cell.
/// - **Any Update Triggers**: Any cell update triggers a new combination.
/// - **Source Arming**: The first source pulse is required to arm.
/// - **Error Handling**: Errors in [combine] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [S] (source type)
///   and [R] (result type).
///
/// ### Example: Combining Form Fields
/// ```dart
/// final username = Cell.ingress<String>();
/// final password = Cell.ingress<String>();
/// val formValid = CombineLatestWith<String, bool>(
///   [password.cell],
///   (username, latest) => username.isNotEmpty && (latest.single as String).isNotEmpty
/// ).toHandle(source: username.cell);
///
/// username.emit('user'); // No emission (password not set)
/// password.emit('pass'); // Emits true
/// username.emit('');     // Emits false
/// ```
///
/// ### Example: Combining Settings
/// ```dart
/// final theme = Cell.ingress<String>();
/// val fontSize = Cell.ingress<int>();
/// val settings = CombineLatestWith<String, Settings>(
///   [fontSize.cell],
///   (theme, latest) => Settings(theme: theme, fontSize: latest.single as int)
/// ).toHandle(source: theme.cell);
/// ```
///
/// ### Parameters:
/// - [others]: **The Additional Cells.** Cells to combine with the source.
/// - [combine]: **The Combination Function.** Takes the source value and a
///   list of latest values from others, returns the combined result.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
/// - [R]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [CombineLatest]: For combining extra cells only.
/// - [WithLatestFrom]: For source-driven combination.
/// - [CombineLatest2]: For typed two-cell combination.
class CombineLatestWith<S, R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [CombineLatestWith] instruction with the specified [others]
  /// and [combine] function.
  ///
  /// ### Parameters:
  /// - [others]: **The Additional Cells.** Cells to combine with the source.
  /// - [combine]: **The Combination Function.** Takes the source value and a
  ///   list of latest values from others, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val combineLatestWith = CombineLatestWith<int, String>(
  ///   [other.cell],
  ///   (source, latest) => '$source-${latest.single}',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  CombineLatestWith(
      Iterable<Cell> others,
      R Function(S source, List<Object?> latest) combine, {
        CombineErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final slots = [for (final _ in others) _LatestSlot()];
      final list = others.toList();
      final emit = _EmitState();
      S? sourceValue;
      var hasSource = false;
      var armed = false;

      void publish(Pulse trigger, String step) {
        if (!hasSource || slots.any((s) => !s.has)) return;
        try {
          final result = combine(
            sourceValue as S,
            [for (final s in slots) s.value],
          );
          emit.future?.call(
            result: _out<R>(result, trigger, emit.cell, step),
            token: emit.token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
        }
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        if (!armed) {
          armed = true;
          for (var i = 0; i < list.length; i++) {
            final index = i;
            Cell.observe(
              source: list[index],
              effect: (Pulse incoming) {
                slots[index].value = incoming.payload;
                slots[index].has = true;
                publish(incoming, 'CombineLatestWith.other');
              },
            );
          }
        }
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
        sourceValue = payload;
        hasSource = true;
        try {
          if (slots.any((s) => !s.has)) return null;
          return _out<R>(
            combine(payload, [for (final s in slots) s.value]),
            pulse,
            cell,
            'CombineLatestWith.source',
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// CombineLatest
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that combines extra Cells only (Rx `combineLatest`
/// of N streams).
///
/// [CombineLatest] acts as a **Multi-Source Combiner (Arming Only)**. The
/// bound source is only used to arm the instruction. After arming, the
/// [combine] function is called whenever any of the [sources] updates.
///
/// ### When to use
/// Use [CombineLatest] when:
/// - You want to combine multiple cells without forwarding the arming pulse
/// - You're using a dedicated gate to start the combination
/// - You want to combine multiple sources without the trigger being part
///   of the combination
/// - You're implementing a fan-in combiner
/// - You're combining data from multiple services
/// - You're creating a derived state from multiple sources
/// - You're implementing a reducer across multiple cells
///
/// ### How it works
/// 1. The first source pulse arms the instruction by storing the `future`
///    and `token` for emission.
/// 2. Observers are started on all [sources] cells.
/// 3. Once all [sources] have at least one value, the [combine] function
///    is called.
/// 4. The result is emitted as a [Pulse].
/// 5. Whenever any source updates, the [combine] function is called again.
/// 6. The arming pulse is not part of the combination.
/// 7. The instruction preserves causal provenance.
///
/// ### Comparison with CombineLatestWith
/// | Feature | CombineLatest | CombineLatestWith |
/// |---------|---------------|-------------------|
/// | **Source in Combination** | No | Yes |
/// | **Arming** | Source is arming gate | Source is also a source |
/// | **Use Case** | Extra sources only | Source + extras |
///
/// ### Non‑obvious
/// - **Arming Only**: The first source pulse is only used to arm.
/// - **All Must Have Value**: Emission only happens after all sources have
///   at least one value.
/// - **Latest Values**: Always uses the most recent value from each source.
/// - **Any Update Triggers**: Any source update triggers a new combination.
/// - **No Source Forwarding**: The arming pulse is not part of the combination.
/// - **Error Handling**: Errors in [combine] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Combine Multiple Sources
/// ```dart
/// final gate = Cell.ingress<void>();
/// final temp = Cell.ingress<double>();
/// val humidity = Cell.ingress<double>();
/// val combined = CombineLatest<Environment>(
///   [temp.cell, humidity.cell],
///   (latest) => Environment(temp: latest[0] as double, humidity: latest[1] as double)
/// ).toHandle(source: gate.cell);
///
/// await gate.emitAsync(null); // arms only
/// await temp.emitAsync(25.0); // no emission (humidity missing)
/// await humidity.emitAsync(60.0); // emits combined
/// ```
///
/// ### Parameters:
/// - [sources]: **The Cells to Combine.** Cells whose values will be combined.
/// - [combine]: **The Combination Function.** Takes a list of latest values
///   from all sources, returns the combined result.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [R]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [CombineLatestWith]: For combining source with others.
/// - [WithLatestFrom]: For source-driven combination.
class CombineLatest<R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [CombineLatest] instruction with the specified [sources]
  /// and [combine] function.
  ///
  /// ### Parameters:
  /// - [sources]: **The Cells to Combine.** Cells whose values will be combined.
  /// - [combine]: **The Combination Function.** Takes a list of latest values
  ///   from all sources, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val combineLatest = CombineLatest<MyState>(
  ///   [cell1.cell, cell2.cell],
  ///   (latest) => MyState.fromList(latest),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  CombineLatest(
      Iterable<Cell> sources,
      R Function(List<Object?> latest) combine, {
        CombineErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final slots = [for (final _ in sources) _LatestSlot()];
      final list = sources.toList();
      final emit = _EmitState();
      var armed = false;

      void publish(Pulse trigger) {
        if (slots.any((s) => !s.has)) return;
        try {
          final result = combine([for (final s in slots) s.value]);
          emit.future?.call(
            result: _out<R>(result, trigger, emit.cell, 'CombineLatest'),
            token: emit.token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
        }
      }

      return (pulse, {cell, user, future, token}) {
        emit.future = future;
        emit.token = token;
        emit.cell = cell;
        if (!armed) {
          armed = true;
          for (var i = 0; i < list.length; i++) {
            final index = i;
            Cell.observe(
              source: list[index],
              effect: (Pulse incoming) {
                slots[index].value = incoming.payload;
                slots[index].has = true;
                publish(incoming);
              },
            );
          }
        }
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// WithLatestFrom
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only when the bound source pulses,
/// pairing it with the latest values of [others] (Rx `withLatestFrom`).
///
/// [WithLatestFrom] acts as a **Source-Driven Combiner**. It only emits when
/// the source updates, using the latest values from the other cells at that
/// moment.
///
/// ### When to use
/// Use [WithLatestFrom] when:
/// - You want to combine the source with the latest values of others
/// - You only want to emit when the source updates
/// - You're implementing a "sample on source" pattern
/// - You're driving updates from one primary source
/// - You're pairing user actions with the latest state
/// - You're implementing a command pattern with state
/// - You're creating a derived value on demand
///
/// ### How it works
/// 1. Observers are started on all [others] cells to track their latest values.
/// 2. When the bound source pulses, the [combine] function is called with
///    the source value and the latest values from [others].
/// 3. If any other cell has not yet produced a value, the source pulse is dropped.
/// 4. The result is emitted as a [Pulse].
/// 5. The instruction preserves causal provenance.
///
/// ### Comparison with CombineLatestWith
/// | Feature | WithLatestFrom | CombineLatestWith |
/// |---------|----------------|-------------------|
/// | **Emit Trigger** | Source only | Any source |
/// | **Others Update** | No emission | Triggers emission |
/// | **Use Case** | Source-driven | Any-update-driven |
///
/// ### Non‑obvious
/// - **Source-Driven**: Only source updates trigger emission.
/// - **Latest Values**: Uses the latest values from others at the time of
///   source update.
/// - **Drop on Miss**: Source pulses are dropped if any other cell has no value.
/// - **Error Handling**: Errors in [combine] are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Command with Latest State
/// ```dart
/// final actions = Cell.ingress<String>();
/// val state = Cell.ingress<AppState>();
/// val processed = WithLatestFrom<String, Processed>(
///   [state.cell],
///   (action, latest) => Processed(action: action, state: latest.single as AppState)
/// ).toHandle(source: actions.cell);
///
/// // Only emits when actions emit, using the latest state
/// await state.emitAsync(initialState);
/// await actions.emitAsync('update'); // emits processed action
/// ```
///
/// ### Example: Logging with Context
/// ```dart
/// final events = Cell.ingress<Event>();
/// val user = Cell.ingress<User>();
/// val logged = WithLatestFrom<Event, LogEntry>(
///   [user.cell],
///   (event, latest) => LogEntry(event: event, user: latest.single as User)
/// ).toHandle(source: events.cell);
/// ```
///
/// ### Parameters:
/// - [others]: **The Additional Cells.** Cells to sample the latest values from.
/// - [combine]: **The Combination Function.** Takes the source value and a
///   list of latest values from others, returns the combined result.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the source payload.
/// - [R]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [CombineLatestWith]: For any-update-driven combination.
/// - [CombineLatest]: For combining extra cells only.
class WithLatestFrom<S, R> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [WithLatestFrom] instruction with the specified [others]
  /// and [combine] function.
  ///
  /// ### Parameters:
  /// - [others]: **The Additional Cells.** Cells to sample the latest values from.
  /// - [combine]: **The Combination Function.** Takes the source value and a
  ///   list of latest values from others, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val withLatestFrom = WithLatestFrom<int, String>(
  ///   [state.cell],
  ///   (source, latest) => '$source-${latest.single}',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  WithLatestFrom(
      Iterable<Cell> others,
      R Function(S source, List<Object?> latest) combine, {
        CombineErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final slots = [for (final _ in others) _LatestSlot()];
      final list = others.toList();
      var armed = false;
      return (pulse, {cell, user, future, token}) {
        if (!armed) {
          armed = true;
          for (var i = 0; i < list.length; i++) {
            final index = i;
            Cell.observe(
              source: list[index],
              effect: (Pulse incoming) {
                slots[index].value = incoming.payload;
                slots[index].has = true;
              },
            );
          }
        }
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
        if (slots.any((s) => !s.has)) return null;
        try {
          return _out<R>(
            combine(payload, [for (final s in slots) s.value]),
            pulse,
            cell,
            'WithLatestFrom',
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          return null;
        }
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// CombineLatest2
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that combines two typed cells
/// (Rx `combineLatest` of two).
///
/// [CombineLatest2] acts as a **Typed Pair Combiner**. It is a specialized
/// version of [CombineLatestWith] for exactly two cells, providing a
/// cleaner API with named types.
///
/// ### When to use
/// Use [CombineLatest2] when:
/// - You have exactly two typed cells to combine
/// - You want type-safe combination with named parameters
/// - You're combining two form fields
/// - You're pairing two data streams
/// - You're implementing a binary combine operation
/// - You're merging two state sources
/// - You're creating a derived value from two inputs
///
/// ### How it works
/// 1. The first source pulse arms the instruction and provides the source value.
/// 2. The other cell is observed for updates.
/// 3. Once both cells have at least one value, the [combine] function is called.
/// 4. The result is emitted as a [Pulse].
/// 5. Whenever either cell updates, the [combine] function is called again.
/// 6. The instruction preserves causal provenance.
///
/// ### Example: Typed Pair
/// ```dart
/// final first = Cell.ingress<int>();
/// final second = Cell.ingress<String>();
/// val paired = CombineLatest2<int, String, String>(
///   second.cell,
///   (a, b) => '$a:$b'
/// ).toHandle(source: first.cell);
///
/// first.emit(3); // No emission (second missing)
/// second.emit('ok'); // Emits '3:ok'
/// ```
///
/// ### Parameters:
/// - [other]: **The Other Cell.** The second cell to combine with the source.
/// - [combine]: **The Combination Function.** Takes the source value and the
///   other value, returns the combined result.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [A]: The type of the source payload.
/// - [B]: The type of the other payload.
/// - [R]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [CombineLatestWith]: For combining with multiple cells.
/// - [WithLatestFrom]: For source-driven combination.
class CombineLatest2<A, B, R> extends CombineLatestWith<A, R> {
  /// Creates a [CombineLatest2] instruction with the specified [other]
  /// and [combine] function.
  ///
  /// ### Parameters:
  /// - [other]: **The Other Cell.** The second cell to combine with the source.
  /// - [combine]: **The Combination Function.** Takes the source value and the
  ///   other value, returns the combined result.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val combineLatest2 = CombineLatest2<int, String, String>(
  ///   other.cell,
  ///   (a, b) => '$a:$b',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  CombineLatest2(
      Cell other,
      R Function(A a, B b) combine, {
        CombineErrorHandler? onError,
        dynamic user,
      }) : super(
    [other],
        (a, latest) => combine(a, latest.single as B),
    onError: onError,
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [CombineLatestWith] instruction and related operators
/// showing their behavior in various combination scenarios.
///
/// ### Expected console output:
/// ```text
/// ── CombineLatest Operators Demo ──────────────────────────────
///
/// 1. CombineLatestWith - source + others
///    [CombineLatestWith] 1-x
///    [CombineLatestWith] 1-y
///
/// 2. CombineLatest - extra Cells only
///    [CombineLatest] 1-x
///    [CombineLatest] 2-x
///
/// 3. WithLatestFrom - source pulses only
///    [WithLatestFrom] 2-y
///
/// 4. CombineLatest2 - typed pair
///    [CombineLatest2] 3:ok
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
/// 1. **CombineLatestWith - source + others**: Shows multi-source combination
///    with source included. The combine function has access to both the source
///    and all other cells. `1` + `x, y` → `1-x, 1-y`
///
/// 2. **CombineLatest - extra Cells only**: Shows combination where the bound
///    source is only used for arming. The combine function only has access to
///    the extra cells. `1, x` → `1-x`, `2, x` → `2-x`
///
/// 3. **WithLatestFrom - source pulses only**: Shows source-driven combination.
///    Only source updates trigger emission, using the latest values from others.
///    `2` + `y` → `2-y`
///
/// 4. **CombineLatest2 - typed pair**: Shows typed two-cell combination with
///    a cleaner API. `3` + `ok` → `3:ok`
///
/// ### Key Takeaways
/// - All combine operators require all sources to have at least one value.
/// - CombineLatestWith includes the source in the combination.
/// - CombineLatest uses the source only for arming.
/// - WithLatestFrom only emits on source updates.
/// - CombineLatest2 provides typed two-cell combination.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── CombineLatest Operators Demo ──────────────────────────────\n');

  print('1. CombineLatestWith - source + others');
  final a = Cell.ingress<int>();
  final b = Cell.ingress<String>();
  final clw = CombineLatestWith<int, String>(
    [b.cell],
        (n, latest) => '$n-${latest.single}',
  ).toHandle(source: a.cell);
  final cObs = Cell.observe(
    source: clw.cell,
    effect: (Pulse p) => print('   [CombineLatestWith] ${p.payload}'),
  );
  await a.emitAsync(1);
  await b.emitAsync('x');
  await b.emitAsync('y');
  cObs.stop();
  print('');

  print('2. CombineLatest - extra Cells only');
  final gate = Cell.ingress<void>();
  final left = Cell.ingress<int>();
  final right = Cell.ingress<String>();
  final cl = CombineLatest<String>(
    [left.cell, right.cell],
        (latest) => '${latest[0]}-${latest[1]}',
  ).toHandle(source: gate.cell);
  final nObs = Cell.observe(
    source: cl.cell,
    effect: (Pulse p) => print('   [CombineLatest] ${p.payload}'),
  );
  await gate.emitAsync(null);
  await left.emitAsync(1);
  await right.emitAsync('x');
  await left.emitAsync(2);
  nObs.stop();
  print('');

  print('3. WithLatestFrom - source pulses only');
  final s = Cell.ingress<int>();
  final o = Cell.ingress<String>();
  final wlf = WithLatestFrom<int, String>(
    [o.cell],
        (n, latest) => '$n-${latest.single}',
  ).toHandle(source: s.cell);
  final wObs = Cell.observe(
    source: wlf.cell,
    effect: (Pulse p) => print('   [WithLatestFrom] ${p.payload}'),
  );
  await s.emitAsync(1);
  await o.emitAsync('y');
  await s.emitAsync(2);
  wObs.stop();
  print('');

  print('4. CombineLatest2 - typed pair');
  final p = Cell.ingress<int>();
  final q = Cell.ingress<String>();
  final pair = CombineLatest2<int, String, String>(
    q.cell,
        (n, label) => '$n:$label',
  ).toHandle(source: p.cell);
  final pObs = Cell.observe(
    source: pair.cell,
    effect: (Pulse p) => print('   [CombineLatest2] ${p.payload}'),
  );
  await p.emitAsync(3);
  await q.emitAsync('ok');
  pObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}