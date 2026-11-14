// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_with_cells.dart';

/// Captures a golden of [cell]'s widget at the current value.
///
/// ## Usage
///
/// ```dart
/// testWidgets('counter golden', (tester) async {
///   final counter = Cell.state<int>(initial: 0);
///   await tester.expectCellGolden(
///     cell: counter.cell,
///     builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
///     name: 'counter_zero',
///   );
///
///   await tester.emitAndSettle(counter.cell, 5);
///   await tester.expectCellGolden(
///     cell: counter.cell,
///     builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
///     name: 'counter_five',
///   );
/// });
/// ```
///
/// ## Generating goldens
///
/// Run with `flutter test --update-goldens` on the reference platform
/// (typically macOS for iOS-shaped goldens; add per-platform overrides for
/// cross-platform precision).
///
/// ## Known limitation: text rendering
///
/// Flutter's default test font renders text as black boxes unless
/// `golden_toolkit`'s `loadAppFonts` is called in `setUpAll`. This
/// utility does not load fonts (that's a suite-level concern). Add:
///
/// ```dart
/// setUpAll(() async {
///   await loadAppFonts(); // from package:golden_toolkit
/// });
/// ```
///
/// `golden_toolkit` is a dev_dependency of the test suite, not of
/// `cell_flutter`.
extension CellExpectGolden on WidgetTester {
  Future<void> expectCellGolden<V>({
    required ValueCell<V> cell,
    required Widget Function(BuildContext context, V? value) builder,
    required String name,
    Map<Symbol, Cell> cells = const {},
    String? goldenPath,
  }) async {
    final widget = CellBuilder<V>(cell: cell, builder: builder);
    if (cells.isNotEmpty) {
      await pumpWithCells(
        cells: cells,
        wrapper: (child) => MaterialApp(home: Scaffold(body: child)),
        child: widget,
      );
    } else {
      await pumpWidget(
        MaterialApp(home: Scaffold(body: widget)),
      );
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(goldenPath ?? 'goldens/$name.png'),
    );
  }
}
