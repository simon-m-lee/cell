import 'package:cell/cell.dart';
import 'package:test/test.dart';

class _ReadOnlyRule extends TestCell<Cell> with EffectfulReadOnly {
  @override
  final String version;
  final void Function() onCall;
  _ReadOnlyRule({required this.version, required this.onCall})
      : super((_, {host, arguments, user}) {
          onCall();
          return true;
        });
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('readOnlyExternal TestCell is re-executed with its journal', () async {
    var callCount = 0;
    final rule = _ReadOnlyRule(
      version: '1.0.0',
      onCall: () => callCount++,
    );

    final src = Cell.ingress<int>(testRule: rule);
    final graph = (CellGraph.builder()..register('src', src.cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    await graph.run(() async {
      src.emit(1); // rule called once
    });
    expect(callCount, 1);

    callCount = 0;
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>(
      testRule: _ReadOnlyRule(
        version: '1.0.0',
        onCall: () => callCount++,
      ),
    );
    final graph2 = (CellGraph.builder()..register('src', src2.cell)).build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);

    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(callCount, 1,
        reason: 'readOnlyExternal TestCell should have been re-called, '
            'with its observation served from the journal');
    await ledger.close();
  });

  test('readOnlyExternal observations replay from the journal', () async {
    var reads = 0;
    final rule = _ReadOnlyRule(
      version: '1.0.0',
      onCall: () => reads++,
    );

    final src = Cell.ingress<int>(testRule: rule);
    final graph = (CellGraph.builder()..register('src', src.cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    // The observation (an I/O read) is recorded into the ambient
    // journal while the rule runs during recording.
    final recording = RecordingJournal();
    await JournalScope.run(recording, () => graph.run(() async {
          src.emit(1);
        }));
    expect(reads, 1);

    final entry = await ledger.entriesSince(0).first;
    // No verdict effect: the rule re-runs on replay.
    expect(entry.effects, isEmpty);

    reads = 0;
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>(
      testRule: _ReadOnlyRule(
        version: '1.0.0',
        onCall: () => reads++,
      ),
    );
    final graph2 = (CellGraph.builder()..register('src', src2.cell)).build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(reads, 1);
    await ledger.close();
  });
}
