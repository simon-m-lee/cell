// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  Decision deferDecision({String resolver = 'approval'}) => Decision(
        id: Identity.next(),
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: Defer(resolver),
        pulse: Pulse<int>.governed(payload: 1),
      );

  group('approval audit trail', () {
    test('submitted + decided effects land in the journal', () async {
      final journal = RecordingJournal();
      final queue = ApprovalQueue<int>(journal: journal);
      final decision = deferDecision();
      queue.submit(decision);
      final id = queue.pending.keys.single;
      await queue.approve(id);
      final json = journal.toJson();
      final submitted = json.where(
        (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.submitted',
      );
      final decided = json.where(
        (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.decided',
      );
      expect(submitted, hasLength(1));
      expect(decided, hasLength(1));
      expect((decided.single['rawOutput'] as Map)['decision'], 'approved');
      await queue.dispose();
    });

    test('ApprovalRequest round-trips through toMap/fromMap', () {
      final decision = deferDecision();
      final request = ApprovalRequest<int>(
        id: 'req-1',
        decision: decision,
        verdict: const Defer('approval', {'n': 1}),
        requestedAt: DateTime.utc(2026, 11, 15, 9),
        attempts: 2,
      );
      final restored = ApprovalRequest.fromMap<int>(request.toMap());
      expect(restored.id, 'req-1');
      expect(restored.decision.id, decision.id);
      expect(restored.verdict.resolver, 'approval');
      expect(restored.verdict.annotations, {'n': 1});
      expect(restored.requestedAt.toUtc(), DateTime.utc(2026, 11, 15, 9));
      expect(restored.attempts, 2);
    });

    test('approvalResolver routes matching names and rejects others', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final resolver = approvalResolver(queue);
      final result = resolver(
          deferDecision(resolver: 'approval'), const Defer('approval'));
      await Future<void>.delayed(Duration.zero);
      expect(queue.pending, hasLength(1));
      await queue.approve(queue.pending.keys.single);
      expect(await result, isTrue);
      expect(
        await approvalResolver(queue)(
          deferDecision(),
          const Defer('supervisor'),
        ),
        isFalse,
        reason: 'Foreign resolver names fail closed without submitting.',
      );
      expect(queue.pending, isEmpty);
      await queue.dispose();
    });
  });
}
