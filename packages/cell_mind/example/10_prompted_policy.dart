// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// ignore_for_file: file_names

// Phase 8 acceptance example: the prompted policy layer end to end.
//
// Walks the complete surface — inline mode, config mode, registry A/B,
// conformance, replay, the structural-first trust boundary, and Defer
// routing into the Phase 4 approval queue. The "LLM" is a mock that
// implements a real rule: reject amounts above the Context's
// max_amount constraint.
//
// Run: dart run example/10_prompted_policy.dart

import 'dart:async';
import 'dart:convert';

import 'package:cell_mind/cell_mind.dart';

void _check(bool condition, String label) {
  if (!condition) {
    throw StateError('FAILED: $label');
  }
  print('  ✓ $label');
}

String _mockLlm(String prompt) {
  // A real policy: parse the rendered context's constraints, compare
  // the LIVE decision payload (the last amount in the prompt — the
  // few-shot examples appear before the real decision), answer as the
  // policyDecider schema demands.
  final constraintsMatches =
      RegExp(r'constraints: (\{.*\})').allMatches(prompt).toList();
  final amountMatches = RegExp(r'"amount":(\d+)').allMatches(prompt).toList();
  final max = constraintsMatches.isEmpty
      ? null
      : (jsonDecode(constraintsMatches.last.group(1)!) as Map)['max_amount'];
  final amount =
      amountMatches.isEmpty ? 0 : int.parse(amountMatches.last.group(1)!);
  if (max is! int) {
    return '{"verdict":"accept","reason":"no constraints declared"}';
  }
  if (amount > max) {
    return '{"verdict":"reject","reason":"amount exceeds max_amount"}';
  }
  if (amount > max * 8 ~/ 10) {
    return '{"verdict":"defer","resolver":"approval",'
        '"reason":"near the limit"}';
  }
  return '{"verdict":"accept","reason":"within limits","confidence":0.97}';
}

Pulse<Map<String, int>> amountPulse(
  int amount, {
  String? traceId,
  double? confidence,
  String? domains,
}) =>
    Pulse<Map<String, int>>.governed(
      payload: {'amount': amount},
      context: PulseContext.fromEntries([
        Provenance.actor.entry('system'),
        Provenance.confidence
            .entry(confidence ?? (amount > 8000 ? 0.55 : 0.95)),
        if (domains != null) Ontology.domains.entry(domains),
        if (traceId != null) Provenance.traceId.entry(traceId),
      ]),
    );

Future<void> main() async {
  print('=== Phase 8 — prompted policy ===\n');

  // ── 1. The rendered prompt (universal format) ─────────────────────
  final config = PromptConfig.policyDecider();
  config.validate();
  final context = Context(
    domains: 'finance,audit',
    compliances: 'GDPR',
    constraints: {'max_amount': 10000},
    partOf: 'ledger_service',
  );
  final rendered = config.render(
    context: context,
    decision: Pulse<Map<String, int>>.governed(
      payload: {'amount': 25000},
      context: PulseContext.fromEntries([
        Provenance.actor.entry('system'),
        Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        Provenance.confidence.entry(0.95),
        Provenance.purpose.entry('TRANSACTION'),
      ]),
    ),
  );
  _check(rendered.contains('## Context'), 'prompt has a Context section');
  _check(rendered.contains('## Decision'), 'prompt has a Decision section');
  _check(rendered.contains('## Expected Output'),
      'prompt carries the JSON schema');
  _check(rendered.contains('"max_amount":10000'),
      'constraints render as sorted JSON');

  // ── 2. Config mode: policyDecider + structural gate ───────────────
  var calls = 0;
  Future<String> llm(String prompt) async {
    calls++;
    return _mockLlm(prompt);
  }

  final gate = Cell.ingress<Map<String, int>>(context: context);
  final handle = cognitive(
    cell: gate.cell,
    policy: contextAware(
      allowMissingConfidence: true,
      requireDomain: false,
    ),
    verdictPolicy: promptedPolicyWith(
      config: config,
      prompt: llm,
      journal: RecordingJournal(),
    ),
  );
  await gate.ingest(
    amountPulse(25000, traceId: 'tx-1', confidence: 0.95, domains: 'finance'),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(
    handle.decisions
        .where((d) => d.pulse != null)
        .every((d) => d.verdict is Reject),
    'LLM rejects the over-limit transaction',
  );
  _check(calls >= 1, 'the adapter was invoked');

  // ── 3. Structural-first: the LLM is skipped on structural reject ──
  final callsBefore = calls;
  final strictGate = Cell.ingress<Map<String, int>>(context: context);
  final strictHandle = cognitive(
    cell: strictGate.cell,
    policy: predicatePolicy((object, {required host}) => false),
    verdictPolicy: promptedPolicyWith(
      config: config,
      prompt: llm,
      journal: RecordingJournal(),
    ),
  );
  await strictHandle.cognitive.apply<Object?>(
    (
      function: () => 1,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ),
  );
  _check(calls == callsBefore, 'structural rejections never reach the LLM');

  // ── 4. Inline mode: one-off prompt ────────────────────────────────
  final inlineCalls = calls;
  final inlineGate = Cell.ingress<Map<String, int>>(context: context);
  final inlineHandle = cognitive(
    cell: inlineGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicy(
      prompt: llm,
      journal: RecordingJournal(),
    ),
  );
  await inlineGate.ingest(amountPulse(5000, traceId: 'tx-2'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(
    inlineHandle.decisions
        .where((d) => d.pulse != null)
        .any((d) => d.verdict is Accept),
    'inline mode accepts a within-limits decision',
  );
  _check(calls > inlineCalls, 'inline mode called the adapter');

  // ── 5. Registry: A/B versions and rollback pinning ────────────────
  PromptConfigRegistry.register(PromptConfig.policyDecider());
  PromptConfigRegistry.register(
    PromptConfig.custom(
      id: 'policy-decider',
      version: '1.1.0',
      description: 'stricter candidate',
      systemPrompt:
          'Reject anything above 90% of the stated limit.\n$defaultSystemPrompt',
      userTemplate: '{{context}}\n\n{{decision}}',
    ),
  );
  _check(
    PromptConfigRegistry.lookup('policy-decider')!.version == '1.1.0',
    'registry resolves the highest version',
  );
  _check(
    PromptConfigRegistry.lookup('policy-decider', version: '1.0.0')!.version ==
        '1.0.0',
    'registry supports rollback pinning',
  );
  PromptConfigRegistry.unregister('policy-decider');

  // ── 6. Conformance: verify the config against the mock LLM ────────
  final report = await conform(
    config: config,
    prompt: llm,
    cases: [
      ConformanceCase(
        context: context,
        decision: amountPulse(5000),
        expected: const Accept(),
      ),
      ConformanceCase(
        context: context,
        decision: amountPulse(25000),
        expected: const Reject('amount exceeds max_amount'),
      ),
      ConformanceCase(
        context: context,
        decision: amountPulse(9000),
        expected: const Defer('approval'),
      ),
    ],
  );
  _check(report.total == 3, 'conformance ran all three cases');
  _check(report.passed == 3, 'conformance passed all three cases');
  _check(report.passedAll, 'conformance report is green');
  _check(report.passRate == 1.0, 'pass rate is 1.0');

  // ── 7. Replay: the journal serves recorded responses ──────────────
  final recording = RecordingJournal();
  final replayGate = Cell.ingress<Map<String, int>>(context: context);
  final replayHandle = cognitive(
    cell: replayGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: config,
      prompt: llm,
      journal: recording,
    ),
  );
  await replayGate.ingest(amountPulse(25000, traceId: 'replay-trace'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(
    replayHandle.decisions
        .where((d) => d.pulse != null)
        .every((d) => d.verdict is Reject),
    'recording captured the reject',
  );
  final callsBeforeReplay = calls;

  final replay = ReplayJournal(
    recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
  );
  final replayGate2 = Cell.ingress<Map<String, int>>(context: context);
  final replayHandle2 = cognitive(
    cell: replayGate2.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: config,
      prompt: llm,
      journal: replay,
    ),
  );
  await replayGate2.ingest(amountPulse(25000, traceId: 'replay-trace'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  replay.assertExhausted();
  _check(calls == callsBeforeReplay, 'replay never re-invokes the LLM');
  _check(
    replayHandle2.decisions
        .where((d) => d.pulse != null)
        .every((d) => d.verdict is Reject),
    'replay reproduces the recorded reject',
  );

  // ── 8. Defer → Phase 4 approval ───────────────────────────────────
  final queue = ApprovalQueue<Map<String, int>>(journal: RecordingJournal());
  final deferGate = Cell.ingress<Map<String, int>>(context: context);
  final deferHandle = cognitive(
    cell: deferGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: config,
      prompt: llm,
      journal: RecordingJournal(),
    ),
    onDeferred: approvalResolver(queue),
  );
  await deferGate.ingest(amountPulse(9000, traceId: 'defer-trace'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(
    deferHandle.decisions.any((d) => d.verdict is Defer),
    'near-limit decision defers to approval',
  );
  _check(queue.pending.length == 1, 'the approval queue received it');
  final requestId = queue.pending.keys.single;
  await queue.approve(requestId);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(
    deferHandle.decisions.last.verdict is Accept,
    'approval commits a follow-up Accept',
  );
  await queue.dispose();

  // ── 10. Dedicated session: conversation history in the prompt ─────
  final sessionPrompts = <String>[];
  Future<String> sessionLlm(String prompt) async {
    sessionPrompts.add(prompt);
    return _mockLlm(prompt);
  }

  final sessionConfig = PromptConfig.custom(
    id: 'session-demo',
    version: '1.0.0',
    description: 'multi-turn fraud review',
    systemPrompt: 'SYSTEM-RULES',
    userTemplate: '{{context}}\n\n{{decision}}',
    sessionMode: SessionMode.dedicated,
    maxSessionMessages: 40,
    maxSessionChars: 20000,
  );
  final sessionGate = Cell.ingress<Map<String, int>>(context: context);
  final sessionPolicy = promptedPolicyWith(
    config: sessionConfig,
    prompt: sessionLlm,
    journal: RecordingJournal(),
  );
  final sessionHandle = cognitive(
    cell: sessionGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: sessionPolicy,
  );
  _check(sessionPolicy.session != null,
      'dedicated mode exposes the auto-created session');
  _check(
    sessionHandle.decisions.isEmpty,
    'the session starts with an empty decision log',
  );
  await sessionGate.ingest(amountPulse(5000, traceId: 's1'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sessionGate.ingest(amountPulse(25000, traceId: 's2'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sessionGate.ingest(amountPulse(9000, traceId: 's3'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(sessionPolicy.session!.length == 6,
      'three decisions accumulate six messages');
  final lastPrompt = sessionPrompts.last;
  _check(lastPrompt.contains('## Conversation History'),
      'the LLM sees prior turns');
  _check(lastPrompt.contains('## Current Request'),
      'the current request is separated');
  _check(
    lastPrompt.contains('"amount":25000'),
    'history includes the rejected transaction',
  );

  // ── 11. Verdict cache: repeats serve without the LLM ──────────────
  var cacheCalls = 0;
  final cacheGate = Cell.ingress<Map<String, int>>(context: context);
  final cachePolicy = promptedPolicyWith(
    config: PromptConfig.custom(
      id: 'cache-demo',
      version: '1.0.0',
      description: 'cached reviews',
      systemPrompt: 'CACHE-RULES',
      userTemplate: '{{context}}\n\n{{decision}}',
    ),
    prompt: (_) async {
      cacheCalls++;
      return '{"verdict":"accept","reason":"within limits"}';
    },
    journal: RecordingJournal(),
  );
  final cacheHandle = cognitive(
    cell: cacheGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: cachePolicy,
  );
  await cacheGate.ingest(amountPulse(5000, traceId: 'c1'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  final callsAfterFirst = cacheCalls;
  await cacheGate.ingest(amountPulse(5000, traceId: 'c1'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(cacheCalls == callsAfterFirst,
      'the identical repeat is a verdict cache hit');
  _check(
    cacheHandle.decisions.where((d) => d.pulse != null).length >= 2,
    'both decisions were recorded',
  );

  // ── 12. Shared session across two policies ────────────────────────
  final shared = PromptSession(id: 'multi-agent');
  PromptConfig sharedConfig() => PromptConfig.custom(
        id: 'shared-demo',
        version: '1.0.0',
        description: 'shared window',
        systemPrompt: 'SHARED-RULES',
        userTemplate: '{{context}}\n\n{{decision}}',
        sessionMode: SessionMode.shared,
      );
  final agentA = promptedPolicyWith(
    config: sharedConfig(),
    prompt: (_) async => '{"verdict":"accept","reason":"within limits"}',
    journal: RecordingJournal(),
    session: shared,
  );
  final agentB = promptedPolicyWith(
    config: sharedConfig(),
    prompt: (_) async => '{"verdict":"reject","reason":"policy violation"}',
    journal: RecordingJournal(),
    session: shared,
  );
  final agentAGate = Cell.ingress<Map<String, int>>(context: context);
  final agentAHandle = cognitive(
    cell: agentAGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: agentA,
  );
  await agentAGate.ingest(amountPulse(5000, traceId: 'sh1'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  final agentBGate = Cell.ingress<Map<String, int>>(context: context);
  final agentBHandle = cognitive(
    cell: agentBGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: agentB,
  );
  await agentBGate.ingest(amountPulse(5000, traceId: 'sh2'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  _check(shared.length == 4, 'two policies accumulate into the shared window');
  _check(
      shared.messages[1].content ==
          '{"verdict":"accept","reason":"within limits"}',
      'agent A turn recorded');
  _check(
      shared.messages[3].content ==
          '{"verdict":"reject","reason":"policy violation"}',
      'agent B turn recorded');
  _check(
    agentAHandle.decisions
        .where((d) => d.pulse != null)
        .every((d) => d.verdict is Accept),
    'agent A accepted',
  );
  _check(
    agentBHandle.decisions
        .where((d) => d.pulse != null)
        .every((d) => d.verdict is Reject),
    'agent B rejected',
  );

  // ── 9. Classifier + extractor presets ─────────────────────────────
  final classifierHandle = cognitive(
    cell: Cell.ingress<int>().cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: PromptConfig.classifier(labels: ['fraud', 'clean']),
      prompt: (_) async => '{"label":"fraud","confidence":0.99}',
      journal: RecordingJournal(),
      labelToVerdict: (label) =>
          label == 'fraud' ? const Reject('fraudulent') : const Accept(),
    ),
  );
  await classifierHandle.cognitive.apply<Object?>(
    (
      function: () => 1,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ),
  );
  _check(
    (classifierHandle.decisions.single.verdict as Reject).reason ==
        'fraudulent',
    'classifier label maps to a verdict',
  );

  final extractorHandle = cognitive(
    cell: Cell.ingress<int>().cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: PromptConfig.extractor(fields: ['amount']),
      prompt: (_) async => '{"fields":{"amount":"25000"}}',
      journal: RecordingJournal(),
      extractionToVerdict: (fields) =>
          int.parse(fields['amount'] as String) > 10000
              ? const Reject('extracted amount too large')
              : const Accept(),
    ),
  );
  await extractorHandle.cognitive.apply<Object?>(
    (
      function: () => 1,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ),
  );
  _check(
    (extractorHandle.decisions.single.verdict as Reject).reason ==
        'extracted amount too large',
    'extractor fields map to a verdict',
  );

  print('\n=== Phase 8 example complete: all checks passed ===');
}
