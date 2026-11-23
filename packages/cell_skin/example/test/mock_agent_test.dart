// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The plan's demo scenario assertions: the expected ledger, the real
/// rejection, the batched pair, and the zero-divergence replay — with
/// the view-model state read from the demo's UI cells.
library;

import 'package:cell/cell.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_home/models/agent_event.dart';
import 'package:echo_home/mock/mock_home.dart';
import 'package:echo_home/mock/mock_scenario.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('demo scenario produces the expected ledger', () async {
    final scenario = MockScenario();
    await scenario.start();

    // Wait for the scripted timeline (4× speed) to finish.
    for (var i = 0; i < 600; i++) {
      if (!scenario.isRunning &&
          (scenario.state.ledgerSeq.cell.value ?? -1) >= 2) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final home = scenario.home;

    // 1. Accepted — the real target apply.
    expect(home.thermostat.cell.value, 19.0);

    // 2. Rejected — the real TestCell. The ledger records mutations,
    // not denials: the rejected lock wrote no entry and no delta.
    final entries = await home.ledger.entriesSince(0).toList();
    expect(entries, hasLength(3)); // setTarget + the tx pair
    expect(entries[0].receipt.cell.id, 'home.living.thermostat');

    // 3. Batching — one wire call, two entries, both or neither.
    expect(entries[1].receipt.cell.id, 'home.living.light');
    expect(entries[2].receipt.cell.id, 'home.living.light.color');
    expect(home.light.cell.value, 0.5);
    expect(home.lightColor.cell.value, '#FDB813');

    // The bill read from the live domain cells moved down.
    expect(home.currentBill, lessThan(4.20));

    // The transcript cell carried the real rejection.
    final messages = scenario.state.transcript.cell.value ?? const [];
    final rejected = messages
        .whereType<AgentCallResult>()
        .where((message) => message.kind == OutcomeKind.rejected);
    expect(rejected, hasLength(1));
    expect(rejected.single.reason, isNotNull);
    expect(scenario.state.doorDenials.cell.value, 1);
    expect(home.door.cell.value, isFalse);

    // 4. Replay — zero divergences.
    await scenario.verifyAndReplay();
    expect(scenario.state.replayDivergences.cell.value, 0);

    await scenario.dispose();
  });

  test('the rejection is the framework gate, not the storyboard', () async {
    final home = MockHome();
    await home.build();

    // Same gate, same apply — the outcome is the framework's denial.
    final outcome = await home.graph
        .run(() => home.client.apply('home.front.door', 'lock'));
    expect(outcome, isA<ApplyRejected<Object?>>());

    // Unlocking (a different function) is allowed by the same gate.
    final unlocked = await home.graph
        .run(() => home.client.apply('home.front.door', 'unlock'));
    expect(unlocked, isA<ApplyAccepted<Object?>>());

    await home.close();
  });
}
