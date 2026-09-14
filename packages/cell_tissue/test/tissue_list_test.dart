// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

/// Resolves the [FutureOr] returned by [TissueList.deputy] into a [TissueList].
Future<TissueList<T>> resolveDeputy<T>(TissueList<T> source) async {
  final result = source.deputy();
  return result is Future<TissueList<T>> ? await result : result;
}

void main() {
  group('TissueList factories', () {
    test('primary factory creates an empty reactive list', () {
      final list = TissueList<int>();

      expect(list.runtimeType.toString(), contains('TissueList'));
      expect(list.toList(), isEmpty);
      expect(list.length, 0);
      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
    });

    test('of factory populates from an iterable', () {
      final list = TissueList.of([1, 2, 2, 3]);

      expect(list.toList(), [1, 2, 2, 3]);
      expect(list.length, 4);
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();
      final list = TissueList.fromNucleus(nucleus, elements: [7, 8]);

      expect(list.toList(), [7, 8]);
    });

    test('create builds a list from explicit parameters', () {
      final list = TissueList.create<int, TissueList<int>>(elements: [3, 4]);

      expect(list.runtimeType.toString(), contains('TissueList'));
      expect(list.toList(), [3, 4]);
    });

    test('growable false creates a fixed-length list', () {
      final list = TissueList<int>(growable: false);

      expect(list.toList(), isEmpty);
      list.add(1);
      expect(list.toList(), isEmpty);
    });
  });

  group('TissueList read operations', () {
    late TissueList<int> list;

    setUp(() {
      list = TissueList.of([1, 2, 3]);
    });

    test('operator [] and length', () {
      expect(list[0], 1);
      expect(list[2], 3);
      expect(list.length, 3);
    });

    test('elementAt, contains and indexOf', () {
      expect(list.elementAt(1), 2);
      expect(list.contains(2), isTrue);
      expect(list.contains(9), isFalse);
      expect(list.indexOf(3), 2);
      expect(list.indexOf(9), -1);
    });

    test('first, last and toList', () {
      expect(list.first, 1);
      expect(list.last, 3);
      expect(list.toList(), [1, 2, 3]);
    });

    test('structural equality, hashCode and toString', () {
      final same = TissueList.of([1, 2, 3]);
      final different = TissueList.of([1, 2, 4]);

      expect(list == list, isTrue);
      expect(list == same, isTrue);
      expect(list == different, isFalse);
      expect(identical(list, 42), isFalse);
      expect(list.hashCode, same.hashCode);
      expect(list.toString(), contains('1'));
    });

    test('cell metadata', () {
      expect(list.validate, same(TestTissue.allowAll));
      expect(list.context, Context.system);
      expect(list.isTerminal, isFalse);
      expect(list.isInvalidated, isFalse);
      expect(list.isGoverned, isFalse);
      expect(list.modifiable, contains(list.add));
      expect(list.modifiable, contains(list.remove));
    });
  });

  group('TissueList mutations', () {
    test('operator []= and setValueAt update elements', () {
      final list = TissueList.of([1, 2, 3]);

      list[0] = 9;
      expect(list.toList(), [9, 2, 3]);
      list.setValueAt(1, 8);
      expect(list.toList(), [9, 8, 3]);
      list.setFirst(7);
      expect(list.toList(), [7, 8, 3]);
    });

    test('add and addAll append elements', () {
      final list = TissueList<int>();

      list.add(1);
      list.addAll([2, 3]);
      expect(list.toList(), [1, 2, 3]);
    });

    test('remove returns true only when present', () {
      final list = TissueList.of([1, 2, 3]);

      expect(list.remove(2), isTrue);
      expect(list.remove(99), isFalse);
      expect(list.toList(), [1, 3]);
    });

    test('removeWhere and retainWhere filter elements', () {
      final list = TissueList.of([1, 2, 3, 4]);

      list.removeWhere((e) => e.isOdd);
      expect(list.toList(), [2, 4]);

      list.retainWhere((e) => e == 2);
      expect(list.toList(), [2]);
    });

    test('clear empties the list', () {
      final list = TissueList.of([1, 2, 3]);

      list.clear();
      expect(list.toList(), isEmpty);
    });

    test('fillRange overwrites a range', () {
      final list = TissueList.of([1, 2, 3, 4]);

      list.fillRange(1, 3, 0);
      expect(list.toList(), [1, 0, 0, 4]);
    });

    test('insert and insertAll shift elements', () {
      final list = TissueList.of([1, 4]);

      list.insert(1, 2);
      list.insertAll(2, [3]);
      expect(list.toList(), [1, 2, 3, 4]);
    });

    test('removeAt and removeLast return removed elements', () {
      final list = TissueList.of([1, 2, 3]);

      expect(list.removeAt(1), 2);
      expect(list.removeLast(), 3);
      expect(list.toList(), [1]);
    });

    test('removeRange deletes a range', () {
      final list = TissueList.of([1, 2, 3, 4]);

      list.removeRange(1, 3);
      expect(list.toList(), [1, 4]);
    });

    test('replaceRange substitutes elements', () {
      final list = TissueList.of([1, 2, 3]);

      list.replaceRange(1, 2, [9, 8]);
      expect(list.toList(), [1, 9, 8, 3]);
    });

    test('setAll and setRange overwrite positions', () {
      final list = TissueList.of([1, 2, 3]);

      list.setAll(0, [9]);
      expect(list.toList(), [9, 2, 3]);

      list.setRange(1, 3, [8, 7]);
      expect(list.toList(), [9, 8, 7]);
    });

    test('sort orders elements', () {
      final list = TissueList.of([3, 1, 2]);

      list.sort();
      expect(list.toList(), [1, 2, 3]);
    });

    test('shuffle keeps elements', () {
      final list = TissueList.of([1, 2, 3]);

      list.shuffle();
      expect(list.toSet(), {1, 2, 3});
    });

    test('length setter truncates or expands', () {
      final list = TissueList.of([1, 2, 3]);

      list.length = 2;
      expect(list.toList(), [1, 2]);
    });

    test('apply gateway dispatches whitelisted functions', () {
      final list = TissueList<int>();

      final added = list.apply(list.add, positionalArguments: [9]);
      expect(added, isNotNull);
      expect(list.toList(), [9]);
    });

    test('apply rejects non-whitelisted functions', () {
      final list = TissueList.of([1]);

      expect(list.apply(list.contains, positionalArguments: [1]), isNull);
    });

    test('operator + concatenates two lists', () {
      final list = TissueList.of([1, 2]);
      final other = TissueList.of([3, 4]);

      final combined = list + other;
      expect(combined.toList(), [1, 2, 3, 4]);
    });

    test('adding Cell values establishes reactive links', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final list = TissueList<Cell>();

      list.add(cell);
      list.addAll([cell]);
      list.insert(0, cell);
      expect(list.length, 3);
    });
  });

  group('TissueListNucleus factories', () {
    test('create returns a reusable blueprint', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();

      final list = TissueList.fromNucleus(nucleus, elements: [1]);
      expect(list.toList(), [1]);
    });

    test('clone produces an independent nucleus', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();
      final clone = nucleus.clone;

      final list = TissueList.fromNucleus(clone, elements: [2, 3]);
      expect(list.toList(), [2, 3]);
    });

    test('evolve produces a deputy nucleus', () {
      final principal = TissueListNucleus.create<int, TissueList<int>>();
      final evolved = TissueListNucleus<int>.evolve(
        principal: principal,
        testRule: TestTissue<int, TissueList<int>>(
          (object, {host, arguments, user}) => (object as int) > 0,
        ),
      );

      expect(evolved, isA<TissueListNucleus<int>>());
    });
  });

  group('TissueList.unmodifiable', () {
    late TissueList<int> source;

    setUp(() {
      source = TissueList.of([1, 2, 3]);
    });

    test('unmodifiable getter returns a read-only view', () {
      final view = source.unmodifiable;

      expect(view.runtimeType.toString(), contains('UnmodifiableTissueList'));
      expect(view.toList(), [1, 2, 3]);
      expect(view.modifiable.toList(), isEmpty);
      expect(identical(view, view.unmodifiable), isTrue);
      expect(view.validate, same(TestTissue.allowAll));
    });

    test('unmodifiable view rejects mutations', () {
      final view = source.unmodifiable;

      view.add(9);
      view[0] = 9;
      expect(view.remove(1), isFalse);
      expect(() => view.removeAt(0), throwsUnsupportedError);
      expect(() => view.removeLast(), throwsUnsupportedError);
      expect(view.toList(), [1, 2, 3]);
    });

    test('standalone UnmodifiableTissueList factory', () {
      final u = UnmodifiableTissueList<int>([1, 2, 3]);

      expect(u.toList(), [1, 2, 3]);
      expect(u.length, 3);
      expect(u.modifiable.toList(), isEmpty);
      expect(u == u, isTrue);
      expect(identical(u, 42), isFalse);
      expect(u.toString(), contains('1'));
    });

    test('view factory with unmodifiableElement false', () {
      final view =
          UnmodifiableTissueList<int>.view(source, unmodifiableElement: false);

      expect(view.toList(), [1, 2, 3]);
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();
      final u =
          UnmodifiableTissueList<int>.fromNucleus(nucleus, elements: [9, 10]);

      expect(u.toList(), [9, 10]);
    });

    test('create factory', () {
      final u = UnmodifiableTissueList.create<int, TissueList<int>>(
        elements: [11, 12],
      );

      expect(u.toList(), [11, 12]);
    });
  });

  group('TissueList.deputy', () {
    test('deputy shares principal storage and equality', () async {
      final source = TissueList.of([1, 2]);
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(deputy.toList(), [1, 2]);
      expect(deputy == source, isTrue);
      expect(source == deputy, isTrue);
    });

    test('nested deputies', () async {
      final source = TissueList.of([1, 2]);
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(nested.toList(), [1, 2]);
      expect(nested == source, isTrue);
      expect(nested == deputy, isTrue);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = TissueList.of([1, 2]);
      final view = source.unmodifiable;
      final deputy = await resolveDeputy(view);

      expect(deputy.toList(), [1, 2]);
    });
  });

  group('ModifiableListAsync', () {
    test('async setValueAt updates the list', () async {
      final list = TissueList.of([1, 2]);
      final async = list.async;

      expect(async, isA<ModifiableListAsync<int>>());
      await async.setValueAt(0, 9);
      expect(list.toList(), [9, 2]);
    });

    test('async mutations mirror the synchronous API', () async {
      final list = TissueList.of([1, 2]);
      final async = list.async;

      await async.setFirst(9);
      expect(list.first, 9);

      await async.add(3);
      await async.addAll([4]);
      await async.insert(0, 0);
      await async.insertAll(0, [0]);
      await async.remove(0);
      await async.removeWhere((e) => e == 0);
      await async.retainWhere((e) => e != 4);
      await async.fillRange(0, 1, 9);
      await async.replaceRange(0, 1, [8]);
      await async.setAll(0, [7]);
      await async.setRange(0, 1, [6]);
      await async.sort();
      await async.shuffle();
      await async.removeAt(0);
      await async.removeLast();
      await async.removeRange(0, 1);
      await async.clear();
      expect(list.toList(), isEmpty);
    });

    test('unmodifiable async facade rejects every mutation', () async {
      final view = TissueList.of([1]).unmodifiable;
      final async = view.async;

      await expectLater(async.setValueAt(0, 9), throwsUnsupportedError);
      await expectLater(async.setFirst(9), throwsUnsupportedError);
      await expectLater(async.add(9), throwsUnsupportedError);
      await expectLater(async.addAll([9]), throwsUnsupportedError);
      await expectLater(async.clear(), throwsUnsupportedError);
      await expectLater(async.remove(1), throwsUnsupportedError);
      await expectLater(async.removeWhere((e) => true), throwsUnsupportedError);
      await expectLater(async.retainWhere((e) => true), throwsUnsupportedError);
      await expectLater(async.fillRange(0, 1, 9), throwsUnsupportedError);
      await expectLater(async.insert(0, 9), throwsUnsupportedError);
      await expectLater(async.insertAll(0, [9]), throwsUnsupportedError);
      await expectLater(async.removeAt(0), throwsUnsupportedError);
      await expectLater(async.removeLast(), throwsUnsupportedError);
      await expectLater(async.removeRange(0, 1), throwsUnsupportedError);
      await expectLater(async.replaceRange(0, 1, [9]), throwsUnsupportedError);
      await expectLater(async.setAll(0, [9]), throwsUnsupportedError);
      await expectLater(async.setRange(0, 1, [9]), throwsUnsupportedError);
      await expectLater(async.shuffle(), throwsUnsupportedError);
      await expectLater(async.sort(), throwsUnsupportedError);
      await expectLater(
        async.apply(view.add, positionalArguments: [9]),
        throwsUnsupportedError,
      );
    });
  });

  group('TissueList.apply + Cell.txApply integration', () {
    test('stages list.add through apply and commits atomically', () async {
      final list = TissueList<int>();
      final events = <TxApplyEvent>[];
      final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

      await tx.execute(
          participants: [list],
          body: (tx) {
            expect(list.toList(), isEmpty);
            list.apply(list.add, positionalArguments: [1], tx: tx);
            list.apply(list.add, positionalArguments: [2], tx: tx);
            expect(list.toList(), isEmpty); // staged, not applied until commit
          });

      expect(list.toList(), [1, 2]);
      expect(events.whereType<TxApplyBegun>(), isNotEmpty);
      expect(events.whereType<TxApplyStaged>().length, 2);
      expect(events.whereType<TxApplyCommitted>(), isNotEmpty);
    });

    test('apply with tx returns null and does not mutate before commit',
        () async {
      final list = TissueList<int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [list],
          body: (tx) {
            final result =
                list.apply(list.add, positionalArguments: [7], tx: tx);
            expect(result, isNull);
            expect(list.toList(), isEmpty);
          });

      expect(list.toList(), [7]);
    });

    test('body failure rolls back staged mutations', () async {
      final list = TissueList<int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [list],
            body: (tx) {
              list.apply(list.add, positionalArguments: [1], tx: tx);
              list.apply(list.add, positionalArguments: [2], tx: tx);
              throw StateError('boom');
            }),
        throwsStateError,
      );

      expect(list.toList(), isEmpty);
    });

    test('compensates unexecuted stages with compensateIfNotExecuted',
        () async {
      final list = TissueList<int>();
      final tx = Cell.txApply(
        const TxApplyOptions(compensateIfNotExecuted: true),
      );

      await tx.begin([list]);
      tx.enqueue(
        list,
        list.add,
        [1],
        null,
        compensateCell: list,
        compensateFunction: list.remove,
        compensatePositional: [1],
      );
      await tx.rollback();

      expect(list.toList(), isEmpty);
    });

    test('rejects functions outside the modifiable whitelist at enqueue',
        () async {
      final list = TissueList<int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [list],
            body: (tx) {
              list.apply(list.contains, positionalArguments: [1], tx: tx);
            }),
        throwsA(isA<TxApplyException>()),
      );

      expect(list.toList(), isEmpty);
    });

    test('enqueued compensation commits when the staged apply succeeds',
        () async {
      final list = TissueList<int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [list],
          body: (tx) {
            list.apply(
              list.add,
              positionalArguments: [5],
              tx: tx,
              compensate: list.remove,
              compensatePositional: [5],
            );
          });

      expect(list.toList(), [5]);
    });
  });
}
