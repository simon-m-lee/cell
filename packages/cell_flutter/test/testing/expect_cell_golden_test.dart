// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The committed goldens were generated on Windows with
  // `flutter test --update-goldens test/testing/expect_cell_golden_test.dart`.
  // Text rendering differs per platform, so the comparison runs only where
  // the reference images were produced; regenerate on another platform
  // before enabling the comparison there.
  group('expectCellGolden', () {
    testWidgets('golden with text', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.expectCellGolden(
        cell: counter.cell,
        builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
        name: 'counter_initial',
      );
    }, skip: !Platform.isWindows);

    testWidgets('golden with registration in CellScope', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.expectCellGolden(
        cell: counter.cell,
        builder: (_, v) => Text('$v'),
        name: 'counter_scoped',
        cells: {#counter: counter.cell},
      );
    }, skip: !Platform.isWindows);

    testWidgets(
      'two-golden workflow: mutate the cell directly between captures',
      (tester) async {
        // Locks in the documented example: every expectCellGolden call
        // pumps a fresh tree, so the value is driven by a direct cell
        // mutation — pumping the old tree in between accomplishes nothing.
        final counter = Cell.state<int>(initial: 0);
        await tester.expectCellGolden(
          cell: counter.cell,
          builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
          name: 'two_golden_zero',
        );

        counter.update(5);
        await tester.expectCellGolden(
          cell: counter.cell,
          builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
          name: 'two_golden_five',
        );
      },
      skip: !Platform.isWindows,
    );
  });
}
