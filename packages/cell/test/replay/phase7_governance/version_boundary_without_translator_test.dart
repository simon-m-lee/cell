import 'package:cell/cell.dart';
import 'package:test/test.dart';

class _VersionedRule extends TestCell<Cell> {
  @override
  final String version;
  _VersionedRule({required this.version})
      : super((_, {host, arguments, user}) => true);
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('replay across a version boundary without a translator fails loudly',
      () async {
    // Record with a rule at version 1.0.0.
    final src = Cell.ingress<int>(testRule: _VersionedRule(version: '1.0.0'));
    final graph = (CellGraph.builder()..register('src', src.cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      src.emit(1);
    });
    final entry = await ledger.entriesSince(0).first;
    expect(entry.receipt.ruleVersion, '1.0.0');
    expect(entry.receipt.receptorVersion, '0.0.0');

    // Rebuild with a rule at version 2.0.0.
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>(testRule: _VersionedRule(version: '2.0.0'));
    final graph2 = (CellGraph.builder()..register('src', src2.cell)).build();

    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.seq,
        'seq',
        0,
      ).having(
        (e) => e.report?.reason,
        'reason',
        contains('version boundary'),
      )),
    );
    await ledger.close();
  });

  test('registering the recorded version in the registry lets replay pass',
      () async {
    final src = Cell.ingress<int>(testRule: _VersionedRule(version: '1.0.0'));
    final graph = (CellGraph.builder()..register('src', src.cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      src.emit(1);
      src.emit(2);
    });

    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>(testRule: _VersionedRule(version: '2.0.0'));
    final graph2 = (CellGraph.builder()..register('src', src2.cell)).build();
    // The recorded (receptor, rule) pair is available at the recorded
    // version, so the engine dispatches instead of failing.
    graph2.versions.register(
      cellId: 'src',
      version: '0.0.0',
      receptor: Receptor.passThrough,
      testRule: _VersionedRule(version: '0.0.0'),
    );

    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    await ledger.close();
  });

  test('unversioned ledger replays against an unversioned target', () async {
    // Plain cells report version '0.0.0'; the ledger records '0.0.0'
    // and the Phase 5/6 replay path is unaffected.
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
    final counter2 = Cell.state<int>(initial: 0);
    final graph2 =
        (CellGraph.builder()..registerState('c', counter2)).build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(counter2.cell.value, 2);
    await ledger.close();
  });
}
