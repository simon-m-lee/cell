// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

// Regression coverage for https://github.com/simon-m-lee/cell/issues/4:
// `TestTissue` rules are `FutureOr<bool>`, but the tissue mutation dispatch
// used to compare an async rule's `Future` with `== true` and silently
// dropped every mutation. The `.async` facade and the `apply` gateway now
// await async verdicts, and the synchronous mutation surface throws
// `UnsupportedError` instead of dropping user data.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

TestTissue<int, TissueList<int>> _asyncNonNegativeListRule() =>
    TestTissue<int, TissueList<int>>(
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    );

TestTissue<int, TissueSet<int>> _asyncNonNegativeSetRule() =>
    TestTissue<int, TissueSet<int>>(
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    );

TestTissue<int, TissueMap<String, int>> _asyncNonNegativeMapRule() =>
    TestTissue<int, TissueMap<String, int>>(
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    );

TestTissue<int, TissueQueue<int>> _asyncNonNegativeQueueRule() =>
    TestTissue<int, TissueQueue<int>>(
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    );

TestTissue<int, TissueValue<int>> _asyncNonNegativeValueRule() =>
    TestTissue<int, TissueValue<int>>(
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    );

void main() {
  group('async TestTissue rules on TissueList', () {
    test('issue repro: async.add applies the mutation before completing',
        () async {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      await list.async.add(1);
      expect(list.length, 1);
      expect(list.first, 1);
    });

    test('async.add rejects elements that fail the async rule', () async {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      await list.async.add(-1);
      expect(list, isEmpty);
    });

    test('async.add completes only after the rule resolves', () async {
      final gate = Completer<bool>();
      final list = TissueList<int>(
        testRule: TestTissue<int, TissueList<int>>(
          (v, {host, arguments, user}) => gate.future,
        ),
      );
      final pending = list.async.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(list, isEmpty, reason: 'mutation must wait for the rule');
      gate.complete(true);
      await pending;
      expect(list.toList(), [1]);
    });

    test('sync add throws UnsupportedError instead of silently dropping', () {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      expect(() => list.add(1), throwsUnsupportedError);
      expect(list, isEmpty);
    });

    test('sync batch addAll throws before partially applying anything', () {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      expect(() => list.addAll([1, 2, 3]), throwsUnsupportedError);
      expect(list, isEmpty);
    });

    test('async.addAll applies permitted elements in order', () async {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      await list.async.addAll([1, -2, 3, -4]);
      expect(list.toList(), [1, 3]);
    });

    test('async.remove applies the rule and reports the outcome', () async {
      final list =
          TissueList<int>.of([1, 2], testRule: _asyncNonNegativeListRule());
      expect(await list.async.remove(2), isTrue);
      expect(list.toList(), [1]);
      expect(await list.async.remove(9), isFalse);
    });

    test('async.removeAt applies the rule before removing', () async {
      final list =
          TissueList<int>.of([1, 2], testRule: _asyncNonNegativeListRule());
      await list.async.removeAt(0);
      expect(list.toList(), [2]);
    });

    test('async.removeAt throws UnsupportedError when the rule rejects',
        () async {
      final list = TissueList<int>.of([1],
          testRule: TestTissue<int, TissueList<int>>(
            (v, {host, arguments, user}) async => false,
          ));
      await expectLater(list.async.removeAt(0), throwsUnsupportedError);
      expect(list.toList(), [1]);
    });

    test('apply gateway awaits async rules', () async {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());

      final accepted = await list.apply<dynamic>((
        function: list.add,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
      expect(accepted, isA<ApplyAccepted<dynamic>>());
      expect(list.toList(), [1]);

      final rejected = await list.apply<dynamic>((
        function: list.add,
        arguments: (positionalArguments: [-1], namedArguments: null),
        compensation: null,
      ));
      expect(rejected, isA<ApplyRejected<dynamic>>());
      expect(list.toList(), [1]);
    });

    test('txApply commit awaits async rules', () async {
      final list = TissueList<int>(testRule: _asyncNonNegativeListRule());
      final tx = Cell.txApply();

      await tx.execute(
        participants: [list],
        body: (tx) {
          list.apply<dynamic>((
            function: list.add,
            arguments: (positionalArguments: [7], namedArguments: null),
            compensation: null,
          ), tx: tx);
          expect(list, isEmpty); // staged until commit
        },
      );

      expect(list.toList(), [7]);
    });

    test('sync setValueAt throws UnsupportedError with an async rule', () {
      final list =
          TissueList<int>.of([0], testRule: _asyncNonNegativeListRule());
      expect(() => list.setValueAt(0, 1), throwsUnsupportedError);
      expect(list.toList(), [0]);
    });
  });

  group('async TestTissue rules on TissueSet', () {
    test('async.add applies the rule before completing', () async {
      final set =
          TissueSet<int>(const [], testRule: _asyncNonNegativeSetRule());
      await set.async.add(1);
      expect(set, contains(1));
      await set.async.add(-1);
      expect(set, isNot(contains(-1)));
    });

    test('sync add throws UnsupportedError instead of silently dropping', () {
      final set =
          TissueSet<int>(const [], testRule: _asyncNonNegativeSetRule());
      expect(() => set.add(1), throwsUnsupportedError);
      expect(set, isEmpty);
    });
  });

  group('async TestTissue rules on TissueMap', () {
    test('async.put applies the rule before completing', () async {
      final map = TissueMap.create<String, int, TissueMap<String, int>>(
        testRule: _asyncNonNegativeMapRule(),
      );
      await map.async.put('a', 1);
      expect(map['a'], 1);
      await map.async.put('b', -1);
      expect(map.containsKey('b'), isFalse);
    });

    test('sync put throws UnsupportedError instead of silently dropping', () {
      final map = TissueMap.create<String, int, TissueMap<String, int>>(
        testRule: _asyncNonNegativeMapRule(),
      );
      expect(() => map.put('a', 1), throwsUnsupportedError);
      expect(map, isEmpty);
    });

    test('async.update awaits the rule and returns the new value', () async {
      final map = TissueMap.create<String, int, TissueMap<String, int>>(
        testRule: _asyncNonNegativeMapRule(),
      );
      await map.async.put('a', 1);
      expect(await map.async.update('a', (v) => v + 1), 2);
      expect(map['a'], 2);
    });
  });

  group('async TestTissue rules on TissueQueue', () {
    test('async.add applies the rule before completing', () async {
      final queue = TissueQueue<int>(testRule: _asyncNonNegativeQueueRule());
      await queue.async.add(1);
      expect(queue, contains(1));
      expect(queue.length, 1);
    });

    test('sync add throws UnsupportedError instead of silently dropping', () {
      final queue = TissueQueue<int>(testRule: _asyncNonNegativeQueueRule());
      expect(() => queue.add(1), throwsUnsupportedError);
      expect(queue, isEmpty);
    });

    test('async.removeFirst awaits the rule and returns the element', () async {
      final queue = TissueQueue<int>(testRule: _asyncNonNegativeQueueRule());
      await queue.async.add(1);
      expect(await queue.async.removeFirst(), 1);
      expect(queue, isEmpty);
    });
  });

  group('async TestTissue rules on TissueValue', () {
    test('async.set applies the rule before completing', () async {
      final value = TissueValue<int>(0, testRule: _asyncNonNegativeValueRule());
      expect(await value.async.set(2), isTrue);
      expect(value.value, 2);
      expect(await value.async.set(-1), isFalse);
      expect(value.value, 2);
    });

    test('sync set throws UnsupportedError instead of silently dropping', () {
      final value = TissueValue<int>(0, testRule: _asyncNonNegativeValueRule());
      expect(() => value.set(2), throwsUnsupportedError);
      expect(value.value, 0);
    });
  });
}
