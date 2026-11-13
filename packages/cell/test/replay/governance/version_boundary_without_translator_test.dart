import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

class _VersionedRule extends TestCell<Cell> {
  @override
  final String version;
  _VersionedRule({required this.version})
      : super((_, {host, arguments, user}) => true);
}

class _VersionedReceptor extends ReceptorBase<Cell> {
  @override
  final String version;
  final List<int> calls;
  _VersionedReceptor({required this.version, required this.calls})
      : super();
  @override
  Receptor<Cell> get clone =>
      _VersionedReceptor(version: version, calls: calls);
  @override
  FutureOr<Pulse?> call(covariant Pulse incoming) {
    if (incoming.payload is int) calls.add(incoming.payload as int);
    return super.call(incoming);
  }
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

  test('registering the recorded version makes the historical receptor run',
      () async {
    // Record with a versioned (receptor, rule) pair at 1.0.0.
    final v1calls = <int>[];
    final v1Receptor =
        _VersionedReceptor(version: '1.0.0', calls: v1calls);
    final cell = Cell.governed(
      receptor: v1Receptor,
      testRule: _VersionedRule(version: '1.0.0'),
    );
    final graph = (CellGraph.builder()..register('c', cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      await cell.apply<Pulse<int>>((
        function: (int payload) => Pulse<int>(payload),
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
      await cell.apply<Pulse<int>>((
        function: (int payload) => Pulse<int>(payload),
        arguments: (positionalArguments: [2], namedArguments: null),
        compensation: null,
      ));
    });
    expect(v1calls, [1, 2]);

    // Rebuild with the live pair at 2.0.0 and register the historical
    // 1.0.0 pair. Review contract: a registry hit must RUN the
    // historical receptor — not authorise the live one.
    CellGraphRegistry.forceReset();
    final v2calls = <int>[];
    final cell2 = Cell.governed(
      receptor: _VersionedReceptor(version: '2.0.0', calls: v2calls),
      testRule: _VersionedRule(version: '2.0.0'),
    );
    final graph2 = (CellGraph.builder()..register('c', cell2)).build();
    graph2.versions.register(
      cellId: 'c',
      version: '1.0.0',
      receptor: v1Receptor,
      testRule: _VersionedRule(version: '1.0.0'),
    );
    v1calls.clear();

    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(v1calls, [1, 2],
        reason: 'the registered historical receptor must actually run');
    expect(v2calls, isEmpty,
        reason: 'the live v2 receptor must not be used for recorded v1');
    await ledger.close();
  });

  test('a registry pair whose rule version differs is refused', () async {
    final cell = Cell.governed(
      receptor: Receptor.passThrough,
      testRule: _VersionedRule(version: '1.0.0'),
    );
    final graph = (CellGraph.builder()..register('c', cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      await cell.apply<Pulse<int>>((
        function: (int payload) => Pulse<int>(payload),
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
    });

    CellGraphRegistry.forceReset();
    final cell2 = Cell.governed(
      receptor: Receptor.passThrough,
      testRule: _VersionedRule(version: '2.0.0'),
    );
    final graph2 = (CellGraph.builder()..register('c', cell2)).build();
    // Receptor version matches, rule version does not: the reviewer's
    // "rule version is not rechecked" case must now fail loudly.
    graph2.versions.register(
      cellId: 'c',
      version: '0.0.0',
      receptor: Receptor.passThrough,
      testRule: _VersionedRule(version: '0.0.0'),
    );

    await expectLater(
      ReplayEngine.replay(ledger: ledger, target: graph2),
      throwsA(isA<ReplayDivergenceException>().having(
        (e) => e.report?.reason,
        'reason',
        contains('rule version'),
      )),
    );
    await ledger.close();
  });

  test('unversioned ledger replays against an unversioned target', () async {
    // Plain cells report version '0.0.0'; the ledger records '0.0.0'
    // and the the replay engine/6 replay path is unaffected.
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
