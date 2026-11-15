// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('recordOutcomes', () {
    test('accumulates mind.outcome pulses into a typed log', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final recording = recordOutcomes(handle);
      handle.recordOutcome(decisionId: 'd-1', reward: 1.0);
      handle.recordOutcome(decisionId: 'd-2', reward: -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(recording.log, hasLength(2));
      expect(recording.log[0].decisionId, 'd-1');
      expect(recording.log[0].reward, 1.0);
      expect(recording.log[1].decisionId, 'd-2');
      recording.stop();
    });

    test('carries metadata and the emission timestamp', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final recording = recordOutcomes(handle);
      handle.recordOutcome(
        decisionId: 'd-1',
        reward: 0.5,
        metadata: {'tool': 'router'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(recording.log.single.metadata, {'tool': 'router'});
      expect(recording.log.single.at, isA<DateTime>());
      recording.stop();
    });

    test('ignores malformed outcome pulses', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final recording = recordOutcomes(handle);
      // Missing decisionId / non-numeric reward / wrong type.
      handle.outcomes.emit(Pulse<Object>({'reward': 1}, type: 'mind.outcome'));
      handle.outcomes.emit(Pulse<Object>(
        {'decisionId': 'd-x', 'reward': 'many'},
        type: 'mind.outcome',
      ));
      handle.outcomes.emit(Pulse<Object>('not-a-map', type: 'other'));
      await Future<void>.delayed(Duration.zero);
      expect(recording.log, isEmpty);
      recording.stop();
    });

    test('stop() halts accumulation but keeps the log', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final recording = recordOutcomes(handle);
      handle.recordOutcome(decisionId: 'd-1', reward: 1);
      await Future<void>.delayed(Duration.zero);
      recording.stop();
      handle.recordOutcome(decisionId: 'd-2', reward: 1);
      await Future<void>.delayed(Duration.zero);
      expect(recording.log, hasLength(1));
      expect(recording.log.single.decisionId, 'd-1');
    });

    test('multiple outcomes for one decision id all accumulate', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final recording = recordOutcomes(handle);
      handle.recordOutcome(decisionId: 'd-1', reward: -1);
      handle.recordOutcome(decisionId: 'd-1', reward: 1);
      await Future<void>.delayed(Duration.zero);
      expect(recording.log, hasLength(2));
      recording.stop();
    });
  });
}
