// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

Decision decision({
  Verdict verdict = const Accept(),
  String? actor,
  double? confidence,
  ReasoningStrategy? strategy,
}) {
  final entries = <GovernanceEntry<Provenance, dynamic>>[
    if (actor != null) Provenance.actor.entry(actor),
    if (confidence != null) Provenance.confidence.entry(confidence),
    if (strategy != null) Provenance.strategy.entry(strategy),
    Provenance.traceId.entry('t-1'),
  ];
  return Decision(
    id: 'abc-123',
    at: DateTime.utc(2026, 11, 15, 10, 30),
    context: Context.fromEntries([Ontology.domains.entry('finance')]),
    contextVersion: '1.0.0',
    verdict: verdict,
    pulse: Pulse<int>.governed(
      payload: 42,
      context: PulseContext.fromEntries(entries),
    ),
    evaluationTime: const Duration(milliseconds: 2),
  );
}

void main() {
  group('narratives', () {
    test('audit template includes timestamp, id, verdict, metadata', () {
      final text = DecisionPath(decision(
        verdict: const Reject('policy-rejected'),
        actor: 'agent_a',
        confidence: 0.82,
        strategy: ReasoningStrategy.probabilistic,
      )).toNarrative();
      expect(text, contains('[2026-11-15T10:30:00.000Z]'));
      expect(text, contains('decision abc-123'));
      expect(text, contains("REJECT 'policy-rejected'"));
      expect(text, contains('actor=agent_a'));
      expect(text, contains('strategy=probabilistic'));
      expect(text, contains('conf=0.82'));
      expect(text, contains('ctx-version=1.0.0'));
      expect(text, contains('eval=2ms'));
    });

    test('ui template is human-facing with no ids', () {
      final text = DecisionPath(decision(
        actor: 'agent_a',
        confidence: 0.82,
      )).toNarrative(template: NarrativeTemplate.ui);
      expect(text, 'agent_a accepted the request (confidence 82%)');
      expect(text, isNot(contains('abc-123')));
    });

    test('ui reject includes the reason', () {
      final text = DecisionPath(decision(
        verdict: const Reject('over-budget'),
        actor: 'agent_a',
      )).toNarrative(template: NarrativeTemplate.ui);
      expect(text, 'agent_a rejected the request: over-budget');
    });

    test('ui defer names the resolver', () {
      final text = DecisionPath(decision(
        verdict: const Defer('supervisor'),
        actor: 'agent_a',
      )).toNarrative(template: NarrativeTemplate.ui);
      expect(text, 'agent_a deferred the request to supervisor');
    });

    test('debug template is structured', () {
      final text = DecisionPath(decision()).toNarrative(
        template: NarrativeTemplate.debug,
      );
      expect(text, contains('DecisionPath(id: abc-123'));
      expect(text, contains('ACCEPT'));
      expect(text, contains('Pulse<int>(42)'));
      expect(text, contains('context: v1.0.0'));
      expect(text, contains('eval: 2ms'));
    });

    test('command decisions render without pulse metadata', () {
      final command = Decision(
        id: 'd-cmd',
        at: DateTime.utc(2026, 11, 15),
        context: Context.system,
        contextVersion: '0.0.0',
        verdict: const Reject('blocked'),
        command: (
          function: () => 1,
          arguments: (positionalArguments: null, namedArguments: null),
          compensation: null,
        ),
      );
      final audit = DecisionPath(command).toNarrative();
      expect(audit, contains('decision d-cmd'));
      expect(audit, contains("REJECT 'blocked'"));
      final ui = DecisionPath(command).toNarrative(
        template: NarrativeTemplate.ui,
      );
      expect(ui, contains('An actor rejected the request: blocked'));
    });

    test('defer verdicts label their resolver in audit', () {
      final text = DecisionPath(decision(
        verdict: const Defer('approval'),
      )).toNarrative();
      expect(text, contains("DEFER 'approval'"));
    });
  });
}
