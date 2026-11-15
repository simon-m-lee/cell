// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A stateless, context-aware decision rule. Composable via `TestCell.+`.
///
/// ### When to use
/// Composed into a cell's `testRule` (static mode) or layered onto an
/// existing cell via `cognitive(...)` (dynamic mode, Phase 2).
///
/// ### How it works
/// A `Policy` is a [TestCell] — accept (`true`) or reject (`false`). The
/// policy reads its decision inputs from:
/// - **`host`**: the cell being validated (`host.context`).
/// - **`object`**: the thing being validated — a [Pulse] (pulse
///   reception), a [Function] (action invocation, with the
///   `ApplyArguments` record as `arguments`), or a [Cell] (link
///   establishment).
///
/// ### Non-obvious
/// - **Object-type dispatch is explicit.** Every factory returns `true`
///   (accept) for object types it does not govern — a pulse policy has
///   nothing to say about actions. Composed policies therefore AND
///   cleanly without accidental rejections.
/// - **Fail-closed is the default.** Missing metadata rejects unless an
///   explicit opt-out flag (`allowMissing`, `allowUntagged`) is set.
///
/// {@category Organ}
/// {@category Policy}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
typedef Policy = TestCell<Cell>;

// ── Domain ──────────────────────────────────────────────────────

/// Accepts pulses whose origin domains are within the acceptor's
/// declared domains (or [additionalDomains]).
///
/// ### When to use
/// Gate an ingress cell so that only pulses from known business areas
/// reach its receptor. Compose with `requiresDomainPolicy()` when both
/// sides must be tagged.
///
/// ### How it works
/// - Reads the acceptor's domains from `host.context.domains`.
/// - Resolves the pulse's origin domains via `_originDomains` — the
///   pulse's own `PulseContext` claim, or the source cell's declared
///   domains (pulse claim must be a subset of the source's, otherwise a
///   [StateError] flags a provenance mismatch).
/// - Accepts when `origin ⊆ host ∪ additionalDomains`.
///
/// ### Non-obvious
/// - **Fail-closed on untagged pulses.** When the acceptor declares
///   domains, a pulse with no domain claim is rejected unless
///   `allowUntagged: true`.
/// - **Permissive when the acceptor is untagged.** A host without
///   declared domains accepts everything — there is nothing to enforce.
///
/// {@category Policy}
/// {@category Domain}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
Policy domainPolicy({
  Set<String>? additionalDomains,
  bool allowUntagged = false,
}) {
  final extras = _normalizeSet(additionalDomains);
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    if (host == null) return true; // No acceptor, nothing to enforce.
    final hostDomains = _parseCommaList(host.context.domains);
    if (hostDomains.isEmpty) return true;
    final origins = _originDomains(object);
    if (origins.isEmpty) return allowUntagged;
    return _isSubset(origins, {...hostDomains, ...extras});
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses only when **both** the acceptor and the pulse declare
/// at least one domain.
///
/// ### When to use
/// The strict domain-existence companion to [domainPolicy]: it rejects
/// the "acceptor declares, pulse silent" case and the "acceptor silent"
/// case outright. `contextAware()` chains it by default.
///
/// ### Non-obvious
/// The pulse side is satisfied by either the pulse's own
/// `PulseContext.domains` claim or its source cell's declared domains.
///
/// {@category Policy}
/// {@category Domain}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy requiresDomainPolicy() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    if (host == null) return false;
    final hostDomains = _parseCommaList(host.context.domains);
    if (hostDomains.isEmpty) return false;
    final pulseClaim = _parseCommaList(object.context.domains);
    final sourceClaim = object.source == null
        ? const <String>{}
        : _parseCommaList(object.source!.context.domains);
    return pulseClaim.isNotEmpty || sourceClaim.isNotEmpty;
  });
}

// ── Compliance ──────────────────────────────────────────────────

/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.compliance` includes every
/// compliance marker required by the acceptor's `Ontology.compliance`.
///
/// ### When to use
/// Gate regulated cells — a GDPR-labelled cell must only process pulses
/// that themselves assert the GDPR marker.
///
/// ### How it works
/// - Reads the required markers from `host.context.compliance`
///   (+ [additionalCompliance]).
/// - Accepts when `required ⊆ pulse.context.compliance`.
/// - An acceptor with no compliance requirements accepts everything; a
///   pulse missing a required marker is rejected (fail-closed — there is
///   no `allowMissing` opt-out: missing markers mean the data cannot be
///   legally processed).
///
/// {@category Policy}
/// {@category Compliance}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy compliancePolicy({Set<String>? additionalCompliance}) {
  final extras = _normalizeSet(additionalCompliance);
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    if (host == null) return true; // No acceptor, nothing to enforce.
    final required = _parseCommaList(host.context.compliance)..addAll(extras);
    if (required.isEmpty) return true;
    final provided = _parseCommaList(object.context.compliance);
    return _isSubset(required, provided);
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A stricter compliance variant: requires **both** the pulse AND the
/// acceptor to declare compliance, and requires the sets to overlap.
///
/// ### When to use
/// Compliance-zone boundaries where two systems must demonstrably share
/// a regulatory framework before data may cross.
///
/// {@category Policy}
/// {@category Compliance}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy complianceOverlapPolicy() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    if (host == null) return false;
    final hostMarkers = _parseCommaList(host.context.compliance);
    if (hostMarkers.isEmpty) return false;
    final pulseMarkers = _parseCommaList(object.context.compliance);
    if (pulseMarkers.isEmpty) return false;
    return hostMarkers.any(pulseMarkers.contains);
  });
}

// ── Authority ───────────────────────────────────────────────────

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts `apply` commands whose verb is within the acceptor's
/// `Mandate.authority` (comma-separated verb whitelist).
///
/// ### When to use
/// Govern a cell's command surface by its declared mandate: a balance
/// cell declaring `'read,write'` rejects `delete`-shaped commands.
///
/// ### How it works
/// - Governs [Function] objects only (passes pulses and links through).
/// - Reads the whitelist from a [DeputyContext]'s `Mandate.authority`
///   (+ [additionalVerbs]); a plain [Context] has no authority.
/// - Extracts the verb via [verbResolver], or by parsing the VM's
///   tear-off shape (`Function 'credit':`), and fails closed when the
///   verb cannot be extracted.
/// - An acceptor with no declared authority and no [additionalVerbs]
///   accepts everything — nothing is being enforced.
///
/// ### Non-obvious
/// Verb extraction is heuristic — anonymous lambdas have no name. For a
/// curated API surface use [exactFunctionsPolicy] (exact `==`
/// comparison), which is the reliable alternative.
///
/// {@category Policy}
/// {@category Authority}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy authorityPolicy({
  Set<String>? additionalVerbs,
  String? Function(Function)? verbResolver,
}) {
  final extras = _normalizeSet(additionalVerbs);
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Function) return true;
    if (host == null) return false;
    final declared = _readAuthority(host.context);
    if (declared.isEmpty && extras.isEmpty) return true;
    final verb = _extractVerb(object, resolver: verbResolver);
    if (verb == null) return false;
    final normalized = verb.toLowerCase();
    return declared.contains(normalized) || extras.contains(normalized);
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts only the specific functions in [whitelist], regardless of
/// mandate.
///
/// ### When to use
/// Narrow, curated API surfaces — exactly these commands, nothing else.
/// Comparison is by function identity (`==`), so tear-offs must be taken
/// from the same instance.
///
/// {@category Policy}
/// {@category Authority}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy exactFunctionsPolicy(Set<Function> whitelist) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Function) return true;
    return whitelist.contains(object);
  });
}

// ── Clearance / isolation / sensitivity ────────────────────────

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Classifies an operation for [clearancePolicy].
///
/// {@category Policy}
/// {@category Clearance}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
enum ApplyCategory {
  /// Receiving a pulse — the lightest operation.
  pulse,

  /// Executing an ordinary state-mutating function.
  pureAction,

  /// Executing a structural function (link/unlink/mount).
  structuralAction,

  /// Executing a function that crosses domain boundaries.
  crossDomainAction,
}

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts operations whose required clearance is within the acceptor's
/// `Mandate.clearance`.
///
/// ### When to use
/// Layer structural protection onto a cell: reads are cheap, mutations
/// need `standard`, topology changes need `administrative`.
///
/// ### How it works
/// The required clearance is derived from the *kind* of operation:
/// - `Pulse` reception → [ApplyCategory.pulse] → `Clearance.minimal`
/// - `Function` action → [categoryResolver] or
///   [ApplyCategory.pureAction] → `Clearance.standard`
/// - `Cell` link → [ApplyCategory.structuralAction] →
///   `Clearance.administrative`
///
/// Override any mapping via [requirements].
///
/// ### Non-obvious
/// The acceptor's clearance is a `DeputyContext` mandate dimension; a
/// plain [Context] resolves to [Clearance.standard].
///
/// {@category Policy}
/// {@category Clearance}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy clearancePolicy({
  Map<ApplyCategory, Clearance>? requirements,
  ApplyCategory Function(Function)? categoryResolver,
}) {
  final defaults = <ApplyCategory, Clearance>{
    ApplyCategory.pulse: Clearance.minimal,
    ApplyCategory.pureAction: Clearance.standard,
    ApplyCategory.structuralAction: Clearance.administrative,
    ApplyCategory.crossDomainAction: Clearance.privileged,
  };
  final effective = {...defaults, ...?requirements};
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (host == null) return false;
    final hostClearance = _readClearance(host.context);
    if (object is Pulse) {
      return hostClearance.authorizes(effective[ApplyCategory.pulse]!);
    }
    if (object is Function) {
      final category =
          categoryResolver?.call(object) ?? ApplyCategory.pureAction;
      return hostClearance.authorizes(effective[category]!);
    }
    if (object is Cell) {
      return hostClearance.authorizes(
        effective[ApplyCategory.structuralAction]!,
      );
    }
    return true; // Unknown object type — nothing to enforce.
  });
}

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts only operations allowed by the acceptor's `Mandate.isolation`.
///
/// ### When to use
/// Deputy hardening — an `Isolation.sandboxed` deputy may only ingest
/// ephemeral pulses, an `Isolation.total` deputy is air-gapped.
///
/// ### How it works
/// Isolation is a [DeputyContext] mandate dimension. A plain [Context]
/// carries no isolation, so the policy passes everything through. For a
/// deputy:
/// - `shared` — accepts everything.
/// - `scoped` — pulses must originate within the acceptor's domains.
/// - `restricted` — `scoped` plus every required compliance marker.
/// - `sandboxed` — only ephemeral pulses (a `PulseEphemeralPolicy`
///   attached); commands and links are rejected (they mutate live state).
/// - `total` — rejects everything (air-gapped observation).
///
/// ### Non-obvious
/// Under `scoped`/`restricted`, non-pulse objects (commands on the host
/// cell itself) pass through — the deputy's own `TestCell` governs its
/// command surface; isolation constrains what *reaches* the deputy.
///
/// {@category Policy}
/// {@category Isolation}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy isolationPolicy() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    final isolation = host == null ? null : _readIsolation(host.context);
    if (isolation == null) return true;
    switch (isolation) {
      case Isolation.shared:
        return true;
      case Isolation.total:
        return false;
      case Isolation.sandboxed:
        return object is Pulse && object.policy != null;
      case Isolation.scoped:
      case Isolation.restricted:
        if (object is! Pulse) return true;
        final hostDomains = _parseCommaList(host!.context.domains);
        if (hostDomains.isEmpty) return false;
        final origins = _originDomains(object);
        if (origins.isEmpty) return false;
        if (!_isSubset(origins, hostDomains)) return false;
        if (isolation == Isolation.restricted) {
          final required = _parseCommaList(host.context.compliance);
          if (required.isEmpty) return false;
          final provided = _parseCommaList(object.context.compliance);
          if (!_isSubset(required, provided)) return false;
        }
        return true;
    }
  });
}

/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.sensitivity` does not exceed the
/// acceptor's declared maximum sensitivity.
///
/// ### When to use
/// Data-classification boundaries: a cell declaring
/// `constraints['max_sensitivity'] = 'confidential'` rejects `secret`
/// pulses before they touch its state.
///
/// ### How it works
/// Reads the max from `host.context.constraints['max_sensitivity']`
/// (enum name or enum value), falling back to [defaultMax], then to
/// [Sensitivity.public] (most restrictive — fail-closed). A pulse with
/// no sensitivity declaration is rejected.
///
/// {@category Policy}
/// {@category Sensitivity}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy sensitivityPolicy({Sensitivity? defaultMax}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    if (host == null) return true; // No acceptor, nothing to enforce.
    final max = defaultMax ?? _readMaxSensitivity(host.context);
    final sensitivity = object.context.sensitivity;
    if (sensitivity == null) return false;
    return sensitivity.index <= max.index;
  });
}

// ── Confidence / strategy / audit ───────────────────────────────

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.confidence` is at least [min].
///
/// ### When to use
/// Gate probabilistic producers (LLM outputs, sensor fusion) — a
/// low-confidence suggestion should not commit state.
///
/// ### Non-obvious
/// Missing confidence rejects unless [allowMissing] is true (P4:
/// fail-closed default).
///
/// {@category Policy}
/// {@category Confidence}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy confidencePolicy({double min = 0.85, bool allowMissing = false}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final confidence = object.context.confidence;
    if (confidence == null) return allowMissing;
    return confidence >= min;
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.strategy` is in [allowed].
///
/// ### When to use
/// Restrict an integrity gate to trusted reasoning pedigrees — e.g. only
/// `deterministic` and `formal` signals.
///
/// ### Non-obvious
/// Missing strategy rejects unless [allowMissing] is true.
///
/// {@category Policy}
/// {@category Strategy}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy strategyPolicy(
  Set<ReasoningStrategy> allowed, {
  bool allowMissing = false,
}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final strategy = object.context.strategy;
    if (strategy == null) return allowMissing;
    return allowed.contains(strategy);
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.auditLevel` meets [min].
///
/// ### When to use
/// Forensic boundaries: a cell that must be auditable rejects telemetry
/// pulses that declare `AuditLevel.none`.
///
/// ### Non-obvious
/// Missing audit level rejects (fail-closed) — an unauditable signal
/// cannot enter an audited cell.
///
/// {@category Policy}
/// {@category Audit}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy auditLevelPolicy({AuditLevel min = AuditLevel.standard}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final auditLevel = object.context.auditLevel;
    if (auditLevel == null) return false;
    return auditLevel.index >= min.index;
  });
}

// ── Actor / purpose ────────────────────────────────────────────

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.actor` is in [allowed].
///
/// ### When to use
/// Whitelist the identities allowed to talk to a cell — e.g. only the
/// compliance auditor service may emit into the audit ledger.
///
/// ### Non-obvious
/// Actor comparison is exact (identifiers are case-sensitive). Missing
/// actor rejects unless [allowMissing] is true.
///
/// {@category Policy}
/// {@category Actor}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy actorPolicy(Set<String> allowed, {bool allowMissing = false}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final actor = object.context.actor;
    if (actor == null) return allowMissing;
    return allowed.contains(actor);
  });
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `Provenance.purpose` is in [allowed].
///
/// ### When to use
/// Mission scoping — a payment cell may only process pulses whose
/// purpose is `TRANSACTION_COMMIT`.
///
/// ### Non-obvious
/// Purpose comparison is exact. Missing purpose rejects unless
/// [allowMissing] is true.
///
/// {@category Policy}
/// {@category Purpose}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy purposePolicy(Set<String> allowed, {bool allowMissing = false}) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final purpose = object.context.purpose;
    if (purpose == null) return allowMissing;
    return allowed.contains(purpose);
  });
}

// ── Time ────────────────────────────────────────────────────────

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts pulses whose `timestamp` is within [window] of [clock]'s now.
///
/// ### When to use
/// Staleness gates: drop signals older than the freshness window before
/// they reach state.
///
/// ### Non-obvious
/// - **Requires a clock.** Uses `clock()` instead of `DateTime.now()` so
///   replay is deterministic. Pass `DateTime.now` for production, a
///   frozen clock for tests.
/// - **Purity is `readOnlyExternal`.** It reads external time state;
///   replay must journal the observed time. Feed a journal-backed clock
///   (`journal.clock`) when the policy participates in a replayable
///   graph.
/// - **Future timestamps are fresh.** A timestamp after `now` yields a
///   negative age and is accepted (clock skew is not the pulse's fault).
/// - A negative [window] is a construction-time [ArgumentError].
///
/// {@category Policy}
/// {@category Time}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy notOlderThan(
  Duration window, {
  required DateTime Function() clock,
}) {
  if (window.isNegative) {
    throw ArgumentError.value(window, 'window', 'must be non-negative');
  }
  return _TimePolicyRule((object, {host, arguments, user}) {
    if (object is! Pulse) return true;
    final age = clock().difference(object.timestamp);
    return age <= window;
  });
}

// ── Composition ────────────────────────────────────────────────

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// The cell's default "safe" policy: domain, compliance, clearance, and
/// confidence composed additively.
///
/// ### When to use
/// `Cell.ingress<T>(testRule: contextAware())` — the recommended default
/// for governed entry points.
///
/// ### Non-obvious
/// - **Fail-closed defaults.** Missing domains → reject via
///   `requiresDomainPolicy()`; missing compliance → reject when
///   `requireCompliance: true`; missing confidence → reject.
/// - **Opt-outs are explicit.** Teams that accept anonymous pulses pass
///   `requireDomain: false` and `allowMissingConfidence: true`.
///
/// {@category Policy}
/// {@category Composition}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy contextAware({
  bool requireDomain = true,
  bool requireCompliance = false,
  bool requireClearance = false,
  double minConfidence = 0.85,
  bool allowMissingConfidence = false,
}) {
  final policies = <Policy>[
    if (requireDomain) requiresDomainPolicy(),
    domainPolicy(),
    if (requireCompliance) compliancePolicy(),
    if (requireClearance) clearancePolicy(),
    confidencePolicy(
      min: minConfidence,
      allowMissing: allowMissingConfidence,
    ),
  ];
  return TestCell<Cell>.chain(policies);
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// The strictest composite: every stateless policy at once.
///
/// ### When to use
/// High-assurance enclaves — nothing untagged, uncompliant, low-clearance,
/// low-confidence, low-audit, or misclassified passes.
///
/// ### What it composes
/// `requiresDomainPolicy + domainPolicy + complianceOverlapPolicy +
/// authorityPolicy + clearancePolicy + isolationPolicy +
/// sensitivityPolicy + confidencePolicy + strategyPolicy(all) +
/// auditLevelPolicy`.
///
/// ### Non-obvious
/// - `actorPolicy`/`purposePolicy` are excluded — they require
///   allowlists that only the caller can supply; compose them on top.
/// - `notOlderThan` is excluded — it requires a clock; compose it on top.
///
/// {@category Policy}
/// {@category Composition}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy paranoid() {
  return TestCell<Cell>.chain([
    requiresDomainPolicy(),
    domainPolicy(),
    complianceOverlapPolicy(),
    authorityPolicy(),
    clearancePolicy(),
    isolationPolicy(),
    sensitivityPolicy(),
    confidencePolicy(),
    strategyPolicy(Set.of(ReasoningStrategy.values)),
    auditLevelPolicy(),
  ]);
}

// ── Custom ──────────────────────────────────────────────────────

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Wraps a plain predicate as a [Policy].
///
/// ### When to use
/// One-off custom checks — `predicatePolicy((object, {required host}) =>
/// object is Pulse && (object.payload as int) >= 0)`.
///
/// ### Non-obvious
/// - The predicate receives the same object dispatch as every factory:
///   [Pulse], [Function], or [Cell]. Decide yourself which types you
///   govern; returning `true` passes other types through.
/// - A `null` host fails closed (`false`) — there is no acceptor to
///   authorise against.
///
/// {@category Policy}
/// {@category Custom}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy predicatePolicy(
  bool Function(dynamic object, {required Cell host}) predicate,
) {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (host == null) return false;
    return predicate(object, host: host);
  });
}

// ── Learned ─────────────────────────────────────────────────────

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Accepts or rejects based on the cell's learned policy block.
///
/// ### When to use
/// Compose with structural policies to add learned-rule enforcement:
/// ```dart
/// final policy = contextAware() + learnedPolicy();
/// ```
/// `contextAware()` is frozen at 0.1.0 and does **not** consult the
/// learned block — the composition is explicit.
///
/// ### How it works
/// 1. Reads `host.context.constraints['cell_mind.policy']`.
/// 2. If absent or empty → returns `true` (no learned opinion).
/// 3. Builds the decision's context vector (pulse provenance + host
///    ontology dimensions).
/// 4. Iterates rules in confidence-descending order.
/// 5. The first rule whose `when` is a **subset** of the vector wins.
/// 6. Returns `true` for `'accept'`, `false` for `'reject'`.
/// 7. No match → `true` (pass through).
///
/// ### Non-obvious
/// - **Subset matching.** A rule `{when: {domains: 'marketing'}}`
///   matches a pulse whose domains are `'marketing,audit'` — rules
///   generalize.
/// - **First-match wins.** Rules are ordered by confidence.
/// - **Commands and links pass through in 0.3.0.** Only pulse shapes
///   are vectorized; command vectorization arrives with Phase 4.
///
/// {@category Policy}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Policy learnedPolicy() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (host == null) return true;
    if (object is! Pulse) return true; // Phase 4 vectorizes commands.
    final block = host.context.constraints?['cell_mind.policy'];
    if (block is! Map) return true;
    final rules = (block['rules'] as List?) ?? const [];
    if (rules.isEmpty) return true;

    final vector = ContextVector.ofHostPulse(host.context, object);
    for (final rule in rules) {
      if (rule is! Map) continue;
      final when = rule['when'];
      final action = rule['action'];
      if (when is! Map || action is! String) continue;
      if (!vector.matchesSubset(when)) continue;
      if (action == 'defer') return true; // Phase 4 interprets defer.
      return action == 'accept';
    }
    return true;
  });
}

// ── Verdict policies ────────────────────────────────────────────

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A policy that returns a full [Verdict] — including [Defer].
///
/// ### When to use
/// Use a `VerdictPolicy` when a decision needs richer semantics than
/// `bool` — specifically when the policy cannot decide and wants to
/// hand off to a resolver.
///
/// ### How it works
/// [call] returns [Accept], [Reject], or [Defer]. The runtime
/// interprets each:
/// - `Accept` → recorded; the pulse/command continues.
/// - `Reject` → recorded with the verdict's reason; dropped.
/// - `Defer` → the runtime invokes its `onDeferred` resolver and
///   records the resolved outcome.
///
/// ### Non-obvious
/// - **Not a [Policy].** The two types compose in separate slots —
///   `cognitive(policy:, verdictPolicy:)` — which prevents "bool loses
///   Defer" bugs from mixed composition.
/// - **`+` chains verdict policies.** A composite short-circuits on
///   the first `Accept` or `Reject`; only `Defer` propagates through.
/// - **Async verdicts are supported (1.1.0).** [call] may return a
///   `Future<Verdict>` — prompted policies must query an LLM before
///   they can decide. The recording runtime awaits the future before
///   recording the decision.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Approval}
///
/// **Stability:** Stable since `cell_mind 1.0.0`; async return type
/// since `cell_mind 1.1.0` (source-compatible for synchronous rules).
abstract interface class VerdictPolicy {
  /// Evaluates the rule and returns the verdict — synchronously or,
  /// since `1.1.0`, asynchronously (an LLM-backed policy).
  FutureOr<Verdict> call(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  });

  /// Chains two verdict policies: the first `Accept`/`Reject` wins;
  /// a `Defer` propagates to [other].
  VerdictPolicy operator +(VerdictPolicy other);
}

final class _VerdictPolicy implements VerdictPolicy {
  final FutureOr<Verdict> Function(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) _rule;

  const _VerdictPolicy(this._rule);

  @override
  FutureOr<Verdict> call(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) =>
      _rule(object, host: host, arguments: arguments);

  @override
  VerdictPolicy operator +(VerdictPolicy other) =>
      _CompositeVerdictPolicy(this, other);
}

final class _CompositeVerdictPolicy implements VerdictPolicy {
  final VerdictPolicy _first;
  final VerdictPolicy _second;

  const _CompositeVerdictPolicy(this._first, this._second);

  @override
  FutureOr<Verdict> call(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) {
    final first = _first.call(object, host: host, arguments: arguments);
    if (first is Future<Verdict>) {
      return first.then((verdict) => verdict is Defer
          ? _second.call(object, host: host, arguments: arguments)
          : verdict);
    }
    if (first is Defer) {
      return _second.call(object, host: host, arguments: arguments);
    }
    return first;
  }

  @override
  VerdictPolicy operator +(VerdictPolicy other) =>
      _CompositeVerdictPolicy(this, other);
}

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap`
///   entry point where one exists.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// Wraps a verdict-returning rule as a [VerdictPolicy].
///
/// ### When to use
/// Author rules that need `Defer`: threshold crossings, low
/// confidence, "ask a human" conditions.
///
/// ### Non-obvious
/// The rule may return a `Future<Verdict>` (since 1.1.0) — the
/// recording runtime awaits it before recording the decision.
///
/// {@category Policy}
/// {@category Approval}
///
/// **Stability:** Stable since `cell_mind 1.0.0`; async rule type
/// since `cell_mind 1.1.0` (source-compatible).
VerdictPolicy verdictPolicy(
  FutureOr<Verdict> Function(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) rule,
) =>
    _VerdictPolicy(rule);

/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A [VerdictPolicy] that reads the cell's learned policy block,
/// including `defer` rules.
///
/// ### When to use
/// Compose in the `verdictPolicy` slot of `cognitive(...)` when the
/// training loop has learned that some decisions should be deferred to
/// human review.
///
/// ### How it works
/// Same matching semantics as [learnedPolicy], but emits [Accept],
/// [Reject], or [Defer] from the rule's `action`:
/// - `'accept'` → [Accept] with the rule's annotations
/// - `'reject'` → [Reject] with the rule's `reason` (default
///   `'learned-reject'`) and annotations
/// - `'defer'` → [Defer] with the rule's `resolver` (default
///   `'approval'`) and annotations
///
/// ### Non-obvious
/// - **Not the same as [learnedPolicy].** `learnedPolicy()` returns
///   `bool` and passes `defer` rules through; this factory honours
///   them. Use one or the other per slot.
/// - **No matching rule is `Accept`** — the verdict slot composes
///   additively, so silence never blocks the structural gate.
///
/// {@category Policy}
/// {@category Approval}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
VerdictPolicy learnedVerdictPolicy() => _VerdictPolicy((
      object, {
      required host,
      arguments,
    }) {
      if (object is! Pulse) return const Accept();
      final block = host.context.constraints?['cell_mind.policy'];
      if (block is! Map) return const Accept();
      final rules = (block['rules'] as List?) ?? const [];
      if (rules.isEmpty) return const Accept();

      final vector = ContextVector.ofHostPulse(host.context, object);
      for (final rule in rules) {
        if (rule is! Map) continue;
        final when = rule['when'];
        final action = rule['action'];
        if (when is! Map || action is! String) continue;
        if (!vector.matchesSubset(when)) continue;
        final annotations = switch (rule['annotations']) {
          final Map m => m.cast<String, dynamic>(),
          _ => const <String, dynamic>{},
        };
        switch (action) {
          case 'accept':
            return Accept(annotations);
          case 'reject':
            final reason = rule['reason'];
            return Reject(
              reason is String ? reason : 'learned-reject',
              annotations,
            );
          case 'defer':
            final resolver = rule['resolver'];
            return Defer(
              resolver is String ? resolver : 'approval',
              annotations,
            );
        }
      }
      return const Accept();
    });

// ── Internal ────────────────────────────────────────────────────

/// Normalizes an optional domain/verb set: trimmed, lower-cased, no
/// blanks.
Set<String> _normalizeSet(Set<String>? raw) => (raw ?? const <String>{})
    .map((s) => s.trim().toLowerCase())
    .where((s) => s.isNotEmpty)
    .toSet();

/// The time-reading policy rule — declares `Purity.readOnlyExternal` and
/// a stable implementation version for the replay engine.
class _TimePolicyRule extends TestCell<Cell> with EffectfulReadOnly {
  _TimePolicyRule(super.rule);

  @override
  String get version => '1.0.0';
}
