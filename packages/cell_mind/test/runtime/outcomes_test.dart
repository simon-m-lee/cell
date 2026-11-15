// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('outcome channel', () {
    test('outcomes are emittable and observable', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: handle.outcomes.cell,
          effect: (Pulse p) {
            // Channel contract: each entry's payload IS the outcome pulse.
            observed.add(p.payload as Pulse);
          });
      final payload = {
        'decisionId': 'd-1',
        'reward': 1.0,
      };
      handle.outcomes.emit(Pulse<Object>(payload, type: 'mind.outcome'));
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single.type, 'mind.outcome');
      expect(observed.single.payload, payload);
      sub.stop();
    });

    test('multiple outcomes may target the same decision id', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      handle.recordOutcome(decisionId: 'd-1', reward: -1.0);
      handle.recordOutcome(decisionId: 'd-1', reward: 1.0);
      final observed = <Map<String, dynamic>>[];
      final sub = Cell.observe(
          source: handle.outcomes.cell,
          effect: (Pulse p) {
            final outcome = p.payload as Pulse;
            if (outcome.type == 'mind.outcome') {
              observed.add(outcome.payload as Map<String, dynamic>);
            }
          });
      handle.recordOutcome(decisionId: 'd-1', reward: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(observed, hasLength(1));
      expect(observed.single['decisionId'], 'd-1');
      expect(observed.single['reward'], 0.5);
      sub.stop();
    });
  });
}
