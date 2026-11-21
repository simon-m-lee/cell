// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The in-app Cell Inspector (registry + overlay).

import 'package:cell_flutter/cell_flutter.dart';
// The dedicated entry point; the barrel re-export goes away in 2.0.
// ignore: unnecessary_import
import 'package:cell_flutter/devtools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CellFlutterDevTools.resetForTesting);

  group('CellFlutterDevTools registry', () {
    test('enable() is idempotent', () {
      expect(CellFlutterDevTools.enabled, isFalse);
      CellFlutterDevTools.enable();
      expect(CellFlutterDevTools.enabled, isTrue);
      CellFlutterDevTools.enable();
      expect(CellFlutterDevTools.enabled, isTrue);
    });

    test('register before enable throws StateError', () {
      final counter = Cell.state<int>(initial: 0);
      expect(
        () => CellFlutterDevTools.register('counter', counter.cell),
        throwsStateError,
      );
    });

    test('registry before enable throws StateError', () {
      expect(
        () => CellFlutterDevTools.registry,
        throwsStateError,
      );
    });

    test('registers and exposes an entry with value and type', () {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 5);
      final entry = CellFlutterDevTools.register('counter', counter.cell);

      expect(CellFlutterDevTools.registry.entries['counter'], same(entry));
      expect(entry.value, '5');
      expect(entry.cell, same(counter.cell));
      expect(entry.pulseCount, 0);
      expect(entry.disposed, isFalse);
    });

    test('duplicate symbol throws StateError', () {
      CellFlutterDevTools.enable();
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      CellFlutterDevTools.register('counter', a.cell);
      expect(
        () => CellFlutterDevTools.register('counter', b.cell),
        throwsStateError,
      );
    });

    test('records pulses newest-first with a cap of 10', () {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 0);
      final entry = CellFlutterDevTools.register('counter', counter.cell);

      for (var i = 1; i <= 12; i++) {
        counter.update(i);
      }

      expect(entry.pulseCount, 12);
      expect(entry.pulses.length, CellRegistryEntry.maxRecordedPulses);
      expect(entry.pulses.first.payload, '12');
      expect(entry.pulses.last.payload, '3');
      expect(entry.pulses.first.type, contains('data'));
    });

    test('unregister releases the observation link', () {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 0);
      final entry = CellFlutterDevTools.register('counter', counter.cell);

      CellFlutterDevTools.unregister('counter');
      expect(entry.disposed, isTrue);
      expect(CellFlutterDevTools.registry.entries, isEmpty);

      // Unregistering an unknown symbol is a no-op.
      CellFlutterDevTools.unregister('nope');
    });

    test('clear releases every link but never disposes cells', () {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 0);
      final entry = CellFlutterDevTools.register('counter', counter.cell);

      CellFlutterDevTools.clear();
      expect(entry.disposed, isTrue);
      expect(CellFlutterDevTools.registry.entries, isEmpty);

      // The cell is still alive and usable.
      counter.update(42);
      expect(counter.cell.value, 42);
    });

    test('registry notifies on register, pulse, and clear', () {
      CellFlutterDevTools.enable();
      var notifications = 0;
      CellFlutterDevTools.registry.addListener(() => notifications++);
      final counter = Cell.state<int>(initial: 0);

      CellFlutterDevTools.register('counter', counter.cell);
      counter.update(1);
      CellFlutterDevTools.clear();

      expect(notifications, 3);
    });

    test('entry values survive broken toString and truncate long values', () {
      CellFlutterDevTools.enable();

      final broken = Cell.state<Object>(initial: _BrokenToString());
      final brokenEntry = CellFlutterDevTools.register('broken', broken.cell);
      expect(brokenEntry.value, contains('unprintable'));

      final long = Cell.state<String>(initial: 'x' * 150);
      final longEntry = CellFlutterDevTools.register('long', long.cell);
      expect(longEntry.value.length, 121); // 120 chars + ellipsis
      expect(longEntry.value, endsWith('…'));
    });
  });

  group('CellInspectorOverlay', () {
    Widget app(Widget child) =>
        MaterialApp(home: CellInspectorOverlay(child: child));

    testWidgets('renders the child unchanged when disabled', (tester) async {
      await tester.pumpWidget(app(const Text('hello')));
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('shows the floating button when enabled', (tester) async {
      CellFlutterDevTools.enable();
      await tester.pumpWidget(app(const Text('hello')));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Cell Inspector'), findsNothing);
    });

    testWidgets('lists registered cells and expands pulse history',
        (tester) async {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 3);
      CellFlutterDevTools.register('counter', counter.cell);

      await tester.pumpWidget(app(const Text('hello')));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(find.text('Cell Inspector'), findsOneWidget);
      expect(find.text('counter'), findsOneWidget);
      expect(find.textContaining('pulses: 0'), findsOneWidget);

      // Empty journal expands to the placeholder.
      await tester.tap(find.text('counter'));
      await tester.pump();
      expect(find.text('— no pulses yet —'), findsOneWidget);

      counter.update(7);
      await tester.pump();
      expect(find.textContaining('pulses: 1'), findsOneWidget);
      expect(find.textContaining('7'), findsWidgets);
      expect(find.text('Pulse history (newest first):'), findsOneWidget);
      expect(find.textContaining('[data]'), findsOneWidget);
    });

    testWidgets('wraps a whole MaterialApp (no Directionality above)',
        (tester) async {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 1);
      CellFlutterDevTools.register('counter', counter.cell);

      await tester.pumpWidget(const CellInspectorOverlay(
        child: MaterialApp(home: Scaffold(body: Text('hello'))),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(find.text('Cell Inspector'), findsOneWidget);
      expect(find.text('counter'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('clear empties the panel and close hides it', (tester) async {
      CellFlutterDevTools.enable();
      final counter = Cell.state<int>(initial: 0);
      CellFlutterDevTools.register('counter', counter.cell);

      await tester.pumpWidget(app(const Text('hello')));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(find.text('counter'), findsOneWidget);

      await tester.tap(find.text('clear'));
      await tester.pump();
      expect(find.textContaining('No cells registered'), findsOneWidget);
      expect(find.text('counter'), findsNothing);

      await tester.tap(find.text('close'));
      await tester.pump();
      expect(find.text('Cell Inspector'), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('panel shows non-value cells as null', (tester) async {
      CellFlutterDevTools.enable();
      CellFlutterDevTools.register('ingress', Cell.ingress<int>().cell);

      await tester.pumpWidget(app(const Text('hello')));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(find.textContaining('null'), findsOneWidget);
    });
  });
}

class _BrokenToString {
  @override
  String toString() => throw StateError('broken toString');
}
