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
  test('recipe 8: learning from rejections', () async {
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
    for (var i = 0; i < 12; i++) {
      await gate.ingest(Pulse<int>.governed(
        payload: 200 + i,
        context: PulseContext.fromEntries([
          Ontology.domains.entry('finance'),
        ]),
      ));
      await Future<void>.delayed(Duration.zero);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>());
      handle.recordOutcome(decisionId: decision.id, reward: -1.0);
    }
    await Future<void>.delayed(Duration.zero);
    final trained = await trainOffline(
      handle: handle,
      outcomes: outcomes.log,
      baseContext: handle.cell.context,
      trainer: contextualBandit(),
      journal: journal,
      config: const TrainingConfig(minSupport: 5),
    );
    expect(trained.ruleCount, greaterThan(0));
    final evolved = trained.applyTo(handle.cell.context);
    expect(evolved.constraints, contains('cell_mind.policy'));
    outcomes.stop();
  });
}
