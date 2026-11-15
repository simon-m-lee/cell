// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

/// Fixture: a Context with the given domains.
///
/// `Ontology.domains` is a **static pillar** (`evolvable: false`) in
/// `cell` 1.1.0 — it must be set at construction, not via `evolve`.
Context ctxWithDomains(String domains) => Context(domains: domains);

/// Fixture: a Context with the given compliance markers.
Context ctxWithCompliance(String compliance) =>
    Context(compliances: compliance);

/// Fixture: a Context with the given authority verb whitelist.
///
/// Authority is a [Mandate] dimension, so it lives on a [DeputyContext].
DeputyContext ctxWithAuthority(
  String authority, {
  Context baseContext = Context.system,
}) =>
    DeputyContext(baseContext: baseContext, authority: authority);

/// Fixture: a Context with the given clearance tier.
DeputyContext ctxWithClearance(
  Clearance clearance, {
  Context baseContext = Context.system,
}) =>
    DeputyContext(
      baseContext: baseContext,
      authority: 'OBSERVATION',
      clearance: clearance,
    );

/// Fixture: a Context with the given isolation tier.
DeputyContext ctxWithIsolation(
  Isolation isolation, {
  Context baseContext = Context.system,
}) =>
    DeputyContext(
      baseContext: baseContext,
      authority: 'OBSERVATION',
      isolation: isolation,
    );

/// Fixture: a Context with a specific version stamp (for replay tests).
///
/// `Ontology.version` is a static pillar; set it at construction.
Context ctxWithVersion(String version) => Context(version: version);

/// Fixture: a Context carrying the given constraint map.
///
/// `Ontology.constraints` is evolvable, so `evolve` is the canonical
/// (and only) path when deriving from an existing context.
Context ctxWithConstraints(Map<String, dynamic> constraints) =>
    Context.system.evolve((_) => Ontology.constraints.entry(constraints));

/// Fixture: a governed Pulse with the given provenance.
///
/// Domains and compliance are static pillars on a [PulseContext], so they
/// are assembled via [PulseContext.fromEntries] rather than `evolve`.
Pulse<int> governedPulse({
  int payload = 0,
  String actor = 'test-actor',
  String reason = 'test-reason',
  String? purpose,
  double? confidence,
  String? domains,
  String? compliance,
  ReasoningStrategy? strategy,
  Sensitivity? sensitivity,
  AuditLevel? auditLevel,
  int? priority,
  String? traceId,
  Cell? source,
  PulseEphemeralPolicy? policy,
}) {
  final context = PulseContext.fromEntries([
    Provenance.actor.entry(actor),
    Provenance.traceId.entry(traceId ?? Identity.next()),
    if (reason.isNotEmpty) Provenance.reason.entry(reason),
    if (purpose != null) Provenance.purpose.entry(purpose),
    if (confidence != null) Provenance.confidence.entry(confidence),
    if (priority != null) Provenance.priority.entry(priority),
    if (compliance != null) Provenance.compliance.entry(compliance),
    if (strategy != null) Provenance.strategy.entry(strategy),
    if (sensitivity != null) Provenance.sensitivity.entry(sensitivity),
    if (auditLevel != null) Provenance.auditLevel.entry(auditLevel),
    if (domains != null) Ontology.domains.entry(domains),
  ]);
  return Pulse<int>.governed(
    payload: payload,
    context: context,
    source: source,
    policy: policy,
  );
}

/// Fixture: an ApplyCommand calling a trivial function.
ApplyCommand trivialCommand() => (
      function: () => 42,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    );

/// Fixture: a [CellBase] subclass whose `modifiable` manifest contains a
/// single whitelisted verb. Used to verify `ApplyReceipt.vetted` against
/// manifest membership — the live `cell` 1.1.0 contract.
class ManifestCell extends CellBase {
  /// The whitelisted verb. Receipts for this function must report
  /// `vetted: true`; any other function reports `vetted: false`.
  late final int Function(int amount) echo = _echo;

  ManifestCell({super.context, super.testRule});

  int _echo(int amount) => amount;

  @override
  Iterable<Function> get modifiable => {echo};
}
