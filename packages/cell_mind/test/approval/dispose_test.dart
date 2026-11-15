// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  Decision deferDecision() => Decision(
        id: Identity.next(),
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        pulse: Pulse<int>.governed(payload: 1),
      );

  group('ApprovalQueue.dispose', () {
    test('completes all pending futures with false', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final f1 = queue.submit(deferDecision());
      final f2 = queue.submit(deferDecision());
      await queue.dispose();
      expect(await f1, isFalse);
      expect(await f2, isFalse);
      expect(queue.isDisposed, isTrue);
    });

    test('journals the disposal', () async {
      final journal = RecordingJournal();
      final queue = ApprovalQueue<int>(journal: journal);
      queue.submit(deferDecision());
      await queue.dispose();
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.disposed',
        ),
        isTrue,
      );
    });

    test('submissions after disposal throw StateError', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      await queue.dispose();
      expect(() => queue.submit(deferDecision()), throwsStateError);
      expect(await queue.approve('x'), isFalse);
      expect(await queue.reject('x', 'r'), isFalse);
    });

    test('dispose is idempotent', () async {
      final journal = RecordingJournal();
      final queue = ApprovalQueue<int>(journal: journal);
      await queue.dispose();
      await queue.dispose();
      final json = journal.toJson();
      expect(
        json.where(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.disposed',
        ),
        hasLength(1),
      );
    });
  });
}
