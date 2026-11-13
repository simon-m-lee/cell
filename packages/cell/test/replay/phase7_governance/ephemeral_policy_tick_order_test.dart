import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('policy ticks are journalled and validated in order (C4)', () async {
    var tickCount = 0;
    final policy = EphemeralPolicy<Cell>(
      eventLimit: 100,
      onEvent: (object, {required cell, required policy, arguments, user}) {
        tickCount++;
        return (events: policy.events + 1);
      },
      onInvalidate: (nucleus) => true,
    );

    final cell = Cell.governed(ephemeralPolicy: policy);
    final graph = (CellGraph.builder()..register('c', cell)).build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    // Ticks are effects: the recording runs inside a journal scope.
    final recording = RecordingJournal();
    await JournalScope.run(recording, () => graph.run(() async {
          for (var i = 1; i <= 5; i++) {
            await cell.apply<Pulse<int>>((
              function: (int payload) => Pulse<int>(payload),
              arguments: (
                // arguments-first reconstruction: the first positional
                // argument becomes the replayed pulse's payload.
                positionalArguments: [i],
                namedArguments: null,
              ),
              compensation: null,
            ));
          }
        }));
    final recordedTicks = tickCount;
    expect(recordedTicks, greaterThan(0));

    // Every recorded entry carries its policy-tick effect.
    final entry = await ledger.entriesSince(0).first;
    expect(entry.effects, everyElement(isA<PolicyTickEffect>()));

    // Replay: the ticks are consumed from the journal and validated;
    // the policy callback is not re-invoked.
    tickCount = 0;
    CellGraphRegistry.forceReset();
    final policy2 = EphemeralPolicy<Cell>(
      eventLimit: 100,
      onEvent: (object, {required cell, required policy, arguments, user}) {
        tickCount++;
        return (events: policy.events + 1);
      },
      onInvalidate: (nucleus) => true,
    );
    final cell2 = Cell.governed(ephemeralPolicy: policy2);
    final graph2 = (CellGraph.builder()..register('c', cell2)).build();
    final result = await ReplayEngine.replay(ledger: ledger, target: graph2);

    expect(result.success, isTrue, reason: result.divergences.toString());
    expect(tickCount, 0,
        reason: 'replay must consume the recorded ticks, not re-run the '
            'policy callbacks');
    await ledger.close();
  });

  test('a tick-order mismatch diverges loudly', () {
    final journal = ReplayJournal([
      PolicyTickEffect(
        ordinal: 0,
        inputDigest: fingerprint(1),
        outputDigest: fingerprint('PolicyA@c'),
        at: DateTime.utc(2026, 11, 12),
        policyLabel: 'PolicyA',
        cellId: 'c',
      ),
    ]);
    expect(
      () => journal.policyTick(
        policyLabel: 'PolicyB', // wrong label
        cellId: 'c',
        input: 1,
      ),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });
}
