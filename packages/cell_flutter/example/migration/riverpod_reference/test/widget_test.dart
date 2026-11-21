// Riverpod reference acceptance tests — the suite that must pass before
// the migration guide starts, and stays green as the reference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:riverpod_reference/main.dart';

void main() {
  testWidgets('adds and toggles todos', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    expect(find.text('Riverpod todos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'Write guide');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Write guide'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-1')));
    await tester.pumpAndSettle();
    final tile =
        tester.widget<CheckboxListTile>(find.byKey(const Key('todo-1')));
    expect(tile.value, isTrue);
  });

  testWidgets('filters completed todos', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('description-field')), 'Alpha');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('rejects an over-long description', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'x' * 61);
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('60 characters'), findsOneWidget);
  });
}
