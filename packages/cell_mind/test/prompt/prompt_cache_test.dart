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

  Future<void> applyOnce(CognitiveHandle handle, int arg) async {
    await handle.cognitive.apply<Object?>(commandFor(read, [arg]));
  }

  group('prompt cache — second tier', () {
    test('a prompt-cache hit skips the LLM when the verdict cache misses',
        () async {
      // Policy 1 populates both caches. Policy 2 has a FRESH verdict
      // cache (per-instance default) but the same rendered prompt —
      // the shared prompt cache serves it without an LLM call.
      var calls = 0;
      final config = PromptConfig.custom(
        id: 'pc-second-tier',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
      );
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle1, 7);
      expect(calls, 1);

      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle2, 7);
      expect(calls, 1, reason: 'the shared prompt cache serves the repeat');
    });

    test(
        'the prompt cache is output-keyed: different verdict caches do '
        'not matter', () async {
      var calls = 0;
      final config = PromptConfig.custom(
        id: 'pc-output-keyed',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        verdictCacheTtl: Duration.zero, // verdict cache off entirely
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle, 7);
      await applyOnce(handle, 7);
      expect(calls, 1, reason: 'prompt cache alone serves the repeat');
    });

    test('a version bump invalidates prompt cache entries', () async {
      var calls = 0;
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'pc-version',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
            verdictCacheTtl: Duration.zero,
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
            id: 'pc-version',
            version: '2.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
            verdictCacheTtl: Duration.zero,
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

    test('session history participates in the rendered-prompt key', () async {
      var calls = 0;
      final config = PromptConfig.custom(
        id: 'pc-session-key',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
        verdictCacheTtl: Duration.zero,
      );
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle1, 1);
      // Same config, fresh policy + fresh session → same empty-history
      // prompt → prompt cache hit.
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle2, 1);
      expect(calls, 1);
      // Now advance the second session and repeat: the prompt includes
      // history → different rendered prompt → prompt cache miss.
      await applyOnce(handle2, 2);
      expect(calls, 2);
    });

    test('prompt-cache hits append to the session and record cache hits',
        () async {
      final journal = RecordingJournal();
      final config = PromptConfig.custom(
        id: 'pc-journal',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
      );
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
      );
      await applyOnce(handle1, 7);
      // Fresh policy (fresh verdict cache) over the shared prompt
      // cache: the repeat renders, hits the prompt cache, appends to
      // the new session, and journals VerdictCacheHitEffect.
      final src2 = Cell.ingress<int>();
      final policy2 = promptedPolicyWith(
        config: config,
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy2,
      );
      await applyOnce(handle2, 7);
      expect(policy2.session!.length, 2,
          reason: 'prompt-cache hits DO append the exchange (D14)');
      final records = journal.toJson().whereType<Map<String, Object?>>();
      final cacheHits = records.where(
        (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt.cache.hit',
      );
      final appends = records.where(
        (e) => e['kind'] == 'io' && e['label'] == 'mind.session.append',
      );
      expect(cacheHits, isNotEmpty);
      expect(appends, hasLength(1),
          reason: 'policy2\'s journal holds its own append only');
    });
  });
}
