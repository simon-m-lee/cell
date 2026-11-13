// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  test('asyncMap records exactly N effects and replays identically',
      () async {
    var callCount = 0;
    var networkCalls = 0;
    Future<String> fakeFetch(int id, {required EffectJournal journal}) async {
      callCount++;
      return journal.io(
        label: 'fetch($id)',
        input: id,
        run: () async {
          networkCalls++;
          return 'profile-$id';
        },
      );
    }

    // ── Recording pass ────────────────────────────────────────────────
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    final out = Cell.asyncMap<int, String>(
      src.cell,
      (v, {required EffectJournal journal}) => fakeFetch(v, journal: journal),
      journal: journal,
    );
    final results = <String>[];
    final observer = Cell.observe(
      source: out,
      effect: (Pulse p) => results.add(p.payload as String),
    );

    src.emit(1);
    src.emit(2);
    src.emit(3);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(callCount, 3);
    expect(results, ['profile-1', 'profile-2', 'profile-3']);
    expect(journal.consumed, 3);

    // The recorded effects are I/O effects with the expected labels and
    // input digests.
    final records = journal
        .toJson()
        .map(EffectRecord.fromJson)
        .toList(growable: false);
    expect(records, everyElement(isA<IoEffect>()));
    expect(
      records.map((r) => (r as IoEffect).label),
      ['fetch(1)', 'fetch(2)', 'fetch(3)'],
    );
    expect(records.first.inputDigest, fingerprint(1));

    observer.stop();

    // ── Replay pass ───────────────────────────────────────────────────
    // A fresh graph + the recorded effects. The mapper's `run` closure is
    // never invoked on the replay side, so the fake network stays quiet.
    callCount = 0;
    networkCalls = 0;
    final replayJournal = ReplayJournal(records);
    final src2 = Cell.ingress<int>();
    final out2 = Cell.asyncMap<int, String>(
      src2.cell,
      (v, {required EffectJournal journal}) => fakeFetch(v, journal: journal),
      journal: replayJournal,
    );
    final replayResults = <String>[];
    final observer2 = Cell.observe(
      source: out2,
      effect: (Pulse p) => replayResults.add(p.payload as String),
    );

    src2.emit(1);
    src2.emit(2);
    src2.emit(3);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(networkCalls, 0, reason: 'replay must not touch the network');
    expect(replayResults, ['profile-1', 'profile-2', 'profile-3']);
    expect(replayJournal.consumed, 3);
    replayJournal.assertExhausted();
    observer2.stop();
  });
}
