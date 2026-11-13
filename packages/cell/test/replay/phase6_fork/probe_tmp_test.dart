import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  test('probe accumulate', () async {
    CellGraphRegistry.forceReset();
    final counter = Cell.state<int>(
      initial: 0,
      evolve: (host, input) =>
          Pulse((host.value ?? 0) + (input.payload as int)),
    );
    for (var i = 1; i <= 20; i++) {
      final ok = counter.update(i);
      if (!ok) print('update($i) rejected, value=${counter.cell.value}');
    }
    print('final=${counter.cell.value} (expect 210)');

    // Without ledger scope, does the graph.run path change anything?
    CellGraphRegistry.forceReset();
    final c2 = Cell.state<int>(
      initial: 0,
      evolve: (host, input) =>
          Pulse((host.value ?? 0) + (input.payload as int)),
    );
    final graph = (CellGraph.builder()..registerState('c', c2)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      for (var i = 1; i <= 20; i++) {
        c2.update(i);
      }
    });
    print('in-run final=${c2.cell.value}');
    await ledger.close();
  });
}
