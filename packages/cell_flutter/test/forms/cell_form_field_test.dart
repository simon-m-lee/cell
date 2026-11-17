// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Forms: CellFormField — the generic non-text FormField bound to
// a cell, with a custom-T (DateTime) round-trip.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {GlobalKey<FormState>? formKey}) {
  return MaterialApp(
    home: Scaffold(
      body: Form(key: formKey, child: child),
    ),
  );
}

void main() {
  group('CellFormField', () {
    testWidgets('renders the cell current value', (tester) async {
      final counter = Cell.state<int>(initial: 3);
      await tester.pumpWidget(_wrap(
        CellFormField<int>(
          cell: counter.cell,
          builder: (state) => Text('value:${state.value}'),
        ),
      ));

      expect(find.text('value:3'), findsOneWidget);
    });

    testWidgets('didChange updates the cell', (tester) async {
      final counter = Cell.state<int>(initial: 1);
      await tester.pumpWidget(_wrap(
        CellFormField<int>(
          cell: counter.cell,
          builder: (state) => TextButton(
            onPressed: () => state.didChange(9),
            child: Text('value:${state.value}'),
          ),
        ),
      ));

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(counter.cell.value, 9);
    });

    testWidgets('cell update updates the field state', (tester) async {
      final counter = Cell.state<int>(initial: 1);
      await tester.pumpWidget(_wrap(
        CellFormField<int>(
          cell: counter.cell,
          builder: (state) => Text('value:${state.value}'),
        ),
      ));

      counter.update(42);
      await tester.pump();
      expect(find.text('value:42'), findsOneWidget);
    });

    testWidgets('Form.validate() calls the validator', (tester) async {
      final formKey = GlobalKey<FormState>();
      final counter = Cell.state<int?>(initial: null);
      await tester.pumpWidget(_wrap(
        CellFormField<int?>(
          cell: counter.cell,
          validator: (v) => v == null ? 'Required' : null,
          builder: (state) => Text(
            'value:${state.value} error:${state.errorText ?? 'none'}',
          ),
        ),
        formKey: formKey,
      ));

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.textContaining('Required'), findsOneWidget);

      counter.update(7);
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('custom T (DateTime) round-trips', (tester) async {
      final now = DateTime(2026, 11, 16);
      final cell = Cell.state<DateTime?>(initial: now);
      await tester.pumpWidget(_wrap(
        CellFormField<DateTime?>(
          cell: cell.cell,
          builder: (state) => TextButton(
            onPressed: () => state.didChange(now.add(const Duration(days: 1))),
            child: Text('date:${state.value}'),
          ),
        ),
      ));

      expect(find.text('date:$now'), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(cell.cell.value, now.add(const Duration(days: 1)));
      expect(find.text('date:${now.add(const Duration(days: 1))}'),
          findsOneWidget);
    });

    testWidgets('cell swap rebinds', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final source = ValueNotifier<ValueCell<int>>(a.cell);
      addTearDown(source.dispose);

      await tester.pumpWidget(_wrap(
        ValueListenableBuilder<ValueCell<int>>(
          valueListenable: source,
          builder: (_, cell, child) => CellFormField<int>(
            cell: cell,
            builder: (state) => Text('value:${state.value}'),
          ),
        ),
      ));
      expect(find.text('value:1'), findsOneWidget);

      source.value = b.cell;
      await tester.pump();
      // The swap sync is deferred to the post-frame callback.
      await tester.pump();
      expect(find.text('value:2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
