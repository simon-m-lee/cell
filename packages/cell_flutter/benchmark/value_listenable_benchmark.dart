// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// ValueListenableBuilder baseline: the native pattern CellBuilder wraps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_runner.dart';

void main() {
  testWidgets('ValueListenableBuilder scenarios', (tester) async {
    final results = <ScenarioResult>[];

    // 1. Single notifier, single builder, 1000 updates.
    {
      final notifier = ValueNotifier<int>(0);
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, v, child) {
            builds++;
            return Text('$v');
          },
        ),
      ));
      results.add(await runScenario(
        tester,
        'ValueListenableBuilder 1 builder',
        updates: 1000,
        update: (i) async {
          notifier.value = i;
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 2. Ten notifiers, ten builders, 1000 updates.
    {
      final notifiers = [for (var i = 0; i < 10; i++) ValueNotifier<int>(0)];
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            for (final notifier in notifiers)
              ValueListenableBuilder<int>(
                valueListenable: notifier,
                builder: (_, v, child) {
                  builds++;
                  return Text('$v');
                },
              ),
          ],
        ),
      ));
      results.add(await runScenario(
        tester,
        'ValueListenableBuilder 10 builders',
        updates: 1000,
        update: (i) async {
          for (final notifier in notifiers) {
            notifier.value = i;
          }
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 3. One hundred notifiers, one hundred builders, 100 updates.
    {
      final notifiers = [for (var i = 0; i < 100; i++) ValueNotifier<int>(0)];
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              for (final notifier in notifiers)
                ValueListenableBuilder<int>(
                  valueListenable: notifier,
                  builder: (_, v, child) {
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
        'ValueListenableBuilder 100 builders',
        updates: 100,
        update: (i) async {
          for (final notifier in notifiers) {
            notifier.value = i;
          }
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    for (final result in results) {
      // ignore: avoid_print
      print('BENCH $result');
    }
  });
}
