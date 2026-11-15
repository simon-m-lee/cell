// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The structural pre-flight for a [PromptConfig].
///
/// Called automatically by [promptedPolicyWith] on the first decision
/// (not at factory time) — the registry path can therefore register a
/// config and wire the policy before any decision is made, and a bad
/// config fails at its first use with an [ArgumentError].
///
/// Checks structure, not semantics: whether the LLM will actually
/// comply with the schema is measured by `conform`, not by this.
void _validatePromptConfig(PromptConfig config) {
  final problems = <String>[];

  void check(bool condition, String message) {
    if (!condition) problems.add(message);
  }

  check(config.id.trim().isNotEmpty, 'id must be non-empty');
  check(config.version.trim().isNotEmpty, 'version must be non-empty');
  check(
    config.systemPrompt.trim().isNotEmpty,
    'systemPrompt must be non-empty',
  );
  check(
    config.userTemplate.trim().isNotEmpty,
    'userTemplate must be non-empty',
  );
  check(
    _schemaResponseKey(config.outputSchema) != null,
    'outputSchema must define a response shape '
    '(one of "verdict", "label", or "fields")',
  );
  check(!config.cacheTtl.isNegative, 'cacheTtl must be non-negative');
  check(config.maxPromptChars >= 100, 'maxPromptChars must be >= 100');

  for (var i = 0; i < config.examples.length; i++) {
    final example = config.examples[i];
    if (!_exampleResponseParses(example.response, config.outputSchema)) {
      problems.add(
        'examples[$i].response does not parse against the '
        'config\'s output schema',
      );
    }
  }

  if (problems.isNotEmpty) {
    throw ArgumentError(
      'PromptConfig "${config.id}" (version ${config.version}) is invalid: '
      '${problems.join('; ')}',
    );
  }
}

/// Which response key the schema promises: `verdict`, `label`, or
/// `fields` — `null` for a schema that promises none of them.
String? _schemaResponseKey(Map<String, dynamic> outputSchema) {
  for (final key in const ['verdict', 'label', 'fields']) {
    if (outputSchema.containsKey(key) ||
        outputSchema['required'] == key ||
        outputSchema['properties'] is Map &&
            (outputSchema['properties'] as Map).containsKey(key)) {
      return key;
    }
  }
  return null;
}

/// Whether one few-shot example response is structurally valid against
/// the config's output schema.
bool _exampleResponseParses(String response, Map<String, dynamic> schema) {
  final key = _schemaResponseKey(schema);
  if (key == null) return false;
  final decoded = _decodeJsonObject(response);
  if (decoded == null) return false;
  switch (key) {
    case 'verdict':
      final verdict = parseVerdict(response);
      return verdict is Accept || verdict is Defer || !_isParseError(verdict);
    case 'label':
      return decoded['label'] is String;
    case 'fields':
      return decoded['fields'] is Map;
    default:
      return false;
  }
}

/// Whether a `Reject` is one of the parser's own failure verdicts
/// (as opposed to a legitimate example rejection).
bool _isParseError(Verdict verdict) {
  if (verdict is! Reject) return false;
  return verdict.reason.startsWith('parse-error') ||
      verdict.reason == 'missing-verdict' ||
      verdict.reason.startsWith('unknown-verdict:') ||
      verdict.reason == 'missing-reason' ||
      verdict.reason == 'defer-missing-resolver';
}
