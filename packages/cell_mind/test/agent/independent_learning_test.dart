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
    );

Future<AgentRuntime> spawnAgent(
  IngressHandle<int> source,
  String name,
) =>
    spawn(
      AgentSpec(
        name: name,
        cell: source.cell,
        mandate: mandate(name),
        routeIn: (p) => source.ingest(p as Pulse<int>),
      ),
      journal: RecordingJournal(),
    );

void main() {
  group('independent learning', () {
    test('each agent trains on its own outcomes only', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      final b = await spawnAgent(source, 'agent-b');

      for (var i = 0; i < 8; i++) {
        source.emit(i);
        await Future<void>.delayed(Duration.zero);
      }
      final aDecisions = a.trace.where((d) => d.pulse != null).toList();
      final bDecisions = b.trace.where((d) => d.pulse != null).toList();
      expect(aDecisions, hasLength(8));
      expect(bDecisions, hasLength(8));

      // Reward agent A negatively; leave agent B untouched.
      for (final decision in aDecisions) {
        a.agentHandle.recordOutcome(decisionId: decision.id, reward: -1);
      }
      await Future<void>.delayed(Duration.zero);
      expect(a.outcomes, hasLength(8));
      expect(b.outcomes, isEmpty,
          reason: 'Outcomes never cross agent boundaries.');

      final trainedA = await trainOffline(
        handle: a.agentHandle,
        outcomes: a.outcomes,
        baseContext: a.agentHandle.cell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
        config: const TrainingConfig(minSupport: 5),
      );
      expect(trainedA.ruleCount, 1,
          reason: 'Agent A learned a reject rule from its outcomes.');

      final trainedB = await trainOffline(
        handle: b.agentHandle,
        outcomes: b.outcomes,
        baseContext: b.agentHandle.cell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
      );
      expect(trainedB.ruleCount, 0,
          reason: 'Agent B had no outcomes and learns nothing.');
      a.dispose();
      b.dispose();
    });

    test('training one agent does not mutate the other', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      final b = await spawnAgent(source, 'agent-b');
      final bContextBefore = b.agentHandle.cell.context;
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      final decision = a.trace.lastWhere((d) => d.pulse != null);
      a.agentHandle.recordOutcome(decisionId: decision.id, reward: -1);
      await Future<void>.delayed(Duration.zero);
      final trained = await trainOffline(
        handle: a.agentHandle,
        outcomes: a.outcomes,
        baseContext: a.agentHandle.cell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
        config: const TrainingConfig(minSupport: 1),
      );
      expect(trained.ruleCount, 1);
      expect(b.agentHandle.cell.context, same(bContextBefore),
          reason: 'B\'s handle is untouched by A\'s training.');
      a.dispose();
      b.dispose();
    });

    test('a trained agent applies its learned context when re-spawned',
        () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      for (var i = 0; i < 6; i++) {
        source.emit(i);
        await Future<void>.delayed(Duration.zero);
      }
      for (final decision in a.trace.where((d) => d.pulse != null)) {
        a.agentHandle.recordOutcome(decisionId: decision.id, reward: -1);
      }
      await Future<void>.delayed(Duration.zero);
      final trained = await trainOffline(
        handle: a.agentHandle,
        outcomes: a.outcomes,
        baseContext: a.sourceCell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
        config: const TrainingConfig(minSupport: 5),
      );
      expect(trained.ruleCount, 1);
      expect(
        a.agentHandle.cell.context.constraints?['cell_mind.policy'],
        isNull,
        reason: 'Training is portable; it never mutates the live handle.',
      );
      final evolved = trained.applyTo(a.sourceCell.context);
      expect(evolved.constraints?['cell_mind.policy'], isNotNull);
      a.dispose();
    });
  });
}
