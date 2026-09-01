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
          return object is int && object > 0;
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

    test('readOnly deputy still exposes apply on the principal via forwarding',
        () async {
      final cell = Cell();
      var ran = false;
      void mark() => ran = true;
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      deputy.apply(mark);
      expect(ran, isTrue);
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
      expect(deputy.apply(add, positionalArguments: [4]), isNull);
      deputy.apply(add, positionalArguments: [4]);
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
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('OpenCell.deputy', () {
    test('returns this when no attenuation is requested', () {
      final cell = Cell.open();
      expect(cell.deputy(), same(cell));
    });

    test('creates an OpenCell proxy that can emit', () async {
      final cell = Cell.open();
      final seen = <dynamic>[];
      Cell.observe(source: cell, effect: (Pulse p) => seen.add(p.payload));
      final deputy = cell.deputy(testRule: TestCell.readOnly);
      expect(deputy, isA<OpenCell>());
      expect(deputy, isNot(same(cell)));
      expect(cell == deputy, isTrue);
      await (deputy as OpenCell).emit(Pulse<int>(3));
      expect(seen, [3]);
    });

    test('nested OpenCell deputy with defaults returns this', () {
      final cell = Cell.open();
      final first = cell.deputy(testRule: TestCell.readOnly);
      expect((first as OpenCell).deputy(), same(first));
    });

    test('OpenCell deputy exposes async handle', () {
      final cell = Cell.open();
      final deputy = cell.deputy(synapses: Synapses.disabled);
      expect((deputy as OpenCell).async, isA<OpenCellAsync>());
    });

    test('OpenCell deputy can link a downstream observer', () async {
      final open = Cell.open();
      final deputy = open.deputy(
        testRule: TestCell((object, {host, arguments, user}) => true),
      ) as OpenCell;
      final sink = Cell();
      final unlink = deputy.link(sink);
      expect(unlink, isNotNull);
    });
  });
}
