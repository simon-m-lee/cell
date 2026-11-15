// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (04_learning_loop → example #4).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// The learning loop — record, train, deploy.
///
/// Run with:
/// ```bash
/// dart run example/04_learning_loop.dart
/// ```
///
/// Simulated world: `marketing` decisions always fail downstream;
/// `finance` decisions succeed. The first runtime is permissive over
/// both domains; the trainer learns a `reject` rule for `marketing`;
/// the redeployed runtime rejects it before it reaches state.
Future<void> main() async {
  print('=== Learning loop demo ===');
  print('');

  // 1. A permissive static gate over three domains, with a version
  //    stamp (replay-ready) and the learned policy composed in.
  final context = Context.fromEntries([
    Ontology.domains.entry('finance,marketing,audit'),
    Ontology.version.entry('1.0.0'),
  ]);
  final gate = Cell.ingress<int>(
    context: context,
    testRule: contextAware() + learnedPolicy(),
  );
  final handle = cognitive(cell: gate.cell);
  final outcomes = recordOutcomes(handle);

  // 2. Simulate traffic: marketing always fails downstream.
  for (var i = 0; i < 12; i++) {
    await gate.ingest(_pulse(i, 'marketing'));
    await Future<void>.delayed(Duration.zero);
    final decision = handle.decisions.lastWhere((d) => d.pulse != null);
    handle.recordOutcome(decisionId: decision.id, reward: -1.0);
  }
  for (var i = 0; i < 6; i++) {
    await gate.ingest(_pulse(100 + i, 'finance'));
    await Future<void>.delayed(Duration.zero);
    final decision = handle.decisions.lastWhere((d) => d.pulse != null);
    handle.recordOutcome(decisionId: decision.id, reward: 1.0);
  }
  await Future<void>.delayed(Duration.zero);

  print('Decisions: ${handle.decisions.length}');
  print('Outcomes:  ${outcomes.log.length}');
  print('');

  // 3. Train offline (journaled).
  final journal = RecordingJournal();
  final trained = await trainOffline(
    handle: handle,
    outcomes: outcomes.log,
    baseContext: handle.cell.context,
    trainer: contextualBandit(),
    journal: journal,
    config: const TrainingConfig(minSupport: 5, minConfidence: 0.6),
  );

  print('Trained on ${trained.resolvedCount}/${trained.decisionCount} '
      'decisions, avg reward ${trained.averageReward.toStringAsFixed(2)}');
  final rules = trained.policyBlock['rules'] as List;
  print('Rules: ${rules.length}');
  for (final rule in rules) {
    final map = rule as Map;
    print('  -> ${map['when']}: ${map['action']} '
        '(conf ${(map['confidence'] as num).toStringAsFixed(2)}, '
        'support ${map['support']})');
  }

  // 4. Deploy: rebuild with the evolved context.
  final evolved = trained.applyTo(handle.cell.context);
  final newGate = Cell.ingress<int>(
    context: evolved,
    testRule: contextAware() + learnedPolicy(),
  );
  final newHandle = cognitive(cell: newGate.cell);
  final observed = <int>[];
  final sub = Cell.observe(
      source: newHandle.cognitive,
      effect: (Pulse p) {
        observed.add(p.payload as int);
      });

  await newGate.ingest(_pulse(999, 'marketing'));
  await newGate.ingest(_pulse(1000, 'finance'));
  await Future<void>.delayed(Duration.zero);
  print('');
  print('After learning:');
  print(
      '  marketing pulse -> ${observed.contains(999) ? 'ACCEPTED' : 'REJECTED '
          '(learned rule)'}');
  print(
      '  finance pulse   -> ${observed.contains(1000) ? 'ACCEPTED' : 'REJECTED'}');

  print('');
  print('Done.');
  sub.stop();
  outcomes.stop();
  handle.dispose();
  newHandle.dispose();
}

Pulse<int> _pulse(int payload, String domains) => Pulse<int>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('sim'),
        Provenance.reason.entry('learning-loop demo'),
        Provenance.traceId.entry(Identity.next()),
        Ontology.domains.entry(domains),
        Provenance.confidence.entry(1.0),
      ]),
    );
