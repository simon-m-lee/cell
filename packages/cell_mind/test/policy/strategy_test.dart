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

  group('strategyPolicy', () {
    test('accepts strategies in the allowed set', () async {
      final policy = strategyPolicy({
        ReasoningStrategy.deterministic,
        ReasoningStrategy.formal,
      });
      expect(
        await policy.call(
          governedPulse(strategy: ReasoningStrategy.deterministic),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(strategy: ReasoningStrategy.formal),
          host: host,
        ),
        isTrue,
      );
    });

    test('rejects strategies outside the allowed set', () async {
      final policy = strategyPolicy({ReasoningStrategy.deterministic});
      expect(
        await policy.call(
          governedPulse(strategy: ReasoningStrategy.probabilistic),
          host: host,
        ),
        isFalse,
      );
    });

    test('rejects missing strategy by default (fail-closed)', () async {
      final policy = strategyPolicy({ReasoningStrategy.deterministic});
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('accepts missing strategy with allowMissing: true', () async {
      final policy = strategyPolicy(
        {ReasoningStrategy.deterministic},
        allowMissing: true,
      );
      expect(await policy.call(governedPulse(), host: host), isTrue);
    });

    test('passes non-pulse objects through', () async {
      final policy = strategyPolicy({ReasoningStrategy.deterministic});
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
