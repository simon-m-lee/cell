// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recordPulses', () {
    test('records sync pulses', () {
      final counter = Cell.state<int>(initial: 0);
      final recorder = counter.cell.recordPulses();
      addTearDown(recorder.stop);

      counter.update(1);
      counter.update(2);
      counter.update(3);

      expect(recorder.payloads, [1, 2, 3]);
    });

    test('records derived cell pulses', () {
      final counter = Cell.state<int>(initial: 1);
      final doubled = Cell.derive<Pulse<int>, Pulse<int>>(
        source: counter.cell,
        project: (p) => Pulse<int>((p.payload ?? 0) * 2),
      );
      final recorder = doubled.recordPulses();
      addTearDown(recorder.stop);

      counter.update(2);
      counter.update(3);

      expect(recorder.payloads, [4, 6]);
    });

    test('records error pulses from fromFuture', () async {
      final future = Future<int>.error(StateError('boom'));
      final cell = Cell.fromFuture<int>(future, journal: RecordingJournal());
      final recorder = cell.recordPulses();
      addTearDown(recorder.stop);

      await Future<void>.delayed(Duration.zero);

      final errorPulses = recorder.pulses.where((p) => p.type == 'error');
      expect(errorPulses, hasLength(1));
      expect(errorPulses.first.payload, isStateError);
    });

    test('stop releases egress', () {
      final counter = Cell.state<int>(initial: 0);
      final recorder = counter.cell.recordPulses();
      counter.update(1);
      expect(recorder.payloads, [1]);
      recorder.stop();
      counter.update(2);
      expect(recorder.payloads, [1]);
    });

    test('stop is idempotent', () {
      final counter = Cell.state<int>(initial: 0);
      final recorder = counter.cell.recordPulses();
      recorder.stop();
      expect(recorder.stop, returnsNormally);
    });

    test('clear resets without stopping', () {
      final counter = Cell.state<int>(initial: 0);
      final recorder = counter.cell.recordPulses();
      addTearDown(recorder.stop);
      counter.update(1);
      counter.update(2);
      expect(recorder.payloads, [1, 2]);
      recorder.clear();
      expect(recorder.payloads, isEmpty);
      counter.update(3);
      expect(recorder.payloads, [3]);
    });
  });
}
