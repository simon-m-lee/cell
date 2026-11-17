// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Bloc todo list (before) — a Cubit holding a list.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TodoCubit extends Cubit<List<String>> {
  TodoCubit() : super(['first']);

  void add() => emit([...state, 'item ${state.length + 1}']);
}

Widget buildTodoApp() {
  return BlocProvider(
    create: (_) => TodoCubit(),
    child: MaterialApp(
      home: Scaffold(
        body: BlocBuilder<TodoCubit, List<String>>(
          builder: (context, items) => Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListTile(title: Text(items[i])),
                ),
              ),
              TextButton(
                onPressed: () => context.read<TodoCubit>().add(),
                child: const Text('add'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
