// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/retry.dart';
import 'package:test/test.dart' hide Retry;

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
  group('Retry', () {
    test('succeeds after transient failures', () async {
      var n = 0;
      final errors = <Object>[];
      final b = bind(Retry<void, String>(
        (_) {
          n++;
          if (n < 3) throw StateError('try-$n');
          return 'ok';
        },
        count: 5,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
      expect(n, 3);
      expect(errors, hasLength(2));
    });

    test('emits an error pulse when retries are exhausted', () async {
      final errors = <Object>[];
      final b = bind(Retry<void, String>(
        (_) => throw StateError('always'),
        count: 2,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.types, contains('error'));
      expect(b.probe.payloads.single, isA<StateError>());
      expect(errors, hasLength(3));
    });

    test('swallows the error pulse when emitErrorPulse is false', () async {
      final errors = <Object>[];
      final b = bind(Retry<void, String>(
        (_) => throw StateError('hidden'),
        count: 0,
        emitErrorPulse: false,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors, hasLength(1));
    });

    test('wrong types call onError and do not run the task', () async {
      final errors = <Object>[];
      var ran = 0;
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Retry<int, int>(
        (n) {
          ran++;
          return n;
        },
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await probe.settle();
      expect(ran, 0);
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('RetryWhen', () {
    test('retries while shouldRetry is true', () async {
      var n = 0;
      final b = bind(RetryWhen<void, String>(
        (_) {
          n++;
          if (n < 3) throw StateError('again');
          return 'ok';
        },
        shouldRetry: (e, attempt) => e is StateError && attempt < 5,
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
    });

    test('stops when shouldRetry is false', () async {
      final b = bind(RetryWhen<void, String>(
        (_) => throw FormatException('no'),
        shouldRetry: (e, attempt) => e is StateError,
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.types, contains('error'));
      expect(b.probe.payloads.single, isA<FormatException>());
    });

    test('shouldRetry exceptions stop retrying', () async {
      final errors = <Object>[];
      final b = bind(RetryWhen<void, String>(
        (_) => throw StateError('task'),
        shouldRetry: (e, attempt) => throw StateError('policy'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors.whereType<StateError>().map((e) => e.message),
          containsAll(['task', 'policy']));
      expect(b.probe.types, contains('error'));
    });
  });

  group('RetryWithDelay', () {
    test('succeeds after the pause', () async {
      var n = 0;
      final b = bind(RetryWithDelay<void, String>(
        (_) {
          n++;
          if (n < 2) throw StateError('wait');
          return 'late';
        },
        count: 3,
        delay: const Duration(milliseconds: 20),
        emitErrorPulse: false,
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 10));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, ['late']);
    });
  });

  group('RetryWithBackoff', () {
    test('succeeds after backoff', () async {
      var n = 0;
      final b = bind(RetryWithBackoff<void, String>(
        (_) {
          n++;
          if (n < 2) throw StateError('again');
          return 'ok';
        },
        count: 3,
        initial: const Duration(milliseconds: 15),
        emitErrorPulse: false,
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, ['ok']);
      expect(n, 2);
    });

    test('gives up after count retries', () async {
      final errors = <Object>[];
      final b = bind(RetryWithBackoff<void, String>(
        (_) => throw StateError('no'),
        count: 1,
        initial: const Duration(milliseconds: 5),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.types, contains('error'));
      expect(errors, hasLength(2));
    });
  });

  group('RetryUntil', () {
    test('stops when until returns true', () async {
      final errors = <Object>[];
      final b = bind(RetryUntil<void, String>(
        (_) => throw const FormatException('bad'),
        until: (e, _) => e is FormatException,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors, hasLength(1));
      expect(b.probe.types, contains('error'));
    });

    test('retries while until is false then succeeds', () async {
      var n = 0;
      final b = bind(RetryUntil<void, String>(
        (_) {
          n++;
          if (n < 3) throw StateError('again');
          return 'ok';
        },
        until: (e, attempt) => attempt >= 10,
        emitErrorPulse: false,
        onError: (_, __) {},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
    });

    test('until exceptions stop retrying', () async {
      final errors = <Object>[];
      final b = bind(RetryUntil<void, String>(
        (_) => throw StateError('task'),
        until: (e, attempt) => throw StateError('until'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors.whereType<StateError>().map((e) => e.message),
          containsAll(['task', 'until']));
    });
  });
}
