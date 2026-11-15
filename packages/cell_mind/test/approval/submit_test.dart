// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart' hide completion;
import 'package:test/test.dart';

void main() {
  final journal = RecordingJournal(
    clockSource: () => DateTime.utc(2026, 11, 15, 12),
    uuidSource: () => 'uuid-submit',
  );

  Decision deferDecision({int payload = 42}) => Decision(
        id: Identity.next(),
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        pulse: Pulse<int>.governed(payload: payload),
      );

  group('ApprovalQueue.submit', () {
    test('adds to pending and returns a pending future', () async {
      final queue = ApprovalQueue<int>(journal: journal);
      final future = queue.submit(deferDecision());
      expect(queue.pending, hasLength(1));
      expect(future, completion(true));
      expect(await queue.approve(queue.pending.keys.first), isTrue);
      expect(await future, isTrue);
      await queue.dispose();
    });

    test('rejects non-Defer decisions', () {
      final queue = ApprovalQueue<int>(journal: journal);
      final decision = Decision(
        id: 'd-1',
        at: DateTime.utc(2026),
        context: Context.system,
        contextVersion: '1.0.0',
        verdict: const Accept(),
      );
      expect(
        () => queue.submit(decision),
        throwsArgumentError,
      );
    });

    test('enforces maxPending with StateError', () async {
      final queue = ApprovalQueue<int>(journal: journal, maxPending: 2);
      queue.submit(deferDecision());
      queue.submit(deferDecision());
      expect(
        () => queue.submit(deferDecision()),
        throwsStateError,
      );
      await queue.dispose();
    });

    test('journals the submission', () async {
      final queue = ApprovalQueue<int>(journal: journal);
      queue.submit(deferDecision());
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.submitted',
        ),
        isTrue,
      );
      await queue.dispose();
    });

    test('requestedAt is journal time', () async {
      final queue = ApprovalQueue<int>(journal: journal);
      queue.submit(deferDecision());
      final request = queue.pending.values.single;
      expect(request.requestedAt, DateTime.utc(2026, 11, 15, 12));
      await queue.dispose();
    });

    test('request id is unique per submission', () async {
      final queue = ApprovalQueue<int>(journal: journal);
      queue.submit(deferDecision());
      queue.submit(deferDecision());
      final ids = queue.pending.keys.toSet();
      expect(ids, hasLength(2));
      await queue.dispose();
    });
  });
}
