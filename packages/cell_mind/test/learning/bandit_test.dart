// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final trainer = contextualBandit();
  final base = learningContext();

  Future<TrainedPolicy> train(
    Iterable<Decision> decisions,
    Iterable<Outcome> outcomes, {
    TrainingConfig? config,
    RewardFunction? reward,
    DateTime? at,
  }) =>
      trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: fixedJournal(at: at),
        config: config,
        reward: reward,
      );

  group('contextual bandit', () {
    test('empty log emits no rules', () async {
      final trained = await train(const [], const []);
      expect(trained.ruleCount, 0);
      expect(trained.resolvedCount, 0);
      expect(trained.averageReward, 0.0);
    });

    test('unresolved decisions are skipped', () async {
      final decisions = [
        decisionFixture(id: 'd-1', context: base, verdict: const Accept()),
      ];
      final trained = await train(decisions, const []);
      expect(trained.resolvedCount, 0);
      expect(trained.ruleCount, 0);
      expect(trained.decisionCount, 1);
    });

    test('negative-reward accepts train a reject rule', () async {
      final decisions = [
        for (var i = 0; i < 10; i++)
          decisionFixture(
            id: 'd-$i',
            context: base,
            verdict: const Accept(),
            domains: 'marketing',
          ),
      ];
      final outcomes = [
        for (var i = 0; i < 10; i++)
          outcomeFixture(decisionId: 'd-$i', reward: -1),
      ];
      final trained = await train(decisions, outcomes);
      expect(trained.ruleCount, 1);
      final rule =
          (trained.policyBlock['rules'] as List).single as Map<String, dynamic>;
      expect(rule['when'], {'actor': 'agent-a', 'domains': 'marketing'});
      expect(rule['action'], 'reject');
      expect(rule['support'], 10);
      expect(rule['confidence'], 1.0);
      expect(rule['trainedIn'], 1);
    });

    test('positive-reward accepts train an accept rule', () async {
      final decisions = [
        for (var i = 0; i < 6; i++)
          decisionFixture(id: 'd-$i', context: base, verdict: const Accept()),
      ];
      final outcomes = [
        for (var i = 0; i < 6; i++)
          outcomeFixture(decisionId: 'd-$i', reward: 1),
      ];
      final trained = await train(decisions, outcomes);
      final rule =
          (trained.policyBlock['rules'] as List).single as Map<String, dynamic>;
      expect(rule['action'], 'accept');
    });

    test('prefers the verdict with the higher average reward', () async {
      final decisions = <Decision>[
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'a-$i',
            context: base,
            verdict: const Accept(),
            domains: 'finance',
          ),
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'r-$i',
            context: base,
            verdict: const Reject('policy-rejected'),
            domains: 'finance',
          ),
      ];
      final outcomes = <Outcome>[
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'a-$i', reward: 0.2),
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'r-$i', reward: -1),
      ];
      final trained = await train(decisions, outcomes);
      final rule =
          (trained.policyBlock['rules'] as List).single as Map<String, dynamic>;
      expect(rule['action'], 'accept');
      expect(rule['support'], 10);
    });

    test('respects minSupport', () async {
      final decisions = [
        for (var i = 0; i < 3; i++)
          decisionFixture(id: 'd-$i', context: base, verdict: const Accept()),
      ];
      final outcomes = [
        for (var i = 0; i < 3; i++)
          outcomeFixture(decisionId: 'd-$i', reward: -1),
      ];
      final trained = await train(
        decisions,
        outcomes,
        config: const TrainingConfig(minSupport: 5),
      );
      expect(trained.ruleCount, 0);
    });

    test('respects minConfidence', () async {
      final decisions = <Decision>[
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'a-$i',
            context: base,
            verdict: const Accept(),
          ),
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'r-$i',
            context: base,
            verdict: const Reject('x'),
          ),
      ];
      final outcomes = <Outcome>[
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'a-$i', reward: 0.5),
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'r-$i', reward: 0.5),
      ];
      final trained = await train(
        decisions,
        outcomes,
        config: const TrainingConfig(minConfidence: 0.6),
      );
      // Equal average rewards → zero confidence → no rule.
      expect(trained.ruleCount, 0);
    });

    test('caps rules at maxRules, keeping the most confident', () async {
      final decisions = <Decision>[
        for (var d = 0; d < 3; d++)
          for (var i = 0; i < 10; i++)
            decisionFixture(
              id: 'd$d-$i',
              context: base,
              verdict: const Accept(),
              domains: 'domain-$d',
              actor: 'actor-$d',
            ),
      ];
      final outcomes = <Outcome>[
        for (var d = 0; d < 3; d++)
          for (var i = 0; i < 10; i++)
            outcomeFixture(
              decisionId: 'd$d-$i',
              reward: d == 0 ? -0.5 : -1.0,
            ),
      ];
      final trained = await train(
        decisions,
        outcomes,
        config: const TrainingConfig(maxRules: 2),
      );
      expect(trained.ruleCount, 2);
    });

    test('window filters decisions by age', () async {
      final oldDecision = decisionFixture(
        id: 'old',
        context: base,
        verdict: const Accept(),
        at: DateTime.utc(2026, 11, 15, 8),
      );
      final freshDecision = decisionFixture(
        id: 'fresh',
        context: base,
        verdict: const Accept(),
        at: DateTime.utc(2026, 11, 15, 11, 30),
      );
      final trained = await train(
        [oldDecision, freshDecision],
        [
          outcomeFixture(decisionId: 'old', reward: -1),
          outcomeFixture(decisionId: 'fresh', reward: -1),
        ],
        config: const TrainingConfig(window: Duration(hours: 1)),
        at: DateTime.utc(2026, 11, 15, 12),
      );
      expect(trained.resolvedCount, 1);
    });

    test('custom RewardFunction overrides the outcome reward', () async {
      final decisions = [
        for (var i = 0; i < 5; i++)
          decisionFixture(id: 'd-$i', context: base, verdict: const Accept()),
      ];
      final trained = await train(
        decisions,
        [
          for (var i = 0; i < 5; i++)
            outcomeFixture(decisionId: 'd-$i', reward: -1)
        ],
        reward: (decision, outcome) => 1.0,
      );
      expect(trained.averageReward, 1.0);
      final rule =
          (trained.policyBlock['rules'] as List).single as Map<String, dynamic>;
      expect(rule['action'], 'accept');
    });

    test('rules are sorted by confidence descending', () async {
      final decisions = <Decision>[
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'a-$i',
            context: base,
            verdict: const Accept(),
            domains: 'alpha',
          ),
        for (var i = 0; i < 5; i++)
          decisionFixture(
            id: 'b-$i',
            context: base,
            verdict: const Accept(),
            domains: 'beta',
          ),
      ];
      final outcomes = <Outcome>[
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'a-$i', reward: -0.5),
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'b-$i', reward: -1.0),
      ];
      final trained = await train(
        decisions,
        outcomes,
        config: const TrainingConfig(minConfidence: 0),
      );
      final rules = trained.policyBlock['rules'] as List;
      expect(rules[0] is Map, isTrue);
      expect(
        (rules[0] as Map)['when'],
        {'actor': 'agent-a', 'domains': 'beta'},
      );
      expect(
        (rules[1] as Map)['when'],
        {'actor': 'agent-a', 'domains': 'alpha'},
      );
    });

    test('trainedAt comes from journal time', () async {
      final trained = await train(
        const [],
        const [],
        at: DateTime.utc(2026, 11, 15, 12, 30),
      );
      expect(trained.trainedAt, DateTime.utc(2026, 11, 15, 12, 30));
    });
  });
}
