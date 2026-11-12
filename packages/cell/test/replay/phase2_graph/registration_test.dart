// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('registers a cell and exposes it under the registered name', () {
    final state = Cell.state<int>(initial: 0);
    final graph = CellGraph.builder()..registerState('counter', state);
    final built = graph.build();

    expect(built.containsName('counter'), isTrue);
    expect(state.cell.id, 'counter');
    expect(built['counter']?.cell, same(state.cell));
  });

  test('builder is single-use', () {
    final builder = CellGraph.builder();
    builder.build();
    expect(() => builder.register('late', Cell()), throwsStateError);
  });

  test('rejects empty name', () {
    expect(
      () => CellGraph.builder().register('', Cell()),
      throwsArgumentError,
    );
  });

  test('rejects duplicate name', () {
    final builder = CellGraph.builder()..register('a', Cell());
    expect(() => builder.register('a', Cell()), throwsArgumentError);
  });
}
