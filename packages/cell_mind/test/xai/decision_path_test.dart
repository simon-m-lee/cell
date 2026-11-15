// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  Decision pulseDecision({Verdict verdict = const Accept()}) {
    final pulse = Pulse<int>.governed(
      payload: 42,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('agent-a'),
        Provenance.reason.entry('test'),
        Provenance.confidence.entry(0.82),
        Provenance.strategy.entry(ReasoningStrategy.probabilistic),
        Provenance.purpose.entry('TEST'),
        Provenance.compliance.entry('SOC2'),
        Provenance.sensitivity.entry(Sensitivity.restricted),
        Provenance.auditLevel.entry(AuditLevel.detailed),
        Provenance.traceId.entry('trace-1'),
      ]),
    );
    return Decision(
      id: 'd-1',
      at: DateTime.utc(2026, 11, 15, 10),
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
      contextVersion: '1.0.0',
      verdict: verdict,
      pulse: pulse,
      policyVersion: '0.6.0',
      evaluationTime: const Duration(milliseconds: 2),
    );
  }

  Decision commandDecision() => Decision(
        id: 'd-2',
        at: DateTime.utc(2026, 11, 15, 10, 1),
        context: Context.system,
        contextVersion: '0.0.0',
        verdict: const Reject('blocked'),
        command: (
          function: () => 1,
          arguments: (positionalArguments: null, namedArguments: null),
          compensation: null,
        ),
      );

  group('DecisionPath', () {
    test('projects the decision fields', () {
      final decision = pulseDecision();
      final path = DecisionPath(decision);
      expect(path.id, decision.id);
      expect(path.at, decision.at);
      expect(path.context, decision.context);
      expect(path.contextVersion, '1.0.0');
      expect(path.pulse, decision.pulse);
      expect(path.command, isNull);
      expect(path.verdict, decision.verdict);
      expect(path.policyVersion, '0.6.0');
      expect(path.evaluationTime, const Duration(milliseconds: 2));
    });

    test('derived accessors read pulse provenance', () {
      final path = DecisionPath(pulseDecision());
      expect(path.actor, 'agent-a');
      expect(path.strategy, ReasoningStrategy.probabilistic);
      expect(path.confidence, 0.82);
      expect(path.purpose, 'TEST');
      expect(path.reason, 'test');
      expect(path.compliance, 'SOC2');
      expect(path.sensitivity, Sensitivity.restricted);
      expect(path.auditLevel, AuditLevel.detailed);
      expect(path.traceId, 'trace-1');
    });

    test('command decisions expose null provenance accessors', () {
      final path = DecisionPath(commandDecision());
      expect(path.pulse, isNull);
      expect(path.actor, isNull);
      expect(path.strategy, isNull);
      expect(path.confidence, isNull);
      expect(path.traceId, isNull);
      expect(path.command, isNotNull);
      expect(path.verdict, isA<Reject>());
    });

    test('explain wraps a decision', () {
      final decision = pulseDecision();
      expect(explain(decision).decision, decision);
    });

    test('accept/reject/defer verdicts expose their types', () {
      expect(const Accept().type, 'accept');
      expect(const Reject('r').type, 'reject');
      expect(const Defer('approval').type, 'defer');
    });
  });
}
