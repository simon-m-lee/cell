// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/sample.dart';
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
  group('Sample', () {
    test('emits the latest pending value on notifier', () async {
      final tick = Cell.ingress<void>();
      final b = bind(Sample<int>(tick.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await tick.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('a notifier with nothing pending is ignored', () async {
      final tick = Cell.ingress<void>();
      final b = bind(Sample<int>(tick.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await tick.emitAsync(null);
      await tick.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('wrong types do not become pending', () async {
      final errors = <Object>[];
      final tick = Cell.ingress<void>();
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Sample<int>(
        tick.cell,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await tick.emitAsync(null);
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('SampleTime', () {
    test('emits the latest value on the period', () async {
      final b = bind(SampleTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [2]);
    });

    test('skips empty periods', () async {
      final b = bind(SampleTime<int>(const Duration(milliseconds: 25)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 40));
      final n = b.probe.payloads.length;
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads.length, n);
    });
  });

  group('Audit', () {
    test('emits after the next notifier', () async {
      final gate = Cell.ingress<void>();
      final b = bind(Audit<int>(gate.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      await gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('notifier without a pending source is ignored', () async {
      final n = Cell.ingress<void>();
      final b = bind(Audit<int>(n.cell));
      addTearDown(b.probe.stop);
      await n.emitAsync(null);
      await b.gate.emitAsync(1);
      await n.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });
  });

  group('AuditTime', () {
    test('emits the latest value after the quiet window', () async {
      final b = bind(AuditTime<int>(const Duration(milliseconds: 30)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 15));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [2]);
    });
  });

  group('edges', () {
    test('Sample does not emit before the first source value', () async {
      final tick = Cell.ingress<void>();
      final b = bind(Sample<int>(tick.cell));
      addTearDown(b.probe.stop);
      await tick.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('performance', () {
    test('SampleTime handles a burst of 100 values', () async {
      final sw = Stopwatch()..start();
      final b = bind(SampleTime<int>(const Duration(milliseconds: 20)));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 100; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle(const Duration(milliseconds: 40));
      sw.stop();
      expect(b.probe.payloads, isNotEmpty);
      expect(b.probe.payloads.last, 99);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
