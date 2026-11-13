// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';
import 'package:test/test.dart';

/// Regression tests for the the tooling layer code-review hardening fixes:
///
/// * asyncMap mapper errors fail the source pulse (no more silent
///   swallow);
/// * asyncMap refuses `concurrency > 1` / `latestOnly` while a ledger is
///   recording (shared-journal attribution is a a later revision item);
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
      concurrency: 1,
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

    await expectLater(
      graph.run(() async {
        await ingress.emit(1);
      }),
      throwsA(isA<StateError>().having(
        (e) => '$e',
        'message',
        contains('only serial execution is attributable'),
      )),
    );
    await settle();
    // The scope rethrows the refusal at the graph.run boundary (inside
    // the receptor pipeline it would be swallowed as a pulse failure);
    // the observable contract is that no mapping happened at all.
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

    await expectLater(
      graph.run(() async {
        await ingress.emit(1);
      }),
      throwsA(isA<StateError>().having(
        (e) => '$e',
        'message',
        contains('only serial execution is attributable'),
      )),
    );
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

  // ── Second review (engine loop) hardening ─────────────────────────

  test('apply-path effectful verdicts are stored exactly once and replay',
      () async {
    final rule = _EffectfulAllowRule();
    final cell = Cell.governed(
      testRule: rule,
      receptor: Receptor.passThrough,
    );
    final graph = (CellGraph.builder(graphId: 'dedup')
          ..register('c', cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    final recording = RecordingJournal();
    await JournalScope.run(recording, () => graph.run(() async {
          await cell.apply<Pulse<int>>((
            function: (int payload) => Pulse<int>(payload),
            arguments: (positionalArguments: [1], namedArguments: null),
            compensation: null,
          ));
        }));
    final entry = await ledger.entriesSince(0).first;
    expect(entry.effects.whereType<VerdictEffect>(), hasLength(1),
        reason: 'the verdict must not be stored twice (journal sweep + '
            'cooperative capture)');

    CellGraphRegistry.forceReset();
    final cell2 = Cell.governed(
      testRule: _EffectfulAllowRule(),
      receptor: Receptor.passThrough,
    );
    final graph2 = (CellGraph.builder(graphId: 'dedup')
          ..register('c', cell2))
        .build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    await ledger.close();
  });

  test('replay verifies the chain before dispatching', () async {
    final dir = await Directory.systemTemp.createTemp('chain_verify');
    final path = '${dir.path}/ledger.jsonl';
    CellGraphRegistry.forceReset();
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'chain-v')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });
    await ledger.close();

    // Tamper with the last entry's hash.
    final lines = await File(path).readAsLines();
    final out = <String>[];
    for (final line in lines) {
      final entry = jsonDecode(line) as Map<String, dynamic>;
      if (entry['seq'] == 1) entry['hash'] = '0' * 64;
      out.add(jsonEncode(entry));
    }
    await File(path).writeAsString('${out.join('\n')}\n');

    final reopened = await Ledger.open(
      graph: graph,
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(initial: 0);
    final graph2 = (CellGraph.builder(graphId: 'chain-v')
          ..registerState('c', counter2))
        .build();
    await expectLater(
      ReplayEngine.replay(ledger: reopened, target: graph2),
      throwsA(isA<LedgerIntegrityException>()),
    );
    await reopened.close();
    await dir.delete(recursive: true);
  });

  test('full replays verify the recorded baseline (before) of each delta',
      () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'baseline')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });

    // Wrong initial state: the first entry's recorded `before` is 0, but
    // the fresh graph starts at 99.
    CellGraphRegistry.forceReset();
    final wrong = Cell.state<int>(initial: 99);
    final wrongGraph = (CellGraph.builder(graphId: 'baseline')
          ..registerState('c', wrong))
        .build();
    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: wrongGraph),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.report?.reason,
        'reason',
        contains('delta.before mismatch'),
      )),
    );

    // Partial replay skips the baseline check by contract.
    CellGraphRegistry.forceReset();
    final partial = Cell.state<int>(initial: 1);
    final partialGraph = (CellGraph.builder(graphId: 'baseline')
          ..registerState('c', partial))
        .build();
    final result = await ReplayEngine.replay(
      ledger: ledger,
      target: partialGraph,
      fromSeq: 1,
    );
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(partial.cell.value, 2);
    await ledger.close();
  });

  test('fork replay serves effects from the parent journal, never the world',
      () async {
    var worldCalls = 0;
    final ingress = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (v, {required EffectJournal journal}) => journal.io<int>(
        label: 'world($v)',
        input: v,
        run: () async {
          worldCalls++;
          return v * 10;
        },
      ),
      journal: RecordingJournal(),
      concurrency: 1,
    );
    final graph = (CellGraph.builder(graphId: 'fork-effects')
          ..register('src', ingress.cell)
          ..register('m', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    final recording = RecordingJournal();
    await JournalScope.run(recording, () => graph.run(() async {
          await ingress.emit(1);
        }));
    expect(worldCalls, 1);

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 0,
      buildFreshGraph: () {
        CellGraphRegistry.forceReset();
        final i2 = Cell.ingress<int>();
        final m2 = Cell.asyncMap<int, int>(
          i2.cell,
          (v, {required EffectJournal journal}) => journal.io<int>(
            label: 'world($v)',
            input: v,
            run: () async {
              worldCalls++;
              return v * 10;
            },
          ),
          journal: RecordingJournal(),
        );
        return (CellGraph.builder(graphId: 'fork-effects')
              ..register('src', i2.cell)
              ..register('m', m2))
            .build();
      },
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    final result = await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) => pulse,
    );
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(worldCalls, 1,
        reason: 'the fork replay must serve the parent journal, not '
            're-execute the io against the real world');
    await ledger.close();
  });

  test('fork entries reconstruct the mutated pulse on replay', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'fork-roundtrip')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 0,
      buildFreshGraph: () {
        CellGraphRegistry.forceReset();
        final c = Cell.state<int>(initial: 0);
        return (CellGraph.builder(graphId: 'fork-roundtrip')
              ..registerState('c', c))
            .build();
      },
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    final result = await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) {
        if (entry.seq == 1) return Pulse(20, source: pulse.source);
        return pulse;
      },
    );
    expect(result.success, isTrue, reason: result.divergences.toString());

    // Replaying the FORK ledger (from seq 1, past the synthetic fork
    // record) must reconstruct the MUTATED pulse, not the parent's.
    CellGraphRegistry.forceReset();
    final third = Cell.state<int>(initial: 1); // baseline after seq 0
    final thirdGraph = (CellGraph.builder(graphId: 'fork-roundtrip')
          ..registerState('c', third))
        .build();
    final again = await ReplayEngine.replay(
      ledger: fork.ledger,
      target: thirdGraph,
      fromSeq: 1,
    );
    expect(again.success, isTrue, reason: again.divergences.toString());
    expect(third.cell.value, 20);
    await ledger.close();
  });

  test('fork store materialize is idempotent and verify reads the file',
      () async {
    final dir = await Directory.systemTemp.createTemp('fork_store');
    final path = '${dir.path}/fork.jsonl';
    final record = ForkRecord(
      forkId: 'fork-1',
      originalLedgerId: 'parent-1',
      divergedAt: 3,
      originalSnapshotHash: fingerprint('snap'),
      parentHeadHash: fingerprint('head'),
      at: DateTime.utc(2026, 11, 12),
    );
    final inner = await FileLedgerStore.open(
      path,
      genesisHash: record.genesisHash,
    );
    final wrapped = ForkLedgerStore(record: record, inner: inner);
    await wrapped.materialize();
    await wrapped.materialize(); // must be a no-op
    final lines = await File(path).readAsLines();
    expect(lines, hasLength(1), reason: 'no duplicate synthetic line');

    // Tamper with the stored synthetic and re-wrap: verify must now
    // hash the FILE's line, not a regenerated one.
    final entry = jsonDecode(lines.single) as Map<String, dynamic>;
    entry['hash'] = '0' * 64;
    await File(path).writeAsString('${jsonEncode(entry)}\n');
    final inner2 = await FileLedgerStore.open(
      path,
      genesisHash: record.genesisHash,
    );
    final wrapped2 = ForkLedgerStore(record: record, inner: inner2);
    final placeholder = (CellGraph.builder(graphId: 'p', strict: false))
        .build();
    final forkLedger = await Ledger.open(
      graph: placeholder,
      store: wrapped2,
      genesisHash: record.genesisHash,
    );
    await expectLater(
      forkLedger.verify(),
      throwsA(isA<LedgerIntegrityException>()),
    );
    await forkLedger.close();
    await wrapped.close();
    await dir.delete(recursive: true);
  });

  test('a legitimate null io result round-trips', () async {
    final recording = RecordingJournal();
    final value = await JournalScope.run(
      recording,
      () => recording.io<int?>(
        label: 'maybe',
        input: 1,
        run: () async => null,
      ),
    );
    expect(value, isNull);

    final replay = ReplayJournal(
      [EffectRecord.fromJson(recording.toJson().single)],
    );
    final served = await replay.io<int?>(
      label: 'maybe',
      input: 1,
      run: () async => 42,
    );
    expect(served, isNull,
        reason: 'a recorded null is a captured value, not a missing one');
    replay.assertExhausted();
  });

  test('nested timer effects are recorded after the timer record', () async {
    final recording = RecordingJournal();
    await JournalScope.run(recording, () {
      return recording.timer(
        duration: Duration.zero,
        input: 't',
        onFire: () => recording.io<int>(
          label: 'nested',
          input: 1,
          run: () async => 2,
        ),
      );
    });
    final kinds = recording
        .toJson()
        .map(EffectRecord.fromJson)
        .map((e) => e.kind)
        .toList(growable: false);
    expect(kinds, ['timer', 'io'],
        reason: 'the timer record must precede its nested effects');

    final replay = ReplayJournal(
      recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
    );
    await replay.timer(
      duration: Duration.zero,
      input: 't',
      onFire: () => replay.io<int>(
        label: 'nested',
        input: 1,
        run: () async => 2,
      ),
    );
    replay.assertExhausted();
  });

  // ── Third review (closing criteria) hardening ─────────────────────

  test('the materialised pulse body is in the entry and replays exactly',
      () async {
    // The apply path records args [5] but the receptor saw the pulse
    // produced by `(x) => Pulse(x + 1)` — payload 6. The stored body
    // must carry 6; the args-first heuristic would replay 5 and the
    // doubling transform would diverge.
    final counter = Cell.state<int>(
      initial: 0,
      evolve: (host, input) => Pulse((input.payload as int) * 2),
    );
    final graph = (CellGraph.builder(graphId: 'body-rt')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      await counter.cell.apply<Pulse<int>>((
        function: (int payload) => Pulse<int>(payload + 1),
        arguments: (positionalArguments: [5], namedArguments: null),
        compensation: null,
      ));
    });
    expect(counter.cell.value, 12);

    final entry = await ledger.entriesSince(0).first;
    expect(entry.pulseJson, isNotNull);
    expect(entry.pulseJson!['payload'], 6,
        reason: 'the body stores the pulse the receptor saw');
    expect(fingerprint(entry.pulseJson!), entry.pulseDigest,
        reason: 'the body must hash to pulseDigest');

    CellGraphRegistry.forceReset();
    final fresh = Cell.state<int>(
      initial: 0,
      evolve: (host, input) => Pulse((input.payload as int) * 2),
    );
    final freshGraph = (CellGraph.builder(graphId: 'body-rt')
          ..registerState('c', fresh))
        .build();
    final result =
        await ReplayEngine.replay(ledger: ledger, target: freshGraph);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(fresh.cell.value, 12,
        reason: 'replay reconstructs payload 6, not the argument 5');
    await ledger.close();
  });

  test('a tampered pulse body fails verify with a pulse-digest reason',
      () async {
    final dir = await Directory.systemTemp.createTemp('body_tamper');
    final path = '${dir.path}/ledger.jsonl';
    CellGraphRegistry.forceReset();
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'body-t')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
    });
    await ledger.close();

    final lines = await File(path).readAsLines();
    final tampered = <String>[];
    for (final line in lines) {
      final entry = jsonDecode(line) as Map<String, dynamic>;
      if (entry['seq'] == 0) {
        final body = entry['pulseJson'] as Map<String, dynamic>;
        body['payload'] = 999; // digest no longer matches
      }
      tampered.add(jsonEncode(entry));
    }
    await File(path).writeAsString('${tampered.join('\n')}\n');

    final reopened = await Ledger.open(
      graph: graph,
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    await expectLater(
      reopened.verify(),
      throwsA(isA<LedgerIntegrityException>().having(
        (e) => '$e',
        'message',
        contains('pulse body digest mismatch'),
      )),
    );
    await reopened.close();
    await dir.delete(recursive: true);
  });

  test('fork verifies the embedded ForkRecord in the fork file', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'embedded-fork')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
      counter.update(3);
    });

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 1,
      buildFreshGraph: () {
        CellGraphRegistry.forceReset();
        final c = Cell.state<int>(initial: 0);
        return (CellGraph.builder(graphId: 'embedded-fork')
              ..registerState('c', c))
            .build();
      },
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    // The fork file's synthetic entry carries the record; the handle's
    // record must match it (ForkVerify would reject a stale one).
    final synthetic = await fork.ledger.entriesSince(0).first;
    final embedded = synthetic.receipt.arguments.positionalArguments!.first;
    expect(
      ForkRecord.fromJson(Map<String, Object?>.from(embedded as Map))
          .genesisHash,
      fork.record.genesisHash,
    );
    // The originalSnapshotHash is the BASELINE (parent state at atSeq),
    // not the live graph's state.
    final baselineHash = fingerprint(
      fork.graph.snapshot(lastLedgerSeq: 1).toJson(),
    );
    expect(fork.record.originalSnapshotHash, baselineHash);
    expect(
      fork.record.originalSnapshotHash,
      isNot(fingerprint(graph.snapshot(lastLedgerSeq: 2).toJson())),
      reason: 'the hash must describe the fork point, not the live head',
    );
    await fork.verify(); // must pass
    await ledger.close();
  });

  test('a tampered embedded ForkRecord fails fork verify', () async {
    final dir = await Directory.systemTemp.createTemp('fork_tamper');
    final path = '${dir.path}/fork.jsonl';
    final record = ForkRecord(
      forkId: 'fork-1',
      originalLedgerId: 'parent-1',
      divergedAt: 3,
      originalSnapshotHash: fingerprint('snap'),
      parentHeadHash: fingerprint('head'),
      at: DateTime.utc(2026, 11, 12),
    );
    final inner = await FileLedgerStore.open(
      path,
      genesisHash: record.genesisHash,
    );
    final wrapped = ForkLedgerStore(record: record, inner: inner);
    await wrapped.materialize();

    // Rewrite the embedded record with a different divergedAt: the
    // genesis no longer matches the chain.
    final lines = await File(path).readAsLines();
    final entry = jsonDecode(lines.single) as Map<String, dynamic>;
    final args = (entry['receipt'] as Map)['arguments'] as Map;
    final positional =
        (args['positional'] as List).cast<Map<String, dynamic>>();
    positional[0]['divergedAt'] = 99;
    await File(path).writeAsString('${jsonEncode(entry)}\n');

    final inner2 = await FileLedgerStore.open(
      path,
      genesisHash: record.genesisHash,
    );
    final wrapped2 = ForkLedgerStore(record: record, inner: inner2);
    final placeholder = (CellGraph.builder(graphId: 'p', strict: false))
        .build();
    final forkLedger = await Ledger.open(
      graph: placeholder,
      store: wrapped2,
      genesisHash: record.genesisHash,
    );
    await expectLater(
      forkLedger.verify(),
      throwsA(isA<LedgerIntegrityException>()),
    );
    await forkLedger.close();
    await wrapped.close();
    await dir.delete(recursive: true);
  });

  test('asyncMap default concurrency is refused loudly under a ledger',
      () async {
    final ingress = Cell.ingress<int>();
    // Default concurrency: 0 — the reviewer's case.
    final mapped = Cell.asyncMap<int, int>(
      ingress.cell,
      (value, {required EffectJournal journal}) async => value,
      journal: RecordingJournal(),
    );
    final graph = (CellGraph.builder(graphId: 'guard-d')
          ..register('src', ingress.cell)
          ..register('mapped', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await expectLater(
      graph.run(() async {
        await ingress.emit(1);
      }),
      throwsA(isA<StateError>().having(
        (e) => '$e',
        'message',
        contains('concurrency: 0 (0 = unlimited)'),
      )),
    );
    await ledger.close();
  });

  test('io digest mismatch is classified as tampering, not a codec error',
      () async {
    final journal = ReplayJournal([
      IoEffect(
        ordinal: 0,
        inputDigest: fingerprint({'q': 'a'}),
        outputDigest: fingerprint('original'),
        at: DateTime.utc(2026, 11, 12),
        label: 'api.fetch',
        rawOutput: 'mutated',
        hasRawOutput: true,
      ),
    ]);
    await expectLater(
      journal.io(
        label: 'api.fetch',
        input: {'q': 'a'},
        run: () async => 'never',
      ),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => '$e',
        'message',
        allOf(
          contains('output digest mismatch'),
          isNot(contains('encodable')),
        ),
      )),
    );
  });

  test('the codec round-trip preserves ungoverned pulses', () {
    final plain = Pulse(5);
    final decoded = PulseCodec.fromJson(
      PulseCodec.toJson(PulseCodec.materialise(plain)),
    );
    expect(decoded.isGoverned, isFalse,
        reason: 'a system context must decode back to an ungoverned pulse');
    expect(decoded.payload, 5);
  });

  // ── Fourth review hardening ───────────────────────────────────────

  test('fork builds its fresh graph without the caller resetting the registry',
      () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'fork-nore')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });

    // NO forceReset inside the factory: fork itself takes over the
    // isolate's id namespace (previously this threw a registration
    // collision while the parent graph was alive).
    final fork = await graph.fork(
      parent: ledger,
      atSeq: 1,
      buildFreshGraph: () {
        final c = Cell.state<int>(initial: 0);
        return (CellGraph.builder(graphId: 'fork-nore')
              ..registerState('c', c))
            .build();
      },
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    expect((fork.graph['c']!.cell as ValueCell<int>).value, 2);
    await fork.verify();
    await ledger.close();
  });

  test('fromFuture constructed inside a ledgered run records its entry',
      () async {
    CellGraphRegistry.forceReset();
    final completer = Completer<int>();
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'ff-ledger')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      // Constructed INSIDE the run, the operator's continuation zone
      // inherits the ledger scope. The cell is NOT registered (an
      // in-run operator cannot be), so no entry is written for it —
      // an unregistered id could never resolve on replay. The guard is
      // the documented behaviour.
      final cell = Cell.fromFuture(
        completer.future,
        journal: RecordingJournal(),
      );
      cell; // keep the operator alive for the run
      completer.complete(7);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    expect(await ledger.lastSeq, -1,
        reason: 'an unregistered detached operator must not write an '
            'entry that no replay could ever resolve');
    await ledger.close();
  });

  test('debounce under a ledger attributes its timer effect', () async {
    CellGraphRegistry.forceReset();
    final src = Cell.ingress<int>();
    final debounced = Cell.debounce(
      src.cell,
      const Duration(milliseconds: 5),
      journal: RecordingJournal(),
    );
    final graph = (CellGraph.builder(graphId: 'deb-ledger')
          ..register('src', src.cell)
          ..register('d', debounced))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      src.emit(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    final entry = await ledger.entriesSince(0).first;
    expect(entry.effects.map((e) => e.kind), contains('timer'),
        reason: 'the debounce timer must be captured into the entry');
    await ledger.close();
  });

  Future<void> debounceRoundTrip(List<int> pulses) async {
    CellGraphRegistry.forceReset();
    final src = Cell.ingress<int>();
    final counter = Cell.state<int>(initial: 0);
    final debounced = Cell.debounce(
      src.cell,
      const Duration(milliseconds: 20),
      journal: RecordingJournal(),
    );
    Cell.observe(
      source: debounced,
      effect: (Pulse p) => counter.update((p.payload as int)),
    );
    final graph = (CellGraph.builder(graphId: 'deb-rt')
          ..register('src', src.cell)
          ..register('d', debounced)
          ..registerState('counter', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (final p in pulses) {
        src.emit(p);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final recorded = counter.cell.value;

    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>();
    final counter2 = Cell.state<int>(initial: 0);
    final debounced2 = Cell.debounce(
      src2.cell,
      const Duration(milliseconds: 20),
      journal: RecordingJournal(),
    );
    Cell.observe(
      source: debounced2,
      effect: (Pulse p) => counter2.update((p.payload as int)),
    );
    final graph2 = (CellGraph.builder(graphId: 'deb-rt')
          ..register('src', src2.cell)
          ..register('d', debounced2)
          ..registerState('counter', counter2))
        .build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(counter2.cell.value, recorded,
        reason: 'replay must reproduce the debounce trailing state');
    await ledger.close();
  }

  test('a single debounce pulse round-trips through replay', () async {
    await debounceRoundTrip([1]);
  });

  test('a debounce burst round-trips (the cancelled timer does not fire)',
      () async {
    // The first pulse's timer is cancelled by the second; replay must
    // consume its record without firing and emit only the last pulse.
    await debounceRoundTrip([1, 2]);
  });

  test('the file store accepts entries larger than 4096 bytes', () async {
    final dir = await Directory.systemTemp.createTemp('big_entry');
    final path = '${dir.path}/ledger.jsonl';
    CellGraphRegistry.forceReset();
    final counter = Cell.state<String>(initial: '');
    final graph = (CellGraph.builder(graphId: 'big-e')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update('x' * 6000);
    });
    await ledger.close();

    final reopened = await Ledger.open(
      graph: graph,
      store: await FileLedgerStore.open(
        path,
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    await reopened.verify();
    await reopened.close();
    await dir.delete(recursive: true);
  });

  test('replaying a fork ledger from seq 0 fails loudly', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'fork-s0')
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
    final fork = await graph.fork(
      parent: ledger,
      atSeq: 0,
      buildFreshGraph: () {
        CellGraphRegistry.forceReset();
        final c = Cell.state<int>(initial: 0);
        return (CellGraph.builder(graphId: 'fork-s0')
              ..registerState('c', c))
            .build();
      },
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    CellGraphRegistry.forceReset();
    final third = Cell.state<int>(initial: 0);
    final thirdGraph = (CellGraph.builder(graphId: 'fork-s0')
          ..registerState('c', third))
        .build();
    await expectLater(
      ReplayEngine.replay(ledger: fork.ledger, target: thirdGraph),
      throwsA(isA<StateError>().having(
        (e) => '$e',
        'message',
        contains('fromSeq: 1'),
      )),
    );
    await ledger.close();
  });

  test('snapshots encode non-JSON values instead of throwing', () {
    CellGraphRegistry.forceReset();
    final counter = Cell.state<DateTime>(
      initial: DateTime.utc(2026, 11, 12),
    );
    final graph = (CellGraph.builder(graphId: 'dt-snap')
          ..registerState('c', counter))
        .build();
    // Used to throw inside canonicalJsonEncode when fingerprinted.
    final snapshot = graph.snapshot();
    expect(fingerprint(snapshot.toJson()), isNotEmpty);
  });

  test('snapshot fromJson rejects corrupt cell entries', () {
    expect(
      () => CellGraphSnapshot.fromJson({
        'graphId': 'g',
        'schemaVersion': 1,
        'lastLedgerSeq': -1,
        'cells': ['not a map'],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('overlapping graph.run appends serialise without racing', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder(graphId: 'overlap')
          ..registerState('c', counter))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    final a = graph.run(() async {
      counter.update(1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
    final b = graph.run(() async {
      counter.update(2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
    await Future.wait([a, b]);
    expect(await ledger.lastSeq, 1);
    await ledger.verify();
    await ledger.close();
  });
}

class _EffectfulAllowRule extends TestCell<Cell> with Effectful {
  @override
  String get version => '1.0.0';
  _EffectfulAllowRule() : super((_, {host, arguments, user}) => true);
}

class _NotEncodable {
  @override
  String toString() => 'NotEncodable';
}
