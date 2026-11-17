// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// expect_lint fixtures for cell_collection_selector_without_equals.
// ignore_for_file: dead_null_aware_expression

// ignore_for_file: unused_local_variable

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: cell_avoid_creation_in_build
    final source = Cell.state<String>(initial: 'a b c');
    // expect_lint: cell_collection_selector_without_equals
    final listSelector = CellSelector<String, List<String>>(
      cell: source.cell,
      select: (v) => (v ?? '').split(' '),
      builder: (context, parts) => Text('$parts'),
    );
    // NOT a lint: equals provided.
    final okListSelector = CellSelector<String, List<String>>(
      cell: source.cell,
      select: (v) => (v ?? '').split(' '),
      equals: listEquals,
      builder: (context, parts) => Text('$parts'),
    );
    // expect_lint: cell_collection_selector_without_equals
    final setSelector = CellSelector<String, Set<String>>(
      cell: source.cell,
      select: (v) => (v ?? '').split(' ').toSet(),
      builder: (context, parts) => Text('$parts'),
    );
    // expect_lint: cell_collection_selector_without_equals
    final mapSelector = CellSelector<String, Map<String, String>>(
      cell: source.cell,
      select: (v) => {for (final p in (v ?? '').split(' ')) p: p},
      builder: (context, parts) => Text('$parts'),
    );
    // NOT a lint: S is not a collection.
    final intSelector = CellSelector<String, int>(
      cell: source.cell,
      select: (v) => (v ?? '').length,
      builder: (context, len) => Text('$len'),
    );
    // ignore: cell_collection_selector_without_equals
    final ignored = CellSelector<String, List<String>>(
      cell: source.cell,
      select: (v) => (v ?? '').split(' '),
      builder: (context, parts) => Text('$parts'),
    );
    return Column(
      children: [
        listSelector,
        okListSelector,
        setSelector,
        mapSelector,
        intSelector,
        ignored,
      ],
    );
  }
}

// useCell fixtures live in a helper so the file stays analyzer-clean.
Widget useCellCollectionFixture(ValueCell<String> source) {
  // expect_lint: cell_collection_selector_without_equals
  final bad = useCell<String, List<String>>(
    cell: source,
    select: (v) => (v ?? '').split(' '),
  );
  final ok = useCell<String, List<String>>(
    cell: source,
    select: (v) => (v ?? '').split(' '),
    equals: listEquals,
  );
  // NOT a lint: non-collection slice.
  final intSlice = useCell<String, int>(
    cell: source,
    select: (v) => (v ?? '').length,
  );
  return Text('${bad ?? ''} $ok ${intSlice ?? ''}');
}
