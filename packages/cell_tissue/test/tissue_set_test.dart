// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

/// Resolves the [FutureOr] returned by [TissueSet.deputy] into a [TissueSet].
Future<TissueSet<T>> resolveDeputy<T>(TissueSet<T> source) async {
  final result = source.deputy();
  return result is Future<TissueSet<T>> ? await result : result;
}

void main() {
  group('TissueSet factories', () {
    test('primary factory deduplicates initial elements', () {
      final set = TissueSet<int>([1, 2, 2, 3]);

      expect(set.runtimeType.toString(), contains('TissueSet'));
      expect(set.toSet(), {1, 2, 3});
      expect(set.length, 3);
      expect(set.isEmpty, isFalse);
      expect(set.isNotEmpty, isTrue);
    });

    test('empty factory creates an empty reactive set', () {
      final set = TissueSet<int>.empty();

      expect(set.runtimeType.toString(), contains('TissueSet'));
      expect(set.toSet(), isEmpty);
      expect(set.length, 0);
    });

    test('of factory builds from an iterable', () {
      final set = TissueSet.of([1, 2, 2, 3]);

      expect(set.toSet(), {1, 2, 3});
    });

    test('from factory casts dynamic elements', () {
      final set = TissueSet<int>.from([1, 2, 3] as List<dynamic>);

      expect(set.toSet(), {1, 2, 3});
    });

    test('identity factory creates an identity-based set', () {
      final set = TissueSet<int>.identity();

      expect(set.add(1), isTrue);
      expect(set.add(2), isTrue);
      expect(set.toSet(), {1, 2});
    });

    test('governed testRule is preserved and enforced', () {
      final rule = TestTissue<int, TissueSet<int>>(
        (object, {host, arguments, user}) => (object as int) > 0,
      );
      final set = TissueSet<int>([1], testRule: rule);

      expect(set.validate, same(rule));
      expect(set.toSet(), {1});

      expect(set.add(-1), isFalse);
      expect(set.toSet(), {1});
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();
      final set = TissueSet.fromNucleus(nucleus, elements: [7, 8]);

      expect(set.toSet(), {7, 8});
    });

    test('create builds a set from explicit parameters', () {
      final set = TissueSet.create<int, TissueSet<int>>(elements: [3, 4]);

      expect(set.runtimeType.toString(), contains('TissueSet'));
      expect(set.toSet(), {3, 4});
    });

    test('create with identity container', () {
      final set = TissueSet.create<int, TissueSet<int>>(
        elements: [5, 6],
        container: Container.identitySet,
      );

      expect(set.toSet(), {5, 6});
    });
  });

  group('TissueSet read operations', () {
    late TissueSet<int> set;

    setUp(() {
      set = TissueSet<int>([1, 2, 3]);
    });

    test('contains and lookup', () {
      expect(set.contains(2), isTrue);
      expect(set.contains(9), isFalse);
      expect(set.lookup(2), 2);
      expect(set.lookup(9), isNull);
    });

    test('containsAll', () {
      expect(set.containsAll([1, 2]), isTrue);
      expect(set.containsAll([1, 9]), isFalse);
    });

    test('toSet returns a plain Set copy', () {
      final copy = set.toSet();

      expect(copy, {1, 2, 3});
      expect(identical(copy, set), isFalse);
    });

    test('structural equality, hashCode and toString', () {
      final same = TissueSet<int>([1, 2, 3]);
      final different = TissueSet<int>([1, 2, 4]);

      expect(set == set, isTrue);
      expect(set == same, isTrue);
      expect(set == {1, 2, 3}, isTrue);
      expect(set == different, isFalse);
      expect(set == {1, 2, 4}, isFalse);
      expect(identical(set, 42), isFalse);
      expect(set.hashCode, same.hashCode);
      expect(set.toString(), contains('1'));
    });

    test('cell metadata', () {
      expect(set.validate, same(TestTissue.allowAll));
      expect(set.context, Context.system);
      expect(set.isTerminal, isFalse);
      expect(set.isInvalidated, isFalse);
      expect(set.isGoverned, isFalse);
      expect(set.modifiable, contains(set.add));
      expect(set.modifiable, contains(set.remove));
    });
  });

  group('TissueSet mutations', () {
    test('add returns true for new elements and false for duplicates', () {
      final set = TissueSet<int>.empty();

      expect(set.add(4), isTrue);
      expect(set.add(4), isFalse);
      expect(set.toSet(), {4});
    });

    test('addAll adds valid elements', () {
      final set = TissueSet<int>.empty();

      set.addAll([5, 6]);
      expect(set.toSet(), {5, 6});

      set.addAll([6, 7]);
      expect(set.toSet(), {5, 6, 7});
    });

    test('remove returns true when present and false otherwise', () {
      final set = TissueSet<int>([1, 2, 3]);

      expect(set.remove(2), isTrue);
      expect(set.remove(99), isFalse);
      expect(set.toSet(), {1, 3});
    });

    test('removeAll removes contained elements', () {
      final set = TissueSet<int>([1, 2, 3, 4]);

      set.removeAll([2, 4]);
      expect(set.toSet(), {1, 3});
    });

    test('removeWhere removes matching elements', () {
      final set = TissueSet<int>([1, 2, 3, 4]);

      set.removeWhere((e) => e.isOdd);
      expect(set.toSet(), {2, 4});
    });

    test('retainAll keeps only contained elements', () {
      final set = TissueSet<int>([1, 2, 3, 4]);

      set.retainAll([2, 4]);
      expect(set.toSet(), {2, 4});
    });

    test('retainWhere keeps matching elements', () {
      final set = TissueSet<int>([1, 2, 3, 4]);

      set.retainWhere((e) => e.isEven);
      expect(set.toSet(), {2, 4});
    });

    test('clear empties the set', () {
      final set = TissueSet<int>([1, 2, 3]);

      set.clear();
      expect(set.toSet(), isEmpty);
      expect(set.length, 0);
    });

    test('mutations on empty set are safe', () {
      final set = TissueSet<int>.empty();

      set.removeAll([1, 2]);
      set.removeWhere((e) => e.isOdd);
      set.retainAll([1]);
      set.retainWhere((e) => e.isEven);
      set.clear();
      expect(set.toSet(), isEmpty);
    });

    test('add and remove can be invoked through apply gateway', () {
      final set = TissueSet<int>.empty();

      final added = set.apply(set.add, positionalArguments: [9]);
      expect(added, isNotNull);
      expect(set.toSet(), {9});

      final removed = set.apply(set.remove, positionalArguments: [9]);
      expect(removed, isNotNull);
      expect(set.toSet(), isEmpty);
    });

    test('apply rejects functions outside the modifiable whitelist', () {
      final set = TissueSet<int>([1]);

      expect(set.apply(set.contains, positionalArguments: [1]), isNull);
    });
  });

  group('TissueSetNucleus factories', () {
    test('create returns a reusable blueprint', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();

      final a = TissueSet.fromNucleus(nucleus, elements: [1]);
      expect(a.toSet(), {1});
    });

    test('clone produces an independent nucleus', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();
      final clone = nucleus.clone;

      final a = TissueSet.fromNucleus(clone, elements: [2, 3]);
      expect(a.toSet(), {2, 3});
    });

    test('evolve produces a deputy nucleus', () {
      final principal = TissueSetNucleus.create<int, TissueSet<int>>();
      final evolved = TissueSetNucleus<int>.evolve(
        principal: principal,
        testRule: TestTissue<int, TissueSet<int>>(
          (object, {host, arguments, user}) => (object as int) > 0,
        ),
      );

      expect(evolved, isA<TissueSetNucleus<int>>());
    });
  });

  group('TissueSet.unmodifiable', () {
    late TissueSet<int> source;

    setUp(() {
      source = TissueSet<int>([4, 5]);
    });

    test('unmodifiable getter returns a live read-only view', () {
      final view = source.unmodifiable;

      expect(view.runtimeType.toString(), contains('UnmodifiableTissueSet'));
      expect(view.toSet(), {4, 5});
      expect(view.modifiable.toList(), isEmpty);
      expect(view == source, isTrue);
      expect(source == view, isTrue);
      expect(view == {4, 5}, isTrue);
      expect(view.validate, same(TestTissue.allowAll));
      expect(identical(view, view.unmodifiable), isTrue);
    });

    test('unmodifiable view rejects mutations silently', () {
      final view = source.unmodifiable;

      expect(view.add(9), isFalse);
      expect(view.remove(4), isFalse);
      view.addAll([9]);
      view.removeAll([4]);
      view.removeWhere((e) => e.isEven);
      view.retainAll([4]);
      view.retainWhere((e) => e.isEven);
      view.clear();
      expect(view.toSet(), {4, 5});
      expect(source.toSet(), {4, 5});
    });

    test('standalone UnmodifiableTissueSet factory', () {
      final u = UnmodifiableTissueSet<int>([1, 2, 3]);

      expect(u.toSet(), {1, 2, 3});
      expect(u.length, 3);
      expect(u.modifiable.toList(), isEmpty);
      expect(u == {1, 2, 3}, isTrue);
      expect(u == u, isTrue);
      expect(identical(u, 42), isFalse);
      expect(u.hashCode, UnmodifiableTissueSet<int>([1, 2, 3]).hashCode);
      expect(u.toString(), contains('1'));
    });

    test('standalone with unmodifiableElement false', () {
      final u =
          UnmodifiableTissueSet<int>([1, 2, 3], unmodifiableElement: false);

      expect(u.toSet(), {1, 2, 3});
    });

    test('view factory with unmodifiableElement false', () {
      final view =
          UnmodifiableTissueSet<int>.view(source, unmodifiableElement: false);

      expect(view.toSet(), {4, 5});
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();
      final u =
          UnmodifiableTissueSet<int>.fromNucleus(nucleus, elements: [9, 10]);

      expect(u.toSet(), {9, 10});
    });

    test('fromNucleus with unmodifiableElement false', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();
      final u = UnmodifiableTissueSet<int>.fromNucleus(nucleus,
          unmodifiableElement: false, elements: [11, 12]);

      expect(u.toSet(), {11, 12});
    });

    test('create factory', () {
      final u = UnmodifiableTissueSet.create<int, TissueSet<int>>(
        elements: [13, 14],
      );

      expect(u.toSet(), {13, 14});
    });

    test('projects child cells as unmodifiable elements', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final cellSet = TissueSet<Cell>([cell]);
      final view = cellSet.unmodifiable;

      final projected = view.toSet().single;
      expect(identical(projected, cell), isFalse);
    });
  });

  group('TissueSet.deputy', () {
    test('deputy shares principal storage and equality', () async {
      final source = TissueSet<int>([4, 5]);
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(deputy.toSet(), {4, 5});
      expect(deputy == source, isTrue);
      expect(source == deputy, isTrue);
    });

    test('nested deputies', () async {
      final source = TissueSet<int>([4, 5]);
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(nested.toSet(), {4, 5});
      expect(nested == source, isTrue);
      expect(nested == deputy, isTrue);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = TissueSet<int>([4, 5]);
      final view = source.unmodifiable;
      final deputy = await resolveDeputy(view);

      expect(deputy.toSet(), {4, 5});
    });
  });

  group('ModifiableSetAsync', () {
    test('async add and addAll', () async {
      final set = TissueSet<int>.empty();
      final async = set.async;

      expect(async, isA<ModifiableSetAsync<int>>());
      expect(await async.add(1), isTrue);
      expect(await async.add(1), isFalse);
      await async.addAll([2, 3]);
      expect(set.toSet(), {1, 2, 3});
    });

    test('async remove and removeAll', () async {
      final set = TissueSet<int>([1, 2, 3, 4]);
      final async = set.async;

      expect(await async.remove(2), isTrue);
      expect(await async.remove(99), isFalse);
      await async.removeAll([4]);
      expect(set.toSet(), {1, 3});
    });

    test('async retain and removeWhere', () async {
      final set = TissueSet<int>([1, 2, 3, 4]);
      final async = set.async;

      await async.retainAll([2, 4]);
      expect(set.toSet(), {2, 4});

      await async.retainWhere((e) => e.isEven);
      expect(set.toSet(), {2, 4});

      await async.removeWhere((e) => e == 2);
      expect(set.toSet(), {4});
    });

    test('async clear', () async {
      final set = TissueSet<int>([1, 2, 3]);
      final async = set.async;

      await async.clear();
      expect(set.toSet(), isEmpty);
    });

    test('unmodifiable async facade rejects every mutation', () async {
      final view = TissueSet<int>([1]).unmodifiable;
      final async = view.async;

      expect(async, isA<ModifiableSetAsync<int>>());
      await expectLater(async.add(1), throwsUnsupportedError);
      await expectLater(async.addAll([1]), throwsUnsupportedError);
      await expectLater(async.remove(1), throwsUnsupportedError);
      await expectLater(async.removeAll([1]), throwsUnsupportedError);
      await expectLater(async.clear(), throwsUnsupportedError);
      await expectLater(async.retainAll([1]), throwsUnsupportedError);
      await expectLater(async.retainWhere((e) => true), throwsUnsupportedError);
      await expectLater(async.removeWhere((e) => true), throwsUnsupportedError);
      await expectLater(
        async.apply(view.add, positionalArguments: [1]),
        throwsUnsupportedError,
      );
    });
  });

  group('TissueSet.apply + Cell.txApply integration', () {
    test('stages set.add through apply and commits atomically', () async {
      final set = TissueSet<int>.empty();
      final events = <TxApplyEvent>[];
      final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

      await tx.execute(
          participants: [set],
          body: (tx) {
            expect(set.toSet(), isEmpty);
            set.apply(set.add, positionalArguments: [1], tx: tx);
            set.apply(set.add, positionalArguments: [2], tx: tx);
            expect(set.toSet(), isEmpty); // staged, not applied until commit
          });

      expect(set.toSet(), {1, 2});
      expect(events.whereType<TxApplyBegun>(), isNotEmpty);
      expect(events.whereType<TxApplyStaged>().length, 2);
      expect(events.whereType<TxApplyCommitted>(), isNotEmpty);
    });

    test('apply with tx returns null and does not mutate before commit',
        () async {
      final set = TissueSet<int>.empty();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [set],
          body: (tx) {
            final result = set.apply(set.add, positionalArguments: [7], tx: tx);
            expect(result, isNull);
            expect(set.toSet(), isEmpty);
          });

      expect(set.toSet(), {7});
    });

    test('body failure rolls back staged mutations', () async {
      final set = TissueSet<int>.empty();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [set],
            body: (tx) {
              set.apply(set.add, positionalArguments: [1], tx: tx);
              set.apply(set.add, positionalArguments: [2], tx: tx);
              throw StateError('boom');
            }),
        throwsStateError,
      );

      expect(set.toSet(), isEmpty);
    });

    test('compensates unexecuted stages with compensateIfNotExecuted',
        () async {
      final set = TissueSet<int>.empty();
      final tx = Cell.txApply(
        const TxApplyOptions(compensateIfNotExecuted: true),
      );

      await tx.begin([set]);
      tx.enqueue(
        set,
        set.add,
        [1],
        null,
        compensateCell: set,
        compensateFunction: set.remove,
        compensatePositional: [1],
      );
      await tx.rollback();

      expect(set.toSet(), isEmpty);
    });

    test('rejects functions outside the modifiable whitelist at enqueue',
        () async {
      final set = TissueSet<int>.empty();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [set],
            body: (tx) {
              set.apply(set.contains, positionalArguments: [1], tx: tx);
            }),
        throwsA(isA<TxApplyException>()),
      );

      expect(set.toSet(), isEmpty);
    });

    test('enqueued compensation commits when the staged apply succeeds',
        () async {
      final set = TissueSet<int>.empty();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [set],
          body: (tx) {
            set.apply(
              set.add,
              positionalArguments: [5],
              tx: tx,
              compensate: set.remove,
              compensatePositional: [5],
            );
          });

      expect(set.toSet(), {5});
    });
  });
}
