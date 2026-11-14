// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz: CellSelector with random slices and equality functions.
// Assertion: rebuild only when the selected slice changes.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('CellSelector fuzz', (tester) async {
    final cell = Cell.state<List<int>>(initial: const [1, 2, 3]);
    var builds = 0;
    var lastSlice = 1 + 2 + 3;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellSelector<List<int>, int>(
          cell: cell.cell,
          select: (list) => (list ?? const []).fold(0, (a, b) => a + b),
          builder: (context, slice) {
            builds++;
            lastSlice = slice;
            return Text('sum:$slice');
          },
        ),
      ),
    ));

    var baselineBuilds = builds;

    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        // Update with the same sum but different elements: the slice is
        // unchanged, so the selector must NOT rebuild.
        final a = random.nextInt(100);
        final b = random.nextInt(100);
        cell.update([a, b, lastSlice - a - b]);
        await tester.pump();
        expect(builds, baselineBuilds,
            reason: 'selector rebuilt although the slice did not change');
        expect(find.text('sum:$lastSlice'), findsOneWidget);

        // Now change the sum: exactly one rebuild per slice change.
        final delta = 1 + random.nextInt(10);
        lastSlice += delta;
        cell.update([a + delta, b, lastSlice - a - b - delta]);
        await tester.pump();
        expect(builds, baselineBuilds + 1,
            reason: 'selector must rebuild exactly once per slice change');
        baselineBuilds += 1;
        expect(find.text('sum:$lastSlice'), findsOneWidget);
      },
    );
  });
}
