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

  PromptConfig sessionConfig(String id, {int maxMessages = 40}) =>
      PromptConfig.custom(
        id: id,
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
        maxSessionMessages: maxMessages,
        maxSessionChars: 20000,
      );

  group('session journaling', () {
    test('dedicated decisions journal init + append effects in order',
        () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: sessionConfig('j-dedicated'),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      final labels = journal
          .toJson()
          .whereType<Map<String, Object?>>()
          .where(
            (e) => e['kind'] == 'io',
          )
          .map((e) => e['label'])
          .toList();
      expect(labels, contains('mind.session.init'));
      expect(labels, contains('mind.session.append'));
      expect(labels.indexOf('mind.session.init'),
          lessThan(labels.indexOf('mind.session.append')));
    });

    test('PromptEffect carries sessionFingerprint and sessionId', () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: sessionConfig('j-fp'),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      final promptRecord =
          journal.toJson().whereType<Map<String, Object?>>().firstWhere(
                (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
              );
      final effect = promptEffectFromMap(
        (promptRecord['rawOutput'] as Map).cast<String, dynamic>(),
      );
      expect(effect.sessionId, policy.session!.id);
      expect(effect.sessionFingerprint, '');
      expect(effect.cacheKey, hasLength(64));
      expect(PromptEffect.schemaVersion, '1.1.0');
    });

    test('stateless decisions journal no session effects', () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      final labels = journal
          .toJson()
          .whereType<Map<String, Object?>>()
          .where(
            (e) => e['kind'] == 'io',
          )
          .map((e) => e['label'])
          .toList();
      expect(labels, isNot(contains('mind.session.init')));
      expect(labels, isNot(contains('mind.session.append')));
      final promptRecord =
          journal.toJson().whereType<Map<String, Object?>>().firstWhere(
                (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
              );
      final effect = promptEffectFromMap(
        (promptRecord['rawOutput'] as Map).cast<String, dynamic>(),
      );
      expect(effect.sessionId, isNull);
      expect(effect.sessionFingerprint, isNull);
    });

    test('compaction journals SessionCompactedEffect with the pair count',
        () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: sessionConfig('j-compact', maxMessages: 2),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      await handle.cognitive.apply<Object?>(commandFor(read, [3]));
      final compact = journal.toJson().whereType<Map<String, Object?>>().where(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.session.compact',
          );
      expect(compact, isNotEmpty);
      final effect = sessionEffectFromMap(
        (compact.last['rawOutput'] as Map).cast<String, dynamic>(),
      ) as SessionCompactedEffect;
      expect(effect.sessionId, policy.session!.id);
      expect(effect.droppedPairs, greaterThanOrEqualTo(1));
      // maxMessages 2 → exactly one pair remains after each append.
      expect(policy.session!.length, 2);
    });

    test('session effects round-trip through the dispatcher', () {
      final append = SessionAppendedEffect(
        sessionId: 's',
        userMessage: ChatMessage(role: ChatRole.user, content: 'u'),
        assistantMessage: ChatMessage(role: ChatRole.assistant, content: 'a'),
        at: DateTime.utc(2026, 11, 15, 12),
      );
      final restored =
          sessionEffectFromMap(append.toMap()) as SessionAppendedEffect;
      expect(restored.sessionId, 's');
      expect(restored.userMessage.content, 'u');
      expect(restored.assistantMessage.content, 'a');

      final init = SessionInitializedEffect(
        sessionId: 's',
        initialMessages: const [],
        at: DateTime.utc(2026, 11, 15, 12),
      );
      expect(
          sessionEffectFromMap(init.toMap()), isA<SessionInitializedEffect>());

      final cleared = SessionClearedEffect(
        sessionId: 's',
        at: DateTime.utc(2026, 11, 15, 12),
      );
      expect(
          sessionEffectFromMap(cleared.toMap()), isA<SessionClearedEffect>());

      final compacted = SessionCompactedEffect(
        sessionId: 's',
        droppedPairs: 3,
        at: DateTime.utc(2026, 11, 15, 12),
      );
      final restoredCompact =
          sessionEffectFromMap(compacted.toMap()) as SessionCompactedEffect;
      expect(restoredCompact.droppedPairs, 3);

      expect(
        () => sessionEffectFromMap({'type': 'unknown'}),
        throwsArgumentError,
      );
    });

    test('clearSession journals the cleared effect', () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: sessionConfig('j-clear'),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      policy.session!.append(
        ChatMessage(role: ChatRole.user, content: 'x'),
      );
      policy.clearSession();
      await Future<void>.delayed(Duration.zero);
      final cleared = journal.toJson().whereType<Map<String, Object?>>().where(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.session.clear',
          );
      expect(cleared, hasLength(1));
    });
  });
}
