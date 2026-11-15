// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  RecordingJournal journal() => RecordingJournal(
        clockSource: () => DateTime.utc(2026, 11, 15, 12),
      );

  Decision deferDecision({int payload = 42}) => Decision(
        id: Identity.next(),
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        pulse: Pulse<int>.governed(payload: payload),
      );

  group('approval atomicity', () {
    test('a failing commit rolls back the pending removal', () async {
      // Replace `committed` with a state whose rule rejects every
      // mutation — the commit stage fails, the tx rolls back, and the
      // request must stay pending.
      final hostile = Cell.state<int?>(
        initial: null,
        testRule: TestCell((object, {host, arguments, user}) => false),
      ).cell;
      final guarded = ApprovalQueue<int>(
        journal: journal(),
        committed: hostile,
      );
      final future = guarded.submit(deferDecision(payload: 7));
      final id = guarded.pending.keys.single;
      expect(await guarded.approve(id), isFalse);
      expect(guarded.pending, hasLength(1),
          reason: 'The pending removal was rolled back.');
      expect(hostile.value, isNull, reason: 'The commit was rolled back.');
      // The future is still pending — the request was never decided.
      var resolved = false;
      future.whenComplete(() => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);
      await guarded.dispose();
      await future;
    });

    test('a rejecting pending gate rejects submission (fail closed)', () async {
      final map = TissueMap<String, ApprovalRequest<int>>(
        properties: TissueMapNucleus<String, ApprovalRequest<int>>(
          testRule: TestTissue((object, {host, arguments, user}) => false),
        ),
      );
      final queue = ApprovalQueue<int>(journal: journal(), pending: map);
      final future = await queue.submit(deferDecision());
      expect(future, isFalse,
          reason: 'The gated submission returns false — nothing pending.');
      expect(queue.pending, isEmpty);
      await queue.dispose();
    });

    test('concurrent approves: exactly one wins', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      queue.submit(deferDecision(payload: 5));
      final id = queue.pending.keys.single;
      final results = await Future.wait([
        queue.approve(id),
        queue.approve(id),
        queue.approve(id),
      ]);
      expect(results.where((r) => r), hasLength(1),
          reason: 'The tx serializes; only the first removal succeeds.');
      expect(queue.pending, isEmpty);
      expect(queue.committed.value, 5);
      await queue.dispose();
    });

    test('approve and reject racing: only one decision is recorded', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      queue.submit(deferDecision(payload: 5));
      final id = queue.pending.keys.single;
      final results = await Future.wait([
        queue.approve(id),
        queue.reject(id, 'race'),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(queue.pending, isEmpty);
      await queue.dispose();
    });
  });
}
