// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('Outcome', () {
    test('constructs with all fields', () {
      final outcome = Outcome(
        decisionId: 'd-1',
        reward: 1.5,
        at: DateTime.utc(2026, 11, 15),
        metadata: {'tool': 'llm'},
      );
      expect(outcome.decisionId, 'd-1');
      expect(outcome.reward, 1.5);
      expect(outcome.metadata, {'tool': 'llm'});
      expect(outcome.at, DateTime.utc(2026, 11, 15));
    });

    test('toMap/fromMap round-trips exactly', () {
      final outcome = Outcome(
        decisionId: 'd-2',
        reward: -1.0,
        at: DateTime.utc(2026, 11, 15, 9, 30),
        metadata: {'error': 'timeout'},
      );
      final restored = Outcome.fromMap(outcome.toMap());
      expect(restored.decisionId, 'd-2');
      expect(restored.reward, -1.0);
      expect(restored.at, DateTime.utc(2026, 11, 15, 9, 30));
      expect(restored.metadata, {'error': 'timeout'});
    });

    test('null metadata round-trips', () {
      final outcome = Outcome(
        decisionId: 'd-3',
        reward: 0,
        at: DateTime.utc(2026),
      );
      final restored = Outcome.fromMap(outcome.toMap());
      expect(restored.metadata, isNull);
    });

    test('integer rewards are coerced to double on restore', () {
      final map = {
        'decisionId': 'd-4',
        'reward': 2,
        'at': '2026-11-15T00:00:00.000Z',
        'metadata': null,
      };
      final restored = Outcome.fromMap(map);
      expect(restored.reward, 2.0);
    });

    test('toString is compact', () {
      final outcome = Outcome(
        decisionId: 'd-5',
        reward: 1,
        at: DateTime.utc(2026),
      );
      expect(outcome.toString(), contains('d-5'));
      expect(outcome.toString(), contains('1.0'));
    });
  });
}
