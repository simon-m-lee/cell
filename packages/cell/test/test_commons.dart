// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

void main() {
  group('mapMerge', () {
    test('copies keys that only exist in other', () {
      final merged = mapMerge({'a': 1}, {'b': 2});
      expect(merged, {'a': 1, 'b': 2});
    });

    test('concatenates when both values are iterables', () {
      final merged = mapMerge(
        {
          'tags': ['a'],
        },
        {
          'tags': ['b', 'c'],
        },
      );
      expect(merged['tags'], ['a', 'b', 'c']);
    });

    test('wraps an existing non-iterable when other is iterable', () {
      final merged = mapMerge(
        {'tags': 'a'},
        {
          'tags': ['b'],
        },
      );
      expect(merged['tags'], ['a', 'b']);
    });

    test('appends a scalar onto an existing iterable', () {
      final merged = mapMerge(
        {
          'tags': ['a'],
        },
        {'tags': 'b'},
      );
      expect(merged['tags'], ['a', 'b']);
    });

    test('wraps both scalars into a list when keys collide', () {
      final merged = mapMerge({'k': 1}, {'k': 2});
      expect(merged['k'], [1, 2]);
    });

    test('does not mutate the original maps', () {
      final original = {'a': 1};
      mapMerge(original, {'b': 2});
      expect(original, {'a': 1});
    });
  });

  group('SyncSet', () {
    test('add, contains, length, and lookup', () async {
      final set = SyncSet<String>();
      expect(await set.add('a'), isTrue);
      expect(await set.add('a'), isFalse);
      expect(await set.contains('a'), isTrue);
      expect(await set.contains('missing'), isFalse);
      expect(await set.length, 1);
      expect(await set.lookup('a'), 'a');
      expect(await set.lookup('missing'), isNull);
    });

    test('remove, isEmpty, and isNotEmpty', () async {
      final set = SyncSet<int>();
      expect(await set.isEmpty, isTrue);
      await set.add(1);
      expect(await set.isNotEmpty, isTrue);
      expect(await set.remove(1), isTrue);
      expect(await set.remove(1), isFalse);
      expect(await set.isEmpty, isTrue);
    });

    test('addAll, toSet, toList, replicate, and iterator', () async {
      final set = SyncSet<int>();
      await set.addAll([1, 2, 2, 3]);
      expect((await set.toSet()), {1, 2, 3});
      expect(await set.toList(growable: false), unorderedEquals([1, 2, 3]));
      expect(await set.replicate(), {1, 2, 3});
      final it = await set.iterator;
      final walked = <int>[];
      while (it.moveNext()) {
        walked.add(it.current);
      }
      expect(walked, unorderedEquals([1, 2, 3]));
    });

    test('containsAll, intersection, union, and difference', () async {
      final set = SyncSet<String>();
      await set.addAll(['a', 'b', 'c']);
      expect(await set.containsAll(['a', 'c']), isTrue);
      expect(await set.containsAll(['a', 'z']), isFalse);
      expect(await set.intersection({'b', 'z'}), {'b'});
      expect(await set.union({'c', 'd'}), {'a', 'b', 'c', 'd'});
      expect(await set.difference({'a', 'x'}), {'b', 'c'});
    });

    test('removeAll, retainAll, removeWhere, retainWhere, clear', () async {
      final set = SyncSet<int>();
      await set.addAll([1, 2, 3, 4, 5]);
      await set.removeAll([1, 5]);
      expect(await set.toSet(), {2, 3, 4});
      await set.retainAll([2, 4, 9]);
      expect(await set.toSet(), {2, 4});
      await set.addAll([6, 7]);
      await set.removeWhere((e) => e.isEven);
      expect(await set.toSet(), {7});
      await set.addAll([8, 9]);
      await set.retainWhere((e) => e.isOdd);
      expect(await set.toSet(), {7, 9});
      await set.clear();
      expect(await set.isEmpty, isTrue);
    });

    test('map, forEach, and where', () async {
      final set = SyncSet<int>();
      await set.addAll([1, 2, 3]);
      expect(await set.map((e) => e * 10), unorderedEquals([10, 20, 30]));
      final seen = <int>[];
      await set.forEach(seen.add);
      expect(seen, unorderedEquals([1, 2, 3]));
      expect(await set.where((e) => e.isOdd), unorderedEquals([1, 3]));
    });

    test('reduce combines elements', () async {
      final set = SyncSet<int>();
      await set.addAll([1, 2, 3]);
      expect(await set.reduce((a, b) => a + b), 6);
    });
  });

  group('QueueList', () {
    test('constructors and FIFO operations', () {
      final empty = QueueList<int>();
      expect(empty, isEmpty);
      final from = QueueList.from([1, 2]);
      final of = QueueList.of([3]);
      from.add(4);
      from.addFirst(0);
      from.addLast(5);
      from.addAll([6]);
      expect(from.toList(), [0, 1, 2, 4, 5, 6]);
      expect(from.removeFirst(), 0);
      expect(from.removeLast(), 6);
      expect(from.remove(2), isTrue);
      expect(from.contains(1), isTrue);
      expect(of.length, 1);
    });

    test('removeWhere, retainWhere, and clear', () {
      final q = QueueList.of([1, 2, 3, 4]);
      q.removeWhere((e) => e.isEven);
      expect(q.toList(), [1, 3]);
      q.retainWhere((e) => e == 3);
      expect(q.toList(), [3]);
      q.clear();
      expect(q, isEmpty);
    });

    test('cast and async wrapper', () async {
      final q = QueueList<num>.of([1, 2]);
      final asInt = q.cast<int>();
      expect(asInt, isA<Queue<int>>());
      await q.async.add(3);
      expect(q.toList(), [1, 2, 3]);
    });
  });

  group('AsyncQueueList', () {
    test('mirrors queue mutations under the lock', () async {
      final q = QueueList<String>();
      final asyncQ = AsyncQueueList(q);
      await asyncQ.add('a');
      await asyncQ.addFirst('z');
      await asyncQ.addLast('b');
      await asyncQ.addAll(['c']);
      expect(await asyncQ.toList(), ['z', 'a', 'b', 'c']);
      expect(await asyncQ.removeFirst(), 'z');
      expect(await asyncQ.removeLast(), 'c');
      await asyncQ.remove('a');
      expect(await asyncQ.toList(), ['b']);
    });

    test('toListAndClear, clearAndAdd, removeWhere, retainWhere, clear',
        () async {
      final asyncQ = AsyncQueueList(QueueList.of([1, 2, 3, 4]));
      expect(await asyncQ.toListAndClear(), [1, 2, 3, 4]);
      expect(await asyncQ.toList(), isEmpty);
      await asyncQ.clearAndAdd(9);
      expect(await asyncQ.toList(), [9]);
      await asyncQ.addAll([1, 2, 3]);
      await asyncQ.removeWhere((e) => e == 9);
      await asyncQ.retainWhere((e) => e.isOdd);
      expect(await asyncQ.toList(), [1, 3]);
      await asyncQ.clear();
      expect(await asyncQ.toList(), isEmpty);
    });

    test('iterator and cast', () async {
      final asyncQ = AsyncQueueList(QueueList.of([1, 2]));
      final it = await asyncQ.iterator;
      expect(it.moveNext(), isTrue);
      expect(it.current, 1);
      final cast = await asyncQ.cast<int>();
      expect(cast, isA<Queue<int>>());
    });
  });

  group('PriorityQueue', () {
    test('extracts the smallest element first with a comparator', () {
      final q = PriorityQueue<int>((a, b) => a.compareTo(b));
      q.addAll([50, 10, 100, 5]);
      expect(q.length, 4);
      expect(q.isNotEmpty, isTrue);
      expect(q.first, 5);
      expect(q.removeFirst(), 5);
      expect(q.removeFirst(), 10);
      expect(q.removeFirst(), 50);
      expect(q.removeFirst(), 100);
      expect(q.isEmpty, isTrue);
    });

    test('uses Comparable when no comparator is provided', () {
      final q = PriorityQueue<int>();
      q.add(3);
      q.add(1);
      q.add(2);
      expect(q.removeFirst(), 1);
      expect(q.removeFirst(), 2);
      expect(q.removeFirst(), 3);
    });

    test('addFirst and addLast still rank by priority', () {
      final q = PriorityQueue<int>();
      q.addFirst(8);
      q.addLast(2);
      q.add(5);
      expect(q.removeFirst(), 2);
    });

    test('remove, removeWhere, retainWhere, and clear', () {
      final q = PriorityQueue<int>();
      q.addAll([1, 2, 3, 4, 5]);
      expect(q.remove(3), isTrue);
      expect(q.remove(99), isFalse);
      expect(q.contains(1), isTrue);
      q.removeWhere((e) => e.isEven);
      expect(q.toList(), unorderedEquals([1, 5]));
      q.retainWhere((e) => e == 5);
      expect(q.toList(), [5]);
      q.clear();
      expect(q, isEmpty);
    });

    test('empty buffer throws on extract', () {
      final q = PriorityQueue<int>();
      expect(() => q.removeFirst(), throwsStateError);
      expect(() => q.first, throwsStateError);
      expect(() => q.removeLast(), throwsStateError);
    });

    test('removeLast pops a leaf and iterator walks the heap', () {
      final q = PriorityQueue<int>();
      q.addAll([4, 1, 3]);
      final last = q.last;
      expect(q.removeLast(), last);
      expect(q.iterator, isA<Iterator<int>>());
    });
  });

  group('AsyncPriorityQueue', () {
    test('add, peek, and ranked extract', () async {
      final q = AsyncPriorityQueue(PriorityQueue<int>());
      await q.add(4);
      await q.addFirst(1);
      await q.addLast(2);
      expect(await q.length, 3);
      expect(await q.isNotEmpty, isTrue);
      expect(await q.first, 1);
      expect(await q.removeFirst(), 1);
      expect(await q.contains(4), isTrue);
      expect(await q.remove(4), isTrue);
    });

    test('addAll, map, toList, toSet, reduce, forEach, replicate', () async {
      final q = AsyncPriorityQueue(PriorityQueue<int>());
      await q.addAll([3, 1, 2]);
      expect(await q.map((e) => e * 2), unorderedEquals([2, 4, 6]));
      expect(await q.toList(), unorderedEquals([3, 1, 2]));
      expect(await q.toSet(), {1, 2, 3});
      expect(await q.reduce((a, b) => a + b), 6);
      final seen = <int>[];
      await q.forEach(seen.add);
      expect(seen, unorderedEquals([1, 2, 3]));
      expect(await q.replicate(), isA<Queue<int>>());
      expect(await q.removeLast(), isA<int>());
      await q.clear();
      expect(await q.isEmpty, isTrue);
    });
  });

  group('SyncQueue', () {
    test('orders by comparison and reports emptiness', () async {
      final q = SyncQueue<int>(comparison: (a, b) => b.compareTo(a));
      await q.add(10);
      await q.add(50);
      expect(await q.removeFirst(), 50);
      expect(await q.isNotEmpty, isTrue);
      expect(await q.first, 10);
    });

    test('of constructor seeds the heap', () async {
      final q = SyncQueue.of([3, 1, 2]);
      expect(await q.length, 3);
      expect(await q.removeFirst(), 1);
    });

    test('capacity rejects overflow on add and addAll', () async {
      final q = SyncQueue<int>(capacity: 1);
      await q.add(1);
      expect(q.add(2), throwsStateError);
      final q2 = SyncQueue<int>(capacity: 1);
      expect(q2.addAll([1, 2]), throwsStateError);
    });

    test('addFirst, addLast, remove, map, clear', () async {
      final q = SyncQueue<int>();
      await q.addFirst(5);
      await q.addLast(1);
      expect(await q.contains(5), isTrue);
      expect(await q.remove(5), isTrue);
      expect(await q.map((e) => e), [1]);
      expect(await q.toSet(), {1});
      expect(await q.reduce((a, b) => a + b), 1);
      final seen = <int>[];
      await q.forEach(seen.add);
      expect(seen, [1]);
      expect(await q.last, 1);
      await q.clear();
      expect(await q.isEmpty, isTrue);
      expect(await q.replicate(), isEmpty);
    });
  });

  group('Box / SyncBox / FinalBox', () {
    test('Box starts null and accepts mutation', () {
      final box = Box<int>();
      expect(box.value, isNull);
      box.value = 7;
      expect(box.value, 7);
      final seeded = Box<String>('hi');
      expect(seeded.value, 'hi');
    });

    test('SyncBox serializes get and set', () async {
      final box = Box<int>(0);
      final sync = box.async;
      await sync.set(9);
      expect(await sync.state, 9);
      expect(box.value, 9);
    });

    test('FinalBox is write-once', () {
      final box = FinalBox<String>();
      box.value = 'NODE_1';
      expect(box.value, 'NODE_1');
      expect(() => box.value = 'NODE_2', throwsA(isA<Error>()));
    });

    test('FinalBox.async is a SyncBox', () async {
      final box = FinalBox<int>();
      expect(box.async, isA<SyncBox<int>>());
      await box.async.set(3);
      expect(box.value, 3);
    });
  });

  group('TypeObject / FunctionObject / get', () {
    test('TypeObject wraps a value', () {
      const wrapped = TypeObject<int>(4);
      expect(wrapped.obj, 4);
    });

    test('FunctionTypeObject evaluates lazily', () {
      var calls = 0;
      final lazy = FunctionTypeObject<int>(() {
        calls++;
        return 11;
      });
      expect(calls, 0);
      expect(lazy.obj, 11);
      expect(lazy.obj, 11);
      expect(calls, 2);
    });

    test('FunctionObject stores a record', () {
      int fn() => 1;
      final wrapped = FunctionObject(fn);
      expect(wrapped.record, fn);
    });

    test('get returns the primary value', () {
      expect(get<int>(() => 4), 4);
    });

    test('get uses fallback when primary throws', () {
      expect(
        get<int>(() => throw StateError('x'), fallback: () => 8),
        8,
      );
    });

    test('get uses orElse when primary and fallback throw', () {
      expect(
        get<int>(
          () => throw StateError('x'),
          fallback: () => throw StateError('y'),
          orElse: 3,
        ),
        3,
      );
    });

    test('get rethrows the original error when orElse cannot satisfy T', () {
      expect(
        () => get<int>(() => throw FormatException('bad')),
        throwsFormatException,
      );
    });
  });

  group('marker types', () {
    test('Async and Unmodifiable are usable as type checks', () {
      expect(Box<int>().async, isA<SyncBox<int>>());
      final cell = ValueCell<int>(initial: 0);
      expect(cell.unmodifiable, isA<Unmodifiable>());
    });
  });
}
