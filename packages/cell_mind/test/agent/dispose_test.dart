// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('AgentRuntime.dispose', () {
    test('stops the outcome subscription', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'a',
          cell: source.cell,
          mandate: DeputyContext(
            baseContext:
                Context.fromEntries([Ontology.domains.entry('finance')]),
            authority: 'agent-a',
          ),
        ),
        journal: RecordingJournal(),
      );
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      final decision = agent.trace.lastWhere((d) => d.pulse != null);
      agent.agentHandle.recordOutcome(decisionId: decision.id, reward: 1);
      await Future<void>.delayed(Duration.zero);
      expect(agent.outcomes, hasLength(1));
      agent.dispose();
      expect(
        () =>
            agent.agentHandle.recordOutcome(decisionId: decision.id, reward: 1),
        throwsStateError,
      );
      expect(agent.outcomes, hasLength(1));
      expect(agent.isDisposed, isTrue);
    });

    test('dispose is idempotent', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final agent = await spawn(
        AgentSpec(
          name: 'a',
          cell: source.cell,
          mandate: DeputyContext(
            baseContext:
                Context.fromEntries([Ontology.domains.entry('finance')]),
            authority: 'agent-a',
          ),
        ),
        journal: RecordingJournal(),
      );
      agent.dispose();
      agent.dispose();
      expect(agent.isDisposed, isTrue);
    });

    test('disposing one agent leaves the other alive', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawn(
        AgentSpec(
          name: 'a',
          cell: source.cell,
          mandate: DeputyContext(
            baseContext:
                Context.fromEntries([Ontology.domains.entry('finance')]),
            authority: 'agent-a',
          ),
        ),
        journal: RecordingJournal(),
      );
      final b = await spawn(
        AgentSpec(
          name: 'b',
          cell: source.cell,
          mandate: DeputyContext(
            baseContext:
                Context.fromEntries([Ontology.domains.entry('finance')]),
            authority: 'agent-b',
          ),
        ),
        journal: RecordingJournal(),
      );
      a.dispose();
      source.emit(1);
      await Future<void>.delayed(Duration.zero);
      expect(b.trace.where((d) => d.pulse != null), hasLength(1));
      b.dispose();
    });
  });
}
