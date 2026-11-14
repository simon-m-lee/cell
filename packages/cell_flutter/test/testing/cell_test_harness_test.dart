// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellTestHarness', () {
    late CellTestHarness harness;

    setUp(() {
      harness = CellTestHarness()
        ..add(#counter, Cell.state<int>(initial: 0).cell)
        ..add(#auth, Cell.state<String?>(initial: null).cell);
    });

    tearDown(() => harness.dispose());

    testWidgets('cell() returns typed cell', (tester) async {
      final c = harness.cell<int>(#counter);
      expect(c, isA<ValueCell<int>>());
    });

    testWidgets('cell() throws on wrong type', (tester) async {
      expect(
        () => harness.cell<String>(#counter),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('cell() for missing id throws', (tester) async {
      expect(
        () => harness.cell<int>(#missing),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('valueCell() returns typed ValueCell', (tester) async {
      final c = harness.valueCell<int>(#counter);
      expect(c.value, 0);
    });

    testWidgets('valueCell() for missing id throws', (tester) async {
      expect(
        () => harness.valueCell<int>(#missing),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('valueCell() throws for non-ValueCell registration',
        (tester) async {
      final src = Cell.ingress<int>();
      harness.add(#src, src.cell);
      expect(
        () => harness.valueCell<int>(#src),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('pump() registers all cells in CellScope', (tester) async {
      await harness.pump(
        tester: tester,
        child: Builder(builder: (ctx) {
          final c = CellScope.valueOf<int>(ctx, #counter);
          final a = CellScope.valueOf<String?>(ctx, #auth);
          return Text('${c.value},${a.value}');
        }),
      );
      expect(find.text('0,null'), findsOneWidget);
    });

    testWidgets('emitAndSettle() updates cell', (tester) async {
      await harness.pump(
        tester: tester,
        child: CellBuilder<int>(
          cell: harness.valueCell<int>(#counter),
          builder: (_, v) => Text('$v'),
        ),
      );
      await harness.emitAndSettle(tester, #counter, 5);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('dispose() stops recorders', (tester) async {
      final counter = harness.valueCell<int>(#counter);
      final recorder = harness.recordPulses(#counter);
      counter.value = 1;
      expect(recorder.payloads, [1]);

      harness.dispose();

      // The cell is still alive (harness does not own it); the recorder is
      // stopped. Emitting further should not record.
      counter.value = 2;
      expect(recorder.payloads, [1]);
    });

    testWidgets('dispose() is idempotent', (tester) async {
      harness.dispose();
      expect(harness.dispose, returnsNormally);
    });

    testWidgets('add() after dispose throws', (tester) async {
      harness.dispose();
      expect(
        () => harness.add(#x, Cell.state<int>(initial: 0).cell),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('pump() after dispose throws', (tester) async {
      harness.dispose();
      expect(
        () => harness.pump(tester: tester, child: const SizedBox.shrink()),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('recordPulses() for missing id throws', (tester) async {
      expect(
        () => harness.recordPulses(#missing),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('recordPulses() after dispose throws', (tester) async {
      harness.dispose();
      expect(
        () => harness.recordPulses(#counter),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('cells getter returns the registered cells', (tester) async {
      final cells = harness.cells;
      expect(cells.length, 2);
      expect(cells[#counter], harness.valueCell<int>(#counter));
      expect(() => cells[#other] = cells[#counter]!, throwsUnsupportedError);
    });
  });
}
