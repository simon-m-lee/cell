// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CounterApp());

class CounterApp extends StatefulWidget {
  const CounterApp({super.key});
  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  late final StateHandle<int> _counter = Cell.state<int>(initial: 0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mitosis Counter')),
        body: Center(
          child: CellBuilder<int>(
            cell: _counter.cell.unmodifiable,
            builder: (_, value) => Semantics(
              label: 'Counter value',
              child: Text(
                '${value ?? 0}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add one',
          onPressed: () => _counter.update((_counter.cell.value ?? 0) + 1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
