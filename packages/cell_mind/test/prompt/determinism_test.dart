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

  group('prompt determinism', () {
    test('replaying a recorded session does not re-invoke the LLM', () async {
      var calls = 0;
      final recording = RecordingJournal();
      // Recording and replay must share the same config instance: the
      // disposition input includes the config id (via the verdict
      // cache key).
      final config = tinyConfig();
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
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));

      // Replay with an adapter that would return a DIFFERENT verdict —
      // it must never run.
      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async {
            calls++;
            return rejectResponse;
          },
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 1, reason: 'Replay must serve the recorded response.');
      expect(handle2.decisions.single.verdict, isA<Accept>());
      replay.assertExhausted();
    });

    test('replaying a dedicated-session recording reconstructs the history',
        () async {
      var calls = 0;
      final recording = RecordingJournal();
      final config = tinyConfig(sessionMode: SessionMode.dedicated);
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
          journal: recording,
        ),
      );
      // Two decisions: the second one renders the first turn as
      // history. Recording and replay share the config instance (its id
      // participates in the disposition inputs).
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      await handle.cognitive.apply<Object?>(commandFor(read, [8]));
      expect(calls, 2);

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      // Replay with the SAME config instance (id participates in disposition inputs).
      final src2 = Cell.ingress<int>();
      final replayPolicy = promptedPolicyWith(
        config: config,
        prompt: (_) async {
          calls++;
          return rejectResponse;
        },
        journal: replay,
      );
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: replayPolicy,
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      await handle2.cognitive.apply<Object?>(commandFor(read, [8]));
      expect(calls, 2, reason: 'Replay never invokes the LLM.');
      expect(replayPolicy.session!.length, 4,
          reason: 'The conversation is reconstructed from served appends.');
      expect(replayPolicy.session!.messages[1].content, acceptResponse);
      expect(
        handle2.decisions.every((d) => d.verdict is Accept),
        isTrue,
      );
      replay.assertExhausted();
    });

    test('recorded and replayed decisions are verdict-identical', () async {
      final recording = RecordingJournal();
      final config = tinyConfig();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(rejectResponse),
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(acceptResponse),
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      final original = handle.decisions.single.verdict as Reject;
      final replayed = handle2.decisions.single.verdict as Reject;
      expect(replayed.reason, original.reason);
      expect(replayed.toMap(), original.toMap());
      replay.assertExhausted();
    });

    test('rendered prompts are byte-identical across recording and replay',
        () async {
      final recording = RecordingJournal();
      final config = tinyConfig();
      final prompts = <String>[];
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(acceptResponse, log: prompts),
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));

      // The journaled PromptEffect carries the exact recorded prompt.
      final recordedRaw =
          recording.toJson().whereType<Map<String, Object?>>().firstWhere(
                (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
              )['rawOutput'] as Map;
      expect(recordedRaw['prompt'], prompts.single);

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final replayPrompts = <String>[];
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(acceptResponse, log: replayPrompts),
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(replayPrompts, isEmpty,
          reason: 'Replay must not call the adapter at all.');
      replay.assertExhausted();
    });

    test('a changed config between recording and replay diverges loudly',
        () async {
      final recording = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'diverge',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 'rules v1',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: mockPrompt(acceptResponse),
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'diverge',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 'rules v2',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: mockPrompt(acceptResponse),
          journal: replay,
        ),
      );
      await expectLater(
        handle2.cognitive.apply<Object?>(commandFor(read, [7])),
        throwsA(isA<ReplayDivergenceException>()),
      );
    });

    test('a recorded LLM error replays as the same rejection', () async {
      final recording = RecordingJournal();
      final config = tinyConfig();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async => throw StateError('api down'),
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(
        (handle.decisions.single.verdict as Reject).reason,
        'prompt-error',
      );

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: mockPrompt(acceptResponse),
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(
        (handle2.decisions.single.verdict as Reject).reason,
        'prompt-error',
      );
      replay.assertExhausted();
    });

    test('multiple decisions replay in order with the recorded verdicts',
        () async {
      final recording = RecordingJournal();
      final config = tinyConfig();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async => acceptResponse,
          journal: recording,
        ),
      );
      // Distinct commands → distinct prompts → distinct journal effects.
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      await handle.cognitive.apply<Object?>(commandFor(read, [3]));

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: config,
          prompt: (_) async => rejectResponse,
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle2.cognitive.apply<Object?>(commandFor(read, [2]));
      await handle2.cognitive.apply<Object?>(commandFor(read, [3]));
      expect(
        handle2.decisions.map((d) => d.verdict.type),
        ['accept', 'accept', 'accept'],
      );
      replay.assertExhausted();
    });

    test('the same config version replays a cache-hit decision', () async {
      // Recording: two identical decisions → LLM once, cache hit once.
      var calls = 0;
      final recording = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'determinism-cache',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: recording,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 1);

      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'determinism-cache',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
          ),
          prompt: (_) async {
            calls++;
            return rejectResponse;
          },
          journal: replay,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      await handle2.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 1, reason: 'Replay never invokes the adapter.');
      expect(handle2.decisions, hasLength(2));
      expect(handle2.decisions.every((d) => d.verdict is Accept), isTrue);
      replay.assertExhausted();
    });

    test('PromptEffect round-trips through the journal codec', () {
      final effect = PromptEffect(
        configId: 'c',
        configVersion: '1.0.0',
        cacheKey: 'k' * 64,
        contextHash: 'a' * 64,
        decisionHash: 'b' * 64,
        sessionFingerprint: 's' * 64,
        sessionId: 'session-1',
        prompt: 'p',
        response: 'r',
        at: DateTime.utc(2026, 11, 15, 12),
        latency: const Duration(milliseconds: 42),
      );
      final restored = PromptEffect.fromMap(effect.toMap());
      expect(restored.configId, 'c');
      expect(restored.configVersion, '1.0.0');
      expect(restored.cacheKey, 'k' * 64);
      expect(restored.contextHash, 'a' * 64);
      expect(restored.decisionHash, 'b' * 64);
      expect(restored.sessionFingerprint, 's' * 64);
      expect(restored.sessionId, 'session-1');
      expect(restored.prompt, 'p');
      expect(restored.response, 'r');
      expect(restored.at, DateTime.utc(2026, 11, 15, 12));
      expect(restored.latency, const Duration(milliseconds: 42));
      expect(promptEffectFromMap(effect.toMap()).toMap(), effect.toMap());
    });
  });
}
