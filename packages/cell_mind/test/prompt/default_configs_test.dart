// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('preset configs', () {
    test('policyDecider validates and renders the universal format', () {
      final config = PromptConfig.policyDecider();
      config.validate();
      final rendered = config.render(
        context: Context(domains: 'finance'),
        decision: Pulse<int>(1, type: 'tx'),
      );
      expect(rendered, contains('## Context'));
      expect(rendered, contains('## Decision'));
      expect(rendered, contains('## Expected Output'));
      expect(rendered, contains('"verdict"'));
      expect(rendered, contains('"enum":["accept","reject","defer"]'));
    });

    test('policyDecider ships three few-shot examples', () {
      final config = PromptConfig.policyDecider();
      expect(config.examples, hasLength(3));
      for (final example in config.examples) {
        expect(example.render(), contains('Context:'));
        expect(example.render(), contains('Decision:'));
        expect(example.render(), contains('Response:'));
      }
    });

    test('policyDecider examples parse to valid verdicts', () {
      for (final example in PromptConfig.policyDecider().examples) {
        final verdict = parseVerdict(example.response);
        expect(
          verdict,
          anyOf(isA<Accept>(), isA<Reject>(), isA<Defer>()),
        );
      }
    });

    test('classifier validates and its schema enumerates the labels', () {
      final config = PromptConfig.classifier(labels: ['spam', 'ham']);
      config.validate();
      final rendered = config.render(
        context: Context.system,
        decision: Pulse<int>(1),
      );
      expect(rendered, contains('"label"'));
      expect(rendered, contains('"enum":["spam","ham"]'));
    });

    test('classifier ignores blank labels', () {
      final config = PromptConfig.classifier(labels: ['spam', '  ', '']);
      final schema = config.outputSchema;
      expect(
        (schema['properties'] as Map)['label'],
        {
          'type': 'string',
          'enum': ['spam']
        },
      );
    });

    test('extractor validates and its schema enumerates the fields', () {
      final config = PromptConfig.extractor(fields: ['amount', 'currency']);
      config.validate();
      final rendered = config.render(
        context: Context.system,
        decision: Pulse<int>(1),
      );
      expect(rendered, contains('"fields"'));
      expect(rendered, contains('"amount"'));
      expect(rendered, contains('"currency"'));
    });

    test('preset ids and versions are the stable registry keys', () {
      expect(PromptConfig.policyDecider().id, 'policy-decider');
      expect(PromptConfig.classifier(labels: ['a']).id, 'classifier');
      expect(PromptConfig.extractor(fields: ['a']).id, 'extractor');
      for (final config in [
        PromptConfig.policyDecider(),
        PromptConfig.classifier(labels: ['a']),
        PromptConfig.extractor(fields: ['a']),
      ]) {
        expect(config.version, '1.0.0');
      }
    });

    test('custom systemPrompt overrides the preset default', () {
      final config = PromptConfig.policyDecider(systemPrompt: 'Custom rules');
      expect(config.systemPrompt, 'Custom rules');
      config.validate();
      final rendered = config.render(
        context: Context.system,
        decision: 1,
      );
      expect(rendered, startsWith('Custom rules'));
    });
  });
}
