// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
//
// Debounce / throttle / distinct drop pulses whose `source` is not the
// bound cell. [Cell.ingress] sets that; [ValueCell._emit] does not.
// Observe via [Cell.observe], not a detached recorder.
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

Future<void> delay(int milliseconds) =>
    Future.delayed(Duration(milliseconds: milliseconds));

int sumInts(Iterable<Cell> cells) {
  var sum = 0;
  for (final c in cells) {
    if (c is ValueCell<int>) sum += c.value ?? 0;
  }
  return sum;
}

void main() {
  group('Phase 2: Flow Control Operators', () {
    group('Cell.debounce', () {
      test('creates a debounce cell with default leading false', () {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
        );
        expect(debounced, isA<Cell>());
      });

      test('debounce delays delivery until silence', () async {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
        );
        final rec = Recorder(debounced);

        source.emit(42);
        expect(rec.pulses, isEmpty);

        await delay(80);
        expect(rec.payloads, [42]);
      });

      test('debounce resets timer on each pulse', () async {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
        );
        final rec = Recorder(debounced);

        source.emit(1);
        await delay(20);
        source.emit(2);
        await delay(20);
        source.emit(3);
        expect(rec.pulses, isEmpty);

        await delay(80);
        expect(rec.payloads, [3]);
      });

      test('debounce with leading true emits first immediately', () async {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
          leading: true,
        );
        final rec = Recorder(debounced);

        source.emit(1);
        expect(rec.payloads, [1]);

        source.emit(2);
        expect(rec.payloads, [1]);

        await delay(80);
        expect(rec.payloads, [1, 2]);
      });

      test('debounce with zero duration delivers immediately', () async {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(source.cell, Duration.zero);
        final rec = Recorder(debounced);

        source.emit(42);
        expect(rec.payloads, [42]);
      });

      test('debounce cancels a pending timer when the output is invalidated', () async {
        final policy = EphemeralPolicy(
          duration: const Duration(milliseconds: 20),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 0),
          onInvalidate: (_) => true,
        );
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
          ephemeralPolicy: policy,
        );
        final rec = Recorder(debounced);

        source.emit(1);
        await delay(60);
        expect(rec.payloads, [1]);

        source.emit(2);
        await delay(40);
        expect(debounced.isInvalidated, isTrue);

        source.emit(3);
        await delay(80);
        expect(rec.payloads, [1]);
      });

      test('debounce with leading true and zero duration emits immediately', () {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration.zero,
          leading: true,
        );
        final rec = Recorder(debounced);

        source.emit(1);
        expect(rec.payloads, [1]);
        source.emit(2);
        expect(rec.payloads, [1, 2]);
      });

      test('debounce with leading true and burst of three', () async {
        final source = Cell.ingress<int>();
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 50),
          leading: true,
        );
        final rec = Recorder(debounced);

        source.emit(1);
        expect(rec.payloads, [1]);

        await delay(20);
        source.emit(2);
        await delay(20);
        source.emit(3);
        expect(rec.payloads, [1]);

        await delay(80);
        expect(rec.payloads, [1, 3]);
      });
    });

    group('Cell.throttle', () {
      test('creates a throttle cell with defaults', () {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 50),
        );
        expect(throttled, isA<Cell>());
      });

      test('throttle with leading true emits first immediately', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 50),
          leading: true,
        );
        final rec = Recorder(throttled);

        source.emit(1);
        expect(rec.payloads, [1]);

        source.emit(2);
        expect(rec.payloads, [1]);
      });

      test('throttle suppresses pulses during window', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 50),
          leading: true,
        );
        final rec = Recorder(throttled);

        source.emit(1);
        expect(rec.payloads, [1]);

        source.emit(2);
        source.emit(3);
        expect(rec.payloads, [1]);

        await delay(80);
        source.emit(4);
        expect(rec.payloads, [1, 4]);
      });

      test('throttle with trailing true emits last during window', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 100),
          leading: true,
          trailing: true,
        );
        final rec = Recorder(throttled);

        source.emit(1);
        expect(rec.payloads, [1]);

        await delay(10);
        source.emit(2);
        await delay(10);
        source.emit(3);
        expect(rec.payloads, [1]);

        await delay(150);
        expect(rec.payloads, [1, 3]);
      });

      test('throttle with leading false only emits trailing', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 50),
          leading: false,
          trailing: true,
        );
        final rec = Recorder(throttled);

        source.emit(1);
        expect(rec.pulses, isEmpty);

        await delay(80);
        expect(rec.payloads, [1]);
      });

      test('throttle with zero duration delivers the leading pulse', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(source.cell, Duration.zero);
        final rec = Recorder(throttled);

        source.emit(1);
        source.emit(2);
        source.emit(3);
        expect(rec.payloads, [1]);

        await delay(20);
        expect(rec.payloads, [1]);
      });

      test('throttle with leading false and trailing false emits nothing',
          () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 50),
          leading: false,
          trailing: false,
        );
        final rec = Recorder(throttled);

        source.emit(1);
        source.emit(2);
        source.emit(3);
        expect(rec.pulses, isEmpty);

        await delay(80);
        expect(rec.pulses, isEmpty);
      });
    });

    group('Cell.distinct', () {
      test('creates a distinct cell with default equality', () {
        final source = Cell.ingress<int>();
        expect(Cell.distinct(source.cell), isA<Cell>());
      });

      test('distinct filters consecutive duplicates', () async {
        final source = Cell.ingress<int>();
        final rec = Recorder(Cell.distinct(source.cell));

        source.emit(1);
        expect(rec.payloads, [1]);

        source.emit(1);
        expect(rec.payloads, [1]);

        source.emit(2);
        expect(rec.payloads, [1, 2]);

        source.emit(2);
        expect(rec.payloads, [1, 2]);
      });

      test('distinct allows non-consecutive duplicates', () async {
        final source = Cell.ingress<int>();
        final rec = Recorder(Cell.distinct(source.cell));

        source.emit(1);
        source.emit(2);
        source.emit(1);
        expect(rec.payloads, [1, 2, 1]);
      });

      test('distinct with custom equals function', () async {
        final source = Cell.ingress<String>();
        final distinct = Cell.distinct(
          source.cell,
          equals: (a, b) =>
              a?.toString().toLowerCase() == b?.toString().toLowerCase(),
        );
        final rec = Recorder(distinct);

        source.emit('Hello');
        expect(rec.payloads, ['Hello']);

        source.emit('hello');
        expect(rec.payloads, ['Hello']);

        source.emit('World');
        expect(rec.payloads, ['Hello', 'World']);
      });

      test('distinct with custom equals on objects', () async {
        final source = Cell.ingress<Map<String, int>>();
        final distinct = Cell.distinct(
          source.cell,
          equals: (a, b) {
            if (a == null && b == null) return true;
            if (a is! Map || b is! Map) return false;
            return a.length == b.length &&
                a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);
          },
        );
        final rec = Recorder(distinct);

        source.emit({'a': 1});
        expect(rec.payloads, [
          {'a': 1}
        ]);

        source.emit({'a': 1});
        expect(rec.payloads, [
          {'a': 1}
        ]);

        source.emit({'a': 2});
        expect(rec.payloads.last, {'a': 2});
        expect(rec.pulses, hasLength(2));
      });

      test('distinct handles null values', () async {
        final source = Cell.ingress<int?>();
        final rec = Recorder(Cell.distinct(source.cell));

        source.emit(null);
        expect(rec.payloads, [null]);

        source.emit(null);
        expect(rec.payloads, [null]);

        source.emit(42);
        expect(rec.payloads, [null, 42]);
      });
    });

    group('Cell.synthesis', () {
      test('creates a synthesis cell with sources', () {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) => Pulse(sumInts(cells)),
        );
        expect(synthesized, isA<Cell>());
      });

      test('synthesis aggregates values from sources', () async {
        final source1 = Cell.state<int>(initial: 10);
        final source2 = Cell.state<int>(initial: 20);
        final source3 = Cell.state<int>(initial: 30);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell, source3.cell],
          aggregator: (cells, emit) => Pulse(sumInts(cells)),
        );
        final rec = Recorder(synthesized);

        source1.update(15);
        expect(rec.payloads, [65]);
      });

      test('synthesis receives the triggering pulse', () async {
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

      test('synthesis with null suppression', () async {
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

      test('synthesis with complex object types', () async {
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

      test('synthesis with multiple source types', () async {
        final source1 = Cell.state<int>(initial: 5);
        final source2 = Cell.state<String>(initial: 'hello');
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            int? num;
            String? str;
            for (final c in cells) {
              if (c is ValueCell<int>) num = c.value;
              if (c is ValueCell<String>) str = c.value;
            }
            return Pulse('$num - $str');
          },
        );
        final rec = Recorder(synthesized);

        source1.update(10);
        expect(rec.payloads.last, '10 - hello');

        source2.update('world');
        expect(rec.payloads.last, '10 - world');
      });

      test('synthesis with empty sources does not throw', () {
        final cell = Cell.synthesis(
          [],
          aggregator: (cells, emit) => Pulse(0),
        );
        expect(cell, isA<SynthesisCell>());
        expect((cell as SynthesisCell).length, 0);
      });

      test('synthesis with single source', () async {
        final source = Cell.state<int>(initial: 42);
        final synthesized = Cell.synthesis(
          [source.cell],
          aggregator: (cells, emit) {
            final c = cells.first;
            return Pulse(c is ValueCell<int> ? c.value ?? 0 : 0);
          },
        );
        final rec = Recorder(synthesized);

        source.update(100);
        expect(rec.payloads, [100]);
      });
    });

    group('Combined Operators', () {
      test('debounce then distinct', () async {
        final source = Cell.ingress<int>();
        // Debounce rewrites pulse.source to the debounce cell, so distinct
        // can see those pulses. Distinct-then-debounce drops them.
        final debounced = Cell.debounce(
          source.cell,
          Duration(milliseconds: 30),
        );
        final rec = Recorder(Cell.distinct(debounced));

        source.emit(1);
        source.emit(1);
        source.emit(2);
        await delay(60);
        expect(rec.payloads, [2]);

        source.emit(2);
        await delay(60);
        expect(rec.payloads, [2]);

        source.emit(3);
        await delay(60);
        expect(rec.payloads, [2, 3]);
      });

      test('throttle then distinct', () async {
        final source = Cell.ingress<int>();
        final throttled = Cell.throttle(
          source.cell,
          Duration(milliseconds: 30),
          leading: true,
        );
        final rec = Recorder(Cell.distinct(throttled));

        source.emit(1);
        source.emit(1);
        source.emit(2);
        expect(rec.payloads, [1]);

        await delay(50);
        source.emit(3);
        expect(rec.payloads, [1, 3]);
      });

      test('synthesis then observe (debounce of synthesis is source-gated)',
          () async {
        final source1 = Cell.state<int>(initial: 1);
        final source2 = Cell.state<int>(initial: 2);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) => Pulse(sumInts(cells)),
        );
        final rec = Recorder(synthesized);

        source1.update(5);
        source2.update(10);
        source1.update(15);
        source2.update(20);
        expect(rec.payloads.last, 35);
        expect(rec.pulses.length, greaterThanOrEqualTo(1));
      });

      test('synthesis consecutive equal sums still fire (no distinct)',
          () async {
        final source1 = Cell.state<int>(initial: 10);
        final source2 = Cell.state<int>(initial: 20);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) => Pulse(sumInts(cells)),
        );
        final rec = Recorder(synthesized);

        source1.update(15);
        expect(rec.payloads, [35]);

        source2.update(25);
        expect(rec.payloads, [35, 40]);
      });

      test('synthesis for form validation', () async {
        final email = Cell.state<String>(initial: '');
        final password = Cell.state<String>(initial: '');
        final confirm = Cell.state<String>(initial: '');

        final isValid = Cell.synthesis(
          [email.cell, password.cell, confirm.cell],
          aggregator: (cells, emit) {
            final e = (cells.elementAt(0) as ValueCell<String>).value ?? '';
            final p = (cells.elementAt(1) as ValueCell<String>).value ?? '';
            final c = (cells.elementAt(2) as ValueCell<String>).value ?? '';
            return Pulse(
              e.contains('@') && p.length >= 8 && p == c,
            );
          },
        );
        final rec = Recorder(isValid);

        email.update('test@example.com');
        expect(rec.payloads.last, false);

        password.update('password123');
        expect(rec.payloads.last, false);

        confirm.update('password123');
        expect(rec.payloads.last, true);

        email.update('test@example.com');
        expect(rec.payloads.last, true);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('debounce with negative duration throws', () {
        final source = Cell.ingress<int>();
        expect(
          () => Cell.debounce(
            source.cell,
            const Duration(milliseconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throttle with negative duration throws', () {
        final source = Cell.ingress<int>();
        expect(
          () => Cell.throttle(
            source.cell,
            const Duration(milliseconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('distinct with null values and custom equals', () async {
        final source = Cell.ingress<String?>();
        final rec = Recorder(
          Cell.distinct(source.cell, equals: (a, b) => a == b),
        );

        source.emit(null);
        expect(rec.payloads, [null]);

        source.emit(null);
        expect(rec.payloads, [null]);

        source.emit('hello');
        expect(rec.payloads, [null, 'hello']);
      });

      test('synthesis with sources that are not ValueCell', () async {
        final source1 = Cell.ingress<int>();
        final source2 = Cell.state<int>(initial: 42);
        final synthesized = Cell.synthesis(
          [source1.cell, source2.cell],
          aggregator: (cells, emit) {
            int? val;
            for (final c in cells) {
              if (c is ValueCell<int>) val = c.value;
            }
            return Pulse(val ?? 0);
          },
        );
        final rec = Recorder(synthesized);

        source2.update(7);
        expect(rec.payloads, [7]);
      });

      test('synthesis with aggregator throwing exception', () async {
        final source = Cell.state<int>(initial: 0);
        final synthesized = Cell.synthesis(
          [source.cell],
          aggregator: (cells, emit) {
            throw Exception('Aggregation error');
          },
        );
        final rec = Recorder(synthesized);

        source.update(5);
        expect(rec.pulses, isEmpty);
      });
    });

    group('toString', () {
      test('debounce cell toString', () {
        final source = Cell.ingress<int>();
        final debounced =
            Cell.debounce(source.cell, Duration(milliseconds: 50));
        expect(debounced.toString(), contains('Cell'));
      });

      test('throttle cell toString', () {
        final source = Cell.ingress<int>();
        final throttled =
            Cell.throttle(source.cell, Duration(milliseconds: 50));
        expect(throttled.toString(), contains('Cell'));
      });

      test('distinct cell toString', () {
        final source = Cell.ingress<int>();
        expect(Cell.distinct(source.cell).toString(), contains('Cell'));
      });

      test('synthesis cell toString', () {
        final source = Cell.state<int>(initial: 0);
        final synthesized = Cell.synthesis(
          [source.cell],
          aggregator: (cells, emit) => Pulse(0),
        );
        expect(synthesized, isA<SynthesisCell>());
        expect(synthesized.toString(), isNotEmpty);
      });
    });
  });
}
