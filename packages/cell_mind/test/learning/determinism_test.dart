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

  group('training determinism', () {
    test('recording → replay produces the identical TrainedPolicy', () async {
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

      final recording = fixedJournal();
      final trained1 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: recording,
      );

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final trained2 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: replay,
      );

      expect(trained2.toMap(), trained1.toMap());
      expect(trained2.trainedAt.toUtc(), trained1.trainedAt.toUtc(),
          reason: 'trainedAt is journal time, reproduced by replay. '
              'Replay restores the epoch in local time; compare instants.');
      replay.assertExhausted();
    });

    test('window filtering uses journal time on both sides', () async {
      final decisions = [
        decisionFixture(
          id: 'old',
          context: base,
          verdict: const Accept(),
          at: DateTime.utc(2026, 11, 15, 8),
        ),
        decisionFixture(
          id: 'fresh',
          context: base,
          verdict: const Accept(),
          at: DateTime.utc(2026, 11, 15, 11, 30),
        ),
      ];
      final outcomes = [
        outcomeFixture(decisionId: 'old', reward: -1),
        outcomeFixture(decisionId: 'fresh', reward: -1),
      ];

      final recording = fixedJournal(at: DateTime.utc(2026, 11, 15, 12));
      final trained1 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: recording,
        config: const TrainingConfig(window: Duration(hours: 1)),
      );
      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final trained2 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: replay,
        config: const TrainingConfig(window: Duration(hours: 1)),
      );
      expect(trained2.toMap(), trained1.toMap());
      expect(trained1.resolvedCount, 1);
      replay.assertExhausted();
    });

    test('pruned runs replay deterministically', () async {
      final baseWithRules = learningContext(constraints: {
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
      final recording = fixedJournal();
      final trained1 = await trainer.train(
        decisions: const [],
        outcomes: const [],
        baseContext: baseWithRules,
        journal: recording,
        config: const TrainingConfig(prune: true),
      );
      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final trained2 = await trainer.train(
        decisions: const [],
        outcomes: const [],
        baseContext: baseWithRules,
        journal: replay,
        config: const TrainingConfig(prune: true),
      );
      expect(trained2.toMap(), trained1.toMap());
      replay.assertExhausted();
    });

    test('same inputs, same journal clock → same policy (twice recorded)',
        () async {
      final decisions = [
        for (var i = 0; i < 5; i++)
          decisionFixture(id: 'd-$i', context: base, verdict: const Accept()),
      ];
      final outcomes = [
        for (var i = 0; i < 5; i++)
          outcomeFixture(decisionId: 'd-$i', reward: 1),
      ];
      final t1 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: fixedJournal(),
      );
      final t2 = await trainer.train(
        decisions: decisions,
        outcomes: outcomes,
        baseContext: base,
        journal: fixedJournal(),
      );
      expect(t1.toMap(), t2.toMap());
    });
  });
}
