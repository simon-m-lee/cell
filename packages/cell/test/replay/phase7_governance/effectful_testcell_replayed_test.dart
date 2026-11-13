import 'package:cell/cell.dart';
import 'package:test/test.dart';

class _EffectfulRule extends TestCell<Cell> with Effectful {
  @override
  final String version;
  final void Function() onCall;
  _EffectfulRule({required this.version, required this.onCall})
      : super((_, {host, arguments, user}) {
          onCall();
          return true;
        });
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('effectful TestCell decision is replayed, not re-called', () async {
    var callCount = 0;
    final rule = _EffectfulRule(
      version: '1.0.0',
      onCall: () => callCount++,
    );

    // Record with the rule firing. The effectful rule's verdict is an
    // effect, so the recording runs inside a journal scope.
    final src = Cell.ingress<int>(testRule: rule);
    final graph = (CellGraph.builder()..register('src', src.cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    final recording = RecordingJournal();
    await JournalScope.run(recording, () => graph.run(() async {
          src.emit(1); // rule called once, verdict journaled
        }));
    expect(callCount, 1);

    final entry = await ledger.entriesSince(0).first;
    expect(entry.effects, hasLength(1));
    expect(entry.effects.single, isA<VerdictEffect>());

    // Replay. The rule must not be called again — its recorded verdict
    // is served from the ReplayJournal.
    callCount = 0;
    CellGraphRegistry.forceReset();
    final src2 = Cell.ingress<int>(
      testRule: _EffectfulRule(
        version: '1.0.0',
        onCall: () => callCount++,
      ),
    );
    final graph2 = (CellGraph.builder()..register('src', src2.cell)).build();

    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);
    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(callCount, 0,
        reason: 'effectful TestCell should have been replayed from the '
            'ledger, not re-called');
    await ledger.close();
  });

  test('a recorded false verdict is served as-is from the journal', () async {
    // A changed effectful rule would normally diverge through the
    // version boundary check; at the journal level the recorded
    // decision is served verbatim — the rule is never consulted.
    final rule = _EffectfulRule(version: '1.0.0', onCall: () {});
    final journal = ReplayJournal([
      VerdictEffect(
        ordinal: 0,
        inputDigest: fingerprint({'payload': 1, 'type': null}),
        outputDigest: fingerprint(false),
        at: DateTime.utc(2026, 11, 12),
        verdict: false,
        ruleLabel: '${rule.runtimeType}@1.0.0',
      ),
    ]);
    var calls = 0;
    final served = await journal.verdict(
      ruleLabel: '${rule.runtimeType}@1.0.0',
      input: {'payload': 1, 'type': null},
      run: () async {
        calls++;
        return true;
      },
    );
    expect(served, isFalse);
    expect(calls, 0, reason: 'the rule must not be re-called on replay');
    journal.assertExhausted();
  });
}
