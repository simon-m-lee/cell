// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Fitness suite — the `cell` / `cell_tissue` contract that `cell_mind`
/// depends on.
///
/// Every test is a canary for a specific primitive:
///
/// - **Tier 1 (F1–F5)** gates Phase 1. A red Tier 1 test halts the
///   project until `cell` is patched.
/// - **Tier 2 (F6–F8)** is non-blocking but recorded in `KNOWN_ISSUES.md`
///   when red.
/// - **Tier 3 (F9–F12)** verifies structural dependencies that later
///   phases consume.
library;

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Tier 1 — gates Phase 1', () {
    group('F1 — Context.evolve semantics for Ontology.constraints', () {
      test('F1a: preserves parent when resolver returns null', () {
        final c1 = Context.system.evolve(
          (_) => Ontology.constraints.entry({'a': 1}),
        );
        final c2 = c1.evolve((_) => null);
        expect(c2.constraints?['a'], 1,
            reason: 'Parent constraints must survive a null resolver; '
                'learning accumulates through evolve().');
      });

      test('F1b: replaces (not merges) when resolver returns non-null', () {
        // Documents the actual semantics — the trainer must merge
        // explicitly before evolving (guide/03-Learning.md §4).
        final c1 = Context.system.evolve(
          (_) => Ontology.constraints.entry({'a': 1}),
        );
        final c2 = c1.evolve(
          (_) => Ontology.constraints.entry({'b': 2}),
        );
        expect(c2.constraints?['b'], 2);
        expect(c2.constraints?['a'], isNull,
            reason: 'Non-null resolver replaces the map; trainer merges.');
      });

      test('F1c: nested map values are not deep-merged', () {
        // Same replace semantics, at the value level.
        final c1 = Context.system.evolve(
          (_) => Ontology.constraints.entry({
            'policy': {'r1': true},
          }),
        );
        final c2 = c1.evolve(
          (_) => Ontology.constraints.entry({
            'policy': {'r2': true},
          }),
        );
        expect(c2.constraints?['policy'], {'r2': true},
            reason: 'The trainer must merge the policy block explicitly '
                'before evolving.');
      });
    });

    test('F2: TestCell.chain short-circuits on rejection', () async {
      var secondCalled = false;
      final a = TestCell<Cell>((_, {host, arguments, user}) => false);
      final b = TestCell<Cell>((_, {host, arguments, user}) {
        secondCalled = true;
        return true;
      });
      final composed = TestCell<Cell>.chain([a, b]);
      final cell = Cell.ingress<int>();
      final accepted = await composed.call(Pulse(0), host: cell.cell);
      expect(accepted, isFalse);
      expect(secondCalled, isFalse,
          reason: 'Rejection must short-circuit; policies compose by AND.');
    });

    test('F3: Pulse.context inherits through evolve', () {
      final root = Pulse<int>.governed(
        payload: 0,
        context: PulseContext(actor: 'a', reason: 'r', confidence: 0.9),
      );
      final evolved = root.evolve(step: 'x');
      expect(evolved.context.actor, 'a');
      expect(evolved.context.confidence, 0.9);
      expect(evolved.trace, ['x']);
    });

    test('F4: TissueList observation emits pulses', () async {
      final list = TissueList<int>();
      final observed = <int>[];
      final sub = Cell.observe(
          source: list,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      list.add(42);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [42]);
      sub.stop();
    });

    group('F5 — ApplyReceipt.vetted accuracy', () {
      test('F5a: vetted reports manifest membership (true)', () async {
        // Live contract (cell 1.1.0): `vetted` records whether the command
        // function was present in the cell's `modifiable` capability
        // manifest. The integrity gate runs either way.
        final cell = ManifestCell();
        final command = (
          function: cell.echo,
          arguments: (positionalArguments: [7], namedArguments: null),
          compensation: null,
        );
        final outcome = await cell.apply<int>(command);
        expect(outcome, isA<ApplyAccepted<int>>());
        expect(outcome.receipt.vetted, isTrue,
            reason: 'A manifest-listed verb must be marked vetted.');
        expect((outcome as ApplyAccepted<int>).result, 7);
      });

      test('F5b: vetted reports manifest membership (false)', () async {
        // The gate still runs for non-manifest functions (it must never be
        // skipped), but the receipt truthfully reports the command was not
        // a declared capability.
        final cell = ManifestCell();
        final command = (
          function: (int x) => x,
          arguments: (positionalArguments: [1], namedArguments: null),
          compensation: null,
        );
        final outcome = await cell.apply<int>(command);
        expect(outcome, isA<ApplyAccepted<int>>());
        expect(outcome.receipt.vetted, isFalse,
            reason: 'A function outside the manifest must be marked '
                'unvetted even when the gate accepts.');
      });

      test('F5c: unmodifiable views reject apply', () async {
        final ingress = Cell.ingress<int>();
        final readOnly = ingress.cell.unmodifiable;
        final command = (
          function: (int x) => x,
          arguments: (positionalArguments: [1], namedArguments: null),
          compensation: null,
        );
        final outcome = await readOnly.apply<int>(command);
        expect(outcome, isA<ApplyRejected<int>>(),
            reason: 'Read-only views must reject every apply command.');
      });
    });
  });

  group('Tier 2 — non-blocking but verified', () {
    test('F6: deputy shares container with principal', () async {
      // `Cell.deputy` is documented as a proxy over the principal's state,
      // not a copy. Prove it behaviourally: an update emitted by the
      // principal is observed by the deputy's synapses.
      final state = Cell.state<int>(initial: 7);
      final deputy = await state.cell.deputy();
      final observed = <int>[];
      final sub = Cell.observe(
          source: deputy,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      state.update(42);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [42],
          reason: 'The deputy must see the principal\'s state transition; '
              'dynamic mode and learning both rely on this.');
      sub.stop();
    });

    test('F7: Pulse.context survives apply', () async {
      final cell = Cell.ingress<int>();
      final seen = <Pulse>[];
      final sub = Cell.observe(
          source: cell.cell,
          effect: (Pulse p) {
            seen.add(p);
          });

      final pulse = Pulse<int>.governed(
        payload: 42,
        context: PulseContext(actor: 'test-actor', reason: 'test-reason'),
      );
      final command = (
        function: () => pulse,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      );
      await cell.cell.apply<dynamic>(command);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isNotEmpty);
      expect(seen.first.context.actor, 'test-actor',
          reason: 'A governed pulse must keep its provenance when it is '
              'routed back through the cell\'s receptor.');
      sub.stop();
    });

    test('F8: journal replay reproduces recorded observations', () async {
      // The EffectJournal boundary is what makes cell_mind's time-reading
      // policies, trainer runs and bridges replayable. A recording must be
      // replayable byte-for-byte against a ReplayJournal.
      final recording = RecordingJournal(
        clockSource: () => DateTime.fromMillisecondsSinceEpoch(1000),
        uuidSource: () => 'uuid-1',
      );

      final observed1 = <String>[];
      await JournalScope.run(recording, () async {
        observed1.add(recording.clock().toIso8601String());
        observed1.add(recording.uuid());
        observed1.add(
          await recording.io<String>(
            label: 'probe',
            input: 1,
            run: () async => 'live-output',
          ),
        );
      });

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final observed2 = <String>[];
      await JournalScope.run(replay, () async {
        observed2.add(replay.clock().toIso8601String());
        observed2.add(replay.uuid());
        observed2.add(
          await replay.io<String>(
            label: 'probe',
            input: 1,
            run: () async => 'must-not-run-on-replay',
          ),
        );
      });

      expect(observed2, observed1,
          reason: 'Replay must serve recorded observations without '
              'touching the outside world.');
      replay.assertExhausted();
    });
  });

  group('Tier 3 — structural verification', () {
    test('F9: EphemeralPolicy TTL invalidates after inactivity', () async {
      // TTL is an INACTIVITY window in cell 1.1.0: the timer starts on the
      // first interaction and restarts on every interaction.
      final src = Cell.ingress<int>();
      final policy = EphemeralPolicy<Cell>(
        duration: Duration(milliseconds: 60),
        onEvent: (object, {required cell, arguments, required policy, user}) =>
            (events: policy.events + 1),
        onInvalidate: (nucleus) => true,
      );
      final governed = await src.cell.deputy(ephemeralPolicy: policy);

      src.emit(1); // First interaction arms the TTL timer.
      expect(governed.isInvalidated, isFalse);
      await Future<void>.delayed(Duration(milliseconds: 200));
      expect(governed.isInvalidated, isTrue,
          reason: 'The approval queue\'s TTL sweeper (Phase 4) reuses '
              'this inactivity-window mechanism.');
    });

    test('F10: Identity.next() generates unique ids', () {
      final ids = {for (var i = 0; i < 100; i++) Identity.next()};
      expect(ids, hasLength(100),
          reason: 'Decision ids and trace ids must never collide.');
    });

    test('F11: PulseContext.systemInternal fills defaults', () {
      final ctx = PulseContext.systemInternal(baseContext: Context.system);
      expect(ctx.actor, 'system_daemon');
      expect(ctx.strategy, ReasoningStrategy.deterministic);
      expect(ctx.confidence, 1.0);
      expect(ctx.auditLevel, AuditLevel.minimal);
      expect(ctx.priority, 35);
      expect(ctx.purpose, 'MAINTENANCE');
      expect(ctx.reason, 'automated internal task');
      expect(ctx.sensitivity, Sensitivity.public);
    });

    test('F12: Cell.ingress handles all Pulse subtypes', () async {
      // NOTE: a `CollectivePulse<int>` is a `Pulse<Iterable<Pulse<int>>>`
      // (payload = the bundle), so the gate is typed `Object` to accept all
      // four payload shapes.
      final gate = Cell.ingress<Object>();
      final received = <Object?>[];
      final sub = Cell.observe(
          source: gate.cell,
          effect: (Pulse p) {
            received.add(p.payload);
          });

      await gate.ingest(Pulse(1)); // plain
      await gate.ingest(Pulse<int>.governed(
        payload: 2,
        context: PulseContext(actor: 'a', reason: 'r'),
      )); // governed
      await gate.ingest(Pulse(3).withStep('evolved')); // lineage-evolved
      // `Pulse.batch` returns the raw `Pulse` type in cell 1.1.0.
      final Pulse collective =
          Pulse.batch<int>(<Pulse<int>>[Pulse(4), Pulse(5)]);
      await gate.ingest(collective as Pulse<Object>); // collective

      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(4),
          reason: 'The cognitive receptor (Phase 2) forwards every pulse '
              'subtype; the substrate must accept them all.');
      expect(received[0], 1);
      expect(received[1], 2);
      expect(received[2], 3);
      final bundle = received[3];
      expect(bundle, isA<Iterable<Pulse>>());
      expect(
        (bundle as Iterable<Pulse>).map((p) => p.payload),
        containsAll([4, 5]),
      );
      sub.stop();
    });
  });
}
