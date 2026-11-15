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

  group('decision log truncation', () {
    test('drops the oldest when the cap is reached', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, maxDecisions: 3);
      for (var i = 0; i < 5; i++) {
        await handle.cognitive.apply<int>(command(i));
      }
      expect(handle.decisions, hasLength(3));
      final remainingArgs = handle.decisions
          .map((d) => d.command!.arguments.positionalArguments!.first)
          .toList();
      expect(remainingArgs, [2, 3, 4],
          reason: 'The two oldest decisions were rolled off.');
    });

    test('maxDecisions: 1 keeps exactly the newest decision', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, maxDecisions: 1);
      await handle.cognitive.apply<int>(command(1));
      await handle.cognitive.apply<int>(command(2));
      expect(handle.decisions, hasLength(1));
      expect(
        handle.decisions.single.command!.arguments.positionalArguments!.first,
        2,
      );
    });

    test('below the cap nothing is dropped', () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, maxDecisions: 10);
      await handle.cognitive.apply<int>(command(1));
      await handle.cognitive.apply<int>(command(2));
      expect(handle.decisions, hasLength(2));
    });

    test('truncation is observable through the TissueList removal pulse',
        () async {
      final src = Cell.ingress<int>();
      final handle = cognitive(cell: src.cell, maxDecisions: 2);
      final removals = <Decision>[];
      final sub = Cell.observe(
          source: handle.decisions,
          effect: (Pulse p) {
            if (p.type == Tissue.elementRemoved) {
              removals.add(p.payload as Decision);
            }
          });
      await handle.cognitive.apply<int>(command(1));
      await handle.cognitive.apply<int>(command(2));
      await handle.cognitive.apply<int>(command(3)); // rolls off decision 1
      await Future<void>.delayed(Duration.zero);
      expect(removals, hasLength(1));
      expect(removals.single.command!.arguments.positionalArguments!.first, 1);
      sub.stop();
    });
  });
}
