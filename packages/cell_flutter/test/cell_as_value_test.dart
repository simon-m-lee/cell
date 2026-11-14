// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cell.asValueCell', () {
    test('mirror emits the same values as the source', () {
      final src = Cell.ingress<int>();
      final mirror = src.cell.asValueCell<int>();

      expect(mirror.cell.value, isNull);

      src.emit(1);
      src.emit(2);

      expect(mirror.cell.value, 2);
      mirror.dispose();
    });

    test('initial seeds the first value', () {
      final src = Cell.ingress<int>();
      final mirror = src.cell.asValueCell<int>(initial: 7);

      expect(mirror.cell.value, 7);

      src.emit(9);
      expect(mirror.cell.value, 9);
      mirror.dispose();
    });

    test('dispose stops mirroring', () {
      final src = Cell.ingress<int>();
      final mirror = src.cell.asValueCell<int>();

      src.emit(1);
      mirror.dispose();

      src.emit(2);
      expect(mirror.cell.value, 1);
    });

    test('nullable V emits null', () {
      final src = Cell.ingress<int?>();
      final mirror = src.cell.asValueCell<int?>(initial: 5);

      src.emit(null);
      expect(mirror.cell.value, isNull);
      mirror.dispose();
    });

    test('error pulses are skipped', () async {
      final src = Cell.ingress<Object>();
      final mirror = src.cell.asValueCell<Object>(initial: 'seed');

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));

      expect(mirror.cell.value, 'seed');
      mirror.dispose();
    });

    test('dispose is idempotent', () {
      final src = Cell.ingress<int>();
      final mirror = src.cell.asValueCell<int>();

      mirror.dispose();
      expect(mirror.dispose, returnsNormally);
    });
  });
}
