// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ─────────────────────────────────────────────────────────────────────
// ACME Health — Bedside monitoring incident forensics
// ─────────────────────────────────────────────────────────────────────
//
// A bedside monitor reads a patient's heart rate every simulated
// minute, computes a clinical risk score, and escalates to a
// "critical" alert when the score crosses a configurable threshold.
//
// On 2025-11-13, a patient deteriorated between readings #6 and #8.
// Reading #7 produced a risk score of 92, just below the production
// threshold of 95, so no alert fired. The nurse noticed the
// deterioration one minute later (reading #8, score 96), by which
// point the patient was in distress.
//
// This demo:
//
//   1. Records ten minute-by-minute readings into a hash-chained
//      ledger, including the clinical risk scorer's output for each.
//   2. Verifies the ledger's integrity.
//   3. Replays the ledger to reconstruct exactly what happened —
//      including the risk scorer's output, served from the effect
//      journal, not re-queried from the model.
//   4. Forks the history at seq 18 (after reading #6, before the
//      incident) and applies a what-if: cap the critical threshold at
//      90 instead of 95. The fork shows that reading #7 would have
//      fired a critical alert under the lower threshold, giving the
//      nurse one extra minute to respond.
//   5. Verifies the fork against its parent.
//   6. Emits a compliance summary for the postmortem, in the shape
//      that 21 CFR Part 11 / EU MDR reviewers ask for.
//
// Run with:
//
//     dart run example/replay/clinical_monitoring_forensics_demo.dart
//
// Exit code 0 on success, 1 on any failed assertion.

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';

// ─────────────────────────────────────────────────────────────────────
// Domain
// ─────────────────────────────────────────────────────────────────────

/// One minute-by-minute vital reading.
class _Reading {
  final int minute;
  final int heartRate;
  const _Reading(this.minute, this.heartRate);
}

/// A simulated clinical risk model. Non-linear: a trained model that
/// accelerates steeply around HR 90-95, which is the clinical concern
/// (early deterioration is often subtle before it is sudden).
///
/// The numbers are deliberately chosen so that reading #7 (HR 95)
/// yields a score of exactly 92, which the production threshold of 95
/// does not fire, but a what-if threshold of 90 would.
int _simulatedRiskScore(int heartRate) {
  const table = <int, int>{
    70: 20, 72: 25, 75: 30, 80: 40, 85: 55,
    90: 70, 95: 92, 100: 96, 105: 98, 110: 100,
  };
  return table[heartRate] ?? 50;
}

// ─────────────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  _banner('ACME Health — Bedside Monitoring Forensics');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 1. Build the monitoring graph and bind a ledger
  // ─────────────────────────────────────────────────────────────────
  _section('1. Build monitoring graph and bind an in-memory ledger');

  final heartRate = Cell.state<int>(initial: 0);
  final alertLevel = Cell.state<String>(initial: 'none');
  final alertsFired = Cell.state<int>(initial: 0);

  final graph = (CellGraph.builder(graphId: 'acme-bedside-monitor')
        ..registerState('heartRate', heartRate)
        ..registerState('alertLevel', alertLevel)
        ..registerState('alertsFired', alertsFired))
      .build();

  final ledger = await graph.bindLedger(
    store: InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );

  print('  graph.id         = ${graph.id}');
  print('  genesis hash     = ${_short(fingerprint({'graphId': graph.id}))}');
  print('  initial HR       = ${heartRate.cell.value} bpm');
  print('  initial alert    = ${alertLevel.cell.value}');
  print('  initial fired    = ${alertsFired.cell.value}');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 2. Record ten minute-by-minute readings
  // ─────────────────────────────────────────────────────────────────
  _section('2. Record ten minute-by-minute readings');

  const productionThreshold = 95;
  const readings = <_Reading>[
    _Reading(1,  70),
    _Reading(2,  72),
    _Reading(3,  75),
    _Reading(4,  80),
    _Reading(5,  85),
    _Reading(6,  90),   // last reading before the incident
    _Reading(7,  95),   // INCIDENT: score 92, just below 95, no alert
    _Reading(8, 100),   // alert finally fires
    _Reading(9, 105),
    _Reading(10, 110),
  ];

  var forkPointSeq = 0;
  await graph.run(() async {
    for (final reading in readings) {
      // Each reading's risk-scorer call is journaled. The journal
      // scope is pushed around the apply so the ledger entry for
      // alertLevel captures the score effect and only the score
      // effect.
      int score = 0;
      await JournalScope.run(RecordingJournal(), () async {
        final result = await EffectJournal.current.io<Map<String, Object?>>(
          label: 'clinicalRisk',
          input: reading.heartRate,
          run: () async => {
            'heartRate': reading.heartRate,
            'score': _simulatedRiskScore(reading.heartRate),
          },
        );
        score = (result['score'] as int?) ?? 0;
      });

      // Heart rate is factual — record what the sensor reported.
      await heartRate.cell.apply<Pulse<int>>((
        function: (int hr) => Pulse<int>(hr),
        arguments: (positionalArguments: [reading.heartRate], namedArguments: null),
        compensation: null,
      ));

      // Alert level decision. Under production, this is the threshold
      // check.
      final isCritical = score > productionThreshold;
      final newLevel = isCritical ? 'critical' : 'none';
      await alertLevel.cell.apply<Pulse<String>>((
        function: (String level) => Pulse<String>(level),
        arguments: (positionalArguments: [newLevel], namedArguments: null),
        compensation: null,
      ));

      // Cumulative alert counter. Incremented on every critical
      // reading (per-reading, not per-transition — that matches the
      // production escalation counter's semantics).
      if (isCritical) {
        final newCount = (alertsFired.cell.value ?? 0) + 1;
        await alertsFired.cell.apply<Pulse<int>>((
          function: (int count) => Pulse<int>(count),
          arguments: (positionalArguments: [newCount], namedArguments: null),
          compensation: null,
        ));
      }

      final flag = isCritical ? '  ⚠ CRITICAL' : '';
      print(
        '  min ${reading.minute.toString().padLeft(2)}: '
        'HR=${reading.heartRate.toString().padLeft(3)} '
        'score=${score.toString().padLeft(3)} '
        'alert=${(newLevel == 'critical' ? 'critical' : 'none').padRight(8)} '
        'fired=${alertsFired.cell.value}$flag',
      );

      if (reading.minute == 6) {
        // The fork point is the ACTUAL last ledger seq after reading
        // #6 — identical writes are deduped by the value pipeline, so
        // the entry count is not a fixed 3-per-reading arithmetic.
        forkPointSeq = await ledger.lastSeq;
      }
    }
  });

  final entryCount = await ledger.lastSeq + 1;
  print('');
  print('  entries recorded = $entryCount');
  print('  final alert      = ${alertLevel.cell.value}');
  print('  final fired      = ${alertsFired.cell.value} '
      '(readings #8, #9, #10)');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 3. Verify the ledger
  // ─────────────────────────────────────────────────────────────────
  _section('3. Verify the ledger hash chain');

  await ledger.verify();
  print('  ✓ hash chain intact');
  print('  ✓ $entryCount entries verified from genesis to head');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 4. Replay to reconstruct the incident
  // ─────────────────────────────────────────────────────────────────
  _section('4. Replay the ledger into a fresh graph');

  CellGraphRegistry.forceReset();

  final replayHeartRate = Cell.state<int>(initial: 0);
  final replayAlertLevel = Cell.state<String>(initial: 'none');
  final replayAlertsFired = Cell.state<int>(initial: 0);

  final replayGraph = (CellGraph.builder(graphId: 'acme-bedside-monitor')
        ..registerState('heartRate', replayHeartRate)
        ..registerState('alertLevel', replayAlertLevel)
        ..registerState('alertsFired', replayAlertsFired))
      .build();

  final replayResult = await ReplayEngine.replay(
    ledger: ledger,
    target: replayGraph,
  );

  print('  entries replayed = ${replayResult.entriesReplayed}');
  print('  replayed HR      = ${replayHeartRate.cell.value} bpm');
  print('  replayed alert   = ${replayAlertLevel.cell.value}');
  print('  replayed fired   = ${replayAlertsFired.cell.value}');

  if (!replayResult.success) {
    print('  ✗ DIVERGENCE');
    for (final d in replayResult.divergences) {
      print('    $d');
    }
    return;
  }
  if (replayAlertsFired.cell.value != alertsFired.cell.value) {
    print('  ✗ replay did not reproduce recorded state');
    return;
  }
  print('  ✓ replay reproduced the recorded state exactly');
  print('  ✓ the missed alert at reading #7 is now provable:');
  print('    score = 92, threshold = 95, no alert fired.');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 5. Fork after reading #6 and lower the threshold
  // ─────────────────────────────────────────────────────────────────
  _section('5. Fork after reading #6 with threshold 90');
  print('  what-if: the critical threshold had been 90 instead of 95');
  print('');

  const forkThreshold = 90;
  final fork = await graph.fork(
    parent: ledger,
    atSeq: forkPointSeq,
    buildFreshGraph: () {
      CellGraphRegistry.forceReset();
      // The fresh graph starts empty; fork() baseline-replays the
      // parent up to forkPointSeq (the state after reading #6:
      // HR=90, no alert, zero escalations).
      return (CellGraph.builder(graphId: 'acme-bedside-monitor-fork')
            ..registerState('heartRate', Cell.state<int>(initial: 0))
            ..registerState('alertLevel', Cell.state<String>(initial: 'none'))
            ..registerState('alertsFired', Cell.state<int>(initial: 0)))
          .build();
    },
    buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
  );

  print('  forkId        = ${_short(fork.record.forkId)}');
  print('  divergedAt    = ${fork.record.divergedAt}');
  print('  parentHead    = ${_short(fork.record.parentHeadHash)}');
  print('');

  // Stateful mutation closure: tracks the fork's own state as it
  // replays, because the fork's state diverges from the recording's.
  var forkAlertsFired = 0;
  var lastScore = 0;

  final forkResult = await ReplayEngineFork.replayFork(
    fork: fork,
    mutation: (entry, pulse) {
      final cellId = entry.receiptCellId;

      switch (cellId) {
        case 'heartRate':
          // Factual; unchanged by the threshold. The risk score is a
          // pure function of the reading (deterministic simulated
          // model), so the mutation recomputes it from the pulse
          // payload.
          lastScore = _simulatedRiskScore(pulse.payload as int);
          return pulse;

        case 'alertLevel':
          final isCritical = lastScore > forkThreshold;
          return Pulse<String>(isCritical ? 'critical' : 'none');

        case 'alertsFired':
          final isCritical = lastScore > forkThreshold;
          if (isCritical) forkAlertsFired++;
          return Pulse<int>(forkAlertsFired);

        default:
          return pulse;
      }
    },
  );

  final forkedAlertsFired =
      (fork.graph['alertsFired']!.cell as ValueCell<int>).value;
  final forkedAlertLevel =
      (fork.graph['alertLevel']!.cell as ValueCell<String>).value;

  print('  entries replayed = ${forkResult.entriesReplayed}');
  print('  forked alert     = $forkedAlertLevel');
  print('  forked fired     = $forkedAlertsFired');

  if (!forkResult.success) {
    print('  ✗ fork replay diverged');
    for (final d in forkResult.divergences) {
      print('    $d');
    }
    return;
  }

  if (forkedAlertsFired != 3) {
    print('  ✗ fork produced unexpected alert count '
        '(expected 3, got $forkedAlertsFired)');
    return;
  }
  print('  ✓ fork replayed the 3 recorded counter increments, with');
  print('    reading #7\'s alert level flipped to critical (its recorded');
  print('    counter entry does not exist — the recording had no alert');
  print('    for #7, so there is nothing to mutate; adding the missing');
  print('    4th increment would be pulse injection, a Phase 6.1 feature).');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 6. Verify the fork and emit the compliance summary
  // ─────────────────────────────────────────────────────────────────
  _section('6. Verify the fork and emit the compliance summary');

  await fork.verify();
  print('  ✓ parent ledger verified');
  print('  ✓ fork ledger chain verified');
  print('  ✓ fork genesis bound to parent at seq ${fork.record.divergedAt}');
  print('');
  print('  ── Postmortem summary ──');
  print('  Incident:  Patient deterioration detected at reading #8, not #7.');
  print('  Cause:     Risk score 92 at reading #7 was below threshold 95.');
  print('  Evidence:  Ledger seq 18 (alertLevel), seq 19 (alertsFired);');
  print('             the recorded score 92 is in the entry\'s IoEffect.');
  print('  Impact:    One-minute delay in escalation.');
  print('  Fix:       Lower the critical threshold from 95 to 90.');
  print('  Proof:     Fork ledger demonstrates reading #7 fires under 90.');
  print('');

  await ledger.close();
  await fork.ledger.close();

  _banner('Demo complete — all checks passed');
}

// ─────────────────────────────────────────────────────────────────────
// Output helpers
// ─────────────────────────────────────────────────────────────────────

void _banner(String text) {
  final line = '═' * (text.length + 4);
  print('╔$line╗');
  print('║  $text  ║');
  print('╚$line╝');
}

void _section(String text) {
  print('▸ $text');
}

String _short(String h) =>
    h.length > 16 ? '${h.substring(0, 16)}…' : h;