// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// State restoration: RestorableCell + CellRestorationScope +
// Cell.restorableState. These tests simulate persisted buckets with
// RestorationBucket.root and the nested rawData format Flutter's
// RestorationMixin claims child buckets from.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a root bucket containing a child bucket for the scope id
/// [scopeId], holding [values] as its restored key-value pairs.
RestorationBucket _bucketWith(Map<String, Object?> values,
    {String scopeId = 'cells'}) {
  return RestorationBucket.root(
    manager: TestWidgetsFlutterBinding.instance.restorationManager,
    rawData: <Object?, Object?>{
      'v': <Object?, Object?>{},
      'c': <Object?, Object?>{
        scopeId: <Object?, Object?>{
          'v': values,
          'c': <Object?, Object?>{},
        },
      },
    },
  );
}

/// A host that registers its cells with the enclosing
/// [CellRestorationScope] in `initState` (the documented timing).
class _RegistrationHost extends StatefulWidget {
  const _RegistrationHost({required this.cells, required this.builder});

  final List<RestorableCell<Object?>> cells;
  final WidgetBuilder builder;

  @override
  State<_RegistrationHost> createState() => _RegistrationHostState();
}

class _RegistrationHostState extends State<_RegistrationHost> {
  @override
  void initState() {
    super.initState();
    for (final cell in widget.cells) {
      CellRestorationScope.of(context).register(cell);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _wrap(Widget child, {RestorationBucket? bucket, Key? key}) {
  return MaterialApp(
    home: KeyedSubtree(
      key: key,
      child: CellRestorationScope(
        restorationScopeId: 'cells',
        bucket: bucket,
        child: Scaffold(body: child),
      ),
    ),
  );
}

CellRestorationScopeState _scopeState(WidgetTester tester) {
  final element = tester.element(
    find.byElementPredicate(
      (e) => e is StatefulElement && e.state is CellRestorationScopeState,
    ),
  ) as StatefulElement;
  return element.state as CellRestorationScopeState;
}

void main() {
  group('RestorableCell', () {
    testWidgets('fresh install falls back to initial', (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
          cells: [cell],
          builder: (_) => CellBuilder<int>(
            cell: cell,
            builder: (_, v) => Text('${v ?? 0}'),
          ),
        ),
        bucket: _bucketWith({}),
      ));

      expect(cell.value, 0);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('persisted bucket restores the value (restored wins)',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
          cells: [cell],
          builder: (_) => CellBuilder<int>(
            cell: cell,
            builder: (_, v) => Text('${v ?? 0}'),
          ),
        ),
        bucket: _bucketWith({'counter': 42}),
      ));

      expect(cell.value, 42);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('primitive types round-trip into the bucket', (tester) async {
      final ints = restorableState<int>(
        restorationId: 'int',
        initial: 1,
      );
      final doubles = restorableState<double>(
        restorationId: 'double',
        initial: 1.5,
      );
      final strings = restorableState<String>(
        restorationId: 'string',
        initial: 'a',
      );
      final bools = restorableState<bool>(
        restorationId: 'bool',
        initial: false,
      );
      final nulls = restorableState<String>(
        restorationId: 'null',
        initial: null,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [ints, doubles, strings, bools, nulls],
            builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));

      ints.value = 7;
      doubles.value = 2.5;
      strings.value = 'hi';
      bools.value = true;
      nulls.value = null;
      await tester.pump();

      final bucket = _scopeState(tester).bucket!;
      expect(bucket.read<Object?>('int'), 7);
      expect(bucket.read<Object?>('double'), 2.5);
      expect(bucket.read<Object?>('string'), 'hi');
      expect(bucket.read<Object?>('bool'), true);
      expect(bucket.contains('null'), isTrue);
    });

    testWidgets('non-primitive value without codecs throws UnsupportedError',
        (tester) async {
      final cell = restorableState<List<int>>(
        restorationId: 'list',
        initial: const [1, 2],
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));

      final error = tester.takeException();
      expect(error, isA<UnsupportedError>());
      expect(error.toString(), contains('not a primitive'));
    });

    testWidgets('custom codecs round-trip a custom object', (tester) async {
      final cell = restorableState<String>(
        restorationId: 'user',
        initial: 'anon',
        toPrimitives: (v) => v,
        fromPrimitives: (data) => data as String?,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));

      cell.value = 'bob';
      await tester.pump();
      expect(_scopeState(tester).bucket!.read<Object?>('user'), 'bob');
    });

    testWidgets('restored value equal to initial does not emit a pulse',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 5,
      );
      final pulses = <Pulse<Object?>>[];
      final egress = Cell.observe<Pulse<Object?>>(
        source: cell,
        effect: pulses.add,
      );
      addTearDown(egress.stop);

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({'counter': 5}),
      ));

      expect(cell.value, 5);
      expect(pulses, isEmpty);
    });

    testWidgets('duplicate restorationId throws StateError', (tester) async {
      final a = restorableState<int>(restorationId: 'dup', initial: 1);
      final b = restorableState<int>(restorationId: 'dup', initial: 2);

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [a, b], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(error.toString(), contains('already registered'));
    });

    testWidgets('registering the same cell twice is idempotent',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 3,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({'counter': 9}),
      ));
      _scopeState(tester).register(cell);
      await tester.pump();

      expect(cell.value, 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unregister removes the value, re-register works',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 1,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));
      cell.value = 7;
      await tester.pump();
      expect(_scopeState(tester).bucket!.contains('counter'), isTrue);

      _scopeState(tester).unregister(cell);
      await tester.pump();
      expect(_scopeState(tester).bucket!.contains('counter'), isFalse);

      _scopeState(tester).register(cell);
      await tester.pump();
      cell.value = 8;
      await tester.pump();
      expect(_scopeState(tester).bucket!.read<Object?>('counter'), 8);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scope disposal unregisters cleanly', (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 1,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));
      cell.value = 5;
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nested scopes restore independently', (tester) async {
      final outer = restorableState<int>(
        restorationId: 'outerValue',
        initial: 0,
      );
      final inner = restorableState<int>(
        restorationId: 'innerValue',
        initial: 0,
      );

      final rootBucket = RestorationBucket.root(
        manager: TestWidgetsFlutterBinding.instance.restorationManager,
        rawData: <Object?, Object?>{
          'v': <Object?, Object?>{},
          'c': <Object?, Object?>{
            'outer': <Object?, Object?>{
              'v': <Object?, Object?>{'outerValue': 11},
              'c': <Object?, Object?>{
                'inner': <Object?, Object?>{
                  'v': <Object?, Object?>{'innerValue': 22},
                  'c': <Object?, Object?>{},
                },
              },
            },
          },
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: CellRestorationScope(
          restorationScopeId: 'outer',
          bucket: rootBucket,
          child: _RegistrationHost(
            cells: [outer],
            builder: (_) => CellRestorationScope(
              restorationScopeId: 'inner',
              child: _RegistrationHost(
                cells: [inner],
                builder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(outer.value, 11);
      expect(inner.value, 22);
    });

    testWidgets('multiple cells in one scope restore', (tester) async {
      final a = restorableState<int>(restorationId: 'a', initial: 0);
      final b = restorableState<String>(restorationId: 'b', initial: '');

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [a, b], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({'a': 1, 'b': 'two'}),
      ));

      expect(a.value, 1);
      expect(b.value, 'two');
    });

    testWidgets('cleared data falls back to initial', (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 10,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}),
      ));

      expect(cell.value, 10);
    });

    testWidgets('wrong-typed restored primitive throws UnsupportedError',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({'counter': 'not-an-int'}),
      ));

      final error = tester.takeException();
      expect(error, isA<UnsupportedError>());
      expect(error.toString(), contains('cannot restore'));
    });

    testWidgets(
        'of() throws when no CellRestorationScope encloses the '
        'context', (tester) async {
      final cell = restorableState<int>(restorationId: 'counter', initial: 0);
      await tester.pumpWidget(MaterialApp(
        home: _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
      ));

      // The host calls CellRestorationScope.of(context) in initState.
      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect(error.toString(), contains('no CellRestorationScope'));
    });

    testWidgets('a changed restoration id re-restores registered cells',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );

      // First mount with a bucket under 'cellsA'; the same scope element
      // then receives a NEW restorationScopeId ('cellsB') without a
      // bucket, which routes through the mixin's restore path and
      // re-registers every known cell (restoreState runs again).
      await tester.pumpWidget(_wrap(
        _RegistrationHost(
            cells: [cell], builder: (_) => const SizedBox.shrink()),
        bucket: _bucketWith({}, scopeId: 'cellsA'),
      ));
      cell.value = 9;
      await tester.pump();
      expect(cell.value, 9);
      expect(
          _scopeState(tester).registeredCells.containsKey('counter'), isTrue);

      await tester.pumpWidget(MaterialApp(
        home: KeyedSubtree(
          child: CellRestorationScope(
            restorationScopeId: 'cellsB',
            child: Scaffold(
              body: _RegistrationHost(
                  cells: [cell], builder: (_) => const SizedBox.shrink()),
            ),
          ),
        ),
      ));
      await tester.pump();

      // No data under the new id: the re-registration resets to initial.
      expect(cell.value, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('value writes after restoration propagate through the graph',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );

      await tester.pumpWidget(_wrap(
        _RegistrationHost(
          cells: [cell],
          builder: (_) => CellBuilder<int>(
            cell: cell,
            builder: (_, v) => Text('${v ?? 0}'),
          ),
        ),
        bucket: _bucketWith({'counter': 3}),
      ));
      expect(find.text('3'), findsOneWidget);

      cell.value = 4;
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('claims a bucket from the surrounding RestorationScope',
        (tester) async {
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 2,
      );

      await tester.pumpWidget(MaterialApp(
        home: RootRestorationScope(
          restorationId: 'root',
          child: CellRestorationScope(
            restorationScopeId: 'cells',
            child: _RegistrationHost(
              cells: [cell],
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      ));

      final scopeState = _scopeState(tester);
      expect(scopeState.bucket, isNotNull);

      cell.value = 9;
      await tester.pump();
      expect(scopeState.bucket!.read<Object?>('counter'), 9);
    });
  });

  group('restoration integration', () {
    testWidgets('CounterApp survives a process-kill simulation',
        (tester) async {
      // Step 1: fresh install, increment to 5.
      final cell = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );
      await tester.pumpWidget(_wrap(
        _RegistrationHost(
          cells: [cell],
          builder: (_) => Column(children: [
            CellBuilder<int>(cell: cell, builder: (_, v) => Text('$v')),
            Builder(
              builder: (ctx) => TextButton(
                onPressed: () => cell.value = (cell.value ?? 0) + 1,
                child: const Text('inc'),
              ),
            ),
          ]),
        ),
        bucket: _bucketWith({}),
      ));
      expect(find.text('0'), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('inc'));
        await tester.pump();
      }
      expect(find.text('5'), findsOneWidget);

      // Kill: read the persisted primitive out of the bucket.
      final persisted = _scopeState(tester).bucket!.read<Object?>('counter');
      expect(persisted, 5);

      // Restart: fresh element tree (a real process restart remounts the
      // tree; the UniqueKey forces the same in the test, so the scope
      // claims its bucket from the persisted data instead of adopting the
      // previous tree's bucket).
      final revived = restorableState<int>(
        restorationId: 'counter',
        initial: 0,
      );
      await tester.pumpWidget(_wrap(
        _RegistrationHost(
          cells: [revived],
          builder: (_) => Column(children: [
            CellBuilder<int>(cell: revived, builder: (_, v) => Text('$v')),
            Builder(
              builder: (ctx) => TextButton(
                onPressed: () => revived.value = (revived.value ?? 0) + 1,
                child: const Text('inc'),
              ),
            ),
          ]),
        ),
        bucket: _bucketWith({'counter': persisted as int}),
        key: UniqueKey(),
      ));
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.text('inc'));
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('a one-sided custom codec asserts in debug builds', () {
    expect(
      () => RestorableCell<int>(
        restorationId: 'x',
        initial: 0,
        fromPrimitives: (data) => data as int, // toPrimitives missing
      ),
      throwsAssertionError,
    );
    expect(
      () => RestorableCell<int>(
        restorationId: 'x',
        initial: 0,
        toPrimitives: (value) => value, // fromPrimitives missing
      ),
      throwsAssertionError,
    );
  });
}
