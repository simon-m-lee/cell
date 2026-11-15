// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// A deterministic journal for trainer tests: fixed clock, fixed uuids.
RecordingJournal fixedJournal({DateTime? at}) => RecordingJournal(
      clockSource: () => at ?? DateTime.utc(2026, 11, 15, 12),
      uuidSource: () => 'uuid-fixed',
    );

/// A decision fixture with a governed pulse carrying [domains].
Decision decisionFixture({
  required String id,
  required Context context,
  required Verdict verdict,
  String domains = 'finance',
  String? actor,
  ReasoningStrategy? strategy,
  String? purpose,
  DateTime? at,
}) {
  final pulse = Pulse<int>.governed(
    payload: 0,
    context: PulseContext.fromEntries([
      Provenance.actor.entry(actor ?? 'agent-a'),
      Provenance.traceId.entry('trace-$id'),
      Ontology.domains.entry(domains),
      if (strategy != null) Provenance.strategy.entry(strategy),
      if (purpose != null) Provenance.purpose.entry(purpose),
    ]),
  );
  return Decision(
    id: id,
    at: at ?? DateTime.utc(2026, 11, 15, 10),
    context: context,
    contextVersion: context.version ?? '0.0.0',
    verdict: verdict,
    pulse: pulse,
  );
}

/// An outcome fixture bound to [decisionId].
Outcome outcomeFixture({
  required String decisionId,
  double reward = 1.0,
  Map<String, dynamic>? metadata,
  DateTime? at,
}) =>
    Outcome(
      decisionId: decisionId,
      reward: reward,
      metadata: metadata,
      at: at ?? DateTime.utc(2026, 11, 15, 11),
    );

/// A context with domains + version + constraints.
Context learningContext({
  String domains = 'finance',
  String version = '1.0.0',
  Map<String, dynamic>? constraints,
}) =>
    Context.fromEntries([
      Ontology.domains.entry(domains),
      Ontology.version.entry(version),
      if (constraints != null) Ontology.constraints.entry(constraints),
    ]);
