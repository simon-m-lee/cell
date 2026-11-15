// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// Benchmark: prompted policy cost — rendering, parsing, cache hits,
/// cache misses, and the full cognitive decision round-trip.
///
/// Run with:
/// ```bash
/// dart run benchmark/micro/prompted_policy_cost.dart
/// ```
Future<void> main() async {
  print('Prompted policy cost:');
  print('');

  final config = PromptConfig.policyDecider();
  final context = Context(
    domains: 'finance',
    constraints: {'max_amount': 10000},
    compliances: 'GDPR',
  );
  Pulse<int> decision() => Pulse<int>.governed(
        payload: 5000,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('bench'),
          Provenance.confidence.entry(0.95),
        ]),
      );

  // 1. Rendering.
  const n = 5000;
  var stopwatch = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    config.render(context: context, decision: decision());
  }
  stopwatch.stop();
  print('  render: '
      '${(n * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'renders/s');

  // 2. Parsing.
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    parseVerdict('{"verdict":"reject","reason":"over limit",'
        '"confidence":0.9}');
  }
  stopwatch.stop();
  print('  parse: '
      '${(n * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'parses/s');

  // 3. Cache miss: one journaled LLM call per decision (adapter is a
  //    microtask — the cost measured is the pipeline around it).
  const misses = 500;
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < misses; i++) {
    final journal = RecordingJournal(
      clockSource: () => DateTime.utc(2026, 11, 15, 12),
    );
    final src = Cell.ingress<int>();
    final handle = cognitive(
      cell: src.cell,
      policy: TestCell.allowAll,
      verdictPolicy: promptedPolicyWith(
        config: PromptConfig.custom(
          id: 'bench-miss-$i',
          version: '1.0.0',
          description: 'bench',
          systemPrompt: 'Decide.',
          userTemplate: '{{context}}\n\n{{decision}}',
        ),
        prompt: (_) async => '{"verdict":"accept"}',
        journal: journal,
      ),
    );
    await handle.cognitive.apply<Object?>(
      (
        function: () => 1,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ),
    );
  }
  stopwatch.stop();
  print('  cache miss (full cognitive decision): '
      '${(misses * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'decisions/s');

  // 4. Cache hit: the same decision again — the adapter never runs.
  const hits = 5000;
  final journal = RecordingJournal(
    clockSource: () => DateTime.utc(2026, 11, 15, 12),
  );
  final src = Cell.ingress<int>();
  final handle = cognitive(
    cell: src.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: PromptConfig.custom(
        id: 'bench-hit',
        version: '1.0.0',
        description: 'bench',
        systemPrompt: 'Decide.',
        userTemplate: '{{context}}\n\n{{decision}}',
      ),
      prompt: (_) async => '{"verdict":"accept"}',
      journal: journal,
    ),
  );
  await handle.cognitive.apply<Object?>(
    (
      function: () => 1,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ),
  );
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < hits; i++) {
    await handle.cognitive.apply<Object?>(
      (
        function: () => 1,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ),
    );
  }
  stopwatch.stop();
  print('  cache hit (full cognitive decision): '
      '${(hits * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'decisions/s');

  // 5. Conformance runner (mock LLM, three cases).
  const runs = 200;
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    await conform(
      config: PromptConfig.custom(
        id: 'bench-conf-$i',
        version: '1.0.0',
        description: 'bench',
        systemPrompt: 'Decide.',
        userTemplate: '{{context}}\n\n{{decision}}',
      ),
      prompt: (_) async => '{"verdict":"accept"}',
      cases: [
        ConformanceCase(
          context: context,
          decision: decision(),
          expected: const Accept(),
        ),
        ConformanceCase(
          context: context,
          decision: decision(),
          expected: const Accept(),
        ),
        ConformanceCase(
          context: context,
          decision: decision(),
          expected: const Accept(),
        ),
      ],
    );
  }
  stopwatch.stop();
  print('  conform (3 mock cases): '
      '${(runs * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'runs/s');

  // 6. Session render: history included in the prompt.
  final session = PromptSession();
  for (var i = 0; i < 20; i++) {
    session.appendExchange(
      ChatMessage(role: ChatRole.user, content: 'decision $i'),
      ChatMessage(
        role: ChatRole.assistant,
        content: '{"verdict":"accept","reason":"ok"}',
      ),
    );
  }
  const sessionRenders = 2000;
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < sessionRenders; i++) {
    PromptConfig.custom(
      id: 'bench-session',
      version: '1.0.0',
      description: 'bench',
      systemPrompt: 'Decide.',
      userTemplate: '{{context}}\n\n{{decision}}',
    ).render(context: context, decision: decision(), session: session);
  }
  stopwatch.stop();
  print('  session render (20 turns): '
      '${(sessionRenders * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'renders/s');

  // 7. Verdict cache hit: the three-tier fast path.
  final verdictCache = InMemoryVerdictCache();
  final vcSrc = Cell.ingress<int>();
  final vcHandle = cognitive(
    cell: vcSrc.cell,
    policy: TestCell.allowAll,
    verdictPolicy: promptedPolicyWith(
      config: PromptConfig.custom(
        id: 'bench-vc',
        version: '1.0.0',
        description: 'bench',
        systemPrompt: 'Decide.',
        userTemplate: '{{context}}\n\n{{decision}}',
      ),
      prompt: (_) async => '{"verdict":"accept"}',
      journal: RecordingJournal(),
      verdictCache: verdictCache,
    ),
  );
  await vcHandle.cognitive.apply<Object?>(
    (
      function: () => 1,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ),
  );
  const vcHits = 5000;
  stopwatch = Stopwatch()..start();
  for (var i = 0; i < vcHits; i++) {
    await vcHandle.cognitive.apply<Object?>(
      (
        function: () => 1,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ),
    );
  }
  stopwatch.stop();
  print('  verdict cache hit (full cognitive decision): '
      '${(vcHits * 1000000 / stopwatch.elapsedMicroseconds).toStringAsFixed(0)} '
      'decisions/s');
}
