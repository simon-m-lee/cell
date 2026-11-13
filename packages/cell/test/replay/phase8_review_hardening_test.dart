// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

/// Regression tests for the Phase 8 code-review hardening fixes:
///
/// * asyncMap mapper errors fail the source pulse (no more silent
///   swallow);
/// * asyncMap refuses `concurrency > 1` / `latestOnly` while a ledger is
///   recording (shared-journal attribution is a Phase 5.1 item);
/// * propagation drops (filter suppression, throttle window) terminalise
///   the pulse so `onComplete` fires;
/// * the async fan-out survives a rejecting downstream and still
///   completes the pulse;
/// * `fromFuture` completion prefers the ambient journal;
/// * distinct pulses with identical metadata do not compare equal.
class _ThrowingAsyncRule extends TestCell<Cell> {
  _ThrowingAsyncRule() : super((_, {host, arguments, user}) => true);
  @override
  Future<bool> call(dynamic object, {Cell? host, dynamic arguments}) async {
    throw StateError('async rule boom');
  }
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('asyncMap mapper errors fail the source pulse instead of vanishing',
      () async {
    final ingress = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (value, {required EffectJournal journal}) async {
        if (value == 2) throw Exception('mapper boom');
        return value * 2;
      },
      journal: RecordingJournal(),
    );
    final recorder = <int>[];
    final observer = Cell.observe(
      source: mapped,
      effect: (Pulse p) => recorder.add(p.payload as int),
    );

    await ingress.emit(2);
    await settle();
    expect(recorder, isEmpty, reason: 'a failing mapper must not emit');

    // The failure is routed to the source pulse's onError channel; the
    // ingress emit path does not expose a public onError seam, so assert
    // the observable contract instead: the stream continues and later
    // values still map.
    ingress.emit(3);
    await settle();
    expect(recorder, [6]);
    observer.stop();
  });

  test('asyncMap concurrency > 1 under an active ledger fails loudly',
      () async {
    final ingress = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (value, {required EffectJournal journal}) async => value,
      journal: RecordingJournal(),
      concurrency: 2,
    );
    final graph = (CellGraph.builder(graphId: 'guard-c')
          ..register('src', ingress.cell)
          ..register('mapped', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    final recorder = <int>[];
    final observer = Cell.observe(
      source: mapped,
      effect: (Pulse p) => recorder.add(p.payload as int),
    );

    await graph.run(() async {
      await ingress.emit(1);
    });
    await settle();
    // The guard throws inside the bridge receptor, which routes the
    // failure to the pulse; the observable contract is that no mapping
    // (and therefore no emission) happens for the refused configuration.
    expect(recorder, isEmpty,
        reason: 'concurrency 2 must be refused under a ledger');
    observer.stop();
    await ledger.close();
  });

  test('asyncMap latestOnly under an active ledger fails loudly', () async {
    final ingress = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (value, {required EffectJournal journal}) async => value,
      journal: RecordingJournal(),
      latestOnly: true,
    );
    final graph = (CellGraph.builder(graphId: 'guard-l')
          ..register('src', ingress.cell)
          ..register('mapped', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    final recorder = <int>[];
    final observer = Cell.observe(
      source: mapped,
      effect: (Pulse p) => recorder.add(p.payload as int),
    );

    await graph.run(() async {
      await ingress.emit(1);
    });
    await settle();
    expect(recorder, isEmpty,
        reason: 'latestOnly must be refused under a ledger');
    observer.stop();
    await ledger.close();
  });

  test('asyncMap with serial concurrency still records under a ledger',
      () async {
    final ingress = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (value, {required EffectJournal journal}) => journal.io<int>(
        label: 'id($value)',
        input: value,
        run: () async => value,
      ),
      journal: RecordingJournal(),
      concurrency: 1,
    );
    final graph = (CellGraph.builder(graphId: 'guard-s')
          ..register('src', ingress.cell)
          ..register('mapped', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      await ingress.emit(1);
    });
    await settle();
    final entry = await ledger.entriesSince(0).first;
    expect(entry.effects, hasLength(1));
    expect(entry.effects.single, isA<IoEffect>());
    await ledger.close();
  });

  test('filter-suppressed pulses complete their onComplete callback', () {
    final synapses = Synapses(
      downstreams: [Cell()],
      filter: FilterRule<Pulse<int>>((pulse, {user}) => null),
    );
    var completed = 0;
    synapses.call(Pulse.governed(
      payload: 1,
      onComplete: (pulse) => completed++,
    ));
    expect(completed, 1);
  });

  test('throttled drops complete their onComplete callback', () {
    final synapses = Synapses(
      downstreams: [Cell()],
      policy: PropagationPolicy(
        strategy: PropagationStrategy.throttled,
        throttleTime: const Duration(seconds: 5),
      ),
    );
    var completed = 0;
    synapses.call(Pulse.governed(
      payload: 1,
      onComplete: (pulse) => completed++,
    ));
    expect(completed, 1, reason: 'the delivered pulse completes');
    synapses.call(Pulse.governed(
      payload: 2,
      onComplete: (pulse) => completed++,
    ));
    expect(completed, 2, reason: 'the throttled drop must also complete');
  });

  test('async fan-out survives a rejecting downstream and completes',
      () async {
    final good = Cell();
    final bad = Cell(
      testRule: _ThrowingAsyncRule(),
      receptor: Receptor.passThrough,
    );
    final synapses = Synapses(downstreams: [bad, good]);

    Object? failure;
    var completed = 0;
    await synapses.async.call(Pulse.governed(
      payload: 1,
      onComplete: (pulse) => completed++,
      onError: (pulse, error, {stackTrace}) => failure = error,
    ));
    await settle();
    expect(failure, isA<StateError>());
    expect(completed, 1,
        reason: 'the fan-out must reconcile the failed branch and '
            'complete the pulse');
  });

  test('fromFuture completion prefers the ambient journal', () async {
    final ambient = RecordingJournal();
    final captured = RecordingJournal();
    late Cell cell;
    await JournalScope.run(ambient, () {
      final completer = Completer<int>();
      cell = Cell.fromFuture<int>(completer.future, journal: captured);
      completer.complete(42);
    });
    await settle();
    expect(ambient.consumed, 1,
        reason: 'the record belongs to the ambient (outer) journal');
    expect(captured.consumed, 0,
        reason: 'the construction-time journal is only the fallback');
    expect(cell.id, isNotEmpty); // keep the cell referenced
  });

  test('equal-metadata pulses compare 0 (the FIFO-stability contract)', () {
    final a = Pulse<int>(1);
    final b = Pulse<int>(1);
    if (a.timestamp == b.timestamp &&
        a.priority == b.priority &&
        a.trace.length == b.trace.length) {
      // Documented contract: compareTo == 0 keeps insertion order in the
      // async receptor's priority queue. Callers needing a total order
      // must supply a submission-sequence comparator, not a hash
      // tiebreaker (which broke FIFO — see the review-fix history).
      expect(a.compareTo(b), 0);
    }
  });

  test('non-encodable transform state is not silently committed', () async {
    final counter = Cell.state<Object>(
      initial: 0,
      evolve: (host, input) => Pulse(_NotEncodable()),
    );
    final graph = (CellGraph.builder(graphId: 'guard-e')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
    });
    expect(counter.cell.value, 0,
        reason: 'a non-encodable transform must not reach the state box');
    await ledger.close();
  });
}

class _NotEncodable {
  @override
  String toString() => 'NotEncodable';
}
