// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Test Fixtures
// ─────────────────────────────────────────────────────────────────────────

class TestCell extends CellBase {
  TestCell() : super();
}

class UserData {
  final String name;
  final String email;

  UserData({required this.name, required this.email});
}

// ─────────────────────────────────────────────────────────────────────────
// Pulse Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('Pulse', () {
    group('Construction', () {
      test('creates a simple pulse with payload', () {
        final pulse = Pulse<int>(42);
        expect(pulse.payload, 42);
        expect(pulse.type, null);
        expect(pulse.priority, Pulse.defaultPriority);
        expect(pulse.isComposite, false);
        expect(pulse.isGoverned, false);
        expect(pulse.isInvalidated, false);
        expect(pulse.source, null);
        expect(pulse.timestamp, isNotNull);

        expect(pulse.trace, isEmpty);
        expect(pulse.context, isA<PulseContext>());
        expect(pulse.root, pulse);
      });

      test('creates a pulse with type', () {
        final pulse = Pulse<String>('Hello', type: 'greeting');
        expect(pulse.payload, 'Hello');
        expect(pulse.type, 'greeting');
      });

      test('creates a pulse with priority', () {
        final pulse = Pulse<int>(42, priority: 80);
        expect(pulse.priority, 80);
      });

      test('creates a pulse with source', () {
        final cell = TestCell();
        final pulse = Pulse<int>(42, source: cell);
        expect(pulse.source, cell);
      });

      test('creates a pulse with step', () {
        final pulse = Pulse<int>(42, step: 'initial');
        expect(pulse.trace, ['initial']);
      });

      test('creates a governed pulse with context', () {
        final context = PulseContext(
          actor: 'admin_001',
          reason: 'Manual update',
          priority: 60,
        );
        final pulse = Pulse.governed(
          payload: 42,
          context: context,
        );
        expect(pulse.payload, 42);
        expect(pulse.isGoverned, true);
        expect(pulse.context.actor, 'admin_001');
        expect(pulse.context.reason, 'Manual update');
        expect(pulse.context.priority, 60);
      });

      test('creates a governed pulse with policy', () {
        final policy = PulseEphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) => true,
        );
        final pulse = Pulse.governed(
          payload: 42,
          policy: policy,
        );
        expect(pulse.policy, policy);
        expect(pulse.isGoverned, true);
      });

      test('creates a governed pulse with context and callbacks', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(
          payload: 42,
          context: context,
          onComplete: (pulse) {},
          onError: (pulse, error, {stackTrace}) {},
        );
        expect(pulse.isGoverned, true);
        expect(pulse.context.actor, 'admin');
      });

      test('Pulse.governed without context or policy is NOT governed', () {
        final pulse = Pulse.governed(
          payload: 42,
        );
        expect(pulse.isGoverned, false);
        expect(pulse.payload, 42);
      });

      test('Pulse.governed with only callbacks is NOT governed', () {
        final pulse = Pulse.governed(
          payload: 42,
          onComplete: (pulse) {},
        );
        expect(pulse.isGoverned, false);
        expect(pulse.payload, 42);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // CORRECTED: withStep vs evolve distinction
    // ─────────────────────────────────────────────────────────────────────────

    group('withStep vs evolve distinction', () {
      test('withStep does NOT create an EvolvedPulse', () {
        final root = Pulse<int>(42);
        final processed = root.withStep('sanitized');

        expect(processed is EvolvedPulse, false);
        expect(processed.isComposite, false);
      });

      test('evolve with ONLY step does NOT create an EvolvedPulse', () {
        final root = Pulse<int>(42);
        final evolved = root.evolve(step: 'validation');

        // evolve with only step returns _Pulse, NOT EvolvedPulse
        expect(evolved is EvolvedPulse, false);
        expect(evolved.isComposite, false);
        expect(evolved.trace, ['validation']);
      });

      test('evolve with ONLY context does NOT create an EvolvedPulse', () {
        final context = PulseContext(actor: 'admin');
        final root = Pulse<int>(42);
        final evolved = root.evolve(context: context);

        // evolve with only context returns _Pulse, NOT EvolvedPulse
        expect(evolved is EvolvedPulse, false);
        expect(evolved.isComposite, false);
        expect(evolved.context.actor, 'admin');
      });

      test('evolve with pulse creates an EvolvedPulse (causal branch)', () {
        final root = Pulse<int>(42);
        final child = Pulse<String>('result');
        final evolved = root.evolve(pulse: child, step: 'process');

        // evolve with pulse creates EvolvedPulse
        expect(evolved is EvolvedPulse, true);
        expect(evolved.isComposite, true);
        expect((evolved as EvolvedPulse).parent, root);
        expect(evolved.payload, 'result');
        expect(evolved.trace, ['process']);
      });

      test('evolve with pulse but no step creates EvolvedPulse', () {
        final root = Pulse<int>(42);
        final child = Pulse<String>('result');
        final evolved = root.evolve(pulse: child);

        expect(evolved is EvolvedPulse, true);
        expect((evolved as EvolvedPulse).parent, root);
        expect(evolved.payload, 'result');
        expect(evolved.trace, isEmpty);
      });

      test('withStep vs evolve(step) are semantically similar', () {
        final root = Pulse<int>(42);

        // Both withStep and evolve(step) add a trace step
        final stepped = root.withStep('validation');
        final evolved = root.evolve(step: 'validation');

        // Both are NOT EvolvedPulse
        expect(stepped is EvolvedPulse, false);
        expect(evolved is EvolvedPulse, false);

        // Both have the same trace
        expect(stepped.trace, ['validation']);
        expect(evolved.trace, ['validation']);

        // Both preserve the same payload
        expect(stepped.payload, 42);
        expect(evolved.payload, 42);
      });

      test('withStep lengthens lineage without causal branching', () {
        final root = Pulse<int>(10);
        final processed = root.withStep('sanitized').withStep('validated');

        expect(processed.trace, ['sanitized', 'validated']);
        expect(root.trace, []);
        expect(root, isNot(same(processed)));
        expect(processed is EvolvedPulse, false);
      });

      test('evolve(step) lengthens lineage without causal branching', () {
        final root = Pulse<int>(10);
        final processed = root.evolve(step: 'sanitized').evolve(step: 'validated');

        expect(processed.trace, ['sanitized', 'validated']);
        expect(root.trace, []);
        expect(root, isNot(same(processed)));
        expect(processed is EvolvedPulse, false);
      });

      test('withStep preserves identity, context, and payload', () {
        final context = PulseContext(actor: 'admin');
        final root = Pulse<int>.governed(
          payload: 42,
          type: 'counter',
          priority: 60,
          context: context,
        );
        final processed = root.withStep('validation');

        expect(processed.payload, 42);
        expect(processed.context.actor, 'admin');
        expect(processed.type, 'counter');
        expect(processed.priority, 60);
        expect(processed is EvolvedPulse, false);
      });

      test('evolve(step) preserves identity, context, and payload', () {
        final context = PulseContext(actor: 'admin');
        final root = Pulse<int>.governed(
          payload: 42,
          type: 'counter',
          priority: 60,
          context: context,
        );
        final processed = root.evolve(step: 'validation');

        expect(processed.payload, 42);
        expect(processed.context.actor, 'admin');
        expect(processed.type, 'counter');
        expect(processed.priority, 60);
        expect(processed is EvolvedPulse, false);
      });

      test('evolve with pulse creates parent-child relationship', () {
        final root = Pulse<int>(42);
        final child = Pulse<String>('result');
        final evolved = root.evolve(pulse: child, step: 'process');

        expect(evolved is EvolvedPulse, true);
        expect((evolved as EvolvedPulse).parent, root);
        expect(evolved.trace, ['process']);
        expect(evolved.payload, 'result');
      });
    });

    group('Evolution', () {
      test('withStep adds a trace step', () {
        final pulse = Pulse<int>(42).withStep('validation');
        expect(pulse.trace, ['validation']);
        expect(pulse.payload, 42);
        expect(pulse.isComposite, false);
        expect(pulse.root.payload, 42);
        expect(pulse is EvolvedPulse, false);
      });

      test('withStep chains multiple steps', () {
        final pulse = Pulse<int>(42)
            .withStep('validation')
            .withStep('transformation')
            .withStep('persistence');
        expect(pulse.trace, ['validation', 'transformation', 'persistence']);
        expect(pulse is EvolvedPulse, false);
      });

      test('evolve(step) adds trace step without EvolvedPulse', () {
        final pulse = Pulse<int>(42).evolve(step: 'validation');
        expect(pulse.trace, ['validation']);
        expect(pulse.payload, 42);
        expect(pulse.isComposite, false);
        expect(pulse is EvolvedPulse, false);
      });

      test('evolve(step) chains multiple steps without EvolvedPulse', () {
        final pulse = Pulse<int>(42)
            .evolve(step: 'step1')
            .evolve(step: 'step2')
            .evolve(step: 'step3');
        expect(pulse.trace, ['step1', 'step2', 'step3']);
        expect(pulse is EvolvedPulse, false);
      });

      test('evolve with context and step adds trace without EvolvedPulse', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse<int>(42).evolve(step: 'validation', context: context);
        expect(pulse.context.actor, 'admin');
        expect(pulse.trace, ['validation']);
        expect(pulse.isGoverned, true);
        expect(pulse is EvolvedPulse, false);
      });

      test('evolve with pulse appends and creates EvolvedPulse', () {
        final root = Pulse<int>(42);
        final child = Pulse<String>('result');
        final evolved = root.evolve(pulse: child, step: 'process');
        expect(evolved.payload, 'result');
        expect(evolved.trace, ['process']);
        expect(evolved is EvolvedPulse, true);
        expect((evolved as EvolvedPulse).parent, root);
      });

      test('evolve requires at least one parameter', () {
        final pulse = Pulse<int>(42);
        expect(() => pulse.evolve(), throwsA(isA<AssertionError>()));
      });

      test('lineage tracks payload history with evolve(pulse)', () {
        final root = Pulse<int>(42);
        final evolved1 = root.evolve(pulse: Pulse<int>(43), step: 'step1');
        final evolved2 = evolved1.evolve(pulse: Pulse<int>(44), step: 'step2');

        final lineage = evolved2.lineage<dynamic>(LineageArgument.payload);
        expect(lineage, [42, 43, 44]);
        expect(evolved2 is EvolvedPulse, true);
      });

      test('lineage tracks type history with evolve(pulse)', () {
        final root = Pulse<int>(42, type: 'counter');
        final evolved1 = root.evolve(pulse: Pulse<String>('result', type: 'validation'), step: 'step1');
        final evolved2 = evolved1.evolve(pulse: Pulse<String>('final', type: 'transformation'), step: 'step2');

        final lineage = evolved2.lineage<dynamic>(LineageArgument.type);
        expect(lineage, ['counter', 'validation', 'transformation']);
        expect(evolved2 is EvolvedPulse, true);
      });

      test('lineage tracks priority history with evolve(pulse)', () {
        final root = Pulse<int>(42, priority: 60);
        final evolved = root.evolve(pulse: Pulse<int>(43, priority: 80), step: 'step1');

        final lineage = evolved.lineage<dynamic>(LineageArgument.priority);
        expect(lineage, [60, 80]);
        expect(evolved is EvolvedPulse, true);
      });

      test('lineage tracks source history with evolve(pulse)', () {
        final cell1 = TestCell();
        final cell2 = TestCell();
        final root = Pulse<int>(42, source: cell1);
        final evolved = root.evolve(pulse: Pulse<int>(43, source: cell2), step: 'step1');

        final lineage = evolved.lineage<dynamic>(LineageArgument.source);
        expect(lineage, [cell1, cell2]);
        expect(evolved is EvolvedPulse, true);
      });

      test('withStep does NOT affect lineage history', () {
        final root = Pulse<int>(42);
        final processed = root
            .withStep('validation')
            .withStep('transformation');

        final lineage = processed.lineage<dynamic>(LineageArgument.payload);
        expect(lineage, [42]);
        expect(processed.trace, ['validation', 'transformation']);
        expect(processed is EvolvedPulse, false);
      });

      test('evolve(step) does NOT affect lineage history', () {
        final root = Pulse<int>(42);
        final processed = root
            .evolve(step: 'validation')
            .evolve(step: 'transformation');

        final lineage = processed.lineage<dynamic>(LineageArgument.payload);
        expect(lineage, [42]);
        expect(processed.trace, ['validation', 'transformation']);
        expect(processed is EvolvedPulse, false);
      });

      test('evolve with pulse creates causal chain, evolve(step) does not', () {
        final root = Pulse<int>(42);

        // evolve(step) - flat, no parent chain
        final stepped = root.evolve(step: 'processed');
        expect(stepped is EvolvedPulse, false);
        expect(stepped.lineage<dynamic>(LineageArgument.payload), [42]);

        // evolve(pulse) - creates parent chain
        final evolved = root.evolve(pulse: Pulse<int>(43), step: 'transformed');
        expect(evolved is EvolvedPulse, true);
        expect(evolved.lineage<dynamic>(LineageArgument.payload), [42, 43]);
      });
    });

    group('Composition', () {
      test('+ operator creates collective pulse', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<String>('hello');
        final collective = p1 + p2;
        expect(collective.isComposite, true);
        expect(collective.payload.length, 2);
        expect(collective.payload.first.payload, 1);
        expect(collective.payload.last.payload, 'hello');
      });

      test('+ operator with multiple pulses', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final p3 = Pulse<int>(3);
        final collective = Pulse.batch([p1, p2, p3]);
        expect(collective.payload.length, 3);
        expect(collective.payload.elementAt(0).payload, 1);
        expect(collective.payload.elementAt(1).payload, 2);
        expect(collective.payload.elementAt(2).payload, 3);
      });

      test('Pulse.batch creates collective pulse', () {
        final pulses = [Pulse<int>(1), Pulse<int>(2), Pulse<int>(3)];
        final collective = Pulse.batch(pulses);
        expect(collective.isComposite, true);
        expect(collective.payload.length, 3);
      });

      test('Pulse.batch with governed pulses', () {
        final p1 = Pulse.governed(payload: 1, context: PulseContext(actor: 'admin'));
        final p2 = Pulse.governed(payload: 2, context: PulseContext(actor: 'admin'));
        final collective = Pulse.batch([p1, p2]);
        expect(collective.isComposite, true);
        expect(collective.payload.length, 2);
        expect(collective.isGoverned, false);
      });

      test('Pulse.batch with callback', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final collective = Pulse.batch(
          [p1, p2],
          onComplete: (pulse) {},
        );
        expect(collective.isComposite, true);
        expect(collective.payload.length, 2);
      });
    });

    group('Shell', () {
      test('shell hides payload', () {
        final pulse = Pulse<String>('Secret');
        final shell = pulse.shell;
        expect(shell.payload, null);
        expect(shell.type, null);
        expect(shell.trace, []);
        expect(shell.isComposite, false);
      });

      test('shell scrutinizes receptor', () {
        final pulse = Pulse<String>('Secret');
        final shell = pulse.shell;
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        final result = shell.scrutinize(receptor, null);
        expect(result.payload, 'Secret');
      });

      test('shell with governed pulse', () {
        final pulse = Pulse.governed(
          payload: 'Secret',
          context: PulseContext(actor: 'admin'),
        );
        final shell = pulse.shell;
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        final result = shell.scrutinize(receptor, null);
        expect(result.payload, 'Secret');
        expect(result.context.actor, 'admin');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Tests for Unmodifiable
    // ─────────────────────────────────────────────────────────────────────────

    group('Unmodifiable', () {
      test('unmodifiable locks payload of this specific instance', () {
        final pulse = Pulse<int>(42);
        final unmodifiable = pulse.unmodifiable;
        expect(unmodifiable.payload, 42);
      });

      test('unmodifiable prevents mutation of the instance', () {
        final pulse = Pulse<int>(42);
        final unmodifiable = pulse.unmodifiable;
        expect(unmodifiable.payload, 42);
      });

      test('unmodifiable does NOT block withStep - creates new modifiable instance', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final next = protected.withStep('forwarded');

        expect(next, isNot(same(protected)));
        expect(next.payload, 42);
        expect(next.trace, ['forwarded']);
        expect(next is EvolvedPulse, false);
        expect(protected.trace, isEmpty);
        expect(protected.payload, 42);
      });

      test('unmodifiable does NOT block evolve(step) - creates new modifiable instance', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final next = protected.evolve(step: 'forwarded');

        expect(next, isNot(same(protected)));
        expect(next.payload, 42);
        expect(next.trace, ['forwarded']);
        expect(next is EvolvedPulse, false);
        expect(protected.trace, isEmpty);
        expect(protected.payload, 42);
      });

      test('unmodifiable protects the payload cell from mutation', () {
        final cell = TestCell();
        final pulse = Pulse<Cell>(cell);
        final unmodifiable = pulse.unmodifiable;

        final protectedCell = unmodifiable.payload as Cell;
        expect(protectedCell, isA<Cell>());
      });

      test('unmodifiable recursively protects parent chain for EvolvedPulse', () {
        final root = Pulse<int>(42);
        // Only evolve with pulse creates EvolvedPulse
        final child = Pulse<String>('result');
        final evolved = root.evolve(pulse: child, step: 'step1');
        final unmodifiable = evolved.unmodifiable;

        expect(unmodifiable, isA<EvolvedPulse>());
        final evolvedPulse = unmodifiable as EvolvedPulse;
        final parent = evolvedPulse.parent;
        expect(parent, isA<UnmodifiablePulse>());
      });

      test('unmodifiable with evolve(step) does NOT create recursive parent chain', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final next = protected.evolve(step: 'step1');

        expect(next is EvolvedPulse, false);
        expect(next.trace, ['step1']);
        expect(next.payload, 42);
      });

      test('unmodifiable recursively protects root and source', () {
        final cell = TestCell();
        final pulse = Pulse<int>(42, source: cell);
        final unmodifiable = pulse.unmodifiable;

        expect(unmodifiable.root, isA<UnmodifiablePulse>());
        expect(unmodifiable.source, isA<Cell>());
      });

      test('unmodifiable preserves reactivity of payload cell', () {
        final cell = TestCell();
        final pulse = Pulse<Cell>(cell);
        final unmodifiable = pulse.unmodifiable;

        final protectedCell = unmodifiable.payload as Cell;
        expect(protectedCell.unmodifiable, isA<Cell>());
      });

      test('unmodifiable is recursive for nested iterables', () {
        final cell = TestCell();
        final pulse = Pulse<List<Cell>>([cell]);
        final unmodifiable = pulse.unmodifiable;

        final list = unmodifiable.payload as List<Cell>;
        expect(list.first.unmodifiable, isA<Cell>());
      });

      // test('unmodifiable is recursive for nested maps', () {
      //   final cell = TestCell();
      //   final pulse = Pulse<Map<String, Cell>>({'key': cell});
      //   final unmodifiable = pulse.unmodifiable;
      //
      //   final map = unmodifiable.payload as Map<String, Cell>;
      //   expect(map.values.first.unmodifiable, isA<Cell>());
      // });

      test('unmodifiable allows reading payload but blocks modifications', () {
        final pulse = Pulse<int>(42);
        final unmodifiable = pulse.unmodifiable;

        expect(unmodifiable.payload, 42);
        expect(unmodifiable.type, null);
        expect(unmodifiable.trace, isEmpty);
        expect(unmodifiable.priority, Pulse.defaultPriority);
      });

      test('evolve with pulse from unmodifiable preserves protected instance as parent', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final child = Pulse<String>('result');
        final next = protected.evolve(pulse: child, step: 'next');

        expect(next, isA<EvolvedPulse>());
        final evolvedNext = next as EvolvedPulse;
        expect(evolvedNext.parent, protected);
        expect(next.payload, 'result');
        expect(next.trace, ['next']);
        expect(protected.trace, isEmpty);
      });

      test('withStep from unmodifiable creates new modifiable instance', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final next = protected.withStep('processed');

        expect(next, isNot(same(protected)));
        expect(next.trace, ['processed']);
        expect(protected.trace, isEmpty);
        expect(next is EvolvedPulse, false);
      });

      test('unmodifiable does not prevent withStep chain', () {
        final pulse = Pulse<int>(42);
        final protected = pulse.unmodifiable;

        final step1 = protected.withStep('step1');
        final step2 = step1.withStep('step2');
        final step3 = step2.withStep('step3');

        expect(step1, isNot(same(protected)));
        expect(step2, isNot(same(step1)));
        expect(step3, isNot(same(step2)));
        expect(step1 is EvolvedPulse, false);
        expect(step2 is EvolvedPulse, false);
        expect(step3 is EvolvedPulse, false);
        expect(step3.trace, ['step1', 'step2', 'step3']);
        expect(protected.trace, isEmpty);
      });

      test('unmodifiable blocks modifications but not observations', () {
        final pulse = Pulse<UserData>(
          UserData(name: 'Alice', email: 'alice@example.com'),
        );
        final unmodifiable = pulse.unmodifiable;

        expect(unmodifiable.payload, isA<UserData>());
        expect(unmodifiable.type, null);
        expect(unmodifiable.priority, Pulse.defaultPriority);
      });
    });

    group('Comparison', () {

      // Earlier timestamp has higher precedence (negative compareTo), independent
      // of payload. Two Pulse() calls in the same microsecond share a timestamp
      // and fall through to priority/trace, so wait until the clock advances.
      test('compareTo orders by timestamp', () async {
        final older = Pulse<int>(99);
        late Pulse<int> newer;
        var attempts = 0;
        do {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          newer = Pulse<int>(1);
          attempts++;
        } while (!older.timestamp.isBefore(newer.timestamp) && attempts < 50);

        expect(
          older.timestamp.isBefore(newer.timestamp),
          isTrue,
          reason: 'clock did not advance after $attempts waits '
              '(${older.timestamp} vs ${newer.timestamp})',
        );
        expect(older.compareTo(newer), lessThan(0));
        expect(newer.compareTo(older), greaterThan(0));
        expect(older.compareTo(older), 0);
      });

      test('compareTo orders by priority when timestamps equal', () {
        final p1 = Pulse<int>(1, priority: 80);
        final p2 = Pulse<int>(2, priority: 60);
        expect(p1.compareTo(p2), isNotNull);
      });

      test('compareTo orders by trace depth when timestamps and priority equal', () {
        final p1 = Pulse<int>(1, priority: 60);
        final p2 = Pulse<int>(2, priority: 60).withStep('step');
        expect(p1.compareTo(p2), lessThan(0));
      });

      test('equality uses record comparison', () {
        final p1 = Pulse<int>(42);
        final p2 = Pulse<int>(42);
        expect(p1 == p2, false);
      });

      test('identity equality works', () {
        final p1 = Pulse<int>(42);
        final p2 = p1;
        expect(p1 == p2, true);
      });

      test('hashCode is stable', () {
        final p1 = Pulse<int>(42);
        final p2 = p1;
        expect(p1.hashCode, p2.hashCode);
      });
    });

    group('Iterable', () {
      test('iterating over single pulse yields itself', () {
        final pulse = Pulse<int>(42);
        final list = pulse.toList();
        expect(list.length, 1);
        expect(list.first, pulse);
      });

      test('iterating over withStep pulse yields itself (not EvolvedPulse)', () {
        final pulse = Pulse<int>(42)
            .withStep('step1')
            .withStep('step2')
            .withStep('step3');
        final list = pulse.toList();
        expect(list.length, 1);
        expect(list[0].payload, 42);
        expect(pulse is EvolvedPulse, false);
      });

      test('iterating over evolve(step) pulse yields itself (not EvolvedPulse)', () {
        final pulse = Pulse<int>(42)
            .evolve(step: 'step1')
            .evolve(step: 'step2')
            .evolve(step: 'step3');
        final list = pulse.toList();
        expect(list.length, 1);
        expect(list[0].payload, 42);
        expect(pulse is EvolvedPulse, false);
      });

      test('iterating over evolve(pulse) yields EvolvedPulse', () {
        final pulse = Pulse<int>(42)
            .evolve(pulse: Pulse<int>(43), step: 'step1')
            .evolve(pulse: Pulse<int>(44), step: 'step2');
        final list = pulse.toList();
        expect(list.length, 2);
        expect(list[0].payload, 43);
        expect(pulse is EvolvedPulse, true);
      });

      test('iterating over collective pulse yields itself', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final p3 = Pulse<int>(3);
        final collective = Pulse.batch([p1, p2, p3]);
        final list = collective.toList();
        expect(list.length, 1);
        expect(list.first.payload.length, 3);
      });

      test('collective payload iteration yields individual pulses', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final p3 = Pulse<int>(3);
        final collective = Pulse.batch([p1, p2, p3]);
        final list = collective.payload.toList();
        expect(list.length, 3);
        expect(list[0].payload, 1);
        expect(list[1].payload, 2);
        expect(list[2].payload, 3);
      });
    });

    group('Governance', () {
      test('isGoverned returns true when context provided', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.isGoverned, true);
      });

      test('isGoverned returns true when policy provided', () {
        final policy = PulseEphemeralPolicy(
          duration: Duration(seconds: 10),
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) => true,
        );
        final pulse = Pulse.governed(payload: 42, policy: policy);
        expect(pulse.isGoverned, true);
      });

      test('isGoverned returns false when no context or policy', () {
        final pulse = Pulse.governed(payload: 42);
        expect(pulse.isGoverned, false);
      });

      test('isGoverned returns false when only callbacks provided', () {
        final pulse = Pulse.governed(
          payload: 42,
          onComplete: (pulse) {},
        );
        expect(pulse.isGoverned, false);
      });

      test('isGoverned returns true when context is inherited via evolve(step)', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(payload: 42, context: context);
        final evolved = pulse.evolve(step: 'validation');
        expect(evolved.isGoverned, true);
        expect(evolved.context.actor, 'admin');
        expect(evolved is EvolvedPulse, false);
      });

      test('isGoverned returns true when context is inherited via evolve(pulse)', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(payload: 42, context: context);
        final child = Pulse<int>(43);
        final evolved = pulse.evolve(pulse: child, step: 'validation');
        expect(evolved.isGoverned, true);
        expect(evolved.context.actor, 'admin');
        expect(evolved is EvolvedPulse, true);
      });

      test('withStep does NOT inherit governance differently', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(payload: 42, context: context);
        final stepped = pulse.withStep('validation');
        expect(stepped.isGoverned, true);
        expect(stepped.context.actor, 'admin');
        expect(stepped is EvolvedPulse, false);
      });

      test('isInvalidated returns false initially', () {
        final pulse = Pulse<int>(42);
        expect(pulse.isInvalidated, false);
      });

      test('isInvalidated returns true after policy expires', () async {
        bool invalidated = false;
        final policy = PulseEphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) {
            invalidated = true;
            return true;
          },
        );
        final pulse = Pulse.governed(
          payload: 42,
          policy: policy,
        );
        expect(pulse.isInvalidated, false);
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        Cell(receptor: receptor);
        receptor.call(pulse);
        await Future.delayed(Duration(milliseconds: 20));
        expect(invalidated, true);
        expect(pulse.isInvalidated, true);
      });
    });

    group('Provenance', () {
      test('context stores actor', () {
        final context = PulseContext(actor: 'admin_001');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.actor, 'admin_001');
      });

      test('context stores reason', () {
        final context = PulseContext(reason: 'Manual override');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.reason, 'Manual override');
      });

      test('context stores purpose', () {
        final context = PulseContext(purpose: 'USER_UPDATE');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.purpose, 'USER_UPDATE');
      });

      test('context stores strategy', () {
        final context = PulseContext(strategy: ReasoningStrategy.manual);
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.strategy, ReasoningStrategy.manual);
      });

      test('context stores confidence', () {
        final context = PulseContext(confidence: 0.85);
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.confidence, 0.85);
      });

      test('context stores priority', () {
        final context = PulseContext(priority: 80);
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.priority, 80);
        expect(pulse.priority, 80);
      });

      test('context stores sensitivity', () {
        final context = PulseContext(sensitivity: Sensitivity.confidential);
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.sensitivity, Sensitivity.confidential);
      });

      test('context stores auditLevel', () {
        final context = PulseContext(auditLevel: AuditLevel.full);
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.auditLevel, AuditLevel.full);
      });

      test('context stores traceId', () {
        final context = PulseContext(traceId: 'custom-trace-123');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.traceId, 'custom-trace-123');
      });

      test('context auto-generates traceId', () {
        final context = PulseContext(actor: 'admin');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.traceId, isNotNull);
        expect(pulse.context.traceId, isNotEmpty);
      });

      test('context stores parentTraceId', () {
        final context = PulseContext(parentTraceId: 'parent-123');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.parentTraceId, 'parent-123');
      });

      test('context stores compliance', () {
        final context = PulseContext(compliance: 'GDPR');
        final pulse = Pulse.governed(payload: 42, context: context);
        expect(pulse.context.compliance, 'GDPR');
      });
    });

    group('Policy', () {
      test('policy tracks hops', () {
        int hopCount = 0;
        final policy = PulseEphemeralPolicy(
          hopLimit: 5,
          onEvent: (cell, {required policy}) {
            hopCount = policy.hops + 1;
            return (hops: hopCount);
          },
          onInvalidate: (pulse) {
            return true;
          },
        );
        expect(policy.hops, 0);
        final pulse = Pulse.governed(payload: 42, policy: policy);
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        Cell(receptor: receptor);
        receptor.call(pulse);
        expect(hopCount, 1);
        final pulse2 = Pulse.governed(payload: 42, policy: policy);
        receptor.call(pulse2);
        expect(hopCount, 2);
      });

      test('policy invalidates on hop limit', () {
        bool invalidated = false;
        final policy = PulseEphemeralPolicy(
          hopLimit: 2,
          onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
          onInvalidate: (pulse) {
            invalidated = true;
            return true;
          },
        );
        final pulse = Pulse.governed(payload: 42, policy: policy);
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        Cell(receptor: receptor);
        receptor.call(pulse);
        expect(invalidated, false);
        final pulse2 = Pulse.governed(payload: 42, policy: policy);
        receptor.call(pulse2);
        expect(invalidated, true);
      });

      test('policy invalidates on TTL', () async {
        bool invalidated = false;
        final policy = PulseEphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) {
            invalidated = true;
            return true;
          },
        );
        final pulse = Pulse.governed(payload: 42, policy: policy);
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        Cell(receptor: receptor);
        receptor.call(pulse);
        expect(invalidated, false);
        await Future.delayed(Duration(milliseconds: 20));
        expect(invalidated, true);
      });
    });

    group('Context Factories', () {
      test('userAction factory creates correct context', () {
        final context = PulseContext.userAction(
          baseContext: Context.system,
          actor: 'user_123',
          reason: 'Profile update',
          priority: 60,
        );
        expect(context.actor, 'user_123');
        expect(context.reason, 'Profile update');
        expect(context.strategy, ReasoningStrategy.manual);
        expect(context.confidence, 1.0);
        expect(context.priority, 60);
        expect(context.auditLevel, AuditLevel.standard);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.purpose, 'USER_INTERACTION');
      });

      test('aiInference factory creates correct context', () {
        final context = PulseContext.aiInference(
          baseContext: Context.system,
          actor: 'AI_Model_v3',
          reason: 'Product recommendation',
          confidence: 0.85,
          priority: 20,
        );
        expect(context.actor, 'AI_Model_v3');
        expect(context.reason, 'Product recommendation');
        expect(context.strategy, ReasoningStrategy.probabilistic);
        expect(context.confidence, 0.85);
        expect(context.priority, 20);
        expect(context.auditLevel, AuditLevel.detailed);
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.purpose, 'AUTONOMOUS_OPTIMIZATION');
      });

      test('regulated factory creates correct context', () {
        final context = PulseContext.regulated(
          actor: 'PaymentProcessor',
          framework: 'PCI-DSS',
          reason: 'Payment authorization',
        );
        expect(context.actor, 'PaymentProcessor');
        expect(context.compliance, 'PCI-DSS');
        expect(context.reason, 'Payment authorization');
        expect(context.sensitivity, Sensitivity.confidential);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.priority, 85);
        expect(context.purpose, 'REGULATED_TRANSACTION');
      });

      test('securityIntervention factory creates correct context', () {
        final context = PulseContext.securityIntervention(
          baseContext: Context.system,
          actor: 'Sentinel',
          reason: 'Suspicious activity',
        );
        expect(context.actor, 'Sentinel');
        expect(context.reason, 'SECURITY_SHIELD: Suspicious activity');
        expect(context.strategy, ReasoningStrategy.reflexive);
        expect(context.priority, 100);
        expect(context.sensitivity, Sensitivity.secret);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.purpose, 'THREAT_MITIGATION');
      });

      test('systemInternal factory creates correct context', () {
        final context = PulseContext.systemInternal(
          baseContext: Context.system,
          reason: 'Cache cleanup',
          purpose: 'GARBAGE_COLLECTION',
          priority: 35,
        );
        expect(context.actor, 'system_daemon');
        expect(context.reason, 'Cache cleanup');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 1.0);
        expect(context.priority, 35);
        expect(context.auditLevel, AuditLevel.minimal);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.purpose, 'GARBAGE_COLLECTION');
      });

      test('homeostasis factory creates correct context', () {
        final context = PulseContext.homeostasis(
          actor: 'CacheJanitor',
          reason: 'Memory pressure',
          priority: 15,
        );
        expect(context.actor, 'CacheJanitor');
        expect(context.reason, 'Memory pressure');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 1.0);
        expect(context.priority, 15);
        expect(context.auditLevel, AuditLevel.minimal);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.purpose, 'SYSTEM_MAINTENANCE');
      });

      test('telemetry factory creates correct context', () {
        final context = PulseContext.telemetry(
          baseContext: Context.system,
          actor: 'MetricsCollector',
          reason: 'CPU usage report',
          purpose: 'METRIC_COLLECTION',
          priority: 10,
        );
        expect(context.actor, 'MetricsCollector');
        expect(context.reason, 'CPU usage report');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 1.0);
        expect(context.priority, 10);
        expect(context.auditLevel, AuditLevel.none);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.purpose, 'METRIC_COLLECTION');
      });

      test('instruction factory creates correct context', () {
        final context = PulseContext.instruction(
          baseContext: Context.system,
          humanActor: 'admin_user',
          directive: 'FLUSH_CACHE',
        );
        expect(context.actor, 'admin_user');
        expect(context.reason, 'USER_DIRECTIVE: FLUSH_CACHE');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 1.0);
        expect(context.priority, 90);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.sensitivity, Sensitivity.public);
        expect(context.purpose, 'MANUAL_OVERRIDE');
      });

      test('selfCorrection factory creates correct context', () {
        final context = PulseContext.selfCorrection(
          baseContext: Context.system,
          actor: 'HomeostasisGuard',
          reason: 'Value out of bounds',
          targetField: 'temperature',
          confidence: 0.9,
        );
        expect(context.actor, 'HomeostasisGuard');
        expect(context.reason, 'Homeostasis Recovery (temperature): Value out of bounds');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 0.9);
        expect(context.priority, 85);
        expect(context.auditLevel, AuditLevel.detailed);
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.purpose, 'SELF_HEALING');
      });

      test('collaboration factory creates correct context', () {
        final context = PulseContext.collaboration(
          baseContext: Context.system,
          actor: 'Orchestrator',
          targetAgent: 'WorkerAgent',
          task: 'ProcessData',
        );
        expect(context.actor, 'Orchestrator');
        expect(context.reason, 'DELEGATION: Assigning ProcessData to WorkerAgent');
        expect(context.strategy, ReasoningStrategy.deterministic);
        expect(context.confidence, 1.0);
        expect(context.priority, 60);
        expect(context.auditLevel, AuditLevel.full);
        expect(context.sensitivity, Sensitivity.private);
        expect(context.purpose, 'COLLABORATIVE_TASK');
      });

      test('hypothesis factory creates correct context', () {
        final context = PulseContext.hypothesis(
          baseContext: Context.system,
          actor: 'Predictor',
          theory: 'Memory scaling improves performance',
        );
        expect(context.actor, 'Predictor');
        expect(context.reason, 'HYPOTHESIS_TEST: Memory scaling improves performance');
        expect(context.strategy, ReasoningStrategy.stochastic);
        expect(context.confidence, 0.0);
        expect(context.priority, 20);
        expect(context.auditLevel, AuditLevel.none);
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.purpose, 'SIMULATION');
      });

      test('infrastructureChange factory creates correct context', () {
        final context = PulseContext.infrastructureChange(
          baseContext: Context.system,
          actor: 'Orchestrator',
          reason: 'Scaling up nodes',
        );
        expect(context.actor, 'Orchestrator');
        expect(context.reason, 'Scaling up nodes');
        expect(context.strategy, ReasoningStrategy.formal);
        expect(context.confidence, 1.0);
        expect(context.priority, 40);
        expect(context.auditLevel, AuditLevel.standard);
        expect(context.sensitivity, Sensitivity.internal);
        expect(context.purpose, 'INFRASTRUCTURE_REFACTOR');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // PulseExtension Tests
    // ─────────────────────────────────────────────────────────────────────────

    group('PulseExtension', () {
      // Pulse implements Iterable, so instance Iterable.map / Iterable.cast
      // hide PulseExtension.map / cast. Call them through PulseExtension(pulse),
      // matching PulseIterableExtension.mapEach.
      //
      // Current evolve contract used by map/cast:
      //   evolve(pulse: Pulse<T>(newPayload)) → EvolvedPulse whose parent is
      //   `this`, payload comes from the child pulse (not inherited from root),
      //   no step is passed, context/governance walk the parent, trace walks
      //   _parent so ancestor withStep entries are kept.
      test('Iterable.map on a Pulse is not PulseExtension.map', () {
        final pulse = Pulse<int>(10);
        final mapped = pulse.map((p) => p.payload);
        expect(mapped, isA<Iterable>());
        expect(mapped, [10]);
        expect(mapped, isNot(isA<Pulse>()));
      });

      test('Iterable.cast on a Pulse is not PulseExtension.cast', () {
        final pulse = Pulse<int>(10);
        final casted = pulse.cast<Pulse<int>>();
        expect(casted, isA<Iterable<Pulse<int>>>());
        expect(casted.single, pulse);
        expect(casted, isNot(isA<EvolvedPulse>()));
      });

      test('map transforms payload and preserves causality', () {
        final pulse = Pulse<int>(10);
        final mapped = PulseExtension(pulse).map((value) => 'Count: $value');
        expect(mapped.payload, 'Count: 10');
        expect(mapped, isA<Pulse<String>>());
        expect(mapped.trace, isEmpty);
        expect(mapped.isComposite, isTrue);
        expect(mapped is EvolvedPulse, isTrue);
        expect((mapped as EvolvedPulse).parent, pulse);
        expect((mapped as EvolvedPulse).parent.payload, 10);
        // root is typed PulseBase<P> of the child; a Pulse<int> parent is not
        // a PulseBase<String>, so mixed-type map cannot walk root.
        expect(() => mapped.root, throwsA(isA<TypeError>()));
      });

      test('map does not mutate the original pulse', () {
        final pulse = Pulse<int>(10);
        final mapped = PulseExtension(pulse).map((value) => value * 2);
        expect(pulse.payload, 10);
        expect(pulse is EvolvedPulse, isFalse);
        expect(mapped.payload, 20);
        expect(mapped, isNot(same(pulse)));
      });

      test('map keeps ancestor withStep entries via parent walk', () {
        final pulse = Pulse<int>(10).withStep('counted');
        final mapped = PulseExtension(pulse).map((value) => value + 1);
        expect(mapped.payload, 11);
        expect(mapped.trace, ['counted']);
        expect((mapped as EvolvedPulse).parent, pulse);
        expect(mapped.root.payload, 10);
      });

      test('map keeps the original context and governance on the evolved child', () {
        final pulse = Pulse<int>.governed(
          payload: 3,
          context: PulseContext(actor: 'mapper'),
        );
        final mapped = PulseExtension(pulse).map((value) => value * 2);
        expect(mapped.payload, 6);
        expect(mapped.context.actor, 'mapper');
        expect(mapped.isGoverned, isTrue);
        expect((mapped as EvolvedPulse).parent, pulse);
      });

      test('chained maps nest EvolvedPulse parents', () {
        final root = Pulse<int>(2);
        final doubled = PulseExtension(root).map((value) => value * 3);
        final labelled = PulseExtension(doubled).map((value) => 'x$value');
        expect(labelled.payload, 'x6');
        expect((labelled as EvolvedPulse).parent, doubled);
        expect((doubled as EvolvedPulse).parent, root);
        expect(doubled.root, root);
        expect(() => labelled.root, throwsA(isA<TypeError>()));
      });

      test('same-type map lineage includes parent and child payloads', () {
        final pulse = Pulse<int>(10);
        final mapped = PulseExtension(pulse).map((value) => value * 2);
        expect(mapped.lineage<int>(LineageArgument.payload), [10, 20]);
        expect(mapped.root, pulse);
      });

      test('mixed-type map lineage skips payloads that fail the cast', () {
        final pulse = Pulse<int>(10);
        final mapped = PulseExtension(pulse).map((value) => 'Count: $value');
        expect(mapped.lineage<String>(LineageArgument.payload), ['Count: 10']);
        expect((mapped as EvolvedPulse).parent.payload, 10);
      });

      test('attach adds context metadata', () {
        final pulse = Pulse<int>(42);
        final context = PulseContext(actor: 'admin');
        final attached = pulse.attach(context);
        expect(attached.context.actor, 'admin');
        expect(attached.payload, 42);
        // attach uses evolve with context, so it's NOT EvolvedPulse
        expect(attached is EvolvedPulse, false);
      });

      test('tap executes side-effect without modifying pulse', () {
        var tapped = false;
        final pulse = Pulse<int>(42);
        final result = pulse.tap((value) {
          tapped = true;
          expect(value, 42);
        });
        expect(tapped, true);
        expect(result.payload, 42);
        expect(result, pulse);
      });

      test('cast re-types payload via evolve(pulse:)', () {
        final pulse = Pulse<dynamic>(100);
        final casted = PulseExtension(pulse).cast<int>();
        expect(casted.payload, 100);
        expect(casted, isA<Pulse<int>>());
        expect((casted.payload as int).isEven, isTrue);
        expect(casted is EvolvedPulse, isTrue);
        expect(casted.isComposite, isTrue);
        expect((casted as EvolvedPulse).parent, pulse);
        expect(() => casted.root, throwsA(isA<TypeError>()));
        expect(casted.lineage<dynamic>(LineageArgument.payload), [100, 100]);
      });

      test('cast of a typed pulse still creates an EvolvedPulse child', () {
        final pulse = Pulse<num>(8);
        final casted = PulseExtension(pulse).cast<int>();
        expect(casted.payload, 8);
        expect((casted as EvolvedPulse).parent, pulse);
        expect(casted.lineage<num>(LineageArgument.payload), [8, 8]);
        expect(() => casted.root, throwsA(isA<TypeError>()));
      });

      test('incompatible PulseExtension.cast throws', () {
        final pulse = Pulse<dynamic>('nope');
        expect(
          () => PulseExtension(pulse).cast<int>(),
          throwsA(isA<TypeError>()),
        );
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // PulseIterableExtension Tests
    // ─────────────────────────────────────────────────────────────────────────

    group('PulseIterableExtension', () {
      test('batch creates collective from iterable', () {
        final pulses = [Pulse<int>(1), Pulse<int>(2), Pulse<int>(3)];
        final collective = pulses.batch();
        expect(collective.isComposite, true);
        expect(collective.payload.length, 3);
        expect(collective.payload.elementAt(0).payload, 1);
        expect(collective.payload.elementAt(1).payload, 2);
        expect(collective.payload.elementAt(2).payload, 3);
      });

      test('flatten converts nested collective to flat sequence', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final p3 = Pulse<int>(3);
        final nested = (p1 + p2) + p3;
        final flat = [nested].flatten().toList();
        expect(flat.length, 3);
        expect(flat[0].payload, 1);
        expect(flat[1].payload, 2);
        expect(flat[2].payload, 3);
      });

      test('withStep adds step to all pulses (not EvolvedPulse)', () {
        final pulses = [Pulse<int>(1), Pulse<int>(2)];
        final stepped = pulses.withStep('test').toList();
        expect(stepped.length, 2);
        expect(stepped[0].trace, ['test']);
        expect(stepped[1].trace, ['test']);
        expect(stepped[0] is EvolvedPulse, false);
        expect(stepped[1] is EvolvedPulse, false);
      });

      test('attach adds context to all pulses', () {
        final pulses = [Pulse<int>(1), Pulse<int>(2)];
        final context = PulseContext(actor: 'admin');
        final attached = pulses.attach(context).toList();
        expect(attached.length, 2);
        expect(attached[0].context.actor, 'admin');
        expect(attached[1].context.actor, 'admin');
      });

      test('mapEach transforms payload of each pulse', () {
        final p1 = Pulse<int>(1);
        final p2 = Pulse<int>(2);
        final mapped = [p1, p2].mapEach((value) => 'Value: $value').toList();
        expect(mapped.length, 2);
        expect(mapped[0].payload, 'Value: 1');
        expect(mapped[1].payload, 'Value: 2');
        expect(mapped[0], isA<EvolvedPulse>());
        expect(mapped[1], isA<EvolvedPulse>());
        expect((mapped[0] as EvolvedPulse).parent, p1);
        expect((mapped[1] as EvolvedPulse).parent, p2);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Causal Chain Distinction Tests
    // ─────────────────────────────────────────────────────────────────────────

    group('Causal Chain Distinction', () {
      test('withStep does NOT create parent-child relationship', () {
        final root = Pulse<int>(42);
        final stepped = root.withStep('processed');

        expect(stepped is EvolvedPulse, false);
        expect(stepped.lineage<dynamic>(LineageArgument.payload), [42]);
        expect(stepped.isComposite, false);
      });

      test('evolve(step) does NOT create parent-child relationship', () {
        final root = Pulse<int>(42);
        final evolved = root.evolve(step: 'processed');

        expect(evolved is EvolvedPulse, false);
        expect(evolved.lineage<dynamic>(LineageArgument.payload), [42]);
        expect(evolved.isComposite, false);
      });

      test('evolve(pulse) creates parent-child relationship', () {
        final root = Pulse<int>(42);
        final evolved = root.evolve(pulse: Pulse<int>(43), step: 'transformed');

        expect(evolved is EvolvedPulse, true);
        expect((evolved as EvolvedPulse).parent, root);
        expect(evolved.lineage<dynamic>(LineageArgument.payload), [42, 43]);
        expect(evolved.isComposite, true);
      });

      test('withStep is for documentation, evolve(pulse) is for causal branching', () {
        final root = Pulse<int>(42);

        // withStep - documents the journey without branching
        final documented = root
            .withStep('validated')
            .withStep('sanitized')
            .withStep('transformed');
        expect(documented.trace, ['validated', 'sanitized', 'transformed']);
        expect(documented is EvolvedPulse, false);
        expect(documented.lineage<dynamic>(LineageArgument.payload), [42]);

        // evolve(pulse) - creates causal branches
        final branched = root
            .evolve(pulse: Pulse<int>(43), step: 'validated')
            .evolve(pulse: Pulse<int>(44), step: 'sanitized')
            .evolve(pulse: Pulse<int>(45), step: 'transformed');
        expect(branched.trace, ['validated', 'sanitized', 'transformed']);
        expect(branched is EvolvedPulse, true);
        expect(branched.lineage<dynamic>(LineageArgument.payload), [42, 43, 44, 45]);
      });

      test('withStep does NOT affect root.trace', () {
        final root = Pulse<int>(10);
        final processed = root
            .withStep('sanitized')
            .withStep('validated')
            .withStep('processed');

        expect(root.trace, []);
        expect(processed.trace, ['sanitized', 'validated', 'processed']);
        expect(root, isNot(same(processed)));
        expect(root.lineage<dynamic>(LineageArgument.payload), [10]);
        expect(processed.lineage<dynamic>(LineageArgument.payload), [10]);
        expect(processed is EvolvedPulse, false);
      });

      test('evolve(pulse) affects parent chain but root remains oblivious', () {
        final root = Pulse<int>(10);
        final evolved1 = root.evolve(pulse: Pulse<int>(20), step: 'step1');
        final evolved2 = evolved1.evolve(pulse: Pulse<int>(30), step: 'step2');

        expect(root.trace, []);
        expect(root.lineage<dynamic>(LineageArgument.payload), [10]);

        expect(evolved2.trace, ['step1', 'step2']);
        expect(evolved2.lineage<dynamic>(LineageArgument.payload), [10, 20, 30]);
        expect(evolved2 is EvolvedPulse, true);
        expect((evolved2 as EvolvedPulse).parent, evolved1);
      });

      test('withStep and evolve(pulse) can be combined', () {
        final root = Pulse<int>(10);

        final documented = root
            .withStep('validated')
            .withStep('sanitized');

        final result = documented.evolve(
            pulse: Pulse<int>(20),
            step: 'transformed'
        );

        expect(result is EvolvedPulse, true);
        expect(result.trace, ['validated', 'sanitized', 'transformed']);
        expect(result.lineage<dynamic>(LineageArgument.payload), [10, 20]);

        expect(documented.trace, ['validated', 'sanitized']);
        expect(documented is EvolvedPulse, false);
      });
    });

    group('toString', () {
      test('formats a payload-only pulse', () {
        expect(Pulse<int>(7).toString(), contains('7'));
      });

      test('formats a null payload', () {
        expect(Pulse<int?>(null).toString(), contains('null'));
      });

      test('includes source, type, and trace when present', () {
        final pulse = Pulse<int>(
          1,
          source: TestCell(),
          type: 'event',
          step: 'ingress',
        );
        final text = pulse.toString();
        expect(text, contains('event'));
        expect(text, contains('ingress'));
        expect(text, contains('1'));
      });

      test('collective toString names CollectivePulse', () {
        final text = Pulse.batch([Pulse<int>(1), Pulse<int>(2)]).toString();
        expect(text, contains('CollectivePulse'));
      });

      test('evolved pulse toString names EvolvedPulse', () {
        final text = Pulse<int>(1).evolve(pulse: Pulse<int>(2)).toString();
        expect(text, contains('EvolvedPulse'));
      });
    });

    group('Callbacks and mask variants', () {
      test('onError-only governed pulse is constructible', () {
        final pulse = Pulse<int>.governed(
          payload: 1,
          onError: (pulse, error, {stackTrace}) {},
        );
        expect(pulse.payload, 1);
      });

      test('onProgress-only governed pulse is constructible', () {
        final pulse = Pulse<int>.governed(
          payload: 2,
          onProgress: (pulse, cell, {message}) {},
        );
        expect(pulse.payload, 2);
      });

      test('onComplete and onProgress together', () {
        final pulse = Pulse<int>.governed(
          payload: 3,
          onComplete: (pulse) {},
          onProgress: (pulse, cell, {message}) {},
        );
        expect(pulse.payload, 3);
      });

      test('all three callbacks plus policy and source', () {
        final pulse = Pulse<int>.governed(
          payload: 4,
          source: TestCell(),
          type: 'job',
          step: 'start',
          policy: PulseEphemeralPolicy(
            duration: const Duration(seconds: 5),
            onEvent: (cell, {required policy}) => (hops: 0),
            onInvalidate: (pulse) => true,
          ),
          onComplete: (pulse) {},
          onError: (pulse, error, {stackTrace}) {},
          onProgress: (pulse, cell, {message}) {},
        );
        expect(pulse.isGoverned, isTrue);
        expect(pulse.source, isA<Cell>());
        expect(pulse.type, 'job');
        expect(pulse.trace, ['start']);
      });
    });

    group('Lineage extras', () {
      test('lineage of policy and context walks the chain', () {
        final ctx = PulseContext(actor: 'a');
        final policy = PulseEphemeralPolicy(
          duration: const Duration(seconds: 5),
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) => true,
        );
        final pulse = Pulse<int>.governed(
          payload: 1,
          context: ctx,
          policy: policy,
        );
        expect(pulse.lineage<PulseEphemeralPolicy>(LineageArgument.policy), [policy]);
        expect(pulse.lineage<Context>(LineageArgument.context), isNotEmpty);
      });

      test('equality with a non-Pulse is false', () {
        expect(Pulse<int>(1) == 1, isFalse);
        expect(Pulse<int>(1) == 'pulse', isFalse);
      });
    });

    group('Unmodifiable collective', () {
      test('batch.unmodifiable is a composite with unmodifiable members', () {
        final batch = Pulse.batch([Pulse<int>(1), Pulse<int>(2)]);
        final view = batch.unmodifiable;
        expect(view.isComposite, isTrue);
        expect(view.payload.length, 2);
        expect(view.toString(), contains('UnmodifiableCollectivePulse'));
        expect(view.iterator, isA<Iterator>());
        expect(view.unmodifiable, same(view));
      });

      test('unmodifiable compareTo and equality delegate to the source', () {
        final pulse = Pulse<int>(5);
        final view = pulse.unmodifiable;
        expect(view == pulse, isTrue);
        expect(view.hashCode, pulse.hashCode);
        expect(view.compareTo(pulse), 0);
        expect(view.type, pulse.type);
        expect(view.trace, pulse.trace);
        expect(view.timestamp, pulse.timestamp);
      });

      test('unmodifiable wraps a Cell payload', () {
        final cell = Cell.state<int>(initial: 1).cell;
        final view = Pulse<Cell>(cell).unmodifiable;
        expect(view.payload, isA<Unmodifiable>());
      });

      test('unmodifiable wraps a Map payload containing a Cell', () {
        final cell = Cell.state<int>(initial: 2).cell;
        final view = Pulse<Map>({'c': cell}).unmodifiable;
        expect(view.payload, isA<Map>());
        expect(view.payload?['c'], isA<Unmodifiable>());
      });
    });

    group('Shell extras', () {
      test('shell compareTo follows timestamp then priority', () async {
        final a = Pulse<int>(1).shell;
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final b = Pulse<int>(1, priority: 90).shell;
        expect(a.compareTo(a), 0);
        expect(a.compareTo(b), isNegative);
      });

      test('shell + / evolve / withStep are unsupported', () {
        final shell = Pulse<int>(1).shell;
        expect(() => shell + Pulse<int>(2), throwsUnsupportedError);
        expect(() => shell.evolve(step: 'x'), throwsUnsupportedError);
        expect(() => shell.withStep('x'), throwsUnsupportedError);
        expect(shell.unmodifiable, same(shell));
        expect(shell.shell, same(shell));
        expect(shell.lineage<int>(LineageArgument.payload), isEmpty);
        expect(shell.isGoverned, isFalse);
        expect(shell.isInvalidated, isFalse);
        expect(shell.policy, isNull);
        expect(shell.root, same(shell));
        expect(shell.iterator.moveNext(), isTrue);
      });

      test('shell exposes kernel priority and source', () {
        final source = Cell();
        final pulse = Pulse<int>(1, priority: 40, source: source);
        final shell = pulse.shell;
        expect(shell.priority, 40);
        expect(shell.source, source);
        expect(shell.context, pulse.context);
      });

      test('shell compareTo uses priority then trace when timestamps match', () {
        PulseShell? low;
        PulseShell? high;
        for (var i = 0; i < 200; i++) {
          final a = Pulse<int>(1, priority: 10).shell;
          final b = Pulse<int>(2, priority: 80).shell;
          if (a.timestamp == b.timestamp) {
            low = a;
            high = b;
            break;
          }
        }
        if (low == null || high == null) {
          return;
        }
        expect(low.compareTo(high), isPositive);
        expect(high.compareTo(low), isNegative);
        expect(low.compareTo(Pulse<int>(3, priority: 10).shell), 0);
      });

      test('shell scrutinize catch returns null when the kernel rejects', () {
        final batch = CollectivePulse.governed(
          [Pulse<int>(1)],
          scrutinize: (receptor, {serializedCompletion}) {
            throw StateError('deny');
          },
        );
        expect(
          batch.shell.scrutinize(Receptor.passThrough, null),
          isNull,
        );
      });
    });

    group('Composition extras', () {
      test('+ of mixed payload types still builds a collective', () {
        final mixed = Pulse<int>(1) + Pulse<String>('x');
        expect(mixed, isA<CollectivePulse>());
        expect(mixed.isComposite, isTrue);
      });

      test('a withStep child of a governed pulse stays governed', () {
        final root = Pulse.governed(
          payload: 1,
          context: PulseContext(actor: 'admin'),
        );
        final child = root.withStep('next');
        expect(child.isGoverned, isTrue);
      });

      test('CollectivePulse.governed stores type, context, step, and scrutinize',
          () {
        final ctx = PulseContext(actor: 'batch');
        final batch = CollectivePulse.governed(
          [Pulse<int>(1), Pulse<int>(2)],
          context: ctx,
          type: 'bundle',
          step: 'packed',
          priority: 70,
          onComplete: (_) {},
          scrutinize: (receptor, {serializedCompletion}) => Pulse<int>(9),
        );
        expect(batch.type, 'bundle');
        expect(batch.context.actor, 'batch');
        expect(batch.priority, 70);
        expect(batch.trace, ['packed']);
        expect(
          batch.scrutinize(Receptor.passThrough, null)?.payload,
          9,
        );
        expect(
          batch.scrutinize(
            Receptor.passThrough,
            null,
            {#serializedCompletion: true},
          )?.payload,
          9,
        );
      });

      test('evolved unmodifiable exposes parent, iterator, and toString', () {
        final evolved = Pulse<int>(1).evolve(pulse: Pulse<int>(2), step: 'map');
        final view = evolved.unmodifiable as EvolvedPulse;
        expect(view.parent, isA<Unmodifiable>());
        expect(view.toString(), contains('UnmodifiableEvolvedPulse'));
        expect(view.iterator.moveNext(), isTrue);
        expect(view, isA<Iterable>());
      });

      test('Pulse.evolve(pulse:) with step, context, and a completing parent',
          () {
        final parent = Pulse.governed(
          payload: 1,
          type: 'root',
          priority: 20,
          onComplete: (_) {},
          onError: (p, e, {stackTrace}) {},
          onProgress: (p, c, {message}) {},
        );
        final child = Pulse<int>(2, priority: 5);
        final evolved = parent.evolve(
          pulse: child,
          step: 'mapped',
          context: PulseContext(actor: 'evolver'),
        );
        expect(evolved, isA<EvolvedPulse>());
        expect((evolved as EvolvedPulse).parent, parent);
        expect(evolved.payload, 2);
      });
    });
  });
}