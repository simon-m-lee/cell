// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/delay.dart';
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
  group('Delay', () {
    test('emits after the duration', () async {
      final b = bind(Delay<int>(const Duration(milliseconds: 30)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 10));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1]);
    });

    test('does not drop earlier values', () async {
      final b = bind(Delay<int>(const Duration(milliseconds: 20)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types call onError and do not schedule', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Delay<int>(
        const Duration(milliseconds: 10),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle(const Duration(milliseconds: 30));
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('DelayWithSelector', () {
    test('uses a per-value duration', () async {
      final b = bind(DelayWithSelector<String>(
        (s) => Duration(milliseconds: s == 'slow' ? 40 : 5),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow');
      await b.gate.emitAsync('fast');
      await b.probe.settle(const Duration(milliseconds: 15));
      expect(b.probe.payloads, ['fast']);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, ['fast', 'slow']);
    });

    test('selector exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(DelayWithSelector<int>(
        (n) => throw StateError('sel'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('DelayWhen', () {
    test('waits for the notifier future', () async {
      final gate = Completer<void>();
      final b = bind(DelayWhen<String>((_) => gate.future));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('go');
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      gate.complete();
      await b.probe.settle();
      expect(b.probe.payloads, ['go']);
    });

    test('notifier errors call onError', () async {
      final errors = <Object>[];
      final pending = Completer<void>();
      final b = bind(DelayWhen<int>(
        (_) => pending.future,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(Duration.zero);
      pending.completeError(StateError('when'));
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('DelayLatest', () {
    test('cancels a pending pulse', () async {
      final b = bind(DelayLatest<String>(const Duration(milliseconds: 30)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('first');
      await b.gate.emitAsync('last');
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, ['last']);
    });
  });

  group('DelayWithTrailing', () {
    test('is an alias of DelayLatest', () async {
      final b = bind(DelayWithTrailing<int>(const Duration(milliseconds: 20)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [2]);
    });
  });

  group('DelayWithTimeout', () {
    test('emits when duration is within timeout', () async {
      final b = bind(DelayWithTimeout<String>(
        const Duration(milliseconds: 10),
        timeout: const Duration(milliseconds: 50),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('ok');
      await b.probe.settle(const Duration(milliseconds: 30));
      expect(b.probe.payloads, ['ok']);
    });

    test('duration longer than timeout calls onError', () async {
      final errors = <Object>[];
      final b = bind(DelayWithTimeout<int>(
        const Duration(milliseconds: 80),
        timeout: const Duration(milliseconds: 10),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<TimeoutException>());
    });
  });

  group('edges', () {
    test('zero duration emits on the next microtask-ish tick', () async {
      final b = bind(Delay<int>(Duration.zero));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('DelayWhen accepts a Duration notifier', () async {
      final b = bind(DelayWhen<int>((_) => const Duration(milliseconds: 15)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 5));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 25));
      expect(b.probe.payloads, [1]);
    });
  });

  group('performance', () {
    test('Delay schedules 100 pulses', () async {
      final sw = Stopwatch()..start();
      final b = bind(Delay<int>(const Duration(milliseconds: 5)));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 100; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle(const Duration(milliseconds: 40));
      sw.stop();
      expect(b.probe.payloads, hasLength(100));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
