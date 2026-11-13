import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('replay 500 pulses against an identical graph succeeds', () async {
    // 1. Build the recording graph.
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var i = 1; i <= 500; i++) {
        counter.update(i);
      }
    });
    expect(await ledger.lastSeq, 499);

    // 2. Build a fresh graph with the same shape.
    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(initial: 0);
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();

    // 3. Replay.
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);

    expect(result.success, isTrue);
    expect(result.entriesReplayed, 500);
    expect(result.divergences, isEmpty);
    expect(counter2.cell.value, 500);
    await ledger.close();
  });

  test('replaying into a ledgered graph is refused', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
    });

    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(initial: 0);
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();
    await graph2.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph2.id),
      ),
    );

    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsStateError,
    );
    await ledger.close();
  });

  test('maxEntries limits the replay to a prefix', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var i = 1; i <= 10; i++) {
        counter.update(i);
      }
    });

    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(initial: 0);
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();

    final result = await ReplayEngine.replay(
      ledger: ledger,
      target: graph2,
      options: const ReplayOptions(maxEntries: 5),
    );
    expect(result.success, isTrue);
    expect(result.entriesReplayed, 5);
    expect(counter2.cell.value, 5);
    await ledger.close();
  });
}
