// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('state sharing between principal and cognitive view', () {
    test('principal updates flow through the cognitive view', () async {
      final state = Cell.state<int>(initial: 7);
      final handle = cognitive(cell: state.cell);
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      state.update(42);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [42]);
      sub.stop();
    });

    test('the cognitive view sees the principal state via apply', () async {
      final state = Cell.state<int>(initial: 7);
      final handle = cognitive(cell: state.cell);
      final outcome = await handle.cognitive.apply<int>((
        function: () => state.cell.value,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));
      expect((outcome as ApplyAccepted<int>).result, 7);
    });

    test('principal pulses record through the view (value cell)', () async {
      final state = Cell.state<int>(initial: 0);
      final handle = cognitive(cell: state.cell);
      state.update(1);
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions, hasLength(1));
      expect(handle.decisions.single.pulse?.payload, 1);
    });

    test('the principal remains ungoverned by the cognitive policy', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
      );
      // Through the principal: accepted (no cognitive policy).
      expect(src.emit(1), isTrue);
      // Through the cognitive view: rejected and recorded. The policy is
      // consulted for the argument first; that rejection short-circuits
      // the action-level evaluation, and is attributed to the command.
      // The principal's earlier emission was also recorded (rejected by
      // the view's policy).
      final outcome = await handle.cognitive.apply<int>((
        function: (int x) => x,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
      expect(outcome, isA<ApplyRejected<int>>());
      expect(
        handle.decisions.where((d) => d.pulse != null),
        hasLength(1),
        reason: 'The principal\'s emission reached the view and was '
            'recorded (rejected).',
      );
      final commandDecisions =
          handle.decisions.where((d) => d.command != null).toList();
      expect(commandDecisions, hasLength(1));
      expect(
        commandDecisions.every((d) => d.verdict is Reject),
        isTrue,
        reason: 'The argument-level rejection is attributed to the '
            'command; the action-level evaluation short-circuited.',
      );
    });
  });
}
