import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('receptor that performs fewer effects diverges', () async {
    // Recording: two I/O calls per pulse.
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    final mapped = Cell.asyncMap<int, String>(
      src.cell,
      (v, {required EffectJournal journal}) async {
        final a = await journal.io(
          label: 'first',
          input: v,
          run: () async => 'a-$v',
        );
        final b = await journal.io(
          label: 'second',
          input: v,
          run: () async => 'b-$v',
        );
        return '$a|$b';
      },
      journal: journal,
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
      src.emit(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(await ledger.lastSeq, 0);

    // Rebuild with a receptor that performs only one I/O call.
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>();
    final journal2 = RecordingJournal();
    final mapped2 = Cell.asyncMap<int, String>(
      src2.cell,
      (v, {required EffectJournal journal}) async {
        return journal.io(
          label: 'first',
          input: v,
          run: () async => 'a-$v',
        );
      },
      journal: journal2,
    );
    final graph2 = (CellGraph.builder()
          ..register('src', src2.cell)
          ..register('mapped', mapped2))
        .build();

    // The modified receptor consumes fewer effects; assertExhausted
    // catches the leftover and reports a divergence with the unused
    // effect as lastEffect.
    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.seq,
        'seq',
        0,
      ).having(
        (e) => e.report?.reason,
        'reason',
        contains('unused effect'),
      ).having(
        (e) => e.report?.lastEffect?.ordinal,
        'lastEffect ordinal',
        1,
      )),
    );
    await ledger.close();
  });
}
