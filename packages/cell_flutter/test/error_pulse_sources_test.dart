// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Permanent regression guard for C2 (the error-pulse contradiction).
//
// These tests are the authoritative statement of per-source error-pulse
// behavior. Every doc in `lib/` that mentions error-pulse sources must
// agree with the behavior asserted here. If a future change to `cell`
// alters error-pulse emission, this file fails and every doc referencing
// it must be updated.
//
// Ground truth (verified against the core package source):
// - `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on failure,
//   and retains it for late subscribers.
// - `Cell.fromStream` never emits an error pulse: a stream error only
//   cancels the subscription when `cancelOnError: true`.
// - `Cell.asyncMap` never emits an error pulse on its output cell: a
//   mapper failure fails the *source* pulse ("no emission" contract).

import 'dart:async';

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('fromFuture', () {
    test('emits an error pulse on future failure', () async {
      final cell = Cell.fromFuture<int>(
        Future<int>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      await pumpEventQueue();

      final latest = Cell.latestPulse(cell);
      expect(latest, isNotNull);
      expect(latest!.type, 'error');
      expect(latest.payload, isA<StateError>());
    });

    test('emits a data pulse on future success', () async {
      final cell = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      await pumpEventQueue();

      final latest = Cell.latestPulse(cell);
      expect(latest, isNotNull);
      expect(latest!.type, isNot('error'));
      expect(latest.payload, 42);
    });
  });

  group('fromStream', () {
    test('does not emit an error pulse on stream error '
        '(cancelOnError: false)', () async {
      final cell = Cell.fromStream<int>(
        Stream<int>.error(StateError('boom')),
        journal: RecordingJournal(),
        cancelOnError: false,
      );
      await pumpEventQueue();

      // The error only decided whether to cancel; nothing was emitted.
      expect(Cell.latestPulse(cell), isNull);
    });

    test('does not emit an error pulse on stream error '
        '(cancelOnError: true)', () async {
      final cell = Cell.fromStream<int>(
        Stream<int>.error(StateError('boom')),
        journal: RecordingJournal(),
        cancelOnError: true,
      );
      await pumpEventQueue();

      expect(Cell.latestPulse(cell), isNull);
    });

    test('retains the last data pulse emitted before a stream error', () async {
      final controller = StreamController<int>(sync: true);
      final cell = Cell.fromStream<int>(
        controller.stream,
        journal: RecordingJournal(),
      );
      controller.add(7);
      await pumpEventQueue();

      final latest = Cell.latestPulse(cell);
      expect(latest, isNotNull);
      expect(latest!.payload, 7);
      await controller.close();
    });
  });

  group('asyncMap', () {
    test('does not emit an error pulse when the mapper throws', () async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) async => throw StateError('boom'),
        journal: RecordingJournal(),
      );
      src.emit(1);
      await pumpEventQueue();

      // Mapper failures fail the source pulse; the output cell never emits.
      expect(Cell.latestPulse(mapped), isNull);
    });

    test('does not emit an error pulse when the mapper returns '
        'Future.error', () async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) => Future<int>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      src.emit(1);
      await pumpEventQueue();

      expect(Cell.latestPulse(mapped), isNull);
    });

    test(
      'retains the last mapped result emitted before a later failure',
      () async {
        final src = Cell.ingress<int>();
        var fail = false;
        final mapped = Cell.asyncMap<int, int>(src.cell, (
          value, {
          required journal,
        }) async {
          if (fail) throw StateError('boom');
          return value * 2;
        }, journal: RecordingJournal());

        src.emit(21);
        await pumpEventQueue();
        expect(Cell.latestPulse(mapped)?.payload, 42);

        fail = true;
        src.emit(22);
        await pumpEventQueue();
        // The failed mapper must not clobber the retained result.
        expect(Cell.latestPulse(mapped)?.payload, 42);
      },
    );
  });

  group('recordPulses', () {
    test('captures the error pulse from a failed fromFuture', () async {
      final cell = Cell.fromFuture<int>(
        Future<int>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      final recorder = cell.recordPulses();
      addTearDown(recorder.stop);

      await pumpEventQueue();

      final errorPulses = recorder.pulses.where((p) => p.type == 'error');
      expect(errorPulses, hasLength(1));
      expect(errorPulses.first.payload, isA<StateError>());
    });

    test('observes no error pulse from a failing asyncMap', () async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) async => throw StateError('boom'),
        journal: RecordingJournal(),
      );
      final recorder = mapped.recordPulses();
      addTearDown(recorder.stop);

      src.emit(1);
      await pumpEventQueue();

      expect(recorder.pulses, isEmpty);
    });

    test('observes no error pulse from a failing fromStream', () async {
      final cell = Cell.fromStream<int>(
        Stream<int>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      final recorder = cell.recordPulses();
      addTearDown(recorder.stop);

      await pumpEventQueue();

      expect(recorder.pulses, isEmpty);
    });
  });

  group('CellAsyncBuilder error seeding (C1 x C2)', () {
    testWidgets('a completed failed fromFuture seeds an error snapshot', (
      tester,
    ) async {
      final cell = Cell.fromFuture<int>(
        Future<int>.error(StateError('boom')),
        journal: RecordingJournal(),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: cell,
            builder: (_, snapshot) =>
                Text('${snapshot.hasData} ${snapshot.hasError}'),
          ),
        ),
      );

      // The retained error pulse seeds the first frame as hasError.
      expect(find.text('false true'), findsOneWidget);
    });
  });
}
