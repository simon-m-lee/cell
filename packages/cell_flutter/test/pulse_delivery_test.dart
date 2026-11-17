// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter/src/pulse_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seedFromRetained', () {
    test('falls back to initial for a plain cell', () {
      final src = Cell.ingress<int>();
      expect(seedFromRetained<int>(src.cell, 5), 5);
    });

    test('serves a ValueCell current value', () {
      final counter = Cell.state<int>(initial: 7);
      expect(seedFromRetained<int>(counter.cell, 5), 7);
    });

    test('falls back to initial for a mismatched retained payload', () {
      final name = Cell.state<String>(initial: 'alice');
      expect(seedFromRetained<int>(name.cell, 5), 5);
    });

    test('accepts a null retained payload for a nullable V', () {
      final cell = Cell.state<int?>(initial: null);
      expect(seedFromRetained<int?>(cell.cell, 5), isNull);
    });
  });

  group('isCollectionLike', () {
    test('reports Map and Iterable, not String or scalars', () {
      expect(isCollectionLike(const {}), isTrue);
      expect(isCollectionLike([1]), isTrue);
      expect(isCollectionLike('text'), isFalse);
      expect(isCollectionLike(3), isFalse);
      expect(isCollectionLike(null), isFalse);
    });
  });
}
