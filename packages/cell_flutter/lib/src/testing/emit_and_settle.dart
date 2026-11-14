// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets [cell]'s value to [value], then pumps until the widget tree settles.
///
/// The common assertion pattern: emit, let the graph and widgets catch up,
/// then assert.
///
/// ## Sync vs async receptors
///
/// - **Sync receptors**: `cell.value = value` runs the pulse through the
///   graph synchronously. `pumpAndSettle` handles scheduled rebuilds.
/// - **Async receptors resolving on a microtask**: `pumpAndSettle` drains
///   microtasks between frames, so this works.
/// - **Async receptors resolving on a timer** (e.g., `Future.delayed`):
///   `pumpAndSettle` does not wait for timers. Use
///   `await tester.pump(duration)` after `emitAndSettle`, or use
///   `emitAndPump(cell, value, duration: ...)`.
///
/// ## Usage
///
/// ```dart
/// await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
/// await tester.emitAndSettle(counter.cell, 5);
/// expect(find.text('5'), findsOneWidget);
/// ```
extension CellEmitAndSettle on WidgetTester {
  Future<void> emitAndSettle<V>(ValueCell<V> cell, V? value) async {
    cell.value = value;
    await pumpAndSettle();
  }

  /// Sets [cell]'s value and pumps a single frame (or [duration], if
  /// provided). Does not wait for settle.
  ///
  /// Use when the test needs to observe an intermediate state — e.g.,
  /// a loading spinner — before the widget settles, or when the receptor
  /// resolves on a timer that `pumpAndSettle` would not wait for.
  ///
  /// ```dart
  /// final query = Cell.state<String>(initial: '');
  /// await tester.pumpWidget(...);
  /// await tester.emitAndPump(query.cell, 'dart');
  /// expect(find.byType(Spinner), findsOneWidget);
  /// await tester.pump(const Duration(seconds: 1));
  /// expect(find.byType(ResultsList), findsOneWidget);
  /// ```
  Future<void> emitAndPump<V>(
    ValueCell<V> cell,
    V? value, {
    Duration? duration,
  }) {
    cell.value = value;
    return duration == null ? pump() : pump(duration);
  }
}
