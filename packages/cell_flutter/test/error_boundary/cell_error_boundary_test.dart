// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Error boundary: invalidated-cell containment, report-channel
// passthrough, recovery, nesting, and handler restoration.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An invalidated cell (the CellNotifier constructor throws ArgumentError).
ValueCell<int> _invalidatedCell() {
  final policy = EphemeralPolicy<Cell>(
    eventLimit: 1,
    onEvent: (object, {required cell, required policy, arguments, user}) =>
        (events: policy.events + 1),
    onInvalidate: (nucleus) => true,
  );
  final head = Cell.governed(
    ephemeralPolicy: policy,
    context: Context.system,
  );
  policy('use', cell: head);
  return ValueCell<int>(initial: 0, bind: head);
}

/// A fallback widget that throws while building (used by the
/// second-error-forwarding test).
class _ThrowingFallback extends StatelessWidget {
  const _ThrowingFallback();

  @override
  Widget build(BuildContext context) {
    throw StateError('fallback exploded');
  }
}

void main() {
  group('CellErrorBoundary', () {
    testWidgets('renders onError for an invalidated-cell error',
        (tester) async {
      final cell = _invalidatedCell();

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => Text('boundary:${error.runtimeType}'),
          child: CellBuilder<int>(
            cell: cell,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      // The build-phase capture is deferred to the post-frame callback.
      await tester.pump();

      expect(find.textContaining('boundary:ArgumentError'), findsOneWidget);
    });

    testWidgets('a cell invalidated mid-frame is contained', (tester) async {
      final policy = EphemeralPolicy<Cell>(
        eventLimit: 1,
        onEvent: (object, {required cell, required policy, arguments, user}) =>
            (events: policy.events + 1),
        onInvalidate: (nucleus) => true,
      );
      final head = Cell.governed(
        ephemeralPolicy: policy,
        context: Context.system,
      );
      final cell = ValueCell<int>(initial: 0, bind: head);

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => const Text('contained'),
          child: CellBuilder<int>(
            cell: cell,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      expect(find.text('0'), findsOneWidget);

      // Invalidate the cell between frames, then force a rebuild that
      // re-creates the CellNotifier over the now-invalidated cell.
      policy('use', cell: head);
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => const Text('contained'),
          child: CellBuilder<int>(
            key: UniqueKey(),
            cell: cell,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('contained'), findsOneWidget);
    });

    testWidgets('does not intercept the cell_flutter report channel',
        (tester) async {
      final boundaryKey = GlobalKey<CellErrorBoundaryState>();

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          key: boundaryKey,
          onError: (error, stack) => const Text('WRONG: intercepted'),
          child: const SizedBox.shrink(),
        ),
      ));

      // A type-mismatch is reported, not thrown: the boundary must forward
      // it to the previous handler (the test framework records it) and
      // must NOT render its fallback.
      final src = Cell.ingress<Object>();
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          key: boundaryKey,
          onError: (error, stack) => const Text('WRONG: intercepted'),
          child: CellValueBuilder<int>(
            cell: src.cell,
            initial: 1,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      src.emit('not-an-int');
      await tester.pump();

      expect(find.text('WRONG: intercepted'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('reset recovers and re-renders the child', (tester) async {
      final boundaryKey = GlobalKey<CellErrorBoundaryState>();
      final good = Cell.state<int>(initial: 7);

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          key: boundaryKey,
          onError: (error, stack) => Builder(
            builder: (ctx) => TextButton(
              onPressed: () => boundaryKey.currentState!.reset(),
              child: const Text('retry'),
            ),
          ),
          child: CellBuilder<int>(
            cell: _invalidatedCell(),
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('retry'), findsOneWidget);

      // Replace the bad cell with a good one, then recover.
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          key: boundaryKey,
          onError: (error, stack) => const Text('retry'),
          child: CellBuilder<int>(
            cell: good.cell,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      await tester.pump();

      boundaryKey.currentState!.reset();
      await tester.pump(); // schedules the post-frame reset callback
      await tester.pump(); // applies the reset

      expect(find.text('7'), findsOneWidget);
      expect(find.text('retry'), findsNothing);
    });

    testWidgets('onReset fires on reset', (tester) async {
      final boundaryKey = GlobalKey<CellErrorBoundaryState>();
      var resetCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          key: boundaryKey,
          onReset: () => resetCount++,
          onError: (error, stack) => const Text('fallback'),
          child: CellBuilder<int>(
            cell: _invalidatedCell(),
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      await tester.pump();

      boundaryKey.currentState!.reset();
      await tester.pump(); // schedules the post-frame reset callback
      await tester.pump(); // applies the reset
      expect(resetCount, 1);
    });

    testWidgets('nested boundaries are independent', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => const Text('outer-fallback'),
          child: CellErrorBoundary(
            onError: (error, stack) => const Text('inner-fallback'),
            child: CellBuilder<int>(
              cell: _invalidatedCell(),
              builder: (_, v) => Text('$v'),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('inner-fallback'), findsOneWidget);
      expect(find.text('outer-fallback'), findsNothing);
    });

    testWidgets('FlutterError.onError is restored on dispose', (tester) async {
      final original = FlutterError.onError;

      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => const Text('fallback'),
          child: const SizedBox.shrink(),
        ),
      ));
      expect(identical(FlutterError.onError, original), isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(identical(FlutterError.onError, original), isTrue);
    });

    testWidgets('a second error while the fallback is showing is forwarded',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => const _ThrowingFallback(),
          child: CellBuilder<int>(
            cell: _invalidatedCell(),
            builder: (_, v) => Text('$v'),
          ),
        ),
      ));
      await tester.pump();

      // The fallback itself throws while building; the boundary forwards
      // the second error to the previous handler (the test framework).
      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(error.toString(), contains('fallback exploded'));
    });

    testWidgets('captures an error reported outside a build phase',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CellErrorBoundary(
          onError: (error, stack) => Text('caught:${error.runtimeType}'),
          child: const SizedBox.shrink(),
        ),
      ));

      // A framework-shaped report arriving between frames (not during a
      // build) is captured synchronously.
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('late error'),
        library: 'widgets library',
        context: ErrorDescription('test'),
      ));
      await tester.pump();

      expect(find.textContaining('caught:StateError'), findsOneWidget);
    });
  });
}
