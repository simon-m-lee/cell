// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// A canonical context vector — the bandit's bucketing key and the
/// learned rule's `when` block.
///
/// ### How it works
/// Dimensions are read from the decision's context and pulse provenance,
/// normalized to lowercase, sorted, comma-joined values. Empty
/// dimensions are omitted. The [key] is the canonical string
/// (`domains=finance,audit|actor=agent_a|...`) — O(1) bucketing with
/// stable ordering.
/// ### When to use
/// The declared purpose is stated above; this section pins the
/// canonical entry point and its prerequisites.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the `fromMap` entry
///   point paired with this type.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// {@category Organ}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class ContextVector {
  /// The canonical string key.
  final String key;

  /// The parsed dimensions, used as the rule's `when` block.
  final Map<String, String> when;

  const ContextVector(this.key, this.when);

  /// Builds the vector for a recorded decision (training side).
  factory ContextVector.of(Decision decision) => _build(
        context: decision.context,
        pulse: decision.pulse,
      );

  /// Builds the vector for an incoming pulse evaluated against a host
  /// (runtime matching side).
  factory ContextVector.ofHostPulse(Context context, Pulse pulse) => _build(
        context: context,
        pulse: pulse,
      );

  /// `true` when every dimension required by [ruleWhen] is present in
  /// this vector (subset semantics — a rule may require fewer
  /// dimensions than the vector carries).
  bool matchesSubset(Map<dynamic, dynamic> ruleWhen) {
    for (final entry in ruleWhen.entries) {
      final dimension = entry.key.toString();
      final required = entry.value.toString().toLowerCase();
      final current = when[dimension];
      if (current == null) return false;
      final currentParts = current.split(',').toSet();
      final requiredParts = required.split(',').toSet();
      if (!currentParts.containsAll(requiredParts)) return false;
    }
    return true;
  }

  static ContextVector _build({required Context context, Pulse? pulse}) {
    final dimensions = <String, String>{};

    void put(String dimension, String? raw) {
      final normalized = _normalizeList(raw);
      if (normalized.isNotEmpty) dimensions[dimension] = normalized;
    }

    put('domains', pulse?.context.domains ?? context.domains);
    final sourceDomains = pulse?.source?.context.domains;
    if (dimensions.containsKey('domains') == false && sourceDomains != null) {
      put('domains', sourceDomains);
    }
    put('compliance', pulse?.context.compliance ?? context.compliance);
    put(
        'authority',
        context[Mandate.authority] is String
            ? context[Mandate.authority]
            : null);
    put('actor', pulse?.context.actor);
    put('strategy', pulse?.context.strategy?.name);
    put('purpose', pulse?.context.purpose);

    final sorted = SplayTreeMap<String, String>.from(dimensions);
    final key = sorted.entries.map((e) => '${e.key}=${e.value}').join('|');
    return ContextVector(key, Map.unmodifiable(sorted));
  }

  static String _normalizeList(String? raw) {
    final parts = (raw ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return parts.join(',');
  }
}
