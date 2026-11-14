// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Fuzz: CellListener with handlers that throw at random.
// Assertion: no crash; handler errors are reported via the framework's
// exception channel (drained here); the listener keeps receiving.

import 'dart:math';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuzz_harness.dart';

void main() {
  testWidgets('CellListener fuzz', (tester) async {
    final cell = Cell.state<int>(initial: 0);
    var received = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellListener<int>(
          cell: cell.cell,
          onPulse: (context, pulse) {
            received++;
            final random = Random(received * 7919);
            if (random.nextBool()) {
              throw StateError('fuzzed handler error $received');
            }
          },
          child: const SizedBox.shrink(),
        ),
      ),
    ));

    final drained = await runFuzz(
      tester: tester,
      seeds: fuzzSeedsForFile(),
      perSeed: fuzzSecondsPerSeed(),
      discardExceptions: true,
      iterate: (tester, random, iteration) async {
        cell.update(iteration);
      },
    );

    expect(received, greaterThan(0),
        reason: 'the listener must keep receiving after handler errors');
    expect(drained, greaterThan(0),
        reason: 'the fuzz should have produced handler errors');
  });
}
