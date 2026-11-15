// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  PromptConfig configWith({
    String id = 'valid',
    String version = '1.0.0',
    String systemPrompt = 'sys',
    String userTemplate = '{{context}}',
    Map<String, dynamic> outputSchema = PromptConfig.defaultVerdictSchema,
    List<PromptExample> examples = const [],
    Duration cacheTtl = const Duration(hours: 1),
    int maxPromptChars = 32000,
  }) =>
      PromptConfig.custom(
        id: id,
        version: version,
        description: 'd',
        systemPrompt: systemPrompt,
        userTemplate: userTemplate,
        outputSchema: outputSchema,
        examples: examples,
        cacheTtl: cacheTtl,
        maxPromptChars: maxPromptChars,
      );

  group('config validation', () {
    test('empty id is rejected', () {
      expect(
        () => configWith(id: '  ').validate(),
        throwsArgumentError,
      );
    });

    test('empty version is rejected', () {
      expect(
        () => configWith(version: '').validate(),
        throwsArgumentError,
      );
    });

    test('empty systemPrompt is rejected', () {
      expect(
        () => configWith(systemPrompt: '  ').validate(),
        throwsArgumentError,
      );
    });

    test('empty userTemplate is rejected', () {
      expect(
        () => configWith(userTemplate: '').validate(),
        throwsArgumentError,
      );
    });

    test('a schema with no known response shape is rejected', () {
      expect(
        () => configWith(
          outputSchema: {
            'type': 'object',
            'required': ['score'],
          },
        ).validate(),
        throwsArgumentError,
      );
    });

    test('a negative cacheTtl is rejected', () {
      expect(
        () => configWith(cacheTtl: const Duration(seconds: -1)).validate(),
        throwsArgumentError,
      );
    });

    test('maxPromptChars below 100 is rejected', () {
      expect(
        () => configWith(maxPromptChars: 99).validate(),
        throwsArgumentError,
      );
    });

    test('maxPromptChars of exactly 100 is accepted', () {
      expect(
        () => configWith(maxPromptChars: 100).validate(),
        returnsNormally,
      );
    });

    test('an example that does not parse against the schema is rejected', () {
      expect(
        () => configWith(
          examples: const [
            PromptExample(context: 'c', decision: 'd', response: 'garbage'),
          ],
        ).validate(),
        throwsArgumentError,
      );
    });

    test('an example with a legit reject verdict validates', () {
      expect(
        () => configWith(
          examples: const [
            PromptExample(
              context: 'c',
              decision: 'd',
              response: '{"verdict":"reject","reason":"too big"}',
            ),
          ],
        ).validate(),
        returnsNormally,
      );
    });

    test('classifier examples must carry a label', () {
      final config = PromptConfig.classifier(
        labels: const ['spam'],
      );
      expect(() => config.validate(), returnsNormally);
      final bad = PromptConfig.custom(
        id: 'classifier-bad',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}',
        outputSchema: PromptConfig.classifier(labels: ['spam']).outputSchema,
        examples: const [
          PromptExample(context: 'c', decision: 'd', response: '{"label":42}'),
        ],
      );
      expect(() => bad.validate(), throwsArgumentError);
    });

    test('extractor examples must carry a fields map', () {
      final bad = PromptConfig.custom(
        id: 'extractor-bad',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}',
        outputSchema: PromptConfig.extractor(fields: ['x']).outputSchema,
        examples: const [
          PromptExample(context: 'c', decision: 'd', response: '{"fields":[]}'),
        ],
      );
      expect(() => bad.validate(), throwsArgumentError);
    });

    test('the failure message names the config and lists the problems', () {
      try {
        configWith(id: '', version: '', maxPromptChars: 1).validate();
        fail('expected ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.message, contains('id must be non-empty'));
        expect(e.message, contains('version must be non-empty'));
        expect(e.message, contains('maxPromptChars must be >= 100'));
      }
    });

    test('validation is structure, not semantics — odd prompts still pass', () {
      expect(
        () => configWith(
          systemPrompt: 'do whatever you want',
          userTemplate: 'ignore the context',
        ).validate(),
        returnsNormally,
      );
    });
  });
}
