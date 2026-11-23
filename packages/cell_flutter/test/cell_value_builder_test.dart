// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CellValueBuilder', () {
    testWidgets('mirrors Cell.derive output', (tester) async {
      final source = Cell.state<int>(initial: 5);
      final derived = Cell.derive<Pulse<int>, Pulse<String>>(
        source: source.cell,
        project: (pulse) => Pulse<String>('v${pulse.payload}'),
      );

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<String>(
            cell: derived,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      // No pulse yet — derive is not seeded.
      expect(find.text('null'), findsOneWidget);

      source.update(7);
      await tester.pump();

      expect(find.text('v7'), findsOneWidget);
    });

    testWidgets('mirrors Cell.synthesis output', (tester) async {
      final price = Cell.state<int>(initial: 100);
      final tax = Cell.state<int>(initial: 10);
      final total = Cell.synthesis<Pulse<int>>(
        [price.cell, tax.cell],
        aggregator: (cells, _) {
          final sum = cells.fold<int>(0, (acc, c) {
            final v = c is ValueCell<int> ? c.value ?? 0 : 0;
            return acc + v;
          });
          return Pulse<int>(sum);
        },
      );

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: total,
            initial: 110,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      expect(find.text('110'), findsOneWidget);

      tax.update(25);
      await tester.pump();

      expect(find.text('125'), findsOneWidget);
    });

    testWidgets('initial seeds the first frame', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: src.cell,
            initial: 42,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);

      src.emit(9);
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('nullable V mirrors a null payload', (tester) async {
      final src = Cell.ingress<int?>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int?>(
            cell: src.cell,
            initial: 5,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);

      src.emit(null);
      await tester.pump();
      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('error pulse silently skipped by default', (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: src.cell,
            initial: 1,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      src.emit(2);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      // Value unchanged, and no error reported.
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error pulse reported when emitErrors is true', (tester) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: src.cell,
            initial: 1,
            emitErrors: true,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      expect(tester.takeException(), isStateError);
    });

    testWidgets(
      'reports a retained error pulse during seed when emitErrors is true '
      '',
      (tester) async {
        final reported = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = reported.add;

        try {
          // A fromFuture that failed before the widget subscribed: the error
          // pulse sits in the retained slot and the seed path must report it.
          final source = Cell.fromFuture<int>(
            Future<int>.error(StateError('boom')),
            journal: RecordingJournal(),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }

          await tester.pumpWidget(
            _wrap(
              CellValueBuilder<int>(
                cell: source,
                emitErrors: true,
                builder: (_, v) => Text('${v ?? 'loading'}'),
              ),
            ),
          );

          expect(reported, hasLength(1));
          expect(reported.single.exception, isA<StateError>());
          expect(reported.single.exception.toString(), contains('boom'));
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'skips a retained error pulse during seed when emitErrors is false '
      '',
      (tester) async {
        final source = Cell.fromFuture<int>(
          Future<int>.error(StateError('boom')),
          journal: RecordingJournal(),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }

        await tester.pumpWidget(
          _wrap(
            CellValueBuilder<int>(
              cell: source,
              builder: (_, v) => Text('${v ?? 'loading'}'),
            ),
          ),
        );

        // Default emitErrors: false — the retained error is skipped and the
        // widget renders its fallback silently.
        expect(find.text('loading'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('type mismatch reported even when emitErrors is false', (
      tester,
    ) async {
      final src = Cell.ingress<Object>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: src.cell,
            initial: 1,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      src.emit('not-an-int');
      await tester.pump();

      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error, isA<StateError>());
    });

    testWidgets('cell swap resets the mirror', (tester) async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: a.cell,
            initial: 0,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      a.emit(5);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: b.cell,
            initial: 0,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);

      b.emit(6);
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('dispose stops egress', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          CellValueBuilder<int>(
            cell: src.cell,
            initial: 1,
            builder: (_, v) => Text('$v'),
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      src.emit(9);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('defers a pulse emitted during build', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          _EmitHost(
            child: CellValueBuilder<int>(
              cell: src.cell,
              initial: 0,
              builder: (_, v) => Text('$v'),
            ),
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);

      // Rebuild the same element; the host emits mid-build. The pulse is
      // queued and applied in the post-frame flush — no setState during
      // the build itself.
      await tester.pumpWidget(
        _wrap(
          _EmitHost(
            emitOnBuild: () => src.emit(99),
            child: CellValueBuilder<int>(
              cell: src.cell,
              initial: 0,
              builder: (_, v) => Text('$v'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'drops a pending deferred pulse when disposed before the flush',
      (tester) async {
        final src = Cell.ingress<int>();

        await tester.pumpWidget(
          _wrap(
            _EmitHost(
              child: CellValueBuilder<int>(
                cell: src.cell,
                initial: 0,
                builder: (_, v) => Text('$v'),
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
