// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

Future<TissueQueue<T>> resolveDeputy<T>(TissueQueue<T> source) async {
  final result = source.deputy();
  return result is Future<TissueQueue<T>> ? await result : result;
}

void main() {
  group('TissueQueue factories', () {
    test('primary factory creates an empty reactive queue', () {
      final queue = TissueQueue<int>();

      expect(queue.runtimeType.toString(), contains('TissueQueue'));
      expect(queue.toList(), isEmpty);
      expect(queue.length, 0);
      expect(queue.isEmpty, isTrue);
      expect(queue.isNotEmpty, isFalse);
    });

    test('of factory populates from an iterable', () {
      final queue = TissueQueue.of([1, 2, 3]);

      expect(queue.toList(), [1, 2, 3]);
    });

    test('capacity bounds the queue', () {
      final queue = TissueQueue<int>(capacity: 2);

      queue.addAll([1, 2, 3]);
      expect(queue.toList(), [2, 3]);
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueQueueNucleus.create<int, TissueQueue<int>>();
      final queue = TissueQueue.fromNucleus(nucleus, elements: [7, 8]);

      expect(queue.toList(), [7, 8]);
    });

    test('create builds a queue from explicit parameters', () {
      final queue = TissueQueue.create<int, TissueQueue<int>>(elements: [3, 4]);

      expect(queue.toList(), [3, 4]);
    });
  });

  group('TissueQueue read operations', () {
    late TissueQueue<int> queue;

    setUp(() {
      queue = TissueQueue.of([1, 2, 3]);
    });

    test('first, last, length and contains', () {
      expect(queue.first, 1);
      expect(queue.last, 3);
      expect(queue.length, 3);
      expect(queue.contains(2), isTrue);
      expect(queue.contains(9), isFalse);
    });

    test('toList preserves FIFO order', () {
      expect(queue.toList(), [1, 2, 3]);
    });

    test('cast converts element type', () {
      final cast = queue.cast<num>();

      expect(cast.toList(), [1, 2, 3]);
    });

    test('structural equality and toString', () {
      final same = TissueQueue.of([1, 2, 3]);

      expect(queue == queue, isTrue);
      expect(queue == same, isTrue);
      expect(identical(queue, 42), isFalse);
      expect(queue.hashCode, same.hashCode);
      expect(queue.toString(), contains('1'));
    });

    test('cell metadata', () {
      expect(queue.validate, same(TestTissue.allowAll));
      expect(queue.context, Context.system);
      expect(queue.modifiable, contains(queue.add));
    });
  });

  group('TissueQueue mutations', () {
    test('add, addFirst and addLast insert elements', () {
      final queue = TissueQueue<int>();

      queue.add(1);
      queue.addLast(3);
      queue.addFirst(0);
      queue.add(2);
      expect(queue.toList(), [0, 1, 3, 2]);
    });

    test('addAll appends elements', () {
      final queue = TissueQueue.of([1]);

      queue.addAll([2, 3]);
      expect(queue.toList(), [1, 2, 3]);
    });

    test('remove returns true only when present', () {
      final queue = TissueQueue.of([1, 2, 3]);

      expect(queue.remove(2), isTrue);
      expect(queue.remove(99), isFalse);
      expect(queue.toList(), [1, 3]);
    });

    test('removeFirst and removeLast return removed elements', () {
      final queue = TissueQueue.of([1, 2, 3]);

      expect(queue.removeFirst(), 1);
      expect(queue.removeLast(), 3);
      expect(queue.toList(), [2]);
    });

    test('removeWhere and retainWhere filter elements', () {
      final queue = TissueQueue.of([1, 2, 3, 4]);

      queue.removeWhere((e) => e.isOdd);
      expect(queue.toList(), [2, 4]);

      queue.retainWhere((e) => e == 2);
      expect(queue.toList(), [2]);
    });

    test('clear empties the queue', () {
      final queue = TissueQueue.of([1, 2, 3]);

      queue.clear();
      expect(queue.toList(), isEmpty);
    });

    test('apply gateway dispatches whitelisted functions', () {
      final queue = TissueQueue<int>();

      final added = queue.apply(queue.add, positionalArguments: [9]);
      expect(added, isNotNull);
      expect(queue.toList(), [9]);
    });

    test('single-element batch mutations notify', () {
      final queue = TissueQueue.of([1, 2]);

      queue.addAll([3]);
      expect(queue.toList(), [1, 2, 3]);

      queue.removeWhere((e) => e == 3);
      expect(queue.toList(), [1, 2]);

      queue.retainWhere((e) => e == 1);
      expect(queue.toList(), [1]);
    });

    test('adding Cell values establishes reactive links', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final queue = TissueQueue<Cell>();

      queue.add(cell);
      queue.addFirst(cell);
      queue.addLast(cell);
      expect(queue.length, 3);

      queue.removeFirst();
      queue.removeLast();
      queue.removeFirst();
      expect(queue.toList(), isEmpty);
    });
  });

  group('TissueQueueNucleus factories', () {
    test('create returns a reusable blueprint', () {
      final nucleus = TissueQueueNucleus.create<int, TissueQueue<int>>();

      final queue = TissueQueue.fromNucleus(nucleus, elements: [1]);
      expect(queue.toList(), [1]);
    });

    test('clone produces an independent nucleus', () {
      final nucleus = TissueQueueNucleus.create<int, TissueQueue<int>>();
      final clone = nucleus.clone;

      final queue = TissueQueue.fromNucleus(clone, elements: [2, 3]);
      expect(queue.toList(), [2, 3]);
    });

    test('evolve produces a deputy nucleus', () {
      final principal = TissueQueueNucleus.create<int, TissueQueue<int>>();
      final evolved = TissueQueueNucleus<int>.evolve(
        principal: principal,
        testRule: TestTissue<int, TissueQueue<int>>(
          (object, {host, arguments, user}) => (object as int) > 0,
        ),
      );

      expect(evolved, isA<TissueQueueNucleus<int>>());
    });
  });

  group('TissueQueue.unmodifiable', () {
    late TissueQueue<int> source;

    setUp(() {
      source = TissueQueue.of([1, 2, 3]);
    });

    test('unmodifiable getter returns a read-only view', () {
      final view = source.unmodifiable;

      expect(view.runtimeType.toString(), contains('UnmodifiableTissueQueue'));
      expect(view.toList(), [1, 2, 3]);
      expect(view.modifiable.toList(), isEmpty);
      expect(identical(view, view.unmodifiable), isTrue);
    });

    test('unmodifiable view cast preserves elements', () {
      final view = source.unmodifiable;

      expect(view.cast<num>().toList(), [1, 2, 3]);
    });

    test('unmodifiable view rejects mutations', () {
      final view = source.unmodifiable;

      view.add(9);
      view.addFirst(0);
      view.addLast(9);
      expect(view.remove(1), isFalse);
      expect(() => view.removeFirst(), throwsUnsupportedError);
      expect(() => view.removeLast(), throwsUnsupportedError);
      expect(view.toList(), [1, 2, 3]);
    });

    test('standalone UnmodifiableTissueQueue factory', () {
      final u = UnmodifiableTissueQueue<int>([1, 2, 3]);

      expect(u.toList(), [1, 2, 3]);
      expect(u.modifiable.toList(), isEmpty);
      expect(u == u, isTrue);
      expect(identical(u, 42), isFalse);
      expect(u.toString(), contains('1'));
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueQueueNucleus.create<int, TissueQueue<int>>();
      final u =
          UnmodifiableTissueQueue<int>.fromNucleus(nucleus, elements: [9, 10]);

      expect(u.toList(), [9, 10]);
    });

    test('create factory', () {
      final u = UnmodifiableTissueQueue.create<int, TissueQueue<int>>(
        elements: [11, 12],
      );

      expect(u.toList(), [11, 12]);
    });
  });

  group('TissueQueue.deputy', () {
    test('deputy shares principal storage and equality', () async {
      final source = TissueQueue.of([1, 2]);
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(deputy.toList(), [1, 2]);
      expect(deputy == source, isTrue);
      expect(source == deputy, isTrue);
    });

    test('nested deputies', () async {
      final source = TissueQueue.of([1, 2]);
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(nested.toList(), [1, 2]);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = TissueQueue.of([1, 2]);
      final view = source.unmodifiable;
      final deputy = await resolveDeputy(view);

      expect(deputy.toList(), [1, 2]);
    });
  });

  group('ModifiableQueueAsync', () {
    test('async add and addAll', () async {
      final queue = TissueQueue<int>();
      final async = queue.async;

      expect(async, isA<ModifiableQueueAsync<int>>());
      await async.add(1);
      await async.addAll([2, 3]);
      await async.addFirst(0);
      await async.addLast(4);
      expect(queue.toList(), [0, 1, 2, 3, 4]);
    });

    test('async remove and clear', () async {
      final queue = TissueQueue.of([1, 2, 3]);
      final async = queue.async;

      expect(await async.remove(2), isTrue);
      await async.removeFirst();
      await async.removeLast();
      await async.clear();
      expect(queue.toList(), isEmpty);
    });

    test('unmodifiable async facade rejects mutations', () async {
      final view = TissueQueue.of([1]).unmodifiable;
      final async = view.async;

      await expectLater(async.add(9), throwsUnsupportedError);
      await expectLater(async.addAll([9]), throwsUnsupportedError);
      await expectLater(async.addFirst(9), throwsUnsupportedError);
      await expectLater(async.addLast(9), throwsUnsupportedError);
      await expectLater(
        async.apply(view.add, positionalArguments: [9]),
        throwsUnsupportedError,
      );
      await expectLater(async.clear(), throwsUnsupportedError);
      await expectLater(async.remove(1), throwsUnsupportedError);
      await expectLater(async.removeFirst(), throwsUnsupportedError);
      await expectLater(async.removeLast(), throwsUnsupportedError);
      await expectLater(async.removeWhere((e) => true), throwsUnsupportedError);
      await expectLater(async.retainWhere((e) => true), throwsUnsupportedError);
    });
  });

  group('TissueQueue.apply + Cell.txApply integration', () {
    test('stages queue.add through apply and commits atomically', () async {
      final queue = TissueQueue<int>();
      final events = <TxApplyEvent>[];
      final tx = Cell.txApply(TxApplyOptions(onEvent: events.add));

      await tx.execute(
          participants: [queue],
          body: (tx) {
            expect(queue.toList(), isEmpty);
            queue.apply(queue.add, positionalArguments: [1], tx: tx);
            queue.apply(queue.add, positionalArguments: [2], tx: tx);
            expect(queue.toList(), isEmpty); // staged, not applied until commit
          });

      expect(queue.toList(), [1, 2]);
      expect(events.whereType<TxApplyBegun>(), isNotEmpty);
      expect(events.whereType<TxApplyStaged>().length, 2);
      expect(events.whereType<TxApplyCommitted>(), isNotEmpty);
    });

    test('apply with tx returns null and does not mutate before commit',
        () async {
      final queue = TissueQueue<int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [queue],
          body: (tx) {
            final result =
                queue.apply(queue.add, positionalArguments: [7], tx: tx);
            expect(result, isNull);
            expect(queue.toList(), isEmpty);
          });

      expect(queue.toList(), [7]);
    });

    test('body failure rolls back staged mutations', () async {
      final queue = TissueQueue<int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [queue],
            body: (tx) {
              queue.apply(queue.add, positionalArguments: [1], tx: tx);
              queue.apply(queue.add, positionalArguments: [2], tx: tx);
              throw StateError('boom');
            }),
        throwsStateError,
      );

      expect(queue.toList(), isEmpty);
    });

    test('compensates unexecuted stages with compensateIfNotExecuted',
        () async {
      final queue = TissueQueue<int>();
      final tx = Cell.txApply(
        const TxApplyOptions(compensateIfNotExecuted: true),
      );

      await tx.begin([queue]);
      tx.enqueue(
        queue,
        queue.add,
        [1],
        null,
        compensateCell: queue,
        compensateFunction: queue.remove,
        compensatePositional: [1],
      );
      await tx.rollback();

      expect(queue.toList(), isEmpty);
    });

    test('rejects functions outside the modifiable whitelist at enqueue',
        () async {
      final queue = TissueQueue<int>();
      final tx = Cell.txApply();

      await expectLater(
        tx.execute(
            participants: [queue],
            body: (tx) {
              queue.apply(queue.contains, positionalArguments: [1], tx: tx);
            }),
        throwsA(isA<TxApplyException>()),
      );

      expect(queue.toList(), isEmpty);
    });

    test('enqueued compensation commits when the staged apply succeeds',
        () async {
      final queue = TissueQueue<int>();
      final tx = Cell.txApply();

      await tx.execute(
          participants: [queue],
          body: (tx) {
            queue.apply(
              queue.add,
              positionalArguments: [5],
              tx: tx,
              compensate: queue.remove,
              compensatePositional: [5],
            );
          });

      expect(queue.toList(), [5]);
    });
  });
}
