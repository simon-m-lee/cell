// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/prompt_fixtures.dart';

void main() {
  int read(int x) => x;

  group('promptedPolicy (inline mode)', () {
    test('returns a VerdictPolicy that composes with cognitive', () async {
      final journal = RecordingJournal();
      final policy = promptedPolicy(
        prompt: mockPrompt(acceptResponse),
        journal: journal,
      );
      expect(policy, isA<VerdictPolicy>());
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: policy,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(handle.decisions.single.verdict, isA<Accept>());
    });

    test('an LLM Accept passes the command through', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: mockPrompt(acceptResponse),
          journal: journal,
        ),
      );
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyAccepted<int>>());
      expect(handle.decisions.single.verdict, isA<Accept>());
    });

    test('an LLM Reject fails closed and records its reason', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: mockPrompt(rejectResponse),
          journal: journal,
        ),
      );
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<int>>());
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'policy violation');
    });

    test('a malformed response fails closed with a parse-error', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: mockPrompt('I cannot decide'),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'parse-error-no-json');
    });

    test('a throwing adapter fails closed with prompt-error', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async => throw StateError('api down'),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'prompt-error');
    });

    test('a timeout fails closed with prompt-timeout', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async => throw TimeoutException('slow'),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'prompt-timeout');
    });

    test('caches identical decisions per instance (one LLM call)', () async {
      var calls = 0;
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(calls, 1);
      expect(handle.decisions, hasLength(2));
      expect(handle.decisions.every((d) => d.verdict is Accept), isTrue);
    });

    test('two inline instances do NOT share caches', () async {
      var calls = 0;
      final journal = RecordingJournal();
      final src1 = Cell.ingress<int>();
      final handle1 = cognitive(
        cell: src1.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: journal,
        ),
      );
      final src2 = Cell.ingress<int>();
      final handle2 = cognitive(
        cell: src2.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: journal,
        ),
      );
      await handle1.cognitive.apply<Object?>(commandFor(read, [1]));
      await handle2.cognitive.apply<Object?>(commandFor(read, [1]));
      expect(calls, 2);
    });

    test('honours a small maxPromptChars by failing closed without a call',
        () async {
      var calls = 0;
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: journal,
          maxPromptChars: 100,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'prompt-too-long');
      expect(calls, 0);
    });

    test('uses custom renderers and a custom parser when supplied', () async {
      final journal = RecordingJournal();
      final prompts = <String>[];
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: mockPrompt('ACCEPT-MARKER', log: prompts),
          journal: journal,
          systemPrompt: 'CUSTOM-SYSTEM',
          contextRenderer: (context) => 'CTX[${context.domains}]',
          decisionRenderer: (object, {host, arguments}) => 'DEC[action]',
          verdictParser: (raw) => raw == 'ACCEPT-MARKER'
              ? const Accept({'parser': 'custom'})
              : const Reject('parser-mismatch'),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [0]));
      expect(handle.decisions.single.verdict, isA<Accept>());
      final prompt = prompts.single;
      expect(prompt, contains('CUSTOM-SYSTEM'));
      expect(prompt, contains('CTX['));
      expect(prompt, contains('DEC[action]'));
    });

    test('journals a PromptEffect with the full prompt and response', () async {
      final journal = RecordingJournal();
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicy(
          prompt: mockPrompt(acceptResponse),
          journal: journal,
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      final io = journal.toJson().whereType<Map<String, Object?>>().where(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt',
          );
      expect(io, hasLength(1));
      final effect = promptEffectFromMap(
        (io.single['rawOutput'] as Map).cast<String, dynamic>(),
      );
      expect(effect.configId, startsWith('_inline_'));
      expect(effect.configVersion, '1.0.0');
      expect(effect.prompt, contains('## Context'));
      expect(effect.prompt, contains('## Decision'));
      expect(effect.response, acceptResponse);
      expect(effect.contextHash, hasLength(64));
      expect(effect.decisionHash, hasLength(64));
    });
  });
}
