// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/async_fold.dart';
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
  group('AsyncFold', () {
    test('emits the running fold', () async {
      final op = AsyncFold<int, int>(0, (acc, n) async => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(op.snapshot.value, 3);
      expect(op.snapshot.generation, 2);
    });

    test('queues a second step until the first finishes', () async {
      final order = <String>[];
      final b = bind(AsyncFold<int, int>(0, (acc, n) async {
        order.add('start-$n');
        await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
        order.add('end-$n');
        return acc + n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(order, ['start-1']);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(order, ['start-1', 'end-1', 'start-2', 'end-2']);
      expect(b.probe.payloads, [1, 3]);
    });

    test('accumulate exceptions keep the previous acc', () async {
      final errors = <Object>[];
      final op = AsyncFold<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('fold');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 4]);
      expect(op.snapshot.value, 4);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError and do not enqueue', () async {
      final errors = <Object>[];
      final op = AsyncFold<int, int>(
        0,
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(5);
      await probe.settle();
      expect(probe.payloads, [5]);
      expect(op.snapshot.value, 5);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('AsyncReduce', () {
    test('uses the first value as the seed', () async {
      final b = bind(AsyncReduce<int>((acc, n) async => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(b.probe.steps, containsAll(['AsyncReduce.seed', 'AsyncReduce']));
    });

    test('accumulate exceptions keep the last good acc', () async {
      final errors = <Object>[];
      final b = bind(AsyncReduce<int>(
        (acc, n) {
          if (n == 2) throw StateError('reduce');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 4]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('AsyncFoldLatest', () {
    test('drops a stale step and keeps the committed acc', () async {
      final op = AsyncFoldLatest<int, int>(0, (acc, n) async {
        await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
        return acc + n * 10;
      });
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [20]);
      expect(op.snapshot.value, 20);
    });

    test('stale errors are not reported', () async {
      final errors = <Object>[];
      final stale = Completer<int>();
      final op = AsyncFoldLatest<String, int>(
        0,
        (acc, n) => n == 'old' ? stale.future : acc + 2,
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await Future<void>.delayed(Duration.zero);
      stale.completeError(StateError('stale'));
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors, isEmpty);
    });
  });

  group('AsyncFoldExhaust', () {
    test('ignores a value while a step is running', () async {
      final op = AsyncFoldExhaust<int, int>(0, (acc, n) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return acc + n;
      });
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(9);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [1]);
      expect(op.snapshot.value, 1);
    });

    test('accepts a value after the step completes', () async {
      final b = bind(AsyncFoldExhaust<int, int>(0, (acc, n) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return acc + n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 40));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 3]);
    });
  });

  group('edges', () {
    test('zero values leave the seed unemitted', () async {
      final op = AsyncFold<int, int>(7, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(op.snapshot.value, 7);
      expect(op.snapshot.generation, 0);
    });

    test('sync accumulate still goes through the future path', () async {
      final b = bind(AsyncFold<int, int>(0, (acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      expect(b.probe.payloads, [4]);
    });

    test('shared snapshot is updated in place', () async {
      final snap = FoldSnapshot<int>(0);
      final op = AsyncFold<int, int>(0, (acc, n) => acc + n, snapshot: snap);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(identical(op.snapshot, snap), isTrue);
      expect(snap.value, 2);
    });
  });

  group('performance', () {
    test('AsyncFold folds 200 ints', () async {
      final sw = Stopwatch()..start();
      final op = AsyncFold<int, int>(0, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      sw.stop();
      expect(op.snapshot.value, 200 * 201 ~/ 2);
      expect(b.probe.payloads, hasLength(200));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
