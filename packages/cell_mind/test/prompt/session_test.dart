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

  group('ChatMessage', () {
    test('constructs with role and content', () {
      final m = user('hello');
      expect(m.role, ChatRole.user);
      expect(m.content, 'hello');
    });

    test('value equality and hashCode', () {
      expect(user('a'), user('a'));
      expect(user('a'), isNot(user('b')));
      expect(user('a'), isNot(assistant('a')));
      expect(user('a').hashCode, user('a').hashCode);
    });

    test('round-trips through toMap/fromMap', () {
      final restored = ChatMessage.fromMap(assistant('json').toMap());
      expect(restored, assistant('json'));
    });

    test('fromMap tolerates unknown roles and missing content', () {
      final fallback = ChatMessage.fromMap({'role': 'ghost'});
      expect(fallback.role, ChatRole.system);
      expect(fallback.content, '');
    });
  });

  group('PromptSession basics', () {
    test('constructs with a generated id and defaults', () {
      final session = PromptSession();
      expect(session.id, isNotEmpty);
      expect(session.maxMessages, 40);
      expect(session.maxChars, 20000);
      expect(session.isEmpty, isTrue);
      expect(session.length, 0);
      expect(session.totalChars, 0);
    });

    test('accepts an explicit id and bounds', () {
      final session = PromptSession(
        id: 's1',
        maxMessages: 6,
        maxChars: 500,
      );
      expect(session.id, 's1');
      expect(session.maxMessages, 6);
      expect(session.maxChars, 500);
    });

    test('append adds a message', () {
      final session = PromptSession();
      session.append(user('hi'));
      expect(session.length, 1);
      expect(session.messages.single, user('hi'));
      expect(session.isEmpty, isFalse);
    });

    test('appendExchange adds a pair atomically', () {
      final session = PromptSession();
      session.appendExchange(user('q'), assistant('a'));
      expect(session.messages, [user('q'), assistant('a')]);
      expect(session.length, 2);
    });

    test('messages is an unmodifiable view', () {
      final session = PromptSession();
      session.append(user('hi'));
      expect(
        () => session.messages.add(assistant('x')),
        throwsUnsupportedError,
      );
    });

    test('clear removes everything', () {
      final session = PromptSession();
      session.appendExchange(user('q'), assistant('a'));
      session.clear();
      expect(session.isEmpty, isTrue);
      expect(session.length, 0);
      expect(session.fingerprint(), '');
    });

    test('totalChars sums message content', () {
      final session = PromptSession();
      session.append(user('abc'));
      session.append(assistant('de'));
      expect(session.totalChars, 5);
    });
  });

  group('PromptSession fingerprints', () {
    test('empty sessions fingerprint to the empty string', () {
      expect(PromptSession().fingerprint(), '');
    });

    test('content-only fingerprint: timestamps irrelevant', () {
      final a = PromptSession();
      final b = PromptSession();
      a.appendExchange(user('q'), assistant('a'));
      b.appendExchange(user('q'), assistant('a'));
      expect(a.fingerprint(), b.fingerprint());
    });

    test('order matters', () {
      final a = PromptSession();
      final b = PromptSession();
      a.appendExchange(user('q'), assistant('a'));
      b.appendExchange(assistant('a'), user('q'));
      expect(a.fingerprint(), isNot(b.fingerprint()));
    });

    test('any content change changes the fingerprint', () {
      final a = PromptSession();
      final b = PromptSession();
      a.appendExchange(user('q'), assistant('a'));
      b.appendExchange(user('q'), assistant('b'));
      expect(a.fingerprint(), isNot(b.fingerprint()));
    });
  });

  group('PromptSession serialization', () {
    test('round-trips through toMap/fromMap', () {
      final session = PromptSession(
        id: 's1',
        maxMessages: 8,
        maxChars: 900,
      );
      session.appendExchange(user('q1'), assistant('a1'));
      final restored = PromptSession.fromMap(session.toMap());
      expect(restored.id, 's1');
      expect(restored.maxMessages, 8);
      expect(restored.maxChars, 900);
      expect(restored.messages, session.messages);
      expect(restored.fingerprint(), session.fingerprint());
    });

    test('fromMap tolerates absent fields', () {
      final restored = PromptSession.fromMap({'id': 'x', 'messages': []});
      expect(restored.maxMessages, 40);
      expect(restored.maxChars, 20000);
      expect(restored.isEmpty, isTrue);
    });
  });
}
