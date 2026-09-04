// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that interleave several sources (Rx `merge` family).
///
/// These operators combine multiple sources into a single stream by
/// interleaving their emissions. They are essential for combining events
/// from multiple UI components, merging data from different sources, or
/// flattening nested structures.
///
/// | Operator | Rx analogue | Sources |
/// |---|---|---|
/// | [MergeWith] | `mergeWith` | bound source + extra [Cell]s |
/// | [Merge] | `merge` | extra [Cell]s only (source is the arming gate) |
/// | [MergeAll] | `mergeAll` | payload *is* an inner sequence |
///
/// A [FlowInstruction] can emit only after it has been given `future`
/// by the first source pulse. Arm [Merge] / [MergeWith] with one
/// `emitAsync` on the bound handle (the payload may be ignored).
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef MergeErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

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
    final value = await inner;
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

// ─────────────────────────────────────────────────────────────
// MergeWith
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards the bound source and every pulse
/// from [others] (Rx `mergeWith`).
///
/// [MergeWith] acts as a **Source Merger**. It combines the bound source
/// cell with additional cells, forwarding pulses from all of them in an
/// interleaved fashion.
///
/// ### When to use
/// Use [MergeWith] when you need to combine multiple sources:
///
/// - **UI Events**: Combine clicks from several widgets
/// - **Data Sources**: Merge a local cache Cell with a network Cell
/// - **Multiple Inputs**: Combine events from different input devices
/// - **Feature Flags**: Merge different feature streams
/// - **Real-time Data**: Combine real-time data from multiple sources
/// - **User Actions**: Merge different user actions into one stream
/// - **Sensors**: Combine readings from multiple sensors
/// - **Timers**: Merge multiple timer events
///
/// ### Choosing Between Merge Patterns
/// - **Use [MergeWith]** for **Source + Others**: When you want to merge
///   the bound source with additional cells.
/// - **Use [Merge]** for **Others Only**: When the bound source is only
///   used to arm the instruction.
/// - **Use [MergeAll]** for **Flattening**: When the payload itself is
///   an inner sequence to merge.
///
/// ### Comparison with Other Operators
/// | Operator | Sources | Arming | Use Case |
/// |----------|---------|--------|----------|
/// | **MergeWith** | Source + others | Source | Source + extras |
/// | **Merge** | Others only | Arming gate | Extra sources only |
/// | **MergeAll** | Payload as inner | First pulse | Flattening |
/// | **ConcatMap** | Sequential | Trigger | Sequential |
/// | **SwitchMap** | Latest only | Trigger | Latest only |
///
/// ### How it works
/// 1. The first source pulse arms the instruction by storing the `future`
///    and `token` for emission.
/// 2. Observers are started on all [others] cells.
/// 3. The bound source pulse passes through (if [forwardSource] is true).
/// 4. Pulses from [others] are forwarded with step `MergeWith.other`.
/// 5. Later source pulses pass through (if [forwardSource] is true).
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Arming**: The first source pulse is required to arm the instruction.
/// - **Interleaved**: Pulses from different sources are interleaved.
/// - **Order Preservation**: Within each source, order is preserved.
/// - **Error Handling**: Type errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Memory Efficiency**: Only the state for emission is stored.
///
/// ### Example: Merge Two UI Components
/// ```dart
/// final button1 = Cell.ingress<int>();
/// final button2 = Cell.ingress<int>();
/// val both = MergeWith<int>([button2.cell])
///     .toHandle(source: button1.cell);
///
/// await button1.emitAsync(0); // arms and emits
/// await button1.emitAsync(1); // emits from source
/// await button2.emitAsync(2); // emits from other
/// // Result: [0, 1, 2]
/// ```
///
/// ### Example: Merge Cache and Network
/// ```dart
/// final cache = Cell.ingress<Data>();
/// val network = Cell.ingress<Data>();
/// val merged = MergeWith<Data>([network.cell])
///     .toHandle(source: cache.cell);
///
/// // Cache emits first, network emits later
/// ```
///
/// ### Parameters:
/// - [others]: **The Additional Cells.** Cells to merge with the source.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [forwardSource]: **Forward Source Pulses.** If `true` (default),
///   pulses from the source are forwarded. If `false`, only others are
///   forwarded after arming.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Merge]: For merging only extra cells.
/// - [MergeAll]: For flattening inner sequences.
/// - [ConcatMap]: For sequential flattening.
class MergeWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [MergeWith] instruction with the specified [others].
  ///
  /// ### Parameters:
  /// - [others]: **The Additional Cells.** Cells to merge with the source.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [forwardSource]: **Forward Source Pulses.** If `true` (default),
  ///   pulses from the source are forwarded. If `false`, only others are
  ///   forwarded after arming.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val mergeWith = MergeWith<int>([other.cell],
  ///   forwardSource: true,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  MergeWith(
      Iterable<Cell> others, {
        MergeErrorHandler? onError,
        bool forwardSource = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _EmitState();
      var armed = false;
      return (pulse, {cell, user, future, token}) {
        state.future = future;
        state.token = token;
        state.cell = cell;
        if (!armed) {
          armed = true;
          for (final other in others) {
            Cell.observe(
              source: other,
              effect: (Pulse incoming) {
                final payload = incoming.payload;
                if (payload is! S) {
                  onError?.call(
                    FormatException(
                      'Expected payload of type $S, got ${payload.runtimeType}',
                    ),
                    StackTrace.current,
                  );
                  return;
                }
                state.future?.call(
                  result: _out<S>(
                    payload,
                    state.cell,
                    incoming,
                    'MergeWith.other',
                  ),
                  token: state.token,
                );
              },
            );
          }
        }
        if (!forwardSource) return null;
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
        return _mark(pulse, 'MergeWith.source');
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Merge
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that merges extra [Cell]s (Rx `merge`).
///
/// [Merge] acts as a **Multi-Source Merger**. The bound source is only
/// used to arm the instruction. After arming, pulses from all specified
/// [sources] are forwarded in an interleaved fashion.
///
/// ### When to use
/// Use [Merge] when:
/// - You want to merge multiple cells into one stream
/// - The arming pulse should not be forwarded
/// - You're using a dedicated gate to start the merge
/// - You want to combine multiple sources without forwarding the trigger
/// - You're implementing a fan-in pattern
/// - You're combining events from multiple sources
/// - You're merging data from different services
///
/// ### How it works
/// 1. The first source pulse arms the instruction by storing the `future`
///    and `token` for emission.
/// 2. Observers are started on all [sources] cells.
/// 3. Pulses from all [sources] are forwarded with step `Merge`.
/// 4. The arming pulse is not forwarded (by default).
/// 5. The instruction preserves causal provenance.
///
/// ### Comparison with MergeWith
/// | Feature | Merge | MergeWith |
/// |---------|-------|-----------|
/// | **Source Forwarding** | No (by default) | Yes (by default) |
/// | **Arming** | Source is arming gate | Source is also a source |
/// | **Use Case** | Extra sources only | Source + extras |
///
/// ### Non‑obvious
/// - **Arming Only**: The first source pulse is only used to arm.
/// - **Interleaved**: Pulses from different sources are interleaved.
/// - **Order Preservation**: Within each source, order is preserved.
/// - **No Source Forwarding**: The arming pulse is not forwarded.
/// - **Error Handling**: Type errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Merge Multiple Sources
/// ```dart
/// final gate = Cell.ingress<void>();
/// final left = Cell.ingress<int>();
/// final right = Cell.ingress<int>();
/// val merged = Merge<int>([left.cell, right.cell])
///     .toHandle(source: gate.cell);
///
/// await gate.emitAsync(null); // arms only
/// await left.emitAsync(10); // emitted
/// await right.emitAsync(20); // emitted
/// // Result: [10, 20] (arming pulse not forwarded)
/// ```
///
/// ### Parameters:
/// - [sources]: **The Cells to Merge.** Cells whose pulses will be forwarded.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [forwardSource]: **Forward Source Pulses.** If `true`, the arming
///   pulse is also forwarded. Defaults to `false`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the sources.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [MergeWith]: For merging source with others.
/// - [MergeAll]: For flattening inner sequences.
class Merge<S> extends MergeWith<S> {
  /// Creates a [Merge] instruction with the specified [sources].
  ///
  /// ### Parameters:
  /// - [sources]: **The Cells to Merge.** Cells whose pulses will be forwarded.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [forwardSource]: **Forward Source Pulses.** If `true`, the arming
  ///   pulse is also forwarded. Defaults to `false`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val merge = Merge<int>([left.cell, right.cell],
  ///   forwardSource: false,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Merge(
      super.sources, {
        super.onError,
        super.forwardSource = false,
        super.user,
      });
}

// ─────────────────────────────────────────────────────────────
// MergeAll
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that concurrently flattens inner sequences
/// (Rx `mergeAll`).
///
/// [MergeAll] acts as a **Concurrent Flattener**. Each payload is treated
/// as an inner sequence (Stream, Future, Iterable, or value), and all
/// sequences are flattened concurrently, interleaving their emissions.
///
/// ### When to use
/// Use [MergeAll] when:
/// - The payload itself is a sequence to flatten
/// - You want to flatten nested structures concurrently
/// - You're implementing concurrent batch processing
/// - You're merging streams from a list
/// - You're flattening nested lists
/// - You're processing multiple streams concurrently
/// - You're implementing a parallel flattening
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted.
/// 2. The payload is treated as an inner sequence.
/// 3. All inner sequences are drained concurrently.
/// 4. Items are emitted as they become available.
/// 5. The instruction preserves causal provenance.
///
/// ### Supported Payload Types
/// The payload can be any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted.
/// - **[Future\<T\>]**: The single value is emitted.
/// - **[Iterable\<T\>]**: Each element is emitted.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission.
/// - **Nested combinations**: Recursively expanded.
///
/// ### Comparison with ConcatAll
/// | Feature | MergeAll | ConcatAll |
/// |---------|----------|-----------|
/// | **Execution** | Concurrent | Sequential |
/// | **Order** | Completion order | Input order |
/// | **Use Case** | Parallel processing | Ordered processing |
///
/// ### Non‑obvious
/// - **Concurrent**: Inner sequences are processed concurrently.
/// - **Interleaved**: Emissions from different sequences are interleaved.
/// - **No Order Guarantee**: Results are emitted in completion order.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Type Safety**: The instruction is generic over [T] (output type).
///
/// ### Example: Merge Lists
/// ```dart
/// final batches = Cell.ingress<Object>();
/// val all = MergeAll<String>().toHandle(source: batches.cell);
///
/// batches.emit(['a', 'b']); // emits 'a', 'b'
/// batches.emit(['x']);     // emits 'x' (interleaved)
/// // Result: ['a', 'x', 'b'] (order may vary)
/// ```
///
/// ### Example: Merge Streams
/// ```dart
/// final sources = Cell.ingress<Stream<String>>();
/// val merged = MergeAll<String>().toHandle(source: sources.cell);
///
/// sources.emit(stream1); // starts streaming
/// sources.emit(stream2); // starts streaming concurrently
/// ```
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload from the inner sequences.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatAll]: For sequential flattening.
/// - [MergeWith]: For merging cells.
/// - [AsyncExpand]: For sequential expansion.
class MergeAll<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [MergeAll] instruction.
  ///
  /// ### Parameters:
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val mergeAll = MergeAll<String>(
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  MergeAll({
    MergeErrorHandler? onError,
    dynamic user,
  }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void> run() async {
        try {
          await _drain(pulse.payload, (item) {
            if (item is T) {
              future!(
                result: _out<T>(item, cell, pulse, 'MergeAll'),
                token: token,
              );
            }
          });
        } catch (e, stack) {
          onError?.call(e, stack);
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [MergeWith] and [Merge].
class _EmitState {
  void Function({required Pulse? result, required dynamic token})? future;
  dynamic token;
  Cell? cell;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [MergeWith] instruction and related operators
/// showing their behavior in various merging scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Merge Operators Demo ──────────────────────────────────────
///
/// 1. MergeWith - source + other
///    [MergeWith] 0
///    [MergeWith] 1
///    [MergeWith] 2
///
/// 2. Merge - others only
///    [Merge] 10
///    [Merge] 20
///
/// 3. MergeAll - overlapping lists / streams
///    [MergeAll] a
///    [MergeAll] x
///    [MergeAll] b
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
/// 1. **MergeWith - source + other**: Shows merging of source with
///    additional cells. The source pulses are forwarded along with pulses
///    from the other cell. `0, 1, 2` → `0, 1, 2`
///
/// 2. **Merge - others only**: Shows merging where the bound source is
///    only used for arming. The arming pulse is not forwarded; only pulses
///    from the extra sources are emitted. `10, 20` → `10, 20`
///
/// 3. **MergeAll - overlapping lists / streams**: Shows concurrent
///    flattening of inner sequences. Lists are flattened and interleaved.
///    `['a','b'], ['x']` → `'a', 'x', 'b'` (order may vary)
///
/// ### Key Takeaways
/// - MergeWith merges the source with other cells.
/// - Merge uses the source only for arming (no source forwarding).
/// - MergeAll flattens inner sequences concurrently.
/// - Merge operators interleave emissions from different sources.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Merge Operators Demo ──────────────────────────────────────\n');

  print('1. MergeWith - source + other');
  final a = Cell.ingress<int>();
  final b = Cell.ingress<int>();
  final both = MergeWith<int>([b.cell]).toHandle(source: a.cell);
  final mObs = Cell.observe(
    source: both.cell,
    effect: (Pulse p) => print('   [MergeWith] ${p.payload}'),
  );
  await a.emitAsync(0);
  await a.emitAsync(1);
  await b.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  mObs.stop();
  print('');

  print('2. Merge - others only');
  final gate = Cell.ingress<void>();
  final left = Cell.ingress<int>();
  final right = Cell.ingress<int>();
  final merged =
  Merge<int>([left.cell, right.cell]).toHandle(source: gate.cell);
  final nObs = Cell.observe(
    source: merged.cell,
    effect: (Pulse p) => print('   [Merge] ${p.payload}'),
  );
  await gate.emitAsync(null);
  await left.emitAsync(10);
  await right.emitAsync(20);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  nObs.stop();
  print('');

  print('3. MergeAll - overlapping lists / streams');
  final batches = Cell.ingress<Object>();
  final all = MergeAll<String>().toHandle(source: batches.cell);
  final aObs = Cell.observe(
    source: all.cell,
    effect: (Pulse p) => print('   [MergeAll] ${p.payload}'),
  );
  await batches.emitAsync(['a', 'b']);
  await batches.emitAsync(['x']);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  aObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}