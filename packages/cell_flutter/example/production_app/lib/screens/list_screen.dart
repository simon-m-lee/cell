// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// List screen — CellListView.builder over 120 derived cells, cell-driven
// navigation into the detail screen.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_router/cell_flutter_router.dart';
import 'package:flutter/material.dart';

import 'detail_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({required this.email, super.key});

  final String email;

  @override
  State<ListScreen> createState() => ListScreenState();
}

class ListScreenState extends State<ListScreen> {
  late final selectedId = Cell.state<int?>(initial: null);

  @override
  void initState() {
    super.initState();
    CellFlutterDevTools.register('list.selectedId', selectedId.cell);
  }

  @override
  void dispose() {
    CellFlutterDevTools.unregister('list.selectedId');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.email}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                CellRouterScope.of(context).router.go('/settings'),
          ),
        ],
      ),
      body: CellListView<String>.builder(
        cell: _itemNames.cell,
        itemBuilder: (ctx, name, i) => ListTile(
          title: Text(name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            selectedId.update(i);
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DetailScreen(index: i)),
            );
          },
        ),
      ),
    );
  }

  /// 120 display names, computed once when the state is created.
  final _itemNames = Cell.state<List<String>>(
    initial: [for (var i = 0; i < 120; i++) 'Item ${i + 1}'],
  );
}
