import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('each apply produces exactly one StateDelta', () async {
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
    final entries = await ledger.entriesSince(0).toList();
    expect(entries.length, 2);
    for (final e in entries) {
      expect(e.deltas.length, 1);
      expect(e.deltas.single.cellId, 'c');
    }
    expect(entries[0].deltas.single.before, 0);
    expect(entries[0].deltas.single.after, 1);
    expect(entries[1].deltas.single.before, 1);
    expect(entries[1].deltas.single.after, 2);
    await ledger.close();
  });

  test('a delta is captured for every cell written in one pulse', () async {
    final a = Cell.state<int>(initial: 0);
    final b = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()
          ..registerState('a', a)
          ..registerState('b', b))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      // Two separate applies -> two entries, one delta each.
      a.update(1);
      b.update(2);
    });
    final entries = await ledger.entriesSince(0).toList();
    expect(entries.length, 2);
    expect(entries[0].deltas.single.cellId, 'a');
    expect(entries[1].deltas.single.cellId, 'b');
    await ledger.close();
  });

  test('no ledger scope means no recording', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);

    // Outside graph.run: no scope, silent no-op.
    counter.update(41);
    counter.update(42);
    expect(await ledger.lastSeq, -1);

    // After unbind, graph.run refuses; the binding is severed cleanly.
    final unbound = await graph.unbindLedger();
    expect(unbound, same(ledger));
    expect(counter.cell.value, 42);
    await ledger.close();
  });

  test('non-JSON-encodable state fails loudly under a ledger scope', () async {
    final opaque = Cell.state<Object>(initial: 0);
    final graph = (CellGraph.builder()..registerState('o', opaque)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    await expectLater(
      graph.run(() {
        opaque.update(DateTime(2026, 11, 12));
        opaque.update(Object()); // not JSON-encodable
      }),
      throwsStateError,
    );
    await ledger.close();
  });

  test('an idempotent write still records a delta (before == after)', () async {
    final cell = Cell.state<int>(initial: 5);
    final graph = (CellGraph.builder()..registerState('c', cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    // Force a receptor commit with an identical value via apply: the
    // value path dedupes, so drive the pulse through the cell's own
    // apply API.
    await graph.run(() async {
      cell.cell.apply((
        function: () => Pulse<int>(5),
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));
    });

    final entry = await ledger.entriesSince(0).single;
    expect(entry.deltas, hasLength(1));
    expect(entry.deltas.single.before, 5);
    expect(entry.deltas.single.after, 5);
    expect(entry.deltas.single.changed, isFalse);
    await ledger.close();
  });
}
