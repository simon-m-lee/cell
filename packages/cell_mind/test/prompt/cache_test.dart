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

  Future<void> applyOnce(
    CognitiveHandle handle,
    int arg,
  ) async {
    await handle.cognitive.apply<Object?>(commandFor(read, [arg]));
  }

  group('prompt cache — content addressing', () {
    test('identical decisions hit the cache (one LLM call)', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-hit',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 7);
      await applyOnce(handle, 7);
      expect(calls, 1);
    });

    test('different decisions miss the cache (two LLM calls)', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-diff',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 1);
      await applyOnce(handle, 2);
      expect(calls, 2);
    });

    test('a config version bump forces a cache miss', () async {
      var calls = 0;
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-version',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: journal,
        ),
      );
      await applyOnce(handle, 7);
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-version',
            version: '2.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle2, 7);
      expect(calls, 2);
    });

    test('a systemPrompt change forces a cache miss', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-sys',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 'first rules',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 7);
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-sys',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 'second rules',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle2, 7);
      expect(calls, 2);
    });

    test('cacheTtl zero disables caching', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-zero',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
            cacheTtl: Duration.zero,
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 7);
      await applyOnce(handle, 7);
      expect(calls, 2);
    });

    test('two policies sharing a config id+version share the cache', () async {
      var calls = 0;
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-shared',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle1, 7);
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-shared',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle2, 7);
      expect(calls, 1);
    });

    test('cache hits still journal one PromptEffect per decision', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-journal',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async => acceptResponse,
          journal: journal,
        ),
      );
      await applyOnce(handle, 7);
      await applyOnce(handle, 7);
      final promptEffects =
          journal.toJson().whereType<Map<String, Object?>>().where(
                (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
              );
      expect(promptEffects, hasLength(2));
    });

    test('errors are not cached', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'cache-errors',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            throw StateError('down');
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 7);
      await applyOnce(handle, 7);
      expect(calls, 2);
    });
  });
}
