// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  test('recipe 13: deterministic training', () async {
    final journal = RecordingJournal();
    final gate = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
    );
    final handle = cognitive(
      cell: gate.cell,
      policy: predicatePolicy((object, {required host, arguments}) {
        if (object is! Pulse) return true;
        return (object.payload as int) < 100;
      }),
    );
    final outcomes = recordOutcomes(handle);
    for (var i = 0; i < 8; i++) {
      await gate.ingest(Pulse<int>.governed(
        payload: 200 + i,
        context: PulseContext.fromEntries([
          Ontology.domains.entry('finance'),
        ]),
      ));
      await Future<void>.delayed(Duration.zero);
      handle.recordOutcome(
        decisionId: handle.decisions.last.id,
        reward: -1.0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    Future<Map<String, dynamic>> train(EffectJournal j) async {
      final trained = await trainOffline(
        handle: handle,
        outcomes: outcomes.log,
        baseContext: handle.cell.context,
        trainer: contextualBandit(),
        journal: j,
        config: const TrainingConfig(minSupport: 3),
      );
      return trained.toMap();
    }

    final first = await train(journal);
    final replay = ReplayJournal(
      journal.records
          .map((r) => EffectRecord.fromJson(r.toJson()))
          .toList(growable: false),
    );
    final second = await train(replay);
    expect(second['policyBlock'], equals(first['policyBlock']));
    expect(second['decisionCount'], first['decisionCount']);
    expect(second['algorithm'], first['algorithm']);
    expect(second['averageReward'], first['averageReward']);
    outcomes.stop();
  });
}
