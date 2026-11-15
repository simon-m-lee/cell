// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: contextual-bandit trainer throughput.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/training_cost.dart
/// ```
///
/// Trains over synthetic logs of 100 / 1,000 / 10,000 resolved
/// decisions and reports decisions per second and the rule count.
///
/// Guidance: ≥ 10,000 decisions/second for 1,000-decision logs on a
/// modern machine. Below 5,000, profile bucketing (the vector
/// normalization is the hot path).
Future<void> main() async {
  final trainer = contextualBandit();
  final base = Context.fromEntries([
    Ontology.domains.entry('finance,marketing,audit'),
    Ontology.version.entry('1.0.0'),
  ]);

  print('Contextual bandit throughput:');
  print('');

  for (final size in [100, 1000, 10000]) {
    final decisions = <Decision>[];
    final outcomes = <Outcome>[];
    for (var i = 0; i < size; i++) {
      final domain = ['finance', 'marketing', 'audit'][i % 3];
      final pulse = Pulse<int>.governed(
        payload: i,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('bench'),
          Provenance.traceId.entry('trace-$i'),
          Ontology.domains.entry(domain),
        ]),
      );
      decisions.add(
        Decision(
          id: 'd-$i',
          at: DateTime.utc(2026, 11, 15),
          context: base,
          contextVersion: '1.0.0',
          verdict: const Accept(),
          pulse: pulse,
        ),
      );
      outcomes.add(
        Outcome(
          decisionId: 'd-$i',
          reward: domain == 'marketing' ? -1.0 : 1.0,
          at: DateTime.utc(2026, 11, 15, 1),
        ),
      );
    }

    final journal = RecordingJournal(
      clockSource: () => DateTime.utc(2026, 11, 15, 2),
    );
    final stopwatch = Stopwatch()..start();
    final trained = await trainer.train(
      decisions: decisions,
      outcomes: outcomes,
      baseContext: base,
      journal: journal,
      config: const TrainingConfig(minSupport: 5, minConfidence: 0.6),
    );
    stopwatch.stop();
    final decisionsPerSecond = size * 1000000 / stopwatch.elapsedMicroseconds;
    print('  ${size.toString().padLeft(6)} decisions: '
        '${decisionsPerSecond.toStringAsFixed(0).padLeft(6)} decisions/s, '
        '${trained.ruleCount} rules');
  }
}
