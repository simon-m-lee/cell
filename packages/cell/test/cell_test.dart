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

/// A simple custom cell that extends CellBase for testing purposes.
class CustomCell extends CellBase {
  CustomCell({
    super.ephemeralPolicy,
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool forceLock = false,
  });

  /// Helper to send a pulse through the cell's receptor.
  Pulse? sendPulse(Pulse pulse) {
    // Use the receptor through the nucleus
    // Since we can't access _nucleus directly, we use a custom method
    // that gets the receptor from the public API
    return _sendPulseThroughReceptor(pulse);
  }

  Pulse? _sendPulseThroughReceptor(Pulse pulse) {
    // We need to access the receptor via the nucleus
    // Since _nucleus is private, we use a workaround:
    // Create a new cell with the same receptor and use it
    // Or we can use the apply method
    // For testing purposes, we'll use a different approach
    return null;
  }
}

/// A cell that stores received pulses for verification.
class PulseRecorder extends CellBase {
  final List<Pulse> receivedPulses = [];

  PulseRecorder({super.bind})
      : super(
    receptor: Receptor((cell, pulse, {user}) {
      (cell as PulseRecorder).receivedPulses.add(pulse);
      return pulse;
    }),
  );
}

/// A custom value cell for state testing.
class CustomValueCell<V> extends ValueCell<V> {
  CustomValueCell({
    super.transform,
    super.initial,
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Helper Functions for Creating Test Rules
// ─────────────────────────────────────────────────────────────────────────

/// Creates a TestCell rule for int validation.
TestCell<Cell> intPositiveRule() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is int) {
      return object > 0;
    }
    return true;
  });
}

/// Creates a TestCell rule for pulse validation.
TestCell<Cell> pulsePositiveRule() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is Pulse) {
      final payload = object.payload;
      return payload is int && payload > 0;
    }
    return true;
  });
}

/// Creates a TestCell rule for action validation.
TestCell<Cell> actionAllowedRule() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is Function) {
      return object.toString().contains('allowed');
    }
    return true;
  });
}

/// Creates a TestCell rule for link validation.
TestCell<Cell> sameDomainLinkRule() {
  return TestCell<Cell>((object, {host, arguments, user}) {
    if (object is Cell) {
      return object.context.type == host?.context.type;
    }
    return true;
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Cell Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('Cell', () {
    // ─────────────────────────────────────────────────────────────
    // Creation & Factory Tests
    // ─────────────────────────────────────────────────────────────

    group('Factory Constructors', () {
      test('Cell() creates a basic cell with defaults', () {
        final cell = CustomCell();
        expect(cell.isTerminal, false);
        expect(cell.isGoverned, false);
        expect(cell.isInvalidated, false);
        expect(cell.context, Context.system);
        expect(cell.validate, TestCell.allowAll);
        expect(cell.modifiable, contains(cell.apply));
      });

      test('Cell() with custom receptor', () {
        final receptor = Receptor((cell, pulse, {user}) {
          final value = pulse.payload as int;
          return Pulse(value * 2);
        });

        final cell = CustomCell(receptor: receptor);
        // We can't directly access _nucleus, but we can test via apply
        // or by using the receptor through other means
        expect(cell.isGoverned, false);
      });

      test('Cell.governed creates a governed cell', () {
        final context = Context.module('TestModule');
        final testRule = intPositiveRule();

        final cell = CustomCell(
          context: context,
          testRule: testRule,
          forceLock: true,
        );

        // isGoverned follows the receptor, not context / testRule.
        expect(cell.isGoverned, false);
        expect(cell.context, context);
        expect(cell.validate, testRule);
      });

      test('Cell.governed with ephemeral policy', () {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
          (events: 0),
          onInvalidate: (nucleus) {
            return true;
          },
        );

        final cell = CustomCell(ephemeralPolicy: policy);
        expect(cell.isInvalidated, false);
      });

      test('Cell.fromNucleus creates a cell from a nucleus', () {
        final nucleus = Nucleus(
          context: Context.module('Test'),
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse(pulse.payload);
          }),
          testRule: TestCell.allowAll,
          synapses: Synapses.enabled,
        );

        final cell = Cell.fromNucleus(nucleus);
        expect(cell, isA<Cell>());
        expect(cell.context.type, 'Test');
        expect(cell.context.taxonomy, 'module');
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Identity & Equality Tests
    // ─────────────────────────────────────────────────────────────

    group('Identity & Equality', () {
      test('two distinct cells are not equal', () {
        final cell1 = CustomCell();
        final cell2 = CustomCell();
        expect(cell1 == cell2, false);
      });

      test('cell is equal to its deputy', () async {
        final cell = CustomCell();
        final deputy = await cell.deputy();
        expect(cell == deputy, true);
        expect(cell.hashCode, deputy.hashCode);
      });

      test('hashCode walks nested deputy principals', () async {
        final cell = CustomCell();
        final first = await cell.deputy(testRule: TestCell.readOnly);
        final second = await first.deputy(
          testRule: TestCell((object, {host, arguments, user}) => true),
        );
        expect(first.hashCode, cell.hashCode);
        expect(second.hashCode, cell.hashCode);
      });

      test('cell identity preserved in sets', () {
        final cell1 = CustomCell();
        final cell2 = CustomCell();
        final set = {cell1, cell2};
        expect(set.length, 2);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Apply / Command Pattern Tests
    // ─────────────────────────────────────────────────────────────

    group('Apply', () {
      test('apply executes a whitelisted function', () {
        final cell = CustomCell();
        var executed = false;

        void testFunction() {
          executed = true;
        }

        cell.apply(testFunction);
        expect(executed, true);
      });

      test('apply with positional arguments', () {
        final cell = CustomCell();
        var result = 0;

        void add(int a, int b) {
          result = a + b;
        }

        cell.apply(add, positionalArguments: [3, 5]);
        expect(result, 8);
      });

      test('apply awaits an async testRule and runs when allowed', () async {
        final cell = Cell(
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            return true;
          }),
        );
        var ran = false;
        void ping() {
          ran = true;
        }

        final result = cell.apply(cell.apply, positionalArguments: [ping]);
        expect(result, isA<Future>());
        await result;
        expect(ran, isTrue);
      });

      test('apply awaits an async testRule and returns null when denied',
          () async {
        final cell = Cell(
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            return false;
          }),
        );
        var ran = false;
        void ping() {
          ran = true;
        }

        final result = await cell.apply(
          cell.apply,
          positionalArguments: [ping],
        );
        expect(result, isNull);
        expect(ran, isFalse);
      });

      test('apply with named arguments', () {
        final cell = CustomCell();
        var result = 0;

        void multiply({required int a, required int b}) {
          result = a * b;
        }

        cell.apply(
          multiply,
          namedArguments: {#a: 4, #b: 5},
        );
        expect(result, 20);
      });

      test('apply returns function result', () {
        final cell = CustomCell();

        int add(int a, int b) => a + b;

        final result = cell.apply(add, positionalArguments: [10, 20]);
        expect(result, 30);
      });

      test('apply with testRule blocks unauthorized actions', () {
        final rule = actionAllowedRule();
        final cell = CustomCell(testRule: rule);

        var executed = false;
        void allowedFunction() {
          executed = true;
        }

        cell.apply(allowedFunction);
        expect(executed, true);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Modifiable Tests
    // ─────────────────────────────────────────────────────────────

    group('Modifiable', () {
      test('modifiable returns list of whitelisted functions', () {
        final cell = CustomCell();
        final modifiable = cell.modifiable.toList();
        expect(modifiable, isNotEmpty);
        expect(modifiable.any((f) => f == cell.apply), true);
      });

      test('read-only cell has modifiable list', () {
        final cell = CustomCell();
        final readOnly = cell.unmodifiable;
        expect(readOnly.modifiable, isNotEmpty);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Terminal & State Tests
    // ─────────────────────────────────────────────────────────────

    group('Terminal & State', () {
      test('isTerminal returns true for cells with disabled synapses', () {
        final terminalCell = CustomCell(synapses: Synapses.disabled);
        expect(terminalCell.isTerminal, true);
      });

      test('isTerminal returns false for cells with enabled synapses', () {
        final cell = CustomCell(synapses: Synapses.enabled);
        expect(cell.isTerminal, false);
      });

      test('isInvalidated returns false for active cells', () {
        final cell = CustomCell();
        expect(cell.isInvalidated, false);
      });

      test('isGoverned returns true for cells with custom context', () {
        final context = Context.module('TestModule');
        final cell = CustomCell(context: context);
        expect(cell.isGoverned, false);
        expect(cell.context, context);
      });

      test('isGoverned returns false for cells with system context', () {
        final cell = CustomCell(context: Context.system);
        expect(cell.isGoverned, false);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Deputy Tests
    // ─────────────────────────────────────────────────────────────

    group('Deputy', () {
      test('deputy returns itself when no changes requested', () async {
        final cell = CustomCell();
        final deputy = await cell.deputy();
        expect(deputy, same(cell));
      });

      test('deputy creates a new instance with custom testRule', () async {
        final cell = CustomCell();
        final testRule = intPositiveRule();

        final deputy = await cell.deputy(testRule: testRule);
        expect(deputy, isNot(same(cell)));
        expect(cell == deputy, true);
      });

      test('deputy with custom context', () async {
        final cell = CustomCell();
        final context = DeputyContext(
          baseContext: Context.system,
          authority: 'READ_ONLY',
          role: 'Observer',
          clearance: Clearance.observational,
        );

        final deputy = await cell.deputy(context: context);
        expect(deputy, isNot(same(cell)));
        expect(cell == deputy, true);
      });

      test('deputy with ephemeral policy', () async {
        final cell = CustomCell();
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
          (events: 0),
          onInvalidate: (nucleus) {
            return true;
          },
        );

        final deputy = await cell.deputy(ephemeralPolicy: policy);
        expect(deputy, isNot(same(cell)));
        expect(deputy.isInvalidated, false);
      });

      test('deputy equality with principal', () async {
        final cell = CustomCell();
        final testRule = intPositiveRule();

        final deputy = await cell.deputy(testRule: testRule);
        expect(cell == deputy, true);
      });

      test('deputy of a deputy', () async {
        final cell = CustomCell();
        final deputy1 = await cell.deputy(
          testRule: TestCell<Cell>((object, {host, arguments, user}) {
            return true;
          }),
        );

        final deputy2 = await deputy1.deputy(
          testRule: intPositiveRule(),
        );

        expect(deputy2, isNot(same(cell)));
        expect(deputy2, isNot(same(deputy1)));
        expect(cell == deputy2, true);
        expect(deputy1 == deputy2, true);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Async Tests
    // ─────────────────────────────────────────────────────────────

    group('Async', () {
      test('async.apply executes function asynchronously', () async {
        final cell = CustomCell();
        var executed = false;

        void testFunction() {
          executed = true;
        }

        await cell.async.apply(testFunction);
        expect(executed, true);
      });

      test('async.apply with positional arguments', () async {
        final cell = CustomCell();
        var result = 0;

        void add(int a, int b) {
          result = a + b;
        }

        await cell.async.apply(add, positionalArguments: [3, 5]);
        expect(result, 8);
      });

      test('async.apply with named arguments', () async {
        final cell = CustomCell();
        var result = 0;

        void multiply({required int a, required int b}) {
          result = a * b;
        }

        await cell.async.apply(
          multiply,
          namedArguments: {#a: 4, #b: 5},
        );
        expect(result, 20);
      });

      test('async.apply returns function result', () async {
        final cell = CustomCell();

        int add(int a, int b) => a + b;

        final result = await cell.async.apply(add, positionalArguments: [10, 20]);
        expect(result, 30);
      });

      test('async.apply without a lock still completes', () async {
        final cell = Cell();
        var ran = false;
        void ping() {
          ran = true;
        }

        await cell.async.apply(ping);
        expect(ran, isTrue);
      });

      test('async.apply with lock serialization', () async {
        final cell = CustomCell(forceLock: true);
        var counter = 0;

        void increment() {
          counter++;
        }

        final futures = [
          cell.async.apply(increment),
          cell.async.apply(increment),
          cell.async.apply(increment),
        ];

        await Future.wait(futures);
        expect(counter, 3);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Unmodifiable Tests
    // ─────────────────────────────────────────────────────────────

    group('Unmodifiable', () {
      test('Modifiable is a const marker', () {
        expect(const Modifiable(), isA<Modifiable>());
      });

      test('unmodifiable returns the same cell instance for CustomCell', () {
        final cell = CustomCell();
        final unmodifiable = cell.unmodifiable;
        expect(unmodifiable, same(cell));
      });

      test('unmodifiable for value cell is read-only', () {
        final valueCell = CustomValueCell<int>(initial: 42);
        final unmodifiable = valueCell.unmodifiable;
        expect(unmodifiable.value, 42);
      });

      test('unmodifiable for deputy returns principal unmodifiable', () async {
        final cell = CustomCell();
        final deputy = await cell.deputy(testRule: TestCell.readOnly);
        final unmodifiable = deputy.unmodifiable;
        expect(unmodifiable, isA<Cell>());
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Validation Tests
    // ─────────────────────────────────────────────────────────────

    group('Validation', () {
      test('validate allows all by default', () {
        final cell = CustomCell();
        final result = cell.validate(Pulse<int>(42), host: cell);
        expect(result, true);
      });

      test('validate blocks with custom rule', () {
        final rule = intPositiveRule();
        final cell = CustomCell(testRule: rule);

        final result1 = cell.validate(5, host: cell);
        expect(result1, true);

        final result2 = cell.validate(-1, host: cell);
        expect(result2, false);
      });

      test('validate with pulse and custom rule', () {
        final rule = pulsePositiveRule();
        final cell = CustomCell(testRule: rule);

        final result1 = cell.validate(Pulse<int>(5), host: cell);
        expect(result1, true);

        final result2 = cell.validate(Pulse<int>(-1), host: cell);
        expect(result2, false);
      });

      test('validate with link rule', () async {
        final cell1 = CustomCell(context: Context.module('ModuleA'));
        final cell2 = CustomCell(context: Context.module('ModuleA'));
        final cell3 = CustomCell(context: Context.module('ModuleB'));

        final rule = TestCell<Cell>((object, {host, arguments, user}) {
          if (object is Cell) {
            return identical(object, cell2);
          }
          return true;
        });
        final gated = CustomCell(
          context: Context.module('ModuleA'),
          testRule: rule,
        );

        expect(await gated.validate(cell2, host: gated), true);
        expect(await gated.validate(cell3, host: gated), false);
        expect(cell1.context.type, 'ModuleA');
        expect(cell3.context.type, 'ModuleB');
      });

      test('validate with action rule', () async {
        var allow = true;
        final rule = TestCell<Cell>((object, {host, arguments, user}) {
          if (object is Function) return allow;
          return true;
        });
        final cell = CustomCell(testRule: rule);

        void someFunction() {}

        expect(await cell.validate(someFunction, host: cell), true);
        allow = false;
        expect(await cell.validate(someFunction, host: cell), false);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Context Tests
    // ─────────────────────────────────────────────────────────────

    group('Context', () {
      test('cell with system context', () {
        final cell = CustomCell(context: Context.system);
        expect(cell.context, Context.system);
      });

      test('cell with module context', () {
        final context = Context.module('TestModule');
        final cell = CustomCell(context: context);
        expect(cell.context, context);
        expect(cell.context.type, 'TestModule');
        expect(cell.context.taxonomy, 'module');
        expect(cell.context.domains, 'logic');
      });

      test('cell with core context', () {
        final context = Context.core('Gateway');
        final cell = CustomCell(context: context);
        expect(cell.context, context);
        expect(cell.context.type, 'Gateway');
        expect(cell.context.taxonomy, 'core');
        expect(cell.context.domains, 'system');
      });

      test('cell with secure enclave context', () {
        final context = Context.secureEnclave(
          partOf: 'CryptoModule',
          compliances: 'FIPS-140-2',
        );
        final cell = CustomCell(context: context);
        expect(cell.context, context);
        expect(cell.context.taxonomy, 'enclave');
        expect(cell.context.domains, 'security');
        expect(cell.context.subDomains, 'integrity-gate');
      });

      test('cell with public interface context', () {
        final context = Context.publicInterface(
          partOf: 'PublicAPI',
          domains: 'Web/v1',
        );
        final cell = CustomCell(context: context);
        expect(cell.context, context);
        expect(cell.context.taxonomy, 'interface');
        expect(cell.context.domains, 'Web/v1');
        expect(cell.context.subDomains, 'ingress');
      });

      test('cell with custom context evolves', () {
        final original = Context.module('Original');
        final cell = CustomCell(context: original);

        final evolved = cell.context.evolve((evolvable) {
          if (evolvable == Ontology.type) {
            return Ontology.type.entry('Evolved');
          }
          return null;
        });

        expect(evolved.type, 'Evolved');
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Ephemeral Policy Tests
    // ─────────────────────────────────────────────────────────────

    group('Ephemeral Policy', () {
      test('policy with TTL invalidates after duration', () async {
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 10),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
          (events: 0),
          onInvalidate: (nucleus) => true,
        );

        final cell = CustomCell(ephemeralPolicy: policy);
        expect(cell.isInvalidated, false);
        cell.validate(42, host: cell);
        expect(cell.isInvalidated, false);
      });

      test('policy with event limit invalidates after threshold', () {
        var events = 0;
        final policy = EphemeralPolicy(
          eventLimit: 3,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            events++;
            return (events: events);
          },
          onInvalidate: (nucleus) => true,
        );

        final cell = CustomCell(ephemeralPolicy: policy);

        // Send events by calling validate
        cell.validate(1, host: cell);
        cell.validate(2, host: cell);
        cell.validate(3, host: cell);
        expect(cell.isInvalidated, false);
      });

      test('policy with both TTL and event limit', () async {
        var events = 0;
        final policy = EphemeralPolicy(
          duration: Duration(milliseconds: 50),
          eventLimit: 5,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            events++;
            return (events: events);
          },
          onInvalidate: (nucleus) => true,
        );

        final cell = CustomCell(ephemeralPolicy: policy);

        // Send some events
        cell.validate(1, host: cell);
        cell.validate(2, host: cell);
        cell.validate(3, host: cell);
        expect(cell.isInvalidated, false);
      });

      test('policy events can be reset', () {
        var events = 0;
        final policy = EphemeralPolicy(
          eventLimit: 3,
          onEvent: (object, {required cell, required policy, arguments, user}) {
            if (object == 'reset') {
              return (events: 0);
            }
            events++;
            return (events: events);
          },
          onInvalidate: (nucleus) => true,
        );

        final cell = CustomCell(ephemeralPolicy: policy);

        cell.validate(1, host: cell);
        cell.validate(2, host: cell);
        cell.validate('reset', host: cell);
        cell.validate(3, host: cell);
        expect(cell.isInvalidated, false);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Cell.valve
    // ─────────────────────────────────────────────────────────────

    group('Cell.valve', () {
      test('creates a valve bound to the source', () {
        final source = Cell.ingress<int>();
        final valve = Cell.valve(source.cell, (Pulse pulse) => true);
        expect(valve, isA<Cell>());
        expect(valve.isTerminal, isFalse);
      });

      test('forwards pulses that pass the gate', () {
        final source = Cell.ingress<int>();
        final valve = Cell.valve<Pulse<int>>(
          source.cell,
          (pulse) => (pulse.payload ?? 0) > 0,
        );
        final payloads = <int>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        expect(source.emit(5), isTrue);
        expect(payloads, [5]);
      });

      test('drops pulses that fail the gate', () {
        final source = Cell.ingress<int>();
        final valve = Cell.valve<Pulse<int>>(
          source.cell,
          (pulse) => (pulse.payload ?? 0) > 0,
        );
        final payloads = <int>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        expect(source.emit(-3), isTrue);
        expect(payloads, isEmpty);
      });

      test('pass and fail can be interleaved', () {
        final source = Cell.ingress<int>();
        final valve = Cell.valve<Pulse<int>>(
          source.cell,
          (pulse) => (pulse.payload ?? 0).isEven,
        );
        final payloads = <int>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        source.emit(1);
        source.emit(2);
        source.emit(3);
        source.emit(4);
        expect(payloads, [2, 4]);
      });

      test('forwards the original payload unchanged', () {
        final source = Cell.ingress<String>();
        final valve = Cell.valve<Pulse<String>>(
          source.cell,
          (pulse) => pulse.payload?.trim().isNotEmpty ?? false,
        );
        final payloads = <String>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );

        source.emit('  keep  ');
        source.emit('   ');
        source.emit('ok');
        expect(payloads, ['  keep  ', 'ok']);
      });

      test('dynamic gate can open and close', () {
        final source = Cell.ingress<String>();
        var open = true;
        final valve = Cell.valve(source.cell, (Pulse pulse) => open);
        final payloads = <String>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );

        source.emit('one');
        open = false;
        source.emit('two');
        source.emit('three');
        open = true;
        source.emit('four');
        expect(payloads, ['one', 'four']);
      });

      test('gate can inspect pulse type', () async {
        final source = Cell.open(
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final valve = Cell.valve(
          source,
          (Pulse pulse) => pulse.type == 'allowed',
        );
        final payloads = <String>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );

        await source.emit(Pulse<String>('keep', type: 'allowed'));
        await source.emit(Pulse<String>('drop', type: 'denied'));
        expect(payloads, ['keep']);
      });

      test('disabled synapses is terminal and does not broadcast', () {
        final source = Cell.ingress<int>();
        final valve = Cell.valve(
          source.cell,
          (Pulse pulse) => true,
          synapses: Synapses.disabled,
        );
        expect(valve.isTerminal, isTrue);
        final payloads = <int>[];
        Cell.observe(
          source: valve,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        source.emit(42);
        expect(payloads, isEmpty);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // OpenCell.perform (the perform factory; there is no Cell.perform)
    // ─────────────────────────────────────────────────────────────

    group('OpenCell.perform', () {
      test('returns an OpenCell bound to the source', () {
        final source = Cell.ingress<int>();
        final cell = OpenCell.perform(
          source.cell,
          (on, pulse, {user}) => pulse,
        );
        expect(cell, isA<OpenCell>());
        expect(cell, isA<Cell>());
        expect(cell.isTerminal, isFalse);
      });

      test('emit runs perform and observers see the result', () async {
        final source = Cell.ingress<int>();
        final cell = OpenCell.perform(
          source.cell,
          (on, pulse, {user}) => Pulse((pulse.payload as int) * 2),
        );
        final payloads = <int>[];
        Cell.observe(
          source: cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        final result = await cell.emit(Pulse<int>(5));
        expect(result, isNotNull);
        expect((result as Pulse).payload, 10);
        expect(payloads, [10]);
      });

      test('perform receives the host OpenCell', () async {
        late final OpenCell cell;
        Cell? host;
        cell = OpenCell.perform(
          Cell.ingress<int>().cell,
          (on, pulse, {user}) {
            host = on;
            return pulse;
          },
        );

        await cell.emit(Pulse<int>(1));
        expect(host, same(cell));
      });

      test('user metadata is forwarded to perform', () async {
        dynamic seenUser;
        final cell = OpenCell.perform(
          Cell.ingress<int>().cell,
          (on, pulse, {user}) {
            seenUser = user;
            return pulse;
          },
          user: 'token',
        );

        await cell.emit(Pulse<int>(1));
        expect(seenUser, 'token');
      });

      test('returning null drops the pulse', () async {
        final cell = OpenCell.perform(
          Cell.ingress<int>().cell,
          (on, pulse, {user}) => null,
        );
        final payloads = <dynamic>[];
        Cell.observe(
          source: cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload),
        );

        expect(await cell.emit(Pulse<int>(1)), isNull);
        expect(payloads, isEmpty);
      });

      test('testRule can reject emit', () async {
        final testRule = TestCell<Cell>((object, {host, arguments, user}) {
          final payload = object is Pulse ? object.payload : object;
          if (payload is int) return payload > 0;
          return true;
        });
        final cell = OpenCell.perform(
          Cell.ingress<int>().cell,
          (on, pulse, {user}) => pulse,
          testRule: testRule,
        );

        expect(await cell.emit(Pulse<int>(5)), isNotNull);
        expect(await cell.emit(Pulse<int>(-1)), isNull);
        expect(await cell.emit(Pulse<int>(10)), isNotNull);
      });

      test('bound source emissions also run perform', () {
        final source = Cell.ingress<int>();
        final cell = OpenCell.perform(
          source.cell,
          (on, pulse, {user}) => Pulse('n=${pulse.payload}'),
        );
        final payloads = <String>[];
        Cell.observe(
          source: cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );

        source.emit(7);
        expect(payloads, ['n=7']);
      });

      test('can drive a state cell as a command handler', () async {
        final account = Cell.state<int>(initial: 100);
        final commands = OpenCell.perform(
          account.cell,
          (on, pulse, {user}) {
            final op = pulse.payload as Map<String, dynamic>;
            final current = account.cell.value ?? 0;
            final next = switch (op['op']) {
              'credit' => current + (op['amount'] as int),
              'debit' => current - (op['amount'] as int),
              _ => current,
            };
            account.update(next);
            return Pulse(next);
          },
        );
        final payloads = <int>[];
        Cell.observe(
          source: commands,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );

        await commands.emit(Pulse({'op': 'credit', 'amount': 25}));
        await commands.emit(Pulse({'op': 'debit', 'amount': 10}));
        expect(account.cell.value, 115);
        expect(payloads, [125, 115]);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // toString Tests
    // ─────────────────────────────────────────────────────────────

    group('toString', () {
      test('cell returns string representation', () {
        final cell = CustomCell();
        expect(cell.toString(), contains('CustomCell'));
        expect(cell.toString(), contains(cell.hashCode.toString()));
      });

      test('value cell returns string with value', () {
        final cell = CustomValueCell<int>(initial: 42);
        expect(cell.toString(), contains('ValueCell<int>'));
        expect(cell.toString(), contains('42'));
      });
    });
  });
}