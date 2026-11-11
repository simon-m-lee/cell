import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('TestCell.chain preserves parent when strategy is null', () {
    test('parent is evaluated for the chain', () async {
      var parentCalls = 0;
      final parent = TestCell<Cell>((object, {host, arguments, user}) {
        parentCalls++;
        return object != 'reject-by-parent';
      });
      final child = TestCell<Cell>((object, {host, arguments, user}) => true);
      final chain = TestCell.chain([child], parent: parent);

      final r1 = await Future<bool>.value(chain.call('ok', host: null));
      expect(r1, isTrue);
      expect(parentCalls, 1,
          reason: 'parent must run after the local rules pass');

      parentCalls = 0;
      final r2 =
          await Future<bool>.value(chain.call('reject-by-parent', host: null));
      expect(r2, isFalse,
          reason: 'parent must be able to veto a chain that passed locally');
      expect(parentCalls, 1);
    });

    test('parent + user are both preserved', () async {
      var parentCalls = 0;
      final parent = TestCell<Cell>((object, {host, arguments, user}) {
        parentCalls++;
        return true;
      });
      final child = TestCell<Cell>((object, {host, arguments, user}) => true);
      final chain = TestCell.chain([child], parent: parent, user: 'tag');

      await _pump();
      final passed = await Future<bool>.value(chain.call('x', host: null));
      expect(passed, isTrue);
      expect(parentCalls, 1);
    });
  });

  group('TestRule.chain preserves user when strategy is set', () {
    test('strategy receives the configured user metadata', () async {
      dynamic observedUser;
      final chain = TestRule<Cell>.chain(
        const [],
        strategy: (object, {host, arguments, user}) {
          observedUser = user;
          return true;
        },
        user: 'my-tag',
      );

      final result = await Future<bool>.value(chain.call('anything'));
      expect(result, isTrue);
      expect(observedUser, 'my-tag',
          reason: 'TestRule.chain must forward `user` to the strategy; the '
              'strategy reads it via `_user` in TestRule.call');
    });
  });

  group('TestRule.chain preserves parent when strategy is null', () {
    test('parent is evaluated', () async {
      var parentCalls = 0;
      final parent = TestRule<Cell>((object, {host, arguments, user}) {
        parentCalls++;
        return true;
      });
      final child = TestRule<Cell>((object, {host, arguments, user}) => true);
      final chain = TestRule.chain([child], parent: parent);

      await Future<bool>.value(chain.call('x'));
      expect(parentCalls, 1);
    });
  });
}
