// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Bloc comparison: Cubit + BlocBuilder. Pin recorded in
// guide/Benchmarks.md.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_runner.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void set(int value) => emit(value);
}

void main() {
  testWidgets('Bloc scenarios', (tester) async {
    final results = <ScenarioResult>[];

    // 1. Single cubit, single BlocBuilder, 1000 updates.
    {
      final cubit = CounterCubit();
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: BlocBuilder<CounterCubit, int>(
          bloc: cubit,
          builder: (context, value) {
            builds++;
            return Text('$value');
          },
        ),
      ));
      results.add(await runScenario(
        tester,
        'Bloc 1 BlocBuilder',
        updates: 1000,
        update: (i) async {
          cubit.set(i);
          await tester.pump();
        },
        builds: () => builds,
      ));
      addTearDown(cubit.close);
    }

    // 2. Ten cubits, ten BlocBuilders, 1000 updates.
    {
      final cubits = [for (var i = 0; i < 10; i++) CounterCubit()];
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            for (final cubit in cubits)
              BlocBuilder<CounterCubit, int>(
                bloc: cubit,
                builder: (context, value) {
                  builds++;
                  return Text('$value');
                },
              ),
          ],
        ),
      ));
      results.add(await runScenario(
        tester,
        'Bloc 10 BlocBuilders',
        updates: 1000,
        update: (i) async {
          for (final cubit in cubits) {
            cubit.set(i);
          }
          await tester.pump();
        },
        builds: () => builds,
      ));
      for (final cubit in cubits) {
        addTearDown(cubit.close);
      }
    }

    for (final result in results) {
      // ignore: avoid_print
      print('BENCH $result');
    }
  });
}
