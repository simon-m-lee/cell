// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Internal helpers shared by the policy factories. Everything here is
// private to the `cell_mind` library and unit-tested through the public
// factories.

/// Parses a comma-separated string into a normalized, trimmed,
/// lower-cased set. Empty segments are dropped.
Set<String> _parseCommaList(String? raw) => (raw ?? '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .where((s) => s.isNotEmpty)
    .toSet();

/// Extracts a verb from a function reference.
///
/// ### How it works
/// 1. Uses [resolver] if provided.
/// 2. Otherwise, extracts from `function.toString()` via the regex
///    `Function '(\w+)'` — the VM shape for named method tear-offs
///    (`Closure: (int) => int from Function 'credit':.`).
/// 3. Otherwise returns `null` (unresolvable — callers fail closed).
///
/// ### Non-obvious
/// Anonymous lambdas produce no match (`Closure: (int) => int`) — use a
/// custom `verbResolver`, or prefer `exactFunctionsPolicy` for curated
/// API surfaces.
String? _extractVerb(Function function,
    {String? Function(Function)? resolver}) {
  if (resolver != null) return resolver(function);
  final match = RegExp(r"Function '(\w+)'").firstMatch(function.toString());
  return match?.group(1);
}

/// `true` when every element of [subset] is present in [superset].
bool _isSubset(Set<String> subset, Set<String> superset) =>
    subset.every(superset.contains);

/// Resolves the origin domains of a pulse.
///
/// ### How it works
/// - No source cell → trust the pulse's own `PulseContext.domains`.
/// - Source cell untagged → trust the pulse's claim.
/// - Pulse untagged → trust the source cell's declared domains.
/// - Both tagged → the pulse claim must be a subset of the source's
///   claim, otherwise a [StateError] is thrown (provenance mismatch —
///   a caller bug that must fail loudly, not silently reject).
Set<String> _originDomains(Pulse pulse) {
  final pulseDomains = _parseCommaList(pulse.context.domains);
  final source = pulse.source;
  if (source == null) return pulseDomains;
  final sourceDomains = _parseCommaList(source.context.domains);
  if (sourceDomains.isEmpty) return pulseDomains;
  if (pulseDomains.isEmpty) return sourceDomains;
  if (!_isSubset(pulseDomains, sourceDomains)) {
    throw StateError(
      'Provenance mismatch: pulse domains $pulseDomains exceed '
      'source cell domains $sourceDomains.',
    );
  }
  return pulseDomains;
}

/// Reads the acceptor's declared authority verb whitelist.
///
/// Authority is a `Mandate` dimension carried by [DeputyContext]; a plain
/// [Context] has none. `cell` 1.1.0 exposes the dimension through the
/// context index operator (`context[Mandate.authority]`), not a getter.
Set<String> _readAuthority(Context context) => context is DeputyContext
    ? _parseCommaList(context[Mandate.authority] as String?)
    : const {};

/// Reads the acceptor's clearance tier.
///
/// `Mandate.clearance` lives on [DeputyContext]; a plain [Context]
/// defaults to [Clearance.standard] (the framework's operational tier).
Clearance _readClearance(Context context) =>
    context is DeputyContext ? context.clearance : Clearance.standard;

/// Reads the acceptor's isolation tier, or `null` when the context is a
/// plain [Context] (no deputy mandate, no isolation constraint).
Isolation? _readIsolation(Context context) =>
    context is DeputyContext ? context.isolation : null;

/// Reads the acceptor's maximum sensitivity from
/// `constraints['max_sensitivity']`.
///
/// The value is the enum *name* (e.g. `'confidential'`) or a
/// [Sensitivity] enum value. Missing or unknown names fall back to
/// [Sensitivity.public] — the most restrictive default (fail-closed).
Sensitivity _readMaxSensitivity(Context context) {
  final raw = context.constraints?['max_sensitivity'];
  if (raw is Sensitivity) return raw;
  if (raw is String) {
    for (final s in Sensitivity.values) {
      if (s.name == raw) return s;
    }
  }
  return Sensitivity.public;
}
