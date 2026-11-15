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
    TrainingConfig? config,
  }) =>
      trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: baseContext,
        journal: fixedJournal(),
        config: config,
      );

  group('accumulation (additive merge)', () {
    test('a new run updates a same-key rule', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 1,
          'rules': [
            {
              'when': {'actor': 'agent-a', 'domains': 'marketing'},
              'action': 'reject',
              'confidence': 0.5,
              'support': 5,
              'trainedIn': 1,
            },
          ],
        },
      });
      final decisions = [
        for (var i = 0; i < 10; i++)
          decisionFixture(
            id: 'd-$i',
            context: base,
            verdict: const Accept(),
            domains: 'marketing',
          ),
      ];
      final trained = await train(
        decisions: decisions,
        outcomes: [
          for (var i = 0; i < 10; i++)
            outcomeFixture(decisionId: 'd-$i', reward: 1),
        ],
        baseContext: base,
      );
      final rules = trained.policyBlock['rules'] as List;
      expect(rules, hasLength(1));
      expect((rules.single as Map)['action'], 'accept',
          reason: 'The newer rule wins on the same when key.');
      expect((rules.single as Map)['trainedIn'], 2);
      expect(trained.policyBlock['version'], 2);
    });

    test('unrelated existing rules are preserved', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 3,
          'rules': [
            {
              'when': {'domains': 'audit'},
              'action': 'reject',
              'confidence': 0.8,
              'support': 20,
              'trainedIn': 3,
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
      expect(rules, hasLength(2));
      final whens = rules.map((r) => (r as Map)['when']).toList();
      expect(
        whens,
        contains(equals({'actor': 'agent-a', 'domains': 'finance'})),
      );
      expect(
        whens,
        contains(equals({'domains': 'audit'})),
        reason: 'The untouched rule survives with its trainedIn.',
      );
      final audit = rules.singleWhere((r) {
        final when = (r as Map)['when'] as Map;
        return when['domains'] == 'audit';
      }) as Map;
      expect(audit['trainedIn'], 3);
      expect(trained.policyBlock['version'], 4);
    });

    test('rules stay sorted by confidence after the merge', () async {
      final base = learningContext(constraints: {
        'cell_mind.policy': {
          'version': 1,
          'rules': [
            {
              'when': {'domains': 'audit'},
              'action': 'reject',
              'confidence': 0.95,
              'support': 10,
              'trainedIn': 1,
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
      expect(rules.first, isA<Map>());
      // The fresh finance rule has confidence 1.0 (all accepts rewarded
      // -1, no rejects), so it sorts ahead of the preserved 0.95 rule.
      expect(
        (rules.first as Map)['when'],
        {'actor': 'agent-a', 'domains': 'finance'},
      );
      expect(
        (rules[1] as Map)['when'],
        {'domains': 'audit'},
      );
    });

    test('other constraint keys survive the evolved context', () async {
      final base = learningContext(constraints: {
        'max_items': 5,
        'cell_mind.policy': {'version': 1, 'rules': []},
      });
      final trained = await train(
        decisions: const [],
        outcomes: const [],
        baseContext: base,
      );
      final evolved = trained.applyTo(base);
      expect(evolved.constraints?['max_items'], 5);
    });
  });
}
