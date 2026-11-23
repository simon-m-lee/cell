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

  test('SkinClient applies through the membrane and reads the manifest',
      () async {
    final f = await SkinFixture.build();
    final client = f.client;

    final accepted = await f.run(() =>
        client.apply('home.living.thermostat', 'setTarget', positional: [19]));
    expect(accepted, isA<ApplyAccepted<Object?>>());
    expect(f.thermostat.cell.value, 19);

    final manifest = await f.run(client.manifest);
    expect(manifest.toolCount, 5);

    await f.membrane.close();
    await f.ledger.close();
  });

  test('SkinClient throws SkinError for exposure misses', () async {
    final f = await SkinFixture.build();
    await expectLater(
      f.run(() => f.client.apply('home.front.door', 'explode')),
      throwsA(isA<SkinError>().having((e) => e.code, 'code', 'unknown_tool')),
    );
    await f.membrane.close();
    await f.ledger.close();
  });

  test('RemoteCellClient calls and observes a remote cell in-process',
      () async {
    final f = await SkinFixture.build();
    final remote =
        RemoteCellClient.inProcess(f.client, 'home.living.thermostat');

    final outcome =
        await f.run(() => remote.call('setTarget', positional: [18]));
    expect(outcome, isA<ApplyAccepted<Object?>>());
    expect(f.thermostat.cell.value, 18);

    final changes = <Pulse<WireMessage>>[];
    final subscription = remote.observe().listen(changes.add);
    await f.run(() => f.thermostat.update(17));
    await f.settle();
    expect(changes, isNotEmpty);
    expect(changes.last.payload, isA<WireStateChange>());

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });
}
