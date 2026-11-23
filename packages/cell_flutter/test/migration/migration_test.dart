// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration guide accuracy contract: every before/after fixture
// pair must render the same visible texts, before and after the same
// interactions. If a fixture pair diverges, the guide is wrong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider/after_counter.dart' as p_after_counter;
import 'provider/after_login.dart' as p_after_login;
import 'provider/after_todo.dart' as p_after_todo;
import 'provider/before_counter.dart' as p_before_counter;
import 'provider/before_login.dart' as p_before_login;
import 'provider/before_todo.dart' as p_before_todo;
import 'riverpod/after_counter.dart' as r_after_counter;
import 'riverpod/after_login.dart' as r_after_login;
import 'riverpod/after_todo.dart' as r_after_todo;
import 'riverpod/before_counter.dart' as r_before_counter;
import 'riverpod/before_login.dart' as r_before_login;
import 'riverpod/before_todo.dart' as r_before_todo;
import 'bloc/after_counter.dart' as b_after_counter;
import 'bloc/after_login.dart' as b_after_login;
import 'bloc/after_todo.dart' as b_after_todo;
import 'bloc/before_counter.dart' as b_before_counter;
import 'bloc/before_login.dart' as b_before_login;
import 'bloc/before_todo.dart' as b_before_todo;

/// The visible text contents of the pumped tree, in order.
List<String?> visibleTexts(WidgetTester tester) => [
  for (final w in tester.allWidgets.whereType<Text>())
    if (w.data != null) w.data,
];

/// Pumps [app] and records the text sequence at each step of [drive].
Future<List<List<String?>>> record(
  WidgetTester tester,
  Widget app,
  Future<void> Function(WidgetTester tester) drive,
) async {
  final steps = <List<String?>>[];
  await tester.pumpWidget(app);
  await tester.pump();
  steps.add(visibleTexts(tester));
  await drive(tester);
  steps.add(visibleTexts(tester));
  return steps;
}

void main() {
  group('Provider fixtures', () {
    testWidgets('counter renders identically before and after', (tester) async {
      final before = await record(tester, p_before_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      final after = await record(tester, p_after_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      expect(after, before);
    });

    testWidgets('login renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.enterText(find.byType(TextField).at(0), 'a@b.co');
        await t.enterText(find.byType(TextField).at(1), 'secret1');
        await t.pump();
      }

      final before = await record(
        tester,
        p_before_login.buildLoginApp(),
        drive,
      );
      final after = await record(tester, p_after_login.buildLoginApp(), drive);
      expect(after, before);
    });

    testWidgets('todo renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.tap(find.text('add'));
        await t.pump();
        await t.tap(find.text('add'));
        await t.pump();
      }

      final before = await record(tester, p_before_todo.buildTodoApp(), drive);
      final after = await record(tester, p_after_todo.buildTodoApp(), drive);
      expect(after, before);
    });
  });

  group('Riverpod fixtures', () {
    testWidgets('counter renders identically before and after', (tester) async {
      final before = await record(tester, r_before_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      final after = await record(tester, r_after_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      expect(after, before);
    });

    testWidgets('login renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.enterText(find.byType(TextField).at(0), 'a@b.co');
        await t.enterText(find.byType(TextField).at(1), 'secret1');
        await t.pump();
      }

      final before = await record(
        tester,
        r_before_login.buildLoginApp(),
        drive,
      );
      final after = await record(tester, r_after_login.buildLoginApp(), drive);
      expect(after, before);
    });

    testWidgets('todo renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.tap(find.text('add'));
        await t.pump();
        await t.tap(find.text('add'));
        await t.pump();
      }

      final before = await record(tester, r_before_todo.buildTodoApp(), drive);
      final after = await record(tester, r_after_todo.buildTodoApp(), drive);
      expect(after, before);
    });
  });

  group('Bloc fixtures', () {
    testWidgets('counter renders identically before and after', (tester) async {
      final before = await record(tester, b_before_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      final after = await record(tester, b_after_counter.buildCounterApp(), (
        t,
      ) async {
        await t.tap(find.textContaining('count:'));
        await t.pump();
      });
      expect(after, before);
    });

    testWidgets('login renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.enterText(find.byType(TextField).at(0), 'a@b.co');
        await t.enterText(find.byType(TextField).at(1), 'secret1');
        await t.pump();
      }

      final before = await record(
        tester,
        b_before_login.buildLoginApp(),
        drive,
      );
      final after = await record(tester, b_after_login.buildLoginApp(), drive);
      expect(after, before);
    });

    testWidgets('todo renders identically before and after', (tester) async {
      Future<void> drive(WidgetTester t) async {
        await t.tap(find.text('add'));
        await t.pump();
        await t.tap(find.text('add'));
        await t.pump();
      }

      final before = await record(tester, b_before_todo.buildTodoApp(), drive);
      final after = await record(tester, b_after_todo.buildTodoApp(), drive);
      expect(after, before);
    });
  });
}
