// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: decision-recording overhead per apply.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/recording_cost.dart
/// ```
///
/// Reports nanoseconds per `apply` for:
/// - the bare principal (`cell.apply`)
/// - the cognitive view (`handle.cognitive.apply` — policy + recording)
///
/// Guidance: the dominant recording cost on the live substrate is the
/// `TissueList.add` forensic write (~40 µs/entry on the Phase 2 dev
/// machine), not policy evaluation or `Decision` construction. The 3×
/// target from the plan applies to CI-recorded baselines; local
/// numbers are informational (see KNOWN_ISSUES.md §R7).
Future<void> main() async {
  final src = Cell.ingress<int>(context: Context(domains: 'finance'));
  final handle = cognitive(cell: src.cell, policy: domainPolicy());

  const n = 20000;

  ApplyCommand command() => (
        function: echo,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      );

  // Warm-up.
  for (var i = 0; i < 200; i++) {
    await src.cell.apply<int>(command());
  }

  print('Recording cost (ns/apply, $n iterations):');
  print('');

  await bench('bare principal apply', n, () async {
    await src.cell.apply<int>(command());
  });
  await bench('cognitive apply (policy + log)', n, () async {
    await handle.cognitive.apply<int>(command());
  });

  final decisions = handle.decisions.length;
  print('');
  print('  decision log entries recorded: $decisions');
}

int echo(int x) => x;

Future<void> bench(String label, int n, Future<void> Function() body) async {
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    await body();
  }
  stopwatch.stop();
  final nsPerDecision = stopwatch.elapsedMicroseconds * 1000 / n;
  print('  ${label.padRight(30)} ${nsPerDecision.toStringAsFixed(1)}');
}
