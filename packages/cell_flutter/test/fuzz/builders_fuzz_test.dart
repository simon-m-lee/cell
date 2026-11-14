// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz: CellBuilder over random cell types and update sequences.
// Assertion: no exception, and the rendered text always matches the
// cell's current value.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('CellBuilder fuzz', (tester) async {
    final values = <Object?>[null, 0, 42, 'text', -7];
    final cell = Cell.state<Object?>(initial: 0);
    var expected = '${cell.cell.value}';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellBuilder<Object?>(
          cell: cell.cell,
          builder: (_, v) => Text('$v'),
        ),
      ),
    ));

    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        final next = values[random.nextInt(values.length)];
        cell.update(next);
        expected = '$next';
        await tester.pump();
        final rendered = find.text(expected);
        // The current frame may lag one pulse only under a mid-frame
        // update; after the harness pump the builder must match.
        if (rendered.evaluate().isEmpty) {
          fail('CellBuilder fuzz: expected "$expected" after update');
        }
      },
    );
  });
}
