// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('TrainedPolicy', () {
    const block = {
      'version': 1,
      'algorithm': 'contextualBandit',
      'rules': [
        {
          'when': {'domains': 'marketing'},
          'action': 'reject',
          'confidence': 0.9,
          'support': 10,
          'trainedIn': 1,
        },
      ],
    };

    TrainedPolicy policy() => TrainedPolicy(
          policyBlock: block,
          decisionCount: 10,
          resolvedCount: 10,
          trainedAt: DateTime.utc(2026, 11, 15, 12),
          algorithm: 'contextualBandit',
          averageReward: -1.0,
        );

    test('toMap/fromMap round-trips every field', () {
      final restored = TrainedPolicy.fromMap(policy().toMap());
      expect(restored.decisionCount, 10);
      expect(restored.resolvedCount, 10);
      expect(restored.trainedAt, DateTime.utc(2026, 11, 15, 12));
      expect(restored.algorithm, 'contextualBandit');
      expect(restored.averageReward, -1.0);
      expect(restored.policyBlock, block);
      expect(restored.ruleCount, 1);
    });

    test('applyTo evolves the base context with the block', () {
      final base = learningContext(constraints: {'max_items': 5});
      final evolved = policy().applyTo(base);
      expect(evolved.domains, 'finance');
      expect(evolved.constraints?['max_items'], 5,
          reason: 'Other constraint keys are preserved.');
      expect(evolved.constraints?['cell_mind.policy'], block);
    });

    test('applyTo is portable across base contexts', () {
      final finance = policy().applyTo(learningContext(domains: 'finance'));
      final audit = policy().applyTo(learningContext(domains: 'audit'));
      expect(finance.constraints?['cell_mind.policy'], block);
      expect(audit.constraints?['cell_mind.policy'], block);
      expect(finance.domains, 'finance');
      expect(audit.domains, 'audit');
    });

    test('ruleCount is zero for an empty block', () {
      final empty = TrainedPolicy(
        policyBlock: {'version': 1, 'rules': []},
        decisionCount: 0,
        resolvedCount: 0,
        trainedAt: DateTime.utc(2026),
        algorithm: 'contextualBandit',
        averageReward: 0,
      );
      expect(empty.ruleCount, 0);
    });

    test('toString is compact and informative', () {
      final text = policy().toString();
      expect(text, contains('contextualBandit'));
      expect(text, contains('1 rules'));
      expect(text, contains('10/10'));
    });
  });
}
