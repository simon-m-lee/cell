// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/buffer.dart';
import 'package:test/test.dart';

class _Probe {
  final List<Object?> payloads = [];
  final List<String> steps = [];
  late final dynamic _obs;

  _Probe(Cell source) {
    _obs = Cell.observe(
      source: source,
      effect: (Pulse p) {
        payloads.add(p.payload);
        steps.addAll(p.trace.whereType<String>());
      },
    );
  }

  Future<void> settle([Duration d = const Duration(milliseconds: 20)]) =>
      Future<void>.delayed(d);

  void stop() {
    try {
      _obs.stop();
    } catch (_) {}
  }
}

({IngressHandle<T> gate, FlowHandle<T> out, _Probe probe}) bind<T>(
  FlowInstructionBase<Cell, Pulse, Pulse> op,
) {
  final gate = Cell.ingress<T>();
  final out = op.toHandle(source: gate.cell);
  final probe = _Probe(out.cell);
  return (gate: gate, out: out, probe: probe);
}

void main() {
  group('BufferCount', () {
    test('emits tumbling lists of size n', () async {
      final b = bind(BufferCount<int>(2));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4, 5]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('skip slides the window', () async {
      final b = bind(BufferCount<int>(2, skip: 1));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
        [2, 3],
      ]);
    });

    test('wrong types do not fill the buffer', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = BufferCount<int>(
        2,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('x');
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [
        [1, 2],
      ]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('BufferWithCount', () {
    test('is an alias of BufferCount', () async {
      final b = bind(BufferWithCount<int>(2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });
  });

  group('BufferTime', () {
    test('flushes after the duration', () async {
      final b = bind(BufferTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });

    test('skips empty windows', () async {
      final b = bind(BufferTime<int>(const Duration(milliseconds: 25)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 40));
      final after = b.probe.payloads.length;
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads.length, after);
    });
  });

  group('BufferWhen', () {
    test('flushes on closer', () async {
      final close = Cell.ingress<void>();
      final b = bind(BufferWhen<String>(close.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await close.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [
        ['a', 'b'],
      ]);
    });

    test('skips an empty flush', () async {
      final close = Cell.ingress<void>();
      final b = bind(BufferWhen<int>(close.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await close.emitAsync(null);
      await close.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1],
      ]);
    });
  });

  group('BufferWithPredicate', () {
    test('closes when test is true and includes the trigger', () async {
      final b = bind(BufferWithPredicate<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });

    test('includeTrigger false leaves the trigger out', () async {
      final b = bind(BufferWithPredicate<int>(
        (n) => n.isEven,
        includeTrigger: false,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1],
      ]);
    });

    test('test exceptions drop that pulse and keep the buffer', () async {
      final errors = <Object>[];
      final b = bind(BufferWithPredicate<int>(
        (n) {
          if (n == 2) throw StateError('pred');
          return n.isEven;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 4],
      ]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('BufferWithTimeAndCount', () {
    test('count wins before the timer', () async {
      final b = bind(BufferWithTimeAndCount<int>(
        duration: const Duration(milliseconds: 80),
        count: 2,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
      expect(b.probe.steps, contains('BufferWithTimeAndCount.count'));
    });

    test('timer wins when count is not reached', () async {
      final b = bind(BufferWithTimeAndCount<int>(
        duration: const Duration(milliseconds: 30),
        count: 5,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 15));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [
        [1, 2],
      ]);
      expect(b.probe.steps, contains('BufferWithTimeAndCount.time'));
    });

    test('timer restarts after a count flush', () async {
      final b = bind(BufferWithTimeAndCount<int>(
        duration: const Duration(milliseconds: 40),
        count: 2,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, [
        [1, 2],
      ]);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [
        [1, 2],
        [3],
      ]);
    });
  });

  group('edges', () {
    test('a leftover item is not emitted without a closer', () async {
      final b = bind(BufferCount<int>(3));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('predicate close on the first item emits a singleton', () async {
      final b = bind(BufferWithPredicate<int>((n) => true));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1],
      ]);
    });
  });

  group('performance', () {
    test('BufferCount batches 300 items', () async {
      final sw = Stopwatch()..start();
      final b = bind(BufferCount<int>(3));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 300; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(100));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
