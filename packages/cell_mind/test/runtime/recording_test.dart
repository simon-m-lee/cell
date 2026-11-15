// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  ApplyCommand commandFor(Function fn, [List<Object?>? args]) => (
        function: fn,
        arguments: (positionalArguments: args, namedArguments: null),
        compensation: null,
      );

  int read(int x) => x;

  group('decision recording — apply path', () {
    test('accepting a command records Accept with full provenance', () async {
      final src = Cell.ingress<int>(context: ctxWithVersion('1.2.3'));
      final handle = cognitive(cell: src.cell);
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyAccepted<int>>());
      final decision = handle.decisions.single;
      expect(decision.id, isNotEmpty);
      expect(decision.at, isA<DateTime>());
      expect(decision.contextVersion, '1.2.3');
      expect(decision.verdict, isA<Accept>());
      expect(decision.command, isNotNull);
      expect(decision.command!.function, same(read));
      expect(decision.command!.arguments.positionalArguments, [7]);
      expect(decision.pulse, isNull);
      expect(decision.evaluationTime, isNotNull);
      expect(decision.policyVersion, isNotNull);
    });

    test('a policy rejection records Reject with reason policy-rejected',
        () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
      );
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<int>>());
      final decision = handle.decisions.single;
      expect(decision.verdict, isA<Reject>());
      expect((decision.verdict as Reject).reason, 'policy-rejected');
    });

    test('each decision gets a unique id', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      await handle.cognitive.apply<int>(commandFor(read, [1]));
      await handle.cognitive.apply<int>(commandFor(read, [2]));
      expect(handle.decisions, hasLength(2));
      expect(
        handle.decisions[0].id,
        isNot(handle.decisions[1].id),
      );
    });
  });

  group('decision recording — pulse path', () {
    test('a pulse flowing through the cognitive view is recorded', () async {
      final src = Cell.ingress<int>(context: ctxWithVersion('2.0.0'));
      final handle = cognitive(cell: src.cell);
      src.emit(42);
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions, hasLength(1));
      final decision = handle.decisions.single;
      expect(decision.verdict, isA<Accept>());
      expect(decision.pulse, isNotNull);
      expect(decision.pulse!.payload, 42);
      expect(decision.contextVersion, '2.0.0');
      expect(decision.command, isNull);
    });

    test('the policy governs pulses reaching the view', () async {
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final handle = cognitive(cell: src.cell, policy: domainPolicy());
      // A governed pulse with a foreign domain is rejected by the policy
      // before the view accepts it — and the rejection is recorded.
      final pulse = governedPulse(payload: 1, domains: 'marketing');
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p);
          });
      src.ingest(pulse);
      await Future<void>.delayed(Duration.zero);
      expect(observed, isEmpty);
      // NOTE: observing the cognitive view links an observer cell to it —
      // the link decision is recorded too. Filter to pulse decisions.
      final pulseDecisions =
          handle.decisions.where((d) => d.pulse != null).toList();
      expect(pulseDecisions, hasLength(1));
      expect(
          (pulseDecisions.single.verdict as Reject).reason, 'policy-rejected');
      sub.stop();
    });
  });

  group('decision recording — link path', () {
    test('link validation through the view records a decision', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell);
      // Direct evaluation of the view's rule with a Cell object — the
      // link-validation shape.
      final link = Cell.ingress<int>().cell;
      final result =
          await handle.cognitive.validate.call(link, host: handle.cognitive);
      expect(result, isTrue);
      expect(handle.decisions, hasLength(1));
      final decision = handle.decisions.single;
      expect(decision.pulse, isNull);
      expect(decision.command, isNull);
      expect(decision.verdict, isA<Accept>());
    });
  });

  group('attribution documentation', () {
    test('principal rejections drop before the recorder (documented)',
        () async {
      // The deputy chain runs the principal's rule first; a
      // principal-rejected command never reaches the recorder. The gate
      // rejects only commands — links (deputy construction) and pulses
      // still pass.
      final gate = TestCell<Cell>(
        (object, {host, arguments, user}) => object is! Function,
      );
      final src = Cell.ingress<int>(testRule: gate);
      final handle = cognitive(cell: src.cell);
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<int>>());
      expect(handle.decisions, isEmpty,
          reason: 'chain([principalRule, recorder]) short-circuits before '
              'the recorder; only decisions that reach the recorder are '
              'logged (guide/02-Runtime.md §5).');
    });
  });
}
