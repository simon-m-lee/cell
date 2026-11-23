// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pumpCell', () {
    testWidgets('pumps a CellBuilder', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      await tester.pumpCell(
        cell: counter.cell,
        builder: (_, v) => Text('value: $v'),
      );
      expect(find.text('value: 42'), findsOneWidget);
    });

    testWidgets('rebuilds on cell update', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
      counter.update(5);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('wraps in MaterialApp + Scaffold', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpCell(
        cell: counter.cell,
        builder: (context, value) => const SizedBox.shrink(),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('nullable V', (tester) async {
      final cell = Cell.state<int?>(initial: null);
      await tester.pumpCell(
        cell: cell.cell,
        builder: (_, v) => Text(v == null ? 'none' : '$v'),
      );
      expect(find.text('none'), findsOneWidget);
    });
  });
}
