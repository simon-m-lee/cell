import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('write to disk, reopen, verify', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_test');
    final path = '${dir.path}/ledger.jsonl';
    try {
      final counter = Cell.state<int>(initial: 0);
      final graph = (CellGraph.builder()..registerState('c', counter)).build();
      final genesis = Ledger.genesisHashOf(graph.id);

      final store1 = await FileLedgerStore.open(path, genesisHash: genesis);
      final ledger1 = await graph.bindLedger(store: store1);
      await graph.run(() async {
        for (var i = 1; i <= 10; i++) {
          counter.update(i);
        }
      });
      expect(await ledger1.lastSeq, 9);
      final inMemoryDigest = await store1.entriesSince(0).first;
      await ledger1.close();

      // Reopen and verify.
      final store2 = await FileLedgerStore.open(path, genesisHash: genesis);
      expect(await store2.lastSeq, 9);
      final ledger2 = await Ledger.openVerified(
        graph: graph,
        store: store2,
      );
      expect(await ledger2.lastSeq, 9);
      await ledger2.verify();

      // Entries reloaded from disk recompute byte-identical digests
      // (live Functions are not serialisable; the stored receipt JSON is
      // authoritative).
      final reloaded = await store2.entriesSince(0).first;
      expect(reloaded.receiptDigest, inMemoryDigest.receiptDigest);
      expect(reloaded.deltas.single.before, 0);
      expect(reloaded.deltas.single.after, 1);
      expect(reloaded.receipt.ledgerSeq, 0);
      await ledger2.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('a tampered file line fails verify on reopen', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_test');
    final path = '${dir.path}/ledger.jsonl';
    try {
      final counter = Cell.state<int>(initial: 0);
      final graph = (CellGraph.builder()..registerState('c', counter)).build();
      final genesis = Ledger.genesisHashOf(graph.id);

      final store1 = await FileLedgerStore.open(path, genesisHash: genesis);
      final ledger1 = await graph.bindLedger(store: store1);
      await graph.run(() async {
        counter.update(1);
        counter.update(2);
      });
      await ledger1.close();

      // Flip a delta value in the second line.
      final lines = await File(path).readAsLines();
      final tampered = lines[1].replaceFirst('"after":2', '"after":999');
      await File(path).writeAsString('${lines[0]}\n$tampered\n');

      final store2 = await FileLedgerStore.open(path, genesisHash: genesis);
      final ledger2 = await Ledger.open(graph: graph, store: store2);
      try {
        await ledger2.verify();
        fail('verify() should have thrown');
      } on LedgerIntegrityException catch (e) {
        expect(e.seq, 1);
        expect(e.reason, contains('hash mismatch'));
      }
      await ledger2.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
