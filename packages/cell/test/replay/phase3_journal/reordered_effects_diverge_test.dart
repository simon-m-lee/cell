// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

ClockEffect _clock(int ordinal, int millis) => ClockEffect(
      ordinal: ordinal,
      inputDigest: fingerprint('clock'),
      outputDigest: fingerprint(millis),
      at: DateTime.fromMillisecondsSinceEpoch(millis),
      epochMillis: millis,
    );

void main() {
  test('ReplayJournal fails loudly on reordered effects', () {
    final records = [
      _clock(0, 1000),
      UuidEffect(
        ordinal: 1,
        inputDigest: fingerprint('uuid'),
        outputDigest: fingerprint('id-1'),
        at: DateTime.fromMillisecondsSinceEpoch(1000),
        uuid: 'id-1',
      ),
    ];
    final journal = ReplayJournal(records);

    // Attempting to consume a UUID first is a kind mismatch.
    expect(
      () => journal.uuid(),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });

  test('ReplayJournal is satisfied when fully consumed', () {
    final journal = ReplayJournal([_clock(0, 1000)]);
    final now = journal.clock(); // consume the only record
    expect(now.millisecondsSinceEpoch, 1000);
    expect(journal.remaining, 0);
    journal.assertExhausted(); // OK
  });

  test('ReplayJournal fails on unreplayed effect at end', () {
    final journal = ReplayJournal([_clock(0, 1000)]);
    // Do not consume; assertExhausted must fail.
    expect(
      () => journal.assertExhausted(),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });

  test('ReplayJournal fails when the receptor consumes extra effects', () {
    final journal = ReplayJournal([_clock(0, 1000)]);
    journal.clock();
    expect(
      () => journal.clock(),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });

  test('ReplayJournal fails on io label and input mismatches', () {
    final journal = ReplayJournal([
      IoEffect(
        ordinal: 0,
        inputDigest: fingerprint({'q': 'a'}),
        outputDigest: fingerprint('answer'),
        at: DateTime.fromMillisecondsSinceEpoch(1000),
        label: 'api.fetch',
        rawOutput: 'answer',
      ),
    ]);

    expect(
      () => journal.io(
        label: 'api.other',
        input: {'q': 'a'},
        run: () async => 'ignored',
      ),
      throwsA(isA<ReplayDivergenceException>()),
    );

    expect(
      () => journal.io(
        label: 'api.fetch',
        input: {'q': 'different'},
        run: () async => 'ignored',
      ),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });

  test('ReplayJournal fails on timer duration mismatch', () {
    final journal = ReplayJournal([
      TimerEffect(
        ordinal: 0,
        inputDigest: fingerprint(1),
        outputDigest: fingerprint(0),
        at: DateTime.fromMillisecondsSinceEpoch(1000),
        scheduled: const Duration(milliseconds: 30),
        scheduledAtMillis: 1000,
        firedAtMillis: 1030,
      ),
    ]);

    expect(
      () => journal.timer(
        duration: const Duration(milliseconds: 50),
        input: 1,
        onFire: () {},
      ),
      throwsA(isA<ReplayDivergenceException>()),
    );
  });

  test('EffectRecord round-trips through its canonical JSON', () {
    final records = [
      _clock(0, 1234567),
      UuidEffect(
        ordinal: 1,
        inputDigest: fingerprint('uuid'),
        outputDigest: fingerprint('u-1'),
        at: DateTime.utc(2026, 11, 12, 10, 0, 0),
        uuid: 'u-1',
      ),
      IoEffect(
        ordinal: 2,
        inputDigest: fingerprint({'id': 1}),
        outputDigest: fingerprint('resp'),
        at: DateTime.utc(2026, 11, 12, 10, 0, 1),
        label: 'http.GET',
        rawOutput: 'resp',
      ),
      StreamEffect(
        ordinal: 3,
        inputDigest: fingerprint('evt'),
        outputDigest: fingerprint(5),
        at: DateTime.utc(2026, 11, 12, 10, 0, 2),
        streamLabel: 'ticks',
        rawValue: 5,
      ),
      TimerEffect(
        ordinal: 4,
        inputDigest: fingerprint('t'),
        outputDigest: fingerprint(0),
        at: DateTime.utc(2026, 11, 12, 10, 0, 3),
        scheduled: const Duration(milliseconds: 30),
        scheduledAtMillis: 10,
        firedAtMillis: 40,
      ),
    ];

    final roundTripped = records
        .map((r) => EffectRecord.fromJson(r.toJson()))
        .toList(growable: false);
    for (var i = 0; i < records.length; i++) {
      expect(
        canonicalJsonEncode(roundTripped[i].toJson()),
        canonicalJsonEncode(records[i].toJson()),
        reason: 'record $i must round-trip byte-identically',
      );
      expect(roundTripped[i].runtimeType, records[i].runtimeType);
    }
  });
}
