import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('diamond graph replays without spurious cycle errors', () async {
    // Diamond shape: source -> left -> sink; source -> right -> sink.
    final source = Cell.ingress<int>();
    final left = Cell.derive<Pulse<int>, Pulse<int>>(
      source: source.cell,
      project: (p) => Pulse((p.payload as int) + 1),
    );
    final right = Cell.derive<Pulse<int>, Pulse<int>>(
      source: source.cell,
      project: (p) => Pulse((p.payload as int) * 2),
    );
    final sink = Cell.synthesis<Pulse<int>>(
      [left, right],
      aggregator: (cells, emit) {
        final l = (cells.elementAt(0) as ValueCell).value as int? ?? 0;
        final r = (cells.elementAt(1) as ValueCell).value as int? ?? 0;
        return Pulse(l + r);
      },
    );

    final graph = (CellGraph.builder()
          ..register('source', source.cell)
          ..register('left', left)
          ..register('right', right)
          ..register('sink', sink))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      source.emit(1);
      source.emit(2);
      source.emit(3);
    });

    // Replay into an identical graph.
    CellGraphRegistry.forceReset();
    final source2 = Cell.ingress<int>();
    final left2 = Cell.derive<Pulse<int>, Pulse<int>>(
      source: source2.cell,
      project: (p) => Pulse((p.payload as int) + 1),
    );
    final right2 = Cell.derive<Pulse<int>, Pulse<int>>(
      source: source2.cell,
      project: (p) => Pulse((p.payload as int) * 2),
    );
    final sink2 = Cell.synthesis<Pulse<int>>(
      [left2, right2],
      aggregator: (cells, emit) {
        final l = (cells.elementAt(0) as ValueCell).value as int? ?? 0;
        final r = (cells.elementAt(1) as ValueCell).value as int? ?? 0;
        return Pulse(l + r);
      },
    );
    final graph2 = (CellGraph.builder()
          ..register('source', source2.cell)
          ..register('left', left2)
          ..register('right', right2)
          ..register('sink', sink2))
        .build();

    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(result.divergences, isEmpty);
    expect(result.entriesReplayed, 3);
    await ledger.close();
  });
}
