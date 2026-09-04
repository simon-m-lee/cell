// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/scan.dart';
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
  group('Scan', () {
    test('uses the first value as seed and starts emitting on the second',
        () async {
      final b = bind(Scan<int, int>((acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [3, 6]);
    });

    test('a single value produces no emission', () async {
      final b = bind(Scan<int, int>((acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('accumulate exceptions call onError and keep the previous acc',
        () async {
      final errors = <Object>[];
      final b = bind(Scan<int, int>(
        (acc, n) {
          if (n == 3) throw StateError('boom');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      expect(b.probe.payloads, [3, 7]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types do not become the seed', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Scan<int, int>(
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [3]);
      expect(errors.single, isA<FormatException>());
    });

    test('marks lineage with Scan', () async {
      final b = bind(Scan<int, int>((acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.steps, contains('Scan'));
    });
  });

  group('ScanSeeded', () {
    test('emits from the first value using the seed', () async {
      final b = bind(ScanSeeded<int, int>(0, (acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3, 6]);
    });

    test('can accumulate into a different type than the source', () async {
      final b = bind(ScanSeeded<int, List<int>>(
        <int>[],
        (acc, n) => [...acc, n],
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1],
        [1, 2],
      ]);
    });
  });

  group('ScanIndexed', () {
    test('passes a zero-based index', () async {
      final seen = <int>[];
      final b = bind(ScanIndexed<String, String>(
        '',
        (acc, value, index) {
          seen.add(index);
          return '$acc$value$index';
        },
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(seen, [0, 1]);
      expect(b.probe.payloads, ['a0', 'a0b1']);
    });

    test('wrong types do not advance the index', () async {
      final seen = <int>[];
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ScanIndexed<int, int>(
        0,
        (acc, value, index) {
          seen.add(index);
          return acc + value;
        },
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(5);
      await probe.settle();
      expect(seen, [0]);
      expect(probe.payloads, [5]);
      expect(errors.single, isA<FormatException>());
    });
  });
}
