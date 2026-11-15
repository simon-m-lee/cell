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

  PulseEphemeralPolicy ephemeralPolicy() => PulseEphemeralPolicy(
        hopLimit: 3,
        onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
        onInvalidate: (pulse) => true,
      );

  group('isolationPolicy', () {
    test('plain Context carries no isolation — everything passes', () async {
      final host = hostWith(Context.system);
      final policy = isolationPolicy();
      expect(await policy.call(governedPulse(), host: host), isTrue);
      expect(await policy.call(someFunction, host: host), isTrue);
    });

    test('shared accepts everything', () async {
      final host = hostWith(ctxWithIsolation(Isolation.shared));
      final policy = isolationPolicy();
      expect(await policy.call(governedPulse(), host: host), isTrue);
      expect(await policy.call(someFunction, host: host), isTrue);
    });

    test('scoped accepts in-domain and rejects out-of-domain pulses', () async {
      final host = hostWith(DeputyContext(
        baseContext: ctxWithDomains('finance'),
        authority: 'OBSERVATION',
        isolation: Isolation.scoped,
      ));
      final policy = isolationPolicy();
      expect(
        await policy.call(governedPulse(domains: 'finance'), host: host),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isFalse,
      );
      expect(
        await policy.call(governedPulse(), host: host),
        isFalse,
        reason: 'Untagged pulses cannot prove domain membership.',
      );
    });

    test('restricted adds the compliance subset requirement', () async {
      final host = hostWith(DeputyContext(
        baseContext: Context(domains: 'finance', compliances: 'GDPR'),
        authority: 'OBSERVATION',
        isolation: Isolation.restricted,
      ));
      final policy = isolationPolicy();
      expect(
        await policy.call(
          governedPulse(domains: 'finance', compliance: 'GDPR'),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(domains: 'finance'), host: host),
        isFalse,
        reason: 'Missing a required compliance marker.',
      );
    });

    test('sandboxed accepts only ephemeral pulses', () async {
      final host = hostWith(ctxWithIsolation(Isolation.sandboxed));
      final policy = isolationPolicy();
      expect(
        await policy.call(
          governedPulse(policy: ephemeralPolicy()),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(), host: host),
        isFalse,
        reason: 'A pulse without a lifecycle policy is not ephemeral.',
      );
      expect(
        await policy.call(someFunction, host: host),
        isFalse,
        reason: 'Commands mutate live state — not allowed in a sandbox.',
      );
    });

    test('total rejects everything (air-gapped)', () async {
      final host = hostWith(ctxWithIsolation(Isolation.total));
      final policy = isolationPolicy();
      expect(await policy.call(governedPulse(), host: host), isFalse);
      expect(await policy.call(someFunction, host: host), isFalse);
      expect(await policy.call(host, host: host), isFalse);
    });
  });
}

int someFunction(int x) => x;
