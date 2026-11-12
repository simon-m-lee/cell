// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<void> _pump() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('debounce journals its timer and replays the fire', () async {
    // ── Recording pass: emit 1 and 2 back-to-back; the first timer is
    // superseded, the second fires after the quiet window. ──
    final src = Cell.ingress<int>();
    final journal = RecordingJournal(
      clockSource: () => DateTime.fromMillisecondsSinceEpoch(1000000),
    );
    final db = Cell.debounce(
      src.cell,
      const Duration(milliseconds: 30),
      journal: journal,
    );
    final seen = <int>[];
    final observer = Cell.observe(
      source: db,
      effect: (Pulse p) => seen.add(p.payload as int),
    );

    src.emit(1);
    src.emit(2);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(seen, [2]);
    expect(journal.consumed, 2); // two debounce resets

    final records =
        journal.toJson().map(EffectRecord.fromJson).toList(growable: false);
    expect(records, everyElement(isA<TimerEffect>()));
    expect(
      records.map((r) => (r as TimerEffect).scheduled),
      everyElement(const Duration(milliseconds: 30)),
    );
    expect(records.map((r) => r.inputDigest), [fingerprint(1), fingerprint(2)]);
    observer.stop();

    // ── Replay pass: the same burst against the recorded timers. The
    // journal fires callbacks in journal order; because the fire is
    // microtask-deferred, the synchronous burst cancels the superseded
    // timer exactly as it did during recording. ──
    final replayJournal = ReplayJournal(records);
    final src2 = Cell.ingress<int>();
    final db2 = Cell.debounce(
      src2.cell,
      const Duration(milliseconds: 30),
      journal: replayJournal,
    );
    final replaySeen = <int>[];
    final observer2 = Cell.observe(
      source: db2,
      effect: (Pulse p) => replaySeen.add(p.payload as int),
    );

    src2.emit(1);
    src2.emit(2);
    await _pump();

    expect(replaySeen, [2]);
    expect(replayJournal.consumed, 2);
    replayJournal.assertExhausted();
    observer2.stop();
  });

  test('throttle journals its window and replays the same output', () async {
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    final th = Cell.throttle(
      src.cell,
      const Duration(milliseconds: 30),
      journal: journal,
      leading: true,
    );
    final seen = <int>[];
    final observer = Cell.observe(
      source: th,
      effect: (Pulse p) => seen.add(p.payload as int),
    );

    src.emit(1);
    src.emit(2); // muted during the window
    await Future<void>.delayed(const Duration(milliseconds: 60));
    src.emit(3); // new window
    // The second window's timer effect is recorded when it fires, 30 ms
    // after the emit — wait for it before asserting the count.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(seen, [1, 3]);
    expect(journal.consumed, 2); // one window timer per emitted pulse
    observer.stop();

    final records =
        journal.toJson().map(EffectRecord.fromJson).toList(growable: false);
    final replayJournal = ReplayJournal(records);
    final src2 = Cell.ingress<int>();
    final th2 = Cell.throttle(
      src2.cell,
      const Duration(milliseconds: 30),
      journal: replayJournal,
      leading: true,
    );
    final replaySeen = <int>[];
    final observer2 = Cell.observe(
      source: th2,
      effect: (Pulse p) => replaySeen.add(p.payload as int),
    );

    src2.emit(1);
    src2.emit(2);
    await _pump();
    src2.emit(3);
    await _pump();

    expect(replaySeen, [1, 3]);
    replayJournal.assertExhausted();
    observer2.stop();
  });
}
