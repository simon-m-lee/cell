// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Forms: CellTextField — rendering, two-way binding, validation,
// focus preservation, and lifecycle.

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
  group('CellTextField', () {
    testWidgets('renders the cell current value', (tester) async {
      final counter = Cell.state<String>(initial: 'hello');
      await tester.pumpWidget(_wrap(CellTextField(cell: counter.cell)));

      expect(find.widgetWithText(TextFormField, 'hello'), findsOneWidget);
    });

    testWidgets('typing updates the cell', (tester) async {
      final counter = Cell.state<String>(initial: '');
      await tester.pumpWidget(_wrap(CellTextField(cell: counter.cell)));

      await tester.enterText(find.byType(TextFormField), 'typed');
      await tester.pump();

      expect(counter.cell.value, 'typed');
    });

    testWidgets('cell update re-renders the field', (tester) async {
      final counter = Cell.state<String>(initial: '');
      await tester.pumpWidget(_wrap(CellTextField(cell: counter.cell)));

      counter.update('external');
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'external'), findsOneWidget);
    });

    testWidgets('validator runs on Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      final counter = Cell.state<String>(initial: '');
      await tester.pumpWidget(
        _wrap(
          CellTextField(
            cell: counter.cell,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          formKey: formKey,
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      counter.update('x@y.z');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('focus is preserved across cell updates', (tester) async {
      final counter = Cell.state<String>(initial: 'ab');
      await tester.pumpWidget(_wrap(CellTextField(cell: counter.cell)));

      final field = find.byType(TextFormField);
      await tester.showKeyboard(field);
      await tester.pump();

      counter.update('abcd'); // Same field, new value: no controller swap.
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('cell swap rebinds the controller', (tester) async {
      final a = Cell.state<String>(initial: 'a');
      final b = Cell.state<String>(initial: 'b');
      final source = ValueNotifier<ValueCell<String>>(a.cell);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        _wrap(
          ValueListenableBuilder<ValueCell<String>>(
            valueListenable: source,
            builder: (_, cell, child) => CellTextField(cell: cell),
          ),
        ),
      );
      expect(find.widgetWithText(TextFormField, 'a'), findsOneWidget);

      source.value = b.cell;
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'b'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'typed');
      await tester.pump();
      expect(b.cell.value, 'typed');
      expect(a.cell.value, 'a', reason: 'old cell must not be affected');
    });

    testWidgets('disposal stops listeners', (tester) async {
      final counter = Cell.state<String>(initial: 'x');
      await tester.pumpWidget(_wrap(CellTextField(cell: counter.cell)));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      counter.update('y');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
