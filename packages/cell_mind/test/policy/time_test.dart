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

  group('notOlderThan', () {
    test('accepts a fresh pulse within the window', () async {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp.add(Duration(minutes: 3)),
      );
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects a pulse older than the window', () async {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp.add(Duration(minutes: 10)),
      );
      expect(await policy.call(pulse, host: host), isFalse);
    });

    test('accepts a pulse exactly at the window edge', () async {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp.add(Duration(minutes: 5)),
      );
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test("accepts future timestamps (clock skew is not the pulse's fault)",
        () async {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp.subtract(Duration(minutes: 1)),
      );
      expect(await policy.call(pulse, host: host), isTrue);
    });

    test('rejects a negative window at construction', () {
      expect(
        () => notOlderThan(
          Duration(minutes: -1),
          clock: () => DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('passes non-pulse objects through', () async {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp,
      );
      expect(await policy.call(someFunction, host: host), isTrue);
    });

    test('declares readOnlyExternal purity and a stable version', () {
      final pulse = governedPulse();
      final policy = notOlderThan(
        Duration(minutes: 5),
        clock: () => pulse.timestamp,
      );
      expect(policy.purity, Purity.readOnlyExternal);
      expect(policy.version, '1.0.0');
    });
  });
}

int someFunction(int x) => x;
