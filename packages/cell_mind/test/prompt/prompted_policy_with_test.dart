// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/prompt_fixtures.dart';

void main() {
  int read(int x) => x;

  tearDown(() {
    for (final config in PromptConfigRegistry.list()) {
      PromptConfigRegistry.unregister(config.id);
    }
  });

  group('promptedPolicyWith (config mode)', () {
    test('policyDecider config drives the verdict', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'with-policydecider',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 'Decide.',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: mockPrompt(rejectResponse),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'policy violation');
    });

    test('resolves a config through the registry via configId', () async {
      PromptConfigRegistry.register(
        PromptConfig.custom(
          id: 'with-registry',
          version: '1.0.0',
          description: 'd',
          systemPrompt: 'Decide.',
          userTemplate: '{{context}}\n\n{{decision}}',
        ),
      );
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          configId: 'with-registry',
          prompt: mockPrompt(acceptResponse),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      expect(handle.decisions.single.verdict, isA<Accept>());
    });

    test('pins a registry config to a specific version', () async {
      PromptConfigRegistry.register(
        PromptConfig.custom(
          id: 'with-pin',
          version: '1.0.0',
          description: 'v1',
          systemPrompt: 'v1 rules',
          userTemplate: '{{context}}',
        ),
      );
      final v2 = PromptConfig.custom(
        id: 'with-pin',
        version: '2.0.0',
        description: 'v2',
        systemPrompt: 'v2 rules',
        userTemplate: '{{context}}',
      );
      PromptConfigRegistry.register(v2);
      final prompts = <String>[];
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          configId: 'with-pin',
          configVersion: '1.0.0',
          prompt: mockPrompt(acceptResponse, log: prompts),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(prompts.single, isNot(contains('v2 rules')));
    });

    test('defaults to the highest registry version', () async {
      PromptConfigRegistry.register(
        PromptConfig.custom(
          id: 'with-highest',
          version: '1.0.0',
          description: 'older',
          systemPrompt: 'older rules',
          userTemplate: '{{context}}',
        ),
      );
      PromptConfigRegistry.register(
        PromptConfig.custom(
          id: 'with-highest',
          version: '1.5.0',
          description: 'newer',
          systemPrompt: 'newer rules',
          userTemplate: '{{context}}',
        ),
      );
      final prompts = <String>[];
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          configId: 'with-highest',
          prompt: mockPrompt(acceptResponse, log: prompts),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      expect(prompts.single, contains('newer rules'));
    });

    test('classifier mode maps the label via labelToVerdict', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.classifier(labels: ['spam', 'ham']),
          prompt: mockPrompt('{"label":"spam","confidence":0.98}'),
          journal: journal,
          labelToVerdict: (label) =>
              label == 'spam' ? const Reject('spam detected') : const Accept(),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'spam detected');
    });

    test('classifier without labelToVerdict fails closed', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.classifier(labels: ['spam']),
          prompt: mockPrompt('{"label":"spam"}'),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'missing-label-to-verdict');
    });

    test('extractor mode maps the fields via extractionToVerdict', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.extractor(fields: ['amount']),
          prompt: mockPrompt('{"fields":{"amount":"25000"}}'),
          journal: journal,
          extractionToVerdict: (fields) =>
              (int.tryParse(fields['amount'] as String? ?? '0') ?? 0) > 10000
                  ? const Reject('amount too large')
                  : const Accept(),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [3]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'amount too large');
    });

    test('extractor without extractionToVerdict fails closed', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.extractor(fields: ['amount']),
          prompt: mockPrompt('{"fields":{"amount":"5"}}'),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [4]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'missing-extraction-to-verdict');
    });

    test('rejects when neither config nor configId is given', () {
      expect(
        () => promptedPolicyWith(
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects when both config and configId are given', () {
      expect(
        () => promptedPolicyWith(
          config: PromptConfig.policyDecider(),
          configId: 'policy-decider',
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
        throwsArgumentError,
      );
    });

    test('throws for an unregistered configId', () {
      expect(
        () => promptedPolicyWith(
          configId: 'missing-config',
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
        throwsArgumentError,
      );
    });

    test('validates the config on the first decision, not at factory time',
        () async {
      final bad = PromptConfig.custom(
        id: 'bad',
        version: '',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}',
      );
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: bad,
          prompt: mockPrompt(acceptResponse),
          journal: journal,
        ),
      );
      expect(
        () async => handle.cognitive.apply<Object?>(commandFor(read, [7])),
        throwsArgumentError,
      );
    });

    test('journals the config id and version on every effect', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(acceptResponse),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      final raw = journal.toJson().whereType<Map<String, Object?>>().firstWhere(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
          )['rawOutput'] as Map;
      expect(raw['configId'], startsWith('tiny-'));
      expect(raw['configVersion'], '1.0.0');
    });
  });
}
