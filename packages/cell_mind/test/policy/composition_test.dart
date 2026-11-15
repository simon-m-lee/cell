// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  Cell hostWith(Context context) => Cell.ingress<int>(context: context).cell;

  group('contextAware', () {
    test('accepts a fully-governed pulse', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = contextAware();
      final pulse = governedPulse(domains: 'finance', confidence: 0.95);
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects a missing domain claim', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = contextAware();
      final pulse = governedPulse(confidence: 0.95);
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects an out-of-domain pulse', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = contextAware();
      final pulse = governedPulse(domains: 'marketing', confidence: 0.95);
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects low confidence', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = contextAware();
      final pulse = governedPulse(domains: 'finance', confidence: 0.5);
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('requireDomain: false lifts the both-tagged requirement', () async {
      // An untagged acceptor no longer requires domain declarations, and a
      // missing-confidence pulse is admitted by the explicit opt-out.
      final untaggedHost = hostWith(Context.system);
      final policy = contextAware(
        requireDomain: false,
        allowMissingConfidence: true,
      );
      expect(
        await policy.call(governedPulse(), host: untaggedHost),
        isTrue,
      );
      // A tagged acceptor still rejects untagged pulses — domainPolicy
      // itself fails closed on the claim (P4).
      final taggedHost = hostWith(ctxWithDomains('finance'));
      expect(
        await policy.call(governedPulse(), host: taggedHost),
        isFalse,
      );
    });

    test('requireCompliance: true adds the compliance gate', () async {
      final host = hostWith(Context(domains: 'finance', compliances: 'GDPR'));
      final policy = contextAware(requireCompliance: true);
      expect(
        await policy.call(
          governedPulse(domains: 'finance', compliance: 'GDPR', confidence: 1),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(domains: 'finance', confidence: 1),
          host: host,
        ),
        isFalse,
      );
    });

    test('requireClearance: true adds the clearance gate', () async {
      final host = hostWith(
        DeputyContext(
          baseContext: ctxWithDomains('finance'),
          authority: 'OBSERVATION',
          clearance: Clearance.observational,
        ),
      );
      final policy = contextAware(requireClearance: true);
      expect(
        await policy.call(
          governedPulse(domains: 'finance', confidence: 1),
          host: host,
        ),
        isFalse,
        reason: 'observational clearance cannot receive pulses',
      );
    });
  });

  group('paranoid', () {
    test('rejects anything short of a fully-declared pulse', () async {
      final host = hostWith(
        DeputyContext(
          baseContext: Context(domains: 'finance', compliances: 'GDPR'),
          authority: 'OBSERVATION',
        ),
      );
      final policy = paranoid();
      expect(await policy.call(governedPulse(), host: host), isFalse);
      expect(
        await policy.call(
          governedPulse(domains: 'finance', confidence: 0.9),
          host: host,
        ),
        isFalse,
        reason: 'complianceOverlapPolicy requires both sides to declare',
      );
      expect(
        await policy.call(
          governedPulse(
            domains: 'finance',
            compliance: 'GDPR',
            confidence: 0.9,
            strategy: ReasoningStrategy.deterministic,
            auditLevel: AuditLevel.standard,
            sensitivity: Sensitivity.public,
          ),
          host: host,
        ),
        isTrue,
      );
    });
  });

  group('composition algebra', () {
    test('+ short-circuits on rejection', () async {
      var secondCalled = false;
      final host = hostWith(ctxWithDomains('finance'));
      final first = domainPolicy();
      final second = predicatePolicy((object, {required host}) {
        secondCalled = true;
        return true;
      });
      final composed = first + second;
      expect(
        await composed.call(governedPulse(domains: 'marketing'), host: host),
        isFalse,
      );
      expect(secondCalled, isFalse,
          reason: 'A rejection at rule N must prevent rule N+1.');
    });

    test('repeated policies compose additively', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy() + domainPolicy();
      expect(
        await policy.call(governedPulse(domains: 'finance'), host: host),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isFalse,
      );
    });

    test('a policy composed into a cell testRule governs static mode',
        () async {
      final gate = Cell.ingress<int>(
        context: ctxWithDomains('finance'),
        testRule: requiresDomainPolicy() + domainPolicy(),
      );
      final accepted = <int>[];
      final sub = Cell.observe(
          source: gate.cell,
          effect: (Pulse p) {
            accepted.add(p.payload as int);
          });
      await gate.ingest(governedPulse(payload: 1, domains: 'finance'));
      await gate.ingest(governedPulse(payload: 2, domains: 'marketing'));
      await gate.ingest(governedPulse(payload: 3));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, [1]);
      sub.stop();
    });
  });
}
