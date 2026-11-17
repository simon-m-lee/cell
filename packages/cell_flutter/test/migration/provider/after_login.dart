// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Provider login (after) — CellTextField with a
// computed validity cell fed by both fields' onChanged (the pattern for
// values derived from several sources).

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

Widget buildLoginApp() {
  final email = Cell.state<String>(initial: '');
  final password = Cell.state<String>(initial: '');
  final valid = Cell.state<bool>(initial: false);

  void recalculate() => valid.update(
        (email.cell.value ?? '').contains('@') &&
            (password.cell.value ?? '').length >= 6,
      );

  return MaterialApp(
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CellTextField(
            cell: email.cell,
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (_) => recalculate(),
          ),
          CellTextField(
            cell: password.cell,
            decoration: const InputDecoration(labelText: 'Password'),
            onChanged: (_) => recalculate(),
          ),
          CellBuilder<bool>(
            cell: valid.cell,
            builder: (context, v) =>
                Text(v == true ? 'logged in' : 'not valid'),
          ),
        ],
      ),
    ),
  );
}
