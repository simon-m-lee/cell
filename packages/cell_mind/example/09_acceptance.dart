// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (09_acceptance → the v1.0 acceptance run).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// The v1.0 acceptance pipeline — a fraud-detection flow that
/// exercises every module end-to-end:
///
/// policy → runtime → deferral → approval → bridge → learning →
/// deployment → multi-agent debate → XAI.
///
/// Run with:
/// ```bash
/// dart run example/09_acceptance.dart
/// ```
Future<void> main() async {
  final journal = RecordingJournal();

  // ── 1. Policy + runtime ──────────────────────────────────────
  final context = Context.fromEntries([
    Ontology.domains.entry('finance,marketing'),
    Ontology.version.entry('1.0.0'),
  ]);
  final policy = contextAware() + learnedPolicy();

  // ── 2. Deferral (verdict layer) ──────────────────────────────
  final verdictRule = verdictPolicy((object, {required host, arguments}) {
    if (object is! Pulse) return const Accept();
    final amount = (object.payload as Transaction).amount;
    if (amount > 10000) {
      return const Defer('approval', {'reason': 'high-value'});
    }
    return const Accept();
  });

  // ── 3. Approval layer ────────────────────────────────────────
  final queue = ApprovalQueue<Transaction>(
    journal: journal,
    ttl: const Duration(minutes: 5),
    maxPending: 100,
  );

  final gate = Cell.ingress<Transaction>(context: context);
  final handle = cognitive(
    cell: gate.cell,
    policy: policy,
    verdictPolicy: verdictRule,
    onDeferred: approvalResolver(queue),
  );

  // ── 4. Traffic + outcomes ────────────────────────────────────
  final outcomes = recordOutcomes(handle);
  var accepted = 0;
  var deferred = 0;
  for (var i = 0; i < 30; i++) {
    final risk = i < 20 ? 'marketing' : 'finance';
    final tx = Transaction(amount: 100 + i, customer: 'c-$i', risk: risk);
    await gate.ingest(_pulse(tx, risk, source: gate.cell));
    await Future<void>.delayed(Duration.zero);
    final decision = handle.decisions.lastWhere((d) => d.pulse != null);
    if (decision.verdict is Accept) {
      accepted++;
      // Marketing transactions always fail downstream; finance succeed.
      handle.recordOutcome(
        decisionId: decision.id,
        reward: risk == 'marketing' ? -1.0 : 1.0,
      );
    }
  }

  // One high-value transaction: defer → human approves.
  final high = Transaction(amount: 50000, customer: 'acme', risk: 'finance');
  final highPulse = _pulse(high, 'finance', source: gate.cell);
  await gate.ingest(highPulse);
  await Future<void>.delayed(Duration.zero);
  _check(queue.pending.length == 1, 'high-value transaction deferred');
  deferred++;
  await queue.approve(queue.pending.keys.single);
  await Future<void>.delayed(Duration.zero);
  _check(queue.committed.value?.amount == 50000, 'approval committed');

  // ── 5. Bridge (tool router) ──────────────────────────────────
  final toolSource = Cell.ingress<Pulse>();
  final router = toolRouter(
    source: toolSource.cell,
    tools: {
      'check_fraud': (args) async => {'flagged': false},
      'check_aml': (args) async => {'cleared': true},
    },
    actor: 'system',
    journal: journal,
  );
  final toolResults = <String>[];
  final toolSub = Cell.observe(
      source: router,
      effect: (Pulse p) {
        toolResults.add((p.payload as Pulse).type.toString());
      });
  toolSource.emit(_toolCall('check_fraud', const {}, 0.9));
  await Future<void>.delayed(Duration.zero);
  _check(
    toolResults.contains('mind.tool.result.check_fraud'),
    'tool bridge dispatched',
  );

  // ── 6. Learning + deployment ─────────────────────────────────
  await Future<void>.delayed(Duration.zero);
  final trained = await trainOffline(
    handle: handle,
    outcomes: outcomes.log,
    baseContext: handle.cell.context,
    trainer: contextualBandit(),
    journal: journal,
    config: const TrainingConfig(minSupport: 5),
  );
  _check(trained.resolvedCount > 0, 'outcomes joined decisions');
  _check(
    (trained.policyBlock['rules'] as List).isNotEmpty,
    'learned rules emitted',
  );

  final evolved = trained.applyTo(handle.cell.context);
  final deployedGate = Cell.ingress<Transaction>(context: evolved);
  final deployedHandle = cognitive(
    cell: deployedGate.cell,
    policy: contextAware() + learnedPolicy(),
  );
  final deployedSeen = <Transaction>[];
  final deployedSub = Cell.observe(
      source: deployedHandle.cognitive,
      effect: (Pulse p) {
        deployedSeen.add(p.payload as Transaction);
      });
  final risky = Transaction(amount: 55, customer: 'spam', risk: 'marketing');
  await deployedGate.ingest(_pulse(risky, 'marketing'));
  await Future<void>.delayed(Duration.zero);
  _check(deployedSeen.isEmpty, 'learned policy rejects marketing');

  // ── 7. Multi-agent debate ────────────────────────────────────
  final agents = <AgentRuntime>[];
  for (final name in ['risk', 'compliance', 'supervisor']) {
    agents.add(await spawn(
      AgentSpec(
        name: name,
        cell: deployedGate.cell,
        mandate: DeputyContext(
          baseContext: evolved,
          authority: 'agent-$name',
          role: 'reviewer',
        ),
        routeIn: (p) => deployedGate.ingest(p as Pulse<Transaction>),
      ),
      journal: journal,
    ));
  }
  final question = _pulse(
    Transaction(amount: 75000, customer: 'acme', risk: 'finance'),
    'finance',
  );
  final result = await debate(
    participants: agents,
    question: question,
    journal: journal,
  );
  _check(result.votesByRound['round-1']!.length == 3, 'three votes cast');

  // ── 8. XAI ───────────────────────────────────────────────────
  final path = explainPulse(highPulse, handle);
  if (path == null) {
    throw StateError('narrative missing for the deferred pulse');
  }
  final narrative = path.toNarrative();
  final resolvedVerdict = path.verdict;
  _check(
    resolvedVerdict is Accept &&
        resolvedVerdict.annotations.containsKey('deferredBy'),
    'narrative carries the deferral resolution',
  );
  final sourcePaths = explainSource(gate.cell, handle);
  _check(sourcePaths.isNotEmpty, 'explainSource finds decisions');

  // ── Report ───────────────────────────────────────────────────
  print('=== Acceptance pipeline complete ===');
  print('decisions: ${handle.decisions.length} '
      '(accepted=$accepted, deferred=$deferred)');
  print('trained: ${trained.resolvedCount} resolved, '
      '${trained.ruleCount} rule(s)');
  print('debate: ${result.winner.type} '
      '(consensus=${result.consensusReached}, rounds=${result.rounds})');
  print('narrative: $narrative');
  print('explainSource: ${sourcePaths.length} decision(s)');
  print('=== OK ===');

  // ── Teardown ────────────────────────────────────────────────
  toolSub.stop();
  deployedSub.stop();
  outcomes.stop();
  await queue.dispose();
  for (final agent in agents) {
    agent.dispose();
  }
  handle.dispose();
  deployedHandle.dispose();
}

void _check(bool condition, String message) {
  if (!condition) {
    throw StateError('Acceptance check failed: $message');
  }
}

final class Transaction {
  final int amount;
  final String customer;
  final String risk;
  const Transaction({
    required this.amount,
    required this.customer,
    required this.risk,
  });

  @override
  String toString() => 'Transaction($customer, $amount, $risk)';
}

Pulse<Transaction> _pulse(
  Transaction tx,
  String domains, {
  Cell? source,
}) =>
    Pulse<Transaction>.governed(
      payload: tx,
      source: source,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('gateway'),
        Provenance.reason.entry('purchase'),
        Provenance.confidence.entry(0.95),
        Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        Provenance.traceId.entry(Identity.next()),
        Ontology.domains.entry(domains),
      ]),
    );

Pulse<Map<String, dynamic>> _toolCall(
  String verb,
  Map<String, dynamic> args,
  double confidence,
) =>
    Pulse<Map<String, dynamic>>.governed(
      payload: {'verb': verb, 'args': args},
      context: PulseContext.fromEntries([
        Provenance.actor.entry('system'),
        Provenance.confidence.entry(confidence),
      ]),
    );
