// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The receipt-provenance suite: the router calls `target.apply` — never
/// its own — and the wire carries the target's real receipt.
library;

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('accepted dispatch carries the target receipt', () async {
    final f = await SkinFixture.build();
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTarget',
            positional: {'0': 19},
            correlationId: 'c-accepted',
          ),
          type: SkinPulseTypes.mcpToolsCall,
        ));
    expect(message, isA<WireResponse>());
    final response = message as WireResponse;
    expect(response.outcome, isA<ApplyAccepted<Object?>>());

    // Receipt provenance: the receipt belongs to the target, not the
    // transport; the ledger back-fills `ledgerSeq` on the stored copy
    // (the live receipt keeps it null).
    final receipt = response.outcome!.receipt;
    expect(receipt.cell.id, 'home.living.thermostat');
    expect(f.thermostat.cell.value, 19);
    expect(await f.ledger.lastSeq, 0);
    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries.single.receipt.ledgerSeq, 0);

    await f.membrane.close();
    await f.ledger.close();
  });

  test('rejected dispatch carries the real ApplyRejected', () async {
    final f = await SkinFixture.build();
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.front.door',
            function: 'lock',
            correlationId: 'c-lock',
          ),
          type: SkinPulseTypes.mcpToolsCall,
        ));
    expect(message, isA<WireResponse>());
    final response = message as WireResponse;
    expect(response.outcome, isA<ApplyRejected<Object?>>());
    expect(response.outcome!.receipt.cell.id, 'home.front.door');

    // The domain gate refused: state unchanged. The framework records
    // no ledger entry for a rejected attempt — the denial travels on
    // the receipt the wire carries, not in the ledger.
    expect(f.door.cell.value, isFalse);
    expect(await f.ledger.lastSeq, -1);

    await f.membrane.close();
    await f.ledger.close();
  });

  test('unknown tool produces a WireError with no receipt', () async {
    final f = await SkinFixture.build();
    final before = await f.ledger.lastSeq;
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.front.door',
            function: 'explode',
            correlationId: 'c-unknown',
          ),
          type: SkinPulseTypes.mcpToolsCall,
        ));
    expect(message, isA<WireError>());
    expect((message as WireError).code, 'unknown_tool');
    expect(message.correlationId, 'c-unknown');
    expect(await f.ledger.lastSeq, before, reason: 'no receipt, no entry');

    await f.membrane.close();
    await f.ledger.close();
  });

  test('manifest request returns the tool catalogue', () async {
    final f = await SkinFixture.build();
    final message = await f.run(() => f.membrane.request(
          const WireManifestRequest(),
          type: SkinPulseTypes.manifestRequest,
        ));
    expect(message, isA<WireManifestResponse>());
    final manifest = (message as WireManifestResponse).manifest;
    expect(manifest.toolCount, 5);
    expect(manifest.cells.map((c) => c.cellId),
        contains('home.living.thermostat'));

    await f.membrane.close();
    await f.ledger.close();
  });
}
