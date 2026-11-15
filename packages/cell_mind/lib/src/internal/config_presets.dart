// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The default user template shared by the three presets. The
/// fragments carry their own `## Context` / `## Decision` headings
/// (see `renderContext` / `renderDecision`).
const String _defaultUserTemplate = '{{context}}\n\n{{decision}}';

/// The `policyDecider` preset (id `policy-decider`, version `1.0.0`):
/// `accept` / `reject` / `defer` verdicts.
PromptConfig _policyDeciderConfig({String? systemPrompt}) => PromptConfig(
      id: 'policy-decider',
      version: '1.0.0',
      description: 'The default accept/reject/defer policy engine.',
      systemPrompt: systemPrompt ?? defaultSystemPrompt,
      userTemplate: _defaultUserTemplate,
      outputSchema: PromptConfig.defaultVerdictSchema,
      examples: const [
        PromptExample(
          context: '- domains: finance,audit\n'
              '- compliance: GDPR\n'
              '- constraints: {"max_amount":10000}',
          decision: '- type: pulse\n'
              '- payload: {"amount":5000,"mfa_verified":true}\n'
              '- actor: system\n'
              '- confidence: 0.95',
          response: '{"verdict":"accept","reason":"within limit",'
              '"confidence":0.97}',
        ),
        PromptExample(
          context: '- domains: finance,audit\n'
              '- compliance: GDPR\n'
              '- constraints: {"max_amount":10000}',
          decision: '- type: pulse\n'
              '- payload: {"amount":25000,"mfa_verified":false}\n'
              '- actor: system\n'
              '- confidence: 0.91',
          response: '{"verdict":"reject","reason":"amount exceeds max_amount"}',
        ),
        PromptExample(
          context: '- domains: finance\n'
              '- constraints: {"max_amount":10000}',
          decision: '- type: pulse\n'
              '- payload: {"amount":9999,"customer":"new_entity"}\n'
              '- actor: system\n'
              '- confidence: 0.55',
          response: '{"verdict":"defer","resolver":"approval",'
              '"reason":"low confidence"}',
        ),
      ],
      parameters: const {'temperature': 0.0, 'json_mode': true},
    );

/// The `classifier` preset (id `classifier`, version `1.0.0`): maps a
/// decision to one of [labels]; `labelToVerdict` converts the label.
PromptConfig _classifierConfig({
  required List<String> labels,
  String? systemPrompt,
}) {
  final normalized = labels.map((l) => l.trim()).where((l) => l.isNotEmpty);
  final examples = normalized.isEmpty
      ? const <PromptExample>[]
      : [
          PromptExample(
            context: '- domains: support',
            decision: '- type: pulse\n- payload: {"text":"Hi there"}',
            response: '{"label":"${normalized.first}","confidence":0.9}',
          ),
        ];
  return PromptConfig(
    id: 'classifier',
    version: '1.0.0',
    description: 'Classifies a decision into one of the configured labels.',
    systemPrompt: systemPrompt ??
        'You are a classification engine for the Cell framework.\n'
            'Read the Context and the Decision, then respond ONLY with a '
            'JSON object matching the schema in the ## Expected Output '
            'section: {"label": "<one of the allowed labels>"}.',
    userTemplate: _defaultUserTemplate,
    outputSchema: {
      'type': 'object',
      'required': ['label'],
      'properties': {
        'label': {'type': 'string', 'enum': normalized.toList()},
        'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      },
    },
    examples: examples,
    parameters: const {'temperature': 0.0, 'json_mode': true},
  );
}

/// The `extractor` preset (id `extractor`, version `1.0.0`): extracts
/// structured [fields]; `extractionToVerdict` converts the map.
PromptConfig _extractorConfig({
  required List<String> fields,
  String? systemPrompt,
}) {
  final normalized = fields.map((f) => f.trim()).where((f) => f.isNotEmpty);
  return PromptConfig(
    id: 'extractor',
    version: '1.0.0',
    description: 'Extracts structured fields from the decision.',
    systemPrompt: systemPrompt ??
        'You are a structured extraction engine for the Cell framework.\n'
            'Read the Context and the Decision, then respond ONLY with a '
            'JSON object matching the schema in the ## Expected Output '
            'section: {"fields": {<field>: "<value>"}}.',
    userTemplate: _defaultUserTemplate,
    outputSchema: {
      'type': 'object',
      'required': ['fields'],
      'properties': {
        'fields': {
          'type': 'object',
          'properties': {
            for (final field in normalized) field: {'type': 'string'},
          },
        },
      },
    },
    parameters: const {'temperature': 0.0, 'json_mode': true},
  );
}
