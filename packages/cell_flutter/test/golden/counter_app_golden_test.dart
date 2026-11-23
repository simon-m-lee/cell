// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Golden files are generated on macOS (`flutter test --update-goldens`).
  // Text rendering differs per platform, so the comparison itself is
  // macOS-only; the widget behaviour covered here is already exercised by
  // the platform-independent widget tests in `cell_builder_test.dart`.
  testWidgets('counter app golden', (tester) async {
    final counter = Cell.state<int>(initial: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Mitosis Counter')),
          body: Center(
            child: CellBuilder<int>(
              cell: counter.cell.unmodifiable,
              builder: (_, value) =>
                  Text('${value ?? 0}', style: const TextStyle(fontSize: 48)),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('counter_app_initial.png'),
    );

    counter.update(5);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('counter_app_updated.png'),
    );
  }, skip: !Platform.isMacOS);
}
