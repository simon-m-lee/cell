// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

DeputyContext mandate(String authority) => DeputyContext(
      baseContext: Context.fromEntries([Ontology.domains.entry('finance')]),
      authority: authority,
      role: 'reviewer',
    );

void main() {
  group('spawn', () {
    test('creates an isolated agent with its own handle and logs', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'risk',
          cell: source.cell,
          mandate: mandate('risk-agent'),
        ),
        journal: RecordingJournal(),
      );
      expect(agent.name, 'risk');
      expect(agent.sourceCell, source.cell);
      expect(agent.trace, agent.agentHandle.decisions);
      expect(agent.outcomes, isEmpty);
      expect(agent.context[Mandate.authority], 'risk-agent');
      expect(agent.agentView, isA<Cell>());
      agent.dispose();
    });

    test('records decisions when the source emits', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'risk',
          cell: source.cell,
          mandate: mandate('risk-agent'),
        ),
        journal: RecordingJournal(),
      );
      source.emit(42);
      await Future<void>.delayed(Duration.zero);
      final decisions = agent.trace.where((d) => d.pulse != null);
      expect(decisions, hasLength(1));
      expect(decisions.single.verdict, isA<Accept>());
      agent.dispose();
    });

    test('two agents on one source record independently', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawn(
        AgentSpec(
          name: 'a',
          cell: source.cell,
          mandate: mandate('agent-a'),
        ),
        journal: RecordingJournal(),
      );
      final b = await spawn(
        AgentSpec(
          name: 'b',
          cell: source.cell,
          mandate: mandate('agent-b'),
        ),
        journal: RecordingJournal(),
      );
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      expect(a.trace.where((d) => d.pulse != null), hasLength(1));
      expect(b.trace.where((d) => d.pulse != null), hasLength(1));
      expect(a.trace, isNot(same(b.trace)));
      a.dispose();
      b.dispose();
    });

    test('custom policy and allowedStrategies gate the agent', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'strict',
          cell: source.cell,
          mandate: mandate('strict-agent'),
          allowedStrategies: {ReasoningStrategy.deterministic},
        ),
        journal: RecordingJournal(),
      );
      await source.ingest(Pulse<int>.governed(
        payload: 1,
        context: PulseContext.fromEntries([
          Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        ]),
      ));
      await Future<void>.delayed(Duration.zero);
      final decision = agent.trace.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>(),
          reason: 'The probabilistic strategy is outside the allowed set.');
      agent.dispose();
    });

    test(
        'a mandate outside the source lineage is accepted by the '
        'live plain-cell deputy path (documented leniency)', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final unrelated = DeputyContext(
        baseContext: Context.fromEntries([Ontology.domains.entry('other')]),
        authority: 'intruder',
      );
      final agent = await spawn(
        AgentSpec(
          name: 'bad',
          cell: source.cell,
          mandate: unrelated,
        ),
        journal: RecordingJournal(),
      );
      expect(agent.context[Mandate.authority], 'intruder');
      agent.dispose();
    });

    test('a custom verdictPolicy is wired through', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'vp',
          cell: source.cell,
          mandate: mandate('vp-agent'),
          verdictPolicy: verdictPolicy(
            (object, {required host, arguments}) => const Reject('vp-says-no'),
          ),
        ),
        journal: RecordingJournal(),
      );
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      final decision = agent.trace.lastWhere((d) => d.pulse != null);
      expect((decision.verdict as Reject).reason, 'vp-says-no');
      agent.dispose();
    });
  });
}
