// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/throttle.dart';
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
  group('Throttle', () {
    test('emits leading immediately and trailing at window close', () async {
      final b = bind(Throttle<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1, 3]);
      expect(
        b.probe.steps,
        containsAll(['Throttle.leading', 'Throttle.trailing']),
      );
    });

    test('a lone pulse emits only the leading value', () async {
      final b = bind(Throttle<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [9]);
    });

    test('a new window opens after the duration', () async {
      final b = bind(Throttle<int>(
        const Duration(milliseconds: 40),
        trailing: false,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types call onError and do not open a window', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Throttle<int>(
        const Duration(milliseconds: 20),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ThrottleLeading', () {
    test('emits only the first value of a burst', () async {
      final b = bind(ThrottleLeading<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1]);
    });
  });

  group('ThrottleTrailing', () {
    test('emits only the last value when the window closes', () async {
      final b = bind(ThrottleTrailing<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [3]);
    });

    test('a lone pulse still emits as trailing', () async {
      final b = bind(ThrottleTrailing<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(4);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [4]);
    });
  });
}
