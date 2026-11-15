// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

/// The object-type dispatch contract (D1): every factory must return
/// `true` for the object types it does not govern. This file cross-cuts
/// every factory against the three dispatch shapes.
void main() {
  final host = Cell.ingress<int>(context: ctxWithDomains('finance')).cell;
  final pulse = governedPulse(domains: 'marketing'); // domain-rejected
  final action = someFunction;
  final link = Cell.ingress<int>().cell;

  Future<void> expectPolicyPasses(
    String label,
    Policy policy,
    List<dynamic> objects,
  ) async {
    for (final object in objects) {
      expect(await policy.call(object, host: host), isTrue,
          reason: '$label must pass ${object.runtimeType} through');
    }
  }

  test('pulse policies pass actions and links through', () async {
    await expectPolicyPasses('domainPolicy', domainPolicy(), [action, link]);
    await expectPolicyPasses(
        'requiresDomainPolicy', requiresDomainPolicy(), [action, link]);
    await expectPolicyPasses(
        'compliancePolicy', compliancePolicy(), [action, link]);
    await expectPolicyPasses(
        'complianceOverlapPolicy', complianceOverlapPolicy(), [action, link]);
    await expectPolicyPasses(
        'confidencePolicy', confidencePolicy(), [action, link]);
    await expectPolicyPasses('strategyPolicy',
        strategyPolicy({ReasoningStrategy.deterministic}), [action, link]);
    await expectPolicyPasses(
        'auditLevelPolicy', auditLevelPolicy(), [action, link]);
    await expectPolicyPasses(
        'actorPolicy', actorPolicy({'auditor'}), [action, link]);
    await expectPolicyPasses(
        'purposePolicy', purposePolicy({'p'}), [action, link]);
    await expectPolicyPasses(
      'sensitivityPolicy',
      sensitivityPolicy(),
      [action, link],
    );
    await expectPolicyPasses(
      'notOlderThan',
      notOlderThan(Duration(minutes: 1), clock: DateTime.now),
      [action, link],
    );
  });

  test('action policies pass pulses and links through', () async {
    await expectPolicyPasses('authorityPolicy', authorityPolicy(), [
      pulse,
      link,
    ]);
    await expectPolicyPasses(
      'exactFunctionsPolicy',
      exactFunctionsPolicy({action}),
      [pulse, link],
    );
  });

  test('clearancePolicy governs all three shapes (no pass-through)', () async {
    // Clearance is a cross-cutting policy: every shape has a required
    // clearance, so nothing passes through silently.
    final privilegedHost = Cell.ingress<int>(
      context: ctxWithClearance(Clearance.unrestricted),
    ).cell;
    final policy = clearancePolicy();
    expect(await policy.call(pulse, host: privilegedHost), isTrue);
    expect(await policy.call(action, host: privilegedHost), isTrue);
    expect(await policy.call(link, host: privilegedHost), isTrue);
  });

  test('isolationPolicy passes non-pulse objects through below sandbox',
      () async {
    final scopedHost = Cell.ingress<int>(
      context: DeputyContext(
        baseContext: ctxWithDomains('finance'),
        authority: 'OBSERVATION',
        isolation: Isolation.scoped,
      ),
    ).cell;
    final policy = isolationPolicy();
    expect(await policy.call(action, host: scopedHost), isTrue);
    expect(await policy.call(link, host: scopedHost), isTrue);
  });
}

int someFunction(int x) => x;
