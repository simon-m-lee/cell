// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Renders a [Context] into the `## Context` prompt fragment.
///
/// ### When to use
/// The default [ContextRenderer] for [promptedPolicy] and
/// [promptedPolicyWith]. Pass it (or a wrapper around it) as the
/// `contextRenderer:` parameter when you need the standard rendering
/// plus custom additions.
///
/// ### How it works
/// 1. Walks every typed [Ontology] dimension in the framework's
///    declaration order, reading `context[dimension]`.
/// 2. Then walks every [Mandate] dimension the same way — deputy
///    authority, clearance, isolation, and the rest appear after the
///    ontology block.
/// 3. Emits one `- name: value` line per non-empty dimension.
/// 4. Empty dimensions (null, blank string, empty list/map) are
///    omitted.
///
/// ### Non-obvious
/// - **Iteration order is declaration order, not map order.** This is
///   what makes rendered prompts byte-for-byte reproducible across
///   runs, processes, and platforms.
/// - **Map values are emitted as sorted-key JSON.** `constraints`
///   renders identically regardless of insertion order.
/// - **The `others` catch-all map is not rendered** — the public
///   [Context] interface does not expose it through a getter.
/// - **Lists join with commas; enums render as their names; dates as
///   ISO-8601 UTC.**
///
/// ### See also
/// - [renderDecision], [PromptConfig.render], `promptedPolicyWith`
///
/// ## AI Agent Guide
/// - Prefer this renderer over hand-rolled prompt fragments; it pins
///   determinism guarantees that the cache and replay rely on.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
String renderContext(Context context) {
  final lines = <String>[];
  for (final dimension in Ontology.values) {
    final value = context[dimension];
    if (_isEmptyDimension(value)) continue;
    lines.add('- ${dimension.name}: ${_dimensionText(value)}');
  }
  for (final dimension in Mandate.values) {
    final value = context[dimension];
    if (_isEmptyDimension(value)) continue;
    lines.add('- ${dimension.name}: ${_dimensionText(value)}');
  }
  if (lines.isEmpty) {
    return '## Context\n\n- (empty)';
  }
  return '## Context\n\n${lines.join('\n')}';
}

/// Whether a dimension value should be omitted from the render.
bool _isEmptyDimension(dynamic value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  if (value is Iterable && value.isEmpty) return true;
  if (value is Map && value.isEmpty) return true;
  return false;
}

/// The deterministic text form of one dimension value.
String _dimensionText(dynamic value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  if (value is Enum) return value.name;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) return _jsonEncodeDeterministic(value);
  if (value is Iterable) {
    return value.map((v) => _dimensionText(v)).join(',');
  }
  return value.toString();
}

/// Canonicalizes [value] for deterministic JSON encoding: maps are
/// sorted by key, enums become names, dates become ISO-8601 UTC, and
/// non-encodable values degrade to `toString()`.
Object? _canonicalize(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is Enum) return value.name;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    final entries = value.entries
        .map((e) => MapEntry(_keyText(e.key), _canonicalize(e.value)))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String, Object?>{for (final e in entries) e.key: e.value};
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  return value.toString();
}

/// Map keys are usually strings, but record/Symbol keys degrade to
/// readable text instead of crashing the encoder.
String _keyText(Object key) {
  if (key is Symbol) return '#${_symbolName(key)}';
  return key.toString();
}

/// The readable name of a [Symbol] (strips the `Symbol("...")` shell).
String _symbolName(Symbol symbol) {
  final raw = symbol.toString();
  if (raw.startsWith('Symbol("') && raw.endsWith('")')) {
    return raw.substring(8, raw.length - 2);
  }
  return raw;
}

/// JSON-encodes [value] deterministically — sorted map keys,
/// canonicalized leaves. The cache and replay fingerprint boundary
/// depend on this.
String _jsonEncodeDeterministic(Object? value) =>
    jsonEncode(_canonicalize(value));
