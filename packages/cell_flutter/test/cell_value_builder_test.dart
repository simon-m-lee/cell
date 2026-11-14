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
  group('CellValueBuilder', () {
    testWidgets('mirrors Cell.derive output', (tester) async {
      final source = Cell.state<int>(initial: 5);
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: source.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );

      await tester.pumpWidget(_wrap(
        CellValueBuilder<String>(
          cell: derived,
          builder: (_, v) => Text('$v'),
        ),
      ));

      // No pulse yet — derive is not seeded.
      expect(find.text('null'), findsOneWidget);

      source.update(7);
      await tester.pump();

      expect(find.text('v7'), findsOneWidget);
    });

    testWidgets('mirrors Cell.synthesis output', (tester) async {
      final price = Cell.state<int>(initial: 100);
      final tax = Cell.state<int>(initial: 10);
      final total = Cell.synthesis<Pulse<int>>(
        [price.cell, tax.cell],
        aggregator: (cells, _) {
          final sum = cells.fold<int>(0, (acc, c) {
            final v = c is ValueCell<int> ? c.value ?? 0 : 0;
            return acc + v;
          });
          return Pulse<int>(sum);
        },
      );

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: total,
          initial: 110,
          builder: (_, v) => Text('$v'),
        ),
      ));

      expect(find.text('110'), findsOneWidget);

      tax.update(25);
      await tester.pump();

      expect(find.text('125'), findsOneWidget);
    });

    testWidgets('initial seeds the first frame', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: src.cell,
          initial: 42,
          builder: (_, v) => Text('$v'),
        ),
      ));

      expect(find.text('42'), findsOneWidget);

      src.emit(9);
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('nullable V mirrors a null payload', (tester) async {
      final src = Cell.ingress<int?>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int?>(
          cell: src.cell,
          initial: 5,
          builder: (_, v) => Text('$v'),
        ),
      ));

      expect(find.text('5'), findsOneWidget);

      src.emit(null);
      await tester.pump();
      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('error pulse silently skipped by default', (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: src.cell,
          initial: 1,
          builder: (_, v) => Text('$v'),
        ),
      ));

      src.emit(2);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      // Value unchanged, and no error reported.
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error pulse reported when emitErrors is true', (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: src.cell,
          initial: 1,
          emitErrors: true,
          builder: (_, v) => Text('$v'),
        ),
      ));

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      expect(tester.takeException(), isStateError);
    });

    testWidgets('type mismatch reported even when emitErrors is false',
        (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: src.cell,
          initial: 1,
          builder: (_, v) => Text('$v'),
        ),
      ));

      src.emit('not-an-int');
      await tester.pump();

      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error, isA<StateError>());
    });

    testWidgets('cell swap resets the mirror', (tester) async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: a.cell,
          initial: 0,
          builder: (_, v) => Text('$v'),
        ),
      ));

      a.emit(5);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: b.cell,
          initial: 0,
          builder: (_, v) => Text('$v'),
        ),
      ));
      expect(find.text('0'), findsOneWidget);

      b.emit(6);
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('dispose stops egress', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: src.cell,
          initial: 1,
          builder: (_, v) => Text('$v'),
        ),
      ));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      src.emit(9);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
