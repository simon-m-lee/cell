// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('bridge effect records', () {
    test('MindCompletionEffect round-trips', () {
      final effect = MindCompletionEffect(
        actor: 'a',
        prompt: 'p',
        confidence: 0.9,
        strategy: ReasoningStrategy.stochastic,
        at: DateTime.utc(2026, 11, 15),
      );
      final restored = MindCompletionEffect.fromMap(effect.toMap());
      expect(restored.actor, 'a');
      expect(restored.prompt, 'p');
      expect(restored.confidence, 0.9);
      expect(restored.strategy, ReasoningStrategy.stochastic);
      expect(restored.at.toUtc(), DateTime.utc(2026, 11, 15));
      expect(effect.toMap()['version'], '1.0.0');
    });

    test('MindCompletionErrorEffect round-trips', () {
      final effect = MindCompletionErrorEffect(
        error: 'e',
        stackTrace: 'st',
        at: DateTime.utc(2026, 11, 15),
      );
      final restored = MindCompletionErrorEffect.fromMap(effect.toMap());
      expect(restored.error, 'e');
      expect(restored.stackTrace, 'st');
    });

    test('MindStreamChunkEffect round-trips', () {
      final effect = MindStreamChunkEffect(
        actor: 'a',
        chunk: 'tok',
        at: DateTime.utc(2026, 11, 15),
      );
      final restored = MindStreamChunkEffect.fromMap(effect.toMap());
      expect(restored.actor, 'a');
      expect(restored.chunk, 'tok');
    });

    test('MindToolDispatchEffect round-trips args', () {
      final effect = MindToolDispatchEffect(
        actor: 'a',
        verb: 'v',
        args: {'x': 1},
        at: DateTime.utc(2026, 11, 15),
      );
      final restored = MindToolDispatchEffect.fromMap(effect.toMap());
      expect(restored.verb, 'v');
      expect(restored.args, {'x': 1});
    });

    test('MindToolResultEffect round-trips and degrades non-encodables', () {
      final plain = MindToolResultEffect(
        verb: 'v',
        result: {'ok': true},
        duration: const Duration(milliseconds: 12),
        at: DateTime.utc(2026, 11, 15),
      );
      final restored = MindToolResultEffect.fromMap(plain.toMap());
      expect(restored.result, {'ok': true});
      expect(restored.duration, const Duration(milliseconds: 12));

      final weird = MindToolResultEffect(
        verb: 'v',
        result: Object(),
        duration: Duration.zero,
        at: DateTime.utc(2026, 11, 15),
      );
      final degraded = MindToolResultEffect.fromMap(weird.toMap());
      expect(degraded.result, isA<String>(),
          reason: 'Non-encodable results degrade to toString().');
    });

    test('MindToolErrorEffect and MindToolRejectedEffect round-trip', () {
      final error = MindToolErrorEffect(
        verb: 'v',
        error: 'boom',
        stackTrace: 'trace',
        at: DateTime.utc(2026, 11, 15),
      );
      final restoredError = MindToolErrorEffect.fromMap(error.toMap());
      expect(restoredError.stackTrace, 'trace');

      final rejected = MindToolRejectedEffect(
        verb: 'v',
        reason: 'low-confidence',
        details: {'confidence': 0.2},
        at: DateTime.utc(2026, 11, 15),
      );
      final restoredRejected = MindToolRejectedEffect.fromMap(rejected.toMap());
      expect(restoredRejected.reason, 'low-confidence');
      expect(restoredRejected.details, {'confidence': 0.2});
    });

    test('bridgeEffectFromMap dispatches every type', () {
      final maps = [
        MindCompletionEffect(
          actor: 'a',
          prompt: 'p',
          confidence: 0.9,
          strategy: ReasoningStrategy.probabilistic,
          at: DateTime.utc(2026),
        ).toMap(),
        MindCompletionErrorEffect(
          error: 'e',
          stackTrace: '',
          at: DateTime.utc(2026),
        ).toMap(),
        MindStreamChunkEffect(
          actor: 'a',
          chunk: 'c',
          at: DateTime.utc(2026),
        ).toMap(),
        MindToolDispatchEffect(
          actor: 'a',
          verb: 'v',
          args: const {},
          at: DateTime.utc(2026),
        ).toMap(),
        MindToolResultEffect(
          verb: 'v',
          result: 1,
          duration: Duration.zero,
          at: DateTime.utc(2026),
        ).toMap(),
        MindToolErrorEffect(
          verb: 'v',
          error: 'e',
          stackTrace: '',
          at: DateTime.utc(2026),
        ).toMap(),
        MindToolRejectedEffect(
          verb: 'v',
          reason: 'unknown-verb',
          details: const {},
          at: DateTime.utc(2026),
        ).toMap(),
      ];
      for (final map in maps) {
        expect(bridgeEffectFromMap(map), isNotNull);
      }
    });

    test('bridgeEffectFromMap rejects unknown types', () {
      expect(
        () => bridgeEffectFromMap({'type': 'mind.unknown'}),
        throwsArgumentError,
      );
    });
  });
}
