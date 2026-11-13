import 'package:cell/cell.dart';
import 'package:test/test.dart';

StateHandle<int> accumulatingCounter() => Cell.state<int>(
      initial: 0,
      evolve: (host, input) =>
          Pulse((host.value ?? 0) + (input.payload as int)),
    );

CellGraph buildFreshGraph() {
  CellGraphRegistry.forceReset();
  final freshCounter = accumulatingCounter();
  return (CellGraph.builder()..registerState('c', freshCounter)).build();
}

/// A store wrapper that returns a tampered entry for [tamperSeq].
class _TamperedStore implements LedgerStore {
  final LedgerStore inner;
  final int tamperSeq;
  bool armed = false;

  _TamperedStore(this.inner, {required this.tamperSeq});

  @override
  String get genesisHash => inner.genesisHash;

  @override
  Future<void> append(LedgerEntry entry) => inner.append(entry);

  @override
  Future<int> get lastSeq => inner.lastSeq;

  @override
  Future<String?> get lastHash => inner.lastHash;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    await for (final entry in inner.entriesSince(fromSeq)) {
      if (armed && entry.seq == tamperSeq) {
        yield LedgerEntry.fromJson(
          (entry.toJson()
                ..['deltas'] = [
                  {
                    'cellId': 'c',
                    'before':
                        entry.deltas.isEmpty ? 0 : entry.deltas.first.before,
                    'after': -999,
                    'at': entry.at.toUtc().toIso8601String(),
                  },
                ])
              .cast<String, Object?>(),
        );
      } else {
        yield entry;
      }
    }
  }

  @override
  Future<void> close() => inner.close();
}

Future<(Ledger, _TamperedStore)> recordTamperedHistory() async {
  final counter = accumulatingCounter();
  final graph = (CellGraph.builder()..registerState('c', counter)).build();
  final tampered = _TamperedStore(
    InMemoryLedgerStore(genesisHash: Ledger.genesisHashOf(graph.id)),
    tamperSeq: 5,
  );
  final ledger = await graph.bindLedger(store: tampered);
  await graph.run(() async {
    for (var k = 1; k <= 20; k++) {
      counter.update(2 * k - 1);
    }
  });
  return (ledger, tampered);
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('fork verify passes when parent and fork are intact', () async {
    final counter = accumulatingCounter();
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var k = 1; k <= 20; k++) {
        counter.update(2 * k - 1);
      }
    });

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 9,
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );

    await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) => pulse,
    );

    await fork.verify(); // OK
    await ledger.close();
  });

  test('fork verify fails when the parent is tampered', () async {
    final (ledger, tampered) = await recordTamperedHistory();

    final graph = ledger.graph;
    final fork = await graph.fork(
      parent: ledger,
      atSeq: 9,
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) => pulse,
    );

    // Tamper the parent AFTER the fork was created: the fork itself is
    // intact, but verify() must reject it because the parent is not.
    tampered.armed = true;

    await expectLater(
      fork.verify(),
      throwsA(isA<ForkIntegrityException>().having(
        (e) => e.reason,
        'reason',
        contains('parent ledger verification failed'),
      )),
    );
    await ledger.close();
  });

  test('forking from a corrupt parent is refused at fork time', () async {
    final (ledger, tampered) = await recordTamperedHistory();
    tampered.armed = true;

    await expectLater(
      ledger.graph.fork(
        parent: ledger,
        atSeq: 9,
        buildFreshGraph: buildFreshGraph,
        buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
      ),
      throwsA(isA<LedgerIntegrityException>()),
    );
    await ledger.close();
  });
}
