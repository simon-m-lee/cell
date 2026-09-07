// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/pairwise.dart';
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
  group('Pairwise', () {
    test('emits adjacent pairs from the second value', () async {
      final b = bind(Pairwise<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [(1, 2), (2, 3)]);
    });

    test('a single value produces no emission', () async {
      final b = bind(Pairwise<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('wrong types do not become previous', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Pairwise<int>(
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [(1, 2)]);
      expect(errors.single, isA<FormatException>());
    });

    test('marks lineage with Pairwise', () async {
      final b = bind(Pairwise<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.steps, contains('Pairwise'));
    });
  });

  group('PairwiseWith', () {
    test('emits the combined delta', () async {
      final b = bind(PairwiseWith<int, int>((prev, next) => next - prev));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(4);
      await b.gate.emitAsync(6);
      await b.probe.settle();
      expect(b.probe.payloads, [3, 2]);
    });

    test('combine exceptions call onError and still advance previous', () async {
      final errors = <Object>[];
      final b = bind(PairwiseWith<int, int>(
        (prev, next) {
          if (next == 3) throw StateError('skip');
          return next - prev;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(6);
      await b.probe.settle();
      expect(b.probe.payloads, [3]);
      expect(errors.single, isA<StateError>());
    });
  });


  group('Pairwise extra', () {
    test('single value never pairs', () async {
      final b = bind(Pairwise<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('wrong types call onError and do not become previous', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Pairwise<int>(
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(errors.single, isA<FormatException>());
      expect(probe.payloads, [(1, 2)]);
    });

    test('onError is optional', () async {
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Pairwise<int>().toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
    });
  });

  group('PairwiseWith extra', () {
    test('combine throw drops that pair', () async {
      final errors = <Object>[];
      final b = bind(PairwiseWith<int, int>(
        (a, b) {
          if (b == 3) throw StateError('c');
          return b - a;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(5);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = PairwiseWith<int, int>(
        (a, b) => a + b,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(errors.single, isA<FormatException>());
    });
  });

  group('composition / performance', () {
    test('Pairwise + PairwiseWith is a chain', () async {
      final op = Pairwise<int>() +
          PairwiseWith<Object, int>((a, b) => 0);
      final gate = Cell.ingress<int>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('Pairwise emits 199 pairs from 200 ints', () async {
      final b = bind(Pairwise<int>());
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, hasLength(199));
    });
  });
}
