// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/partition.dart';
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
  group('Partition', () {
    test('tags each value', () async {
      final b = bind(Partition<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        const Split(matched: false, value: 1),
        const Split(matched: true, value: 2),
      ]);
    });

    test('test exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(Partition<int>(
        (n) => throw StateError('test'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Partition<int>(
        (n) => n.isEven,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('PartitionMap', () {
    test('maps each side', () async {
      final b = bind(PartitionMap<int, String>(
        (n) => n.isEven,
        thenMap: (n) => 'even-$n',
        elseMap: (n) => 'odd-$n',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, ['odd-1', 'even-2']);
    });

    test('mapper exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(PartitionMap<int, int>(
        (n) => n.isEven,
        thenMap: (n) => throw StateError('then'),
        elseMap: (n) => n,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('PartitionCollect', () {
    test('fills both buckets', () async {
      final op = PartitionCollect<int>((n) => n.isEven);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(op.matched, [2]);
      expect(op.other, [1]);
      expect(b.probe.payloads.last, {
        'matched': [2],
        'other': [1],
      });
    });

    test('test exceptions leave the buckets alone', () async {
      final errors = <Object>[];
      final op = PartitionCollect<int>(
        (n) {
          if (n == 2) throw StateError('collect');
          return n.isEven;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(op.other, [1]);
      expect(op.matched, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('PartitionOnly', () {
    test('keeps the matching side', () async {
      final b = bind(PartitionOnly<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('matched false keeps the other side', () async {
      final b = bind(PartitionOnly<int>((n) => n.isEven, matched: false));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });
  });
}
