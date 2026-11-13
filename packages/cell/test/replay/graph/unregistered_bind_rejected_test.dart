// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('strict mode rejects reachability through an unregistered bind', () {
    final upstream = Cell.state<int>(initial: 0);
    final downstream = Cell(bind: upstream.cell);

    // Register only the downstream — upstream is reachable but not
    // registered.
    final builder = CellGraph.builder()..register('downstream', downstream);
    expect(builder.build, throwsStateError);
  });

  test('terminal observers do not trip strict reachability (the graph registry scope)', () {
    final upstream = Cell.state<int>(initial: 0);
    // The observer is a downstream of `upstream` via its synapses — an
    // operator-internal wiring edge. Strict mode validates bind edges;
    // synapse plumbing (observers, asyncMap's bridge) is the journal's
    // journal concern.
    final observer = Cell.observe(
      source: upstream.cell,
      effect: (Pulse p) {},
    );

    final graph = (CellGraph.builder()..registerState('upstream', upstream))
        .build();
    expect(graph.containsName('upstream'), isTrue);
    observer.stop();
  });

  test('registering both ends passes', () {
    final upstream = Cell.state<int>(initial: 0);
    final downstream = Cell(bind: upstream.cell);

    final graph = (CellGraph.builder()
          ..registerState('upstream', upstream)
          ..register('downstream', downstream))
        .build();
    expect(graph.roots.length, 2);
    expect(graph.containsCell(downstream), isTrue);
  });

  test('unrestricted mode does not check reachability', () {
    final upstream = Cell.state<int>(initial: 0);
    final downstream = Cell(bind: upstream.cell);
    // No registration at all:
    final graph = CellGraph.unrestricted();
    expect(graph.strict, isFalse);
    expect(upstream.cell.id, startsWith('nucleus:'));
    expect(downstream.id, startsWith('nucleus:'));
  });
}
