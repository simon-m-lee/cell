import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('500 pulses replay deterministically with effects', () async {
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    final mapped = Cell.asyncMap<int, String>(
      src.cell,
      (v, {required EffectJournal journal}) =>
          journal.io(label: 'fetch($v)', input: v, run: () async => 'r$v'),
      journal: journal,
      concurrency: 1,
    );
    final graph = (CellGraph.builder()
          ..register('src', src.cell)
          ..register('mapped', mapped))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var i = 0; i < 500; i++) {
        src.emit(i);
        // Let the asyncMap's future resolve before the next emit.
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    expect(await ledger.lastSeq, 499);

    // Every entry must carry its I/O effect — the cooperative capture
    // contract that makes the replay actually verify effects.
    final firstEntry = await ledger.entriesSince(0).first;
    expect(firstEntry.effects, hasLength(1));

    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>();
    final journal2 = RecordingJournal();
    final mapped2 = Cell.asyncMap<int, String>(
      src2.cell,
      (v, {required EffectJournal journal}) =>
          journal.io(label: 'fetch($v)', input: v, run: () async => 'r$v'),
      journal: journal2,
      concurrency: 1,
    );
    final graph2 = (CellGraph.builder()
          ..register('src', src2.cell)
          ..register('mapped', mapped2))
        .build();

    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(result.divergences, isEmpty);
    expect(result.entriesReplayed, 500);
    await ledger.close();
  });
}
