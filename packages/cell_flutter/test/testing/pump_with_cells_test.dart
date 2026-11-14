// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pumpWithCells', () {
    testWidgets('registers cells in CellScope', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      await tester.pumpWithCells(
        cells: {#counter: counter.cell},
        child: Builder(builder: (ctx) {
          final c = CellScope.valueOf<int>(ctx, #counter);
          return Text('${c.value}');
        }),
      );
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('default wrapper provides MaterialApp + Scaffold',
        (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpWithCells(
        cells: {#counter: counter.cell},
        child: CellBuilder<int>(
          cell: counter.cell,
          builder: (_, v) => Text('$v'),
        ),
      );
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('custom wrapper overrides default', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpWithCells(
        cells: {#counter: counter.cell},
        wrapper: (child) => MaterialApp(
          navigatorKey: navKey,
          home: child,
        ),
        child: const Text('custom'),
      );
      expect(navKey.currentState, isNotNull);
      expect(find.text('custom'), findsOneWidget);
    });

    testWidgets('multiple cells registered', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<String>(initial: 'hello');
      await tester.pumpWithCells(
        cells: {#a: a.cell, #b: b.cell},
        child: Builder(builder: (ctx) {
          final av = CellScope.valueOf<int>(ctx, #a);
          final bv = CellScope.valueOf<String>(ctx, #b);
          return Text('${av.value},${bv.value}');
        }),
      );
      expect(find.text('1,hello'), findsOneWidget);
    });

    testWidgets('unregistered id throws', (tester) async {
      final a = Cell.state<int>(initial: 0);
      await tester.pumpWithCells(
        cells: {#a: a.cell},
        child: Builder(builder: (ctx) {
          expect(
            () => CellScope.valueOf<int>(ctx, #missing),
            throwsAssertionError,
          );
          return const SizedBox.shrink();
        }),
      );
    });
  });
}
