// BLoC reference acceptance tests — the suite that must pass before the
// migration guide starts, and stays green as the reference.

import 'package:bloc_reference/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TodoBloc', () {
    test('loads seed todos', () async {
      final bloc = TodoBloc();
      expect(bloc.state, isA<TodoLoading>());
      bloc.add(const LoadTodos());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final state = bloc.state;
      expect(state, isA<TodoLoaded>());
      expect((state as TodoLoaded).todos, hasLength(1));
    });

    test('adds and toggles todos through events', () async {
      final bloc = TodoBloc();
      bloc.add(const LoadTodos());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const AddTodo('Write guide'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((bloc.state as TodoLoaded).todos, hasLength(2));

      bloc.add(const ToggleTodo('2'));
      await Future<void>.delayed(Duration.zero);
      final todos = (bloc.state as TodoLoaded).todos;
      expect(todos.last.completed, isTrue);
    });

    test('rejects an empty description', () async {
      final bloc = TodoBloc();
      bloc.add(const LoadTodos());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final states = <TodoState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const AddTodo('   '));
      await Future<void>.delayed(Duration.zero);
      expect(states, contains(isA<TodoError>()));
      await sub.cancel();
    });
  });

  testWidgets('renders todos and toggles from the widget tree',
      (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    expect(find.text('BLoC todos'), findsOneWidget);
    expect(find.text('Seed todo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-1')));
    await tester.pumpAndSettle();
    final tile =
        tester.widget<CheckboxListTile>(find.byKey(const Key('todo-1')));
    expect(tile.value, isTrue);
  });

  testWidgets('adds a todo through the form', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'New todo');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('New todo'), findsOneWidget);
  });
}
