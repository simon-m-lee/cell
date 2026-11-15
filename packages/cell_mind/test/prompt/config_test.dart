// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('PromptConfig construction', () {
    test('policyDecider has stable id and version', () {
      final config = PromptConfig.policyDecider();
      expect(config.id, 'policy-decider');
      expect(config.version, '1.0.0');
    });

    test('classifier has stable id and carries the labels in its schema', () {
      final config = PromptConfig.classifier(labels: ['spam', 'ham']);
      expect(config.id, 'classifier');
      final schema = config.outputSchema;
      expect(
        (schema['properties'] as Map)['label'],
        {
          'type': 'string',
          'enum': ['spam', 'ham']
        },
      );
    });

    test('extractor has stable id and carries the fields in its schema', () {
      final config = PromptConfig.extractor(fields: ['amount', 'currency']);
      expect(config.id, 'extractor');
      final fields = ((config.outputSchema['properties'] as Map)['fields']
          as Map)['properties'] as Map;
      expect(fields.keys, containsAll(['amount', 'currency']));
    });

    test('custom supplies explicit defaults for optional fields', () {
      final config = PromptConfig.custom(
        id: 'custom-1',
        version: '2.0.0',
        description: 'd',
        systemPrompt: 'sys',
        userTemplate: '{{context}} {{decision}}',
      );
      expect(config.outputSchema, PromptConfig.defaultVerdictSchema);
      expect(config.examples, isEmpty);
      expect(config.cacheTtl, const Duration(hours: 1));
      expect(config.maxPromptChars, 32000);
      expect(config.parameters, {'temperature': 0.0, 'json_mode': true});
    });

    test('fields are immutable after construction', () {
      final config = PromptConfig.custom(
        id: 'i',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: 't',
        examples: const [
          PromptExample(
            context: 'c',
            decision: 'd',
            response: '{"verdict":"accept"}',
          ),
        ],
      );
      expect(
        () => (config.examples as List).add(
          const PromptExample(
            context: 'x',
            decision: 'y',
            response: '{"verdict":"accept"}',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(config.examples.single.response, '{"verdict":"accept"}');
    });

    test('default constructor accepts all fields explicitly', () {
      const config = PromptConfig(
        id: 'raw',
        version: '1.2.3',
        description: 'raw config',
        systemPrompt: 'sys',
        userTemplate: '{{context}}',
        maxPromptChars: 400,
        cacheTtl: Duration.zero,
      );
      expect(config.id, 'raw');
      expect(config.maxPromptChars, 400);
      expect(config.cacheTtl, Duration.zero);
    });

    test('validate passes for the three presets', () {
      PromptConfig.policyDecider().validate();
      PromptConfig.classifier(labels: ['a', 'b']).validate();
      PromptConfig.extractor(fields: ['x']).validate();
    });

    test('render is byte-identical for identical inputs', () {
      final config = PromptConfig.custom(
        id: 'r',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'sys',
        userTemplate: '{{context}}|{{decision}}',
        examples: const [],
      );
      final context = Context(domains: 'a,b', compliances: 'GDPR');
      final decision = Pulse<int>(1, type: 'p');
      final a = config.render(context: context, decision: decision);
      final b = config.render(context: context, decision: decision);
      expect(a, b);
    });

    test('render substitutes only the two placeholders', () {
      final config = PromptConfig.custom(
        id: 'r2',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'sys',
        userTemplate: 'Keep {{literal}} as-is: {{context}} / {{decision}}',
        examples: const [],
      );
      final out = config.render(context: Context.system, decision: 7);
      expect(out, contains('Keep {{literal}} as-is:'));
      expect(out, isNot(contains('{{context}}')));
      expect(out, isNot(contains('{{decision}}')));
    });

    test('PromptExample.render uses the fixed three-section format', () {
      const example = PromptExample(
        context: 'ctx',
        decision: 'dec',
        response: 'res',
      );
      expect(example.render(),
          'Context:\nctx\n\nDecision:\ndec\n\nResponse:\nres');
    });
  });
}
