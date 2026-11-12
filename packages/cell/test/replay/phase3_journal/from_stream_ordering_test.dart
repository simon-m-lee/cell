// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  test('fromStream emits values in order and journals each', () async {
    final controller = StreamController<int>();
    final journal = RecordingJournal();
    final cell = Cell.fromStream<int>(controller.stream, journal: journal);
    final seen = <int>[];
    final observer = Cell.observe(
      source: cell,
      effect: (Pulse p) => seen.add(p.payload as int),
    );

    controller.add(1);
    controller.add(2);
    controller.add(3);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.close();

    expect(seen, [1, 2, 3]);
    expect(journal.consumed, 3);

    final records =
        journal.toJson().map(EffectRecord.fromJson).toList(growable: false);
    expect(records, everyElement(isA<IoEffect>()));
    expect(
      records.map((r) => (r as IoEffect).rawOutput),
      [1, 2, 3],
    );

    observer.stop();
  });

  test('fromFuture journals its value', () async {
    final journal = RecordingJournal();
    final cell =
        Cell.fromFuture<int>(Future.value(7), journal: journal);
    final seen = <int>[];
    final observer = Cell.observe(
      source: cell,
      effect: (Pulse p) => seen.add(p.payload as int),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(seen, [7]);
    expect(journal.consumed, 1);
    final record = EffectRecord.fromJson(journal.toJson().single);
    expect(record, isA<IoEffect>());
    expect((record as IoEffect).rawOutput, 7);

    observer.stop();
  });
}
