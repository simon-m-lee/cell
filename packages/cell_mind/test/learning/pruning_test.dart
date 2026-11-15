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

  Future<TrainedPolicy> train({
    required Iterable<Decision> decisions,
    required Iterable<Outcome> outcomes,
    required Context baseContext,
  }) =>
      trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: baseContext,
        journal: fixedJournal(),
        config: const TrainingConfig(prune: true),
      );

  group('pruning (full replacement)', () {
    test('prune: true keeps only this run\'s rules', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 5,
          'rules': [
            {
              'when': {'domains': 'audit'},
              'action': 'reject',
              'confidence': 0.9,
              'support': 50,
              'trainedIn': 5,
            },
          ],
        },
      });
      final decisions = [
        for (var i = 0; i < 6; i++)
          decisionFixture(
            id: 'd-$i',
            context: base,
            verdict: const Accept(),
            domains: 'finance',
          ),
      ];
      final trained = await train(
        decisions: decisions,
        outcomes: [
          for (var i = 0; i < 6; i++)
            outcomeFixture(decisionId: 'd-$i', reward: -1),
        ],
        baseContext: base,
      );
      final rules = trained.policyBlock['rules'] as List;
      expect(rules, hasLength(1));
      expect(
        (rules.single as Map)['when'],
        {'actor': 'agent-a', 'domains': 'finance'},
        reason: 'The old audit rule was pruned.',
      );
      expect(trained.policyBlock['version'], 6);
    });

    test('prune with no new rules still clears the block', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 2,
          'rules': [
            {
              'when': {'domains': 'audit'},
              'action': 'reject',
              'confidence': 0.9,
              'support': 9,
              'trainedIn': 2,
            },
          ],
        },
      });
      final trained = await train(
        decisions: const [],
        outcomes: const [],
        baseContext: base,
      );
      expect(trained.ruleCount, 0);
      expect(trained.policyBlock['version'], 3);
    });

    test('the pruning run is journaled as an effect', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 1,
          'rules': [
            {
              'when': {'domains': 'audit'},
              'action': 'reject',
              'confidence': 0.9,
              'support': 9,
              'trainedIn': 1,
            },
          ],
        },
      });
      final journal = fixedJournal();
      await trainer.train(
        decisions: const [],
        outcomes: const [],
        baseContext: base,
        journal: journal,
        config: const TrainingConfig(prune: true),
      );
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.pruning',
        ),
        isTrue,
        reason: 'The removed rule is recorded for audit.',
      );
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.training',
        ),
        isTrue,
      );
    });
  });
}
