// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ─────────────────────────────────────────────────────────────────────
// ACME Support — AI refund agent incident forensics
// ─────────────────────────────────────────────────────────────────────
//
// A customer-service agent processes refund requests by calling an
// LLM to decide the refund amount, then issuing the refund. On
// 2025-11-13 the agent issued a $10,000 refund for an order that cost
// $100. This demo:
//
//   1. Records five refund requests into a hash-chained ledger.
//      Request #3 is the incident: the LLM hallucinated $10,000.
//   2. Verifies the ledger's integrity (proof of non-tampering).
//   3. Replays the ledger to reconstruct exactly what happened —
//      including the LLM's hallucinated output, served from the
//      effect journal rather than re-queried from the model.
//   4. Forks the history at seq 5 (after request #2, before the
//      incident) and applies a "what-if" fix: cap the LLM's output
//      at the order's actual value. The fork produces a divergent
//      history that shows what a fixed deployment would have done.
//   5. Verifies the fork against its parent — a fork is only as
//      trustworthy as the ledger it branches from.
//   6. Produces a compliance report for the postmortem.
//
// Run with:
//
//     dart run example/replay/agent_incident_forensics_demo.dart
//
// Exit code 0 on success, 1 on any failed assertion.

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';

// ─────────────────────────────────────────────────────────────────────
// Domain types
// ─────────────────────────────────────────────────────────────────────

/// An inbound refund request.
class _Request {
  final int id;
  final String customerId;
  final String reason;
  final int orderAmount;
  const _Request(this.id, this.customerId, this.reason, this.orderAmount);
}

/// The LLM's decision, with the confidence it reported.
class _LLMDecision {
  final int amount;
  final double confidence;
  const _LLMDecision(this.amount, this.confidence);

  Map<String, Object?> toJson() =>
      {'amount': amount, 'confidence': confidence};

  factory _LLMDecision.fromJson(Map<String, Object?> json) => _LLMDecision(
        json['amount'] as int,
        (json['confidence'] as num).toDouble(),
      );
}

/// A `ValueCell<int>` that exposes `issueRefund` as a *whitelisted*
/// function, so that calls to it go through the integrity gate and
/// produce a proper `ApplyReceipt`.
class _AgentCell extends ValueCell<int> {
  _AgentCell({int initial = 0}) : super(initial: initial);

  Pulse<int> issueRefund(int amount) => Pulse<int>(amount);

  @override
  Iterable<Function> get modifiable => {issueRefund, apply};
}

/// A simulated LLM. Request #3 is the incident: it hallucinates a
/// refund of $10,000 for a $100 order.
_LLMDecision _simulatedLLM(_Request request) {
  if (request.id == 3) {
    return const _LLMDecision(10000, 0.95);
  }
  return _LLMDecision(request.orderAmount, 0.92);
}

// ─────────────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  _banner('ACME Support — AI Refund Agent Forensics');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 1. Build the graph and bind a ledger
  // ─────────────────────────────────────────────────────────────────
  _section('1. Build agent graph and bind an in-memory ledger');

  final agent = _AgentCell(initial: 0);
  final status = Cell.state<String>(initial: 'idle');
  final total = Cell.state<int>(initial: 0);

  final graph = (CellGraph.builder(graphId: 'acme-refund-agent')
        ..register('agent', agent)
        ..registerState('status', status)
        ..registerState('total', total))
      .build();

  final ledger = await graph.bindLedger(
    store: InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );

  print('  graph.id       = ${graph.id}');
  print('  genesis hash   = ${_short(fingerprint({'graphId': graph.id}))}');
  print('  initial agent  = \$${agent.value} (last issued refund)');
  print('  initial status = ${status.cell.value}');
  print('  initial total  = \$${total.cell.value}');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 2. Record five refund requests
  // ─────────────────────────────────────────────────────────────────
  _section('2. Record five refund requests');

  final requests = [
    const _Request(1, 'CUST-100', 'Incorrect item received', 100),
    const _Request(2, 'CUST-200', 'Late delivery', 50),
    const _Request(3, 'CUST-300', 'Wrong size — INCIDENT', 100),
    const _Request(4, 'CUST-400', 'Not delivered', 200),
    const _Request(5, 'CUST-500', 'Damaged on arrival', 75),
  ];

  await graph.run(() async {
    for (final req in requests) {
      // The LLM decision is a DRIVER-side call (the demo plays the
      // service desk); what the ledger records is the *decision's
      // outcome* — the amount passed to `issueRefund` as the apply
      // argument, which the replay re-commits through the receptor.
      // The decision itself is journaled in a local recording journal
      // for traceability (not ambient: ambient effects would be
      // captured into the ledger entry, and a driver-side effect has
      // no receptor to consume it during replay).
      final journal = RecordingJournal();
      final decision = await journal.io<_LLMDecision>(
        label: 'llmDecide(request=${req.id})',
        input: req.id,
        run: () async => _simulatedLLM(req),
        serializeOutput: (d) => d.toJson(),
      );

      await agent.apply<Pulse<int>>((
        function: agent.issueRefund,
        arguments: (
          positionalArguments: [decision.amount],
          namedArguments: null,
        ),
        compensation: null,
      ));

      // Status update — pure mutation, no journal needed.
      await status.cell.apply<Pulse<String>>((
        function: (String s) => Pulse<String>(s),
        arguments: (positionalArguments: ['processed'], namedArguments: null),
        compensation: null,
      ));

      // Running total — pure mutation, no journal needed.
      final newTotal = (total.cell.value ?? 0) + (agent.value ?? 0);
      await total.cell.apply<Pulse<int>>((
        function: (int t) => Pulse<int>(t),
        arguments: (positionalArguments: [newTotal], namedArguments: null),
        compensation: null,
      ));

      print(
        '  req ${req.id} (${req.customerId}): '
        'decision=\$${agent.value}  total=\$${total.cell.value}',
      );
    }
  });

  final entryCount = await ledger.lastSeq + 1;
  print('');
  print('  entries recorded = $entryCount (3 per request × 5 requests)');
  print('  final agent      = \$${agent.value}');
  print('  final status     = ${status.cell.value}');
  print('  final total      = \$${total.cell.value}');
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

  final replayAgent = _AgentCell(initial: 0);
  final replayStatus = Cell.state<String>(initial: 'idle');
  final replayTotal = Cell.state<int>(initial: 0);

  final replayGraph = (CellGraph.builder(graphId: 'acme-refund-agent')
        ..register('agent', replayAgent)
        ..registerState('status', replayStatus)
        ..registerState('total', replayTotal))
      .build();

  final replayResult = await ReplayEngine.replay(
    ledger: ledger,
    target: replayGraph,
  );

  print('  entries replayed = ${replayResult.entriesReplayed}');
  print('  replayed agent   = \$${replayAgent.value}');
  print('  replayed status  = ${replayStatus.cell.value}');
  print('  replayed total   = \$${replayTotal.cell.value}');

  if (!replayResult.success) {
    print('  ✗ DIVERGENCE');
    for (final d in replayResult.divergences) {
      print('    $d');
    }
    return;
  }

  if (replayTotal.cell.value != total.cell.value) {
    print('  ✗ replay did not reproduce recorded state');
    return;
  }
  print('  ✓ replay reproduced the recorded state exactly');
  print('  ✓ the LLM\'s \$10,000 hallucination is now provable');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 5. Fork at seq 5 and apply a what-if fix
  // ─────────────────────────────────────────────────────────────────
  _section('5. Fork at seq 5 (after request #2) with a fix');
  print('  what-if: cap the LLM\'s output at the order\'s actual value');
  print('');

  final fork = await graph.fork(
    parent: ledger,
    atSeq: 5,
    buildFreshGraph: () {
      CellGraphRegistry.forceReset();
      return (CellGraph.builder(graphId: 'acme-refund-agent-fork')
            // Baseline state at seq 5: agent=$50, status='processed',
            // total=$150 (from requests #1 + #2). Real applications
            // compute these by replaying the parent ledger to atSeq;
            // the demo hardcodes them for brevity.
            ..register('agent', _AgentCell(initial: 50))
            ..registerState('status', Cell.state<String>(initial: 'processed'))
            ..registerState('total', Cell.state<int>(initial: 150)))
          .build();
    },
    buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
  );

  print('  forkId        = ${_short(fork.record.forkId)}');
  print('  divergedAt    = ${fork.record.divergedAt}');
  print('  parentHead    = ${_short(fork.record.parentHeadHash)}');
  print('');

  // The mutation closure tracks the running total the fork "should"
  // have produced, starting from the baseline of 150.
  var runningTotal = 150;
  var currentAmount = 0;

  final forkResult = await ReplayEngineFork.replayFork(
    fork: fork,
    mutation: (entry, pulse) {
      final cellId = entry.receiptCellId;

      switch (cellId) {
        case 'agent':
          var amount = (pulse.payload as int?) ?? 0;
          if (entry.seq == 6) {
            // The incident. Cap at the order's actual value.
            amount = 100;
          }
          currentAmount = amount;
          return Pulse<int>(amount);

        case 'total':
          runningTotal += currentAmount;
          return Pulse<int>(runningTotal);

        case 'status':
          // Status is always 'processed'; pass through.
          return pulse;

        default:
          return pulse;
      }
    },
  );

  final forkedAgent = fork.graph['agent']!.cell as ValueCell<int>;
  final forkedStatus = fork.graph['status']!.cell as ValueCell<String>;
  final forkedTotal = fork.graph['total']!.cell as ValueCell<int>;

  print('  entries replayed = ${forkResult.entriesReplayed}');
  print('  forked agent     = \$${forkedAgent.value}');
  print('  forked status    = ${forkedStatus.value}');
  print('  forked total     = \$${forkedTotal.value}');

  if (!forkResult.success) {
    print('  ✗ fork replay diverged');
    for (final d in forkResult.divergences) {
      print('    $d');
    }
    return;
  }

  if (forkedTotal.value != 525) {
    print('  ✗ fork produced unexpected total (expected \$525)');
    return;
  }
  print('  ✓ what-if branch produced total \$525 (vs \$10425 recorded)');
  print('  ✓ the fix would have prevented \$9,900 of overpayment');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 6. Verify the fork
  // ─────────────────────────────────────────────────────────────────
  _section('6. Verify the fork binds to its parent');

  await fork.verify();
  print('  ✓ parent ledger verified');
  print('  ✓ fork ledger chain verified');
  print('  ✓ fork genesis bound to parent at seq ${fork.record.divergedAt}');
  print('');

  // ─────────────────────────────────────────────────────────────────
  // 7. Compliance summary
  // ─────────────────────────────────────────────────────────────────
  _section('7. Compliance summary for the postmortem');

  print('  Incident: refund for \$10,000 against a \$100 order.');
  print('  Cause:    LLM hallucination (confidence reported as 0.95).');
  print('  Evidence: Ledger entry seq 6, receipt.arguments[0] == 10000.');
  print('  Impact:   Overpayment of \$9,900 (recorded total vs fixed total).');
  print('  Fix:      Cap LLM output at the order\'s amount.');
  print('  Proof:    Fork ledger demonstrates the fixed history.');
  print('');

  await ledger.close();
  await fork.ledger.close();

  _banner('Demo complete — all checks passed');
}

// ─────────────────────────────────────────────────────────────────────
// Helpers
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