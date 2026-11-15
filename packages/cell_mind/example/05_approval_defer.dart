// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (05_approval_defer → example #5).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// Human-in-the-loop: `Defer` → `ApprovalQueue` → approve/reject.
///
/// Run with:
/// ```bash
/// dart run example/05_approval_defer.dart
/// ```
///
/// Amounts above 1000 are deferred to a human. The deferred pulse is
/// recorded as a `Defer` decision and dropped from the wave; the human
/// decision commits the value to `queue.committed` and is recorded as a
/// follow-up decision linked by `decisionId`.
Future<void> main() async {
  print('=== Approval demo ===');
  print('');

  final context = Context.fromEntries([
    Ontology.domains.entry('finance'),
    Ontology.version.entry('1.0.0'),
  ]);
  final gate = Cell.ingress<int>(context: context);
  final queue = ApprovalQueue<int>(
    journal: RecordingJournal(),
    ttl: const Duration(seconds: 30),
  );

  final handle = cognitive(
    cell: gate.cell,
    verdictPolicy: verdictPolicy((object, {required host, arguments}) {
      if (object is! Pulse) return const Accept();
      final amount = object.payload as int? ?? 0;
      if (amount > 1000) {
        return const Defer('approval', {'reason': 'amount-exceeds-threshold'});
      }
      return const Accept();
    }),
    onDeferred: approvalResolver(queue),
  );

  // Observe decisions.
  final decisionsSub = Cell.observe(
      source: handle.decisions,
      effect: (Pulse p) {
        final decision = p.payload as Decision;
        if (decision.pulse != null) {
          final verdict = decision.verdict;
          print('  decision ${decision.id}: ${verdict.runtimeType} '
              '${verdict.toMap()} (payload ${decision.pulse!.payload})');
        }
      });

  // Observe committed approvals.
  final committedSub = Cell.observe(
      source: queue.committed,
      effect: (Pulse p) {
        if (p.payload != null) {
          print('  COMMITTED: ${p.payload}');
        }
      });

  // Small pulse — auto-accepted.
  print('Small amount (500):');
  await gate.ingest(Pulse<int>.governed(
    payload: 500,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('demo'),
      Provenance.reason.entry('small'),
    ]),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  // Large pulse — deferred to approval.
  print('');
  print('Large amount (2000):');
  await gate.ingest(Pulse<int>.governed(
    payload: 2000,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('demo'),
      Provenance.reason.entry('large'),
    ]),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  print('  pending: ${queue.pending.length}');

  // A human reviews and approves.
  final requestId = queue.pending.keys.first;
  print('  approving $requestId...');
  await queue.approve(requestId);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  // A second large pulse — rejected by the human.
  print('');
  print('Second large amount (3000):');
  await gate.ingest(Pulse<int>.governed(
    payload: 3000,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('demo'),
      Provenance.reason.entry('large-again'),
    ]),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  final secondId = queue.pending.keys.first;
  print('  rejecting $secondId...');
  await queue.reject(secondId, 'reviewer-said-no');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  print('');
  print('Committed value: ${queue.committed.value}');
  print('Decisions: ${handle.decisions.length}');
  print('');
  print('Done.');
  decisionsSub.stop();
  committedSub.stop();
  await queue.dispose();
}
