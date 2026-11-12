// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('snapshot round-trips through JSON with identical ids', () {
    final a = Cell.state<int>(initial: 1);
    final b = Cell.state<String>(initial: 'hello');
    final graph = (CellGraph.builder(graphId: 'g-1')
          ..registerState('a', a)
          ..registerState('b', b))
        .build();

    final snapshot = graph.snapshot(lastLedgerSeq: 7);
    final json = canonicalJsonEncode(snapshot.toJson());
    final reparsed = CellGraphSnapshot.fromJson(
      canonicalJsonDecode(json) as Map<String, Object?>,
    );

    expect(reparsed.graphId, 'g-1');
    expect(reparsed.lastLedgerSeq, 7);
    expect(reparsed.cells.map((c) => c.id), ['a', 'b']);
    expect(reparsed.cells[0].value, 1);
    expect(reparsed.cells[1].value, 'hello');
    expect(reparsed.cells.every((c) => c.receptorVersion == '0.0.0'), isTrue);
  });

  test('snapshot config fingerprint changes when the rule changes', () {
    final a = Cell.state<int>(initial: 1);
    final graph1 = (CellGraph.builder()..registerState('a', a)).build();
    final s1 = graph1.snapshot();

    // Rebuild with a different test rule. The cell is registered under
    // the same name, but the rule changed, so the fingerprint must differ.
    CellGraphRegistry.forceReset();
    final a2 = Cell.state<int>(initial: 1, testRule: TestCell.readOnly);
    final graph2 = (CellGraph.builder()..registerState('a', a2)).build();
    final s2 = graph2.snapshot();

    expect(
      s1.cells.single.configFingerprint,
      isNot(s2.cells.single.configFingerprint),
    );
  });

  test('snapshot bytes are independent of registration order', () {
    final a = Cell.state<int>(initial: 1);
    final b = Cell.state<int>(initial: 2);

    final graph1 = (CellGraph.builder(graphId: 'g-order')
          ..registerState('a', a)
          ..registerState('b', b))
        .build();
    CellGraphRegistry.forceReset();
    final a2 = Cell.state<int>(initial: 1);
    final b2 = Cell.state<int>(initial: 2);
    final graph2 = (CellGraph.builder(graphId: 'g-order')
          ..registerState('b', b2)
          ..registerState('a', a2))
        .build();

    final bytes1 = canonicalJsonEncode(graph1.snapshot().toJson());
    final bytes2 = canonicalJsonEncode(graph2.snapshot().toJson());
    expect(bytes1, bytes2);
  });

  test('20-cell graph, snapshot, restore, identical state and ids', () {
    final states = <String, StateHandle<int>>{};
    for (var i = 0; i < 20; i++) {
      states['c$i'] = Cell.state<int>(initial: i);
    }
    final builder = CellGraph.builder(graphId: 'twenty');
    states.forEach((name, handle) => builder.registerState(name, handle));
    final graph = builder.build();

    final snapshot = graph.snapshot();
    expect(snapshot.cells.length, 20);
    for (final name in states.keys) {
      expect(graph[name]?.cell.id, name);
    }

    // Restore: parse the snapshot JSON, then verify every cell's id and
    // value survives.
    final reparsed = CellGraphSnapshot.fromJson(
      canonicalJsonDecode(canonicalJsonEncode(snapshot.toJson()))
          as Map<String, Object?>,
    );
    final byId = {for (final c in reparsed.cells) c.id: c.value};
    for (var i = 0; i < 20; i++) {
      expect(byId['c$i'], i);
    }
    expect(byId.keys, containsAll(states.keys));
  });
}
