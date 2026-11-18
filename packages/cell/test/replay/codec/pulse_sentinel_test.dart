// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  group('override sentinels', () {
    test('each sentinel is a const singleton (identical to itself)', () {
      expect(identical(pulseNullPolicy, pulseNullPolicy), isTrue);
      expect(identical(pulseNullPayload, pulseNullPayload), isTrue);
      expect(identical(pulseNullType, pulseNullType), isTrue);
      expect(identical(pulseNullSource, pulseNullSource), isTrue);
      expect(identical(pulseNullStep, pulseNullStep), isTrue);
    });

    test('the five sentinels are distinct from each other', () {
      final sentinels = [
        pulseNullPolicy,
        pulseNullPayload,
        pulseNullType,
        pulseNullSource,
        pulseNullStep,
      ];
      for (var i = 0; i < sentinels.length; i++) {
        for (var j = i + 1; j < sentinels.length; j++) {
          expect(
            identical(sentinels[i], sentinels[j]),
            isFalse,
            reason: 'sentinels $i and $j must differ',
          );
        }
      }
    });

    test('identity is the only way to use a sentinel — lookalikes override',
        () {
      // A user object (e.g., a real Cell for the source slot) is an
      // override, never a sentinel: the sentinels compare by identity.
      final cell = Cell.ingress<int>().cell;
      final json = Pulse<int>(1, source: cell).toJson();
      final decoded = Pulse.fromJson(
        json,
        resolver: (_) => cell,
        source: cell, // a real Cell — an override, not a sentinel
      );
      expect(decoded.source, same(cell));
    });

    test('the sentinels document their slots', () {
      expect(pulseNullPolicy.toString(), isNot(contains('Cell')));
      expect(pulseNullSource.toString(), isNot(contains('Policy')));
    });
  });
}
