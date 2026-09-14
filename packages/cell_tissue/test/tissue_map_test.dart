// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

/// Resolves the [FutureOr] returned by [TissueMap.deputy] into a [TissueMap].
Future<TissueMap<K, V>> resolveDeputy<K, V>(TissueMap<K, V> source) async {
  final result = source.deputy();
  return result is Future<TissueMap<K, V>> ? await result : result;
}

/// Converts a [TissueMap] into a plain [Map] for easy assertions.
Map<K, V> toMap<K, V>(TissueMap<K, V> map) => Map.fromEntries(map.entries);

/// A minimal concrete [TissueMapBase] subclass used to exercise the base
/// class members that are normally shadowed by the public implementations.
class _DirectMapBase<K, V> extends TissueMapBase<K, V, TissueMap<K, V>> {
  _DirectMapBase(super.properties) : super.fromNucleus();

  @override
  TissueMap<K, V> get unmodifiable => this;
}

void main() {
  group('TissueMap factories', () {
    test('primary factory creates an empty reactive map', () {
      final map = TissueMap<String, int>();

      expect(map.runtimeType.toString(), contains('TissueMap'));
      expect(toMap(map), isEmpty);
      expect(map.length, 0);
      expect(map.isEmpty, isTrue);
      expect(map.isNotEmpty, isFalse);
    });

    test('from factory copies a Dart map', () {
      final map = TissueMap<String, int>.from({'x': 1, 'y': 2});

      expect(toMap(map), {'x': 1, 'y': 2});
      expect(map.length, 2);
    });

    test('fromEntries factory ingests entries', () {
      final map = TissueMap<String, int>.fromEntries([
        MapEntry('p', 9),
        MapEntry('q', 10),
      ]);

      expect(toMap(map), {'p': 9, 'q': 10});
    });

    test('identity factory creates an identity-keyed map', () {
      final map = TissueMap<String, int>.identity();

      expect(map.add('k', 7), isTrue);
      expect(map['k'], 7);
      expect(toMap(map), {'k': 7});
    });

    test('fromNucleus populates entries', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final map = TissueMap.fromNucleus(nucleus, entries: [MapEntry('n', 1)]);

      expect(toMap(map), {'n': 1});
    });

    test('create builds a map from explicit parameters', () {
      final map = TissueMap.create<String, int, TissueMap<String, int>>(
        entries: [MapEntry('c', 2)],
      );

      expect(map.runtimeType.toString(), contains('TissueMap'));
      expect(toMap(map), {'c': 2});
    });
  });

  group('TissueMap read operations', () {
    late TissueMap<String, int> map;

    setUp(() {
      map = TissueMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});
    });

    test('operator [] and containsKey', () {
      expect(map['a'], 1);
      expect(map['b'], 2);
      expect(map['zz'], isNull);
      expect(map.containsKey('a'), isTrue);
      expect(map.containsKey('zz'), isFalse);
    });

    test('containsValue', () {
      expect(map.containsValue(2), isTrue);
      expect(map.containsValue(99), isFalse);
    });

    test('keys, values and entries', () {
      expect(map.keys.toSet(), {'a', 'b', 'c'});
      expect(map.values.toSet(), {1, 2, 3});
      expect(
        map.entries.map((e) => '${e.key}=${e.value}').toSet(),
        {'a=1', 'b=2', 'c=3'},
      );
    });

    test('structural equality, hashCode and toString', () {
      final same = TissueMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});
      final different = TissueMap<String, int>.from({'a': 1, 'b': 2, 'c': 4});

      expect(map == map, isTrue);
      expect(map == same, isTrue);
      expect(map == different, isFalse);
      expect(identical(map, 42), isFalse);
      expect(map.hashCode, same.hashCode);
      expect(map.toString(), contains('a'));
    });

    test('cell metadata', () {
      expect(map.validate, same(TestTissue.allowAll));
      expect(map.context, Context.system);
      expect(map.isTerminal, isFalse);
      expect(map.isInvalidated, isFalse);
      expect(map.isGoverned, isFalse);
      expect(map.modifiable, contains(map.add));
      expect(map.modifiable, contains(map.remove));
      expect(map.modifiable, contains(map.update));
    });
  });

  group('TissueMap mutations', () {
    test('operator []= and add associate keys', () {
      final map = TissueMap<String, int>();
      map['a'] = 1;

      expect(map['a'], 1);
      expect(map.add('b', 2), isTrue);
      expect(map.add('b', 3), isFalse);
      expect(toMap(map), {'a': 1, 'b': 2});
    });

    test('addAll adds entries from a map', () {
      final map = TissueMap<String, int>.from({'a': 1});

      map.addAll({'b': 2, 'c': 3});
      expect(toMap(map), {'a': 1, 'b': 2, 'c': 3});
    });

    test('addEntries adds entries from an iterable', () {
      final map = TissueMap<String, int>.from({'a': 1});

      map.addEntries([MapEntry('d', 4), MapEntry('e', 5)]);
      expect(toMap(map), {'a': 1, 'd': 4, 'e': 5});
    });

    test('putIfAbsent returns existing or inserts missing', () {
      final map = TissueMap<String, int>.from({'a': 1});

      expect(map.putIfAbsent('a', () => 99), 1);
      expect(map.putIfAbsent('b', () => 2), 2);
      expect(toMap(map), {'a': 1, 'b': 2});
    });

    test('update mutates existing values', () {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});

      expect(map.update('b', (v) => v * 10), 20);
      expect(map['b'], 20);
    });

    test('update with ifAbsent inserts missing keys', () {
      final map = TissueMap<String, int>.from({'a': 1});

      expect(map.update('z', (v) => v * 2, ifAbsent: () => 10), 10);
      expect(toMap(map), {'a': 1, 'z': 10});
    });

    test('updateAll applies a function to every entry', () {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});

      map.updateAll((key, value) => value + 1);
      expect(toMap(map), {'a': 2, 'b': 3});
    });

    test('remove returns the removed value or null', () {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});

      expect(map.remove('a'), 1);
      expect(map.remove('zz'), isNull);
      expect(toMap(map), {'b': 2});
    });

    test('removeWhere removes matching entries', () {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});

      map.removeWhere((key, value) => value.isEven);
      expect(toMap(map), {'a': 1, 'c': 3});
    });

    test('clear empties the map', () {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});

      map.clear();
      expect(toMap(map), isEmpty);
      expect(map.length, 0);
    });

    test('adding Cell values establishes reactive links', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final map = TissueMap<String, Cell>();

      expect(map.add('cell', cell), isTrue);
      map.addAll({'another': cell});
      map.addEntries([MapEntry('third', cell)]);
      expect(map.putIfAbsent('fourth', () => cell), cell);
      expect(map.length, 4);
    });

    test('update on a missing key without ifAbsent throws StateError', () {
      final map = TissueMap<String, int>.from({'a': 1});

      expect(() => map.update('zz', (v) => v + 1), throwsStateError);
    });

    test('fromNucleus links initial Cell values', () {
      final nucleus =
          TissueMapNucleus.create<String, Cell, TissueMap<String, Cell>>();
      final cell = Cell.state<int>(initial: 1).cell;
      final map =
          TissueMap.fromNucleus(nucleus, entries: [MapEntry('cell', cell)]);

      expect(map['cell'], same(cell));
    });

    test('add and remove can be invoked through the apply gateway', () {
      final map = TissueMap<String, int>();

      final added = map.apply(map.add, positionalArguments: ['x', 9]);
      expect(added, isNotNull);
      expect(map['x'], 9);

      final removed = map.apply(map.remove, positionalArguments: ['x']);
      expect(removed, 9);
      expect(map.containsKey('x'), isFalse);
    });

    test('apply rejects functions outside the modifiable whitelist', () {
      final map = TissueMap<String, int>.from({'a': 1});

      expect(map.apply(map.containsKey, positionalArguments: ['a']), isNull);
    });
  });

  group('TissueMapNucleus factories', () {
    test('create returns a reusable blueprint', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();

      final map = TissueMap.fromNucleus(nucleus, entries: [MapEntry('a', 1)]);
      expect(toMap(map), {'a': 1});
    });

    test('clone produces an independent nucleus', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final clone = nucleus.clone;

      final map = TissueMap.fromNucleus(clone, entries: [MapEntry('b', 2)]);
      expect(toMap(map), {'b': 2});
    });

    test('evolve produces a deputy nucleus', () {
      final principal =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final evolved = TissueMapNucleus<String, int>.evolve(
        principal: principal,
        testRule: TestTissue<int, TissueMap<String, int>>(
          (object, {host, arguments, user}) => (object as int) > 0,
        ),
      );

      expect(evolved, isA<TissueMapNucleus<String, int>>());
    });
  });

  group('TissueMap.unmodifiable', () {
    late TissueMap<String, int> source;

    setUp(() {
      source = TissueMap<String, int>.from({'a': 1, 'b': 2});
    });

    test('unmodifiable getter returns a read-only view', () {
      final view = source.unmodifiable;

      expect(view.runtimeType.toString(), contains('UnmodifiableTissueMap'));
      expect(toMap(view), {'a': 1, 'b': 2});
      expect(view.modifiable.toList(), isEmpty);
      expect(identical(view, view.unmodifiable), isTrue);
      expect(view.validate, same(TestTissue.allowAll));
    });

    test('unmodifiable view rejects every mutation', () {
      final view = source.unmodifiable;

      expect(() => view['q'] = 1, throwsUnsupportedError);
      expect(() => view.add('q', 1), throwsUnsupportedError);
      expect(() => view.addAll({'q': 1}), throwsUnsupportedError);
      expect(() => view.addEntries([MapEntry('q', 1)]), throwsUnsupportedError);
      expect(() => view.clear(), throwsUnsupportedError);
      expect(() => view.putIfAbsent('q', () => 1), throwsUnsupportedError);
      expect(() => view.remove('a'), throwsUnsupportedError);
      expect(() => view.removeWhere((k, v) => true), throwsUnsupportedError);
      expect(() => view.update('a', (v) => v + 1), throwsUnsupportedError);
      expect(() => view.updateAll((k, v) => v + 1), throwsUnsupportedError);
      expect(toMap(source), {'a': 1, 'b': 2});
    });

    test('standalone UnmodifiableTissueMap factory', () {
      final u = UnmodifiableTissueMap<String, int>(
          [MapEntry('a', 1), MapEntry('b', 2)]);

      expect(toMap(u), {'a': 1, 'b': 2});
      expect(u.length, 2);
      expect(u.modifiable.toList(), isEmpty);
      expect(u == u, isTrue);
      expect(identical(u, 42), isFalse);
      expect(u.toString(), contains('a'));
    });

    test('view factory with unmodifiableElement false', () {
      final view = UnmodifiableTissueMap<String, int>.view(source,
          unmodifiableElement: false);

      expect(toMap(view), {'a': 1, 'b': 2});
    });

    test('fromNucleus populates entries', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final u = UnmodifiableTissueMap<String, int>.fromNucleus(nucleus,
          entries: [MapEntry('u', 4)]);

      expect(toMap(u), {'u': 4});
    });

    test('fromNucleus with unmodifiableElement false', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final u = UnmodifiableTissueMap<String, int>.fromNucleus(nucleus,
          unmodifiableElement: false, entries: [MapEntry('u', 5)]);

      expect(toMap(u), {'u': 5});
    });

    test('create factory', () {
      final u =
          UnmodifiableTissueMap.create<String, int, TissueMap<String, int>>(
        entries: [MapEntry('u', 6)],
      );

      expect(toMap(u), {'u': 6});
    });

    test('projects child cells as unmodifiable elements', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final cellMap = TissueMap<String, Cell>.from({'cell': cell});
      final view = cellMap.unmodifiable;

      final projected = view.values.single;
      expect(identical(projected, cell), isFalse);
    });
  });

  group('TissueMap.deputy', () {
    test('deputy shares principal storage and equality', () async {
      final source = TissueMap<String, int>.from({'a': 1, 'b': 2});
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(toMap(deputy), {'a': 1, 'b': 2});
      expect(deputy == source, isTrue);
      expect(source == deputy, isTrue);
    });

    test('nested deputies', () async {
      final source = TissueMap<String, int>.from({'a': 1});
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(toMap(nested), {'a': 1});
      expect(nested == source, isTrue);
      expect(nested == deputy, isTrue);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = TissueMap<String, int>.from({'a': 1});
      final view = source.unmodifiable;
      final deputy = await resolveDeputy(view);

      expect(toMap(deputy), {'a': 1});
    });
  });

  group('TissueMapBase direct subclass', () {
    test('base deputy member is exercised', () async {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final direct = _DirectMapBase<String, int>(nucleus);

      expect(direct.unmodifiable, same(direct));
      final deputy = await resolveDeputy(direct);
      expect(deputy, isA<TissueMap<String, int>>());
    });
  });

  group('ModifiableMapAsync', () {
    test('async add and addAll', () async {
      final map = TissueMap<String, int>();
      final async = map.async;

      expect(async, isA<ModifiableMapAsync<String, int>>());
      expect(await async.add('a', 1), isTrue);
      expect(await async.add('a', 2), isFalse);
      await async.addAll({'b': 2, 'c': 3});
      expect(toMap(map), {'a': 1, 'b': 2, 'c': 3});
    });

    test('async addEntries and putIfAbsent', () async {
      final map = TissueMap<String, int>.from({'a': 1});
      final async = map.async;

      await async.addEntries([MapEntry('d', 4)]);
      expect(await async.putIfAbsent('a', () => 99), 1);
      expect(await async.putIfAbsent('e', () => 5), 5);
      expect(toMap(map), {'a': 1, 'd': 4, 'e': 5});
    });

    test('async remove and removeWhere', () async {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});
      final async = map.async;

      expect(await async.remove('a'), 1);
      expect(await async.remove('zz'), isNull);
      await async.removeWhere((key, value) => value.isEven);
      expect(toMap(map), {'c': 3});
    });

    test('async update and updateAll', () async {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});
      final async = map.async;

      expect(await async.update('b', (v) => v * 10), 20);
      expect(map['b'], 20);
      await async.updateAll((key, value) => value + 1);
      expect(toMap(map), {'a': 2, 'b': 21});
    });

    test('async clear', () async {
      final map = TissueMap<String, int>.from({'a': 1, 'b': 2});
      final async = map.async;

      await async.clear();
      expect(toMap(map), isEmpty);
    });

    test('unmodifiable async facade rejects every mutation', () async {
      final view = TissueMap<String, int>.from({'a': 1}).unmodifiable;
      final async = view.async;

      expect(async, isA<ModifiableMapAsync<String, int>>());
      await expectLater(async.add('q', 1), throwsUnsupportedError);
      await expectLater(async.addAll({'q': 1}), throwsUnsupportedError);
      await expectLater(
          async.addEntries([MapEntry('q', 1)]), throwsUnsupportedError);
      await expectLater(async.clear(), throwsUnsupportedError);
      await expectLater(
          async.putIfAbsent('q', () => 1), throwsUnsupportedError);
      await expectLater(async.remove('a'), throwsUnsupportedError);
      await expectLater(
          async.removeWhere((k, v) => true), throwsUnsupportedError);
      await expectLater(
          async.update('a', (v) => v + 1), throwsUnsupportedError);
      await expectLater(
          async.updateAll((k, v) => v + 1), throwsUnsupportedError);
      await expectLater(
        async.apply(view.add, positionalArguments: ['q', 1]),
        throwsUnsupportedError,
      );
    });
  });

  group('TissueMap.apply + Cell.txApply integration', () {
    test('stages map.add through apply and commits atomically', () async {
      final map = TissueMap<String, int>();
      final events = <TxApplyEvent>[];
      final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

      await tx.execute(
          participants: [map],
          body: (tx) {
            expect(toMap(map), isEmpty);
            map.apply(map.add, positionalArguments: ['a', 1], tx: tx);
            map.apply(map.add, positionalArguments: ['b', 2], tx: tx);
            expect(toMap(map), isEmpty); // staged, not applied until commit
          });

      expect(toMap(map), {'a': 1, 'b': 2});
      expect(events.whereType<TxApplyBegun>(), isNotEmpty);
      expect(events.whereType<TxApplyStaged>().length, 2);
      expect(events.whereType<TxApplyCommitted>(), isNotEmpty);
    });

    test('apply with tx returns null and does not mutate before commit',
        () async {
      final map = TissueMap<String, int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [map],
          body: (tx) {
            final result =
                map.apply(map.add, positionalArguments: ['k', 7], tx: tx);
            expect(result, isNull);
            expect(toMap(map), isEmpty);
          });

      expect(toMap(map), {'k': 7});
    });

    test('body failure rolls back staged mutations', () async {
      final map = TissueMap<String, int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [map],
            body: (tx) {
              map.apply(map.add, positionalArguments: ['a', 1], tx: tx);
              map.apply(map.add, positionalArguments: ['b', 2], tx: tx);
              throw StateError('boom');
            }),
        throwsStateError,
      );

      expect(toMap(map), isEmpty);
    });

    test('compensates unexecuted stages with compensateIfNotExecuted',
        () async {
      final map = TissueMap<String, int>();
      final tx = Cell.txApply(
        const TxApplyOptions(compensateIfNotExecuted: true),
      );

      await tx.begin([map]);
      tx.enqueue(
        map,
        map.add,
        ['a', 1],
        null,
        compensateCell: map,
        compensateFunction: map.remove,
        compensatePositional: ['a'],
      );
      await tx.rollback();

      expect(toMap(map), isEmpty);
    });

    test('rejects functions outside the modifiable whitelist at enqueue',
        () async {
      final map = TissueMap<String, int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [map],
            body: (tx) {
              map.apply(map.containsKey, positionalArguments: ['a'], tx: tx);
            }),
        throwsA(isA<TxApplyException>()),
      );

      expect(toMap(map), isEmpty);
    });

    test('enqueued compensation commits when the staged apply succeeds',
        () async {
      final map = TissueMap<String, int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [map],
          body: (tx) {
            map.apply(
              map.add,
              positionalArguments: ['x', 5],
              tx: tx,
              compensate: map.remove,
              compensatePositional: ['x'],
            );
          });

      expect(toMap(map), {'x': 5});
    });
  });
}
