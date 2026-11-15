// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (07_multi_agent → example #7).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// Multi-agent demo — three agents vote on a purchase, then train
/// independently.
///
/// Run with:
/// ```bash
/// dart run example/07_multi_agent.dart
/// ```
Future<void> main() async {
  print('=== Multi-agent demo ===');
  print('');

  final source = Cell.ingress<int>(
    context: Context.fromEntries([Ontology.domains.entry('finance')]),
  );

  // 1. Spawn three reviewers with distinct mandates.
  final agents = <AgentRuntime>[];
  for (final name in ['Risk', 'Compliance', 'Supervisor']) {
    final agent = await spawn(
      AgentSpec(
        name: name,
        cell: source.cell,
        mandate: DeputyContext(
          baseContext: Context.fromEntries([Ontology.domains.entry('finance')]),
          authority: 'agent-$name',
          role: 'reviewer',
        ),
        routeIn: (p) => source.ingest(p as Pulse<int>),
      ),
      journal: RecordingJournal(),
    );
    agents.add(agent);
    print('  spawned $name (authority agent-$name)');
  }

  // 2. Traffic: three purchases flow through every agent.
  print('');
  print('Purchases: 3x 1200');
  for (var i = 0; i < 3; i++) {
    source.emit(1200);
    await Future<void>.delayed(Duration.zero);
  }
  for (final agent in agents) {
    print(
        '  ${agent.name}: ${agent.trace.where((d) => d.pulse != null).length} decisions');
  }

  // 3. Debate one more purchase.
  print('');
  print('Debating purchase 2000...');
  final outcome = await debate(
    participants: agents,
    question: Pulse<int>.governed(
      payload: 2000,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('moderator'),
        Provenance.reason.entry('debate'),
        Provenance.strategy.entry(ReasoningStrategy.manual),
      ]),
    ),
    journal: RecordingJournal(),
  );
  print('  winner: ${outcome.winner.type} '
      '(consensus: ${outcome.consensusReached}, rounds: ${outcome.rounds})');
  print('  votes: ${outcome.votesByRound}');

  // 4. Independent learning: each agent trains on its own outcomes.
  print('');
  print('Training each agent independently...');
  for (final agent in agents) {
    for (final decision in agent.trace.where((d) => d.pulse != null)) {
      // Supervisor likes everything; Risk and Compliance are strict.
      agent.agentHandle.recordOutcome(
        decisionId: decision.id,
        reward: agent.name == 'Supervisor' ? 1.0 : -1.0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    final trained = await trainOffline(
      handle: agent.agentHandle,
      outcomes: agent.outcomes,
      baseContext: agent.sourceCell.context,
      trainer: contextualBandit(),
      journal: RecordingJournal(),
      config: const TrainingConfig(minSupport: 3),
    );
    print('  ${agent.name}: ${trained.ruleCount} learned rule(s), '
        '${agent.outcomes.length} outcomes');
    agent.dispose();
  }

  print('');
  print('=== Done ===');
}
