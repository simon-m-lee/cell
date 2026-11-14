// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/material.dart';

void main() => runApp(const HooksCounterApp());

class HooksCounterApp extends StatelessWidget {
  const HooksCounterApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: HooksCounterHome());
}

class HooksCounterHome extends HookWidget {
  const HooksCounterHome({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = useMemoized(() => Cell.state<int>(initial: 0));
    final value = useCellValue(counter.cell);
    return Scaffold(
      appBar: AppBar(title: const Text('Hooks Counter')),
      body: Center(
        child: Semantics(
          label: 'Counter value',
          child: Text(
            '${value ?? 0}',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add one',
        onPressed: () => counter.update((counter.cell.value ?? 0) + 1),
        child: const Icon(Icons.add),
      ),
    );
  }
}
