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

  test('asyncMap reports effectful (Phase 3 flip)', () {
    // Phase 2 pinned `pure` as a marker; Phase 3's journal retrofit flips
    // it: asyncMap is effectful and requires a journal.
    final src = Cell.ingress<int>();
    final map = Cell.asyncMap<int, String>(
      src.cell,
      (v, {required EffectJournal journal}) async => 'v=$v',
      journal: RecordingJournal(),
    );
    final graph = (CellGraph.builder()
          ..register('src', src.cell)
          ..register('mapped', map))
        .build();
    expect(graph.purityOf('mapped'), Purity.effectful);
  });

  test('debounce and throttle report readOnlyExternal', () {
    final src = Cell.ingress<int>();
    final journal = RecordingJournal();
    final db = Cell.debounce(src.cell, const Duration(milliseconds: 5),
        journal: journal);
    final th = Cell.throttle(src.cell, const Duration(milliseconds: 5),
        journal: journal);
    final graph = (CellGraph.builder()
          ..register('src', src.cell)
          ..register('db', db)
          ..register('th', th))
        .build();
    expect(graph.purityOf('db'), Purity.readOnlyExternal);
    expect(graph.purityOf('th'), Purity.readOnlyExternal);
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
