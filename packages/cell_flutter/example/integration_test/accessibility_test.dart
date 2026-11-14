// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Accessibility audit for all six examples: semantics labels on
// interactive widgets and tap targets >= 48dp. Contrast is verified
// manually (Flutter's test framework has no stable contrast API).

import 'package:cell_flutter_example/async_search.dart' as search;
import 'package:cell_flutter_example/auth_flow.dart' as auth;
import 'package:cell_flutter_example/counter_app.dart' as counter;
import 'package:cell_flutter_example/derived_cells.dart' as derived;
import 'package:cell_flutter_example/hooks_counter.dart' as hooks;
import 'package:cell_flutter_example/todo_with_auth.dart' as todo;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Accessibility', () {
    testWidgets('counter_app: counter value has semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const counter.CounterApp());
        expect(find.bySemanticsLabel(RegExp('Counter value')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('counter_app: FAB has tooltip', (tester) async {
      await tester.pumpWidget(const counter.CounterApp());
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add one');
    });

    testWidgets('hooks_counter: counter value has semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const hooks.HooksCounterApp());
        expect(find.bySemanticsLabel(RegExp('Counter value')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('hooks_counter: FAB has tooltip', (tester) async {
      await tester.pumpWidget(const hooks.HooksCounterApp());
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add one');
    });

    testWidgets('auth_flow: sign-in button has semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const auth.AuthApp());
        expect(
            find.bySemanticsLabel(RegExp('Sign in')), findsAtLeastNWidgets(1));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('async_search: search field has semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const search.SearchApp());
        expect(find.bySemanticsLabel(RegExp('Search field')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('async_search: loading indicator has semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const search.SearchApp());
        await tester.enterText(find.byType(TextField), 'dart');
        await tester.pump(const Duration(milliseconds: 1));
        expect(
            find.bySemanticsLabel(RegExp('Loading results')), findsOneWidget);
      } finally {
        semantics.dispose();
        // Drain the asyncMap timer and stop the spinner before teardown.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('derived_cells: displayed values have semantics labels',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const derived.DerivedCellsApp());
        expect(find.bySemanticsLabel(RegExp('Price')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Tax')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Total')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('todo_with_auth: FAB has tooltip', (tester) async {
      todo.authState.update(const todo.SignedOut());
      todo.todosState.update(const []);
      todo.lastSaved.update(null);
      await tester.pumpWidget(const todo.TodoApp());
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add todo');
    });

    testWidgets('todo_with_auth: checkbox has semantics label', (tester) async {
      todo.authState.update(const todo.SignedOut());
      todo.todosState.update(const []);
      todo.lastSaved.update(null);
      await tester.pumpWidget(const todo.TodoApp());
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'audit me');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      try {
        expect(
            find.bySemanticsLabel(RegExp('Complete audit me')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('todo_with_auth: tap targets are at least 48dp',
        (tester) async {
      todo.authState.update(const todo.SignedOut());
      todo.todosState.update(const []);
      todo.lastSaved.update(null);
      await tester.pumpWidget(const todo.TodoApp());
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      final fab = tester.getSize(find.byType(FloatingActionButton));
      expect(fab.width, greaterThanOrEqualTo(48));
      expect(fab.height, greaterThanOrEqualTo(48));
    });
  });
}
