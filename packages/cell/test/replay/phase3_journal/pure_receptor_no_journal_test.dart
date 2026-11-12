// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

/// A test-local receptor that opts into the effectful contract via the
/// mixin — the one-liner that pins exit criterion 9.
class _EffectfulReceptor extends ReceptorBase<Cell> with Effectful {
  _EffectfulReceptor() : super();

  @override
  Receptor<Cell> get clone => _EffectfulReceptor();
}

void main() {
  test('pure receptor replays without any journal', () {
    // No journal in scope; no journal is needed. A pure Cell.state
    // update must go through cleanly.
    final state = Cell.state<int>(initial: 0);
    state.update(42);
    expect(state.cell.value, 42);
  });

  test('derive is pure and needs no journal', () {
    final src = Cell.ingress<int>();
    final derived = Cell.derive<Pulse<int>, Pulse<int>>(
      source: src.cell,
      project: (p) => Pulse<int>((p.payload ?? 0) * 2),
    );
    final seen = <int>[];
    Cell.observe(
      source: derived,
      effect: (Pulse p) => seen.add(p.payload as int),
    );
    src.emit(3);
    expect(seen, [6]);
  });

  test('the Effectful mixin produces Purity.effectful', () {
    expect(_EffectfulReceptor().purity, Purity.effectful);
    expect(_EffectfulReceptor().purity.isExactlyReplayable, isFalse);
  });
}
