// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: agent construction cost.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/spawn_cost.dart
/// ```
Future<void> main() async {
  final source = Cell.ingress<int>(
    context: Context.fromEntries([Ontology.domains.entry('finance')]),
  );
  final stopwatch = Stopwatch()..start();
  const n = 100;
  for (var i = 0; i < n; i++) {
    final agent = await spawn(
      AgentSpec(
        name: 'agent-$i',
        cell: source.cell,
        mandate: DeputyContext(
          baseContext: Context.fromEntries([Ontology.domains.entry('finance')]),
          authority: 'bench',
        ),
        routeIn: (p) => source.ingest(p as Pulse<int>),
      ),
      journal: RecordingJournal(),
    );
    agent.dispose();
  }
  stopwatch.stop();
  print('Agent spawn cost: '
      '${(n * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'spawns/s');
}
