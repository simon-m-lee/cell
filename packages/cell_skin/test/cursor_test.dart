// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('a stale lastSeenSeq conflicts before the target apply runs', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'setTargetStrict',
          target: targets.thermostat.cell,
          nextValue: (int target) => target,
          strictCursor: true,
        ),
      ],
    );

    // Advance the ledger to head 0.
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    expect(await f.ledger.lastSeq, 0);

    // Stale cursor: conflict, no apply, no new entry.
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTargetStrict',
            positional: {'0': 17},
            correlationId: 'c-stale',
            lastSeenSeq: -1,
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    expect(message, isA<WireError>());
    expect((message as WireError).code, 'conflict');
    expect(f.thermostat.cell.value, 20);
    expect(await f.ledger.lastSeq, 0);

    // A missing cursor is rejected outright.
    final missing = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTargetStrict',
            positional: {'0': 17},
            correlationId: 'c-missing',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    expect(missing, isA<WireError>());
    expect((missing as WireError).code, 'cursor_required');

    // A cursor ahead of the head cannot have seen the current state —
    // strict equality is the rule, so it conflicts too.
    final ahead = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTargetStrict',
            positional: {'0': 17},
            correlationId: 'c-ahead',
            lastSeenSeq: 99,
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    expect(ahead, isA<WireError>());
    expect((ahead as WireError).code, 'conflict');
    expect(f.thermostat.cell.value, 20);
    expect(await f.ledger.lastSeq, 0);

    // Fresh cursor: proceeds.
    final ok = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTargetStrict',
            positional: {'0': 17},
            correlationId: 'c-fresh',
            lastSeenSeq: 0,
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    expect(ok, isA<WireResponse>());
    expect(f.thermostat.cell.value, 17);

    await f.membrane.close();
    await f.ledger.close();
  });
}
