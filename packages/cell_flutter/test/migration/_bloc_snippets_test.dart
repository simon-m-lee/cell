// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Every Mitosis snippet from guide/MigratingFrom-Bloc.md appears here as
// a compiling, runnable test. When the guide changes, this file changes.
// A guide whose snippets do not compile is broken.

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MigratingFrom-Bloc.md — Section 3 (Cubit → Cell.state)', () {
    testWidgets('Cubit → Cell.state + CellBuilder', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CellBuilder<int>(
            cell: counter.cell.unmodifiable,
            builder: (_, count) => Text('${count ?? 0}'),
          ),
        ),
      ));

      void increment() => counter.update((counter.cell.value ?? 0) + 1);
      increment();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('MigratingFrom-Bloc.md — Section 4 (Bloc → Cell.state + ingress)', () {
    test('event validation moves into refine and testRule', () async {
      final todos = Cell.state<List<Todo>>(
        initial: const [],
        testRule: TestCell((object, {host, arguments, user}) {
          if (object is! Pulse) return true; // links/actions pass
          final payload = object.payload;
          return payload is List<Todo> &&
              payload.every((t) => t.title.trim().isNotEmpty);
        }),
      );
      final todoEvents = Cell.ingress<Todo>(
        refine: (host, input) {
          final title = input.payload?.title.trim() ?? '';
          if (title.isEmpty) return null; // silently drop empty titles
          return Pulse<Todo>(Todo(title), type: 'todo.add');
        },
      );

      // Wire the ingress into the state cell (one-time, app init):
      final egress = Cell.observe<Pulse<Todo>>(
        source: todoEvents.cell,
        effect: (p) {
          if (p.payload == null) return;
          todos.update([...?todos.cell.value, p.payload!]);
        },
      );
      addTearDown(egress.stop);

      todoEvents.emit(Todo('buy milk'));
      await Future<void>.delayed(Duration.zero);
      expect(todos.cell.value, hasLength(1));

      todoEvents.emit(Todo('   ')); // dropped by refine
      await Future<void>.delayed(Duration.zero);
      expect(todos.cell.value, hasLength(1));
    });
  });

  group('MigratingFrom-Bloc.md — Section 6 (DI)', () {
    testWidgets('BlocProvider → CellScope', (tester) async {
      final todos = Cell.state<List<Todo>>(initial: const []);

      await tester.pumpWidget(CellScope(
        cells: {#todos: todos.cell},
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ));

      final cell = CellScope.valueOf<List<Todo>>(
        tester.element(find.byType(Scaffold)),
        #todos,
      );
      expect(cell.value, isEmpty);
    });
  });

  group('MigratingFrom-Bloc.md — Section 7 (testing)', () {
    test('blocTest → recordPulses', () {
      final counter = Cell.state<int>(initial: 0);
      final recorder = counter.cell.recordPulses();
      addTearDown(recorder.stop);

      counter.update((counter.cell.value ?? 0) + 1);

      expect(recorder.payloads, [1]);
    });
  });

  group('MigratingFrom-Bloc.md — Section 8 (hydration)', () {
    test('minimal load-on-init persistence pattern', () {
      final stored = Cell.state<List<Todo>>(initial: const []);
      final saved = <List<Todo>>[];
      final egress = Cell.observe<Pulse<List<Todo>>>(
        source: stored.cell,
        effect: (_) => saved.add(stored.cell.value ?? const []),
      );
      addTearDown(egress.stop);

      stored.update([Todo('persisted')]);

      expect(saved, hasLength(1));
      expect(saved.single.single.title, 'persisted');
    });
  });
}

/// Minimal todo value class for the snippets.
class Todo {
  Todo(this.title);

  final String title;
}
