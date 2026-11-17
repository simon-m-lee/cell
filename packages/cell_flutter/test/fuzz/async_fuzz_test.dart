// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz: CellAsyncBuilder with rapid pulse storms and cell swaps.
// Assertion: no crash; after the storm drains, the final snapshot
// matches the last emitted value.
//
// Caveat (documented in the CellAsyncBuilder dartdoc): the widget
// observes `asyncMap` correctly; the tracked-separately
// caveat concerns the source's replay fidelity, not the widget.

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('CellAsyncBuilder asyncMap storm', (tester) async {
    final query = Cell.state<String>(initial: 'a');
    final results = Cell.asyncMap<String, String>(
      query.cell,
      (q, {required EffectJournal journal}) async => 'result for $q',
      latestOnly: true,
      journal: RecordingJournal(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellAsyncBuilder<String>(
          cell: results,
          builder: (_, snapshot) =>
              Text(snapshot.hasData ? '${snapshot.data}' : 'loading'),
        ),
      ),
    ));

    var last = 'a';
    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        // Pulse storm: 1..8 updates within this iteration.
        final burst = 1 + random.nextInt(8);
        for (var i = 0; i < burst; i++) {
          last = 'q$iteration-$i';
          query.update(last);
        }
        // Drain the asyncMap timers and settle the widget.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('result for $last'), findsOneWidget,
            reason: 'final snapshot must match the last pulse');
      },
    );
  });

  testWidgets('CellAsyncBuilder fromFuture cell swaps', (tester) async {
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Text('waiting $builds')),
    ));

    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        final completer = Completer<int>();
        final cell =
            Cell.fromFuture<int>(completer.future, journal: RecordingJournal());
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CellAsyncBuilder<int>(
              cell: cell,
              builder: (_, snapshot) {
                builds++;
                return Text(
                  snapshot.hasData ? 'v${snapshot.data}' : 'loading',
                );
              },
            ),
          ),
        ));
        completer.complete(iteration);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('v$iteration'), findsOneWidget,
            reason: 'swapped fromFuture must render its value');
      },
    );
  });
}
