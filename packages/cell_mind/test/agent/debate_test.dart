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
  String name, {
  Policy? policy,
}) =>
    spawn(
      AgentSpec(
        name: name,
        cell: source.cell,
        mandate: mandate(name),
        policy: policy,
        routeIn: (p) => source.ingest(p as Pulse<int>),
      ),
      journal: RecordingJournal(),
    );

Pulse<int> question({int payload = 7}) => Pulse<int>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('moderator'),
        Provenance.reason.entry('debate question'),
        Provenance.strategy.entry(ReasoningStrategy.manual),
        Provenance.traceId.entry(Identity.next()),
      ]),
    );

void main() {
  group('debate', () {
    test('unanimous accepts reach consensus', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      final b = await spawnAgent(source, 'agent-b');
      final c = await spawnAgent(source, 'agent-c');
      final outcome = await debate(
        participants: [a, b, c],
        question: question(),
        journal: RecordingJournal(),
      );
      expect(outcome.winner, isA<Accept>());
      expect(outcome.consensusReached, isTrue);
      expect(outcome.rounds, 1);
      expect(outcome.votesByRound['round-1'], hasLength(3));
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('rejecting agents reach consensus-reject', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final rejectAll = predicatePolicy((object, {required host}) => false);
      final a = await spawnAgent(source, 'agent-a', policy: rejectAll);
      final b = await spawnAgent(source, 'agent-b', policy: rejectAll);
      final c = await spawnAgent(source, 'agent-c', policy: rejectAll);
      final outcome = await debate(
        participants: [a, b, c],
        question: question(),
        journal: RecordingJournal(),
      );
      expect(outcome.winner, isA<Reject>());
      expect((outcome.winner as Reject).reason, 'consensus-reject');
      expect(outcome.consensusReached, isTrue);
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('a split below the threshold resolves to no-consensus', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final rejectAll = predicatePolicy((object, {required host}) => false);
      final a = await spawnAgent(source, 'agent-a', policy: rejectAll);
      final b = await spawnAgent(source, 'agent-b', policy: rejectAll);
      final c = await spawnAgent(source, 'agent-c');
      final d = await spawnAgent(source, 'agent-d');
      final outcome = await debate(
        participants: [a, b, c, d],
        question: question(),
        journal: RecordingJournal(),
        consensusThreshold: 0.75,
      );
      // 2/4 rejects = 0.5 < 0.75, 2/4 accepts = 0.5 < 0.75.
      expect(outcome.consensusReached, isFalse);
      expect(outcome.winner, isA<Reject>());
      expect((outcome.winner as Reject).reason, 'no-consensus');
      expect(outcome.rounds, 1,
          reason: 'Stateless agents cannot re-vote; round 1 is decisive.');
      a.dispose();
      b.dispose();
      c.dispose();
      d.dispose();
    });

    test('empty participants fail closed', () async {
      final outcome = await debate(
        participants: [],
        question: question(),
        journal: RecordingJournal(),
      );
      expect(outcome.consensusReached, isFalse);
      expect((outcome.winner as Reject).reason, 'no-participants');
      expect(outcome.rounds, 0);
    });

    test('the outcome is journaled as a mind.debate effect', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      final journal = RecordingJournal();
      await debate(
        participants: [a],
        question: question(),
        journal: journal,
      );
      final json = journal.toJson();
      expect(
        json.any((e) => e['kind'] == 'io' && e['label'] == 'mind.debate'),
        isTrue,
      );
      final effect = json
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.debate')
          .single;
      final raw = effect['rawOutput'] as Map;
      expect(raw['consensusReached'], isTrue);
      a.dispose();
    });

    test('each participant records its own vote decision', () async {
      final source = Cell.ingress<int>(
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
      );
      final a = await spawnAgent(source, 'agent-a');
      final b = await spawnAgent(source, 'agent-b');
      await debate(
        participants: [a, b],
        question: question(),
        journal: RecordingJournal(),
      );
      expect(a.trace.where((d) => d.pulse != null), hasLength(1));
      expect(b.trace.where((d) => d.pulse != null), hasLength(1));
      a.dispose();
      b.dispose();
    });
  });
}
