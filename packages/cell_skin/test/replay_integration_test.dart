// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The in-process acceptance test: every remote call lands in the
/// target's own apply, every receipt is recorded, and the ledger
/// replays into a fresh graph with zero divergences.
library;

import 'package:cell/cell.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('membrane-driven applies replay with zero divergences', () async {
    final f = await SkinFixture.build(graphId: 'replay-home');

    await f.run(() async {
      await f.client
          .apply('home.living.thermostat', 'setTarget', positional: [19]);
      await f.client.apply('home.living.light', 'dim', positional: [0.5]);
    });
    await f.settle();

    expect(await f.ledger.lastSeq, greaterThanOrEqualTo(1));
    await f.ledger.verify();

    // Fresh graph with the same id and registrations — the definition
    // of a replay target.
    CellGraphRegistry.forceReset();
    final thermostat2 = Cell.state<int>(
      initial: 22,
      testRule: ValueGate((v) => v is int && v >= 16 && v <= 26),
    );
    final light2 = Cell.state<double>(initial: 0.8);
    final target = (CellGraph.builder(graphId: 'replay-home')
          ..register('home.living.thermostat', thermostat2.cell)
          ..register('home.living.light', light2.cell))
        .build();

    final result = await ReplayEngine.replay(ledger: f.ledger, target: target);
    expect(
      result.success,
      isTrue,
      reason: result.divergences.map((d) => d.toString()).join('; '),
    );
    expect(result.entriesReplayed, greaterThanOrEqualTo(2));
    expect(result.divergences, isEmpty);

    await f.membrane.close();
    await f.ledger.close();
  });
}
