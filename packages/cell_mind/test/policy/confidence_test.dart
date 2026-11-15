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

  group('confidencePolicy', () {
    test('accepts confidence at or above the threshold', () async {
      final policy = confidencePolicy(min: 0.85);
      expect(
        await policy.call(governedPulse(confidence: 0.85), host: host),
        isTrue,
      );
      expect(
        await policy.call(governedPulse(confidence: 0.99), host: host),
        isTrue,
      );
    });

    test('rejects confidence below the threshold', () async {
      final policy = confidencePolicy(min: 0.85);
      expect(
        await policy.call(governedPulse(confidence: 0.5), host: host),
        isFalse,
      );
    });

    test('rejects missing confidence by default (fail-closed)', () async {
      final policy = confidencePolicy();
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('accepts missing confidence with allowMissing: true', () async {
      final policy = confidencePolicy(allowMissing: true);
      expect(await policy.call(governedPulse(), host: host), isTrue);
    });

    test('passes non-pulse objects through', () async {
      final policy = confidencePolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
