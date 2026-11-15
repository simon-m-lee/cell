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

  group('auditLevelPolicy', () {
    test('accepts audit levels at or above the minimum', () async {
      final policy = auditLevelPolicy(min: AuditLevel.standard);
      expect(
        await policy.call(
          governedPulse(auditLevel: AuditLevel.standard),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(auditLevel: AuditLevel.full),
          host: host,
        ),
        isTrue,
      );
    });

    test('rejects audit levels below the minimum', () async {
      final policy = auditLevelPolicy(min: AuditLevel.standard);
      expect(
        await policy.call(
          governedPulse(auditLevel: AuditLevel.minimal),
          host: host,
        ),
        isFalse,
      );
      expect(
        await policy.call(
          governedPulse(auditLevel: AuditLevel.none),
          host: host,
        ),
        isFalse,
      );
    });

    test('rejects missing audit level (fail-closed)', () async {
      final policy = auditLevelPolicy();
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('passes non-pulse objects through', () async {
      final policy = auditLevelPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
