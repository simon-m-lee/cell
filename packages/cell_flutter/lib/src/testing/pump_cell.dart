// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a bare [CellBuilder] over [cell].
///
/// The wrapper is `MaterialApp(home: Scaffold(body: CellBuilder(...)))`,
/// giving `Text`-based cells the ambient `TextStyle` they need. No
/// [CellScope] is installed; use [CellPumpWithCells.pumpWithCells] when
/// the widget needs scoped cell lookups.
///
/// ## Usage
///
/// ```dart
/// testWidgets('displays cell value', (tester) async {
///   final counter = Cell.state<int>(initial: 0);
///   await tester.pumpCell(
///     cell: counter.cell,
///     builder: (_, v) => Text('value: $v'),
///   );
///   expect(find.text('value: 0'), findsOneWidget);
/// });
/// ```
///
/// ## Hooks
///
/// `pumpCell` only renders a `CellBuilder`. For a hook-based widget that
/// needs the ambient `MaterialApp` + `Scaffold` frame, use
/// `pumpWidget(MaterialApp(home: Scaffold(body: HookBuilder(...))))`
/// directly — Phase 4's hooks work fine inside that frame.
extension CellPumpCell on WidgetTester {
  Future<void> pumpCell<V>({
    required ValueCell<V> cell,
    required Widget Function(BuildContext context, V? value) builder,
  }) {
    return pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellBuilder<V>(cell: cell, builder: builder),
      ),
    ));
  }
}
