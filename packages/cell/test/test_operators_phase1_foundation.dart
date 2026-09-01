// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ignore_for_file: use_super_parameters, unused_local_variable

// ─────────────────────────────────────────────────────────────────────────
// Test Fixtures
// ─────────────────────────────────────────────────────────────────────────

/// A recording cell that captures pulses for verification.
class RecordingCell extends CellBase {
  final List<Pulse> receivedPulses = [];
  final List<dynamic> receivedPayloads = [];

  RecordingCell({Cell? bind})
      : super(
    bind: bind,
    receptor: Receptor((cell, pulse, {user}) {
      final recorder = cell as RecordingCell;
      recorder.receivedPulses.add(pulse);
      recorder.receivedPayloads.add(pulse.payload);
      return pulse;
    }),
  );
}

/// A simple value cell wrapper for testing.
class TestValueCell<T> extends ValueCell<T> {
  TestValueCell({T? initial, super.context, super.testRule, super.synapses})
      : super(initial: initial);
}

// ─────────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────────

/// Waits for async operations to complete.
Future<void> delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

// ─────────────────────────────────────────────────────────────────────────
// Cell.state Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('Cell.state', () {
    // ─────────────────────────────────────────────────────────────
    // Basic State Tests
    // ─────────────────────────────────────────────────────────────

    group('Basic State', () {
      test('creates a state cell with initial value', () {
        final handle = Cell.state<int>(initial: 42);
        expect(handle.cell.value, 42);
        expect(handle.cell, isA<ValueCell<int>>());
      });

      test('creates a state cell with null initial value', () {
        final handle = Cell.state<int?>(initial: null);
        expect(handle.cell.value, null);
      });

      test('creates a state cell with no initial value', () {
        final handle = Cell.state<int>();
        expect(handle.cell.value, null);
      });

      test('update changes the state value', () {
        final handle = Cell.state<int>(initial: 0);
        final updated = handle.update(42);
        expect(updated, true);
        expect(handle.cell.value, 42);
      });

      test('update multiple times', () {
        final handle = Cell.state<int>(initial: 0);
        handle.update(10);
        expect(handle.cell.value, 10);
        handle.update(20);
        expect(handle.cell.value, 20);
        handle.update(30);
        expect(handle.cell.value, 30);
      });

      test('updateAsync changes the state value', () async {
        final handle = Cell.state<int>(initial: 0);
        final updated = await handle.updateAsync(42);
        expect(updated, true);
        expect(handle.cell.value, 42);
      });

      test('updateAsync with multiple concurrent updates', () async {
        final handle = Cell.state<int>(initial: 0);
        final futures = [
          handle.updateAsync(10),
          handle.updateAsync(20),
          handle.updateAsync(30),
        ];
        await Future.wait(futures);
        expect(handle.cell.value, 30);
      });

      test('cell.async.state reads through the cell lock', () async {
        final handle = Cell.state<int>(initial: 7);
        expect(await handle.cell.async.state, 7);
        await handle.updateAsync(11);
        expect(await handle.cell.async.state, 11);
      });

      test('unlocked ValueNucleus still supports async state and updateAsync',
          () async {
        final handle = ValueCell.create(
          ValueNucleus<int>.from(),
          initial: 4,
        );
        expect(await handle.cell.async.state, 4);
        expect(await handle.updateAsync(9), isTrue);
        expect(handle.cell.value, 9);
        expect(await handle.cell.async.state, 9);
      });

      test('ValueNucleus.from with instruction transforms updates', () {
        final handle = ValueCell.create(
          ValueNucleus<int>.from(
            instruction: Instruction<ValueCell<int>, Pulse, Pulse<int?>>(
              (pulse, {cell, user}) {
                return Pulse((pulse.payload as int) + 1);
              },
            ),
          ),
          initial: 0,
        );
        expect(handle.update(4), isTrue);
        expect(handle.cell.value, 5);
      });

      test('ValueNucleus.evolve hydrates a cell from a principal', () {
        final principal = ValueNucleus<int>();
        final evolved = ValueNucleus<int>.evolve(
          principal: principal,
          testRule: TestCell.readOnly,
        );
        final cell = ValueCell.fromNucleus(evolved, initial: 2);
        expect(cell.value, 2);
        expect(cell.validate, TestCell.readOnly);
      });

      test('ValueNucleus.evolve with instruction transforms updates', () {
        final handle = ValueCell.create(
          ValueNucleus<int>.evolve(
            principal: ValueNucleus<int>(),
            instruction: Instruction<ValueCell<int>, Pulse, Pulse<int?>>(
              (pulse, {cell, user}) {
                return Pulse((pulse.payload as int) * 2);
              },
            ),
          ),
          initial: 1,
        );
        expect(handle.update(3), isTrue);
        expect(handle.cell.value, 6);
      });

      test('ValueNucleus.evolve with passThrough still commits via postProcess',
          () {
        final handle = ValueCell.create(
          ValueNucleus<int>.evolve(
            principal: ValueNucleus<int>(),
            receptor: Receptor.passThrough,
          ),
          initial: 0,
        );
        expect(handle.update(8), isTrue);
        expect(handle.cell.value, 8);
      });

      test('ValueNucleus.evolve with a custom receptor commits via postProcess',
          () {
        final handle = ValueCell.create(
          ValueNucleus<int>.evolve(
            principal: ValueNucleus<int>(),
            receptor: ValueCell.receptor<int>((host, input, {user}) {
              return Pulse((input.payload as int) + 10);
            }),
          ),
          initial: 0,
        );
        expect(handle.update(1), isTrue);
        expect(handle.cell.value, 11);
      });

      test('ValueNucleus.evolve with override uses the override local record',
          () {
        final principal = ValueNucleus<int>();
        final override = ValueNucleus<int>(testRule: TestCell.readOnly);
        final evolved = ValueNucleus<int>.evolve(
          principal: principal,
          override: override,
        );
        final cell = ValueCell.fromNucleus(evolved, initial: 4);
        expect(cell.value, 4);
        expect(cell.validate, TestCell.readOnly);
      });

      test('ValueCell.terminal holds state without broadcasting', () {
        final source = Cell.ingress<int>();
        final cell = ValueCell<int>.terminal(
          initial: 8,
          bind: source.cell,
        );
        expect(cell.isTerminal, isTrue);
        expect(cell.value, 8);
        final seen = <dynamic>[];
        Cell.observe(
          source: cell,
          effect: (Pulse p) => seen.add(p.payload),
        );
        source.emit(3);
        expect(cell.value, 3);
        expect(seen, isEmpty);
      });

      test('ValueCell.receptor persists transformed pulses', () {
        final source = Cell.ingress<int>();
        final cell = ValueCell<int>(
          initial: 0,
          bind: source.cell,
          receptor: ValueCell.receptor<int>((host, input, {user}) {
            return Pulse((input.payload as int) * 3);
          }),
        );
        source.emit(4);
        expect(cell.value, 12);
      });

      test('unmodifiable projects a nested Cell and is already the view', () {
        final inner = ValueCell<int>(initial: 9);
        final outer = ValueCell<Cell>(initial: inner);
        final view = outer.unmodifiable;
        expect(view.value, isA<Unmodifiable>());
        expect((view.value as ValueCell).value, 9);
        expect(view.unmodifiable, same(view));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // State with evolve Tests
    // ─────────────────────────────────────────────────────────────

    group('State with evolve', () {
      test('evolve modifies incoming pulses', () {
        final handle = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final delta = input.payload as int? ?? 0;
            return Pulse(host.value! + delta);
          },
        );
        handle.update(5);
        expect(handle.cell.value, 5);
        handle.update(10);
        expect(handle.cell.value, 15);
      });

      test('evolve can filter updates by returning null', () {
        final handle = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final delta = input.payload as int? ?? 0;
            if (delta < 0) {
              return null;
            }
            return Pulse(host.value! + delta);
          },
        );
        handle.update(5);
        expect(handle.cell.value, 5);
        handle.update(-10);
        expect(handle.cell.value, 5);
        handle.update(3);
        expect(handle.cell.value, 8);
      });

      test('evolve with type conversion', () {
        final handle = Cell.state<String>(
          initial: 'Hello',
          evolve: (host, input) {
            final value = input.payload as String?;
            if (value != null) {
              return Pulse('${host.value!} $value');
            }
            return Pulse(host.value);
          },
        );
        handle.update('World');
        expect(handle.cell.value, 'Hello World');
        handle.update('Again');
        expect(handle.cell.value, 'Hello World Again');
      });

      test('evolve with complex objects', () {
        final handle = Cell.state<List<int>>(
          initial: [],
          evolve: (host, input) {
            final incoming = input.payload;
            if (incoming is! Iterable) return null;
            final newList = List<int>.from(host.value ?? const []);
            for (final item in incoming) {
              if (item is int) newList.add(item);
            }
            return Pulse(newList);
          },
        );
        handle.update([1]);
        expect(handle.cell.value, [1]);
        handle.update([2]);
        expect(handle.cell.value, [1, 2]);
        handle.update([3]);
        expect(handle.cell.value, [1, 2, 3]);
      });

      test('evolve with validation', () {
        final handle = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final value = input.payload as int?;
            if (value == null || value < 0) {
              return null;
            }
            return Pulse(value);
          },
        );
        handle.update(42);
        expect(handle.cell.value, 42);
        handle.update(-5);
        expect(handle.cell.value, 42);
        handle.update(100);
        expect(handle.cell.value, 100);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Ingest Tests
    // ─────────────────────────────────────────────────────────────

    group('Ingest', () {
      test('ingest with pulse', () async {
        final handle = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final value = input.payload as int?;
            if (value != null) {
              return Pulse(host.value! + value);
            }
            return null;
          },
        );
        await handle.ingest(Pulse<int>(5));
        expect(handle.cell.value, 5);
        await handle.ingest(Pulse<int>(10));
        expect(handle.cell.value, 15);
      });

      test('ingest with serialized completion', () async {
        var completed = false;
        final handle = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final value = input.payload as int?;
            if (value != null) {
              completed = true;
              return Pulse(host.value! + value);
            }
            return null;
          },
        );
        await handle.ingest(Pulse<int>(42), serializedCompletion: true);
        expect(completed, true);
        expect(handle.cell.value, 42);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Edge Cases
    // ─────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('state cell with null update', () {
        final handle = Cell.state<int?>(initial: 42);
        handle.update(null);
        expect(handle.cell.value, null);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Cell.ingress Tests
  // ─────────────────────────────────────────────────────────────

  group('Cell.ingress', () {
    // ─────────────────────────────────────────────────────────────
    // Basic Ingress Tests
    // ─────────────────────────────────────────────────────────────

    group('Basic Ingress', () {
      test('creates an ingress cell', () {
        final handle = Cell.ingress<int>();
        expect(handle.cell, isA<Cell>());
        expect(handle.emit, isA<bool Function(int)>());
        expect(handle.emitAsync, isA<Future<bool> Function(int)>());
        expect(handle.ingest, isA<Future<void> Function(Pulse<int>, {bool serializedCompletion})>());
      });

      test('emit sends a pulse through the ingress', () {
        final handle = Cell.ingress<int>();
        final payloads = <int>[];
        Cell.observe(
          source: handle.cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        final result = handle.emit(42);
        expect(result, true);
        expect(payloads, [42]);
      });

      test('emit with refine transforms the input', () {
        final handle = Cell.ingress<String>(
          refine: (cell, input) {
            final raw = input.payload ?? '';
            final trimmed = raw.trim();
            if (trimmed.isEmpty) {
              return null;
            }
            return Pulse(trimmed.toLowerCase());
          },
        );
        final payloads = <String>[];
        Cell.observe(
          source: handle.cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );
        final result = handle.emit('  HELLO WORLD  ');
        expect(result, true);
        expect(payloads, ['hello world']);
      });

      test('emit with refine can filter input', () {
        final handle = Cell.ingress<int>(
          refine: (cell, input) {
            final value = input.payload ?? 0;
            if (value < 0) {
              return null;
            }
            return Pulse(value);
          },
        );
        final result1 = handle.emit(42);
        expect(result1, true);
        final result2 = handle.emit(-5);
        expect(result2, false);
      });

      test('emitAsync sends a pulse asynchronously', () async {
        final handle = Cell.ingress<int>();
        final result = await handle.emitAsync(42);
        expect(result, true);
      });

      test('emitAsync with multiple concurrent emissions', () async {
        final handle = Cell.ingress<int>();
        final payloads = <int>[];
        Cell.observe(
          source: handle.cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        final results = await Future.wait([
          handle.emitAsync(1),
          handle.emitAsync(2),
          handle.emitAsync(3),
        ]);
        expect(results, [true, true, true]);
        expect(payloads, unorderedEquals([1, 2, 3]));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Ingress with Governance Tests
    // ─────────────────────────────────────────────────────────────

    group('Ingress with Governance', () {
      test('ingress with custom context', () {
        final context = Context.module('IngressModule');
        final handle = Cell.ingress<int>(
          context: context,
        );
        expect(handle.cell.context, context);
      });

      test('ingress with test rule', () {
        final testRule = TestCell<Cell>((object, {host, arguments, user}) {
          final payload = object is Pulse ? object.payload : object;
          if (payload is int) return payload > 0;
          return true;
        });
        final handle = Cell.ingress<int>(
          testRule: testRule,
        );
        final result1 = handle.emit(42);
        expect(result1, true);
        final result2 = handle.emit(-5);
        expect(result2, false);
      });

      test('ingress with forceLock', () {
        final handle = Cell.ingress<int>(
          forceLock: true,
        );
        expect(handle.cell, isA<Cell>());
        expect(handle.emit(42), true);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Ingress with Source Binding Tests
    // ─────────────────────────────────────────────────────────────

    group('Ingress with Source Binding', () {
      test('ingress with source bind', () {
        final source = Cell.state<int>(initial: 0);
        final handle = Cell.ingress<int>(
          source: source.cell,
          refine: (cell, input) {
            final value = input.payload ?? 0;
            return Pulse(value * 2);
          },
        );
        source.update(5);
        expect(handle.cell, isA<Cell>());
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Ingest Tests
    // ─────────────────────────────────────────────────────────────

    group('Ingest', () {
      test('ingest with pulse', () async {
        final handle = Cell.ingress<int>();
        final payloads = <int>[];
        Cell.observe(
          source: handle.cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        await handle.ingest(Pulse<int>(42));
        await delay(20);
        expect(payloads, [42]);
      });

      test('ingest with serialized completion', () async {
        var completed = false;
        final handle = Cell.ingress<int>(
          refine: (cell, input) {
            completed = true;
            return input;
          },
        );
        await handle.ingest(Pulse<int>(42), serializedCompletion: true);
        expect(completed, true);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Edge Cases
    // ─────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('ingress with null payload', () {
        final handle = Cell.ingress<int?>();
        final result = handle.emit(null);
        expect(result, true);
      });

      test('ingress with empty string after refine', () {
        final handle = Cell.ingress<String>(
          refine: (cell, input) {
            final raw = input.payload ?? '';
            if (raw.trim().isEmpty) {
              return null;
            }
            return Pulse(raw);
          },
        );
        final result = handle.emit('   ');
        expect(result, false);
      });

      test('ingress with disabled synapses', () {
        final handle = Cell.ingress<int>(synapses: Synapses.disabled);
        expect(handle.cell.isTerminal, isTrue);
        final payloads = <int>[];
        Cell.observe(
          source: handle.cell,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        expect(handle.emit(42), isTrue);
        expect(payloads, isEmpty);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Cell.observe Tests
  // ─────────────────────────────────────────────────────────────

  group('Cell.observe', () {
    test('creates an observer', () {
      final source = Cell.state<int>(initial: 0);
      var received = false;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          received = true;
        },
      );
      expect(handle.cell, isA<Cell>());
      expect(handle.start, isA<void Function()>());
      expect(handle.stop, isA<void Function()>());
      expect(received, false);
    });

    test('observer receives pulses when started', () {
      final source = Cell.state<int>(initial: 0);
      var receivedValue = 0;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          receivedValue = pulse.payload;
        },
      );
      source.update(42);
      expect(receivedValue, 42);
    });

    test('observer can be stopped', () {
      final source = Cell.state<int>(initial: 0);
      var receivedCount = 0;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          receivedCount++;
        },
      );
      source.update(1);
      expect(receivedCount, 1);
      handle.stop();
      source.update(2);
      expect(receivedCount, 1);
      handle.start();
      source.update(3);
      expect(receivedCount, 2);
    });

    test('observer with initiallyStarted false', () {
      final source = Cell.state<int>(initial: 0);
      var receivedCount = 0;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          receivedCount++;
        },
        initiallyStarted: false,
      );
      source.update(1);
      expect(receivedCount, 0);
      handle.start();
      source.update(2);
      expect(receivedCount, 1);
    });

    test('observer with multiple pulses', () {
      final source = Cell.state<int>(initial: 0);
      final values = <int>[];
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          values.add(pulse.payload);
        },
      );
      source.update(1);
      source.update(2);
      source.update(3);
      expect(values, [1, 2, 3]);
    });

    test('observer with String pulses', () {
      final source = Cell.state<String>(initial: '');
      final values = <String>[];
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          values.add(pulse.payload);
        },
      );
      source.update('Hello');
      source.update('World');
      expect(values, ['Hello', 'World']);
    });

    test('observer with complex object pulses', () {
      final source = Cell.state<List<int>>(initial: []);
      final values = <List<int>>[];
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          values.add(pulse.payload);
        },
      );
      source.update([1, 2]);
      source.update([3, 4]);
      expect(values, [
        [1, 2],
        [3, 4]
      ]);
    });

    test('observer with governed pulse', () async {
      final source = Cell.ingress<int>();
      var actor = '';
      Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          actor = pulse.context.actor ?? '';
        },
      );
      await source.ingest(
        Pulse<int>.governed(
          payload: 42,
          context: PulseContext(actor: 'test_actor'),
        ),
      );
      expect(actor, 'test_actor');
    });

    test('observer with null payload', () {
      final source = Cell.state<int?>(initial: 0);
      var receivedNull = false;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          if (pulse.payload == null) {
            receivedNull = true;
          }
        },
      );
      source.update(null);
      expect(receivedNull, true);
    });

    test('observer stop called multiple times', () {
      final source = Cell.state<int>(initial: 0);
      var count = 0;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          count++;
        },
      );
      handle.stop();
      handle.stop();
      source.update(1);
      expect(count, 0);
    });

    test('observer start called multiple times', () {
      final source = Cell.state<int>(initial: 0);
      var count = 0;
      final handle = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) {
          count++;
        },
        initiallyStarted: false,
      );
      handle.start();
      handle.start();
      source.update(1);
      expect(count, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Cell.derive Tests
  // ─────────────────────────────────────────────────────────────

  group('Cell.derive', () {
    group('Basic Derive', () {
      test('creates a derived cell', () {
        final source = Cell.state<int>(initial: 42);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        expect(derived, isA<Cell>());
      });

      test('derive transforms the source value', () {
        final source = Cell.state<int>(initial: 10);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        final payloads = <int>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        source.update(5);
        expect(payloads, [10]);
      });

      test('derive with type conversion', () {
        final source = Cell.state<int>(initial: 42);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse('Value: ${pulse.payload}'),
        );
        final payloads = <String>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );
        source.update(100);
        expect(payloads, ['Value: 100']);
      });

      test('derive with multiple transformations', () {
        final source = Cell.state<int>(initial: 0);
        final derived1 = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload + 1),
        );
        final derived2 = Cell.derive(
          source: derived1,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        final payloads = <int>[];
        Cell.observe(
          source: derived2,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        source.update(5);
        expect(payloads, [12]);
      });
    });

    group('Derive with Filtering', () {
      test('derive can filter by returning null', () {
        final source = Cell.state<int>(initial: 0);
        // Explicit type parameters: Input is Pulse<int>, Output is Pulse<int>
        final derived = Cell.derive<Pulse<int>, Pulse<int>>(
          source: source.cell,
          project: (Pulse<int> pulse) {
            final value = pulse.payload;
            if (value! % 2 == 0) {
              return Pulse(value);
            }
            // Returning null filters out odd numbers
            return null;
          },
        );
        final payloads = <int>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        source.update(2);
        source.update(3);
        source.update(4);
        expect(payloads, [2, 4]);
      });

      test('derive filter with complex condition', () {
        final source = Cell.state<String>(initial: '');
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) {
            final value = pulse.payload;
            if (value.isNotEmpty && value.length > 3) {
              return Pulse(value.toUpperCase());
            }
            return null;
          },
        );
        final payloads = <String>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );
        source.update('Hi');
        source.update('Hello');
        source.update('A');
        source.update('World');
        expect(payloads, ['HELLO', 'WORLD']);
      });
    });

    group('Edge Cases', () {
      test('derive with null source value', () {
        final source = Cell.state<int?>(initial: null);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) {
            final value = pulse.payload;
            if (value == null) {
              return Pulse('No value');
            }
            return Pulse('Value: $value');
          },
        );
        final payloads = <String>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as String),
        );
        source.update(42);
        expect(payloads, ['Value: 42']);
      });

      test('derive with project that throws', () {
        final source = Cell.state<int>(initial: 0);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) {
            if (pulse.payload == 0) {
              throw Exception('Zero not allowed');
            }
            return Pulse(pulse.payload * 2);
          },
        );
        final payloads = <int>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        source.update(0);
        source.update(5);
        expect(payloads, [10]);
      });

      test('derive with source changes multiple times', () {
        final source = Cell.state<int>(initial: 0);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        final payloads = <int>[];
        Cell.observe(
          source: derived,
          effect: (Pulse pulse) => payloads.add(pulse.payload as int),
        );
        source.update(1);
        source.update(2);
        source.update(3);
        expect(payloads, [2, 4, 6]);
      });
    });

    group('Combined Operators', () {
      test('state + derive + observe', () {
        final source = Cell.state<int>(initial: 0);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: derived,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );
        source.update(5);
        expect(receivedValue, 10);
        source.update(10);
        expect(receivedValue, 20);
      });

      test('ingress + derive + observe', () {
        final ingress = Cell.ingress<int>();
        final derived = Cell.derive(
          source: ingress.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 3),
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: derived,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );
        ingress.emit(5);
        expect(receivedValue, 15);
        ingress.emit(10);
        expect(receivedValue, 30);
      });

      test('state + derive + state', () {
        final source = Cell.state<int>(initial: 0);
        final derived = Cell.derive(
          source: source.cell,
          project: (Pulse pulse) => Pulse(pulse.payload * 2),
        );
        final target = Cell.state<int>(
          initial: 0,
          evolve: (host, input) {
            final value = input.payload as int?;
            if (value != null) {
              return Pulse(value);
            }
            return null;
          },
        );
        // Link the derived cell to the target via the observer pattern
        final observer = Cell.observe(
          source: derived,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );
        source.update(5);
        expect(target.cell.value, 10);
        source.update(7);
        expect(target.cell.value, 14);
      });
    });
  });
}