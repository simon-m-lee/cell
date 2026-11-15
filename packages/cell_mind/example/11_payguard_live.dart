// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// ignore_for_file: file_names

// PayGuard — a real-life payment gateway governed by cell_mind.
//
// One executable walks the complete cross-phase surface of the
// package against a LIVE DeepSeek LLM:
//
//   Phase 1  policy      — structural gate (domain, compliance,
//                           confidence) runs before anything else
//   Phase 2  runtime     — every transaction becomes a Decision
//   Phase 3  learning    — outcomes train a bandit policy offline
//   Phase 4  approval    — large amounts Defer into ApprovalQueue
//   Phase 8/9 prompt     — PromptConfig + live adapter, three-tier
//                           cache, dedicated + shared chat sessions
//   Phase 6  xai         — explainPulse narrative for the audit
//   replay               — ReplayJournal re-runs without the LLM
//   conform              — deploy-gate conformance (--conformance)
//
// LLM configuration is read from the DeepSeek settings.json at the
// repository root (`.deepcode/settings.json`), from a local
// `settings.json`, or from DEEPSEEK_API_KEY / DEEPSEEK_BASE_URL /
// DEEPSEEK_MODEL environment variables. Without any configuration the
// example still runs end to end with a rule-based mock adapter, so it
// is safe for CI and offline machines.
//
// Run:  dart run example/11_payguard_live.dart
//       dart run example/11_payguard_live.dart --conformance
//
// Expect a handful of live DeepSeek calls (~15-40 s); every repeat
// decision is a cache hit and costs nothing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell_mind/cell_mind.dart';

// ---------------------------------------------------------------------------
// Output harness
// ---------------------------------------------------------------------------

var _hardFailures = 0;
var _softFailures = 0;

/// Hard checks pin framework guarantees (caching, journaling, replay,
/// defer routing). Soft checks pin LLM behaviour — a live model may
/// legitimately deviate, so they warn instead of failing the run.
void _expect(bool condition, String label, {bool hard = true}) {
  if (condition) {
    print('  ✓ $label');
    return;
  }
  if (hard) {
    _hardFailures++;
    print('  ✗ $label  [HARD]');
  } else {
    _softFailures++;
    print('  ⚠ $label  [soft — model deviated]');
  }
}

void _section(String title) {
  print('');
  print('── $title');
}

// ---------------------------------------------------------------------------
// DeepSeek settings (settings.json at the repository root)
// ---------------------------------------------------------------------------

class _DeepSeekSettings {
  const _DeepSeekSettings({
    required this.model,
    required this.baseUrl,
    required this.apiKey,
  });

  final String model;
  final String baseUrl;
  final String apiKey;
}

/// Resolves the DeepSeek configuration. Looks for:
///   1. `settings.json` next to the working directory,
///   2. `.deepcode/settings.json` (the repository-root settings),
///   3. `DEEPSEEK_*` environment variables.
/// Returns null when nothing is configured (mock mode).
_DeepSeekSettings? _loadSettings() {
  const candidates = [
    'settings.json',
    '.deepcode/settings.json',
    '../settings.json',
    '../.deepcode/settings.json',
    '../../settings.json',
    '../../.deepcode/settings.json',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) continue;
      final env = json['env'] is Map ? json['env'] as Map : json;
      final model = (env['MODEL'] ?? env['model']) as String?;
      final baseUrl = (env['BASE_URL'] ?? env['baseUrl']) as String?;
      final apiKey = (env['API_KEY'] ?? env['apiKey']) as String?;
      if (model == null || apiKey == null || apiKey.isEmpty) continue;
      print('DeepSeek settings: $path');
      return _DeepSeekSettings(
        model: model,
        baseUrl: baseUrl ?? 'https://api.deepseek.com',
        apiKey: apiKey,
      );
    } catch (_) {
      // Unreadable settings file — try the next candidate.
    }
  }
  final envKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) {
    return _DeepSeekSettings(
      model: Platform.environment['DEEPSEEK_MODEL'] ?? 'deepseek-chat',
      baseUrl: Platform.environment['DEEPSEEK_BASE_URL'] ??
          'https://api.deepseek.com',
      apiKey: envKey,
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// The live LLM adapter (PromptFunction) + deterministic mock fallback
// ---------------------------------------------------------------------------

class _Adapter {
  _Adapter(this.settings, this.systemPrompt)
      : live = settings != null,
        _client = settings == null
            ? null
            : (HttpClient()..connectionTimeout = const Duration(seconds: 20));

  final _DeepSeekSettings? settings;
  final String systemPrompt;
  final bool live;
  final HttpClient? _client;

  int calls = 0;
  int failures = 0;
  String lastPrompt = '';

  Future<String> call(String fullPrompt) async {
    calls++;
    lastPrompt = fullPrompt;
    if (!live) return _mockVerdict(fullPrompt);
    final result = await _completeLive(fullPrompt);
    if (result == null) {
      failures++;
      throw StateError('DeepSeek completion failed; see stderr above');
    }
    return result;
  }

  Future<String?> _completeLive(String fullPrompt) async {
    final settings = this.settings!;
    // The rendered prompt starts with the system prompt; split it so the
    // model receives a real system/user message pair.
    final (system, user) = fullPrompt.startsWith(systemPrompt)
        ? (systemPrompt, fullPrompt.substring(systemPrompt.length).trim())
        : ('You are a helpful assistant.', fullPrompt);
    try {
      final request = await _client!.postUrl(
        Uri.parse('${settings.baseUrl}/chat/completions'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${settings.apiKey}',
      );
      request.add(
        utf8.encode(
          jsonEncode({
            'model': settings.model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0,
            'stream': false,
            'response_format': {'type': 'json_object'},
          }),
        ),
      );
      final response = await request.close().timeout(
            const Duration(seconds: 90),
          );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        stderr.writeln('DeepSeek HTTP ${response.statusCode}: $body');
        return null;
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        stderr.writeln('DeepSeek returned no choices: $body');
        return null;
      }
      final message =
          (choices.first as Map<String, dynamic>)['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        stderr.writeln('DeepSeek returned an empty message: $body');
        return null;
      }
      return content;
    } catch (e, st) {
      stderr.writeln('DeepSeek call failed: $e\n$st');
      return null;
    }
  }

  /// Deterministic stand-in for the live model. Implements the same
  /// rules the system prompt asks the LLM to follow, so every section
  /// of this example is exercisable offline.
  String _mockVerdict(String prompt) {
    // History turns precede the current request in a session-aware
    // prompt, so the CURRENT decision is always the LAST occurrence.
    final merchantMatches =
        RegExp(r'"merchant":\s*"([^"]*)"').allMatches(prompt);
    final merchant = merchantMatches.isEmpty ? null : merchantMatches.last;
    final amounts = RegExp(r'"amount":\s*(\d+)').allMatches(prompt);
    final amount = amounts.isEmpty ? 0 : int.parse(amounts.last.group(1)!);
    if (merchant != null && merchant.group(1) == 'suspicious-crypto') {
      return '{"verdict":"reject","reason":"suspicious merchant"}';
    }
    if (amount >= 5000) {
      return '{"verdict":"defer","resolver":"approval",'
          '"reason":"large amount"}';
    }
    if (prompt.contains('approveRefund')) {
      return '{"verdict":"accept","reason":"command within policy"}';
    }
    return '{"verdict":"accept","reason":"within risk appetite",'
        '"confidence":0.97}';
  }
}

// ---------------------------------------------------------------------------
// Domain fixtures
// ---------------------------------------------------------------------------

const _systemPrompt = '''
You are PayGuard, the risk reviewer of a payment gateway. You receive a
transaction (or a command with its arguments) and must answer with ONE
JSON object matching the schema, nothing else.

RULES, in order:
1. If the decision mentions merchant "suspicious-crypto": verdict
   "reject", reason "suspicious merchant".
2. If the decision mentions amount >= 5000: verdict "defer", resolver
   EXACTLY "approval", reason "large amount".
3. If the decision is a command/function (approveRefund etc.): verdict
   "accept", reason "command within policy".
4. Otherwise: verdict "accept", reason "within risk appetite",
   confidence between 0.9 and 1.0.
''';

final _paymentsContext = Context(
  domains: 'payments',
  compliances: 'PCI-DSS',
  constraints: {'max_amount': 5000},
  version: '1.0.0',
);

PromptConfig _riskConfig(
        {required String id, SessionMode mode = SessionMode.stateless}) =>
    PromptConfig.custom(
      id: id,
      version: '1.0.0',
      description: 'PayGuard live risk review',
      systemPrompt: _systemPrompt,
      userTemplate: '{{context}}\n\n{{decision}}',
      cacheTtl: const Duration(hours: 1),
      verdictCacheTtl: const Duration(hours: 1),
      sessionMode: mode,
    );

Pulse<Map<String, dynamic>> _txPulse(
  String id,
  int amount,
  String merchant, {
  double confidence = 0.95,
}) =>
    Pulse<Map<String, dynamic>>.governed(
      payload: {'id': id, 'amount': amount, 'merchant': merchant},
      type: 'payment.transaction',
      context: PulseContext.fromEntries([
        Ontology.domains.entry('payments'),
        Provenance.compliance.entry('PCI-DSS'),
        Provenance.actor.entry('customer-app'),
        Provenance.purpose.entry('purchase'),
        Provenance.confidence.entry(confidence),
        Provenance.traceId.entry(id),
      ]),
    );

/// An [ApplyCommand] over [fn] with positional [args].
ApplyCommand _commandFor(Function fn, [List<Object?>? args]) => (
      function: fn,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    );

void _approveRefund(int amount) {}

Future<void> _settle([Duration delay = const Duration(milliseconds: 25)]) =>
    Future<void>.delayed(delay);

/// A prompted verdict completes asynchronously (live LLM = network
/// latency). Poll the decision log until [handle] records at least
/// [minCount] decisions or the timeout expires.
Future<List<Decision>> _awaitDecisions(
  CognitiveHandle handle,
  int minCount,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 95));
  while (handle.decisions.toList().length < minCount &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  return handle.decisions.toList();
}

// ---------------------------------------------------------------------------
// The scenario
// ---------------------------------------------------------------------------

Future<void> main(List<String> arguments) async {
  final runConformance = arguments.contains('--conformance');
  print('=== PayGuard — a live cell_mind payment gateway ===');

  final settings = _loadSettings();
  if (settings == null) {
    print('No DeepSeek settings.json or DEEPSEEK_API_KEY found — '
        'running with the deterministic mock adapter.');
    print('(Point settings.json at the repo root to query DeepSeek live.)');
  } else {
    print('Model: ${settings.model}   Base URL: ${settings.baseUrl}');
  }
  final adapter = _Adapter(settings, _systemPrompt);
  final journal = RecordingJournal();

  // ── 1. The structural gate (Phase 1) ──────────────────────────────
  _section('1. Structural gate — Phase 1 policy');
  final gate = Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
  final queue = ApprovalQueue<Map<String, dynamic>>(journal: journal);
  final riskConfig =
      _riskConfig(id: 'payguard-risk-review', mode: SessionMode.dedicated);
  final riskPolicy = promptedPolicyWith(
    config: riskConfig,
    prompt: adapter.call,
    journal: journal,
  );
  final handle = cognitive(
    cell: gate.cell,
    policy: contextAware(requireCompliance: true) + confidencePolicy(min: 0.7),
    verdictPolicy: riskPolicy,
    onDeferred: approvalResolver(queue),
  );
  final outcomes = recordOutcomes(handle);
  _expect(riskPolicy.session != null, 'dedicated session auto-created');

  Future<Decision> ingestTx(String id, int amount, String merchant) async {
    final pulse = _txPulse(id, amount, merchant);
    final before = handle.decisions.toList().length;
    await gate.ingest(pulse);
    final decisions = await _awaitDecisions(handle, before + 1);
    return decisions.last;
  }

  // ── 2. First transaction — live LLM verdict (Phase 8) ─────────────
  _section('2. TX-1001 coffee — live verdict, then cached repeats');
  final tx1 = await ingestTx('TX-1001', 125, 'blue-bottle-coffee');
  _expect(adapter.calls == 1, 'the DeepSeek adapter was called exactly once');
  _expect(tx1.verdict is Accept, 'model accepted the low-risk purchase',
      hard: !adapter.live || adapter.failures == 0);
  _expect(riskPolicy.session!.length == 2,
      'the successful decision appended one (user, assistant) turn');

  // Repeat: verdict cache hit — no render, no LLM, no new turn.
  final callsBeforeRepeat = adapter.calls;
  final tx1Repeat = await ingestTx('TX-1001', 125, 'blue-bottle-coffee');
  _expect(adapter.calls == callsBeforeRepeat,
      'repeat decision was a verdict-cache hit (zero LLM calls)');
  _expect(
    jsonEncode(tx1Repeat.verdict.toMap()) == jsonEncode(tx1.verdict.toMap()),
    'repeat served the cached verdict',
  );
  _expect(riskPolicy.session!.length == 2,
      'a cache hit does NOT append a conversation turn (D14)');

  // Second tier: a fresh policy instance (fresh verdict cache) over the
  // same config — the rendered prompt is identical, so the prompt cache
  // serves it without an LLM call.
  final secondGate =
      Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
  final secondHandle = cognitive(
    cell: secondGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config:
          _riskConfig(id: 'payguard-risk-review', mode: SessionMode.dedicated),
      prompt: adapter.call,
      journal: RecordingJournal(),
    ),
  );
  final callsBeforePromptHit = adapter.calls;
  final secondPulse = _txPulse('TX-1001', 125, 'blue-bottle-coffee');
  await secondGate.ingest(secondPulse);
  final secondDecisions = await _awaitDecisions(secondHandle, 1);
  _expect(adapter.calls == callsBeforePromptHit,
      'fresh verdict cache + warm prompt cache = prompt-cache hit (no LLM)');
  _expect(
    secondDecisions.single.verdict is Accept,
    'the prompt-cache hit produced a decision',
    hard: !adapter.live || adapter.failures == 0,
  );

  // ── 3. Large amount — Defer → human approval (Phase 4) ────────────
  _section('3. TX-1002 luxury watch — Defer → ApprovalQueue');
  final tx2 = await ingestTx('TX-1002', 9500, 'luxury-watch');
  _expect(tx2.verdict is Defer, 'model deferred the large amount',
      hard: !adapter.live || adapter.failures == 0);
  _expect(queue.pending.length == 1, 'the approval queue received the request');
  final requestId = queue.pending.keys.single;
  final decisionsBeforeApprove = handle.decisions.toList().length;
  await queue.approve(requestId);
  await _awaitDecisions(handle, decisionsBeforeApprove + 1);
  _expect(queue.committed.value?['id'] == 'TX-1002',
      'the approved value flows through queue.committed');
  _expect(handle.decisions.toList().last.verdict is Accept,
      'approval committed a follow-up Accept decision');
  _expect(
    handle.decisions
            .toList()
            .where((d) => d.pulse?.payload?['id'] == 'TX-1002')
            .length ==
        2,
    'the audit shows the request + resolution pair',
  );

  // ── 4. Suspicious merchant — model rejection ──────────────────────
  _section('4. TX-1003 suspicious crypto — model rejection');
  final tx3 = await ingestTx('TX-1003', 300, 'suspicious-crypto');
  _expect(tx3.verdict is Reject, 'model rejected the suspicious merchant',
      hard: !adapter.live || adapter.failures == 0);

  // ── 5. Session history is visible to the model (Phase 8.1) ────────
  _section('5. TX-1004 book store — the conversation follows the money');
  await ingestTx('TX-1004', 42, 'book-store');
  _expect(riskPolicy.session!.length == 8,
      'four gateway decisions accumulated eight messages');
  _expect(adapter.lastPrompt.contains('## Conversation History'),
      'the live prompt carried the conversation history');
  _expect(adapter.lastPrompt.contains('## Current Request'),
      'the current request is separated from the history');

  // ── 6. Command decision — the LLM sees the command AND its args ───
  _section('6. Refund command — command decision with arguments');
  final decisionsBeforeCommand = handle.decisions.toList().length;
  await handle.cognitive.apply<Object?>(
    _commandFor(_approveRefund, [300]),
  );
  await _awaitDecisions(handle, decisionsBeforeCommand + 1);
  _expect(handle.decisions.toList().last.command != null,
      'the command decision was recorded');

  // ── 7. Two reviewers share one conversation (Phase 8.1 shared) ────
  _section('7. Shared session — two prompted reviewers, one window');
  final window = PromptSession(id: 'reviewers');
  final sharedConfig =
      _riskConfig(id: 'payguard-shared-review', mode: SessionMode.shared);
  Future<Decision> reviewOnce(
    String reviewer,
    String txId,
    int amount,
    String merchant,
  ) async {
    final reviewerGate =
        Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
    final reviewerPolicy = promptedPolicyWith(
      config: sharedConfig,
      prompt: adapter.call,
      journal: RecordingJournal(),
      session: window,
    );
    final reviewerHandle = cognitive(
      cell: reviewerGate.cell,
      policy: contextAware(requireCompliance: true),
      verdictPolicy: reviewerPolicy,
    );
    await reviewerGate.ingest(_txPulse(txId, amount, merchant));
    final reviewerDecisions = await _awaitDecisions(reviewerHandle, 1);
    print('  reviewer $reviewer: ${reviewerDecisions.last.verdict}');
    return reviewerDecisions.last;
  }

  final callsBeforeAgents = adapter.calls;
  final agentA = await reviewOnce('A', 'TX-1005', 4999, 'stationery-co');
  final agentB = await reviewOnce('B', 'TX-1005', 4999, 'stationery-co');
  _expect(adapter.calls == callsBeforeAgents + 2,
      'both reviewers called the LLM (different history each time)');
  _expect(
      window.length == 4, 'the shared window accumulated both agents\' turns');
  _expect(
      window.messages[1].role == ChatRole.assistant &&
          window.messages[3].role == ChatRole.assistant,
      'both verdicts are assistant turns in the shared window');
  _expect(agentA.verdict is Accept && agentB.verdict is Accept,
      'both reviewers accepted the compliant transaction',
      hard: !adapter.live || adapter.failures == 0);

  // ── 8. Outcomes → offline learning (Phase 3) ──────────────────────
  _section('8. Outcomes feed the offline bandit (Phase 3 learning)');
  for (final decision in handle.decisions.toList()) {
    final reward = switch (decision.verdict) {
      Accept() => 1.0,
      Reject() => -1.0,
      Defer() => 0.5,
    };
    handle.recordOutcome(decisionId: decision.id, reward: reward);
  }
  final outcomeDeadline = DateTime.now().add(const Duration(seconds: 10));
  while (outcomes.log.length < handle.decisions.toList().length &&
      DateTime.now().isBefore(outcomeDeadline)) {
    await _settle();
  }
  _expect(outcomes.log.length >= 6, 'outcomes were recorded per decision');
  final trained = await trainOffline(
    handle: handle,
    outcomes: outcomes.log,
    baseContext: _paymentsContext,
    trainer: contextualBandit(),
    journal: journal,
    config: const TrainingConfig(
      minSupport: 1,
      minConfidence: 0.5,
      maxRules: 20,
    ),
  );
  _expect(trained.decisionCount == handle.decisions.toList().length,
      'the trainer consumed the whole decision log');
  final rules = (trained.policyBlock['rules'] as List?) ?? const [];
  print('  learned ${rules.length} rule(s): '
      '${jsonEncode(trained.policyBlock)}');
  _expect(rules.isNotEmpty, 'the bandit emitted at least one learned rule');

  // ── 9. XAI — the audit narrative (Phase 6) ────────────────────────
  _section('9. XAI — explain the deferred transaction');
  final deferDecision = handle.decisions.toList().firstWhere((d) =>
      d.pulse != null &&
      d.pulse!.payload?['id'] == 'TX-1002' &&
      d.verdict is Defer);
  final path = explain(deferDecision);
  final narrative = path.toNarrative(template: NarrativeTemplate.ui);
  print('  narrative: $narrative');
  _expect(narrative.contains('defer'), 'the narrative names the deferral');
  final followUp = explainPulse(deferDecision.pulse!, handle);
  _expect(followUp != null && followUp.verdict is Accept,
      'explainPulse surfaces the follow-up resolution (newest first)');

  // ── 10. Replay — the journal replays without the LLM (Phase 8) ────
  _section('10. Replay — recorded governance re-runs without DeepSeek');
  final replayRecording = RecordingJournal();
  final replayConfig =
      _riskConfig(id: 'payguard-replay', mode: SessionMode.dedicated);
  final replayGate =
      Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
  final replayHandle = cognitive(
    cell: replayGate.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: replayConfig,
      prompt: adapter.call,
      journal: replayRecording,
    ),
  );
  final callsBeforeReplayRecording = adapter.calls;
  await replayGate.ingest(_txPulse('TX-9001', 125, 'replay-cafe'));
  await _awaitDecisions(replayHandle, 1);
  _expect(adapter.calls == callsBeforeReplayRecording + 1,
      'recording the replay scenario called the LLM once');

  final replayJournal = ReplayJournal(
    replayRecording.toJson().map(EffectRecord.fromJson).toList(growable: false),
  );
  final replayGate2 =
      Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
  final replayHandle2 = cognitive(
    cell: replayGate2.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: replayConfig,
      prompt: adapter.call, // would return a different verdict — never runs
      journal: replayJournal,
    ),
  );
  final callsBeforeReplay = adapter.calls;
  await replayGate2.ingest(_txPulse('TX-9001', 125, 'replay-cafe'));
  final replayDecisions = await _awaitDecisions(replayHandle2, 1);
  _expect(adapter.calls == callsBeforeReplay,
      'replay never re-invoked the DeepSeek adapter');
  _expect(
    jsonEncode(replayDecisions.single.verdict.toMap()) ==
        jsonEncode(replayHandle.decisions.toList().single.verdict.toMap()),
    'replay reproduced the recorded verdict',
  );
  replayJournal.assertExhausted();
  _expect(true, 'replay journal exhausted cleanly');

  // ── 11. Conformance — the deploy gate (optional) ──────────────────
  if (runConformance) {
    _section('11. Conformance — deploy gate against the live model');
    final report = await conform(
      config: _riskConfig(id: 'payguard-conformance'),
      prompt: adapter.call,
      cases: [
        ConformanceCase(
          context: _paymentsContext,
          decision: _txPulse('TX-8001', 9999, 'conformance-check'),
          expected: const Defer('approval'),
        ),
      ],
    );
    print('  conformance: ${report.passedAll ? "PASS" : "FAIL"} '
        '(${report.passed}/${report.total}, '
        '${(report.passRate * 100).toStringAsFixed(0)}%)');
  }

  // ── Summary ────────────────────────────────────────────────────────
  _section('Summary');
  final decisions = handle.decisions.toList();
  final byVerdict = <String, int>{};
  for (final decision in decisions) {
    final kind = switch (decision.verdict) {
      Accept() => 'accept',
      Reject() => 'reject',
      Defer() => 'defer',
    };
    byVerdict[kind] = (byVerdict[kind] ?? 0) + 1;
  }
  print('  gateway decisions: ${decisions.length}  $byVerdict');
  print('  DeepSeek calls: ${adapter.calls}'
      '${adapter.failures > 0 ? " (${adapter.failures} failed)" : ""}');
  print('  journal records: ${journal.toJson().length}');
  print('  session turns: ${riskPolicy.session?.length}');

  if (_hardFailures > 0 || _softFailures > 0) {
    print('');
    print('  hard failures: $_hardFailures   soft warnings: $_softFailures');
    if (_hardFailures > 0) {
      throw StateError('PayGuard example FAILED ($_hardFailures hard '
          'checks). See the output above.');
    }
  }
  print('');
  print('=== PayGuard example complete: all hard checks passed ===');
}
