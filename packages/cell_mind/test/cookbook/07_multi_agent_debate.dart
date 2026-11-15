// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  test('recipe 7: multi-agent debate with consensus', () async {
    final journal = RecordingJournal();
    final source = Cell.ingress<int>();
    final agents = <AgentRuntime>[
      for (final name in ['risk', 'compliance', 'supervisor'])
        await spawn(
          AgentSpec(
            name: name,
            cell: source.cell,
            mandate: DeputyContext(
              baseContext: source.cell.context,
              authority: 'agent-$name',
            ),
            routeIn: (p) => source.ingest(p as Pulse<int>),
          ),
          journal: journal,
        ),
    ];
    final outcome = await debate(
      participants: agents,
      question: Pulse<int>.governed(
        payload: 42,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('moderator'),
          Provenance.strategy.entry(ReasoningStrategy.manual),
        ]),
      ),
      journal: journal,
      consensusThreshold: 0.7,
    );
    expect(outcome.consensusReached, isTrue);
    expect(outcome.winner, isA<Accept>());
    expect(outcome.votesByRound['round-1'], hasLength(3));
    for (final agent in agents) {
      agent.dispose();
    }
  });
}
