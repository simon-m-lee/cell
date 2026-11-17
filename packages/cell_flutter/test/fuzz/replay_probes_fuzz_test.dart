// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz for the replay-verified scenarios: debounce bursts,
// throttle rate, `fromFuture` and `fromStream` snapshot sequences.
// These are the operators whose replay round-trip commit `05b4895d`
// fixed; a regression here must block the 1.0 gate.

import 'dart:async';

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('debounce fuzz: at most one emission per settled burst',
      (tester) async {
    final source = Cell.state<int>(initial: 0);
    final debounced = Cell.debounce(
        source.cell, const Duration(milliseconds: 50),
        journal: RecordingJournal());

    await tester.pumpWidget(const SizedBox.shrink());
    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        final recorder = debounced.recordPulses();
        final burst = 1 + random.nextInt(10);
        for (var i = 0; i < burst; i++) {
          source.update(i);
          await tester.pump(const Duration(milliseconds: 1));
        }
        // Let the trailing debounce timer fire.
        await tester.pump(const Duration(milliseconds: 200));
        expect(recorder.payloads.length, lessThanOrEqualTo(1),
            reason: 'a burst must collapse to at most one pulse');
        recorder.stop();
      },
    );
  });

  testWidgets('throttle fuzz: emission rate respects the window',
      (tester) async {
    final source = Cell.state<int>(initial: 0);
    final throttled = Cell.throttle(
        source.cell, const Duration(milliseconds: 50),
        journal: RecordingJournal());

    await tester.pumpWidget(const SizedBox.shrink());
    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        final recorder = throttled.recordPulses();
        final burst = 2 + random.nextInt(8);
        for (var i = 0; i < burst; i++) {
          source.update(i);
          await tester.pump(const Duration(milliseconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 200));
        // With leading enabled, at most one pulse can be emitted per
        // 50ms window; a 200ms drain allows at most 5.
        expect(recorder.payloads.length, lessThanOrEqualTo(5),
            reason: 'throttle must respect its window');
        recorder.stop();
      },
    );
  });

  testWidgets('fromFuture / fromStream fuzz: well-formed snapshots',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      iterate: (tester, random, iteration) async {
        final value = random.nextInt(1000);
        final completer = Completer<int>();
        final futureCell =
            Cell.fromFuture<int>(completer.future, journal: RecordingJournal());
        final streamController = StreamController<int>();
        final streamCell = Cell.fromStream<int>(streamController.stream,
            journal: RecordingJournal());

        var futureText = 'none';
        var streamText = 'none';
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(children: [
              CellAsyncBuilder<int>(
                cell: futureCell,
                builder: (_, snapshot) {
                  if (snapshot.hasData) futureText = '${snapshot.data}';
                  return Text(futureText);
                },
              ),
              CellAsyncBuilder<int>(
                cell: streamCell,
                builder: (_, snapshot) {
                  if (snapshot.hasData) streamText = '${snapshot.data}';
                  return Text(streamText);
                },
              ),
            ]),
          ),
        ));

        completer.complete(value);
        // Deliver stream events one timer tick apart, matching how a
        // live stream paces its events.
        streamController.add(value);
        await tester.pump(const Duration(milliseconds: 50));
        streamController.add(value + 1);
        await tester.pump(const Duration(milliseconds: 100));
        await streamController.close();
        await tester.pumpAndSettle();
        expect(find.text('$value'), findsWidgets,
            reason: 'fromFuture must render its value');
        expect(find.text('${value + 1}'), findsOneWidget,
            reason: 'fromStream must render the last stream value');
      },
    );
  });
}
