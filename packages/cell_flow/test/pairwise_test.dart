// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
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
}
