import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('modified pure receptor diverges at the correct seq', () async {
    // Recording: counter starts at 0, commits the update value as-is.
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1); // seq 0
      counter.update(2); // seq 1
      counter.update(3); // seq 2
    });

    // Rebuild with a *modified* receptor: a counter that doubles the
    // update value.
    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(
      initial: 0,
      evolve: (host, input) =>
          Pulse((host.value ?? 0) + (input.payload as int) * 2),
    );
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();

    // Replay: the modified receptor produces different deltas. The first
    // divergence is at seq 0 (the first entry whose delta no longer
    // matches), not the last or the middle.
    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.seq,
        'seq',
        0,
      ).having(
        (e) => e.report?.reason,
        'reason',
        contains('delta.after mismatch'),
      )),
    );
    await ledger.close();
  });

  test('lenient replay collects the divergence report', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });

    CellGraphRegistry.forceReset();
    final counter2 = Cell.state<int>(
      initial: 0,
      evolve: (host, input) => Pulse((host.value ?? 0) + 100),
    );
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();

    final result = await ReplayEngine.replay(
      ledger: ledger,
      target: graph2,
      options: ReplayOptions.diff,
    );
    expect(result.success, isFalse);
    expect(result.divergedAt, 0);
    expect(result.divergences, isNotEmpty);
    expect(result.divergences.first.seq, 0);
    expect(result.divergences.first.expected, 1);
    expect(result.divergences.first.actual, 100);
    await ledger.close();
  });
}
