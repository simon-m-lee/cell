// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget with [cells] pre-registered in a [CellScope].
///
/// Default wrapper: `MaterialApp(home: Scaffold(body: child))`. Override
/// with [wrapper] for custom trees (e.g., a `Navigator` with a key, a
/// theme override).
///
/// ## Usage
///
/// ```dart
/// testWidgets('counter renders', (tester) async {
///   final counter = Cell.state<int>(initial: 42);
///   await tester.pumpWithCells(
///     cells: {#counter: counter.cell},
///     child: CellBuilder<int>(
///       cell: counter.cell,
///       builder: (_, v) => Text('$v'),
///     ),
///   );
///   expect(find.text('42'), findsOneWidget);
/// });
/// ```
///
/// ## Custom wrapper
///
/// ```dart
/// final navKey = GlobalKey<NavigatorState>();
/// await tester.pumpWithCells(
///   cells: {#auth: auth.cell},
///   wrapper: (child) => MaterialApp(
///     navigatorKey: navKey,
///     home: child,
///   ),
///   child: const LoginScreen(),
/// );
/// ```
extension CellPumpWithCells on WidgetTester {
  Future<void> pumpWithCells({
    required Map<Symbol, Cell> cells,
    required Widget child,
    Widget Function(Widget child)? wrapper,
  }) {
    final wrapped = wrapper != null
        ? wrapper(child)
        : MaterialApp(home: Scaffold(body: child));
    return pumpWidget(CellScope(cells: cells, child: wrapped));
  }
}
