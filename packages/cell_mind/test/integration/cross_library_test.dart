// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:cell_organ/cell_organ.dart' hide Reject;
import 'package:test/test.dart';

void main() {
  group('cell ↔ cell_tissue ↔ cell_organ', () {
    Blend userBlend(String name) => Blend(
          'User',
          fields: [ValueField<Blend, String>(name: #name, value: name)],
        );

    test('a Blend carries the context a cognitive handle records', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final blend = userBlend('ada');
      final handle = cognitive(cell: source.cell);
      source.emit(7);
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions.where((d) => d.pulse != null), hasLength(1));
      expect(handle.decisions.last.verdict, isA<Accept>());
      // The blend is a Cell: usable as a policy/context carrier and
      // explainable by identity.
      expect(blend, isA<Cell>());
      expect(explainSource(blend, handle), isEmpty,
          reason: 'No pulse was emitted by the blend itself');
    });

    test('Many<E> composes with TrainedPolicy contexts', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final handle = cognitive(cell: source.cell);
      final many = Many<Blend>([userBlend('ada'), userBlend('grace')]);
      final unmodifiable = Many<Blend>.unmodifiable(many.toList());
      expect(many.length, 2);
      expect(unmodifiable.length, 2);

      // Train against the plain context (organ constraints live on
      // the Context, not on the stem).
      final outcomes = recordOutcomes(handle);
      for (var i = 0; i < 10; i++) {
        source.emit(i);
        await Future<void>.delayed(Duration.zero);
        handle.recordOutcome(
          decisionId: handle.decisions.last.id,
          reward: -1.0,
        );
      }
      await Future<void>.delayed(Duration.zero);
      final trained = await trainOffline(
        handle: handle,
        outcomes: outcomes.log,
        baseContext: source.cell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
        config: const TrainingConfig(minSupport: 3),
      );
      outcomes.stop();
      expect(trained.ruleCount, greaterThan(0));
      final evolved = trained.applyTo(source.cell.context);
      final block = evolved.constraints?['cell_mind.policy'];
      expect(block, isNotNull);
      expect((block as Map)['rules'], isNotEmpty);
    });

    test('TestStem blends compose beside agent debates', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final blend = Blend(
        'Gate',
        fields: [ValueField<Blend, String>(name: #label, value: 'gate')],
        testRule: TestStem.allowAll,
      );
      expect(blend, isA<Cell>());
      final agents = <AgentRuntime>[];
      for (final name in ['a', 'b', 'c']) {
        agents.add(await spawn(
          AgentSpec(
            name: name,
            cell: source.cell,
            mandate: DeputyContext(
              baseContext: Context.fromEntries(
                [Ontology.domains.entry('finance')],
              ),
              authority: 'agent-$name',
            ),
            routeIn: (p) => source.ingest(p as Pulse<int>),
          ),
          journal: RecordingJournal(),
        ));
      }
      final outcome = await debate(
        participants: agents,
        question: Pulse<int>.governed(
          payload: 42,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('organ'),
            Provenance.strategy.entry(ReasoningStrategy.manual),
          ]),
        ),
        journal: RecordingJournal(),
      );
      expect(outcome.consensusReached, isTrue);
      expect(outcome.winner, isA<Accept>());
      for (final agent in agents) {
        agent.dispose();
      }
    });

    test('a Blend with a gate composes with policy evaluation', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final handle = cognitive(
        cell: source.cell,
        policy: domainPolicy(additionalDomains: const {}),
      );
      final blend = Blend(
        'User',
        fields: [ValueField<Blend, String>(name: #name, value: 'ada')],
      );
      expect(blend.context, isA<Context>());
      // Raw ingest with no provenance: the domain gate must reject.
      await source.ingest(Pulse<int>.governed(payload: 1));
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions.last.verdict, isA<Reject>(),
          reason: 'Untagged pulses fail the domain gate');
    });

    test('narratives render decisions recorded beside organ cells', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final handle = cognitive(cell: source.cell);
      final blend = userBlend('grace');
      await source.ingest(Pulse<int>.governed(
        payload: 5,
        source: source.cell,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('organ'),
          Provenance.traceId.entry('trace-1'),
          Ontology.domains.entry('finance'),
        ]),
      ));
      await Future<void>.delayed(Duration.zero);
      final path = explainPulse(
        Pulse<int>.governed(
          payload: 5,
          context: PulseContext.fromEntries([
            Provenance.traceId.entry('trace-1'),
          ]),
        ),
        handle,
      );
      expect(path, isNotNull);
      expect(path!.toNarrative(), contains('ACCEPT'));
      expect(explainSource(source.cell, handle), hasLength(1));
      expect(explainSource(blend, handle), isEmpty);
    });
  });
}
