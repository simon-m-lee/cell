// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  Context hostWithRules(List<Map<String, dynamic>> rules) =>
      Context.fromEntries([
        Ontology.domains.entry('finance,marketing,audit'),
        Ontology.constraints.entry({
          'cell_mind.policy': {'version': 1, 'rules': rules},
        }),
      ]);

  Map<String, dynamic> rule(String action, {Map<String, dynamic>? extra}) => {
        'when': {'domains': 'marketing'},
        'action': action,
        'confidence': 0.9,
        'support': 10,
        'trainedIn': 1,
        ...?extra,
      };

  group('learnedVerdictPolicy', () {
    test('accept rules emit Accept with annotations', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([
          rule('accept', extra: {
            'annotations': {'src': 'learned'}
          }),
        ]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict =
          policy.call(governedPulse(domains: 'marketing'), host: host);
      expect(verdict, isA<Accept>());
      expect((verdict as Accept).annotations, {'src': 'learned'});
    });

    test('reject rules emit Reject with reason and annotations', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([
          rule('reject', extra: {
            'reason': 'bad-actor',
            'annotations': {'code': 1},
          }),
        ]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict =
          policy.call(governedPulse(domains: 'marketing'), host: host);
      expect(verdict, isA<Reject>());
      final reject = verdict as Reject;
      expect(reject.reason, 'bad-actor');
      expect(reject.annotations, {'code': 1});
    });

    test('defer rules emit Defer with resolver and annotations', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([
          rule('defer', extra: {
            'resolver': 'supervisor',
            'annotations': {'tier': 'gold'},
          }),
        ]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict =
          policy.call(governedPulse(domains: 'marketing'), host: host);
      expect(verdict, isA<Defer>());
      final defer = verdict as Defer;
      expect(defer.resolver, 'supervisor');
      expect(defer.annotations, {'tier': 'gold'});
    });

    test('a defer rule without resolver defaults to approval', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([rule('defer')]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict =
          policy.call(governedPulse(domains: 'marketing'), host: host);
      expect((verdict as Defer).resolver, 'approval');
    });

    test('no matching rule is Accept (additive default)', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([rule('reject')]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict =
          policy.call(governedPulse(domains: 'finance'), host: host);
      expect(verdict, isA<Accept>());
    });

    test('subset matching applies multi-domain pulses', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([
          rule('reject', extra: {'reason': 'x'})
        ]),
      ).cell;
      final policy = learnedVerdictPolicy();
      final verdict = policy.call(
        governedPulse(domains: 'marketing,audit'),
        host: host,
      );
      expect(verdict, isA<Reject>());
    });

    test('non-pulse objects are Accept (command vectorization is Phase 5)',
        () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([rule('reject')]),
      ).cell;
      final policy = learnedVerdictPolicy();
      expect(policy.call('text', host: host), isA<Accept>());
    });

    test('composes with verdictPolicy via +', () async {
      final host = Cell.ingress<int>(
        context: hostWithRules([
          rule('reject', extra: {'reason': 'x'})
        ]),
      ).cell;
      final composite = verdictPolicy(
            (object, {required host, arguments}) => const Defer('first'),
          ) +
          learnedVerdictPolicy();
      final verdict = composite.call(
        governedPulse(domains: 'marketing'),
        host: host,
      );
      expect(verdict, isA<Reject>(),
          reason: 'The manual Defer propagates into the learned policy.');
    });
  });
}
