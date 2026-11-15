// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: bridge overhead — completion emission and tool dispatch.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/bridge_cost.dart
/// ```
///
/// Measures the governed-call cost: one completion bridge emission
/// (governed pulse + journal effect) and one tool-router round-trip
/// (validation + journaled dispatch + result pulse).
Future<void> main() async {
  print('Bridge cost:');
  print('');

  // 1. Completion emission.
  final stopwatch = Stopwatch()..start();
  const n = 1000;
  for (var i = 0; i < n; i++) {
    final journal = RecordingJournal(
      clockSource: () => DateTime.utc(2026, 11, 15, 12),
    );
    final cell = completion(
      future: Future.value('answer-$i'),
      actor: 'bench',
      prompt: 'p',
      confidence: 0.9,
      journal: journal,
    );
    final sub = Cell.observe(source: cell, effect: (Pulse p) {});
    await Future<void>.delayed(Duration.zero);
    sub.stop();
  }
  stopwatch.stop();
  print('  completion emission: '
      '${(n * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'emissions/s');

  // 2. Tool router round-trip.
  final stopwatch2 = Stopwatch()..start();
  for (var i = 0; i < 200; i++) {
    final journal = RecordingJournal(
      clockSource: () => DateTime.utc(2026, 11, 15, 12),
    );
    final source = Cell.ingress<Pulse>();
    final router = toolRouter(
      source: source.cell,
      tools: {'echo': (args) async => args['v']},
      actor: 'bench',
      journal: journal,
    );
    final sub = Cell.observe(source: router, effect: (Pulse p) {});
    source.emit(
      Pulse<Map<String, dynamic>>.governed(
        payload: {
          'verb': 'echo',
          'args': {'v': i}
        },
        context: PulseContext.fromEntries([
          Provenance.actor.entry('bench'),
          Provenance.confidence.entry(0.9),
        ]),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    sub.stop();
  }
  stopwatch2.stop();
  print('  tool dispatch round-trip: '
      '${(200 * 1000000 / stopwatch2.elapsedMicroseconds).toStringAsFixed(0)} '
      'dispatches/s');
}
