// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  test('recipe 6: HITL approval for high-value actions', () async {
    final journal = RecordingJournal();
    final queue = ApprovalQueue<int>(
      journal: journal,
      ttl: const Duration(minutes: 5),
    );
    final gate = Cell.ingress<int>();
    final handle = cognitive(
      cell: gate.cell,
      verdictPolicy: verdictPolicy((object, {required host, arguments}) {
        if (object is! Pulse) return const Accept();
        return (object.payload as int) > 1000
            ? const Defer('approval')
            : const Accept();
      }),
      onDeferred: approvalResolver(queue),
    );
    await gate.ingest(Pulse<int>.governed(payload: 5000));
    await Future<void>.delayed(Duration.zero);
    expect(queue.pending, hasLength(1));
    final id = queue.pending.keys.single;
    expect(await queue.approve(id), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(queue.committed.value, 5000);
    expect(handle.decisions.last.verdict, isA<Accept>());
    await queue.dispose();
  });
}
