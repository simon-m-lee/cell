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

  group('approval capacity', () {
    test('maxPending limits concurrent submissions', () async {
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(),
        maxPending: 1,
      );
      queue.submit(deferDecision());
      expect(() => queue.submit(deferDecision()), throwsStateError);
      await queue.dispose();
    });

    test('capacity frees after a decision', () async {
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(),
        maxPending: 1,
      );
      queue.submit(deferDecision());
      final id = queue.pending.keys.single;
      await queue.reject(id, 'done');
      expect(queue.pending, isEmpty);
      queue.submit(deferDecision());
      expect(queue.pending, hasLength(1));
      await queue.dispose();
    });

    test('invalid constructor arguments throw', () {
      expect(
        () => ApprovalQueue<int>(
          journal: RecordingJournal(),
          maxPending: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ApprovalQueue<int>(
          journal: RecordingJournal(),
          ttl: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
