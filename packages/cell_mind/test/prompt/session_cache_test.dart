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

  PromptConfig sessionConfig(String id) => PromptConfig.custom(
        id: id,
        version: '1.0.0',
        description: 'd',
        systemPrompt: 's',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.dedicated,
        cacheTtl: Duration.zero, // observe verdict-cache keys only
      );

  group('session-aware caching', () {
    test('identical decisions in the same session state are cache hits',
        () async {
      var calls = 0;
      final policy = promptedPolicyWith(
        config: sessionConfig('sc-hit'),
        prompt: (_) async {
          calls++;
          return acceptResponse;
        },
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
      final lengthAfterFirst = policy.session!.length;
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(calls, 1);
      expect(policy.session!.length, lengthAfterFirst,
          reason: 'verdict cache hits do not append to the session');
    });

    test('different session states produce different cache keys', () async {
      var calls = 0;
      final policy = promptedPolicyWith(
        config: sessionConfig('sc-keys'),
        prompt: (_) async {
          calls++;
          return acceptResponse;
        },
        journal: RecordingJournal(),
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      // Decision A: session empty.
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      // Session now contains (A, accept). Decision B with a different
      // command is a different key anyway; the same command repeated
      // is a hit. Now clear the session and repeat the SAME command:
      // the session fingerprint differs → fresh LLM call.
      await Future<void>.delayed(Duration.zero);
      policy.clearSession();
      await Future<void>.delayed(Duration.zero);
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(calls, 2);
    });

    test('two sessions with identical content share verdict cache keys',
        () async {
      // Content equality, not identity: the same history in another
      // session object fingerprints identically.
      final sessionA = PromptSession(id: 'a');
      final sessionB = PromptSession(id: 'b');
      final msg = ChatMessage(role: ChatRole.user, content: 'same');
      sessionA.append(msg);
      sessionB.append(msg);
      expect(sessionA.fingerprint(), sessionB.fingerprint());
      expect(sessionA.fingerprint(), isNotEmpty);
    });

    test('a shared VerdictCache serves across policies with the same state',
        () async {
      var calls = 0;
      final cache = InMemoryVerdictCache();
      final config = PromptConfig.custom(
        id: 'sc-shared-cache',
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
          verdictCache: cache,
        ),
      );
      await handle1.cognitive.apply<Object?>(commandFor(read, [1]));
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
          verdictCache: cache,
        ),
      );
      await handle2.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(calls, 1, reason: 'the shared cache serves the repeat');
    });

    test('session mutations invalidate: same decision, evolved history',
        () async {
      var calls = 0;
      final policy = promptedPolicyWith(
        config: sessionConfig('sc-evolve'),
        prompt: (_) async {
          calls++;
          return acceptResponse;
        },
        journal: RecordingJournal(),
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle.cognitive.apply<Object?>(commandFor(read, [2]));
      // A fresh decision with a new session state cannot reuse the old
      // entry because the session fingerprint participates.
      await handle.cognitive.apply<Object?>(commandFor(read, [3]));
      expect(calls, 3);
    });
  });
}
