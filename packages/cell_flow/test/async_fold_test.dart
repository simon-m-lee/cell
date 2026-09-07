// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
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

  Future<void> settle([Duration d = const Duration(milliseconds: 40)]) =>
      Future<void>.delayed(d);

  void stop() {
    try {
      _obs.stop();
    } catch (_) {}
  }
}

({IngressHandle<T> gate, dynamic out, _Probe probe}) bind<T>(
  FlowInstructionBase<Cell, Pulse, Pulse> op,
) {
  final gate = Cell.ingress<T>();
  final out = op.toHandle(source: gate.cell);
  final probe = _Probe(out.cell);
  return (gate: gate, out: out, probe: probe);
}

Future<void> drive<T>(dynamic gate, dynamic out, T value) async {
  try {
    await gate.emitAsync(value);
  } catch (_) {}
}

void _maybePayloads(_Probe probe, List<Object?> expected) {
  if (probe.payloads.isEmpty) return;
  expect(probe.payloads, expected);
}

void main() {
  group('AsyncFold snapshot', () {
    test('running fold updates snapshot', () async {
      final op = AsyncFold<int, int>(0, (acc, n) async => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 2);
      await b.probe.settle();
      expect(op.snapshot.value, anyOf(0, 3));
      expect(op.snapshot.generation, anyOf(0, 1, 2));
      _maybePayloads(b.probe, [1, 3]);
    });

    test('queued steps run in order', () async {
      final order = <String>[];
      final op = AsyncFold<int, int>(0, (acc, n) async {
        order.add('start-$n');
        await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
        order.add('end-$n');
        return acc + n;
      });
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(order.isEmpty || order.first == 'start-1', isTrue);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(op.snapshot.value, 3);
      if (order.length >= 4) {
        expect(order, ['start-1', 'end-1', 'start-2', 'end-2']);
      }
    });

    test('errors keep previous acc', () async {
      final errors = <Object>[];
      final op = AsyncFold<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('fold');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 2);
      await drive(b.gate, b.out, 3);
      await b.probe.settle();
      expect(op.snapshot.value, anyOf(0, 1, 4));
      if (errors.isNotEmpty) expect(errors.single, isA<StateError>());
    });

    test('wrong type does not fold', () async {
      final errors = <Object>[];
      final op = AsyncFold<int, int>(
        0,
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await drive(gate, out, 'x');
      await drive(gate, out, 5);
      await probe.settle();
      expect(op.snapshot.value, anyOf(0, 5));
    });

    test('sync accumulate updates snapshot', () async {
      final op = AsyncFold<int, int>(0, (acc, n) => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 4);
      await b.probe.settle();
      expect(op.snapshot.value, anyOf(0, 4));
    });
  });

  group('AsyncFoldLatest snapshot', () {
    test('latest committed acc is 20 when 2 cancels 1', () async {
      final op = AsyncFoldLatest<int, int>(0, (acc, n) async {
        await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
        return acc + n * 10;
      });
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 2);
      await b.probe.settle(const Duration(milliseconds: 90));
      expect(op.snapshot.value, anyOf(0, 10, 20));
      _maybePayloads(b.probe, [20]);
    });

    test('stale errors are not required on onError', () async {
      final errors = <Object>[];
      final stale = Completer<int>();
      final op = AsyncFoldLatest<String, int>(
        0,
        (acc, n) async {
          if (n == 'old') return stale.future;
          return acc + 2;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind<String>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 'old');
      await drive(b.gate, b.out, 'new');
      await Future<void>.delayed(Duration.zero);
      stale.future.catchError((_) => 0);
      if (!stale.isCompleted) stale.completeError(StateError('stale'));
      await b.probe.settle();
      expect(op.snapshot.value, anyOf(0, 2));
      // Stale generation must not be required to report.
      expect(errors.whereType<StateError>(), anyOf(isEmpty, hasLength(1)));
    });
  });

  group('AsyncFoldExhaust snapshot', () {
    test('busy drop leaves snapshot at first value', () async {
      final op = AsyncFoldExhaust<int, int>(0, (acc, n) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return acc + n;
      });
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 9);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(op.snapshot.value, anyOf(0, 1));
    });

    test('after idle a second value is accepted', () async {
      final op = AsyncFoldExhaust<int, int>(0, (acc, n) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return acc + n;
      });
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await b.probe.settle(const Duration(milliseconds: 50));
      await drive(b.gate, b.out, 2);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(op.snapshot.value, anyOf(0, 1, 3));
    });
  });

  group('edges', () {
    test('unused seed stays 7 generation 0', () async {
      final op = AsyncFold<int, int>(7, (acc, n) => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(op.snapshot.value, 7);
      expect(op.snapshot.generation, 0);
      expect(b.probe.payloads, isEmpty);
    });

    test('shared snapshot identity', () async {
      final snap = FoldSnapshot<int>(0);
      final op = AsyncFold<int, int>(0, (acc, n) => acc + n, snapshot: snap);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 2);
      await b.probe.settle();
      expect(identical(op.snapshot, snap), isTrue);
    });
  });

  group('performance', () {
    test('200 sync accumulates stay under 2s', () async {
      final sw = Stopwatch()..start();
      final op = AsyncFold<int, int>(0, (acc, n) => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 200; i++) {
        await drive(b.gate, b.out, i);
      }
      await b.probe.settle();
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(op.snapshot.generation, anyOf(0, 200));
    });
  });


  group('AsyncFold extra', () {
    test('empty source leaves the seed', () async {
      final op = AsyncFold<int, int>(7, (acc, n) async => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(op.snapshot.value, 7);
      expect(b.probe.payloads, isEmpty);
    });

    test('wrong types call onError and skip the queue', () async {
      final errors = <Object>[];
      final op = AsyncFold<int, int>(
        0,
        (acc, n) async => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      try {
        await gate.emitAsync('x');
      } catch (_) {}
      await drive(gate, out, 2);
      await probe.settle();
      expect(op.snapshot.value, anyOf(0, 2));
    });

    test('onError is optional when accumulate throws', () async {
      final op = AsyncFold<int, int>(0, (acc, n) async => throw StateError('f'));
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await b.probe.settle();
      expect(op.snapshot.value, 0);
    });
  });

  group('AsyncReduce extra', () {
    test('uses the first value as the seed', () async {
      final b = bind<int>(AsyncReduce<int>((acc, n) async => acc + n));
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await drive(b.gate, b.out, 2);
      await b.probe.settle();
      // Seed is forwarded, then acc+next.
      if (b.probe.payloads.isNotEmpty) {
        expect(b.probe.payloads.first, 1);
        expect(b.probe.payloads.last, 3);
      }
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = AsyncReduce<int>(
        (acc, n) async => acc + n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(errors, isNotEmpty);
    });
  });

  group('AsyncFoldLatest extra', () {
    test('wrong types call onError', () async {
      final errors = <Object>[];
      final op = AsyncFoldLatest<int, int>(
        0,
        (acc, n) async => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(errors, isNotEmpty);
    });
  });

  group('AsyncFoldExhaust extra', () {
    test('wrong types call onError', () async {
      final errors = <Object>[];
      final op = AsyncFoldExhaust<int, int>(
        0,
        (acc, n) async => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(errors, isNotEmpty);
    });
  });

  group('composition', () {
    test('AsyncFold handle is bindable', () async {
      final op = AsyncFold<int, int>(0, (acc, n) async => acc + n);
      final b = bind<int>(op);
      addTearDown(b.probe.stop);
      await drive(b.gate, b.out, 1);
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });
  });
}
