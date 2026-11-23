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

  test('a whitelisted set hides bound functions from the wire', () async {
    final f = await SkinFixture.build(
      whitelist: SkinWhitelist({
        'home.living.thermostat': {'setTarget'},
      }),
    );

    // Whitelisted: works.
    final allowed = await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    expect(allowed, isA<ApplyAccepted<Object?>>());

    // Bound but not whitelisted: does not exist on the wire.
    final before = await f.ledger.lastSeq;
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.front.door',
            function: 'lock',
            correlationId: 'c-hidden',
          ),
          type: SkinPulseTypes.mcpToolsCall,
        ));
    expect(message, isA<WireError>());
    expect((message as WireError).code, 'unknown_tool');
    expect(await f.ledger.lastSeq, before,
        reason: 'exposure rejection produces no receipt, no entry');

    // The manifest reflects the policy.
    final manifest = f.membrane.manifest;
    expect(manifest.toolCount, 1);
    expect(manifest.cells.single.cellId, 'home.living.thermostat');

    await f.membrane.close();
    await f.ledger.close();
  });
}
