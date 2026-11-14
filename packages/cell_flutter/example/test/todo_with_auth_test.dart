// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:cell_flutter_example/todo_with_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // The example's cells are module-level; reset them between tests.
    authState.update(const SignedOut());
    todosState.update(const []);
    lastSaved.update(null);
  });

  Future<void> pumpApp(WidgetTester tester) =>
      tester.pumpWidget(const TodoApp());

  Future<void> addTodo(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('sign in → todos appear', (tester) async {
    await pumpApp(tester);

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('No todos yet'), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Ada'), findsOneWidget);
    expect(find.text('No todos yet'), findsOneWidget);
  });

  testWidgets('add todo → list updates', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await addTodo(tester, 'buy milk');

    expect(find.text('buy milk'), findsOneWidget);
    expect(find.text('1 incomplete'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
  });

  testWidgets('complete todo → incomplete count decreases', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await addTodo(tester, 'buy milk');

    expect(find.text('1 incomplete'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('0 incomplete'), findsOneWidget);
    expect(find.text('0 left'), findsOneWidget);
  });

  testWidgets('empty title rejected by the refine hook', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // The dialog shows the validation error and stays open.
    expect(find.text('Title must not be empty'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('No todos yet'), findsOneWidget);
    expect(todosState.cell.value, isEmpty);
  });

  testWidgets('saved snackbar fires via recordPulses', (tester) async {
    final recorder = lastSaved.cell.recordPulses();
    addTearDown(recorder.stop);

    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await addTodo(tester, 'buy milk');

    expect(find.text('Saved "buy milk"'), findsOneWidget);
    expect(recorder.payloads, ['buy milk']);
  });

  testWidgets('refine-dropped event does not rebuild the count selector',
      (tester) async {
    var selectorBuilds = 0;

    await tester.pumpWidget(MaterialApp(
      home: CellSelector<List<Todo>, int>(
        cell: todosState.cell,
        select: (list) =>
            (list ?? const <Todo>[]).where((t) => !t.completed).length,
        builder: (context, count) {
          selectorBuilds++;
          return Text('probe:$count');
        },
      ),
    ));

    final baseline = selectorBuilds;
    expect(find.text('probe:0'), findsOneWidget);

    // An event the refine hook drops emits no pulse: the selector must
    // not rebuild.
    todoEvents.emit(const Todo(id: 99, title: '   '));
    await tester.pumpAndSettle();
    expect(selectorBuilds, baseline);
    expect(find.text('probe:0'), findsOneWidget);
  });
}
