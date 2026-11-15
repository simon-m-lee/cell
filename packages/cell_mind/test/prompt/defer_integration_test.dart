// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/prompt_fixtures.dart';

void main() {
  group('prompt defer integration', () {
    test('an LLM Defer routes to onDeferred and approval commits', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(deferResponse),
          journal: RecordingJournal(),
        ),
        onDeferred: approvalResolver(queue),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 5000,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-1'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(handle.decisions.any((d) => d.verdict is Defer), isTrue);
      expect(queue.pending.length, 1);
      final requestId = queue.pending.keys.single;
      final approved = await queue.approve(requestId);
      expect(approved, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final followUp = handle.decisions.last;
      expect(followUp.verdict, isA<Accept>());
      expect(
        (followUp.verdict as Accept).annotations['deferredBy'],
        'approval',
      );
      await queue.dispose();
    });

    test('an LLM Defer without a resolver fails closed', () async {
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt('{"verdict":"defer"}'),
          journal: RecordingJournal(),
        ),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-2'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        handle.decisions.any(
          (d) =>
              d.verdict is Reject &&
              (d.verdict as Reject).reason == 'defer-missing-resolver',
        ),
        isTrue,
      );
    });

    test('an LLM Defer with no onDeferred fails closed', () async {
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(deferResponse),
          journal: RecordingJournal(),
        ),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-3'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        handle.decisions.any(
          (d) =>
              d.verdict is Reject &&
              (d.verdict as Reject).reason == 'defer-no-resolver',
        ),
        isTrue,
      );
    });

    test('a rejected approval records defer-rejected', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(deferResponse),
          journal: RecordingJournal(),
        ),
        onDeferred: approvalResolver(queue),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-4'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final requestId = queue.pending.keys.single;
      await queue.reject(requestId, 'too risky');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(handle.decisions.last.verdict, isA<Reject>());
      expect(
        (handle.decisions.last.verdict as Reject).reason,
        'defer-rejected',
      );
      await queue.dispose();
    });

    test('the LLM still runs once even when its verdict defers', () async {
      var calls = 0;
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return deferResponse;
          },
          journal: RecordingJournal(),
        ),
        onDeferred: approvalResolver(queue),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-5'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, greaterThanOrEqualTo(1));
      expect(handle.decisions.any((d) => d.verdict is Defer), isTrue);
      await queue.dispose();
    });

    test('Defer annotations from the LLM reach the follow-up decision',
        () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>();
      final handle = cognitive(
        cell: gate.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(
            '{"verdict":"defer","resolver":"approval","confidence":0.6,'
            '"annotations":{"flag":"review"}}',
          ),
          journal: RecordingJournal(),
        ),
        onDeferred: approvalResolver(queue),
      );
      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('llm'),
            Provenance.traceId.entry('defer-trace-6'),
          ]),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final deferred = handle.decisions.firstWhere(
        (d) => d.verdict is Defer,
      );
      expect((deferred.verdict as Defer).annotations['flag'], 'review');
      final requestId = queue.pending.keys.single;
      await queue.approve(requestId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final followUp = handle.decisions.last.verdict as Accept;
      expect(followUp.annotations['flag'], 'review');
      await queue.dispose();
    });
  });
}
