// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Feature goldens. Committed on Windows (the reference platform
// for this suite); the comparison skips elsewhere, matching the existing
// golden policy in test/testing/.

import 'dart:io';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('feature goldens', () {
    testWidgets(
      'CellTextField empty',
      (tester) async {
        final cell = Cell.state<String>(initial: '');
        await tester.pumpWidget(_wrap(
          CellTextField(
            cell: cell.cell,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cell_text_field_empty.png'),
        );
      },
      skip: !Platform.isWindows,
    );

    testWidgets(
      'CellTextField filled',
      (tester) async {
        final cell = Cell.state<String>(initial: 'user@example.com');
        await tester.pumpWidget(_wrap(
          CellTextField(
            cell: cell.cell,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cell_text_field_filled.png'),
        );
      },
      skip: !Platform.isWindows,
    );

    testWidgets(
      'CellErrorBoundary fallback',
      (tester) async {
        final policy = EphemeralPolicy<Cell>(
          eventLimit: 1,
          onEvent: (object,
                  {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (nucleus) => true,
        );
        final head = Cell.governed(
          ephemeralPolicy: policy,
          context: Context.system,
        );
        policy('use', cell: head);
        final cell = ValueCell<int>(initial: 0, bind: head);

        await tester.pumpWidget(_wrap(
          CellErrorBoundary(
            onError: (error, stack) => const Text('Something broke'),
            child: CellBuilder<int>(cell: cell, builder: (_, v) => Text('$v')),
          ),
        ));
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cell_error_boundary_fallback.png'),
        );
      },
      skip: !Platform.isWindows,
    );

    testWidgets(
      'CellListView filled',
      (tester) async {
        final list = Cell.state<List<String>>(initial: ['alpha', 'beta']);
        await tester.pumpWidget(_wrap(
          CellListView<String>.builder(
            cell: list.cell,
            itemBuilder: (_, item, i) => ListTile(title: Text(item)),
          ),
        ));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cell_list_view_filled.png'),
        );
      },
      skip: !Platform.isWindows,
    );

    testWidgets(
      'CellListView empty',
      (tester) async {
        final list = Cell.state<List<String>>(initial: const []);
        await tester.pumpWidget(_wrap(
          CellListView<String>.builder(
            cell: list.cell,
            itemBuilder: (_, item, i) => ListTile(title: Text(item)),
          ),
        ));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cell_list_view_empty.png'),
        );
      },
      skip: !Platform.isWindows,
    );
  });
}
