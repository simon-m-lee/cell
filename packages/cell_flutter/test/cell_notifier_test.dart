// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellNotifier', () {
    test('reflects initial cell value', () {
      final counter = Cell.state<int>(initial: 42);
      final notifier = CellNotifier(counter.cell);
      addTearDown(notifier.dispose);

      expect(notifier.value, 42);
      expect(notifier.cell, same(counter.cell));
    });

    test('null initial value', () {
      final cell = Cell.state<int?>(initial: null);
      final notifier = CellNotifier(cell.cell);
      addTearDown(notifier.dispose);

      expect(notifier.value, isNull);
    });

    test('fires listener on cell update', () {
      final counter = Cell.state<int>(initial: 0);
      final notifier = CellNotifier(counter.cell);
      addTearDown(notifier.dispose);

      final observed = <int?>[];
      notifier.addListener(() => observed.add(notifier.value));

      counter.update(1);
      counter.update(2);
      counter.update(3);

      expect(observed, [1, 2, 3]);
    });

    test('reflects a null emission after a non-null value', () {
      final cell = Cell.state<int?>(initial: 7);
      final notifier = CellNotifier(cell.cell);
      addTearDown(notifier.dispose);

      cell.update(null);

      expect(notifier.value, isNull);
    });

    test('deduplicates equal updates', () {
      final counter = Cell.state<int>(initial: 0);
      final notifier = CellNotifier(counter.cell);
      addTearDown(notifier.dispose);

      var count = 0;
      notifier.addListener(() => count++);

      counter.update(1);
      counter.update(1); // Cell.state deduplicates internally; notifier
      // sees one emission.
      counter.update(2);

      expect(count, 2);
    });

    test('dispose stops listening', () {
      final counter = Cell.state<int>(initial: 0);
      final notifier = CellNotifier(counter.cell);

      var count = 0;
      notifier.addListener(() => count++);

      notifier.dispose();
      counter.update(1);
      counter.update(2);

      expect(count, 0, reason: 'listener fired after dispose');
    });

    test('dispose is idempotent', () {
      final counter = Cell.state<int>(initial: 0);
      final notifier = CellNotifier(counter.cell);

      notifier.dispose();
      expect(notifier.dispose, returnsNormally);
    });

    test('set value throws UnsupportedError', () {
      final counter = Cell.state<int>(initial: 0);
      final notifier = CellNotifier(counter.cell);
      addTearDown(notifier.dispose);

      expect(() => notifier.value = 99, throwsA(isA<UnsupportedError>()));
    });

    test('rejects invalidated cell', () {
      // Invalidate a governed head cell through its ephemeral policy, then
      // bind a ValueCell to it: per the `Cell` contract, `isInvalidated`
      // mirrors the upstream head ("the head owns the body").
      final policy = EphemeralPolicy<Cell>(
        eventLimit: 1,
        onEvent: (object, {required cell, required policy, arguments, user}) =>
            (events: policy.events + 1),
        onInvalidate: (nucleus) => true,
      );
      final head = Cell.governed(
        ephemeralPolicy: policy,
        context: Context.system,
      );
      policy('use', cell: head);
      expect(head.isInvalidated, isTrue);

      final cell = ValueCell<int>(initial: 0, bind: head);
      expect(cell.isInvalidated, isTrue);

      expect(() => CellNotifier(cell), throwsA(isA<ArgumentError>()));
    });

    test('works with a read-only unmodifiable view', () {
      final counter = Cell.state<int>(initial: 5);
      final readOnly = counter.cell.unmodifiable;
      final notifier = CellNotifier(readOnly);
      addTearDown(notifier.dispose);

      expect(notifier.value, 5);

      counter.update(9);
      expect(notifier.value, 9);

      expect(() => readOnly.value = 1, throwsUnsupportedError);
    });
  });
}
