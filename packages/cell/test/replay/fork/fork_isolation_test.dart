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

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('fork does not mutate the parent graph or ledger', () async {
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
    final parentLastSeq = await ledger.lastSeq;
    final parentValue = counter.cell.value; // 20² = 400
    final parentHeadHash = await ledger.lastHash;

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 9, // baseline 10² = 100
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );

    await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) {
        // Radical mutation: replace every pulse with +100.
        return Pulse<int>(100, source: pulse.source);
      },
    );

    // Parent untouched.
    expect(await ledger.lastSeq, parentLastSeq);
    expect(await ledger.lastHash, parentHeadHash);
    expect(counter.cell.value, parentValue);

    // Fork is different: baseline 100 + 10 x 100.
    final forkCounter = fork.graph['c']!.cell as ValueCell<int>;
    expect(forkCounter.value, 100 + 10 * 100);
    expect(forkCounter.value, isNot(parentValue));

    // The fork chain is independent and intact.
    await fork.verify();
    await ledger.close();
  });
}
