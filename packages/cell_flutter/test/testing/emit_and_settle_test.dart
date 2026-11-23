// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emitAndSettle', () {
    testWidgets('updates cell and settles', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
      await tester.emitAndSettle(counter.cell, 5);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('settles nested rebuilds', (tester) async {
      final a = Cell.state<int>(initial: 0);
      final b = Cell.state<int>(initial: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CellBuilder<int>(
                  cell: a.cell,
                  builder: (_, v) => Text('A: $v'),
                ),
                CellBuilder<int>(
                  cell: b.cell,
                  builder: (_, v) => Text('B: $v'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.emitAndSettle(a.cell, 1);
      await tester.emitAndSettle(b.cell, 2);
      expect(find.text('A: 1'), findsOneWidget);
      expect(find.text('B: 2'), findsOneWidget);
    });

    testWidgets('null value', (tester) async {
      final cell = Cell.state<int?>(initial: 42);
      await tester.pumpCell(
        cell: cell.cell,
        builder: (_, v) => Text(v == null ? 'none' : '$v'),
      );
      await tester.emitAndSettle(cell.cell, null);
      expect(find.text('none'), findsOneWidget);
    });
  });

  group('emitAndPump', () {
    testWidgets('pumps a single frame', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
      await tester.emitAndPump(counter.cell, 5);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('pumps a duration', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
      await tester.emitAndPump(
        counter.cell,
        5,
        duration: const Duration(milliseconds: 100),
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does not wait for settle', (tester) async {
      // A widget that keeps rebuilding: pumpAndSettle would never settle,
      // but emitAndPump returns after one frame.
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellBuilder<int>(
              cell: counter.cell,
              builder: (_, v) => const CircularProgressIndicator(),
            ),
          ),
        ),
      );
      await tester.emitAndPump(counter.cell, 5);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Stop the animation so the test tears down cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
