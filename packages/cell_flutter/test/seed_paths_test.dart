// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Permanent regression guard for C1 (the late-subscriber seed bug).
//
// `retainedPulseOf` must serve every state-like operator (`fromFuture`,
// `fromStream`, `asyncMap`, `derive`) whose latest pulse the core package
// retains via `Cell.latestPulse`, not only `ValueCell`. Before the fix,
// all twelve tests below except the two "before completion" cases failed:
// a source that emitted before the consumer subscribed rendered `initial`
// / `nothing()` / no event forever.
//
// The widget docs that mention seed semantics (`CellValueBuilder`,
// `CellAsyncBuilder`, `CellAsValue`, `CellAsStream`, `pulse_delivery`)
// reference this file as the authoritative statement of seed behavior.

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Advances the fake clock and drains microtasks inside `testWidgets`.
///
/// Async operators (`fromFuture`, `asyncMap`) settle their emissions in
/// microtasks and zero-duration timers, which the widget-tester's fake
/// clock only fires when it is explicitly pumped.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('CellValueBuilder seeds from retained pulses', () {
    testWidgets('1. fromFuture subscribed after completion renders 42',
        (tester) async {
      final source = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      await _settle(tester);

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: source,
          builder: (_, v) => Text(v?.toString() ?? 'loading'),
        ),
      ));

      expect(find.text('42'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets(
        '2. fromFuture subscribed before completion shows initial '
        'then 42', (tester) async {
      final completer = Completer<int>();
      final source = Cell.fromFuture<int>(
        completer.future,
        journal: RecordingJournal(),
      );

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: source,
          builder: (_, v) => Text(v?.toString() ?? 'loading'),
        ),
      ));
      expect(find.text('loading'), findsOneWidget);

      completer.complete(42);
      await _settle(tester);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets(
        '3. derive subscribed after emission renders the derived '
        'value', (tester) async {
      final src = Cell.ingress<int>();
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: src.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );
      src.emit(7);
      await _settle(tester);

      await tester.pumpWidget(_wrap(
        CellValueBuilder<String>(
          cell: derived,
          builder: (_, v) => Text(v?.toString() ?? 'loading'),
        ),
      ));

      expect(find.text('v7'), findsOneWidget);
    });

    testWidgets(
        '4. asyncMap subscribed after emission renders the mapped '
        'value', (tester) async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) async => value * 2,
        journal: RecordingJournal(),
      );
      src.emit(21);
      await _settle(tester);

      await tester.pumpWidget(_wrap(
        CellValueBuilder<int>(
          cell: mapped,
          builder: (_, v) => Text(v?.toString() ?? 'loading'),
        ),
      ));

      expect(find.text('42'), findsOneWidget);
    });
  });

  group('CellAsyncBuilder seeds from retained pulses', () {
    testWidgets('5. fromFuture subscribed after completion has data 42',
        (tester) async {
      final source = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      await _settle(tester);

      await tester.pumpWidget(_wrap(
        CellAsyncBuilder<int>(
          cell: source,
          builder: (_, snapshot) => Text(
            '${snapshot.hasData} ${snapshot.hasError} '
            '${snapshot.data}',
          ),
        ),
      ));

      expect(find.text('true false 42'), findsOneWidget);
    });

    testWidgets(
        '6. fromFuture subscribed before completion shows nothing '
        'then data', (tester) async {
      final completer = Completer<int>();
      final source = Cell.fromFuture<int>(
        completer.future,
        journal: RecordingJournal(),
      );

      await tester.pumpWidget(_wrap(
        CellAsyncBuilder<int>(
          cell: source,
          builder: (_, snapshot) => Text(
            '${snapshot.hasData} ${snapshot.hasError}',
          ),
        ),
      ));
      expect(find.text('false false'), findsOneWidget);

      completer.complete(42);
      await _settle(tester);
      expect(find.text('true false'), findsOneWidget);
    });

    testWidgets('7. fromStream subscribed after one value has data',
        (tester) async {
      final controller = StreamController<int>();
      final source = Cell.fromStream<int>(
        controller.stream,
        journal: RecordingJournal(),
      );
      // Deliver the value like a live stream: an async controller event
      // plus an explicit pump (matching the replay-probe fuzz pattern).
      controller.add(1);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(_wrap(
        CellAsyncBuilder<int>(
          cell: source,
          builder: (_, snapshot) => Text(
            '${snapshot.hasData} ${snapshot.hasError} '
            '${snapshot.data}',
          ),
        ),
      ));

      expect(find.text('true false 1'), findsOneWidget);
      await controller.close();
      await tester.pump();
    });

    testWidgets('8. asyncMap subscribed after one value has data',
        (tester) async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) async => value * 2,
        journal: RecordingJournal(),
      );
      src.emit(21);
      await _settle(tester);

      await tester.pumpWidget(_wrap(
        CellAsyncBuilder<int>(
          cell: mapped,
          builder: (_, snapshot) => Text(
            '${snapshot.hasData} ${snapshot.hasError} '
            '${snapshot.data}',
          ),
        ),
      ));

      expect(find.text('true false 42'), findsOneWidget);
    });
  });

  group('asValueCell seeds from retained pulses', () {
    test('9. derive subscribed after emission mirrors the derived value',
        () async {
      final src = Cell.ingress<int>();
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: src.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );
      src.emit(7);
      await pumpEventQueue();

      final mirror = derived.asValueCell<String>();
      addTearDown(mirror.dispose);

      expect(mirror.cell.value, 'v7');
    });

    test('10. fromFuture subscribed after completion mirrors 42', () async {
      final source = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      await pumpEventQueue();

      final mirror = source.asValueCell<int>();
      addTearDown(mirror.dispose);

      expect(mirror.cell.value, 42);
    });
  });

  group('asStream seeds from retained pulses', () {
    test(
        '11. derive subscribed after emission emits the derived value '
        'first', () async {
      final src = Cell.ingress<int>();
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: src.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );
      src.emit(7);
      await pumpEventQueue();

      final received = <String?>[];
      final sub = derived.asStream<String>().listen(received.add);
      await pumpEventQueue();

      expect(received, ['v7']);
      await sub.cancel();
    });

    test('12. fromFuture subscribed after completion emits 42 first', () async {
      final source = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      await pumpEventQueue();

      final received = <int?>[];
      final sub = source.asStream<int>().listen(received.add);
      await pumpEventQueue();

      expect(received, [42]);
      await sub.cancel();
    });
  });
}
