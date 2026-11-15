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

  PromptConfig dedicatedConfig() => PromptConfig.custom(
        id: 'modes-dedicated',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
      );

  group('session modes', () {
    test('stateless: no session object is created', () {
      final policy = promptedPolicyWith(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      expect(policy, isA<PromptedPolicy>());
      expect(policy.session, isNull);
      expect(policy.config.sessionMode, SessionMode.stateless);
    });

    test('dedicated: a session is auto-created and exposed', () {
      final policy = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      expect(policy.session, isNotNull);
      expect(policy.session!.id, startsWith('dedicated-'));
      expect(policy.session!.isEmpty, isTrue);
    });

    test('dedicated: decisions accumulate user + assistant pairs', () async {
      final policy = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(policy.session!.length, 2);
      expect(policy.session!.messages[0].role, ChatRole.user);
      expect(policy.session!.messages[0].content, contains('## Context'));
      expect(policy.session!.messages[1].role, ChatRole.assistant);
      expect(policy.session!.messages[1].content, acceptResponse);
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      expect(policy.session!.length, 4);
    });

    test('two dedicated policies have distinct sessions', () {
      final a = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      final b = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      expect(identical(a.session, b.session), isFalse);
      expect(a.session!.id, isNot(b.session!.id));
    });

    test('shared: requires a session argument', () {
      expect(
        () => promptedPolicyWith(
          config: PromptConfig.custom(
            id: 'modes-shared',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}',
            sessionMode: SessionMode.shared,
          ),
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
        throwsArgumentError,
      );
    });

    test('shared: uses the user-provided session directly', () async {
      final session = PromptSession(id: 'shared-1');
      final policy = promptedPolicyWith(
        config: PromptConfig.custom(
          id: 'modes-shared',
          version: '1.0.0',
          description: 'd',
          systemPrompt: 's',
          userTemplate: '{{context}}\n\n{{decision}}',
          sessionMode: SessionMode.shared,
        ),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
        session: session,
      );
      expect(identical(policy.session, session), isTrue);
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(session.length, 2);
    });

    test('shared: two policies over the same session share the history',
        () async {
      final session = PromptSession(id: 'shared-2');
      PromptConfig sharedConfig() => PromptConfig.custom(
            id: 'modes-shared-2',
            version: '1.0.0',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}\n\n{{decision}}',
            sessionMode: SessionMode.shared,
          );
      final a = promptedPolicyWith(
        config: sharedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
        session: session,
      );
      final b = promptedPolicyWith(
        config: sharedConfig(),
        prompt: mockPrompt(rejectResponse),
        journal: RecordingJournal(),
        session: session,
      );
      final srcA = Cell.ingress<int>();
      final handleA = cognitive(
        cell: srcA.cell,
        policy: TestCell.allowAll,
        verdictPolicy: a,
      );
      await handleA.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(session.length, 2);
      final srcB = Cell.ingress<int>();
      final handleB = cognitive(
        cell: srcB.cell,
        policy: TestCell.allowAll,
        verdictPolicy: b,
      );
      await handleB.cognitive.apply<Object?>(commandFor(read, [2]));
      expect(session.length, 4);
      expect(session.messages[3].content, rejectResponse);
    });

    test('session argument is ignored in stateless mode', () {
      final session = PromptSession(id: 'ignored');
      final policy = promptedPolicyWith(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
        session: session,
      );
      expect(policy.session, isNull);
      expect(session.isEmpty, isTrue);
    });

    test('session argument is ignored in dedicated mode', () {
      final session = PromptSession(id: 'ignored-2');
      final policy = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
        session: session,
      );
      expect(identical(policy.session, session), isFalse);
      expect(policy.session!.id, startsWith('dedicated-'));
    });

    test('clearSession works in every mode', () {
      final stateless = promptedPolicyWith(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      stateless.clearSession(); // No-op.

      final dedicated = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      dedicated.session!.append(
        ChatMessage(role: ChatRole.user, content: 'x'),
      );
      dedicated.clearSession();
      expect(dedicated.session!.isEmpty, isTrue);

      final sharedSession = PromptSession(id: 'shared-3');
      final shared = promptedPolicyWith(
        config: PromptConfig.custom(
          id: 'modes-shared-3',
          version: '1.0.0',
          description: 'd',
          systemPrompt: 's',
          userTemplate: '{{context}}',
          sessionMode: SessionMode.shared,
        ),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
        session: sharedSession,
      );
      sharedSession.append(ChatMessage(role: ChatRole.user, content: 'x'));
      shared.clearSession();
      expect(sharedSession.isEmpty, isTrue);
    });

    test('clearSession journals a SessionClearedEffect', () async {
      final journal = RecordingJournal();
      final policy = promptedPolicyWith(
        config: dedicatedConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      policy.session!.append(ChatMessage(role: ChatRole.user, content: 'x'));
      policy.clearSession();
      await Future<void>.delayed(Duration.zero);
      final cleared = journal.toJson().whereType<Map<String, Object?>>().where(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.session.clear',
          );
      expect(cleared, hasLength(1));
      final effect = sessionEffectFromMap(
        (cleared.single['rawOutput'] as Map).cast<String, dynamic>(),
      ) as SessionClearedEffect;
      expect(effect.sessionId, policy.session!.id);
    });

    test('PromptedPolicy composes as a VerdictPolicy via operator +', () async {
      final policy = promptedPolicyWith(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        journal: RecordingJournal(),
      );
      final composed = policy + learnedVerdictPolicy();
      expect(composed, isA<VerdictPolicy>());
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: composed,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(handle.decisions.single.verdict, isA<Accept>());
    });
  });
}
