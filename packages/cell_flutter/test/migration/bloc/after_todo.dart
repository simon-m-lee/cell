// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Bloc todo list (after) — CellListView.builder.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

Widget buildTodoApp() {
  final items = Cell.state<List<String>>(initial: ['first']);
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CellListView<String>.builder(
              cell: items.cell,
              itemBuilder: (context, item, i) => ListTile(title: Text(item)),
            ),
          ),
          TextButton(
            onPressed: () => items.update([
              ...items.cell.value ?? <String>[],
              'item ${(items.cell.value?.length ?? 0) + 1}',
            ]),
            child: const Text('add'),
          ),
        ],
      ),
    ),
  );
}
