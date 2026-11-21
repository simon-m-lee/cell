// Cell reference acceptance tests — the migrated screen's contract:
// add via a txApply transaction (with receipts), toggle, filter, and
// validation through the side-effect channel.

import 'package:cell_reference/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits a todo through a txApply transaction',
      (tester) async {
    await tester.pumpWidget(const TodoApp());
    expect(find.text('0 receipts'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'Write guide');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Write guide'), findsOneWidget);
    // Two staged commands (add todo + bump stats) = two receipts.
    expect(find.text('2 receipts'), findsOneWidget);
    // The success snackbar surfaced through the CellListener.
    expect(find.textContaining('added (+1 stats)'), findsOneWidget);
  });

  testWidgets('toggles a todo and mints another receipt', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'Alpha');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-1')));
    await tester.pumpAndSettle();
    final tile =
        tester.widget<CheckboxListTile>(find.byKey(const Key('todo-1')));
    expect(tile.value, isTrue);
    expect(find.text('3 receipts'), findsOneWidget);
  });

  testWidgets('filters completed todos', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'Alpha');
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

  testWidgets('rejects an empty description without a transaction',
      (tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('must not be empty'), findsOneWidget);
    // No transaction ran, so no receipts were minted.
    expect(find.text('0 receipts'), findsOneWidget);
  });
}
