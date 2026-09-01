// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

class _AsyncActionRule extends TestActionRule<Cell> {
  final bool allow;
  _AsyncActionRule({this.allow = true})
      : super((action, {required host, arguments, user}) => true);

  @override
  Future<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return allow;
  }
}

class _AsyncLinkRule extends TestLinkRule<Cell> {
  final bool allow;
  _AsyncLinkRule({this.allow = true})
      : super((link, {required host, user}) => true);

  @override
  Future<bool> link(covariant Cell link, {required Cell host}) async {
    await Future<void>.delayed(Duration.zero);
    return allow;
  }
}

class _AsyncPulseRule extends TestPulseRule<Cell> {
  final bool allow;
  _AsyncPulseRule({this.allow = true})
      : super((pulse, {required host, user}) => true);

  @override
  Future<bool> pulse(covariant Pulse pulse, {required Cell host}) async {
    await Future<void>.delayed(Duration.zero);
    return allow;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
//
// [TestCell.call] is the integrity gate the framework uses (pulses, values,
// functions). Specialized [TestPulseRule] / [TestLinkRule] / [TestActionRule]
// are only consulted by [TestCell.pulse] / [link] / [action] when they appear
// in a [TestCell.chain] rules list.
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('TestCell', () {
    group('allowAll', () {
      test('is a reusable TestPasses singleton', () {
        expect(identical(TestCell.allowAll, TestCell.allowAll), isTrue);
        expect(TestCell.allowAll, isA<TestPasses>());
      });

      test('allows every object', () {
        expect(TestCell.allowAll.call(null), isTrue);
        expect(TestCell.allowAll.call(-1), isTrue);
        expect(TestCell.allowAll.call(Pulse<int>(0)), isTrue);
      });

      test('allows links, pulses, and actions', () {
        final host = Cell();
        final other = Cell();
        expect(TestCell.allowAll.link(other, host: host), isTrue);
        expect(TestCell.allowAll.pulse(Pulse<int>(1), host: host), isTrue);
        expect(TestCell.allowAll.action(host.apply, host: host), isTrue);
      });

      test('allowAll + customRule behaves like the custom rule', () {
        final positive = TestCell((object, {host, arguments, user}) {
          return object is int && object > 0;
        });
        final policy = TestCell.allowAll + positive;
        expect(policy.call(5), isTrue);
        expect(policy.call(-1), isFalse);
      });
    });

    group('readOnly', () {
      test('is a reusable singleton', () {
        expect(identical(TestCell.readOnly, TestCell.readOnly), isTrue);
        expect(TestCell.readOnly, isNot(TestCell.allowAll));
        expect(identical(TestCell.readOnly, TestCell.allowAll), isFalse);
      });

      test('allows observation of values and pulses', () {
        final host = Cell();
        expect(TestCell.readOnly.call(42, host: host), isTrue);
        expect(TestCell.readOnly.pulse(Pulse<int>(1), host: host), isTrue);
        expect(TestCell.readOnly.link(Cell(), host: host), isTrue);
      });

      test('blocks apply when the action is on the modifiable whitelist', () {
        final host = Cell();
        expect(host.modifiable.contains(host.apply), isTrue);
        expect(
          TestCell.readOnly.action(host.apply, host: host),
          isFalse,
        );
      });

      test('call on a Function consults action', () {
        final host = Cell();
        expect(TestCell.readOnly.call(host.apply, host: host), isFalse);
        void other() {}
        expect(TestCell.readOnly.call(other, host: host), isTrue);
      });

      test('readOnly + customRule delegates to the custom rule', () {
        final policy = TestCell.readOnly +
            TestCell((object, {host, arguments, user}) {
              return object is int && object > 0;
            });
        expect(policy.call(5), isTrue);
        expect(policy.call(-1), isFalse);
      });

      test('TestPasses is the allowAll implementation', () {
        final host = Cell();
        expect(const TestPasses(), isA<TestCell>());
        expect(const TestPasses().call(null), isTrue);
        expect(const TestPasses().action(host.apply, host: host), isTrue);
        expect(
          const TestPasses().action(
            host.apply,
            host: host,
            arguments: (
              positionalArguments: [1],
              namedArguments: {#k: 2},
            ),
          ),
          isTrue,
        );
      });

      test('readOnly action with arguments still allows non-modifiable tear-offs', () {
        final host = Cell();
        void other() {}
        expect(
          TestCell.readOnly.action(
            other,
            host: host,
            arguments: (
              positionalArguments: [1],
              namedArguments: {#k: 2},
            ),
          ),
          isTrue,
        );
      });
    });

    group('Construction', () {
      test('custom rule allows matching values', () {
        final positive = TestCell((object, {host, arguments, user}) {
          return object is int && object > 0;
        });
        expect(positive.call(1), isTrue);
        expect(positive.call(0), isFalse);
        expect(positive.call(-3), isFalse);
      });

      test('custom rule can inspect a Pulse payload', () {
        final evenPulse = TestCell((object, {host, arguments, user}) {
          if (object is Pulse && object.payload is int) {
            return (object.payload as int).isEven;
          }
          return true;
        });
        expect(evenPulse.call(Pulse<int>(2)), isTrue);
        expect(evenPulse.call(Pulse<int>(3)), isFalse);
        expect(evenPulse.call('ignore'), isTrue);
      });

      test('user metadata is passed to the rule', () {
        dynamic seenUser;
        final rule = TestCell((object, {host, arguments, user}) {
          seenUser = user;
          return true;
        }, user: 'gate');
        rule.call(1);
        expect(seenUser, 'gate');
      });

      test('parent is evaluated after this rule passes', () {
        final stages = <String>[];
        final parent = TestCell((object, {host, arguments, user}) {
          stages.add('parent');
          return object != 99;
        });
        final child = TestCell((object, {host, arguments, user}) {
          stages.add('child');
          return object is int && object > 0;
        }, parent: parent);

        expect(child.call(5), isTrue);
        expect(stages, ['child', 'parent']);

        stages.clear();
        expect(child.call(-1), isFalse);
        expect(stages, ['child']);

        stages.clear();
        expect(child.call(99), isFalse);
        expect(stages, ['child', 'parent']);
      });
    });

    group('Composition', () {
      test('+ evaluates left to right and short-circuits', () {
        final stages = <String>[];
        final positive = TestCell((object, {host, arguments, user}) {
          stages.add('positive');
          return object is int && object > 0;
        });
        final even = TestCell((object, {host, arguments, user}) {
          stages.add('even');
          return object is int && object.isEven;
        });
        final policy = positive + even;

        expect(policy.call(4), isTrue);
        expect(stages, ['positive', 'even']);

        stages.clear();
        expect(policy.call(-2), isFalse);
        expect(stages, ['positive']);

        stages.clear();
        expect(policy.call(3), isFalse);
        expect(stages, ['positive', 'even']);
      });

      test('TestCell.chain is fail-fast like +', () {
        final policy = TestCell.chain([
          TestCell((object, {host, arguments, user}) => object is int && object > 0),
          TestCell((object, {host, arguments, user}) => object is int && object < 10),
        ]);
        expect(policy.call(5), isTrue);
        expect(policy.call(0), isFalse);
        expect(policy.call(11), isFalse);
      });

      test('chains nest', () {
        final a = TestCell((object, {host, arguments, user}) => object is int);
        final b = TestCell((object, {host, arguments, user}) => object is int && object >= 0);
        final c = TestCell((object, {host, arguments, user}) => object is int && object <= 10);
        final policy = (a + b) + c;
        expect(policy.call(7), isTrue);
        expect(policy.call(-1), isFalse);
        expect(policy.call(11), isFalse);
      });
    });

    group('Exceptions', () {
      test('a throwing rule passes when the host is ungoverned', () {
        final rule = TestCell((object, {host, arguments, user}) {
          throw Exception('bad rule');
        });
        final host = Cell();
        expect(host.isGoverned, isFalse);
        expect(rule.call(1, host: host), isTrue);
      });

      test('a throwing rule with no host passes', () {
        final rule = TestCell((object, {host, arguments, user}) {
          throw Exception('bad rule');
        });
        expect(rule.call(1), isTrue);
      });
    });

    group('Async', () {
      test('an async rule is awaited', () async {
        final rule = TestCell((object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration.zero);
          return object is int && object > 0;
        });
        expect(await rule.call(5), isTrue);
        expect(await rule.call(-1), isFalse);
      });
    });

    group('TestPulseRule', () {
      test('accepts pulses that match the predicate', () {
        final rule = TestPulseRule<Cell>((pulse, {required host, user}) {
          return pulse.payload is int && (pulse.payload as int) > 0;
        });
        final host = Cell();
        expect(rule.pulse(Pulse<int>(5), host: host), isTrue);
        expect(rule.pulse(Pulse<int>(-1), host: host), isFalse);
      });

      test('non-pulse objects pass the wrapped call', () {
        final rule = TestPulseRule<Cell>((pulse, {required host, user}) => false);
        expect(rule.call(42, host: Cell()), isTrue);
      });

      test('TestCell.pulse consults chained TestPulseRules', () {
        final pulseRule = TestPulseRule<Cell>((pulse, {required host, user}) {
          return pulse.priority >= 50;
        });
        final policy = TestCell.chain([pulseRule]);
        final host = Cell();
        expect(policy.pulse(Pulse<int>(1, priority: 60), host: host), isTrue);
        expect(policy.pulse(Pulse<int>(1, priority: 10), host: host), isFalse);
      });

      test('TestCell.pulse awaits chained async TestPulseRules', () async {
        final host = Cell();
        final policy = TestCell.chain([
          _AsyncPulseRule(allow: true),
          _AsyncPulseRule(allow: true),
        ]);
        expect(await policy.pulse(Pulse<int>(1), host: host), isTrue);

        final denied = TestCell.chain([
          _AsyncPulseRule(allow: true),
          _AsyncPulseRule(allow: false),
        ]);
        expect(await denied.pulse(Pulse<int>(1), host: host), isFalse);
      });
    });

    group('TestLinkRule', () {
      test('accepts links that match the predicate', () {
        final allowed = Cell();
        final rule = TestLinkRule<Cell>((link, {required host, user}) {
          return identical(link, allowed);
        });
        final host = Cell();
        expect(rule.link(allowed, host: host), isTrue);
        expect(rule.link(Cell(), host: host), isFalse);
      });

      test('TestCell.link consults chained TestLinkRules', () {
        final allowed = Cell();
        final linkRule = TestLinkRule<Cell>((link, {required host, user}) {
          return identical(link, allowed);
        });
        final policy = TestCell.chain([linkRule]);
        final host = Cell();
        expect(policy.link(allowed, host: host), isTrue);
        expect(policy.link(Cell(), host: host), isFalse);
      });

      test('TestCell.link awaits chained async TestLinkRules', () async {
        final host = Cell();
        final other = Cell();
        final policy = TestCell.chain([
          _AsyncLinkRule(allow: true),
          _AsyncLinkRule(allow: true),
        ]);
        expect(await policy.link(other, host: host), isTrue);

        final denied = TestCell.chain([
          _AsyncLinkRule(allow: true),
          _AsyncLinkRule(allow: false),
        ]);
        expect(await denied.link(other, host: host), isFalse);
      });
    });

    group('TestActionRule', () {
      test('accepts actions that match the predicate', () {
        final host = Cell();
        void allowed() {}
        void other() {}
        final rule = TestActionRule<Cell>((action, {required host, arguments, user}) {
          return identical(action, allowed);
        });
        expect(rule.action(allowed, host: host), isTrue);
        expect(rule.action(other, host: host), isFalse);
      });

      test('TestCell.action validates positional arguments via call', () {
        final policy = TestCell((object, {host, arguments, user}) {
          if (object is int) return object > 0;
          return true;
        });
        final host = Cell();
        expect(
          policy.action(
            host.apply,
            host: host,
            arguments: (positionalArguments: [5], namedArguments: null),
          ),
          isTrue,
        );
        expect(
          policy.action(
            host.apply,
            host: host,
            arguments: (positionalArguments: [-1], namedArguments: null),
          ),
          isFalse,
        );
      });

      test('TestCell.action validates named arguments via call', () {
        final policy = TestCell((object, {host, arguments, user}) {
          if (object is int) return object > 0;
          return true;
        });
        final host = Cell();
        expect(
          policy.action(
            host.apply,
            host: host,
            arguments: (
              positionalArguments: null,
              namedArguments: {#amount: 5},
            ),
          ),
          isTrue,
        );
        expect(
          policy.action(
            host.apply,
            host: host,
            arguments: (
              positionalArguments: null,
              namedArguments: {#amount: -1},
            ),
          ),
          isFalse,
        );
      });

      test('TestCell.action awaits chained async TestActionRules', () async {
        final host = Cell();
        final policy = TestCell.chain([
          _AsyncActionRule(allow: true),
          _AsyncActionRule(allow: true),
        ]);
        expect(await policy.action(host.apply, host: host), isTrue);

        final denied = TestCell.chain([
          _AsyncActionRule(allow: true),
          _AsyncActionRule(allow: false),
        ]);
        expect(await denied.action(host.apply, host: host), isFalse);
      });
    });

    group('Graph integration', () {
      test('cell.validate uses the TestCell rule', () {
        final rule = TestCell((object, {host, arguments, user}) {
          return object is int && object > 0;
        });
        final cell = Cell(testRule: rule);
        expect(cell.validate, rule);
        expect(cell.validate(5, host: cell), isTrue);
        expect(cell.validate(-1, host: cell), isFalse);
      });

      test('pulse validation on a cell drops odd payloads', () {
        final source = Cell.ingress<int>();
        final cell = Cell(
          bind: source.cell,
          testRule: TestCell((object, {host, arguments, user}) {
            if (object is Pulse && object.payload is int) {
              return (object.payload as int).isEven;
            }
            return true;
          }),
        );
        final rec = <dynamic>[];
        Cell.observe(
          source: cell,
          effect: (Pulse p) => rec.add(p.payload),
        );

        source.emit(2);
        source.emit(3);
        expect(rec, [2]);
      });

      test('link is rejected when the host TestCell denies the observer', () {
        final synapses = Synapses();
        final host = Cell(
          synapses: synapses,
          testRule: TestCell((object, {host, arguments, user}) {
            return false;
          }),
        );
        expect(synapses.link(host, downstreamCell: Cell()), isFalse);
      });
    });
  });

  group('TestRule', () {
    test('an async rule still consults parent', () async {
      final parent = TestRule<int>((object, {host, arguments, user}) {
        return object != 99;
      });
      final child = TestRule<int>((object, {host, arguments, user}) async {
        await Future<void>.delayed(Duration.zero);
        return object is int && object > 0;
      }, parent: parent);

      expect(await child.call(5), isTrue);
      expect(await child.call(-1), isFalse);
      expect(await child.call(99), isFalse);
    });

    test('chain awaits an async rule and continues', () async {
      final chain = TestRule<int>.chain([
        TestRule<int>((object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration.zero);
          return object is int;
        }),
        TestRule<int>((object, {host, arguments, user}) {
          return object is int && object > 0;
        }),
      ]);
      expect(await chain.call(5), isTrue);
      expect(await chain.call(-1), isFalse);
    });

    test('chain short-circuits later rules when an async rule fails', () async {
      var ranSecond = false;
      final chain = TestRule<int>.chain([
        TestRule<int>((object, {host, arguments, user}) async {
          await Future<void>.delayed(Duration.zero);
          return false;
        }),
        TestRule<int>((object, {host, arguments, user}) {
          ranSecond = true;
          return true;
        }),
      ]);
      expect(await chain.call(1), isFalse);
      expect(ranSecond, isFalse);
    });

    test('chain rethrows an Exception from a child rule', () {
      final chain = TestRule<int>.chain([
        TestRule<int>((object, {host, arguments, user}) {
          throw Exception('rule failed');
        }),
      ]);
      expect(() => chain.call(1), throwsA(isA<Exception>()));
    });

    test('equality and hashCode follow the flyweight record', () {
      bool always(dynamic object, {host, arguments, user}) => true;
      final a = TestRule<int>(always);
      final b = TestRule<int>(always);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(TestRule<int>((object, {host, arguments, user}) => false)));
    });

    test('fromRecord reconstitutes a callable rule', () {
      bool positive(dynamic object, {host, arguments, user}) {
        return object is int && object > 0;
      }

      final restored = TestRule<int>.fromRecord((rule: positive,));
      expect(restored.call(3), isTrue);
      expect(restored.call(-1), isFalse);
      expect(restored, TestRule<int>(positive));
    });
  });
}
