// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Canonical `cell_flutter_persistence` example: a counter whose value
/// hydrates from a persistence adapter and writes back on every change.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';
import 'package:flutter/material.dart';

void main() {
  final adapter = InMemoryAdapter<int>();
  final counter = persistedState<int>(
    restorationId: 'counter',
    initial: 0,
    adapter: adapter,
  );
  // Async hydration; with an empty in-memory store the cell keeps `initial`.
  counter.load();
  runApp(PersistedCounterApp(counter: counter));
}

/// Root widget of the example: renders the persisted counter and a
/// button that increments it.
class PersistedCounterApp extends StatefulWidget {
  /// Creates the example root with [counter] as the persisted state.
  const PersistedCounterApp({required this.counter, super.key});

  /// The [PersistedCell] the UI reads and increments.
  final PersistedCell<int> counter;

  @override
  State<PersistedCounterApp> createState() => _PersistedCounterAppState();
}

class _PersistedCounterAppState extends State<PersistedCounterApp> {
  @override
  void initState() {
    super.initState();
    // Register for process-kill restoration.
    CellRestorationScope.maybeOf(context)?.register(widget.counter.cell);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('cell_flutter_persistence example')),
        body: Center(
          child: CellBuilder<int>(
            cell: widget.counter.cell,
            builder: (_, value) => Text('Counter: ${value ?? 0}'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add one',
          onPressed: () =>
              widget.counter.cell.value = (widget.counter.cell.value ?? 0) + 1,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
