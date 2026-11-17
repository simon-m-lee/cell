// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useCell', () {
    testWidgets('renders initial selected value', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      String? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCell<int, String>(
          cell: counter.cell,
          select: (v) => 'value: $v',
        );
        return const SizedBox.shrink();
      }));
      expect(captured, 'value: 42');
    });

    testWidgets('debug asserts when select returns a collection without equals',
        (tester) async {
      final counter = Cell.state<int>(initial: 1);
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCell<int, List<int>>(
          cell: counter.cell,
          select: (v) => [v ?? 0],
        );
        return const SizedBox.shrink();
      }));
      // The assert fires during build and is captured by the framework —
      // the same contract CellSelector enforces.
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('does not assert for a collection selection with equals',
        (tester) async {
      final counter = Cell.state<int>(initial: 1);
      List<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCell<int, List<int>>(
          cell: counter.cell,
          select: (v) => [v ?? 0],
          equals: listEquals,
        );
        return const SizedBox.shrink();
      }));
      expect(captured, [1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'debug asserts when a changed select returns a collection without equals',
        (tester) async {
      final counter = Cell.state<int>(initial: 1);
      final selector = ValueNotifier<Object Function(int?)>((v) => v ?? 0);
      addTearDown(selector.dispose);

      // First build: the selection is an int, so no assert fires.
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(selector);
        useCell<int, Object>(
          cell: counter.cell,
          select: selector.value,
        );
        return const SizedBox.shrink();
      }));
      expect(tester.takeException(), isNull);

      // Swap the selector to return a collection with equals still null:
      // the recompute effect fires the same debug assertion.
      selector.value = (v) => [v ?? 0];
      await tester.pump();
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('rebuilds when selected slice changes', (tester) async {
      final user = Cell.state<User>(initial: const User('alice', 30));
      final captured = <String>[];
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured.add(useCell<User, String>(
          cell: user.cell,
          select: (u) => u?.name ?? '',
        ));
        return const SizedBox.shrink();
      }));
      expect(captured, ['alice']);

      user.update(const User('bob', 30));
      await tester.pump();
      expect(captured, ['alice', 'bob']);
    });

    testWidgets('does not rebuild when unselected slice changes',
        (tester) async {
      final user = Cell.state<User>(initial: const User('alice', 30));
      var buildCount = 0;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCell<User, String>(
          cell: user.cell,
          select: (u) => u?.name ?? '',
        );
        buildCount++;
        return const SizedBox.shrink();
      }));
      expect(buildCount, 1);

      user.update(const User('alice', 31)); // name unchanged
      await tester.pump();
      expect(buildCount, 1, reason: 'selector should suppress rebuild');
    });

    testWidgets('selector change recomputes selected', (tester) async {
      final user = Cell.state<User>(initial: const User('alice', 30));
      final captured = <String>[];
      var useName = true;

      Future<void> pumpWith() => tester.pumpWidget(HookBuilder(builder: (_) {
            captured.add(useCell<User, String>(
              cell: user.cell,
              select: useName ? (u) => u?.name ?? '' : (u) => '${u?.age ?? 0}',
            ));
            return const SizedBox.shrink();
          }));

      await pumpWith();
      expect(captured.last, 'alice');

      // Rebuild with a new selector closure on the same cell.
      useName = false;
      await pumpWith();
      expect(captured.last, '30', reason: 'selector swap recomputes');
    });

    testWidgets('custom equals for lists', (tester) async {
      final cell = Cell.state<List<int>>(initial: [1, 2, 3]);
      var buildCount = 0;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCell<List<int>, List<int>>(
          cell: cell.cell,
          select: (v) => v ?? const [],
          equals: listEquals,
        );
        buildCount++;
        return const SizedBox.shrink();
      }));
      expect(buildCount, 1);

      cell.update([1, 2, 3]); // equal content, new list
      await tester.pump();
      expect(buildCount, 1, reason: 'listEquals suppresses rebuild');

      cell.update([1, 2, 4]);
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('null handling', (tester) async {
      final cell = Cell.state<int?>(initial: null);
      String? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCell<int?, String>(
          cell: cell.cell,
          select: (v) => v == null ? 'none' : '$v',
        );
        return const SizedBox.shrink();
      }));
      expect(captured, 'none');

      cell.update(5);
      await tester.pump();
      expect(captured, '5');
    });

    testWidgets('cell swap rebinds', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final source = ValueNotifier<ValueCell<int>>(a.cell);
      addTearDown(source.dispose);
      int? captured;

      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(source); // rebuild when the source swaps
        captured = useCell<int, int>(cell: source.value, select: (v) => v ?? 0);
        return const SizedBox.shrink();
      }));
      expect(captured, 1);

      source.value = b.cell;
      await tester.pump();
      expect(captured, 2);

      a.update(99);
      await tester.pump();
      expect(captured, 2, reason: 'old cell should not affect');

      b.update(42);
      await tester.pump();
      expect(captured, 42);
    });

    testWidgets(
        'returns the new cell\'s slice on the first build after a '
        'swap (no flash)', (tester) async {
      final cellA = Cell.state<String>(initial: 'A').cell;
      final cellB = Cell.state<String>(initial: 'B').cell;
      var currentCell = cellA;
      final rendered = <String>[];

      await tester.pumpWidget(HookBuilder(builder: (_) {
        final value =
            useCell<String, String>(cell: currentCell, select: (v) => v ?? '');
        rendered.add(value);
        return const SizedBox.shrink();
      }));

      // Change the cell and rebuild. The recompute effect re-runs
      // synchronously during the build that registers the new keys, so the
      // very first build with the new cell already returns its slice.
      currentCell = cellB;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        final value =
            useCell<String, String>(cell: currentCell, select: (v) => v ?? '');
        rendered.add(value);
        return const SizedBox.shrink();
      }));

      // Lock in the exact sequence: no stale 'A' build after the swap.
      expect(rendered, ['A', 'B']);
    });

    testWidgets('keying the HookWidget resets the whole hook state',
        (tester) async {
      final cellA = Cell.state<String>(initial: 'A').cell;
      final cellB = Cell.state<String>(initial: 'B').cell;
      var currentCell = cellA;

      await tester.pumpWidget(MaterialApp(
        home: HookBuilder(
          key: ValueKey(currentCell),
          builder: (_) {
            final value = useCell<String, String>(
              cell: currentCell,
              select: (v) => v ?? '',
            );
            return Text(value);
          },
        ),
      ));

      currentCell = cellB;
      await tester.pumpWidget(MaterialApp(
        home: HookBuilder(
          key: ValueKey(currentCell),
          builder: (_) {
            final value = useCell<String, String>(
              cell: currentCell,
              select: (v) => v ?? '',
            );
            return Text(value);
          },
        ),
      ));

      // The key change disposes and rebuilds the hook state.
      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets(
        'non-collection select without equals works without '
        'assertion', (tester) async {
      final source = Cell.state<List<String>>(initial: ['a', 'b']);
      int? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCell<List<String>, int>(
          cell: source.cell,
          select: (v) => v?.length ?? 0,
          // equals intentionally omitted — an int slice is not a collection.
        );
        return const SizedBox.shrink();
      }));
      expect(captured, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose stops subscription', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      var rebuilds = 0;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCell<int, int>(cell: counter.cell, select: (v) => v ?? 0);
        rebuilds++;
        return const SizedBox.shrink();
      }));
      expect(rebuilds, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      counter.update(1);
      await tester.pump();
      expect(rebuilds, 1);
    });

    testWidgets('fresh select closure does not churn subscription',
        (tester) async {
      final counter = Cell.state<int>(initial: 0);
      var rebuilds = 0;
      Future<void> pumpOnce() => tester.pumpWidget(HookBuilder(builder: (_) {
            useCell<int, int>(
              cell: counter.cell,
              select: (v) => (v ?? 0) * 1,
            );
            rebuilds++;
            return const SizedBox.shrink();
          }));

      for (var i = 0; i < 100; i++) {
        await pumpOnce();
      }
      expect(rebuilds, 100);

      counter.update(1);
      await tester.pump();
      expect(rebuilds, 101, reason: 'subscription intact after 100 rebuilds');
    });

    testWidgets('multiple useCell calls in one widget', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final captured = <String>[];
      await tester.pumpWidget(HookBuilder(builder: (_) {
        final av = useCell<int, int>(cell: a.cell, select: (v) => v ?? 0);
        final bv = useCell<int, int>(cell: b.cell, select: (v) => v ?? 0);
        captured.add('$av,$bv');
        return const SizedBox.shrink();
      }));
      expect(captured.last, '1,2');

      a.update(10);
      await tester.pump();
      expect(captured.last, '10,2');

      b.update(20);
      await tester.pump();
      expect(captured.last, '10,20');
    });
  });

  group('useCellValue', () {
    testWidgets('rebuilds on every value change', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      final captured = <int?>[];
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured.add(useCellValue(counter.cell));
        return const SizedBox.shrink();
      }));
      expect(captured, [0]);

      counter.update(1);
      await tester.pump();
      expect(captured, [0, 1]);
    });
  });

  group('useCellNotifier', () {
    testWidgets('returns a notifier bound to cell', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      CellNotifier<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellNotifier(counter.cell);
        return const SizedBox.shrink();
      }));
      expect(captured!.value, 42);
      expect(captured!.cell, same(counter.cell));
    });

    testWidgets('dispose notifier on unmount', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      CellNotifier<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellNotifier(counter.cell);
        return const SizedBox.shrink();
      }));
      final notifier = captured!;

      await tester.pumpWidget(const SizedBox.shrink());
      counter.update(1);
      await tester.pump();

      // The egress was stopped on unmount: the notifier no longer
      // observes the cell.
      expect(notifier.value, 0);
    });

    testWidgets('rebinds when cell changes', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final source = ValueNotifier<ValueCell<int>>(a.cell);
      addTearDown(source.dispose);
      CellNotifier<int>? captured;

      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(source); // rebuild when the source swaps
        captured = useCellNotifier(source.value);
        return const SizedBox.shrink();
      }));
      expect(captured!.cell, same(a.cell));

      source.value = b.cell;
      await tester.pump();
      expect(captured!.cell, same(b.cell));
      expect(captured!.value, 2);
    });
  });
}

class User {
  const User(this.name, this.age);
  final String name;
  final int age;
}
