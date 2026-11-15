// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Parses an LLM's raw response into a [Verdict], failing closed.
///
/// ### When to use
/// The default [VerdictParser] for [promptedPolicy] and
/// [promptedPolicyWith]. Also callable directly when you consume raw
/// model output outside the prompted policy pipeline.
///
/// ### How it works
/// 1. Locates the JSON object in the response — prose around it,
///    markdown fences, and trailing text are tolerated.
/// 2. Decodes it and reads the `verdict` field.
/// 3. `accept` → [Accept]; `reject` → [Reject] (its `reason` is
///    required); `defer` → [Defer] (its `resolver` is required).
/// 4. `reason`, `confidence`, and the custom `annotations` object are
///    carried into the verdict's annotations.
///
/// ### Non-obvious
/// - **Every error path returns `Reject`, never throws.** The exact
///   reason string is part of the audit trail:
///   `parse-error-invalid-json`, `parse-error-no-json`,
///   `missing-verdict`, `unknown-verdict:<value>`, `missing-reason`,
///   `defer-missing-resolver`.
/// - **Code fences are unwrapped before extraction.**
/// - **The first balanced JSON object wins** when the model embeds
///   several objects in prose.
///
/// ### See also
/// - [VerdictParser], `promptedPolicyWith`, `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - This parser is the security boundary for LLM output: prefer it
///   over hand-rolled parsing; never accept a raw model string as a
///   verdict without schema validation.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
Verdict parseVerdict(String rawResponse) {
  final extracted = _extractJsonText(rawResponse);
  if (extracted == null) return const Reject('parse-error-no-json');
  final decoded = _decodeJson(extracted);
  if (decoded is! Map) {
    return const Reject('parse-error-invalid-json');
  }
  final map = decoded.map((k, v) => MapEntry(k.toString(), v));

  final verdictValue = map['verdict'];
  if (verdictValue is! String) return const Reject('missing-verdict');

  final annotations = _annotationsOf(map);
  switch (verdictValue.trim().toLowerCase()) {
    case 'accept':
      return Accept(annotations);
    case 'reject':
      final reason = map['reason'];
      if (reason is! String || reason.trim().isEmpty) {
        return const Reject('missing-reason');
      }
      return Reject(reason, annotations);
    case 'defer':
      final resolver = map['resolver'];
      if (resolver is! String || resolver.trim().isEmpty) {
        return const Reject('defer-missing-resolver');
      }
      return Defer(resolver, annotations);
    default:
      return Reject('unknown-verdict:$verdictValue');
  }
}

/// The fail-closed extraction pipeline shared by [parseVerdict] and
/// the shape-dispatch in the prompted policy. Returns `null` when no
/// JSON object can be found or decoded.
Object? _decodeJson(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

/// Finds the first balanced JSON object in the response, tolerating
/// prose, markdown fences, and trailing text. Returns `null` when the
/// response contains no `{` at all; unbalanced braces yield the
/// substring from the first `{` so the decoder reports malformed JSON.
String? _extractJsonText(String rawResponse) {
  var text = rawResponse.trim();
  // Unwrap markdown code fences: ```json ... ``` (or plain ```).
  final fence = RegExp(r'^```[a-zA-Z]*\s*\n?', multiLine: false);
  text = text.replaceFirst(fence, '');
  if (text.endsWith('```')) {
    text = text.substring(0, text.length - 3).trimRight();
  }

  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  // Unbalanced braces: hand the raw text to jsonDecode, which fails —
  // the caller reports `parse-error-invalid-json`.
  return text.substring(start);
}

/// The annotations carried into a parsed verdict: the custom
/// `annotations` object plus `reason` and `confidence` when present.
Map<String, dynamic> _annotationsOf(Map<String, dynamic> map) {
  final annotations = <String, dynamic>{};
  final custom = map['annotations'];
  if (custom is Map) {
    annotations.addAll(custom.map((k, v) => MapEntry(k.toString(), v)));
  }
  final reason = map['reason'];
  if (reason is String && reason.trim().isNotEmpty) {
    annotations['reason'] = reason;
  }
  final confidence = map['confidence'];
  if (confidence is num) {
    annotations['confidence'] = confidence.toDouble();
  }
  return annotations;
}

/// Decodes [raw] to a JSON object map, or `null` when the response
/// contains no decodable JSON object. Shared by the shape dispatch.
Map<String, dynamic>? _decodeJsonObject(String raw) {
  final extracted = _extractJsonText(raw);
  if (extracted == null) return null;
  final decoded = _decodeJson(extracted);
  if (decoded is! Map) return null;
  return decoded.map((k, v) => MapEntry(k.toString(), v));
}
