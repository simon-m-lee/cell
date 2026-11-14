// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellSelector collection warning', () {
    testWidgets('warns on collection without equals', (tester) async {
      final listCell = Cell.state<List<int>>(initial: [1, 2, 3]);
      await tester.pumpWidget(MaterialApp(
        home: CellSelector<List<int>, List<int>>(
          cell: listCell.cell,
          select: (v) => v ?? const [],
          builder: (context, selected) => const SizedBox.shrink(),
        ),
      ));
      // The assert fires during build and is captured by the framework.
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('does not warn with equals', (tester) async {
      final listCell = Cell.state<List<int>>(initial: [1, 2, 3]);
      await tester.pumpWidget(MaterialApp(
        home: CellSelector<List<int>, List<int>>(
          cell: listCell.cell,
          select: (v) => v ?? const [],
          equals: listEquals,
          builder: (context, selected) => const SizedBox.shrink(),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
