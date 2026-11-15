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

  group('compliancePolicy', () {
    test('accepts when every required marker is provided', () async {
      final host = hostWith(ctxWithCompliance('GDPR,SOC2'));
      final policy = compliancePolicy();
      final pulse = governedPulse(compliance: 'GDPR,SOC2');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('accepts extra pulse markers beyond the requirements', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = compliancePolicy();
      final pulse = governedPulse(compliance: 'GDPR,HIPAA');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects when a required marker is missing', () async {
      final host = hostWith(ctxWithCompliance('GDPR,SOC2'));
      final policy = compliancePolicy();
      final pulse = governedPulse(compliance: 'GDPR');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects untagged pulses when the acceptor requires markers',
        () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = compliancePolicy();
      final pulse = governedPulse();
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('accepts everything when the acceptor is untagged', () async {
      final host = hostWith(Context.system);
      final policy = compliancePolicy();
      final pulse = governedPulse(compliance: 'GDPR');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('accepts additionalCompliance beyond the host declaration', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = compliancePolicy(additionalCompliance: {'HIPAA'});
      final pulse = governedPulse(compliance: 'GDPR,HIPAA');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('passes non-pulse objects through', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = compliancePolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });

  group('complianceOverlapPolicy', () {
    test('accepts when both sides declare overlapping markers', () async {
      final host = hostWith(ctxWithCompliance('GDPR,SOC2'));
      final policy = complianceOverlapPolicy();
      final pulse = governedPulse(compliance: 'SOC2,HIPAA');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects when the marker sets are disjoint', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = complianceOverlapPolicy();
      final pulse = governedPulse(compliance: 'HIPAA');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects when the acceptor is untagged', () async {
      final host = hostWith(Context.system);
      final policy = complianceOverlapPolicy();
      final pulse = governedPulse(compliance: 'GDPR');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects when the pulse is untagged', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = complianceOverlapPolicy();
      final pulse = governedPulse();
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('passes non-pulse objects through', () async {
      final host = hostWith(ctxWithCompliance('GDPR'));
      final policy = complianceOverlapPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
