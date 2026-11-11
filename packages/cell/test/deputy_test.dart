// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:test/test.dart';
import 'package:cell/cell.dart';

void main() {
  group('Cell.deputy', () {
    test('returns this when no attenuation is requested', () async {
      final cell = Cell();
      expect(await cell.deputy(), same(cell));
      expect(await cell.deputy(testRule: TestCell.allowAll), same(cell));
      expect(
        await cell.deputy(context: DeputyContext.system),
        same(cell),
      );
    });

    test('creates a distinct proxy when a testRule is supplied', () async {
      final cell = Cell();
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      expect(deputy, isNot(same(cell)));
      expect(cell == deputy, isTrue);
      expect(deputy == cell, isTrue);
      expect(deputy.hashCode, cell.hashCode);
    });

    test('creates a distinct proxy when a DeputyContext is supplied', () async {
      final cell = Cell();
      final mandate = DeputyContext(
        baseContext: Context.system,
        authority: 'READ',
        role: 'Observer',
        clearance: Clearance.observational,
      );
      final deputy = await cell.deputy(context: mandate);
      expect(deputy, isNot(same(cell)));
      expect(deputy.context, mandate);
      expect(cell == deputy, isTrue);
    });

    test('creates a distinct proxy when an ephemeral policy is supplied',
        () async {
      final policy = EphemeralPolicy(
        eventLimit: 10,
        onEvent: (object, {required cell, required policy, arguments, user}) =>
            (events: 0),
        onInvalidate: (nucleus) => true,
      );
      final cell = Cell();
      final deputy = await cell.deputy(ephemeralPolicy: policy);
      expect(deputy, isNot(same(cell)));
      expect(deputy.isInvalidated, isFalse);
    });

    test('creates a distinct proxy when synapses are overridden', () async {
      final cell = Cell();
      final deputy = await cell.deputy(synapses: Synapses.disabled);
      expect(deputy, isNot(same(cell)));
      expect(deputy.isTerminal, isTrue);
      expect(cell.isTerminal, isFalse);
    });
  });

  group('identity', () {
    test('deputies of the same principal compare equal and share hashCode',
        () async {
      final cell = Cell();
      final a = await cell.deputy(testRule: TestCell.readOnly);
      final b = await cell.deputy(
        testRule: TestCell((object, {host, arguments, user}) => true),
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect({cell, a, b}.length, 1);
    });

    test('a nested deputy remains equal to the root principal', () async {
      final cell = Cell();
      final first = await cell.deputy(
        testRule: TestCell((object, {host, arguments, user}) => true),
      );
      final second = await first.deputy(testRule: TestCell.readOnly);
      expect(second, isNot(same(first)));
      expect(cell == second, isTrue);
      expect(first == second, isTrue);
      expect(second == cell, isTrue);
      expect(second.hashCode, cell.hashCode);
    });

    test('unrelated cells are not equal to a deputy', () async {
      final a = Cell();
      final b = Cell();
      final deputy = await a.deputy(testRule: TestCell.readOnly);
      expect(deputy == b, isFalse);
      expect(a == b, isFalse);
    });
  });

  group('testRule layering', () {
    test('the deputy rule is additive on top of the principal', () async {
      final principal = Cell(
        testRule: TestCell((object, {host, arguments, user}) {
          // Value predicate for apply/emit; also accept Cell objects so
          // the deputy's construction link passes the link gate (the gate
          // consults the rule with the linked cell object).
          return object is int ? object > 0 : object is Cell;
        }),
      );
      final deputy = await principal.deputy(
        testRule: TestCell((object, {host, arguments, user}) {
          return object is int && object < 10;
        }),
      );
      expect(principal.validate.call(5), isTrue);
      expect(principal.validate.call(15), isTrue);
      expect(deputy.validate.call(5), isTrue);
      expect(deputy.validate.call(15), isFalse);
      expect(deputy.validate.call(-1), isFalse);
    });

    test('readOnly deputy rejects apply forwarding', () async {
      final cell = Cell();
      var ran = false;
      void mark() => ran = true;
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      final outcome = await deputy.apply<void>((
        function: mark,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));
      expect(outcome, isA<ApplyRejected<void>>());
      expect(ran, isFalse);
    });
  });

  group('apply forwarding', () {
    test('deputy.apply executes on the principal', () async {
      final cell = Cell();
      var total = 0;
      void add(int n) {
        total += n;
      }

      final deputy = await cell.deputy(
        testRule: TestCell((object, {host, arguments, user}) => true),
      );
      final command = (
        function: add,
        arguments: (positionalArguments: [4], namedArguments: null),
        compensation: null,
      );
      expect(deputy.apply<void>(command), isA<ApplyAccepted<void>>());
      deputy.apply<void>(command);
      expect(total, 8);
    });
  });

  group('unmodifiable', () {
    test('deputy.unmodifiable is the principal unmodifiable view', () async {
      final cell = Cell();
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      expect(deputy.unmodifiable, same(cell.unmodifiable));
    });

    test('ValueCell deputy unmodifiable is an UnmodifiableValueCell', () async {
      final cell = ValueCell<int>(initial: 7);
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      final view = deputy.unmodifiable;
      expect(view, isA<Unmodifiable>());
      expect((view as ValueCell).value, 7);
    });
  });

  group('causal integrity', () {
    test('a nested deputy may use DeputyContext.system', () async {
      final cell = Cell();
      final first = await cell.deputy(
        context: DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        ),
      );
      expect(await first.deputy(), same(first));
    });

    test('a nested deputy may use an evolved descendant context', () async {
      final cell = Cell();
      final parentCtx = DeputyContext(
        baseContext: Context.system,
        authority: 'READ, WRITE',
        role: 'Delegate',
      );
      final first = await cell.deputy(context: parentCtx);
      final childCtx = parentCtx.evolve((evolvable) {
        if (evolvable == Mandate.authority) {
          return Mandate.authority.entry('READ');
        }
        return null;
      });
      final second = await first.deputy(context: childCtx);
      expect(second, isNot(same(first)));
      expect(second.context, childCtx);
    });

    group('Attenuation enforcement', () {
      test('isolation can only tighten', () {
        final ctx = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
          isolation: Isolation.scoped,
        );
        expect(
          () => ctx.evolve((e) => e == Mandate.isolation
              ? Mandate.isolation.entry(Isolation.shared)
              : null),
          throwsArgumentError,
        );
        final tightened = ctx.evolve((e) => e == Mandate.isolation
            ? Mandate.isolation.entry(Isolation.sandboxed)
            : null);
        expect(tightened.isolation, Isolation.sandboxed);
      });

      test('sovereignty can only tighten', () {
        final ctx = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        );
        final supervised = ctx.evolve((e) => e == Mandate.sovereignty
            ? Mandate.sovereignty.entry(Sovereignty.supervised)
            : null);
        expect(supervised.sovereignty, Sovereignty.supervised);
        expect(
          () => supervised.evolve((e) => e == Mandate.sovereignty
              ? Mandate.sovereignty.entry(Sovereignty.sovereign)
              : null),
          throwsArgumentError,
        );
      });

      test('clearance can only tighten', () {
        final ctx = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        );
        final observational = ctx.evolve((e) => e == Mandate.clearance
            ? Mandate.clearance.entry(Clearance.observational)
            : null);
        expect(observational.clearance, Clearance.observational);
        expect(
          () => observational.evolve((e) => e == Mandate.clearance
              ? Mandate.clearance.entry(Clearance.standard)
              : null),
          throwsArgumentError,
        );
      });

      test('auditLevel can only tighten', () {
        final ctx = DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        );
        expect(
          () => ctx.evolve((e) => e == Mandate.auditLevel
              ? Mandate.auditLevel.entry(AuditLevel.none)
              : null),
          throwsArgumentError,
        );
        final detailed = ctx.evolve((e) => e == Mandate.auditLevel
            ? Mandate.auditLevel.entry(AuditLevel.full)
            : null);
        expect(detailed.auditLevel, AuditLevel.full);
      });
    });

    test('a nested deputy rejects an unrelated DeputyContext', () async {
      final cell = Cell();
      final first = await cell.deputy(
        context: DeputyContext(
          baseContext: Context.system,
          authority: 'READ',
        ),
      );
      final unrelated = DeputyContext(
        baseContext: Context.system,
        authority: 'WRITE',
      );
      expect(
        () => first.deputy(context: unrelated),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('OpenCell.deputy', () {
    test('returns this when no attenuation is requested', () {
      final cell = Cell.open();
      expect(cell.deputy(), same(cell));
    });

    test('rejects a DeputyContext from an unrelated context tree',
        () async {
      final gate = Cell.open(context: Context.module('Auth'));
      final unrelated = DeputyContext.observer(
        baseContext: Context.module('HR'),
        task: 'spy',
      );
      expect(
        () => gate.deputy(context: unrelated),
        throwsA(isA<StateError>()),
      );
    });

    test('creates an OpenCell proxy that can emit', () async {
      final cell = Cell.open();
      final seen = <dynamic>[];
      Cell.observe(source: cell, effect: (Pulse p) => seen.add(p.payload));
      final deputy = cell.deputy(testRule: TestCell.readOnly);
      expect(deputy, isA<OpenCell>());
      expect(deputy, isNot(same(cell)));
      expect(cell == deputy, isTrue);
      await (deputy).emit(Pulse<int>(3));
      expect(seen, [3]);
    });

    test('nested OpenCell deputy with defaults returns this', () {
      final cell = Cell.open();
      final first = cell.deputy(testRule: TestCell.readOnly);
      expect((first).deputy(), same(first));
    });

    test('OpenCell deputy exposes async handle', () {
      final cell = Cell.open();
      final deputy = cell.deputy(synapses: Synapses.disabled);
      expect((deputy).async, isA<OpenCellAsync>());
    });

    test('OpenCell deputy can link a downstream observer', () async {
      final open = Cell.open();
      final deputy = open.deputy(
        testRule: TestCell((object, {host, arguments, user}) => true),
      );
      final sink = Cell();
      final unlink = deputy.link(sink);
      expect(unlink, isNotNull);
    });
  });
}
