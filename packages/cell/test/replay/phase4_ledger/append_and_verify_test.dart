import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('1000 updates, verify() OK', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);

    await graph.run(() async {
      for (var i = 1; i <= 1000; i++) {
        counter.update(i);
      }
    });

    expect(await ledger.lastSeq, 999);
    await ledger.verify();
    await ledger.close();
  });

  test('the chain hash covers at/effects/deltas: entries differ', () async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);

    await graph.run(() async {
      counter.update(1);
      counter.update(2);
    });

    final entries = await ledger.entriesSince(0).toList();
    expect(entries[0].hash, isNot(entries[1].hash));
    expect(entries[1].prevHash, entries[0].hash);
    // Both receipts are back-filled on the stored copy.
    expect(entries[1].receipt.ledgerSeq, 1);
    expect(entries[1].receipt.pulseDigest, entries[1].pulseDigest);
    await ledger.close();
  });
}
