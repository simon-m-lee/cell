// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useCellAsync', () {
    testWidgets('nothing before first pulse', (tester) async {
      final cell = Cell.ingress<int>().cell;
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(cell);
        return const SizedBox.shrink();
      }));
      expect(captured!.connectionState, ConnectionState.none);
      expect(captured!.hasData, false);
    });

    testWidgets('seeds from a ValueCell current value', (tester) async {
      // Parity with CellAsyncBuilder: snapshotForCell serves a ValueCell's
      // current value on the first frame.
      final counter = Cell.state<int>(initial: 7);
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(counter.cell);
        return const SizedBox.shrink();
      }));
      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasData, true);
      expect(captured!.data, 7);
    });

    testWidgets('seeds from a completed fromFuture', (tester) async {
      // Parity with CellAsyncBuilder: snapshotForCell serves the retained
      // pulse of a plain async cell on the first frame.
      final source = Cell.fromFuture<int>(
        Future<int>.value(42),
        journal: RecordingJournal(),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(source);
        return const SizedBox.shrink();
      }));

      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasData, true);
      expect(captured!.data, 42);
    });

    testWidgets('seeds from a fromStream after one value',
        (tester) async {
      final controller = StreamController<int>();
      final source = Cell.fromStream<int>(
        controller.stream,
        journal: RecordingJournal(),
      );
      controller.add(7);
      await tester.pump(const Duration(milliseconds: 50));

      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(source);
        return const SizedBox.shrink();
      }));

      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasData, true);
      expect(captured!.data, 7);
      await controller.close();
      await tester.pump();
    });

    testWidgets('seeds from an asyncMap after one value',
        (tester) async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(
        src.cell,
        (value, {required journal}) async => value * 2,
        journal: RecordingJournal(),
      );
      src.emit(21);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(mapped);
        return const SizedBox.shrink();
      }));

      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasData, true);
      expect(captured!.data, 42);
    });

    testWidgets('seeds from a derive after one emission',
        (tester) async {
      final src = Cell.ingress<int>();
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: src.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );
      src.emit(7);
      await tester.pump();

      AsyncSnapshot<String>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<String>(derived);
        return const SizedBox.shrink();
      }));

      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasData, true);
      expect(captured!.data, 'v7');
    });

    testWidgets('active+data after pulse', (tester) async {
      final ingress = Cell.ingress<int>();
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(ingress.cell);
        return const SizedBox.shrink();
      }));
      ingress.emit(42);
      await tester.pump();
      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.data, 42);
    });

    testWidgets('active+error after error pulse', (tester) async {
      final ingress = Cell.ingress<Object>();
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(ingress.cell);
        return const SizedBox.shrink();
      }));
      await ingress.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();
      expect(captured!.hasError, true);
      expect(captured!.error, isStateError);
    });

    testWidgets('nullable V accepts a null payload as data', (tester) async {
      final ingress = Cell.ingress<int?>();
      AsyncSnapshot<int?>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int?>(ingress.cell);
        return const SizedBox.shrink();
      }));

      ingress.emit(null);
      await tester.pump();

      expect(captured!.connectionState, ConnectionState.active);
      expect(captured!.hasError, false);
      expect(captured!.data, isNull);
    });

    testWidgets('type mismatch becomes an error snapshot', (tester) async {
      final ingress = Cell.ingress<Object>();
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(ingress.cell);
        return const SizedBox.shrink();
      }));

      ingress.emit('not-an-int');
      await tester.pump();

      expect(captured!.hasError, true);
      expect(captured!.error, isA<StateError>());
    });

    testWidgets('initialSnapshot seeds', (tester) async {
      final cell = Cell.ingress<int>().cell;
      AsyncSnapshot<int>? captured;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        captured = useCellAsync<int>(
          cell,
          initialSnapshot: const AsyncSnapshot<int>.withData(
            ConnectionState.active,
            7,
          ),
        );
        return const SizedBox.shrink();
      }));
      expect(captured!.data, 7);
    });

    testWidgets('cell swap rebinds', (tester) async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final source = ValueNotifier<Cell>(a.cell);
      addTearDown(source.dispose);
      AsyncSnapshot<int>? captured;

      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(source); // rebuild when the source swaps
        captured = useCellAsync<int>(source.value);
        return const SizedBox.shrink();
      }));
      expect(captured!.connectionState, ConnectionState.none);

      source.value = b.cell;
      await tester.pump();
      b.emit(42);
      await tester.pump();
      expect(captured!.data, 42);

      a.emit(99);
      await tester.pump();
      expect(captured!.data, 42, reason: 'old cell should not affect');
    });

    testWidgets('snapshot persists across cell swap (documented divergence)',
        (tester) async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final source = ValueNotifier<Cell>(a.cell);
      addTearDown(source.dispose);
      AsyncSnapshot<int>? captured;

      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(source); // rebuild when the source swaps
        captured = useCellAsync<int>(source.value);
        return const SizedBox.shrink();
      }));

      a.emit(1);
      await tester.pump();
      expect(captured!.data, 1);

      source.value = b.cell;
      await tester.pump();
      // Snapshot persists (documented divergence from CellAsyncBuilder).
      // To reset, key the HookWidget on the cell.
      expect(captured!.data, 1, reason: 'snapshot does not reset on cell swap');
    });
  });
}
