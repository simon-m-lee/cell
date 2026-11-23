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

  test('ledgered egress pairs each change with its own receipt', () async {
    final f = await SkinFixture.build();
    final changes = <WireStateChange>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireStateChange) {
        changes.add(pulse.payload as WireStateChange);
      }
    });

    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    await f.settle();
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    await f.settle();

    final thermostatChanges =
        changes.where((c) => c.cellId == 'home.living.thermostat').toList();
    expect(thermostatChanges.length, greaterThanOrEqualTo(2));
    final first = thermostatChanges[thermostatChanges.length - 2];
    final second = thermostatChanges.last;
    expect(first.pendingReceipt, isFalse);
    expect(second.pendingReceipt, isFalse);
    expect(first.receipt, isNotNull);
    expect(second.receipt, isNotNull);
    expect(first.receipt!.id, isNot(second.receipt!.id));
    expect(first.receipt!.cellId, 'home.living.thermostat');
    expect(first.payload, 20);
    expect(second.payload, 21);
    // Egress is not a reply: no correlation id exists to misattribute.
    expect(first.toJson().containsKey('correlationId'), isFalse);

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('unledgered egress marks every change pendingReceipt', () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'unledgered')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        function: (int target) => thermostat.update(target),
      ));
    final sent = <Pulse<WireMessage>>[];
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      journal: RecordingJournal(),
      send: sent.add,
    );

    final subscription = membrane.responses.listen((_) {});
    thermostat.update(18);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final changes = sent
        .where((p) => p.payload is WireStateChange)
        .map((p) => p.payload as WireStateChange)
        .toList();
    expect(changes, isNotEmpty);
    expect(changes.last.pendingReceipt, isTrue);
    expect(changes.last.receipt, isNull,
        reason: 'without a ledger there is no receipt — never fabricated');

    await subscription.cancel();
    await membrane.close();
  });

  test('the ledger stream appears as skin.ledger.entry pulses', () async {
    final f = await SkinFixture.build();
    final entries = <WireLedgerEntry>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireLedgerEntry) {
        entries.add(pulse.payload as WireLedgerEntry);
      }
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    await f.settle();
    expect(entries, isNotEmpty);
    expect(entries.last.entry.receiptCellId, 'home.living.thermostat');

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });
}
