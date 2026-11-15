// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('CognitiveHandle construction', () {
    test('exposes principal, cognitive view, policy, log, outcomes', () async {
      final src = Cell.ingress<int>();
      final policy = domainPolicy();
      final handle = cognitive(cell: src.cell, policy: policy);
      expect(handle.cell, same(src.cell));
      expect(handle.cognitive, isA<Cell>());
      expect(handle.cognitive, isNot(same(src.cell)));
      expect(handle.policy, same(policy));
      expect(handle.decisions, isEmpty);
      expect(handle.outcomes, isA<IngressHandle<Pulse>>());
      expect(handle.isDisposed, isFalse);
    });

    test('records against the default allowAll policy', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      expect(handle.policy, same(TestCell.allowAll));
      final outcome = await handle.cognitive.apply<int>(trivialCommand());
      expect(outcome, isA<ApplyAccepted<int>>());
      expect(handle.decisions, hasLength(1));
      expect(handle.decisions.first.verdict, isA<Accept>());
    });

    test('rejects non-positive maxDecisions at construction', () {
      final src = Cell.ingress<int>();
      expect(
        () => cognitive(cell: src.cell, maxDecisions: 0),
        throwsArgumentError,
      );
      expect(
        () => cognitive(cell: src.cell, maxDecisions: -1),
        throwsArgumentError,
      );
    });

    test('dispose marks the handle and guards recordOutcome', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      expect(handle.isDisposed, isFalse);
      handle.dispose();
      expect(handle.isDisposed, isTrue);
      handle.dispose(); // idempotent
      expect(
        () => handle.recordOutcome(decisionId: 'x', reward: 1),
        throwsStateError,
      );
      // The log remains readable after disposal.
      expect(handle.decisions, isEmpty);
    });

    test('maxDecisions getter reports the configured cap', () {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, maxDecisions: 7);
      expect(handle.maxDecisions, 7);
    });
  });

  group('CognitiveHandle identity', () {
    test('the cognitive view shares the principal context', () async {
      final ctx = ctxWithDomains('finance');
      final src = Cell.ingress<int>(context: ctx);
      final handle = cognitive(cell: src.cell);
      expect(handle.cognitive.context.domains, 'finance');
      expect(handle.cognitive.context, same(ctx));
    });

    test('two handles over the same cell are independent views', () {
      final src = Cell.ingress<int>();
      final h1 = cognitive(cell: src.cell);
      final h2 = cognitive(cell: src.cell);
      expect(h1.cognitive, isNot(same(h2.cognitive)));
      expect(h1.decisions, isNot(same(h2.decisions)));
    });
  });
}
