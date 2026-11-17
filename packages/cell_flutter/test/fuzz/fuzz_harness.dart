// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Deterministic seeded fuzz harness for the 1.0 gate.
//
// Configuration via --dart-define:
//   FUZZ_SEEDS     total seeds across the whole fuzz suite (default 6)
//   FUZZ_SECONDS   wall-clock seconds per seed (default 3)
//
// The full gate run is 60 seeds x 30 seconds (30 minutes); the defaults
// are a fast smoke configuration. The seed budget is split evenly
// across the six fuzz files.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

const _fuzzSeeds = int.fromEnvironment('FUZZ_SEEDS', defaultValue: 6);
const _fuzzSeconds = int.fromEnvironment('FUZZ_SECONDS', defaultValue: 3);

/// Number of fuzz files in `test/fuzz/` — the seed budget is shared.
const fuzzFileCount = 6;

/// Seeds assigned to one fuzz file.
int fuzzSeedsForFile() => max(1, _fuzzSeeds ~/ fuzzFileCount);

/// Wall-clock duration per seed.
Duration fuzzSecondsPerSeed() => const Duration(seconds: _fuzzSeconds);

/// A deterministic random source for [seed].
Random fuzzRandom(int seed) => Random(0x5EED + seed * 7919);

/// Runs [iterate] repeatedly against the fake clock for [perSeed], once
/// per seed, and fails on any uncaught framework exception.
///
/// Each iteration pumps at least one frame; every pump is followed by a
/// [WidgetTester.takeException] check so exceptions in builders,
/// listeners, and selectors fail the fuzz instead of being swallowed.
///
/// [discardExceptions] is for fuzz scenarios whose handlers throw by
/// design (e.g. the `CellListener` fuzz): exceptions are drained and
/// counted instead of failing.
Future<int> runFuzz({
  required WidgetTester tester,
  required int seeds,
  required Duration perSeed,
  required Future<void> Function(
    WidgetTester tester,
    Random random,
    int iteration,
  ) iterate,
  bool discardExceptions = false,
}) async {
  var drained = 0;
  for (var seed = 0; seed < seeds; seed++) {
    final random = fuzzRandom(seed);
    final deadline = DateTime.now().add(perSeed);
    var iteration = 0;
    while (DateTime.now().isBefore(deadline)) {
      await iterate(tester, random, iteration++);
      final exception = tester.takeException();
      if (exception != null) {
        if (discardExceptions) {
          drained++;
        } else {
          fail('Fuzz seed $seed, iteration $iteration: uncaught exception '
              '$exception');
        }
      }
      await tester.pump(Duration(milliseconds: 1 + random.nextInt(50)));
      final pumpException = tester.takeException();
      if (pumpException != null) {
        if (discardExceptions) {
          drained++;
        } else {
          fail('Fuzz seed $seed, iteration $iteration: exception after pump '
              '$pumpException');
        }
      }
    }
  }
  return drained;
}
