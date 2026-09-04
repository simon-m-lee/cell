// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Concat Operators
// ─────────────────────────────────────────────────────────────

/// Flow instructions that play inners **one after another**
/// (Rx `concat` family).
///
/// A Cell does not complete, so [Concat] is not "source A then source
/// Cell B". It concatenates **inners** (list / future / stream) that
/// the bound source delivers, or a fixed list of inners armed by the
/// first pulse.
///
/// | Operator | Plays |
/// |---|---|
/// | [Concat] | fixed [inners] after the arming pulse |
/// | [ConcatAll] | each source payload as an inner, queued |
/// | [ConcatFirst] | only the first item of each inner |
/// | [ConcatLatest] | only the last item of each inner |
///
/// Per-item mapping is [ConcatMap] in `concat_map.dart`.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

/// Error handler callback for concat operators.
///
/// Called when an error occurs during concatenation operations.
/// The error and optional stack trace are provided for logging or recovery.
///
/// ### Example
/// ```dart
/// final errorHandler = ConcatErrorHandler((error, stack) {
///   print('Concat error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef ConcatErrorHandler = void Function(Object error, StackTrace? stackTrace);

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

/// Drains any object (Future, Stream, Iterable, or value) into a callback.
///
/// This is the internal engine that handles the various types of inner
/// sequences that concat operators can produce.
///
/// ### How it works
/// 1. If [inner] is `null`, returns immediately.
/// 2. If [inner] is a `Stream`, iterates over it asynchronously.
/// 3. If [inner] is a `Future`, waits for it and recurses.
/// 4. If [inner] is an `Iterable` (not `String`), iterates over it.
/// 5. Otherwise, calls [onData] with the value.
///
/// ### Parameters:
/// - [inner]: The object to drain.
/// - [onData]: Called for each value drained.
/// - [stillLive]: Optional callback to check if the operation is still current.
///
/// ### Non‑obvious
/// - **Recursive Draining**: The function recurses on `Future` and `Iterable`
///   values, allowing nested structures to be flattened.
/// - **Cancellation**: The [stillLive] callback is checked at each step,
///   allowing cancelled operations to stop early.
/// - **String Special Case**: Strings are treated as values, not iterables,
///   to avoid character-by-character iteration.
Future<void> _drain(
    Object? inner,
    void Function(dynamic value) onData, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await Future<dynamic>.value(inner);
    await _drain(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  onData(inner);
}

/// Collects all values from an inner into a list.
///
/// [_collect] drains an inner and collects all values into a list.
/// This is used by [ConcatLatest] to find the last item.
///
/// ### Parameters:
/// - [inner]: The object to collect from.
///
/// ### Returns:
/// A list of all values from the inner.
Future<List<dynamic>> _collect(Object? inner) async {
  final out = <dynamic>[];
  await _drain(inner, out.add);
  return out;
}

// ─────────────────────────────────────────────────────────────
// Concat - Static Sequence Concatenation
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that plays [inners] in order when the bound
/// source first pulses (Rx `concat` of static sequences).
///
/// [Concat] concatenates a fixed list of inners (lists, futures,
/// streams, or values) in order, emitting all values from each inner
/// before moving to the next.
///
/// ### When to use
/// Use [Concat] when you have a fixed list of sequences to play
/// in order.
///
/// - **Sequence Concatenation**: Playing multiple sequences in order.
/// - **Predefined Workflows**: Executing predefined steps.
/// - **Static Data Sources**: Combining static data sources.
/// - **Initialization**: Initializing multiple resources in order.
/// - **Test Data**: Combining test data sequences.
///
/// ### Choosing Between Concat Variants
/// - **Use [Concat]** for **Fixed Sequences**: When you have a fixed
///   list of inners to play in order.
/// - **Use [ConcatAll]** for **Dynamic Sequences**: When each source
///   payload is an inner to play.
/// - **Use [ConcatFirst]** for **First Item Only**: When you only
///   need the first item of each inner.
/// - **Use [ConcatLatest]** for **Last Item Only**: When you only
///   need the last item of each inner.
///
/// ### Comparison with Other Operators
/// | Operator | Inners | Emits | Order | Arming |
/// |----------|--------|-------|-------|--------|
/// | **Concat** | Fixed | All items | Sequential | First pulse |
/// | **ConcatAll** | Dynamic (payload) | All items | Sequential | Each pulse |
/// | **ConcatFirst** | Dynamic (payload) | First item | Sequential | Each pulse |
/// | **ConcatLatest** | Dynamic (payload) | Last item | Sequential | Each pulse |
///
/// ### How it works
/// 1. The first source pulse arms the instruction.
/// 2. Each inner in [inners] is drained in order.
/// 3. All values from each inner are emitted.
/// 4. The instruction stops after all inners are played.
/// 5. Each emitted value gets the step `'Concat'` for provenance.
///
/// ### Non‑obvious
/// - **Fixed Inners**: The inners are fixed at construction time.
/// - **First Pulse Only**: The instruction only arms on the first pulse.
/// - **Sequential**: Inners are played one after another.
/// - **Error Isolation**: Errors in one inner don't stop the next.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Example: Static Sequence Concatenation
/// ```dart
/// final arm = Cell.ingress<void>();
///
/// final concat = Concat<String>([
///   ['a', 'b'],
///   ['c'],
/// ]).toHandle(source: arm.cell);
///
/// arm.emit(null);
/// // Outputs: a, b, c
/// ```
///
/// ### Example: Mixed Inners
/// ```dart
/// final arm = Cell.ingress<void>();
///
/// final concat = Concat<String>([
///   ['a', 'b'],           // Iterable
///   Future.value('c'),    // Future
///   Stream.fromIterable(['d', 'e']), // Stream
/// ]).toHandle(source: arm.cell);
/// // Outputs: a, b, c, d, e
/// ```
///
/// ### Parameters:
/// - [inners]: **Fixed Inners.** The sequences to play in order.
///   Each inner can be a `List`, `Future`, `Stream`, or raw value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that concatenates static sequences.
///
/// ### See Also:
/// - [ConcatAll]: For dynamic sequence concatenation.
/// - [ConcatFirst]: For first item only.
/// - [ConcatLatest]: For last item only.
/// - [ConcatMap]: For per-item mapping.
class Concat<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Concat(
      Iterable<Object?> inners, {
        ConcatErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      var armed = false;
      return (pulse, {cell, user, future, token}) {
        if (armed) return null;
        armed = true;
        Future<void> run() async {
          for (final inner in inners) {
            try {
              await _drain(inner, (item) {
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'Concat'),
                    token: token,
                  );
                }
              });
            } catch (e, stack) {
              onError?.call(e, stack);
            }
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
// ConcatAll - Dynamic Sequence Concatenation
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] where each source payload is an inner;
/// inners run in arrival order (Rx `concatAll`).
///
/// [ConcatAll] treats each source payload as an inner sequence and
/// plays them in arrival order. This is useful when the sequences
/// are dynamically generated.
///
/// ### When to use
/// Use [ConcatAll] when each source payload is a sequence to play
/// in order.
///
/// - **Dynamic Sequences**: When sequences are generated dynamically.
/// - **Stream of Streams**: Concatenating a stream of streams.
/// - **Queue Processing**: Processing queued items sequentially.
/// - **Request/Response**: Concatenating responses in order.
/// - **Lazy Loading**: Loading data sequentially on demand.
///
/// ### Example: Stream of Lists
/// ```dart
/// final lists = Cell.ingress<List<int>>();
///
/// final all = ConcatAll<int>().toHandle(source: lists.cell);
///
/// lists.emit([1, 2]); // -> 1, 2
/// lists.emit([3]);    // -> 3
/// lists.emit([4, 5]); // -> 4, 5
/// // Outputs: 1, 2, 3, 4, 5
/// ```
///
/// ### How it works
/// 1. Each source pulse adds its payload to a queue.
/// 2. The queue is processed one inner at a time.
/// 3. All values from each inner are emitted.
/// 4. If the queue is empty, the instruction waits.
/// 5. Each emitted value gets the step `'ConcatAll'` for provenance.
///
/// ### Non‑obvious
/// - **Dynamic Payloads**: The inners come from the source payloads.
/// - **Queueing**: Inners are queued and processed in order.
/// - **Sequential**: Inners are played one after another.
/// - **Error Isolation**: Errors in one inner don't stop the next.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that concatenates dynamic sequences.
///
/// ### See Also:
/// - [Concat]: For static sequence concatenation.
/// - [ConcatFirst]: For first item only.
/// - [ConcatLatest]: For last item only.
/// - [AsyncExpand]: For flattening with different strategies.
class ConcatAll<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatAll({
    ConcatErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final queue = <Object?>[];
      var busy = false;
      return (pulse, {cell, user, future, token}) {
        queue.add(pulse.payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final inner = queue.removeAt(0);
            try {
              await _drain(inner, (item) {
                if (item is T) {
                  future!(
                    result: _out<T>(item, cell, pulse, 'ConcatAll'),
                    token: token,
                  );
                }
              });
            } catch (e, stack) {
              onError?.call(e, stack);
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
// ConcatFirst - First Item Only
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that only emits the first item of each inner.
///
/// [ConcatFirst] processes each inner and only emits its first item.
/// This is useful when you only need the first value from each
/// sequence.
///
/// ### When to use
/// Use [ConcatFirst] when you only need the first item from each
/// sequence.
///
/// - **First Value**: Getting the first value from each source.
/// - **Head Extraction**: Extracting the head of each sequence.
/// - **Sampling**: Sampling the first value from each sequence.
/// - **Initialization**: Getting the first value for initialization.
/// - **Status Checks**: Getting the first status from each source.
///
/// ### Example: First Values
/// ```dart
/// final lists = Cell.ingress<List<String>>();
///
/// final first = ConcatFirst<String>().toHandle(source: lists.cell);
///
/// lists.emit(['a', 'b', 'c']); // -> a
/// lists.emit(['d', 'e']);      // -> d
/// lists.emit(['f']);           // -> f
/// ```
///
/// ### How it works
/// 1. Each source pulse adds its payload to a queue.
/// 2. The queue is processed one inner at a time.
/// 3. Only the first item of each inner is emitted.
/// 4. The rest of the inner is skipped.
/// 5. Each emitted value gets the step `'ConcatFirst'` for provenance.
///
/// ### Non‑obvious
/// - **First Only**: Only the first item of each inner is emitted.
/// - **Skip Rest**: The rest of the inner is skipped.
/// - **Queueing**: Inners are queued and processed in order.
/// - **Sequential**: Inners are played one after another.
/// - **Error Isolation**: Errors don't stop the next inner.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits the first item of each inner.
///
/// ### See Also:
/// - [Concat]: For full sequence concatenation.
/// - [ConcatAll]: For dynamic sequence concatenation.
/// - [ConcatLatest]: For last item only.
class ConcatFirst<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatFirst({
    ConcatErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final queue = <Object?>[];
      var busy = false;
      return (pulse, {cell, user, future, token}) {
        queue.add(pulse.payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final inner = queue.removeAt(0);
            try {
              var taken = false;
              await _drain(inner, (item) {
                if (taken) return;
                if (item is T) {
                  taken = true;
                  future!(
                    result: _out<T>(item, cell, pulse, 'ConcatFirst'),
                    token: token,
                  );
                }
              }, stillLive: () => !taken);
            } catch (e, stack) {
              onError?.call(e, stack);
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
// ConcatLatest - Last Item Only
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that only emits the last item of each inner
/// (Rx-ish `concat` + `last`).
///
/// [ConcatLatest] processes each inner and only emits its last item.
/// This is useful when you only need the final value from each
/// sequence.
///
/// ### When to use
/// Use [ConcatLatest] when you only need the last item from each
/// sequence.
///
/// - **Last Value**: Getting the last value from each source.
/// - **Tail Extraction**: Extracting the tail of each sequence.
/// - **Final State**: Getting the final state from each source.
/// - **Completion**: Getting the completion value from each sequence.
/// - **Aggregation**: Getting the last value for aggregation.
///
/// ### Example: Last Values
/// ```dart
/// final lists = Cell.ingress<List<String>>();
///
/// final latest = ConcatLatest<String>().toHandle(source: lists.cell);
///
/// lists.emit(['a', 'b', 'c']); // -> c
/// lists.emit(['d', 'e']);      // -> e
/// lists.emit(['f']);           // -> f
/// ```
///
/// ### How it works
/// 1. Each source pulse adds its payload to a queue.
/// 2. The queue is processed one inner at a time.
/// 3. The inner is fully drained and collected.
/// 4. The last typed value of type [T] is emitted.
/// 5. Each emitted value gets the step `'ConcatLatest'` for provenance.
///
/// ### Non‑obvious
/// - **Last Only**: Only the last item of each inner is emitted.
/// - **Full Drain**: The entire inner is drained to find the last.
/// - **Type Filtering**: Only values of type [T] are considered.
/// - **Memory Usage**: Drains the full inner into memory.
/// - **Provenance Preservation**: Each emitted value preserves the
///   source cell, type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that emits the last item of each inner.
///
/// ### See Also:
/// - [Concat]: For full sequence concatenation.
/// - [ConcatAll]: For dynamic sequence concatenation.
/// - [ConcatFirst]: For first item only.
class ConcatLatest<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatLatest({
    ConcatErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final queue = <Object?>[];
      var busy = false;
      return (pulse, {cell, user, future, token}) {
        queue.add(pulse.payload);
        Future<void> pump() async {
          if (busy) return;
          busy = true;
          while (queue.isNotEmpty) {
            final inner = queue.removeAt(0);
            try {
              final items = await _collect(inner);
              final last = items.cast<dynamic>().lastWhere(
                    (e) => e is T,
                orElse: () => null,
              );
              if (last is T) {
                future!(
                  result: _out<T>(last, cell, pulse, 'ConcatLatest'),
                  token: token,
                );
              }
            } catch (e, stack) {
              onError?.call(e, stack);
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

/// A demonstration of the [Concat] instruction and related operators
/// showing their behavior in various concatenation scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Concat Operators Demo ─────────────────────────────────────
///
/// 1. Concat - static inners
///    [Concat] a
///    [Concat] b
///    [Concat] c
///
/// 2. ConcatAll
///    [ConcatAll] 1
///    [ConcatAll] 2
///    [ConcatAll] 3
///
/// 3. ConcatFirst
///    [ConcatFirst] a
///
/// 4. ConcatLatest
///    [ConcatLatest] c
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
/// 1. **Concat - Static Inners**: Shows static sequence concatenation
///    where fixed inners are played in order. The inners `['a', 'b']`
///    and `['c']` are concatenated to produce `a, b, c`.
///
/// 2. **ConcatAll - Dynamic Inners**: Shows dynamic sequence
///    concatenation where each source payload is an inner. The lists
///    `[1, 2]` and `[3]` are concatenated to produce `1, 2, 3`.
///
/// 3. **ConcatFirst - First Item Only**: Shows first-item extraction
///    where only the first item of each inner is emitted. The list
///    `['a', 'b']` produces `a`.
///
/// 4. **ConcatLatest - Last Item Only**: Shows last-item extraction
///    where only the last item of each inner is emitted. The list
///    `['a', 'b', 'c']` produces `c`.
///
/// ### Key Takeaways
/// - Concat plays fixed inners in order on the first pulse.
/// - ConcatAll treats each source payload as an inner.
/// - ConcatFirst only emits the first item of each inner.
/// - ConcatLatest only emits the last item of each inner.
/// - All operators preserve causal provenance via EvolvedPulse.
/// - Inners can be Lists, Futures, Streams, or raw values.
/// - _drain handles all inner types recursively.
///
/// ### Note on Completeness
/// A Cell does not complete, so [Concat] is not "source A then source
/// Cell B". It concatenates inners that the bound source delivers,
/// or a fixed list of inners armed by the first pulse.
Future<void> main() async {
  print('── Concat Operators Demo ─────────────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Concat - Static Inners
  // ─────────────────────────────────────────────────────────────────────
  print('1. Concat - static inners');

  final arm = Cell.ingress<void>();

  final concat = Concat<String>([
    ['a', 'b'],
    ['c'],
  ]).toHandle(source: arm.cell);

  final cObs = Cell.observe(
    source: concat.cell,
    effect: (Pulse p) => print('   [Concat] ${p.payload}'),
  );

  await arm.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  cObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. ConcatAll - Dynamic Inners
  // ─────────────────────────────────────────────────────────────────────
  print('2. ConcatAll');

  final lists = Cell.ingress<List<int>>();

  final all = ConcatAll<int>().toHandle(source: lists.cell);

  final aObs = Cell.observe(
    source: all.cell,
    effect: (Pulse p) => print('   [ConcatAll] ${p.payload}'),
  );

  await lists.emitAsync([1, 2]);
  await lists.emitAsync([3]);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  aObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. ConcatFirst - First Item Only
  // ─────────────────────────────────────────────────────────────────────
  print('3. ConcatFirst');

  final firstIn = Cell.ingress<List<String>>();

  final first = ConcatFirst<String>().toHandle(source: firstIn.cell);

  final fObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [ConcatFirst] ${p.payload}'),
  );

  await firstIn.emitAsync(['a', 'b']);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  fObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. ConcatLatest - Last Item Only
  // ─────────────────────────────────────────────────────────────────────
  print('4. ConcatLatest');

  final lastIn = Cell.ingress<List<String>>();

  final latest = ConcatLatest<String>().toHandle(source: lastIn.cell);

  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [ConcatLatest] ${p.payload}'),
  );

  await lastIn.emitAsync(['a', 'b', 'c']);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  lObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}