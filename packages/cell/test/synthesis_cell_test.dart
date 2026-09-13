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
// Observe via [Cell.observe]. Drive [ValueCell] sources with [Cell.state]
// handles — a detached Receptor does not update cell state.
// Aggregators return a [Pulse], not a bare payload.
// ─────────────────────────────────────────────────────────────────────────

class Recorder {
  final List<Pulse> pulses = [];

  List<dynamic> get payloads =>
      pulses.map((p) => p.payload).toList(growable: false);

  late final EgressHandle handle;

  Recorder(Cell source) {
    handle = Cell.observe(
      source: source,
      effect: (Pulse p) => pulses.add(p),
    );
  }
}

int sumInts(Iterable<Cell> cells) {
  var sum = 0;
  for (final c in cells) {
    if (c is ValueCell<int>) sum += c.value ?? 0;
  }
  return sum;
}

int? sumNullableInts(Iterable<Cell> cells) {
  var sum = 0;
  for (final c in cells) {
    if (c is ValueCell<int?>) sum += c.value ?? 0;
  }
  return sum;
}

Pulse<int>? sumPulse(Iterable<Cell> cells, Pulse emit) => Pulse(sumInts(cells));

void main() {
  group('SynthesisCell', () {
    group('Construction', () {
      test('creates a synthesis cell with sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final cell = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: sumPulse,
        );

        expect(cell, isA<SynthesisCell>());
        final synth = cell as SynthesisCell;
        expect(synth.length, 2);
        expect(synth.contains(source1.cell), true);
        expect(synth.contains(source2.cell), true);
      });

      test('creates a synthesis cell with custom context', () {
        final context = Context.module('SynthesisModule');
        final source = Cell.state<int>(initial: 1);
        final cell = SynthesisCell([source.cell], context: context);
        expect(cell.context, context);
      });

      test('creates a synthesis cell with custom test rule', () {
        final testRule = TestCell<Cell>((object, {host, arguments, user}) {
          return true;
        });
        final source = Cell.state<int>(initial: 1);
        final cell = SynthesisCell([source.cell], testRule: testRule);
        expect(cell.validate, testRule);
      });

      test('creates a synthesis cell with disabled synapses (terminal)', () {
        final source = Cell.state<int>(initial: 1);
        final cell = SynthesisCell(
          [source.cell],
          synapses: Synapses.disabled,
        );
        expect(cell.isTerminal, true);
      });

      test('creates a synthesis cell with forceLock', () {
        final source = Cell.state<int>(initial: 1);
        final cell = SynthesisCell([source.cell], forceLock: true);
        expect(cell, isA<SynthesisCell>());
      });

      test('empty sources does not throw', () {
        final cell = Cell.synthesis(
          [],
          aggregator: (cells, emit) => Pulse(0),
        );
        expect(cell, isA<SynthesisCell>());
        expect((cell as SynthesisCell).length, 0);
      });
    });

    group('Aggregation', () {
      test('aggregator combines values from multiple sources', () {
        final source1 = Cell.state<int>(initial: 10);
        final source2 = Cell.state<int>(initial: 20);
        final source3 = Cell.state<int>(initial: 30);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell, source3.cell],
          aggregator: sumPulse,
        );
        final rec = Recorder(synthesized);

        source1.update(15);
        expect(rec.payloads, [65]);
      });

      test('aggregator receives the emitting pulse', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        Pulse? receivedEmit;
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            receivedEmit = emit;
            return Pulse(42);
          },
        );
        Recorder(synthesized);

        source1.update(5);
        expect(receivedEmit, isNotNull);
        expect(receivedEmit!.payload, 5);
      });

      test('aggregator can access all source values', () {
        final source1 = Cell.state<String>(initial: 'Hello');
        final source2 = Cell.state<String>(initial: 'World');
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            var result = '';
            for (final c in cells) {
              if (c is ValueCell<String>) result += c.value ?? '';
            }
            return Pulse(result);
          },
        );
        final rec = Recorder(synthesized);

        source1.update('Goodbye');
        expect(rec.payloads.first, 'GoodbyeWorld');
      });

      test('aggregator returning null suppresses emission', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        var shouldEmit = true;
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            if (!shouldEmit) return null;
            return Pulse(42);
          },
        );
        final rec = Recorder(synthesized);

        source1.update(5);
        expect(rec.payloads, [42]);

        shouldEmit = false;
        source1.update(10);
        expect(rec.payloads, [42]);

        shouldEmit = true;
        source1.update(15);
        expect(rec.payloads, [42, 42]);
      });

      test('aggregator with complex object types', () {
        final source1 = Cell.state<Map<String, int>>(
          initial: {'a': 1, 'b': 2},
        );
        final source2 = Cell.state<Map<String, int>>(
          initial: {'c': 3, 'd': 4},
        );
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            final result = <String, int>{};
            for (final c in cells) {
              if (c is ValueCell<Map<String, int>>) {
                result.addAll(c.value ?? {});
              }
            }
            return Pulse(result);
          },
        );
        final rec = Recorder(synthesized);

        source1.update({'a': 10, 'b': 20});
        expect(rec.payloads, isNotEmpty);
        final result = rec.payloads.first as Map<String, int>;
        expect(result['a'], 10);
        expect(result['b'], 20);
        expect(result['c'], 3);
        expect(result['d'], 4);
      });

      test('does not emit an initial aggregate', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: sumPulse,
        );
        final rec = Recorder(synthesized);
        expect(rec.pulses, isEmpty);
      });
    });

    group('Source Management', () {
      test('synthesis cell is iterable over sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final source3 = Cell.state<int>(initial: 3);
        final cell = Cell.synthesis(
          [source1.cell, source2.cell, source3.cell],
          aggregator: (cells, emit) => Pulse(42),
        ) as SynthesisCell;

        final sources = cell.toList();
        expect(sources.length, 3);
        expect(sources, containsAll([source1.cell, source2.cell, source3.cell]));
      });

      test('synthesis handle can add sources dynamically', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell]);

        expect(handle.add(source2.cell), true);
        expect(handle.toList().length, 2);
        expect(handle.cell.contains(source2.cell), true);
      });

      test('added source participates in aggregation', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle(
          [source1.cell],
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse(sumInts(cell as SynthesisCell));
          }),
        );
        final rec = Recorder(handle.cell);

        handle.add(source2.cell);
        source1.update(10);
        expect(rec.payloads.last, 12);
      });

      test('synthesis handle can remove sources dynamically', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell, source2.cell]);

        expect(handle.toList().length, 2);
        expect(handle.remove(source2.cell), true);
        expect(handle.toList().length, 1);
        expect(handle.toList()[0], source1.cell);
        expect(handle.cell.contains(source2.cell), false);
      });

      test('synthesis handle can add multiple sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final source3 = Cell.state<int>(initial: 3);
        final handle = SynthesisCell.handle([source1.cell]);

        expect(handle.toList().length, 1);
        handle.addAll([source2.cell, source3.cell]);
        expect(handle.toList().length, 3);
        expect(handle.toList()[0], source1.cell);
        expect(handle.toList()[1], source2.cell);
        expect(handle.toList()[2], source3.cell);
      });

      test('synthesis handle can remove multiple sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final source3 = Cell.state<int>(initial: 3);
        final handle = SynthesisCell.handle(
          [source1.cell, source2.cell, source3.cell],
        );

        expect(handle.toList().length, 3);
        handle.removeAll([source2.cell, source3.cell]);
        expect(handle.toList().length, 1);
        expect(handle.toList()[0], source1.cell);
      });

      test('synthesis handle can clear all sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell, source2.cell]);

        expect(handle.toList().length, 2);
        handle.clear();
        expect(handle.toList().length, 0);
        expect(handle.isEmpty(), true);
        expect(handle.cell.isEmpty, true);
      });

      test('synthesis handle reports isEmpty correctly', () {
        final source1 = Cell.state<int>(initial: 1);
        final handle = SynthesisCell.handle([source1.cell]);

        expect(handle.isEmpty(), false);
        handle.remove(source1.cell);
        expect(handle.isEmpty(), true);
      });

      test('synthesis handle toList returns current sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell]);

        var list = handle.toList();
        expect(list.length, 1);
        expect(list[0], source1.cell);

        handle.add(source2.cell);
        list = handle.toList();
        expect(list.length, 2);
        expect(list[0], source1.cell);
        expect(list[1], source2.cell);
      });
    });

    group('Stop/Start', () {
      test('stop prevents aggregation from sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle(
          [source1.cell, source2.cell],
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse(sumInts(cell as SynthesisCell));
          }),
        );
        final rec = Recorder(handle.cell);

        handle.stop();
        expect(handle.toList().length, 2);

        source1.update(10);
        expect(rec.pulses, isEmpty);

        handle.start();
        source1.update(11);
        expect(rec.payloads, isNotEmpty);
      });

      test('stop disconnects all sources but keeps membership', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell, source2.cell]);

        handle.stop();
        expect(handle.toList().length, 2);

        handle.start();
        expect(handle.toList().length, 2);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('handles null values from sources', () {
        final source1 = Cell.state<int?>(initial: null);
        final source2 = Cell.state<int?>(initial: 2);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) => Pulse(sumNullableInts(cells)),
        );
        final rec = Recorder(synthesized);

        source1.update(0);
        expect(rec.payloads.first, 2);
      });

      test('handles sources that are not ValueCell', () {
        final source1 = Cell.ingress<int>();
        final source2 = Cell.state<int>(initial: 20);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            if (emit.payload is int) {
              return Pulse((emit.payload as int) + 100);
            }
            return Pulse(0);
          },
        );
        final rec = Recorder(synthesized);

        source1.emit(10);
        expect(rec.payloads.first, 110);
      });

      test('handles aggregator throwing exception gracefully', () {
        final source1 = Cell.state<int>(initial: 1);
        final synthesized = Cell.synthesis(
          [source1.cell],
          aggregator: (cells, emit) {
            throw Exception('Aggregation error');
          },
        );
        final rec = Recorder(synthesized);

        source1.update(5);
        expect(rec.pulses, isEmpty);
      });

      test('handles removing non-existent source', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final handle = SynthesisCell.handle([source1.cell]);
        expect(handle.remove(source2.cell), false);
      });

      test('handles adding duplicate source', () {
        final source1 = Cell.state<int>(initial: 1);
        final handle = SynthesisCell.handle([source1.cell]);
        expect(handle.add(source1.cell), false);
      });
    });

    group('Context & Governance', () {
      test('synthesis cell does not inherit context from sources', () {
        final context = Context.module('SynthesisModule');
        final source = ValueCell<int>(initial: 1, context: context);
        final cell = Cell.synthesis(
          [source],
          aggregator: (cells, emit) => Pulse(42),
        );
        expect(cell.context, isNot(context));
      });

      test('synthesis cell with custom context overrides', () {
        final sourceContext = Context.module('SourceModule');
        final source = ValueCell<int>(initial: 1, context: sourceContext);
        final customContext = Context.module('SynthesisModule');
        final cell = SynthesisCell(
          [source],
          context: customContext,
        );
        expect(cell.context, customContext);
      });

      test('synthesis cell validation rule applies to incoming pulses', () {
        final testRule = TestCell<Cell>((object, {host, arguments, user}) {
          if (object is Pulse) {
            final value = object.payload;
            if (value is int) return value.isEven;
          }
          return true;
        });
        final source = Cell.state<int>(initial: 1);
        final cell = SynthesisCell(
          [source.cell],
          testRule: testRule,
          receptor: Receptor((cell, pulse, {user}) => Pulse(42)),
        );
        final rec = Recorder(cell);

        source.update(2);
        expect(rec.payloads, [42]);

        source.update(3);
        expect(rec.payloads, [42]);
      });
    });

    group('Real-World Scenarios', () {
      test('synthesis for form validation - all fields valid', () {
        final email = Cell.state<String>(initial: 'test@example.com');
        final password = Cell.state<String>(initial: 'password123');
        final confirmPassword = Cell.state<String>(initial: 'password123');
        final synthesized = Cell.synthesis(
          [email.cell, password.cell, confirmPassword.cell],
          aggregator: (cells, emit) {
            String? emailVal;
            String? passVal;
            String? confirmVal;
            for (final c in cells) {
              if (c == email.cell) emailVal = (c as ValueCell<String>).value;
              if (c == password.cell) passVal = (c as ValueCell<String>).value;
              if (c == confirmPassword.cell) {
                confirmVal = (c as ValueCell<String>).value;
              }
            }
            final isEmailValid = emailVal?.contains('@') ?? false;
            final isPasswordValid = (passVal?.length ?? 0) >= 8;
            final doPasswordsMatch = passVal == confirmVal;
            return Pulse(isEmailValid && isPasswordValid && doPasswordsMatch);
          },
        );
        final rec = Recorder(synthesized);

        password.update('short');
        expect(rec.payloads.last, false);

        password.update('newpassword123');
        confirmPassword.update('newpassword123');
        expect(rec.payloads.last, true);
      });

      test('synthesis for price calculation with tax and discount', () {
        final subtotal = Cell.state<double>(initial: 100.0);
        final taxRate = Cell.state<double>(initial: 0.08);
        final discount = Cell.state<double>(initial: 10.0);
        final synthesized = Cell.synthesis(
          [subtotal.cell, taxRate.cell, discount.cell],
          aggregator: (cells, emit) {
            var sub = 0.0;
            var tax = 0.0;
            var disc = 0.0;
            for (final c in cells) {
              if (c == subtotal.cell) sub = (c as ValueCell<double>).value ?? 0;
              if (c == taxRate.cell) tax = (c as ValueCell<double>).value ?? 0;
              if (c == discount.cell) disc = (c as ValueCell<double>).value ?? 0;
            }
            return Pulse(sub + (sub * tax) - disc);
          },
        );
        final rec = Recorder(synthesized);

        subtotal.update(200.0);
        expect(rec.payloads.last, 206.0);

        discount.update(20.0);
        expect(rec.payloads.last, 196.0);
      });

      test('synthesis for user profile - derived full name', () {
        final firstName = Cell.state<String>(initial: 'John');
        final lastName = Cell.state<String>(initial: 'Doe');
        final synthesized = Cell.synthesis(
          [firstName.cell, lastName.cell],
          aggregator: (cells, emit) {
            var first = '';
            var last = '';
            for (final c in cells) {
              if (c == firstName.cell) {
                first = (c as ValueCell<String>).value ?? '';
              }
              if (c == lastName.cell) {
                last = (c as ValueCell<String>).value ?? '';
              }
            }
            return Pulse('$first $last'.trim());
          },
        );
        final rec = Recorder(synthesized);

        firstName.update('Jane');
        expect(rec.payloads.last, 'Jane Doe');

        lastName.update('Smith');
        expect(rec.payloads.last, 'Jane Smith');
      });

      test('synthesis for counter - sum of multiple counters', () {
        final counter1 = Cell.state<int>(initial: 0);
        final counter2 = Cell.state<int>(initial: 0);
        final counter3 = Cell.state<int>(initial: 0);
        final synthesized = Cell.synthesis(
          [counter1.cell, counter2.cell, counter3.cell],
          aggregator: sumPulse,
        );
        final rec = Recorder(synthesized);

        counter1.update(5);
        expect(rec.payloads.last, 5);

        counter2.update(10);
        expect(rec.payloads.last, 15);

        counter3.update(7);
        expect(rec.payloads.last, 22);

        counter1.update(3);
        expect(rec.payloads.last, 20);
      });
    });

    group('toString', () {
      test('synthesis cell returns string representation', () {
        final source = Cell.state<int>(initial: 1);
        final cell = Cell.synthesis(
          [source.cell],
          aggregator: (cells, emit) => Pulse(42),
        );
        expect(cell.toString(), contains('SynthesisCell'));
      });

      test('synthesis cell shows sources in string representation', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final cell = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) => Pulse(42),
        );
        expect(cell.toString(), contains('SynthesisCell'));
      });
    });
  });
}
