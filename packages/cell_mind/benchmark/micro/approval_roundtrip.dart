// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: submit → approve round-trip on [ApprovalQueue].
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/approval_roundtrip.dart
/// ```
///
/// Measures the full human-in-the-loop mutation cost (submit apply +
/// txApply commit + journal effects) for 100 / 1,000 round-trips.
Future<void> main() async {
  final queue = ApprovalQueue<int>(
    journal: RecordingJournal(
      clockSource: () => DateTime.utc(2026, 11, 15, 12),
      uuidSource: () => Identity.next(),
    ),
    ttl: const Duration(days: 1),
  );

  Decision decision(int i) => Decision(
        id: 'bench-$i',
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        pulse: Pulse<int>.governed(payload: i),
      );

  print('Approval round-trip (submit → approve):');
  print('');

  for (final size in [100, 1000]) {
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < size; i++) {
      final future = queue.submit(decision(i));
      await Future<void>.delayed(Duration.zero);
      final id = queue.pending.keys.last;
      await queue.approve(id);
      await future;
    }
    stopwatch.stop();
    final roundTripsPerSecond = size * 1000000 / stopwatch.elapsedMicroseconds;
    print('  ${size.toString().padLeft(5)} round-trips: '
        '${roundTripsPerSecond.toStringAsFixed(0).padLeft(6)} round-trips/s');
  }

  await queue.dispose();
}
