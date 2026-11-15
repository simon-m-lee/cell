// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  Context hostWithBlock(Map<String, dynamic> block) => Context.fromEntries([
        Ontology.domains.entry('finance,marketing,audit'),
        Ontology.constraints.entry({'cell_mind.policy': block}),
      ]);

  final rejectMarketingBlock = {
    'version': 1,
    'rules': [
      {
        'when': {'domains': 'marketing'},
        'action': 'reject',
        'confidence': 0.92,
        'support': 42,
        'trainedIn': 1,
      },
    ],
  };

  group('learnedPolicy', () {
    test('no block → pass through', () async {
      final host = Cell.ingress<int>(context: ctxWithDomains('finance')).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isTrue,
      );
    });

    test('a matching reject rule rejects', () async {
      final host =
          Cell.ingress<int>(context: hostWithBlock(rejectMarketingBlock)).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isFalse,
      );
    });

    test('a non-matching pulse passes through', () async {
      final host =
          Cell.ingress<int>(context: hostWithBlock(rejectMarketingBlock)).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(governedPulse(domains: 'finance'), host: host),
        isTrue,
      );
    });

    test('subset matching: a multi-domain pulse still matches', () async {
      final host =
          Cell.ingress<int>(context: hostWithBlock(rejectMarketingBlock)).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(
          governedPulse(domains: 'marketing,audit'),
          host: host,
        ),
        isFalse,
        reason: 'The rule\'s marketing requirement is a subset of the '
            'pulse\'s domains.',
      );
    });

    test('accept rules accept', () async {
      final block = {
        'version': 1,
        'rules': [
          {
            'when': {'domains': 'finance'},
            'action': 'accept',
            'confidence': 0.8,
            'support': 10,
            'trainedIn': 1,
          },
        ],
      };
      final host = Cell.ingress<int>(context: hostWithBlock(block)).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(governedPulse(domains: 'finance'), host: host),
        isTrue,
      );
    });

    test('first-match wins by confidence order', () async {
      final block = {
        'version': 1,
        'rules': [
          {
            'when': {'domains': 'marketing'},
            'action': 'reject',
            'confidence': 0.95,
            'support': 50,
            'trainedIn': 1,
          },
          {
            'when': {'domains': 'marketing'},
            'action': 'accept',
            'confidence': 0.7,
            'support': 30,
            'trainedIn': 1,
          },
        ],
      };
      final host = Cell.ingress<int>(context: hostWithBlock(block)).cell;
      final policy = learnedPolicy();
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isFalse,
        reason: 'The higher-confidence reject rule wins.',
      );
    });

    test('non-pulse objects pass through (commands unvectorized in 0.3.0)',
        () async {
      final host =
          Cell.ingress<int>(context: hostWithBlock(rejectMarketingBlock)).cell;
      final policy = learnedPolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
      expect(await policy.call(host, host: host), isTrue);
    });

    test('composes with contextAware', () async {
      final host =
          Cell.ingress<int>(context: hostWithBlock(rejectMarketingBlock)).cell;
      final policy = contextAware() + learnedPolicy();
      // contextAware accepts the domain; learnedPolicy rejects it.
      expect(
        await policy.call(
          governedPulse(domains: 'marketing', confidence: 0.99),
          host: host,
        ),
        isFalse,
      );
      expect(
        await policy.call(
          governedPulse(domains: 'finance', confidence: 0.99),
          host: host,
        ),
        isTrue,
      );
    });
  });
}

int someFunction(int x) => x;
