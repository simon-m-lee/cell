// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/interval.dart';
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
  group('Interval', () {
    test('emits 0, 1, 2 after the first period, then stops', () async {
      final b = bind(Interval(
        const Duration(milliseconds: 25),
        maxTicks: 3,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 10));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 100));
      expect(b.probe.payloads, [0, 1, 2]);
      expect(b.probe.steps, contains('Interval'));
    });

    test('a second source pulse does not restart by default', () async {
      final b = bind(Interval(
        const Duration(milliseconds: 20),
        maxTicks: 2,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 30));
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, [0, 1]);
    });

    test('resetOnSource restarts the counter', () async {
      final b = bind(Interval(
        const Duration(milliseconds: 25),
        maxTicks: 1,
        resetOnSource: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [0]);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [0, 0]);
    });

    test('maxTicks 0 emits nothing', () async {
      final b = bind(Interval(
        const Duration(milliseconds: 10),
        maxTicks: 0,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('IntervalWithValue', () {
    test('emits a constant value', () async {
      final b = bind(IntervalWithValue<String>(
        const Duration(milliseconds: 20),
        value: 'tick',
        maxTicks: 2,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['tick', 'tick']);
    });

    test('maps the tick index', () async {
      final b = bind(IntervalWithValue<String>(
        const Duration(milliseconds: 20),
        valueOf: (tick) => 'tick-$tick',
        maxTicks: 2,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['tick-0', 'tick-1']);
    });

    test('valueOf exceptions call onError and stop the clock', () async {
      final errors = <Object>[];
      var calls = 0;
      final b = bind(IntervalWithValue<int>(
        const Duration(milliseconds: 20),
        valueOf: (tick) {
          calls++;
          if (tick == 1) throw StateError('tick-1');
          return tick;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [0]);
      expect(errors.single, isA<StateError>());
      expect(calls, 2);
    });
  });

  group('IntervalWithState', () {
    test('threads state across ticks', () async {
      final b = bind(IntervalWithState<int>(
        const Duration(milliseconds: 20),
        1,
        (state, tick) => tick == 0 ? state : state * 2,
        maxTicks: 3,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 90));
      expect(b.probe.payloads, [1, 2, 4]);
    });

    test('next exceptions call onError and stop the clock', () async {
      final errors = <Object>[];
      final b = bind(IntervalWithState<int>(
        const Duration(milliseconds: 20),
        0,
        (state, tick) {
          if (tick == 1) throw StateError('next');
          return state + 1;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TimerPulse', () {
    test('emits once after the delay', () async {
      final b = bind(TimerPulse<String>(
        const Duration(milliseconds: 25),
        value: 'go',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 10));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, ['go']);
    });

    test('a second source pulse does not fire again', () async {
      final b = bind(TimerPulse<int>(
        const Duration(milliseconds: 15),
        value: 1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1]);
    });

    test('valueOf exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(TimerPulse<int>(
        const Duration(milliseconds: 15),
        valueOf: () => throw StateError('timer'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });
}
