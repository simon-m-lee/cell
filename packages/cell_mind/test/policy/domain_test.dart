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

  group('domainPolicy', () {
    test('accepts when pulse domains are within host domains', () async {
      final host = hostWith(ctxWithDomains('finance,audit'));
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'finance');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('accepts multi-domain origins fully covered by the host', () async {
      final host = hostWith(ctxWithDomains('finance,audit'));
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'finance,audit');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects when domains are disjoint', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'marketing');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects when any origin domain escapes the host', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'finance,hr');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('accepts everything when the acceptor is untagged', () async {
      final host = hostWith(Context.system);
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'marketing');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects untagged pulses by default (fail-closed)', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      final pulse = governedPulse();
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('accepts untagged pulses with allowUntagged: true', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy(allowUntagged: true);
      final pulse = governedPulse();
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('accepts additionalDomains beyond the host declaration', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy(additionalDomains: {'hr'});
      final pulse = governedPulse(domains: 'hr');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('resolves origin from the source cell when pulse is untagged',
        () async {
      final source = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      final pulse = governedPulse(source: source.cell);
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('throws StateError on provenance mismatch', () async {
      final source = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      final pulse = governedPulse(domains: 'hr', source: source.cell);
      await expectLater(
        Future<void>.sync(() => policy.call(pulse, host: host)),
        throwsStateError,
      );
    });

    test('passes non-pulse objects through', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = domainPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
      expect(await policy.call(host, host: host), isTrue);
    });
  });

  group('requiresDomainPolicy', () {
    test('accepts when both acceptor and pulse declare domains', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = requiresDomainPolicy();
      final pulse = governedPulse(domains: 'finance');
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects when the acceptor is untagged', () async {
      final host = hostWith(Context.system);
      final policy = requiresDomainPolicy();
      final pulse = governedPulse(domains: 'finance');
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('rejects when the pulse is untagged', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = requiresDomainPolicy();
      final pulse = governedPulse();
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('accepts a pulse claim carried by the source cell', () async {
      final source = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final host = hostWith(ctxWithDomains('finance'));
      final policy = requiresDomainPolicy();
      final pulse = governedPulse(source: source.cell);
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('passes non-pulse objects through', () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = requiresDomainPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });

  group('domain composition', () {
    test('requiresDomainPolicy + domainPolicy governs tagged traffic',
        () async {
      final host = hostWith(ctxWithDomains('finance'));
      final policy = requiresDomainPolicy() + domainPolicy();
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
      );
    });
  });
}

int someFunction(int x) => x;
