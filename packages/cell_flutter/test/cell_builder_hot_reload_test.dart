// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures `debugPrint` output for the duration of [body] and restores
/// the original hook before the test body returns — the binding verifies
/// foundation debug variables are restored before package:test tearDowns
/// run.
Future<void> captureDebugPrint(
  Future<void> Function(List<String> logs) body,
) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (msg, {wrapWidth}) => logs.add(msg ?? '');
  try {
    await body(logs);
  } finally {
    debugPrint = original;
  }
}

void main() {
  group('CellBuilder hot-reload warning', () {
    testWidgets('warns after 3 consecutive cell swaps', (tester) async {
      await captureDebugPrint((logs) async {
        for (var i = 0; i < 5; i++) {
          final fresh = Cell.state<int>(initial: i);
          await tester.pumpWidget(
            MaterialApp(
              home: CellBuilder<int>(
                cell: fresh.cell,
                builder: (_, v) => Text('$v'),
              ),
            ),
          );
        }
        expect(
          logs.any((l) => l.contains('the cell identity changed')),
          isTrue,
        );
      });
    });

    testWidgets('does not warn on same cell rebuild', (tester) async {
      await captureDebugPrint((logs) async {
        final counter = Cell.state<int>(initial: 0);
        for (var i = 0; i < 5; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: CellBuilder<int>(
                cell: counter.cell,
                builder: (_, v) => Text('$v'),
              ),
            ),
          );
        }
        expect(logs, isEmpty);
      });
    });

    testWidgets('counter resets on non-swap', (tester) async {
      await captureDebugPrint((logs) async {
        final a = Cell.state<int>(initial: 0);
        final b = Cell.state<int>(initial: 1);
        Future<void> pump(ValueCell<int> cell) => tester.pumpWidget(
          MaterialApp(
            home: CellBuilder<int>(
              cell: cell,
              builder: (context, value) => const SizedBox(),
            ),
          ),
        );
        await pump(a.cell);
        await pump(b.cell);
        await pump(b.cell);
        await pump(a.cell);
        await pump(b.cell);
        expect(logs, isEmpty);
      });
    });
  });
}
