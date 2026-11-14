// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CellBuilder', () {
    testWidgets('renders initial value', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: counter.cell,
          builder: (_, value) => Text('value: $value'),
        ),
      ));

      expect(find.text('value: 42'), findsOneWidget);
    });

    testWidgets('rebuilds on cell update', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: counter.cell,
          builder: (_, value) => Text('value: $value'),
        ),
      ));

      expect(find.text('value: 0'), findsOneWidget);

      counter.update(1);
      await tester.pump();

      expect(find.text('value: 1'), findsOneWidget);
    });

    testWidgets('renders null initial value', (tester) async {
      final cell = Cell.state<int?>(initial: null);
      await tester.pumpWidget(_wrap(
        CellBuilder<int?>(
          cell: cell.cell,
          builder: (_, value) => Text('value: ${value ?? "none"}'),
        ),
      ));

      expect(find.text('value: none'), findsOneWidget);
    });

    testWidgets('rebinds when cell swaps', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);

      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: a.cell,
          builder: (_, value) => Text('value: $value'),
        ),
      ));
      expect(find.text('value: 1'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: b.cell,
          builder: (_, value) => Text('value: $value'),
        ),
      ));
      await tester.pump();

      expect(find.text('value: 2'), findsOneWidget);

      // Updating `a` should not affect the widget anymore.
      a.update(10);
      await tester.pump();
      expect(find.text('value: 2'), findsOneWidget);

      // Updating `b` should.
      b.update(20);
      await tester.pump();
      expect(find.text('value: 20'), findsOneWidget);
    });

    testWidgets('multiple builders over the same cell all rebuild',
        (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(_wrap(
        Column(
          children: [
            CellBuilder<int>(
              cell: counter.cell,
              builder: (_, value) => Text('A: $value'),
            ),
            CellBuilder<int>(
              cell: counter.cell,
              builder: (_, value) => Text('B: $value'),
            ),
          ],
        ),
      ));

      expect(find.text('A: 0'), findsOneWidget);
      expect(find.text('B: 0'), findsOneWidget);

      counter.update(7);
      await tester.pump();

      expect(find.text('A: 7'), findsOneWidget);
      expect(find.text('B: 7'), findsOneWidget);
    });

    testWidgets('read-only view propagates reads and rejects mutation',
        (tester) async {
      final counter = Cell.state<int>(initial: 0);
      final readOnly = counter.cell.unmodifiable;

      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: readOnly,
          builder: (_, value) => Text('value: $value'),
        ),
      ));

      // Deputies share state with the principal.
      counter.update(5);
      await tester.pump();
      expect(find.text('value: 5'), findsOneWidget);

      // Mutation through the read-only view is rejected.
      expect(() => readOnly.value = 99, throwsUnsupportedError);
    });

    testWidgets('emit during build raises a framework error', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      // Emitting from one builder's `builder` synchronously notifies every
      // subscribed builder. Flutter allows the emitting builder to mark
      // itself dirty during its own build, but a *sibling* builder that
      // receives the notification throws "setState() or markNeedsBuild()
      // called during build" — the framework error the binding warns about.
      await tester.pumpWidget(_wrap(
        Column(
          children: [
            CellBuilder<int>(
              cell: counter.cell,
              builder: (_, value) {
                if (value == 1) {
                  counter.update(2); // emit during build (one-shot)
                }
                return Text('A: $value');
              },
            ),
            CellBuilder<int>(
              cell: counter.cell,
              builder: (_, value) => Text('B: $value'),
            ),
          ],
        ),
      ));

      expect(find.text('A: 0'), findsOneWidget);
      expect(find.text('B: 0'), findsOneWidget);

      counter.update(1);
      await tester.pump();

      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error, isFlutterError);

      // Reset the tree so the aborted build doesn't leak into teardown.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('builder errors propagate to Flutter error widget',
        (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(_wrap(
        CellBuilder<int>(
          cell: counter.cell,
          builder: (_, value) => throw StateError('boom'),
        ),
      ));

      expect(tester.takeException(), isStateError);
    });
  });

  group('ValueCell.builder extension', () {
    testWidgets('works as shorthand', (tester) async {
      final counter = Cell.state<int>(initial: 5);
      await tester.pumpWidget(_wrap(
        counter.cell.builder((_, value) => Text('value: $value')),
      ));

      expect(find.text('value: 5'), findsOneWidget);
    });
  });
}
