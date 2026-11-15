// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('end-to-end cognitive runtime', () {
    test('domain-gated pipeline records decisions and captures outcomes',
        () async {
      // 1. Governed source.
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      // 2. Cognitive layer.
      final handle = cognitive(cell: src.cell, policy: contextAware());
      // 3. Decision-log observer (XAI-style consumption).
      final log = <String>[];
      final logSub = Cell.observe(
          source: handle.decisions,
          effect: (Pulse p) {
            final decision = p.payload as Decision;
            log.add('${decision.verdict.runtimeType}');
          });
      // 4. Outcome observer (learning-style consumption).
      final outcomes = <Map<String, dynamic>>[];
      final outcomeSub = Cell.observe(
          source: handle.outcomes.cell,
          effect: (Pulse p) {
            final outcome = p.payload as Pulse;
            if (outcome.type == 'mind.outcome') {
              outcomes.add(outcome.payload as Map<String, dynamic>);
            }
          });

      // 5. Traffic.
      await src.ingest(
          governedPulse(payload: 1, domains: 'finance', confidence: 0.99));
      await src.ingest(
          governedPulse(payload: 2, domains: 'marketing', confidence: 0.99));
      await Future<void>.delayed(Duration.zero);

      expect(handle.decisions, hasLength(2));
      expect(log, ['Accept', 'Reject']);

      // 6. Reward the accepted decision.
      handle.recordOutcome(
        decisionId: handle.decisions[0].id,
        reward: 1.0,
        metadata: {'source': 'integration-test'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(outcomes, hasLength(1));
      expect(outcomes.single['decisionId'], handle.decisions[0].id);

      logSub.stop();
      outcomeSub.stop();
    });

    test('the full loop serialize → restore keeps verdicts intact', () async {
      final src = Cell.ingress<int>(context: ctxWithVersion('3.1.4'));
      final handle = cognitive(cell: src.cell, policy: domainPolicy());
      await src.ingest(governedPulse(payload: 1, domains: 'finance'));
      await Future<void>.delayed(Duration.zero);
      final restored =
          handle.decisions.map((d) => Decision.fromMap(d.toMap())).toList();
      expect(restored, hasLength(1));
      expect(restored.single.contextVersion, '3.1.4');
      expect(restored.single.verdict, isA<Accept>());
      expect(restored.single.id, handle.decisions.single.id);
    });

    test('rejected pulses never reach downstream observers', () async {
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final handle = cognitive(cell: src.cell, policy: domainPolicy());
      final seen = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            seen.add(p.payload as int);
          });
      await src.ingest(governedPulse(payload: 7, domains: 'marketing'));
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      // The observer's own link to the cognitive view is also recorded;
      // filter to the pulse decision.
      final pulseDecisions =
          handle.decisions.where((d) => d.pulse != null).toList();
      expect(pulseDecisions, hasLength(1));
      expect(
          (pulseDecisions.single.verdict as Reject).reason, 'policy-rejected');
      sub.stop();
    });
  });
}
