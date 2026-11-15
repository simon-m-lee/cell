// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  ChatMessage user(String content) =>
      ChatMessage(role: ChatRole.user, content: content);
  ChatMessage assistant(String content) =>
      ChatMessage(role: ChatRole.assistant, content: content);

  group('session compaction', () {
    test('dropping oldest pairs keeps the newest ones under maxMessages', () {
      final session = PromptSession(maxMessages: 4, maxChars: 10000);
      session.appendExchange(user('q1'), assistant('a1'));
      session.appendExchange(user('q2'), assistant('a2'));
      session.appendExchange(user('q3'), assistant('a3'));
      // 6 messages > 4: drop the oldest pair → 4 remain.
      expect(session.messages, [
        user('q2'),
        assistant('a2'),
        user('q3'),
        assistant('a3'),
      ]);
    });

    test('compaction never drops partial pairs', () {
      final session = PromptSession(maxMessages: 3, maxChars: 10000);
      session.appendExchange(user('q1'), assistant('a1'));
      session.appendExchange(user('q2'), assistant('a2'));
      // 4 > 3 → drop oldest pair → 2 remain (under the bound).
      expect(session.messages, [user('q2'), assistant('a2')]);
    });

    test('maxChars drops oldest pairs until under the bound', () {
      final session = PromptSession(maxMessages: 100, maxChars: 10);
      session.appendExchange(user('aaaa'), assistant('bbbb'));
      session.appendExchange(user('cc'), assistant('dd'));
      // 8 + 4 = 12 > 10 → drop first pair (8) → 4 remain.
      expect(session.messages, [user('cc'), assistant('dd')]);
      expect(session.totalChars, 4);
    });

    test('system messages are protected while pairs are droppable', () {
      final session = PromptSession(maxMessages: 4, maxChars: 10000);
      session.append(ChatMessage(role: ChatRole.system, content: 'rules'));
      session.appendExchange(user('q1'), assistant('a1'));
      session.appendExchange(user('q2'), assistant('a2'));
      // 5 > 4 → drop the oldest pair; system message stays.
      expect(session.messages, [
        ChatMessage(role: ChatRole.system, content: 'rules'),
        user('q2'),
        assistant('a2'),
      ]);
    });

    test('fallback: oldest non-initial system message is dropped', () {
      final session = PromptSession(maxMessages: 3, maxChars: 10000);
      session.append(ChatMessage(role: ChatRole.system, content: 'first'));
      session.append(ChatMessage(role: ChatRole.system, content: 'second'));
      session.append(ChatMessage(role: ChatRole.system, content: 'third'));
      // No pairs to drop; 3 > 3? No — 3 == 3, no compaction.
      expect(session.length, 3);
      session.append(ChatMessage(role: ChatRole.system, content: 'fourth'));
      // 4 > 3, no pairs → drop oldest non-initial system ('second').
      expect(session.messages.map((m) => m.content).toList(), [
        'first',
        'third',
        'fourth',
      ]);
    });

    test('unpaired messages are never partially dropped', () {
      final session = PromptSession(maxMessages: 1, maxChars: 1);
      session.append(user('q1'));
      session.append(user('q2'));
      session.append(user('q3'));
      // No (user, assistant) pairs and no system messages → nothing is
      // droppable; messages are kept rather than partially destroyed.
      expect(session.messages, [user('q1'), user('q2'), user('q3')]);
    });

    test('compaction is deterministic across sessions', () {
      PromptSession build() {
        final s = PromptSession(maxMessages: 6, maxChars: 60);
        s.appendExchange(user('a' * 10), assistant('b' * 10));
        s.appendExchange(user('c' * 10), assistant('d' * 10));
        s.appendExchange(user('e' * 10), assistant('f' * 10));
        s.appendExchange(user('g' * 10), assistant('h' * 10));
        return s;
      }

      final a = build();
      final b = build();
      expect(a.messages, b.messages);
      expect(a.fingerprint(), b.fingerprint());
    });

    test('fingerprint changes after compaction drops history', () {
      final session = PromptSession(maxMessages: 4, maxChars: 10000);
      session.appendExchange(user('q1'), assistant('a1'));
      final before = session.fingerprint();
      session.appendExchange(user('q2'), assistant('a2'));
      session.appendExchange(user('q3'), assistant('a3'));
      expect(session.fingerprint(), isNot(before));
      expect(session.messages, [
        user('q2'),
        assistant('a2'),
        user('q3'),
        assistant('a3'),
      ]);
    });
  });
}
