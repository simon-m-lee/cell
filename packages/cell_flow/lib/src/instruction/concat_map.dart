// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that flatten inner sequences (Rx `concatMap` family).
///
/// | Operator | Rx analogue | Overlap | Order |
/// |---|---|---|---|
/// | [ConcatMap] | `concatMap` | no | trigger then inner |
/// | [ConcatMapTo] | `concatMapTo` | no | same inner every time |
/// | [ConcatMapLatest] | `switchMap` | cancel previous | latest inner |
/// | [ConcatMapFirst] | `exhaustMap` | drop while busy | first inner |
///
/// [mapper] / inner sources may return a [Stream], [Future], [Iterable],
/// a raw value, or `null` (drop). Nested values are drained recursively.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef FlattenErrorHandler = void Function(Object error, StackTrace? stackTrace);
typedef FlattenMapper<S> = FutureOr<Object?> Function(S value);

Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

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
// ConcatMap
// ─────────────────────────────────────────────────────────────

/// Sequential flatten: each inner sequence finishes before the next starts
/// (Rx `concatMap`).
///
/// ### When to use
/// - Multi-phase workflows that must not interleave
/// - Unrolling a list / stream per command in FIFO order
///
/// ### How it works
/// 1. The payload is type-checked as [S].
/// 2. [mapper] produces an inner sequence.
/// 3. Items are emitted one by one as [T] pulses.
/// 4. A later trigger is queued until the current inner completes.
///
/// ### Example
/// ```dart
/// final orders = Cell.ingress<String>();
/// final life = ConcatMap<String, String>((id) async* {
///   yield '$id:created';
///   yield '$id:paid';
/// }).toHandle(source: orders.cell);
/// ```
///
/// ### See Also:
/// [ConcatMapTo], [ConcatMapLatest], [ConcatMapFirst]
class ConcatMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatMap(
    FlattenMapper<S> mapper, {
    FlattenErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final queue = _ConcatQueue();
            return (pulse, {cell, user, future, token}) {
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
              queue.enqueue(() async {
                try {
                  final inner = await Future.sync(() => mapper(payload));
                  await _drain(inner, (value) {
                    if (value is T) {
                      future!(
                        result: _out<T>(value, cell, pulse, 'ConcatMap'),
                        token: token,
                      );
                    }
                  });
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

/// Rx `concatMapTo` — ignore the trigger payload and flatten the same
/// inner sequence after every pulse.
class ConcatMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatMapTo(
    FutureOr<Object?> Function() inner, {
    FlattenErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final queue = _ConcatQueue();
            return (pulse, {cell, user, future, token}) {
              queue.enqueue(() async {
                try {
                  final seq = await Future.sync(inner);
                  await _drain(seq, (value) {
                    if (value is T) {
                      future!(
                        result: _out<T>(value, cell, pulse, 'ConcatMapTo'),
                        token: token,
                      );
                    }
                  });
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

/// Latest-only flatten (Rx `switchMap` semantics, concatMap naming).
///
/// A new trigger cancels emission from the previous inner sequence.
/// Use for search-as-you-type or selection changes.
class ConcatMapLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatMapLatest(
    FlattenMapper<S> mapper, {
    FlattenErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final gen = _GenerationState();
            return (pulse, {cell, user, future, token}) {
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
              final id = ++gen.generation;
              Future<void>(() async {
                try {
                  final inner = await Future.sync(() => mapper(payload));
                  if (id != gen.generation) return;
                  await _drain(
                    inner,
                    (item) {
                      if (id != gen.generation) return;
                      if (item is T) {
                        future!(
                          result: _out<T>(item, cell, pulse, 'ConcatMapLatest'),
                          token: token,
                        );
                      }
                    },
                    stillLive: () => id == gen.generation,
                  );
                } catch (e, stack) {
                  if (id == gen.generation) onError?.call(e, stack);
                }
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// First-wins flatten (Rx `exhaustMap` semantics, concatMap naming).
///
/// Triggers that arrive while an inner sequence is running are dropped.
/// Use for submit / save buttons that must not double-fire.
class ConcatMapFirst<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  ConcatMapFirst(
    FlattenMapper<S> mapper, {
    FlattenErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _BusyState();
            return (pulse, {cell, user, future, token}) {
              if (state.busy) return null;
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
              state.busy = true;
              Future<void>(() async {
                try {
                  final inner = await Future.sync(() => mapper(payload));
                  await _drain(inner, (item) {
                    if (item is T) {
                      future!(
                        result: _out<T>(item, cell, pulse, 'ConcatMapFirst'),
                        token: token,
                      );
                    }
                  });
                } catch (e, stack) {
                  onError?.call(e, stack);
                } finally {
                  state.busy = false;
                }
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

class _ConcatQueue {
  Future<void> tail = Future<void>.value();

  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}

class _GenerationState {
  int generation = 0;
}

class _BusyState {
  bool busy = false;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// Demonstration of the concatMap family.
///
/// ### Expected console output:
/// ```text
/// ── ConcatMap Operators Demo ──────────────────────────────────
///
/// 1. ConcatMap - Sequential lifecycle
///    [ConcatMap] ORD-1:created
///    [ConcatMap] ORD-1:paid
///    [ConcatMap] ORD-2:created
///    [ConcatMap] ORD-2:paid
///
/// 2. ConcatMapTo - Same inner every trigger
///    [ConcatMapTo] ping
///    [ConcatMapTo] pong
///    [ConcatMapTo] ping
///    [ConcatMapTo] pong
///
/// 3. ConcatMapLatest - Latest inner only
///    [ConcatMapLatest] new-1
///    [ConcatMapLatest] new-2
///
/// 4. ConcatMapFirst - Ignore while busy
///    [ConcatMapFirst] 1-a
///    [ConcatMapFirst] 1-b
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── ConcatMap Operators Demo ──────────────────────────────────\n');

  print('1. ConcatMap - Sequential lifecycle');
  final orders = Cell.ingress<String>();
  final life = ConcatMap<String, String>((id) async* {
    yield '$id:created';
    await Future<void>.delayed(const Duration(milliseconds: 25));
    yield '$id:paid';
  }).toHandle(source: orders.cell);
  final lifeObs = Cell.observe(
    source: life.cell,
    effect: (Pulse p) => print('   [ConcatMap] ${p.payload}'),
  );
  await orders.emitAsync('ORD-1');
  await orders.emitAsync('ORD-2');
  await Future<void>.delayed(const Duration(milliseconds: 120));
  lifeObs.stop();
  print('');

  print('2. ConcatMapTo - Same inner every trigger');
  final clicks = Cell.ingress<void>();
  final echo = ConcatMapTo<void, String>(() async* {
    yield 'ping';
    yield 'pong';
  }).toHandle(source: clicks.cell);
  final echoObs = Cell.observe(
    source: echo.cell,
    effect: (Pulse p) => print('   [ConcatMapTo] ${p.payload}'),
  );
  await clicks.emitAsync(null);
  await clicks.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  echoObs.stop();
  print('');

  print('3. ConcatMapLatest - Latest inner only');
  final query = Cell.ingress<String>();
  final latest = ConcatMapLatest<String, String>((q) async* {
    await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 10));
    yield '$q-1';
    yield '$q-2';
  }).toHandle(source: query.cell);
  final latestObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [ConcatMapLatest] ${p.payload}'),
  );
  await query.emitAsync('old');
  await query.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  latestObs.stop();
  print('');

  print('4. ConcatMapFirst - Ignore while busy');
  final taps = Cell.ingress<int>();
  final first = ConcatMapFirst<int, String>((n) async* {
    yield '$n-a';
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield '$n-b';
  }).toHandle(source: taps.cell);
  final firstObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [ConcatMapFirst] ${p.payload}'),
  );
  await taps.emitAsync(1);
  await taps.emitAsync(2);
  await taps.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  firstObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}
