// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

class User {
  const User(this.name, this.age, [this.roles = const []]);
  final String name;
  final int age;
  final List<String> roles;
}

void main() {
  group('CellSelector', () {
    testWidgets('rebuilds when the selected slice changes', (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));
      var builds = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => u!.name,
          builder: (_, name) {
            builds++;
            return Text(name);
          },
        ),
      ));

      expect(find.text('ada'), findsOneWidget);
      expect(builds, 1);

      user.update(const User('grace', 31));
      await tester.pump();

      expect(find.text('grace'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('does not rebuild when the slice is unchanged', (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));
      var builds = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => u!.name,
          builder: (_, name) {
            builds++;
            return Text(name);
          },
        ),
      ));
      expect(builds, 1);

      // Same name, different age: the slice is equal, no rebuild.
      user.update(const User('ada', 31));
      await tester.pump();

      expect(builds, 1);
    });

    testWidgets('selector change with same cell recomputes immediately',
        (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => u!.name,
          builder: (_, slice) => Text('name:$slice'),
        ),
      ));
      expect(find.text('name:ada'), findsOneWidget);

      // Same cell, new selector: the slice must recompute without a pulse.
      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => '${u!.age}',
          builder: (_, slice) => Text('age:$slice'),
        ),
      ));

      expect(find.text('age:30'), findsOneWidget);
    });

    testWidgets('custom equals with listEquals', (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30, ['admin']));
      var builds = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, List<String>>(
          cell: user.cell,
          select: (u) => u!.roles,
          equals: listEquals,
          builder: (_, roles) {
            builds++;
            return Text('${roles.length}');
          },
        ),
      ));
      expect(builds, 1);

      // New list instance, same content: listEquals says equal → no rebuild.
      user.update(const User('ada', 30, ['admin']));
      await tester.pump();
      expect(builds, 1);

      // Content change → rebuild.
      user.update(const User('ada', 30, ['admin', 'dev']));
      await tester.pump();
      expect(builds, 2);
    });

    testWidgets('rebinds on cell swap', (tester) async {
      final a = Cell.state<User>(initial: const User('ada', 30));
      final b = Cell.state<User>(initial: const User('grace', 31));

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: a.cell,
          select: (u) => u!.name,
          builder: (_, name) => Text(name),
        ),
      ));
      expect(find.text('ada'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: b.cell,
          select: (u) => u!.name,
          builder: (_, name) => Text(name),
        ),
      ));
      expect(find.text('grace'), findsOneWidget);

      a.update(const User('old', 1));
      await tester.pump();
      expect(find.text('grace'), findsOneWidget);

      b.update(const User('new', 2));
      await tester.pump();
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('nullable V handled in select', (tester) async {
      final cell = Cell.state<int?>(initial: 5);

      await tester.pumpWidget(_wrap(
        CellSelector<int?, String>(
          cell: cell.cell,
          select: (v) => v == null ? 'none' : '$v',
          builder: (_, s) => Text(s),
        ),
      ));
      expect(find.text('5'), findsOneWidget);

      cell.update(null);
      await tester.pump();
      expect(find.text('none'), findsOneWidget);
    });

    testWidgets('multiple emissions in one frame cause a single rebuild',
        (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));
      var builds = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => u!.name,
          builder: (_, name) {
            builds++;
            return Text(name);
          },
        ),
      ));
      expect(builds, 1);

      user.update(const User('a', 1));
      user.update(const User('b', 2));
      user.update(const User('c', 3));
      await tester.pump();

      expect(find.text('c'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('select is called once per emission', (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));
      var selectCalls = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) {
            selectCalls++;
            return u!.name;
          },
          builder: (_, name) => Text(name),
        ),
      ));

      // initState runs select once.
      expect(selectCalls, 1);

      user.update(const User('grace', 31));
      await tester.pump();

      expect(selectCalls, 2);
    });

    testWidgets('no rebuild after dispose', (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));
      var builds = 0;

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (u) => u!.name,
          builder: (_, name) {
            builds++;
            return Text(name);
          },
        ),
      ));
      expect(builds, 1);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      user.update(const User('grace', 31));
      await tester.pump();

      expect(builds, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('select throwing is contained by the framework',
        (tester) async {
      final user = Cell.state<User>(initial: const User('ada', 30));

      await tester.pumpWidget(_wrap(
        CellSelector<User, String>(
          cell: user.cell,
          select: (_) => throw StateError('select boom'),
          builder: (_, s) => Text(s),
        ),
      ));

      expect(tester.takeException(), isStateError);
    });

    testWidgets('defers slice recompute for a pulse emitted during build',
        (tester) async {
      final counter = Cell.state<int>(initial: 1);

      await tester.pumpWidget(_wrap(_EmitHost(
        child: CellSelector<int, int>(
          cell: counter.cell,
          select: (v) => v ?? 0,
          builder: (_, s) => Text('$s'),
        ),
      )));
      expect(find.text('1'), findsOneWidget);

      // Rebuild the same element; the host emits mid-build. The selector's
      // own setState is routed through runAfterBuild, so no framework
      // error fires and the slice lands on the next frame.
      await tester.pumpWidget(_wrap(_EmitHost(
        emitOnBuild: () => counter.update(9),
        child: CellSelector<int, int>(
          cell: counter.cell,
          select: (v) => v ?? 0,
          builder: (_, s) => Text('$s'),
        ),
      )));
      await tester.pump();

      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _EmitHost extends StatefulWidget {
  const _EmitHost({required this.child, this.emitOnBuild});

  final Widget child;

  /// Invoked from `build` — lets a test emit a pulse mid-frame.
  final void Function()? emitOnBuild;

  @override
  State<_EmitHost> createState() => _EmitHostState();
}

class _EmitHostState extends State<_EmitHost> {
  @override
  Widget build(BuildContext context) {
    widget.emitOnBuild?.call();
    return widget.child;
  }
}
