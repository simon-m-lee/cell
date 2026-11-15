// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  final host = Cell.ingress<int>().cell;

  group('actorPolicy', () {
    test('accepts allowlisted actors', () async {
      final policy = actorPolicy({'auditor', 'admin'});
      expect(
        await policy.call(governedPulse(actor: 'auditor'), host: host),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(actor: 'admin'), host: host),
        isTrue,
      );
    });

    test('rejects actors outside the allowlist', () async {
      final policy = actorPolicy({'auditor'});
      expect(
        await policy.call(governedPulse(actor: 'intruder'), host: host),
        isFalse,
      );
    });

    test('rejects missing actor by default (fail-closed)', () async {
      final policy = actorPolicy({'auditor'});
      expect(
        await policy.call(
          Pulse<int>.governed(
            payload: 0,
            context: PulseContext.fromEntries([
              Provenance.reason.entry('r'),
              Provenance.traceId.entry(Identity.next()),
            ]),
          ),
          host: host,
        ),
        isFalse,
      );
    });

    test('accepts missing actor with allowMissing: true', () async {
      final policy = actorPolicy({'auditor'}, allowMissing: true);
      expect(
        await policy.call(
          Pulse<int>.governed(
            payload: 0,
            context: PulseContext.fromEntries([
              Provenance.reason.entry('r'),
              Provenance.traceId.entry(Identity.next()),
            ]),
          ),
          host: host,
        ),
        isTrue,
      );
    });

    test('passes non-pulse objects through', () async {
      final policy = actorPolicy({'auditor'});
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });

  group('purposePolicy', () {
    test('accepts allowlisted purposes', () async {
      final policy = purposePolicy({'TRANSACTION_COMMIT'});
      expect(
        await policy.call(
          governedPulse(purpose: 'TRANSACTION_COMMIT'),
          host: host,
        ),
        isTrue,
      );
    });

    test('rejects purposes outside the allowlist', () async {
      final policy = purposePolicy({'TRANSACTION_COMMIT'});
      expect(
        await policy.call(governedPulse(purpose: 'SYSTEM_MAINTENANCE'),
            host: host),
        isFalse,
      );
    });

    test('rejects missing purpose by default (fail-closed)', () async {
      final policy = purposePolicy({'TRANSACTION_COMMIT'});
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('accepts missing purpose with allowMissing: true', () async {
      final policy = purposePolicy(
        {'TRANSACTION_COMMIT'},
        allowMissing: true,
      );
      expect(await policy.call(governedPulse(), host: host), isTrue);
    });

    test('passes non-pulse objects through', () async {
      final policy = purposePolicy({'TRANSACTION_COMMIT'});
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });

  group('actor × purpose composition', () {
    test('both allowlists must agree', () async {
      final policy =
          actorPolicy({'auditor'}) + purposePolicy({'TRANSACTION_COMMIT'});
      expect(
        await policy.call(
          governedPulse(actor: 'auditor', purpose: 'TRANSACTION_COMMIT'),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(actor: 'admin', purpose: 'TRANSACTION_COMMIT'),
          host: host,
        ),
        isFalse,
      );
      expect(
        await policy.call(
          governedPulse(actor: 'auditor', purpose: 'OTHER'),
          host: host,
        ),
        isFalse,
      );
    });
  });
}

int someFunction(int x) => x;
