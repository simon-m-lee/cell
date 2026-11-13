// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('two distinct cells cannot share an id', () {
    final a = Cell();
    final b = Cell();
    CellGraph.builder().register('shared', a).assertConsistent();
    expect(
      () => CellGraph.builder().register('shared', b),
      throwsA(anything),
    );
  });

  test('re-registering the same nucleus with the same name is a no-op', () {
    final cell = Cell();
    CellGraph.builder().register('x', cell);
    // A second builder can adopt the already-registered name — this is
    // what makes graph rebuilds work.
    final graph = (CellGraph.builder()..register('x', cell)).build();
    expect(graph.containsName('x'), isTrue);
    expect(cell.id, 'x');
  });

  test('re-registering with a different name is an error', () {
    final cell = Cell();
    CellGraph.builder().register('first', cell);
    expect(
      () => CellGraph.builder().register('second', cell),
      throwsArgumentError,
    );
  });

  test('CellGraphRegistry.forceReset clears ids', () {
    final cell = Cell();
    CellGraph.builder().register('x', cell);
    expect(cell.id, 'x');
    CellGraphRegistry.forceReset();
    expect(cell.id.startsWith('nucleus:'), isTrue);
  });

  test('a deputy resolves the registered name of its principal', () async {
    final cell = Cell.ingress<int>().cell;
    CellGraph.builder().register('counter', cell);
    final deputy = await cell.deputy(testRule: TestCell.readOnly);
    expect(cell.id, 'counter');
    expect(deputy.id, 'counter');
  });
}
