// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Provider todo list (before) — a ChangeNotifier list.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TodoModel extends ChangeNotifier {
  final List<String> items = ['first'];

  void add(String item) {
    items.add(item);
    notifyListeners();
  }
}

Widget buildTodoApp() {
  final model = TodoModel();
  return ChangeNotifierProvider.value(
    value: model,
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Consumer<TodoModel>(
                builder: (context, m, child) => ListView.builder(
                  itemCount: m.items.length,
                  itemBuilder: (context, i) =>
                      ListTile(title: Text(m.items[i])),
                ),
              ),
            ),
            TextButton(
              onPressed: () => model.add('item ${model.items.length + 1}'),
              child: const Text('add'),
            ),
          ],
        ),
      ),
    ),
  );
}
