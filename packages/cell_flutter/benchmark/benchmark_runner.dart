// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Shared microbenchmark runner.
//
// Measures wall-clock frame time per update (p50/p99) inside
// `testWidgets`; each update is one `tester.pump()`. The harness cost is
// identical across implementations, so the ratios are meaningful even
// though the absolute numbers are microbenchmark artifacts.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

class ScenarioResult {
  ScenarioResult(this.name, this.updates, this.rebuilds, this.timesUs);

  final String name;
  final int updates;
  final int rebuilds;
  final List<int> timesUs;

  double p50() => percentile(timesUs, 50);
  double p99() => percentile(timesUs, 99);

  static double percentile(List<int> values, double p) {
    final sorted = [...values]..sort();
    if (sorted.isEmpty) return 0;
    final index =
        min(sorted.length - 1, ((p / 100) * (sorted.length - 1)).round());
    return sorted[index].toDouble();
  }

  @override
  String toString() => '$name: p50=${p50().round()}us '
      'p99=${p99().round()}us rebuilds=$rebuilds/$updates';
}

/// Runs [update] [updates] times, one `tester.pump()` each, and reports
/// per-update wall time plus the number of times [countBuild] fired.
Future<ScenarioResult> runScenario(
  WidgetTester tester,
  String name, {
  required int updates,
  required Future<void> Function(int iteration) update,
  required int Function() builds,
}) async {
  final times = <int>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < updates; i++) {
    stopwatch
      ..reset()
      ..start();
    await update(i);
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds);
  }
  return ScenarioResult(name, updates, builds(), times);
}
