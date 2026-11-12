// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('default Cell.state is pure', () {
    final state = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('counter', state))
        .build();
    expect(graph.purityOf('counter'), Purity.pure);
  });

  test('default derive is pure', () {
    final src = Cell.ingress<int>();
    final derived = Cell.derive<Pulse<int>, Pulse<int>>(
      source: src.cell,
      project: (p) => Pulse<int>((p.payload ?? 0) * 2),
    );
    final graph = (CellGraph.builder()
          ..register('src', src.cell)
          ..register('derived', derived))
        .build();
    expect(graph.purityOf('src'), Purity.pure);
    expect(graph.purityOf('derived'), Purity.pure);
  });

  test('asyncMap currently reports pure (Phase 3 will override)', () {
    // Phase 2 ships the plumbing; Phase 3 retrofits `asyncMap` to
    // `effectful`. This test pins the *current* default and is expected
    // to be updated in the Phase 3 commit that flips it.
    final src = Cell.ingress<int>();
    final map = Cell.asyncMap<int, String>(
      src.cell,
      (v) async => 'v=$v',
    );
    final graph = (CellGraph.builder()
          ..register('src', src.cell)
          ..register('mapped', map))
        .build();
    expect(graph.purityOf('mapped'), Purity.pure);
  });

  test('a custom receptor and rule can declare their purity', () {
    final receptor = Receptor((cell, pulse, {user}) => pulse);
    final graph = (CellGraph.builder()
          ..register('c', Cell(receptor: receptor)))
        .build();
    expect(receptor.purity, Purity.pure);
    expect(receptor.version, '0.0.0');
    expect(graph.purityOf('c'), Purity.pure);
    expect(TestCell.allowAll.purity, Purity.pure);
    expect(TestCell.allowAll.version, '0.0.0');
  });

  test('purityOf on an unregistered name fails loudly', () {
    final graph = (CellGraph.builder()..register('a', Cell())).build();
    expect(() => graph.purityOf('missing'), throwsArgumentError);
  });
}
