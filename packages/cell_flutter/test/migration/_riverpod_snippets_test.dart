// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Every Mitosis snippet from guide/MigratingFrom-Riverpod.md appears here
// as a compiling, runnable test. When the guide changes, this file
// changes. A guide whose snippets do not compile is broken.

import 'dart:async';

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MigratingFrom-Riverpod.md — Section 3 (state primitives)', () {
    testWidgets('StateProvider → Cell.state', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellBuilder<int>(
              cell: counter.cell.unmodifiable,
              builder: (_, count) => Text('${count ?? 0}'),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      counter.update(5);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    test('Notifier → Cell.state with testRule', () {
      final counter = Cell.state<int>(
        initial: 0,
        testRule: TestCell((object, {host, arguments, user}) {
          if (object is! Pulse) return true; // links/actions pass
          final payload = object.payload;
          return payload is int && payload >= 0;
        }),
      );
      expect(counter.update(5), isTrue);
      expect(counter.cell.value, 5);
      expect(counter.update(-1), isFalse); // rejected by testRule
      expect(counter.cell.value, 5);
    });
  });

  group('MigratingFrom-Riverpod.md — Section 4 (derived state)', () {
    test('Provider → Cell.derive', () {
      final base = Cell.state<int>(initial: 1);
      final doubled = Cell.derive<Pulse<int>, Pulse<int>>(
        source: base.cell,
        project: (p) => Pulse<int>((p.payload ?? 0) * 2),
      );
      final recorder = doubled.recordPulses();
      addTearDown(recorder.stop);
      base.update(5);
      expect(recorder.payloads, [10]);
    });

    testWidgets('derived Cell requires CellValueBuilder for display', (
      tester,
    ) async {
      final base = Cell.state<int>(initial: 1);
      final doubled = Cell.derive<Pulse<int>, Pulse<int>>(
        source: base.cell,
        project: (p) => Pulse<int>((p.payload ?? 0) * 2),
      );

      // CellValueBuilder accepts any Cell; CellBuilder requires ValueCell.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellValueBuilder<int>(
              cell: doubled, // Cell, not ValueCell
              initial: 2,
              builder: (_, total) => Text('$total'),
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    test('Provider → Cell.synthesis', () {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final sum = Cell.synthesis<Pulse<int>>(
        [a.cell, b.cell],
        aggregator: (cells, _) => Pulse<int>(
          cells.fold<int>(
            0,
            (acc, c) => acc + (((c as ValueCell<int>).value) ?? 0),
          ),
        ),
      );
      final recorder = sum.recordPulses();
      addTearDown(recorder.stop);
      a.update(10);
      expect(recorder.payloads.last, 12);
    });
  });

  group('MigratingFrom-Riverpod.md — Section 5 (async)', () {
    test('FutureProvider → Cell.fromFuture emits error pulse', () async {
      final user = Cell.fromFuture<String>(
        Future<String>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      final recorder = user.recordPulses();
      addTearDown(recorder.stop);
      await Future<void>.delayed(Duration.zero);
      final errors = recorder.pulses.where((p) => p.type == 'error');
      expect(errors, hasLength(1));
    });

    test(
      'StreamProvider → Cell.fromStream does NOT emit error pulse',
      () async {
        final ticks = Cell.fromStream<int>(
          Stream<int>.error(StateError('boom')),
          journal: RecordingJournal(),
        );
        final recorder = ticks.recordPulses();
        addTearDown(recorder.stop);
        await Future<void>.delayed(Duration.zero);
        final errors = recorder.pulses.where((p) => p.type == 'error');
        expect(
          errors,
          isEmpty,
          reason: 'fromStream does not emit error pulses today',
        );
      },
    );

    testWidgets('AsyncValue → AsyncSnapshot via CellAsyncBuilder', (
      tester,
    ) async {
      final completer = Completer<String>();
      final user = Cell.fromFuture<String>(
        completer.future,
        journal: RecordingJournal(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellAsyncBuilder<String>(
              cell: user,
              builder: (_, snapshot) => snapshot.hasError
                  ? ErrorView(snapshot.error!)
                  : snapshot.hasData
                  ? Text('user: ${snapshot.data}')
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byType(ErrorView), findsNothing);
      completer.complete('ada');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('user: ada'), findsOneWidget);
    });
  });

  group('MigratingFrom-Riverpod.md — Section 6 (widgets)', () {
    testWidgets('ref.listen → CellListener branches on error type', (
      tester,
    ) async {
      final auth = Cell.state<int?>(initial: null);
      Object? seenError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellListener<int?>(
              cell: auth.cell,
              onPulse: (context, pulse) {
                if (pulse.type == 'error') {
                  seenError = pulse.payload;
                  return;
                }
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      auth.cell.value = 42;
      await tester.pump();
      expect(seenError, isNull);
    });
  });

  group('MigratingFrom-Riverpod.md — Section 7 (DI)', () {
    testWidgets('ProviderScope → CellScope', (tester) async {
      final auth = Cell.state<String?>(initial: null);

      await tester.pumpWidget(
        CellScope(
          cells: {#auth: auth.cell},
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Deep in the tree:
                  final cell = CellScope.valueOf<String?>(context, #auth);
                  return Text('${cell.value}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });
  });

  group('MigratingFrom-Riverpod.md — Section 8 (testing)', () {
    testWidgets('overrideWithValue → pumpWithCells', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      await tester.pumpWithCells(
        cells: {#counter: counter.cell},
        child: CellBuilder<int>(
          cell: counter.cell,
          builder: (_, v) => Text('$v'),
        ),
      );
      expect(find.text('42'), findsOneWidget);
    });
  });
}

/// Minimal error surface for the async snippet.
class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => Text('error: $error');
}
