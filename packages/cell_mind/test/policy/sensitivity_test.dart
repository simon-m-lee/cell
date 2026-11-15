// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  Cell hostWithConstraints(Map<String, dynamic> constraints) =>
      Cell.ingress<int>(context: ctxWithConstraints(constraints)).cell;

  group('sensitivityPolicy', () {
    test('accepts pulses at or below the declared max', () async {
      final host = hostWithConstraints({'max_sensitivity': 'confidential'});
      final policy = sensitivityPolicy();
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.confidential),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.public),
          host: host,
        ),
        isTrue,
      );
    });

    test('rejects pulses above the declared max', () async {
      final host = hostWithConstraints({'max_sensitivity': 'confidential'});
      final policy = sensitivityPolicy();
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.secret),
          host: host,
        ),
        isFalse,
      );
    });

    test('rejects pulses with no sensitivity declaration (fail-closed)',
        () async {
      final host = hostWithConstraints({'max_sensitivity': 'confidential'});
      final policy = sensitivityPolicy();
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('falls back to public when no max is declared', () async {
      final host = hostWithConstraints({});
      final policy = sensitivityPolicy();
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.public),
          host: host,
        ),
        isTrue,
      );
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.internal),
          host: host,
        ),
        isFalse,
      );
    });

    test('defaultMax overrides the context declaration', () async {
      final host = hostWithConstraints({'max_sensitivity': 'secret'});
      final policy = sensitivityPolicy(defaultMax: Sensitivity.private);
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.confidential),
          host: host,
        ),
        isFalse,
      );
      expect(
        await policy.call(
          governedPulse(sensitivity: Sensitivity.private),
          host: host,
        ),
        isTrue,
      );
    });

    test('passes non-pulse objects through', () async {
      final host = hostWithConstraints({'max_sensitivity': 'confidential'});
      final policy = sensitivityPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
