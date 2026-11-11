// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('Tissue Apply command model', () {
    test('execute routes through the dispatch engine and returns accepted',
        () async {
      final list = TissueList<int>();

      final outcome = await list.apply<dynamic>((
        function: list.add,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));

      expect(outcome, isA<ApplyAccepted<dynamic>>());
      expect(outcome.receipt.vetted, isTrue);
      expect(list.toList(), [1]);
    });

    test('execute stages into a transaction and commits atomically',
        () async {
      final list = TissueList<int>();
      final tx = Cell.txApply();

      late ApplyOutcome<dynamic> staged;
      await tx.execute(participants: [list], body: (scope) {
        staged = list.apply<dynamic>(
          (
            function: list.add,
            arguments: (positionalArguments: [4], namedArguments: null),
            compensation: null,
          ),
          tx: scope,
        ) as ApplyOutcome<dynamic>;
        expect(list.toList(), isEmpty);
      });

      expect(staged, isA<ApplyStaged>());
      expect(staged.receipt.txSequence, 0);
      expect(list.toList(), [4]);
    });

    test('execute with compensation rolls back through the command model',
        () async {
      final list = TissueList<int>.of([1]);
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(participants: [list], body: (scope) {
          list.apply<dynamic>(
            (
              function: list.add,
              arguments: (positionalArguments: [2], namedArguments: null),
              compensation: (
                function: list.remove,
                arguments: (positionalArguments: [2], namedArguments: null),
                cell: list,
              ),
            ),
            tx: scope,
          );
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(list.toList(), [1]);
    });

    test('execute on an unmodifiable view returns rejected', () async {
      final list = TissueList<int>.of([1]);
      final view = list.unmodifiable;

      final outcome = await view.apply<int>((
        function: list.add,
        arguments: (positionalArguments: [9], namedArguments: null),
        compensation: null,
      ));

      expect(outcome, isA<ApplyRejected<int>>());
      expect(list.toList(), [1]);
    });
  });
}
