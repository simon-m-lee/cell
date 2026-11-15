// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  Decision deferDecision(String id) => Decision(
        id: id,
        at: DateTime.utc(2026, 11, 15, 10),
        context: Context.fromEntries([Ontology.domains.entry('finance')]),
        contextVersion: '1.0.0',
        verdict: const Defer('approval'),
        pulse: Pulse<int>.governed(payload: 1),
      );

  group('TTL sweeper', () {
    test('expired requests are removed and resolve false', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(clockSource: () => now),
        ttl: const Duration(milliseconds: 80),
      );
      final future = queue.submit(deferDecision('d-1'));
      expect(queue.pending, hasLength(1));

      now = now.add(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(queue.pending, isEmpty, reason: 'The sweeper expired it.');
      expect(await future, isFalse);
      await queue.dispose();
    });

    test('fresh requests are not expired prematurely', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(clockSource: () => now),
        ttl: const Duration(minutes: 5),
      );
      queue.submit(deferDecision('d-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(queue.pending, hasLength(1));
      await queue.dispose();
    });

    test('multiple expirations in one sweep', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(clockSource: () => now),
        ttl: const Duration(milliseconds: 60),
      );
      queue.submit(deferDecision('d-1'));
      queue.submit(deferDecision('d-2'));
      now = now.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(queue.pending, isEmpty);
      await queue.dispose();
    });

    test('expirations are journaled', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final journal = RecordingJournal(clockSource: () => now);
      final queue = ApprovalQueue<int>(
        journal: journal,
        ttl: const Duration(milliseconds: 60),
      );
      queue.submit(deferDecision('d-1'));
      now = now.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.approval.expired',
        ),
        isTrue,
      );
      await queue.dispose();
    });

    test('the sweeper keeps rescheduling while pending remain', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(clockSource: () => now),
        ttl: const Duration(minutes: 1),
      );
      queue.submit(deferDecision('d-1'));
      // A long-lived request stays pending across many sweeps.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(queue.pending, hasLength(1));
      await queue.dispose();
    });
  });
}
