// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  PromptConfig config({int maxSessionMessages = 40}) => PromptConfig.custom(
        id: 'render-session',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'SYSTEM',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
        maxSessionMessages: maxSessionMessages,
        maxSessionChars: 20000,
      );

  group('session rendering', () {
    test('an empty session renders like a stateless prompt', () {
      final session = PromptSession();
      final withSession = config().render(
        context: Context.system,
        decision: 1,
        session: session,
      );
      final stateless = config().render(
        context: Context.system,
        decision: 1,
      );
      expect(withSession, stateless);
      expect(withSession, isNot(contains('## Conversation History')));
    });

    test('history renders as Markdown blocks in insertion order', () {
      final session = PromptSession();
      session.appendExchange(
        ChatMessage(role: ChatRole.user, content: 'Q1'),
        ChatMessage(role: ChatRole.assistant, content: 'A1'),
      );
      final rendered = config().render(
        context: Context.system,
        decision: 1,
        session: session,
      );
      expect(rendered, contains('## Conversation History'));
      expect(rendered, contains('### User\nQ1'));
      expect(rendered, contains('### Assistant\nA1'));
      expect(rendered, contains('## Current Request'));
      final historyAt = rendered.indexOf('## Conversation History');
      final currentAt = rendered.indexOf('## Current Request');
      final schemaAt = rendered.indexOf('## Expected Output');
      expect(historyAt, greaterThan(0));
      expect(currentAt, greaterThan(historyAt));
      expect(schemaAt, greaterThan(currentAt));
    });

    test('system messages render with their own heading', () {
      final session = PromptSession();
      session.append(ChatMessage(role: ChatRole.system, content: 'RULES'));
      final rendered = config().render(
        context: Context.system,
        decision: 1,
        session: session,
      );
      expect(rendered, contains('### System\nRULES'));
    });

    test('the current request is the substituted template', () {
      final session = PromptSession();
      session.appendExchange(
        ChatMessage(role: ChatRole.user, content: 'OLD'),
        ChatMessage(role: ChatRole.assistant, content: '{"verdict":"accept"}'),
      );
      final rendered = config().render(
        context: Context(domains: 'finance'),
        decision: Pulse<int>(7, type: 'tx'),
        session: session,
      );
      // History contains the old turn, current request the new one.
      expect(rendered, contains('OLD'));
      expect(rendered.indexOf('OLD'),
          lessThan(rendered.indexOf('- domains: finance')));
      final currentSection =
          rendered.substring(rendered.indexOf('## Current Request'));
      expect(currentSection, contains('- domains: finance'));
      expect(currentSection, contains('- type: tx'));
      expect(currentSection, contains('- payload: 7'));
    });

    test('rendering is byte-identical for identical session content', () {
      PromptSession build() {
        final s = PromptSession();
        s.appendExchange(
          ChatMessage(role: ChatRole.user, content: 'Q'),
          ChatMessage(role: ChatRole.assistant, content: 'A'),
        );
        return s;
      }

      final a = config().render(
        context: Context.system,
        decision: 1,
        session: build(),
      );
      final b = config().render(
        context: Context.system,
        decision: 1,
        session: build(),
      );
      expect(a, b);
      expect(a.codeUnits, b.codeUnits);
    });

    test('compaction is reflected in the rendered history', () {
      final session = PromptSession(maxMessages: 2, maxChars: 20000);
      session.appendExchange(
        ChatMessage(role: ChatRole.user, content: 'Q1'),
        ChatMessage(role: ChatRole.assistant, content: 'A1'),
      );
      session.appendExchange(
        ChatMessage(role: ChatRole.user, content: 'Q2'),
        ChatMessage(role: ChatRole.assistant, content: 'A2'),
      );
      final rendered = config(maxSessionMessages: 2).render(
        context: Context.system,
        decision: 1,
        session: session,
      );
      expect(rendered, contains('Q2'));
      expect(rendered, isNot(contains('Q1')));
    });
  });
}
