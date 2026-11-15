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

  group('ApprovalQueue.approve / reject', () {
    test('approve removes from pending and commits the value', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      final future = queue.submit(deferDecision(payload: 99));
      final id = queue.pending.keys.single;
      expect(await queue.approve(id), isTrue);
      expect(queue.pending, isEmpty);
      expect(queue.committed.value, 99);
      expect(await future, isTrue);
      await queue.dispose();
    });

    test('approve of an unknown id returns false', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      expect(await queue.approve('nope'), isFalse);
      await queue.dispose();
    });

    test('a second approve of the same id returns false', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      queue.submit(deferDecision());
      final id = queue.pending.keys.single;
      expect(await queue.approve(id), isTrue);
      expect(await queue.approve(id), isFalse);
      await queue.dispose();
    });

    test('reject removes from pending and resolves false', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      final future = queue.submit(deferDecision(payload: 99));
      final id = queue.pending.keys.single;
      expect(await queue.reject(id, 'denied-by-reviewer'), isTrue);
      expect(queue.pending, isEmpty);
      expect(queue.committed.value, isNull,
          reason: 'Rejects do not commit a value.');
      expect(await future, isFalse);
      await queue.dispose();
    });

    test('reject of an unknown id returns false', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      expect(await queue.reject('nope', 'x'), isFalse);
      await queue.dispose();
    });

    test('reject after approve returns false', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      queue.submit(deferDecision());
      final id = queue.pending.keys.single;
      await queue.approve(id);
      expect(await queue.reject(id, 'too-late'), isFalse);
      await queue.dispose();
    });

    test('command decisions commit null (no pre-execution payload)', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      final commandDecision = Decision(
        id: Identity.next(),
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.system,
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        command: (
          function: () => 1,
          arguments: (positionalArguments: null, namedArguments: null),
          compensation: null,
        ),
      );
      queue.submit(commandDecision);
      final id = queue.pending.keys.single;
      expect(await queue.approve(id), isTrue);
      expect(queue.committed.value, isNull);
      await queue.dispose();
    });

    test('committed emits an observable pulse on approve', () async {
      final queue = ApprovalQueue<int>(journal: journal());
      final observed = <int?>[];
      final sub = Cell.observe(
          source: queue.committed,
          effect: (Pulse p) {
            observed.add(p.payload);
          });
      queue.submit(deferDecision(payload: 7));
      await queue.approve(queue.pending.keys.single);
      await Future<void>.delayed(Duration.zero);
      expect(observed, contains(7));
      sub.stop();
      await queue.dispose();
    });
  });
}
