// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/timeout.dart';
import 'package:test/test.dart' hide Timeout;

class _Probe {
  final List<Object?> payloads = [];
  final List<String?> types = [];
  final List<String> steps = [];
  late final dynamic _obs;

  _Probe(Cell source) {
    _obs = Cell.observe(
      source: source,
      effect: (Pulse p) {
        payloads.add(p.payload);
        types.add(p.type);
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
  group('Timeout', () {
    test('forwards values and errors after idle', () async {
      final errors = <Object>[];
      final b = bind(Timeout<int>(
        const Duration(milliseconds: 40),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, [1]);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.types, contains('error'));
      expect(b.probe.payloads.last, isA<TimeoutException>());
      expect(errors.single, isA<TimeoutException>());
    });

    test('a later pulse resets the idle timer', () async {
      final b = bind(Timeout<int>(
        const Duration(milliseconds: 40),
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 25));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 25));
      expect(b.probe.types, isNot(contains('error')));
      expect(b.probe.payloads, [1, 2]);
    });

    test('emitErrorPulse false only calls onError', () async {
      final errors = <Object>[];
      final b = bind(Timeout<int>(
        const Duration(milliseconds: 25),
        emitErrorPulse: false,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.types, isNot(contains('error')));
      expect(errors.single, isA<TimeoutException>());
    });

    test('wrong types call onError and do not start the clock', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Timeout<int>(
        const Duration(milliseconds: 20),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await probe.settle(const Duration(milliseconds: 40));
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('TimeoutWithError', () {
    test('emits the custom error payload', () async {
      final b = bind(TimeoutWithError<int>(
        const Duration(milliseconds: 25),
        error: StateError('late'),
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads.last, isA<StateError>());
      expect((b.probe.payloads.last as StateError).message, 'late');
    });

    test('errorOf exceptions call onError and skip the pulse', () async {
      final errors = <Object>[];
      final b = bind(TimeoutWithError<int>(
        const Duration(milliseconds: 25),
        errorOf: () => throw FormatException('build'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.types, isNot(contains('error')));
      expect(errors.single, isA<FormatException>());
    });
  });

  group('TimeoutWithFallback', () {
    test('emits the fallback after idle', () async {
      final b = bind(TimeoutWithFallback<int>(
        const Duration(milliseconds: 30),
        fallback: -1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, [1, -1]);
    });

    test('once true emits fallback only one time', () async {
      final b = bind(TimeoutWithFallback<int>(
        const Duration(milliseconds: 20),
        fallback: -1,
        once: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads.where((e) => e == -1), hasLength(1));
    });
  });

  group('TimeoutFirst', () {
    test('does not reset the deadline on later pulses', () async {
      final b = bind(TimeoutFirst<int>(
        const Duration(milliseconds: 45),
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 20));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads.take(2).toList(), [1, 2]);
      expect(b.probe.types, contains('error'));
    });
  });

  group('TimeoutLast', () {
    test('is an idle timeout alias', () async {
      final b = bind(TimeoutLast<int>(
        const Duration(milliseconds: 30),
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.types, contains('error'));
    });
  });
}
