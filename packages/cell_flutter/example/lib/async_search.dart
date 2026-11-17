// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const SearchApp());

class SearchApp extends StatefulWidget {
  const SearchApp({super.key});
  @override
  State<SearchApp> createState() => _SearchAppState();
}

class _SearchAppState extends State<SearchApp> {
  late final IngressHandle<String> _query;
  late final Cell _results;

  @override
  void initState() {
    super.initState();
    _query = Cell.ingress<String>();
    _results = Cell.asyncMap<String, List<String>>(
      _query.cell,
      (q, {required EffectJournal journal}) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return [for (var i = 0; i < 3; i++) '$q result $i'];
      },
      journal: RecordingJournal(),
      latestOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Async search')),
        body: Column(
          children: [
            Semantics(
              label: 'Search field',
              textField: true,
              child: TextField(
                onChanged: _query.emit,
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  labelText: 'Search',
                ),
              ),
            ),
            Expanded(
              child: CellAsyncBuilder<List<String>>(
                cell: _results,
                builder: (_, snapshot) => switch (snapshot) {
                  AsyncSnapshot(hasData: true, data: final results) => ListView(
                      children: [
                        for (final r in results!) ListTile(title: Text(r)),
                      ],
                    ),
                  _ => Center(
                      child: Semantics(
                        label: 'Loading results',
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
