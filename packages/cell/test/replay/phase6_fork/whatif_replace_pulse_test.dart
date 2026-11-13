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

  test('replace pulse #150 payload, replay to 200, check alternative state',
      () async {
    // 200 accumulating pulses with odd payloads: pulse k = seq k-1
    // carries 2k-1; the value after k pulses is k².
    final counter = accumulatingCounter();
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var k = 1; k <= 200; k++) {
        counter.update(2 * k - 1);
      }
    });
    expect(counter.cell.value, 200 * 200); // 40000

    // Fork at pulse 100 (seq 99): baseline = 100² = 10000.
    final fork = await graph.fork(
      parent: ledger,
      atSeq: 99,
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );
    final forkCounter = fork.graph['c']!.cell as ValueCell<int>;
    expect(forkCounter.value, 10000);

    // Replay pulses 101..200 (seqs 100..199), replacing pulse #150
    // (original payload 299) with +1000.
    final result = await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) {
        if (pulse.payload == 299) {
          return Pulse<int>(1000, source: pulse.source);
        }
        return pulse;
      },
    );

    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(result.entriesReplayed, 100); // parent seqs 100..199
    // 10000 + (sum(201..399) - 299 + 1000)
    //     = 10000 + 30000 - 299 + 1000 = 40701.
    expect(forkCounter.value, 40701);

    // The fork's ledger holds the ForkRecord + one entry per replayed
    // pulse, independently verifiable against the parent.
    expect(await fork.ledger.lastSeq, 100);
    await fork.verify();
    // Parent untouched.
    expect(counter.cell.value, 40000);
    expect(await ledger.lastSeq, 199);
    await ledger.close();
  });

  test('dropping a pulse leaves the fork without that entry', () async {
    final counter = accumulatingCounter();
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var k = 1; k <= 10; k++) {
        counter.update(2 * k - 1);
      }
    });
    expect(counter.cell.value, 100); // 10²

    final fork = await graph.fork(
      parent: ledger,
      atSeq: 4, // baseline 5² = 25
      buildFreshGraph: buildFreshGraph,
      buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
    );

    final result = await ReplayEngineFork.replayFork(
      fork: fork,
      mutation: (entry, pulse) {
        if (pulse.payload == 13) return null; // drop pulse 7
        return pulse;
      },
    );
    expect(result.success, isTrue, reason: result.divergences.toString());
    final forkCounter = fork.graph['c']!.cell as ValueCell<int>;
    // 25 + (11 + 15 + 17 + 19) = 87 (13 dropped).
    expect(forkCounter.value, 87);
    // Fork ledger: seq 0 = ForkRecord + 4 replayed entries.
    expect(await fork.ledger.lastSeq, 4);
    await fork.verify();
    await ledger.close();
  });
}
