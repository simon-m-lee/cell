// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (03_decision_log → example #3).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// The decision log — recording, observing, querying, and rewarding.
///
/// Run with:
/// ```bash
/// dart run example/03_decision_log.dart
/// ```
Future<void> main() async {
  print('=== Decision log demo ===');
  print('');

  // 1. A domain-gated source with a versioned context (replay-ready).
  final context = Context.fromEntries([
    Ontology.domains.entry('finance'),
    Ontology.version.entry('1.0.0'),
  ]);
  final src = Cell.ingress<int>(context: context);
  final handle = cognitive(cell: src.cell, policy: domainPolicy());

  // 2. Observe the log live.
  final live = <String>[];
  final observer = Cell.observe(
      source: handle.decisions,
      effect: (Pulse p) {
        final decision = p.payload as Decision;
        if (decision.pulse != null) {
          live.add('${decision.pulse!.payload} -> '
              '${decision.verdict.runtimeType}');
        }
      });

  // 3. Traffic.
  await src.ingest(_pulse(1, 'finance'));
  await src.ingest(_pulse(2, 'marketing'));
  await src.ingest(_pulse(3, 'finance'));
  await Future<void>.delayed(Duration.zero);

  print('Observed live:');
  for (final line in live) {
    print('  $line');
  }

  // 4. Query the log.
  final accepted = handle.decisions
      .where((d) => d.pulse != null && d.verdict is Accept)
      .toList();
  final rejected = handle.decisions
      .where((d) => d.pulse != null && d.verdict is Reject)
      .toList();
  print('');
  print('Accepted: ${accepted.length}, rejected: ${rejected.length}');

  // 5. Reward the accepted decisions (the learning loop consumes these).
  for (final decision in accepted) {
    handle.recordOutcome(decisionId: decision.id, reward: 1.0);
  }

  // 6. Serialize one decision for the audit trail.
  final serialized = accepted.first.toMap();
  print('');
  print('Serialized decision:');
  print('  ${serialized.toString()}');

  print('');
  print('Done.');
  observer.stop();
}

Pulse<int> _pulse(int payload, String domains) => Pulse<int>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('demo'),
        Provenance.reason.entry('decision-log example'),
        Provenance.traceId.entry(Identity.next()),
        Ontology.domains.entry(domains),
      ]),
    );
