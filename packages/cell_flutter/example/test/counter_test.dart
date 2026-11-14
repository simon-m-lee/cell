// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CounterApp', () {
    late CellTestHarness harness;

    setUp(() {
      harness = CellTestHarness()
        ..add(#counter, Cell.state<int>(initial: 0).cell);
    });

    tearDown(() => harness.dispose());

    testWidgets('displays initial value and increments on tap', (tester) async {
      final counter = harness.valueCell<int>(#counter);

      await harness.pump(
        tester: tester,
        child: Column(
          children: [
            CellBuilder<int>(
              cell: counter,
              builder: (_, v) => Text('value: $v'),
            ),
            FloatingActionButton(
              onPressed: () => counter.value = (counter.value ?? 0) + 1,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      );

      expect(find.text('value: 0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('value: 1'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('value: 2'), findsOneWidget);
    });

    testWidgets('records pulse sequence', (tester) async {
      final recorder = harness.recordPulses(#counter);

      await harness.pump(
        tester: tester,
        child: CellBuilder<int>(
          cell: harness.valueCell<int>(#counter),
          builder: (context, value) => const SizedBox.shrink(),
        ),
      );

      await harness.emitAndSettle(tester, #counter, 1);
      await harness.emitAndSettle(tester, #counter, 2);
      await harness.emitAndSettle(tester, #counter, 3);

      expect(recorder.payloads, [1, 2, 3]);
    });
  });
}
