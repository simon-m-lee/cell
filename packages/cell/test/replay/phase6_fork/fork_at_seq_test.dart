import 'package:cell/cell.dart';
import 'package:test/test.dart';

/// An accumulating counter: update(n) adds n to the current value.
///
/// Tests drive it with the odd payloads 1, 3, 5, … — after k pulses the
/// value is k². Odd payloads never collide with the current value, which
/// matters: `ValueCell.update` dedupes when the input equals the current
/// state (driving 1,2,3,… collides at update(3)).
StateHandle<int> accumulatingCounter() => Cell.state<int>(
      initial: 0,
      evolve: (host, input) =>
          Pulse((host.value ?? 0) + (input.payload as int)),
    );

/// Records [count] accumulating pulses: pulse k carries payload 2k-1
/// (parent seq k-1); the value after k pulses is k².
Future<(CellGraph, Ledger)> recordHistory(int count) async {
  final counter = accumulatingCounter();
  final graph = (CellGraph.builder()..registerState('c', counter)).build();
  final ledger = await graph.bindLedger(
    store: InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );
  await graph.run(() async {
    for (var k = 1; k <= count; k++) {
      counter.update(2 * k - 1);
    }
  });
  return (graph, ledger);
}

CellGraph buildFreshGraph() {
  CellGraphRegistry.forceReset();
  final freshCounter = accumulatingCounter();
  return (CellGraph.builder()..registerState('c', freshCounter)).build();
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('fork at seq 99 records divergedAt=99 and seals the parent',
      () async {
    // 200 accumulating pulses: pulse k = seq k-1; final value 200².
    final (graph, ledger) = await recordHistory(200);
    expect(await ledger.lastSeq, 199);

    // Fork at seq 99 (the 100th pulse; baseline = state after it).
    final fork = await graph.fork(
      parent: ledger,
      atSeq: 99,
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );

    expect(fork.record.divergedAt, 99);
    expect(fork.record.originalLedgerId, graph.id);
    expect(fork.record.parentHeadHash, isNotEmpty);
    expect(fork.record.parentHeadHash, await ledger.hashAtSeq(99));
    expect(fork.record.originalSnapshotHash, isNotEmpty);
    expect(await fork.ledger.lastSeq, 0); // only the ForkRecord so far

    // Baseline replay: the fork starts at the parent's state at seq 99.
    final forkCounter = fork.graph['c']!.cell as ValueCell<int>;
    expect(forkCounter.value, 100 * 100); // 100²

    // Parent untouched.
    expect((graph['c']!.cell as ValueCell<int>).value, 200 * 200);
    expect(await ledger.lastSeq, 199);
    await ledger.close();
  });

  test('non-isolated policies throw UnimplementedError', () async {
    final (graph, ledger) = await recordHistory(5);
    await expectLater(
      graph.fork(
        parent: ledger,
        atSeq: 2,
        buildFreshGraph: buildFreshGraph,
        buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
        policy: ForkPolicy.sharedTopology,
      ),
      throwsUnimplementedError,
    );
    await ledger.close();
  });
}
