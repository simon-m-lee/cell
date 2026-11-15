// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('recordOutcome', () {
    test('emits a mind.outcome pulse with decisionId and reward', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final observed = <Map<String, dynamic>>[];
      final sub = Cell.observe(
          source: handle.outcomes.cell,
          effect: (Pulse p) {
            final outcome = p.payload as Pulse;
            if (outcome.type == 'mind.outcome') {
              observed.add(outcome.payload as Map<String, dynamic>);
            }
          });
      handle.recordOutcome(decisionId: 'd-1', reward: 1.0);
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single['decisionId'], 'd-1');
      expect(observed.single['reward'], 1.0);
      expect(observed.single.containsKey('metadata'), isFalse);
      sub.stop();
    });

    test('metadata is carried when provided', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final observed = <Map<String, dynamic>>[];
      final sub = Cell.observe(
          source: handle.outcomes.cell,
          effect: (Pulse p) {
            final outcome = p.payload as Pulse;
            if (outcome.type == 'mind.outcome') {
              observed.add(outcome.payload as Map<String, dynamic>);
            }
          });
      handle.recordOutcome(
        decisionId: 'd-2',
        reward: -1.0,
        metadata: {'latencyMs': 12},
      );
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single['metadata'], {'latencyMs': 12});
      sub.stop();
    });

    test('does not verify the decision exists', () {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      expect(
        () => handle.recordOutcome(decisionId: 'ghost', reward: 0.5),
        returnsNormally,
      );
    });
  });
}
