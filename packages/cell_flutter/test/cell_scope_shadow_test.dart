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
  group('CellScope nested shadow warning', () {
    testWidgets('warns when symbol shadowed', (tester) async {
      await captureDebugPrint((logs) async {
        CellScope.shadowWarned.clear();
        final outer = Cell.state<int>(initial: 0);
        final inner = Cell.state<int>(initial: 1);
        await tester.pumpWidget(
          MaterialApp(
            home: CellScope(
              cells: {#counter: outer.cell},
              child: CellScope(
                cells: {#counter: inner.cell},
                child: Builder(
                  builder: (ctx) {
                    CellScope.of<int>(ctx, #counter);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        expect(
          logs.any((l) => l.contains('is registered in a nested scope')),
          isTrue,
        );
      });
    });

    testWidgets('does not warn when symbol unique', (tester) async {
      await captureDebugPrint((logs) async {
        CellScope.shadowWarned.clear();
        final a = Cell.state<int>(initial: 0);
        final b = Cell.state<int>(initial: 1);
        await tester.pumpWidget(
          MaterialApp(
            home: CellScope(
              cells: {#a: a.cell},
              child: CellScope(
                cells: {#b: b.cell},
                child: Builder(
                  builder: (ctx) {
                    CellScope.of<int>(ctx, #b);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        expect(logs, isEmpty);
      });
    });

    testWidgets('warns once per symbol', (tester) async {
      await captureDebugPrint((logs) async {
        CellScope.shadowWarned.clear();
        final outer = Cell.state<int>(initial: 0);
        final inner = Cell.state<int>(initial: 1);
        await tester.pumpWidget(
          MaterialApp(
            home: CellScope(
              cells: {#counter: outer.cell},
              child: CellScope(
                cells: {#counter: inner.cell},
                child: Builder(
                  builder: (ctx) {
                    CellScope.of<int>(ctx, #counter);
                    CellScope.of<int>(ctx, #counter);
                    CellScope.of<int>(ctx, #counter);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        final matches = logs.where((l) => l.contains('nested scope')).toList();
        expect(matches, hasLength(1));
      });
    });
  });
}
