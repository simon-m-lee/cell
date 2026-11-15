// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Read/merge/write helpers for the learned policy block at
// `Ontology.constraints['cell_mind.policy']`. The merge respects the
// Phase 0 F1 finding: `Context.evolve` REPLACES the constraints map on
// a non-null resolver, so merging happens here, before the single
// evolve call.

/// Reads the learned block from [context], or an empty block.
Map<String, dynamic> _readPolicyBlock(Context context) {
  final raw = context.constraints?['cell_mind.policy'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// The canonical identity of a rule — sorted `when` dimensions joined.
String _ruleKey(Map<dynamic, dynamic> rule) {
  final when = rule['when'];
  if (when is! Map) return rule.toString();
  final entries = when.entries
      .map((e) => '${e.key}=${e.value.toString().toLowerCase()}')
      .toList()
    ..sort();
  return entries.join('|');
}

/// The next block version: existing + 1 (1 for a fresh block).
int _nextPolicyVersion(Context context) {
  final block = _readPolicyBlock(context);
  final current = block['version'];
  return current is int ? current + 1 : 1;
}

/// The canonical serialization of a `when` map — used for effect
/// records and pruning audit.
Map<String, dynamic> _canonicalWhen(Map<dynamic, dynamic> when) => {
      for (final entry in when.entries)
        entry.key.toString(): entry.value.toString(),
    };

/// Merges [emitted] rules into [existing], per D5:
///
/// - `prune: true` → full replacement: only [emitted] rules survive.
/// - `prune: false` (default) → additive: new rules replace existing
///   rules with the same `when` key; other existing rules are
///   preserved with their original `trainedIn` versions.
Map<String, dynamic> _mergePolicyBlock({
  required Map<String, dynamic> existing,
  required List<Map<String, dynamic>> emitted,
  required TrainingConfig config,
  required int version,
}) {
  if (config.prune) {
    return {
      'version': version,
      'algorithm': 'contextualBandit',
      'rules': emitted,
    };
  }

  final rules = <Map<String, dynamic>>[...emitted];
  final emittedKeys = emitted.map(_ruleKey).toSet();
  final existingRules = (existing['rules'] as List?) ?? const [];
  for (final rule in existingRules) {
    if (rule is! Map) continue;
    if (emittedKeys.contains(_ruleKey(rule))) continue;
    rules.add(rule.cast<String, dynamic>());
  }
  rules.sort((a, b) => ((b['confidence'] as num?) ?? 0)
      .toDouble()
      .compareTo(((a['confidence'] as num?) ?? 0).toDouble()));
  return {
    'version': version,
    'algorithm': 'contextualBandit',
    'rules': rules,
  };
}
