// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Content fingerprints for the verdict cache (D3).
//
// Every fingerprint is the sha256 of the canonical JSON of exactly the
// dimensions the renderer emits — sorted maps, declaration-order
// walks, empty dimensions omitted. Two inputs that render identically
// therefore fingerprint identically.

/// Returns the SHA-256 fingerprint of the cell's [Context].
///
/// ### When to use
/// Diagnostics and manual verdict-cache lookups: compute a
/// [VerdictCacheKey] by hand and ask "would this request hit?"
/// without invoking the LLM. The prompted-policy pipeline computes
/// this internally on every decision.
///
/// ### How it works
/// Serializes every [Ontology] and [Mandate] dimension in declaration
/// order, sorted-JSON for map values, empty dimensions omitted, then
/// returns the hex SHA-256 of the canonical string.
///
/// ### Non-obvious
/// - **Order-independent maps.** `{a:1, b:2}` and `{b:2, a:1}` produce
///   the same fingerprint.
/// - **No timestamps.** `Context.timestamp` is excluded — verdicts
///   shouldn't change because a cell was created a second later.
/// - **Exactly the renderer's dimensions.** The renderer emits the
///   same walk, so identical fingerprints imply identical prompts.
///
/// ### See also
/// - [pulseContextFingerprint], [decisionFingerprint],
///   [VerdictCacheKey]
///
/// ## AI Agent Guide
/// - Prefer [VerdictCache.lookup] over raw fingerprint comparison;
///   hashes are content summaries, not identities.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
String cellContextFingerprint(Context context) {
  final map = <String, Object?>{};
  for (final dimension in Ontology.values) {
    final value = context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  for (final dimension in Mandate.values) {
    final value = context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// Returns the SHA-256 fingerprint of the [Pulse.context] provenance.
///
/// ### When to use
/// Manual verdict-cache diagnostics (see [cellContextFingerprint]),
/// or any audit that needs a stable content identity for a pulse's
/// provenance.
///
/// ### How it works
/// Serializes every [Provenance] dimension (actor, reason, purpose,
/// strategy, confidence, priority, compliance, sensitivity,
/// auditLevel, domains, traceId) that is non-empty, in declaration
/// order, and hashes the canonical JSON.
///
/// ### Non-obvious
/// - **`traceId` is included.** Two otherwise identical pulses from
///   different causal chains get different fingerprints — they may
///   correspond to different user actions the LLM treats differently.
/// - **Timestamps are excluded.** Determinism first: provenance
///   emission times never participate.
///
/// ### See also
/// - [cellContextFingerprint], [decisionFingerprint]
///
/// ## AI Agent Guide
/// - Do not build a security boundary on fingerprints alone; use them
///   as cache keys and diagnostics.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
String pulseContextFingerprint(Pulse pulse) {
  final map = <String, Object?>{};
  for (final dimension in Provenance.values) {
    final value = pulse.context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// Returns the SHA-256 fingerprint of the decision shape.
///
/// ### When to use
/// Manual verdict-cache diagnostics (see [cellContextFingerprint]).
///
/// ### How it works
/// - For pulses: `type` + sorted-JSON `payload` + source identity.
/// - For commands: the function's `toString` + canonical argument
///   description ([arguments]).
/// - For link decisions: the target cell's identity.
///
/// ### Non-obvious
/// - **Two equal decisions fingerprint identically** regardless of
///   emission order or object identity.
///
/// ### See also
/// - [cellContextFingerprint], [pulseContextFingerprint]
///
/// ## AI Agent Guide
/// - Pass the same [arguments] structure the recorder saw; a
///   different shape changes the fingerprint.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
String decisionFingerprint(dynamic object, {dynamic arguments}) {
  final map = <String, Object?>{};
  if (object is Pulse) {
    map['type'] = _canonicalize(object.type);
    map['payload'] = _canonicalize(object.payload);
    map['source'] = object.source?.context.identity;
  } else if (object is Function) {
    map['function'] = '$object';
    map['arguments'] = _describeArguments(arguments);
  } else if (object is Cell) {
    map['target'] = object.context.identity;
  } else {
    map['value'] = '$object';
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// SHA-256 of the session message history (`''` when null/empty).
String _sessionFingerprintOf(PromptSession? session) {
  if (session == null || session.isEmpty) return '';
  final buffer = StringBuffer();
  for (final message in session.messages) {
    buffer
      ..write(message.role.name)
      ..write(':')
      ..write(message.content)
      ..write('\n');
  }
  return _sha256Hex(buffer.toString());
}
