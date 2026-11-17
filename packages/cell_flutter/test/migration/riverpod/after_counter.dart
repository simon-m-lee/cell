// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Riverpod counter (after) — the cell_flutter version.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

Widget buildCounterApp() {
  final counter = Cell.state<int>(initial: 0);
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: CellBuilder<int>(
          cell: counter.cell,
          builder: (context, value) => TextButton(
            onPressed: () => counter.update((value ?? 0) + 1),
            child: Text('count: ${value ?? 0}'),
          ),
        ),
      ),
    ),
  );
}
