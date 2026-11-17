// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Riverpod todo list (before, riverpod 3.x).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodoNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['first'];

  void add() => state = [...state, 'item ${state.length + 1}'];
}

final todoProvider = NotifierProvider<TodoNotifier, List<String>>(
  TodoNotifier.new,
);

Widget buildTodoApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: _TodoView()),
    ),
  );
}

class _TodoView extends ConsumerWidget {
  const _TodoView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todoProvider);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(title: Text(items[i])),
          ),
        ),
        TextButton(
          onPressed: () => ref.read(todoProvider.notifier).add(),
          child: const Text('add'),
        ),
      ],
    );
  }
}
