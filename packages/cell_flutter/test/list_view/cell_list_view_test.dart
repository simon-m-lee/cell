// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// List virtualization: CellListView.builder + CellListView.keyed —
// rendering, diffed rebuilds, keyed state preservation, and scale.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// An item that counts taps — proves element state survives reorders.
class _StatefulItem extends StatefulWidget {
  const _StatefulItem({required this.label});

  final String label;

  @override
  State<_StatefulItem> createState() => _StatefulItemState();
}

class _StatefulItemState extends State<_StatefulItem> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${widget.label}:$taps'),
      onTap: () => setState(() => taps++),
    );
  }
}

void main() {
  group('CellListView.builder', () {
    testWidgets('renders the list items', (tester) async {
      final list = Cell.state<List<int>>(initial: [1, 2, 3, 4, 5]);
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.builder(
            cell: list.cell,
            itemBuilder: (_, item, i) => Text('item:$item'),
          ),
        ),
      );

      for (final i in [1, 2, 3, 4, 5]) {
        expect(find.text('item:$i'), findsOneWidget);
      }
    });

    testWidgets('updates when the cell list changes', (tester) async {
      final list = Cell.state<List<int>>(initial: [1]);
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.builder(
            cell: list.cell,
            itemBuilder: (_, item, i) => Text('item:$item'),
          ),
        ),
      );

      list.update([1, 2]);
      await tester.pump();
      expect(find.text('item:2'), findsOneWidget);
    });

    testWidgets('a cell that has never emitted renders an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.builder(
            cell: Cell.ingress<int>().cell,
            itemBuilder: (_, item, i) => Text('item:$item'),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.textContaining('item:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('composes with per-item CellBuilder', (tester) async {
      final a = Cell.state<int>(initial: 10);
      final b = Cell.state<int>(initial: 20);
      final items = Cell.state<List<ValueCell<int>>>(initial: [a.cell, b.cell]);
      await tester.pumpWidget(
        _wrap(
          CellListView<ValueCell<int>>.builder(
            cell: items.cell,
            itemBuilder: (_, cell, i) => CellBuilder<int>(
              cell: cell,
              builder: (_, v) => Text('value:$v'),
            ),
          ),
        ),
      );

      expect(find.text('value:10'), findsOneWidget);
      expect(find.text('value:20'), findsOneWidget);

      a.update(11);
      await tester.pump();
      expect(find.text('value:11'), findsOneWidget);
    });
  });

  group('CellListView.keyed', () {
    testWidgets('renders the list items', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b', 'c']);
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) => Text('keyed:$item'),
          ),
        ),
      );

      expect(find.text('keyed:a'), findsOneWidget);
      expect(find.text('keyed:c'), findsOneWidget);
    });

    testWidgets('append rebuilds only the new item', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b']);
      var builds = 0;
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) {
              builds++;
              return Text('keyed:$item');
            },
          ),
        ),
      );
      final buildsAfterMount = builds;

      list.update(['a', 'b', 'c']);
      await tester.pump();

      expect(
        builds - buildsAfterMount,
        1,
        reason: 'only the appended item is built',
      );
      expect(find.text('keyed:c'), findsOneWidget);
    });

    testWidgets('remove drops only the removed item', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b', 'c']);
      var builds = 0;
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) {
              builds++;
              return Text('keyed:$item');
            },
          ),
        ),
      );
      final buildsAfterMount = builds;

      list.update(['a', 'c']);
      await tester.pump();

      expect(
        builds,
        buildsAfterMount,
        reason: 'unchanged items come from the cache',
      );
      expect(find.text('keyed:b'), findsNothing);
      expect(find.text('keyed:c'), findsOneWidget);
    });

    testWidgets('replace rebuilds only the replaced item', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b']);
      var builds = 0;
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) {
              builds++;
              return Text('keyed:$item');
            },
          ),
        ),
      );
      final buildsAfterMount = builds;

      list.update(['a', 'z']);
      await tester.pump();

      expect(
        builds - buildsAfterMount,
        1,
        reason: 'only the replaced item is built',
      );
      expect(find.text('keyed:z'), findsOneWidget);
      expect(find.text('keyed:b'), findsNothing);
    });

    testWidgets('reorder preserves item state through keys', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b']);
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) => _StatefulItem(label: item),
          ),
        ),
      );

      // Tap item 'a' once; then reorder so 'a' moves to the end.
      await tester.tap(find.text('a:0'));
      await tester.pump();
      expect(find.text('a:1'), findsOneWidget);

      list.update(['b', 'a']);
      await tester.pump();

      expect(
        find.text('a:1'),
        findsOneWidget,
        reason: 'the keyed element (and its tap state) moved with the item',
      );
    });

    testWidgets('duplicate itemKey throws StateError', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'a']);
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) => Text('keyed:$item'),
          ),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('scroll position survives a list mutation', (tester) async {
      final list = Cell.state<List<int>>(
        initial: List<int>.generate(1000, (i) => i),
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) =>
                SizedBox(height: 40, child: Text('item:$item')),
            controller: controller,
          ),
        ),
      );

      controller.jumpTo(400);
      await tester.pump();
      final offsetBefore = controller.offset;

      list.update(List<int>.generate(1000, (i) => i == 5 ? -5 : i));
      await tester.pump();

      expect(controller.offset, offsetBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10,000 items render and scroll to the end', (tester) async {
      final list = Cell.state<List<int>>(
        initial: List<int>.generate(10000, (i) => i),
      );
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            itemBuilder: (_, item, i) =>
                SizedBox(height: 20, child: Text('item:$item')),
          ),
        ),
      );
      expect(find.text('item:0'), findsOneWidget);

      final position = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      position.position.jumpTo(199900); // last row
      await tester.pump();
      expect(find.text('item:9999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CellListView review fixes', () {
    testWidgets('keyed rebuilds a row when the value changes under a '
        'stable key', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a-old', 'b']);
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item.substring(0, 1), // id-stable key
            itemBuilder: (_, item, i) => Text('todo:$item'),
          ),
        ),
      );
      expect(find.text('todo:a-old'), findsOneWidget);

      // Same key ('a'), new value: the row must not freeze the first one.
      list.update(['a-new', 'b']);
      await tester.pump();
      expect(find.text('todo:a-new'), findsOneWidget);
      expect(find.text('todo:a-old'), findsNothing);
    });

    testWidgets('builder clamps an oversized itemCount to the list length', (
      tester,
    ) async {
      final list = Cell.state<List<int>>(initial: [1, 2]);
      await tester.pumpWidget(
        _wrap(
          CellListView<int>.builder(
            cell: list.cell,
            itemCount: 10, // larger than the current list
            itemBuilder: (_, item, i) => Text('item:$item'),
          ),
        ),
      );

      expect(find.text('item:1'), findsOneWidget);
      expect(find.text('item:2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CellListView.reverse', () {
    testWidgets('builder pins index 0 to the bottom for live feeds', (
      tester,
    ) async {
      final list = Cell.state<List<String>>(
        initial: ['newest', 'older', 'oldest'],
      );
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.builder(
            cell: list.cell,
            reverse: true,
            itemBuilder: (_, item, i) =>
                SizedBox(height: 60, child: Text('feed:$item')),
          ),
        ),
      );

      // Reversed layout: the first item renders at the visual bottom.
      final firstY = tester.getTopLeft(find.text('feed:newest')).dy;
      final secondY = tester.getTopLeft(find.text('feed:older')).dy;
      expect(
        firstY,
        greaterThan(secondY),
        reason: 'reverse pins the first item below the second',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyed pins index 0 to the bottom for live feeds', (
      tester,
    ) async {
      final list = Cell.state<List<String>>(
        initial: ['newest', 'older', 'oldest'],
      );
      await tester.pumpWidget(
        _wrap(
          CellListView<String>.keyed(
            cell: list.cell,
            itemKey: (item) => item,
            reverse: true,
            itemBuilder: (_, item, i) =>
                SizedBox(height: 60, child: Text('feed:$item')),
          ),
        ),
      );

      final firstY = tester.getTopLeft(find.text('feed:newest')).dy;
      final secondY = tester.getTopLeft(find.text('feed:older')).dy;
      expect(
        firstY,
        greaterThan(secondY),
        reason: 'reverse pins the first item below the second',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a live feed stays pinned to the newest item', (tester) async {
      final list = Cell.state<List<String>>(initial: ['a', 'b', 'c']);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 120,
            child: CellListView<String>.builder(
              cell: list.cell,
              reverse: true,
              itemBuilder: (_, item, i) =>
                  SizedBox(height: 60, child: Text('feed:$item')),
            ),
          ),
        ),
      );

      // Append a new item to the head of the list; the reversed view
      // must show it at the pinned bottom edge.
      list.update(['d', 'a', 'b', 'c']);
      await tester.pump();
      expect(find.text('feed:d'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
