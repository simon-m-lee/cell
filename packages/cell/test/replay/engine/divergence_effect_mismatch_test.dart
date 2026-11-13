import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<Ledger> recordEffectfulGraph(
  String Function(int v) label,
) async {
  final src = Cell.ingress<int>();
  final journal = RecordingJournal();
  final mapped = Cell.asyncMap<int, String>(
    src.cell,
    (v, {required EffectJournal journal}) => journal.io(
      label: label(v),
      input: v,
      run: () async => 'result-$v',
    ),
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
    src.emit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  return ledger;
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('modified effectful receptor diverges at the first effect',
      () async {
    // Recording: asyncMap does one I/O call per pulse with label
    // 'fetch(v)'.
    final ledger = await recordEffectfulGraph((v) => 'fetch($v)');
    expect(await ledger.lastSeq, 0);

    // Rebuild with a *modified* mapper: uses a different label.
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>();
    final journal2 = RecordingJournal();
    final mapped2 = Cell.asyncMap<int, String>(
      src2.cell,
      (v, {required EffectJournal journal}) => journal.io(
        label: 'fetchV2($v)', // different label
        input: v,
        run: () async => 'result-$v',
      ),
      journal: journal2,
    );
    final graph2 = (CellGraph.builder()
          ..register('src', src2.cell)
          ..register('mapped', mapped2))
        .build();

    // The modified mapper consumes the recorded I/O with a mismatching
    // label; the journal latches the divergence and assertExhausted
    // reports it with the offending effect.
    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.seq,
        'seq',
        0,
      ).having(
        (e) => e.report?.reason,
        'reason',
        contains('label mismatch'),
      ).having(
        (e) => e.report?.lastEffect?.ordinal,
        'lastEffect ordinal',
        0,
      )),
    );
    await ledger.close();
  });

  test('an extra effect (modified receptor) also diverges', () async {
    final ledger = await recordEffectfulGraph((v) => 'fetch($v)');

    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>();
    final journal2 = RecordingJournal();
    final mapped2 = Cell.asyncMap<int, String>(
      src2.cell,
      (v, {required EffectJournal journal}) async {
        await journal.io(
          label: 'fetch($v)',
          input: v,
          run: () async => 'result-$v',
        );
        await journal.io(
          label: 'extra',
          input: v,
          run: () async => 'extra',
        );
        return 'result-$v';
      },
      journal: journal2,
    );
    final graph2 = (CellGraph.builder()
          ..register('src', src2.cell)
          ..register('mapped', mapped2))
        .build();

    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.seq,
        'seq',
        0,
      )),
    );
    await ledger.close();
  });
}
