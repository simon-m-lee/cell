// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

class _Host extends StatefulWidget {
  const _Host({
    required this.cell,
    required this.initialSnapshot,
    this.emitOnBuild,
  });

  final Cell cell;
  final AsyncSnapshot<int>? initialSnapshot;

  /// Invoked from `build` — lets a test emit a pulse mid-frame.
  final void Function()? emitOnBuild;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    widget.emitOnBuild?.call();
    return CellAsyncBuilder<int>(
      cell: widget.cell,
      initialSnapshot: widget.initialSnapshot,
      builder: (_, snapshot) => Text(
        snapshot.hasError
            ? 'error'
            : snapshot.hasData
            ? 'data:${snapshot.data}'
            : 'state:${snapshot.connectionState}',
      ),
    );
  }
}

void main() {
  group('CellAsyncBuilder', () {
    testWidgets('nothing before first pulse', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: src.cell,
            builder: (_, snapshot) => Text(
              '${snapshot.connectionState} '
              '${snapshot.hasData} ${snapshot.hasError}',
            ),
          ),
        ),
      );

      expect(find.text('${ConnectionState.none} false false'), findsOneWidget);
    });

    testWidgets('active + data after first data pulse', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: src.cell,
            builder: (_, snapshot) =>
                Text(snapshot.hasData ? 'data:${snapshot.data}' : 'none'),
          ),
        ),
      );

      expect(find.text('none'), findsOneWidget);

      src.emit(42);
      await tester.pump();

      expect(find.text('data:42'), findsOneWidget);
    });

    testWidgets('active + error after error pulse', (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<Object>(
            cell: src.cell,
            builder: (_, snapshot) => Text(snapshot.hasError ? 'error' : 'ok'),
          ),
        ),
      );

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('initialSnapshot seeds first frame', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: src.cell,
            initialSnapshot: const AsyncSnapshot<int>.withData(
              ConnectionState.active,
              7,
            ),
            builder: (_, snapshot) => Text('data:${snapshot.data}'),
          ),
        ),
      );

      expect(find.text('data:7'), findsOneWidget);

      src.emit(8);
      await tester.pump();
      expect(find.text('data:8'), findsOneWidget);
    });

    testWidgets('type mismatch becomes an error snapshot', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<String>(
            cell: src.cell,
            builder: (_, snapshot) => Text(snapshot.hasError ? 'error' : 'ok'),
          ),
        ),
      );

      src.emit(42);
      await tester.pump();

      expect(find.text('error'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'mismatch is a snapshot error, not a thrown exception',
      );
    });

    testWidgets('nullable V accepts a null payload as data', (tester) async {
      final src = Cell.ingress<int?>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int?>(
            cell: src.cell,
            builder: (_, snapshot) => Text(
              // Flutter defines `hasData` as `data != null`; for a nullable V,
              // distinguish "received a null payload" via connectionState.
              snapshot.connectionState == ConnectionState.none
                  ? 'none'
                  : snapshot.hasError
                  ? 'error'
                  : 'data:${snapshot.data}',
            ),
          ),
        ),
      );

      src.emit(1);
      await tester.pump();
      expect(find.text('data:1'), findsOneWidget);

      src.emit(null);
      await tester.pump();
      expect(find.text('data:null'), findsOneWidget);
    });

    testWidgets('error pulse with null payload uses a placeholder error', (
      tester,
    ) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<Object>(
            cell: src.cell,
            builder: (_, snapshot) => Text(
              snapshot.hasError ? '${snapshot.error.runtimeType}' : 'ok',
            ),
          ),
        ),
      );

      await src.ingest(Pulse<Object>(null, type: 'error'));
      await tester.pump();

      expect(find.text('StateError'), findsOneWidget);
    });

    testWidgets('cell swap resets to nothing and rebinds', (tester) async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(_Host(cell: a.cell, initialSnapshot: null)),
      );
      expect(find.text('state:${ConnectionState.none}'), findsOneWidget);

      a.emit(1);
      await tester.pump();
      expect(find.text('data:1'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(_Host(cell: b.cell, initialSnapshot: null)),
      );
      expect(find.text('state:${ConnectionState.none}'), findsOneWidget);

      a.emit(10); // old cell — ignored
      await tester.pump();
      expect(find.text('state:${ConnectionState.none}'), findsOneWidget);

      b.emit(2); // new cell — observed
      await tester.pump();
      expect(find.text('data:2'), findsOneWidget);
    });

    testWidgets('renders fromFuture success as data', (tester) async {
      // Complete the future only after the widget subscribed: a
      // `Future.value`-style cell emits in the first microtask flush, which
      // happens before the first frame builds — the documented ordering
      // caveat (see `initialSnapshot`).
      final completer = Completer<int>();
      final future = Cell.fromFuture<int>(
        completer.future,
        journal: RecordingJournal(),
      );

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: future,
            builder: (_, snapshot) =>
                Text(snapshot.hasData ? 'data:${snapshot.data}' : 'waiting'),
          ),
        ),
      );

      expect(find.text('waiting'), findsOneWidget);

      completer.complete(42);
      await tester.pump(); // future completes; pulse arrives
      await tester.pump(); // snapshot rebuild

      expect(find.text('data:42'), findsOneWidget);
    });

    testWidgets('renders fromFuture failure as error', (tester) async {
      final completer = Completer<Object>();
      final future = Cell.fromFuture<Object>(
        completer.future,
        journal: RecordingJournal(),
      );

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<Object>(
            cell: future,
            builder: (_, snapshot) =>
                Text(snapshot.hasError ? 'error' : 'waiting'),
          ),
        ),
      );

      expect(find.text('waiting'), findsOneWidget);

      completer.completeError(StateError('boom'));
      await tester.pump();
      await tester.pump();

      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('asyncMap mapper failure keeps the last successful value', (
      tester,
    ) async {
      final src = Cell.ingress<int>();
      final mapped = Cell.asyncMap<int, int>(src.cell, (
        v, {
        required EffectJournal journal,
      }) async {
        if (v == 2) throw StateError('mapper boom');
        return v * 10;
      }, journal: RecordingJournal());

      await tester.pumpWidget(
        _wrap(
          CellAsyncBuilder<int>(
            cell: mapped,
            builder: (_, snapshot) => Text(
              snapshot.hasError
                  ? 'error'
                  : snapshot.hasData
                  ? 'data:${snapshot.data}'
                  : 'waiting',
            ),
          ),
        ),
      );

      // asyncMap schedules mapper work via `Future(...)` (a zero-delay
      // timer); the test clock must elapse a positive duration.
      src.emit(1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('data:10'), findsOneWidget);

      // asyncMap emits no error pulse for a throwing mapper; the widget
      // keeps the last successful snapshot.
      src.emit(2);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('data:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose stops egress', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(_Host(cell: src.cell, initialSnapshot: null)),
      );

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      // No exceptions from a disposed listener; the snapshot is frozen.
      src.emit(99);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('defers a pulse emitted during build', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(_Host(cell: src.cell, initialSnapshot: null)),
      );
      expect(find.text('state:${ConnectionState.none}'), findsOneWidget);

      // Rebuild the same element; the host emits mid-build. The pulse is
      // queued and applied in the post-frame flush, never via a setState
      // during the build itself.
      await tester.pumpWidget(
        _wrap(
          _Host(
            cell: src.cell,
            initialSnapshot: null,
            emitOnBuild: () => src.emit(99),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('data:99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'drops a pending deferred pulse when disposed before the flush',
      (tester) async {
        final src = Cell.ingress<int>();

        await tester.pumpWidget(
          _wrap(
            _EmitHost(
              child: CellAsyncBuilder<int>(
                cell: src.cell,
                builder: (_, snapshot) => Text('${snapshot.data ?? 'none'}'),
              ),
            ),
          ),
        );

        // The host emits mid-build and unmounts the builder in the same
        // frame. The post-frame flush runs after dispose and must drop the
        // pending pulse silently.
        await tester.pumpWidget(
          _wrap(
            _EmitHost(
              emitOnBuild: () => src.emit(99),
              child: const SizedBox.shrink(),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _EmitHost extends StatefulWidget {
  const _EmitHost({required this.child, this.emitOnBuild});

  final Widget child;

  /// Invoked from `build` — lets a test emit a pulse mid-frame.
  final void Function()? emitOnBuild;

  @override
  State<_EmitHost> createState() => _EmitHostState();
}

class _EmitHostState extends State<_EmitHost> {
  @override
  Widget build(BuildContext context) {
    widget.emitOnBuild?.call();
    return widget.child;
  }
}
