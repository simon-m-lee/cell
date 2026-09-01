// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
//
// A [Nucleus] is a blueprint until [Cell.fromNucleus] binds it.
// [Nucleus.activate] only succeeds when the cell's nucleus is this instance.
// [Nucleus.evolve] inherits receptor/context/testRule; [bind] is local only.
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('Nucleus', () {
    group('empty / Nucleolus', () {
      test('Nucleus.empty is a reusable singleton', () {
        expect(identical(Nucleus.empty(), Nucleus.empty()), isTrue);
        expect(Nucleus.empty(), isA<Nucleolus>());
      });

      test('empty nucleus uses framework defaults', () {
        final empty = Nucleus.empty();
        expect(empty.context, Context.system);
        expect(empty.receptor, Receptor.passThrough);
        expect(empty.testRule, TestCell.allowAll);
        expect(empty.synapses, Synapses.disabled);
        expect(empty.bind, isNull);
        expect(empty.principal, isNull);
        expect(empty.user, isNull);
        expect(empty.lock, isNull);
        expect(empty.isInvalidated, isFalse);
      });

      test('empty nucleus is activation-resistant', () {
        final empty = Nucleus.empty();
        expect(empty.isActivated, isTrue);
        expect(empty.activate(Cell()), isFalse);
        expect(empty.clone, same(empty));
      });

      test('empty nucleus timestamp is a DateTime', () {
        expect(Nucleus.empty().timestamp, isA<DateTime>());
      });
    });

    group('Construction & defaults', () {
      test('default Nucleus uses system context and allowAll', () {
        final nucleus = Nucleus();
        expect(nucleus.context, Context.system);
        expect(nucleus.testRule, TestCell.allowAll);
        expect(nucleus.bind, isNull);
        expect(nucleus.principal, isNull);
        expect(nucleus.isActivated, isFalse);
        expect(nucleus.isInvalidated, isFalse);
      });

      test('default Nucleus allocates a lock', () {
        expect(Nucleus().lock, isNotNull);
      });

      test('forceLock: false omits a dedicated lock', () {
        expect(Nucleus(forceLock: false).lock, isNull);
      });

      test('default synapses are an enabled registry, not the flyweight', () {
        final nucleus = Nucleus();
        expect(identical(nucleus.synapses, Synapses.enabled), isFalse);
        expect(identical(nucleus.synapses, Synapses.disabled), isFalse);
        expect(nucleus.synapses, isEmpty);
      });

      test('Synapses.disabled is stored as a terminal egress', () {
        final nucleus = Nucleus(synapses: Synapses.disabled);
        expect(nucleus.synapses, Synapses.disabled);
      });

      test('custom context is stored', () {
        final context = Context.module('Auth');
        final nucleus = Nucleus(context: context);
        expect(nucleus.context, context);
        expect(nucleus.context.type, 'Auth');
        expect(nucleus.context.taxonomy, 'module');
      });

      test('custom receptor is stored', () {
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        final nucleus = Nucleus(receptor: receptor);
        expect(nucleus.receptor, isA<Receptor>());
        expect(identical(nucleus.receptor, Receptor.passThrough), isFalse);
      });

      test('custom testRule is stored', () {
        final rule = TestCell((object, {host, arguments, user}) => true);
        final nucleus = Nucleus(testRule: rule);
        expect(nucleus.testRule, rule);
      });

      test('bind is stored', () {
        final upstream = Cell();
        final nucleus = Nucleus(bind: upstream);
        expect(nucleus.bind, upstream);
      });

      test('user record is stored', () {
        final nucleus = Nucleus(user: (flag: true));
        expect(nucleus.user, (flag: true));
      });

      test('isGoverned follows the receptor, not a custom context', () {
        final nucleus = Nucleus(context: Context.module('Gov'));
        expect(nucleus.isGoverned, isFalse);
      });

      test('timestamp is a DateTime', () {
        expect(Nucleus().timestamp, isA<DateTime>());
      });
    });

    group('Nucleus.create', () {
      test('create without principal uses defaults', () {
        final nucleus = Nucleus.create();
        expect(nucleus.context, Context.system);
        expect(nucleus.testRule, TestCell.allowAll);
        expect(nucleus.principal, isNull);
      });

      test('create with principal inherits from it', () {
        final principal = Nucleus(context: Context.module('Root'));
        final created = Nucleus.create(principal: principal);
        expect(created.principal, principal);
        expect(created.context.type, 'Root');
      });
    });

    group('Activation', () {
      test('unactivated cell getter throws', () {
        expect(() => Nucleus().cell, throwsA(isA<Error>()));
      });

      test('activate returns false for a cell that does not own this nucleus', () {
        final nucleus = Nucleus();
        expect(nucleus.activate(Cell()), isFalse);
        expect(nucleus.isActivated, isFalse);
      });

      test('Cell.fromNucleus binds and activates the nucleus', () {
        final nucleus = Nucleus(context: Context.module('Bound'));
        final cell = Cell.fromNucleus(nucleus);
        expect(nucleus.isActivated, isTrue);
        expect(identical(nucleus.cell, cell), isTrue);
        expect(cell.context.type, 'Bound');
      });

      test('fromNucleus of an already activated nucleus uses a clone', () {
        final nucleus = Nucleus(context: Context.module('Shared'));
        final first = Cell.fromNucleus(nucleus);
        final second = Cell.fromNucleus(nucleus);

        expect(identical(first, second), isFalse);
        expect(first.context.type, 'Shared');
        expect(second.context.type, 'Shared');
      });

      test('fromNucleus with bind links the upstream synapses', () {
        final source = Cell.ingress<int>();
        final nucleus = Nucleus(bind: source.cell);
        final cell = Cell.fromNucleus(nucleus);
        final rec = <dynamic>[];
        Cell.observe(
          source: cell,
          effect: (Pulse p) => rec.add(p.payload),
        );

        source.emit(3);
        expect(rec, [3]);
      });
    });

    group('evolve', () {
      test('inherits context, receptor, and testRule from principal', () {
        final receptor = Receptor((cell, pulse, {user}) => Pulse('ok'));
        final rule = TestCell((object, {host, arguments, user}) => true);
        final principal = Nucleus(
          context: Context.module('Root'),
          receptor: receptor,
          testRule: rule,
        );
        final child = Nucleus.evolve(principal: principal);

        expect(child.principal, principal);
        expect(child.context.type, 'Root');
        expect(child.testRule, rule);
        expect(child.receptor, isA<Receptor>());
      });

      test('local testRule overrides the principal', () {
        final principal = Nucleus(
          testRule: TestCell((object, {host, arguments, user}) => true),
        );
        final override = TestCell((object, {host, arguments, user}) => false);
        final child = Nucleus.evolve(
          principal: principal,
          testRule: override,
        );
        expect(child.testRule, override);
        expect(principal.testRule, isNot(override));
      });

      test('local context overrides the principal', () {
        final principal = Nucleus(context: Context.module('Root'));
        final child = Nucleus.evolve(
          principal: principal,
          context: Context.module('Child'),
        );
        expect(child.context.type, 'Child');
        expect(principal.context.type, 'Root');
      });

      test('bind is not inherited', () {
        final upstream = Cell();
        final principal = Nucleus(bind: upstream);
        final child = Nucleus.evolve(principal: principal);
        expect(principal.bind, upstream);
        expect(child.bind, isNull);
      });

      test('user is inherited', () {
        final principal = Nucleus(user: (role: 'admin'));
        final child = Nucleus.evolve(principal: principal);
        expect(child.user, (role: 'admin'));
      });

      test('local user overrides the principal', () {
        final principal = Nucleus(user: (role: 'admin'));
        final child = Nucleus.evolve(
          principal: principal,
          user: (role: 'guest'),
        );
        expect(child.user, (role: 'guest'));
      });

      test('walks a chain of principals', () {
        final root = Nucleus(context: Context.module('Root'));
        final mid = Nucleus.evolve(
          principal: root,
          context: Context.module('Mid'),
        );
        final leaf = Nucleus.evolve(principal: mid);
        expect(leaf.context.type, 'Mid');
        expect(leaf.principal, mid);
        expect(mid.principal, root);
      });

      test('lock falls back to the principal', () {
        final principal = Nucleus();
        final child = Nucleus.evolve(principal: principal);
        expect(child.lock, principal.lock);
      });
    });

    group('clone', () {
      test('clone is a distinct unactivated blueprint', () {
        final original = Nucleus(context: Context.module('Clone'));
        final clone = original.clone;
        expect(identical(original, clone), isFalse);
        expect(clone.isActivated, isFalse);
        expect(clone.context.type, 'Clone');
        expect(clone.principal, original);
      });

      test('clone can hydrate an independent cell', () {
        final original = Nucleus(context: Context.module('Clone'));
        Cell.fromNucleus(original);
        final clone = original.clone;
        final cell = Cell.fromNucleus(clone);
        expect(cell.context.type, 'Clone');
        expect(identical(clone.cell, cell), isTrue);
      });
    });

    group('Equality', () {
      test('two distinct root nuclei are not equal', () {
        expect(Nucleus() == Nucleus(), isFalse);
      });

      test('identity equality holds', () {
        final nucleus = Nucleus();
        expect(nucleus == nucleus, isTrue);
      });

      test('evolved nuclei that share a root principal compare equal', () {
        final root = Nucleus();
        final a = Nucleus.evolve(principal: root);
        final b = Nucleus.evolve(principal: root);
        expect(a == b, isTrue);
        expect(a == root, isTrue);
      });
    });

    group('inheritable', () {
      test('inheritable handle exposes the resolved pillars', () {
        final context = Context.module('Pillars');
        final nucleus = Nucleus(context: context);
        final handle = nucleus.inheritable;
        expect(handle.context, context);
        expect(handle.testRule, TestCell.allowAll);
        expect(handle.receptor, isA<Receptor>());
        expect(handle.bind, isNull);
        expect(handle.ephemeralPolicy, isNull);
      });
    });

    group('Cell hydration', () {
      test('hydrated cell uses the nucleus testRule', () {
        final rule = TestCell((object, {host, arguments, user}) {
          if (object is Pulse && object.payload is int) {
            return (object.payload as int).isEven;
          }
          return true;
        });
        final source = Cell.ingress<int>();
        final cell = Cell.fromNucleus(
          Nucleus(
            bind: source.cell,
            testRule: rule,
          ),
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

      test('hydrated cell with disabled synapses is terminal', () {
        final cell = Cell.fromNucleus(
          Nucleus(synapses: Synapses.disabled),
        );
        expect(cell.isTerminal, isTrue);
      });
    });
  });
}
