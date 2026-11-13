import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('an apply nested inside a receptor does not recurse or double-record',
      () async {
    final inner = Cell.state<int>(initial: 0);
    final outer = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()
          ..registerState('inner', inner)
          ..registerState('outer', outer))
        .build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);

    // The outer cell's command applies to the inner cell too; both deltas
    // land in the scope, one entry per apply, in causal order.
    await graph.run(() async {
      outer.cell.apply((
        function: () {
          inner.update(7);
          return Pulse<int>(1);
        },
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));
    });

    expect(await ledger.lastSeq, 1); // two entries: inner update + outer apply
    await ledger.verify();
    final entries = await ledger.entriesSince(0).toList();
    expect(entries.length, 2);
    await ledger.close();
  });

  test('recordAndAppend does not recurse', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var i = 1; i <= 3; i++) {
        counter.update(i);
      }
    });
    expect(await ledger.lastSeq, 2); // three entries, seq 0-2
    await ledger.verify();
    await ledger.close();
  });

  test('graph.run refuses to run without a bound ledger', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    expect(
      () => graph.run(() => counter.update(1)),
      throwsStateError,
    );
  });

  test('bindLedger refuses a second bind until unbound', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);
    expect(
      () => graph.bindLedger(store: store),
      throwsStateError,
    );
    expect(await graph.unbindLedger(), same(ledger));
    await ledger.close();
  });

  test('a store built for another graph is rejected at open time', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(genesisHash: 'some-other-graph');
    expect(
      () => graph.bindLedger(store: store),
      throwsStateError,
    );
  });

  test(
      'a hand-crafted appendInternal entry has an empty delta list — '
      'verify passes, replay (Phase 5) will reject it', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);

    // Bypass the coordinated path: no postProcessRule capture ran, so
    // the entry carries no deltas. The chain is still valid.
    final pulse = Pulse<int>(42);
    final receipt = ((
      id: 'hand-crafted',
      cell: counter.cell,
      function: (() {}),
      arguments: (positionalArguments: null, namedArguments: null),
      timestamp: DateTime.now(),
      txSequence: null,
      vetted: false,
      ledgerSeq: null,
      pulseDigest: null,
    ));
    await ledger.appendInternal(
      pulse: pulse,
      receipt: receipt,
      cellId: counter.cell.id,
      effects: const [],
      deltas: const [],
    );

    await ledger.verify(); // chain-valid
    final entry = await store.entriesSince(0).single;
    expect(entry.deltas, isEmpty);
    expect(entry.receipt.ledgerSeq, 0);
    expect(entry.receipt.pulseDigest, isNotNull);
    await ledger.close();
  });
}
