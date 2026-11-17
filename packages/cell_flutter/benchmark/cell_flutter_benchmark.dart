// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// cell_flutter microbenchmarks: CellBuilder (1/10/100 cells) and the
// CellSelector rebuild-reduction scenario.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_runner.dart';

void main() {
  testWidgets('cell_flutter scenarios', (tester) async {
    final results = <ScenarioResult>[];

    // 1. Single cell, single builder, 1000 updates.
    {
      final cell = Cell.state<int>(initial: 0);
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: CellBuilder<int>(
          cell: cell.cell,
          builder: (_, v) {
            builds++;
            return Text('$v');
          },
        ),
      ));
      results.add(await runScenario(
        tester,
        'cell_flutter 1 builder',
        updates: 1000,
        update: (i) async {
          cell.update(i);
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 2. Ten cells, ten builders, 1000 updates.
    {
      final cells = [for (var i = 0; i < 10; i++) Cell.state<int>(initial: 0)];
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            for (final cell in cells)
              CellBuilder<int>(
                cell: cell.cell,
                builder: (_, v) {
                  builds++;
                  return Text('$v');
                },
              ),
          ],
        ),
      ));
      results.add(await runScenario(
        tester,
        'cell_flutter 10 builders',
        updates: 1000,
        update: (i) async {
          for (final cell in cells) {
            cell.update(i);
          }
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 3. One hundred cells, one hundred builders, 100 updates.
    {
      final cells = [for (var i = 0; i < 100; i++) Cell.state<int>(initial: 0)];
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              for (final cell in cells)
                CellBuilder<int>(
                  cell: cell.cell,
                  builder: (_, v) {
                    builds++;
                    return Text('$v');
                  },
                ),
            ],
          ),
        ),
      ));
      results.add(await runScenario(
        tester,
        'cell_flutter 100 builders',
        updates: 100,
        update: (i) async {
          for (final cell in cells) {
            cell.update(i);
          }
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 4. CellSelector rebuild reduction: irrelevant fields must not
    //    rebuild the selector.
    {
      final user = Cell.state<({int id, String name, int age})>(
        initial: (id: 0, name: 'ada', age: 30),
      );
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: CellSelector<({int id, String name, int age}), String>(
          cell: user.cell,
          select: (u) => u?.name ?? '',
          builder: (context, name) {
            builds++;
            return Text(name);
          },
        ),
      ));
      results.add(await runScenario(
        tester,
        'cell_flutter selector (irrelevant updates)',
        updates: 1000,
        update: (i) async {
          user.update((id: i, name: 'ada', age: i));
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // The selector scenario must show the rebuild reduction: the slice
    // never changes, so the selector must not rebuild beyond its first.
    final selector = results.last;
    expect(selector.rebuilds, lessThan(10),
        reason: 'selector rebuilt ${selector.rebuilds} times although '
            'the selected slice never changed');

    for (final result in results) {
      // ignore: avoid_print
      print('BENCH $result');
    }
  });
}
