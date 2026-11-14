// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz: CellScope with random nesting depths and symbol collisions.
// Assertions: no uncaught exception; shadow warnings are recorded once
// per shadowed symbol; lookups resolve to the nearest scope.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('CellScope fuzz', (tester) async {
    CellScope.shadowWarned.clear();
    final inner = Cell.state<int>(initial: 1);
    final outer = Cell.state<int>(initial: 2);

    await tester.pumpWidget(MaterialApp(
      home: CellScope(
        cells: {#value: outer.cell},
        child: CellScope(
          cells: {#value: inner.cell},
          child: Builder(builder: (context) {
            // The documented pattern: look the cell up through the scope,
            // then observe it with a CellBuilder.
            final cell = CellScope.valueOf<int>(context, #value);
            return CellBuilder<int>(
              cell: cell,
              builder: (_, v) => Text('${v ?? -1}'),
            );
          }),
        ),
      ),
    ));

    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        inner.update(iteration);
        outer.update(iteration * 2);
        await tester.pump();
        await tester.pump();
        expect(find.text('$iteration'), findsOneWidget,
            reason: 'nearest scope must win');
      },
    );

    // The shadow warning must be recorded exactly once per symbol.
    expect(CellScope.shadowWarned, contains(#value));
    expect(CellScope.shadowWarned.where((s) => s == #value), hasLength(1));
  });
}
