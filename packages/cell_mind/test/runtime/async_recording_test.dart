// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  ApplyCommand command(int tag) => (
        function: (int x) => x,
        arguments: (positionalArguments: [tag], namedArguments: null),
        compensation: null,
      );

  group('async policy recording', () {
    test('an async accepting policy records Accept', () async {
      final asyncPolicy = TestCell<Cell>(
        (object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          return true;
        },
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, policy: asyncPolicy);
      final outcome = await handle.cognitive.apply<int>(command(1));
      expect(outcome, isA<ApplyAccepted<int>>());
      expect(handle.decisions, hasLength(1));
      expect(handle.decisions.single.verdict, isA<Accept>());
    });

    test('an async rejecting policy records Reject before the caller sees it',
        () async {
      final asyncPolicy = TestCell<Cell>(
        (object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          return false;
        },
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, policy: asyncPolicy);
      final outcome = await handle.cognitive.apply<int>(command(1));
      expect(outcome, isA<ApplyRejected<int>>());
      // The decision is logged before the await returns to the caller.
      expect(handle.decisions, hasLength(1));
      expect(
        (handle.decisions.single.verdict as Reject).reason,
        'policy-rejected',
      );
    });

    test('an async throwing policy fails closed via the substrate', () async {
      final throwingPolicy = TestCell<Cell>(
        (object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          throw StateError('boom');
        },
      );
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, policy: throwingPolicy);
      // StateError is an Error: the substrate rethrows it rather than
      // converting it to a rejection. The recorder therefore does not
      // record a decision — the caller bug propagates loudly.
      await expectLater(
        handle.cognitive.apply<int>(command(1)),
        throwsStateError,
      );
      expect(handle.decisions, isEmpty);
    });

    test('async policy composition records correctly', () async {
      final composed = TestCell<Cell>(
            (object, {host, arguments, user}) async => true,
          ) +
          TestCell<Cell>(
            (object, {host, arguments, user}) async => false,
          );
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, policy: composed);
      final outcome = await handle.cognitive.apply<int>(command(1));
      expect(outcome, isA<ApplyRejected<int>>());
      expect(handle.decisions, hasLength(1));
    });
  });
}
