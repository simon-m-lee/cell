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
  test('recipe 9: replay a decision log', () async {
    final recording = RecordingJournal();
    final gate = Cell.ingress<int>();
    final handle = cognitive(cell: gate.cell);
    gate.emit(1);
    gate.emit(2);
    await Future<void>.delayed(Duration.zero);
    final decisions = handle.decisions.toList();
    expect(decisions, hasLength(2));

    // Record one io effect, then replay it: the replay journal
    // serves the recorded output without re-running the world.
    await recording.io(
      label: 'cookbook.replay.probe',
      input: {'n': 2},
      run: () async => 'ok',
    );
    final probeRecords = recording.records
        .whereType<IoEffect>()
        .where((r) => r.label == 'cookbook.replay.probe')
        .toList();
    final replay = ReplayJournal(probeRecords);
    var replayedRun = false;
    final out = await replay.io(
      label: 'cookbook.replay.probe',
      input: {'n': 2},
      run: () async {
        replayedRun = true;
        return 'wrong';
      },
    );
    expect(out, 'ok');
    expect(replayedRun, isFalse,
        reason: 'Replay serves the recording; the world never runs.');
    // The decision log round-trips through its serialized form.
    expect(Decision.fromMap(decisions[0].toMap()).verdict, isA<Accept>());
    expect(Decision.fromMap(decisions[1].toMap()).verdict, isA<Accept>());
  });
}
