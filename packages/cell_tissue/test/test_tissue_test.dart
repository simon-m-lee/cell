// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

class _AsyncElementRule extends TestElementRule<int, TissueList<int>> {
  _AsyncElementRule()
      : super((e, {required host, action, user}) => true);

  @override
  FutureOr<bool> element(int? element, {required TissueList<int> host, Function? action}) async {
    return element != null && element > 0;
  }
}

void main() {
  group('TestTissue sentinel policies', () {
    test('allowAll authorises every vector', () async {
      final allow = TestTissue.allowAll;
      final list = TissueList.of([1]);
      final other = TissueList<int>();

      expect(identical(allow, TestTissue.allowAll), isTrue);
      expect(TestTissue.unlimitedLength, -1);

      expect(await allow.action(list.add, host: list), isTrue);
      expect(await allow.call(1, host: list), isTrue);
      expect(await allow.element(1, host: list, action: list.add), isTrue);
      expect(await allow.link(other, host: list), isFalse);
      expect(await allow.pulse(Pulse(1), host: list), isTrue);
    });

    test('allowAll + other delegates to the other rule', () async {
      final delegate = TestTissue<Never, Never>(
        (object, {Never? host, dynamic arguments, dynamic user}) =>
            identical(object, 'yes'),
      );
      final combined = TestTissue.allowAll + delegate;

      expect(combined, isA<TestTissue<Never, Never>>());
      expect(await combined.call('yes', host: null), isTrue);
      expect(await combined.call('no', host: null), isFalse);
    });

    test('readOnly blocks modifiable actions but allows reads', () async {
      final readonly = TestTissue.readOnly;
      final list = TissueList.of([1]);

      expect(identical(readonly, TestTissue.readOnly), isTrue);

      // Modifiable function is blocked (returns false).
      expect(await readonly.action(list.add, host: list), isFalse);
      // Non-modifiable function passes.
      expect(await readonly.action(list.contains, host: list), isTrue);

      // call() routes functions through action().
      expect(await readonly.call(list.add, host: list), isFalse);
      // Non-function objects always pass.
      expect(await readonly.call('x', host: list), isTrue);
    });

    test('readOnly + other delegates to the other rule', () async {
      final positive = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value > 0,
      );
      final combined = TestTissue.readOnly + positive;

      expect(combined, isA<TestTissue<Never, Never>>());
      expect(await (combined as dynamic).call(1, host: null), isTrue);
      expect(await (combined as dynamic).call(-1, host: null), isFalse);
    });
  });

  group('TestTissue rule policies', () {
    test('call routes element objects with function arguments to element()', () async {
      final rule = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value > 0,
      );
      final list = TissueList<int>();

      expect(await rule.call(1, host: list, arguments: list.add), isTrue);
      expect(await rule.call(-1, host: list, arguments: list.add), isFalse);
    });

    test('call falls back to super when arguments are not a Function', () async {
      final rule = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value is! int || value > 0,
      );
      final list = TissueList<int>();

      // object is E but arguments is null -> super.call path.
      expect(await rule.call(1, host: list, arguments: null), isTrue);
      // object is not E -> super.call path.
      expect(await rule.call('x', host: list, arguments: list.add), isTrue);
    });

    test('single-rule policy evaluates through element()', () async {
      final rule = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value != 42,
      );
      final list = TissueList<int>();

      expect(await rule.element(1, host: list), isTrue);
      expect(await rule.element(42, host: list), isFalse);
    });

    test('operator + composes policies with short-circuit order', () async {
      final positive = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value > 0,
      );
      final even = TestTissue<int, TissueList<int>>(
        (value, {host, arguments, user}) => value.isEven,
      );
      final combo = positive + even;
      final list = TissueList<int>();

      expect(combo, isA<TestTissue<int, TissueList<int>>>());
      expect(await combo.element(2, host: list), isTrue);
      expect(await combo.element(1, host: list), isFalse);
      expect(await combo.element(-2, host: list), isFalse);
    });
  });

  group('TestTissue.chain pipelines', () {
    test('sync chain evaluates in order and short-circuits', () async {
      final rules = <TestRule<TissueList<int>>>[
        TestElementRule<int, TissueList<int>>(
          (e, {required host, action, user}) => (e ?? 0) > 0,
        ),
        TestElementRule<int, TissueList<int>>(
          (e, {required host, action, user}) => (e ?? 0).isEven,
        ),
      ];
      final policy = TestTissue.chain(rules);
      final list = TissueList<int>();

      expect(await policy.element(2, host: list), isTrue);
      expect(await policy.element(1, host: list), isFalse);
      expect(await policy.element(-2, host: list), isFalse);
    });

    test('async chain resumes the remaining rules', () async {
      final rules = <TestRule<TissueList<int>>>[
        _AsyncElementRule(),
        TestElementRule<int, TissueList<int>>(
          (e, {required host, action, user}) => (e ?? 0).isEven,
        ),
      ];
      final policy = TestTissue.chain(rules);
      final list = TissueList<int>();

      expect(await policy.element(2, host: list), isTrue);
      expect(await policy.element(-2, host: list), isFalse);
      expect(await policy.element(1, host: list), isFalse);
    });

    test('chain strategy overrides sequential evaluation', () async {
      final rules = <TestRule<TissueList<int>>>[
        TestElementRule<int, TissueList<int>>(
          (e, {required host, action, user}) => false,
        ),
      ];
      final policy = TestTissue.chain(
        rules,
        strategy: (object, {host, arguments, user}) async => true,
      );
      final list = TissueList<int>();

      expect(await policy.call('x', host: list, arguments: null), isTrue);
    });
  });

  group('TestElementRule', () {
    test('evaluates elements with a function action', () async {
      final rule = TestElementRule<int, TissueList<int>>(
        (e, {required host, action, user}) => (e ?? 0) > 0,
      );
      final list = TissueList<int>();

      expect(await rule.call(1, host: list, arguments: list.add), isTrue);
      expect(await rule.call(-1, host: list, arguments: list.add), isFalse);
    });

    test('bypasses the predicate for non-element objects', () async {
      final rule = TestElementRule<int, TissueList<int>>(
        (e, {required host, action, user}) => (e ?? 0) > 0,
      );
      final list = TissueList<int>();

      // Not an int element -> the wrapper returns true.
      expect(await rule.call('x', host: list, arguments: list.add), isTrue);
      // No host -> the wrapper returns true.
      expect(await rule.call(1, host: null, arguments: list.add), isTrue);
    });

    test('element() delegates to call()', () async {
      final rule = TestElementRule<int, TissueList<int>>(
        (e, {required host, action, user}) => (e ?? 0) > 0,
      );
      final list = TissueList<int>();

      expect(await rule.element(2, host: list), isTrue);
      expect(await rule.element(-2, host: list), isFalse);
    });

    test('action-aware element rule receives the mutation function', () async {
      final seenActions = <Function>[];
      final rule = TestElementRule<int, TissueList<int>>(
        (e, {required host, action, user}) {
          seenActions.add(action as Function);
          return true;
        },
      );
      final list = TissueList<int>();

      await rule.element(1, host: list, action: list.add);
      await rule.call(1, host: list, arguments: list.remove);

      expect(seenActions, [list.add, list.remove]);
    });
  });
}
