// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('PromptConfig serialization', () {
    test('toMap is JSON-encodable and round-trips via fromMap', () {
      final config = PromptConfig.custom(
        id: 'fraud-v1',
        version: '1.2.0',
        description: 'Fraud screening',
        systemPrompt: 'You are a fraud screener.',
        userTemplate: '{{context}}\n\n{{decision}}',
        outputSchema: PromptConfig.defaultVerdictSchema,
        examples: const [
          PromptExample(
            context: '## Context\n\n- domains: finance',
            decision: '## Decision\n\n- type: pulse',
            response: '{"verdict":"accept","reason":"ok"}',
          ),
        ],
        parameters: const {'temperature': 0.2, 'json_mode': true},
        cacheTtl: const Duration(minutes: 30),
        maxPromptChars: 8000,
      );
      final map = config.toMap();
      expect(jsonEncode(map), isA<String>());
      final restored = PromptConfig.fromMap(map);
      expect(restored.id, config.id);
      expect(restored.version, config.version);
      expect(restored.description, config.description);
      expect(restored.systemPrompt, config.systemPrompt);
      expect(restored.userTemplate, config.userTemplate);
      expect(restored.outputSchema, config.outputSchema);
      expect(
          restored.examples.single.render(), config.examples.single.render());
      expect(restored.parameters, config.parameters);
      expect(restored.cacheTtl, config.cacheTtl);
      expect(restored.maxPromptChars, config.maxPromptChars);
    });

    test('cacheTtl serializes as milliseconds', () {
      final map = PromptConfig.custom(
        id: 't',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: 'u',
        cacheTtl: const Duration(hours: 1),
      ).toMap();
      expect(map['cacheTtl'], 3600000);
    });

    test('presets round-trip through JSON files', () {
      for (final config in [
        PromptConfig.policyDecider(),
        PromptConfig.classifier(labels: ['a', 'b']),
        PromptConfig.extractor(fields: ['x', 'y']),
      ]) {
        final restored = PromptConfig.fromMap(
          jsonDecode(jsonEncode(config.toMap())) as Map<String, dynamic>,
        );
        expect(restored.id, config.id);
        expect(restored.version, config.version);
        expect(restored.outputSchema, config.outputSchema);
        expect(restored.examples.length, config.examples.length);
      }
    });

    test('fromMap tolerates absent optional fields', () {
      final restored = PromptConfig.fromMap({
        'id': 'min',
        'version': '1.0.0',
        'systemPrompt': 's',
        'userTemplate': 'u',
      });
      expect(restored.id, 'min');
      expect(restored.outputSchema, PromptConfig.defaultVerdictSchema);
      expect(restored.cacheTtl, const Duration(hours: 1));
      expect(restored.maxPromptChars, 32000);
      restored.validate();
    });

    test('PromptExample round-trips', () {
      const example = PromptExample(
        context: 'ctx',
        decision: 'dec',
        response: 'res',
      );
      final restored = PromptExample.fromMap(example.toMap());
      expect(restored.context, 'ctx');
      expect(restored.decision, 'dec');
      expect(restored.response, 'res');
    });

    test('PromptExample.fromMap tolerates absent fields', () {
      final restored = PromptExample.fromMap(const {});
      expect(restored.context, '');
      expect(restored.decision, '');
      expect(restored.response, '');
    });

    test('a restored config validates like the original', () {
      final config = PromptConfig.policyDecider();
      final restored = PromptConfig.fromMap(config.toMap());
      restored.validate();
      expect(
        restored.render(context: Context.system, decision: 1),
        config.render(context: Context.system, decision: 1),
      );
    });

    test('config file workflow: write, read, register, lookup', () {
      final file = PromptConfig.custom(
        id: 'file-config',
        version: '3.0.0',
        description: 'shipped as a file',
        systemPrompt: 'sys',
        userTemplate: '{{context}}',
      );
      final encoded = jsonEncode(file.toMap());
      final loaded = PromptConfig.fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      PromptConfigRegistry.register(loaded);
      expect(
        PromptConfigRegistry.lookup('file-config')!.version,
        '3.0.0',
      );
      PromptConfigRegistry.unregister('file-config');
    });
  });
}
