// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Riverpod comparison: ConsumerWidget + NotifierProvider (the ref.watch
// path). Pin recorded in guide/Benchmarks.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_runner.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

void main() {
  testWidgets('Riverpod scenarios', (tester) async {
    final results = <ScenarioResult>[];

    // 1. Single provider, single ConsumerWidget, 1000 updates.
    {
      final provider = NotifierProvider<CounterNotifier, int>(
        CounterNotifier.new,
      );
      var builds = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(builder: (context, ref, child) {
            final value = ref.watch(provider);
            builds++;
            return Text('$value');
          }),
        ),
      ));
      results.add(await runScenario(
        tester,
        'Riverpod 1 ConsumerWidget',
        updates: 1000,
        update: (i) async {
          container.read(provider.notifier).set(i);
          await tester.pump();
        },
        builds: () => builds,
      ));
    }

    // 2. Ten providers, ten ConsumerWidgets, 1000 updates.
    {
      final providers = [
        for (var i = 0; i < 10; i++)
          NotifierProvider<CounterNotifier, int>(CounterNotifier.new),
      ];
      var builds = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Column(
            children: [
              for (final provider in providers)
                Consumer(builder: (context, ref, child) {
                  final value = ref.watch(provider);
                  builds++;
                  return Text('$value');
                }),
            ],
          ),
        ),
      ));
      results.add(await runScenario(
        tester,
        'Riverpod 10 ConsumerWidgets',
        updates: 1000,
        update: (i) async {
          for (final provider in providers) {
            container.read(provider.notifier).set(i);
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
