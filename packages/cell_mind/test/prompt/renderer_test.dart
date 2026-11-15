// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('context renderer', () {
    test('renders typed ontology dimensions in declaration order', () {
      final context = Context(
        domains: 'finance,audit',
        compliances: 'GDPR,SOC2',
        constraints: {'max_amount': 10000, 'require_mfa': true},
        partOf: 'ledger_service',
      );
      final rendered = renderContext(context);
      expect(rendered, startsWith('## Context\n\n'));
      final domainsAt = rendered.indexOf('- domains:');
      final constraintsAt = rendered.indexOf('- constraints:');
      final complianceAt = rendered.indexOf('- compliance:');
      final partOfAt = rendered.indexOf('- partOf:');
      expect(domainsAt, greaterThan(0));
      expect(constraintsAt, greaterThan(domainsAt));
      expect(complianceAt, greaterThan(constraintsAt));
      expect(partOfAt, greaterThan(complianceAt));
    });

    test('renders mandate dimensions for a deputy context', () {
      final context = DeputyContext(
        baseContext: Context(domains: 'finance'),
        authority: 'read,write',
        clearance: Clearance.standard,
        isolation: Isolation.scoped,
        role: 'Auditor',
      );
      final rendered = renderContext(context);
      expect(rendered, contains('- authority: read,write'));
      expect(rendered, contains('- role: Auditor'));
      expect(rendered, contains('- isolation: scoped'));
      expect(rendered, contains('- domains: finance'));
    });

    test('omits empty dimensions', () {
      final rendered = renderContext(Context.system);
      expect(rendered, '## Context\n\n- (empty)');
      expect(renderContext(Context(domains: '  ')), '## Context\n\n- (empty)');
      expect(
        renderContext(Context(constraints: const {})),
        '## Context\n\n- (empty)',
      );
    });

    test('sorts map values by key regardless of insertion order', () {
      final a = renderContext(
        Context(constraints: {
          'z': 1,
          'a': 2,
          'm': {'n': 1, 'b': 2}
        }),
      );
      final b = renderContext(
        Context(constraints: {
          'm': {'b': 2, 'n': 1},
          'a': 2,
          'z': 1
        }),
      );
      expect(a, b);
      expect(a, contains('{"a":2,"m":{"b":2,"n":1},"z":1}'));
    });

    test('renders enums as names, lists as comma-joined values', () {
      final rendered = renderContext(
        DeputyContext(
          baseContext: Context.system,
          authority: 'x',
          isolation: Isolation.restricted,
          clearance: Clearance.privileged,
        ),
      );
      expect(rendered, contains('- isolation: restricted'));
      expect(rendered, contains('- clearance: privileged'));
    });

    test('is byte-identical across repeated calls', () {
      final context = Context(
        domains: 'a,b',
        constraints: {
          'k': [1, 2, 3]
        },
        compliances: 'GDPR',
      );
      final first = renderContext(context);
      final second = renderContext(context);
      expect(first, second);
      expect(first.codeUnits, second.codeUnits);
    });
  });

  group('decision renderer', () {
    test('renders a governed pulse with provenance in declaration order', () {
      final pulse = governedPulse(
        payload: 5000,
        actor: 'system',
        strategy: ReasoningStrategy.probabilistic,
        confidence: 0.95,
        purpose: 'TRANSACTION',
        traceId: 'trace-1',
      );
      final rendered = renderDecision(pulse);
      expect(rendered, startsWith('## Decision\n\n'));
      expect(rendered, contains('- type: unknown'));
      expect(rendered, contains('- payload: 5000'));
      expect(rendered, contains('- actor: system'));
      expect(rendered, contains('- strategy: probabilistic'));
      expect(rendered, contains('- confidence: 0.95'));
      expect(rendered, contains('- purpose: TRANSACTION'));
      expect(rendered, contains('- traceId: trace-1'));
      final actorAt = rendered.indexOf('- actor:');
      final purposeAt = rendered.indexOf('- purpose:');
      final strategyAt = rendered.indexOf('- strategy:');
      final confidenceAt = rendered.indexOf('- confidence:');
      // Provenance declaration order: actor, reason, purpose, strategy,
      // confidence, priority, compliance, sensitivity, auditLevel,
      // traceId, parentTraceId, integrity.
      expect(purposeAt, greaterThan(actorAt));
      expect(strategyAt, greaterThan(purposeAt));
      expect(confidenceAt, greaterThan(strategyAt));
    });

    test('does not render the pulse timestamp (determinism)', () {
      final pulse = Pulse<int>(1);
      final rendered = renderDecision(pulse);
      expect(rendered, isNot(contains('- timestamp:')));
      expect(rendered, isNot(contains(pulse.timestamp.toIso8601String())));
    });

    test('renders the source identity when the pulse has a source', () {
      final src = Cell.ingress<int>(context: Context(identity: 'gate.ingress'));
      final pulse = Pulse<int>(1, source: src.cell);
      expect(renderDecision(pulse), contains('- source: gate.ingress'));
    });

    test('renders payload maps as sorted JSON', () {
      final pulse = Pulse<Map<String, dynamic>>(
        {
          'z': 1,
          'a': {'y': 2, 'b': 1}
        },
        type: 'tx',
      );
      final rendered = renderDecision(pulse);
      expect(rendered, contains('"a":{"b":1,"y":2}'));
      expect(rendered, contains('"z":1'));
    });

    test('renders non-encodable payloads via toString', () {
      final pulse = Pulse<Object>(Object(), type: 'opaque');
      // Non-encodable values degrade to their `toString()` text inside
      // the JSON string (lossy but deterministic).
      expect(renderDecision(pulse), contains("Instance of 'Object'"));
    });

    test('renders a Function decision with arguments', () {
      int buy(int amount) => amount;
      final rendered = renderDecision(
        buy,
        arguments: (positionalArguments: [7], namedArguments: null),
      );
      expect(rendered, contains('- type: action'));
      expect(rendered, contains('- function:'));
      expect(rendered, contains('"positional":[7]'));
    });

    test('renders named Symbol arguments by plain name', () {
      int buy({int amount = 0}) => amount;
      final rendered = renderDecision(
        buy,
        arguments: (
          positionalArguments: null,
          namedArguments: {#amount: 7},
        ),
      );
      expect(rendered, contains('"named":{"amount":7}'));
    });

    test('renders a link decision', () {
      final target = Cell.ingress<int>(context: Context(identity: 'ledger'));
      expect(renderDecision(target.cell), contains('- target: ledger'));
    });

    test('renders unknown objects defensively', () {
      final rendered = renderDecision(DateTime.utc(2026, 11, 15));
      expect(rendered, contains('- type: DateTime'));
      expect(rendered, contains('- value:'));
    });

    test('is byte-identical across repeated calls', () {
      final pulse = Pulse<Map<String, int>>({'a': 1});
      expect(renderDecision(pulse), renderDecision(pulse));
    });
  });

  group('config renderer', () {
    PromptConfig config() => PromptConfig.custom(
          id: 'r',
          version: '1.0.0',
          description: 'd',
          systemPrompt: 'SYSTEM',
          userTemplate: '{{context}}\n\n{{decision}}',
          examples: const [
            PromptExample(
              context: 'CTX',
              decision: 'DEC',
              response: '{"verdict":"accept"}',
            ),
          ],
        );

    test('assembles system, examples, template, and schema in order', () {
      final rendered = config().render(
        context: Context(domains: 'd'),
        decision: 1,
      );
      expect(rendered, startsWith('SYSTEM\n\n### Example 1\n\n'));
      expect(rendered, contains('Context:\nCTX\n\nDecision:\nDEC'));
      expect(rendered, contains('## Expected Output'));
      expect(rendered, endsWith('"annotations":{"type":"object"}}}\n'));
    });

    test('renders examples in fixed order', () {
      final c = PromptConfig.custom(
        id: 'r',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'S',
        userTemplate: '{{context}}',
        examples: const [
          PromptExample(
              context: '1', decision: 'a', response: '{"verdict":"accept"}'),
          PromptExample(
              context: '2', decision: 'b', response: '{"verdict":"accept"}'),
        ],
      );
      final rendered = c.render(context: Context.system, decision: 1);
      final first = rendered.indexOf('### Example 1');
      final second = rendered.indexOf('### Example 2');
      expect(first, greaterThan(0));
      expect(second, greaterThan(first));
    });

    test('unknown placeholders remain literal', () {
      final c = PromptConfig.custom(
        id: 'r',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'S',
        userTemplate: '{{context}} {{other}}',
      );
      final rendered = c.render(context: Context.system, decision: 1);
      expect(rendered, contains('{{other}}'));
    });

    test('missing placeholders are allowed', () {
      final c = PromptConfig.custom(
        id: 'r',
        version: '1.0.0',
        description: 'd',
        systemPrompt: 'S',
        userTemplate: 'just a prompt',
      );
      c.validate();
      final rendered = c.render(context: Context.system, decision: 1);
      expect(rendered, contains('just a prompt'));
    });

    test('byte-for-byte determinism of the complete prompt', () {
      final c = config();
      final context = Context(
        domains: 'finance',
        constraints: {'b': 2, 'a': 1},
        compliances: 'GDPR',
      );
      final decision = Pulse<Map<String, int>>({'x': 1});
      final a = c.render(context: context, decision: decision);
      final b = c.render(context: context, decision: decision);
      expect(a, b);
      expect(a.codeUnits, b.codeUnits);
    });
  });
}
