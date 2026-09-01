// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - asyncMap
// ─────────────────────────────────────────────────────────────

/// Maps each upstream payload through an async function and emits results.
///
/// ### Concurrency modes
/// * [concurrency] `0` (default) – unlimited in-flight (mergeMap-style)
/// * [concurrency] `1` – sequential (concatMap-style)
/// * [concurrency] `n` – at most *n* concurrent futures
/// * [latestOnly] `true` – drop results from older generations (switchMap-style)
/// * [exhaust] `true` – **ignore new upstream values while any work is in flight**
///   (exhaustMap-style). Takes precedence over queueing when busy.
///
/// [latestOnly] and [exhaust] are mutually exclusive in intent:
/// * switch → cancel interest in in-flight when a newer value arrives
/// * exhaust → refuse new values until the current in-flight work finishes
Cell _asyncMap<S, T>(
    Cell source,
    Future<T> Function(S value) mapper, {
      int concurrency = 0,
      bool latestOnly = false,
      bool exhaust = false,
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
    }) {
  if (latestOnly && exhaust) {
    throw ArgumentError(
      'asyncMap: use either latestOnly or exhaust, not both',
    );
  }

  final state = _AsyncMapState<S, T>(
    mapper: mapper,
    concurrency: concurrency <= 0 ? 0 : concurrency,
    latestOnly: latestOnly,
    exhaust: exhaust,
  );

  final outputCell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: Receptor.passThrough,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  void emitResult(T value) {
    if (outputCell.isInvalidated) return;
    outputCell._nucleus.receptor.call(
      Pulse<T>.governed(payload: value, source: outputCell),
    );
  }

  final bridge = Cell.governed(
    bind: source,
    context: context,
    testRule: TestCell.allowAll,
    synapses: Synapses.disabled,
    receptor: Receptor(
          (cell, pulse, {user}) {
        if (outputCell.isInvalidated) return null;
        final payload = pulse.payload;
        if (payload is! S) return null;

        state.enqueue(payload, onResult: emitResult);
        return null; // do not forward source pulse
      },
    ),
  );

  state.retain(bridge);
  return outputCell;
}

class _AsyncMapState<S, T> {
  _AsyncMapState({
    required this.mapper,
    required this.concurrency,
    required this.latestOnly,
    required this.exhaust,
  });

  final Future<T> Function(S value) mapper;
  final int concurrency; // 0 = unlimited
  final bool latestOnly;
  final bool exhaust;

  final List<S> _queue = <S>[];
  int _inFlight = 0;
  int _generation = 0;
  Object? _pin;

  void retain(Object pin) => _pin = pin;

  bool get _busy => _inFlight > 0;

  void enqueue(S value, {required void Function(T value) onResult}) {
    // ── exhaustMap: drop upstream while busy ─────────────────
    if (exhaust && _busy) {
      return; // ignore new values until idle
    }

    if (latestOnly) {
      _generation++;
      _queue
        ..clear()
        ..add(value);
      _pump(onResult, generation: _generation);
      return;
    }

    _queue.add(value);
    _pump(onResult, generation: _generation);
  }

  void _pump(void Function(T value) onResult, {required int generation}) {
    while (_queue.isNotEmpty) {
      if (concurrency > 0 && _inFlight >= concurrency) break;
      // exhaust uses concurrency effectively as 1 when in flight via enqueue gate;
      // still respect explicit concurrency for non-exhaust modes.

      final next = _queue.removeAt(0);
      _inFlight++;
      final gen = generation;

      Future<void>(() async {
        try {
          final result = await mapper(next);
          if (latestOnly && gen != _generation) return; // superseded
          onResult(result);
        } catch (_) {
          // Swallow by default (same policy as fromFuture).
        } finally {
          _inFlight--;
          if (!latestOnly || gen == _generation) {
            _pump(onResult, generation: _generation);
          }
        }
      });
    }
  }
}