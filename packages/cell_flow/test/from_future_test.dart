// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/from_future.dart';
import 'package:test/test.dart';

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

  Future<void> settle([Duration d = const Duration(milliseconds: 30)]) =>
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
  group('FromFuture', () {
    test('emits the future value once after a trigger', () async {
      final b = bind<void>(FromFuture<int>(Future.value(42)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [42]);
    });

    test('ignores a second trigger', () async {
      final completer = Completer<int>();
      final b = bind<void>(FromFuture<int>(completer.future));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      completer.complete(7);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [7]);
    });

    test('.value emits the constant', () async {
      final b = bind<void>(FromFuture.value('ok'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
    });

    test('.error emits type error when emitErrorPulse is true', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFuture<int>.error(StateError('nope')));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.types, contains('error'));
      expect(b.probe.payloads.single, isA<StateError>());
      expect(errors, isEmpty);
    });

    test('timeout produces an error pulse', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFuture<int>(
        Future<int>.delayed(const Duration(milliseconds: 80), () => 1),
        timeout: const Duration(milliseconds: 15),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(errors.whereType<TimeoutException>(), isNotEmpty);
      expect(b.probe.types, contains('error'));
    });
  });

  group('DeferFuture', () {
    test('starts a new future per trigger', () async {
      var calls = 0;
      final b = bind<int>(DeferFuture<int>((pulse) async {
        calls++;
        return (pulse.payload as int) * 2;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(5);
      await b.probe.settle();
      expect(calls, 2);
      expect(b.probe.payloads, [6, 10]);
    });

    test('reports compute errors', () async {
      final errors = <Object>[];
      final b = bind<void>(DeferFuture<int>(
        (_) async => throw FormatException('x'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors.single, isA<FormatException>());
      expect(b.probe.types, contains('error'));
    });
  });

  group('FromFutureOr', () {
    test('emits a synchronous value immediately', () async {
      final b = bind<int>(FromFutureOr<int>((p) => p.payload as int));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(b.probe.payloads, [9]);
    });

    test('awaits a Future value', () async {
      final b = bind<int>(FromFutureOr<int>(
        (p) async => (p.payload as int) + 1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(b.probe.payloads, [10]);
    });

    test('sync throw becomes an error pulse', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFutureOr<int>(
        (_) => throw StateError('sync'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors.single, isA<StateError>());
      expect(b.probe.types, contains('error'));
    });
  });

  group('ConcatFromFuture', () {
    test('emits in trigger order even if later work is faster', () async {
      final b = bind<String>(ConcatFromFuture<String>((p) async {
        final name = p.payload as String;
        await Future<void>.delayed(Duration(
          milliseconds: name == 'slow' ? 50 : 5,
        ));
        return name;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow');
      await b.gate.emitAsync('fast');
      await b.probe.settle(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['slow', 'fast']);
    });
  });

  group('MergeFromFuture', () {
    test('may emit in completion order', () async {
      final b = bind<String>(MergeFromFuture<String>((p) async {
        final name = p.payload as String;
        await Future<void>.delayed(Duration(
          milliseconds: name == 'slow' ? 50 : 5,
        ));
        return name;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow');
      await b.gate.emitAsync('fast');
      await b.probe.settle(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['fast', 'slow']);
    });
  });

  group('SwitchFromFuture', () {
    test('ignores stale in-flight work', () async {
      final b = bind<String>(SwitchFromFuture<String>((p) async {
        final name = p.payload as String;
        await Future<void>.delayed(Duration(
          milliseconds: name == 'old' ? 50 : 10,
        ));
        return name;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['new']);
    });
  });

  group('ExhaustFromFuture', () {
    test('drops triggers while a compute is in flight', () async {
      final b = bind<int>(ExhaustFromFuture<int>((p) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return p.payload as int;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1]);
    });

    test('accepts a new trigger after the previous compute finishes', () async {
      final b = bind<int>(ExhaustFromFuture<int>((p) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return p.payload as int;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('FromFutures', () {
    test('emits each future as it completes', () async {
      final b = bind<void>(FromFutures<String>([
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
        Future<String>.value('fast'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['fast', 'slow']);
    });

    test('starts only once', () async {
      var extra = 0;
      final first = Future<int>.value(1);
      final second = Future<int>(() {
        extra++;
        return 2;
      });
      final b = bind<void>(FromFutures<int>([first, second]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads.toSet(), {1, 2});
      expect(extra, 1);
    });
  });

  group('FromFuturesInOrder', () {
    test('emits in list order, not completion order', () async {
      final b = bind<void>(FromFuturesInOrder<String>([
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
        Future<String>.value('fast'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['slow', 'fast']);
    });
  });

  group('ForkJoinFutures', () {
    test('emits a single list when all succeed', () async {
      final b = bind<void>(ForkJoinFutures<int>([
        Future.value(1),
        Future.value(2),
        Future.value(3),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2, 3]
      ]);
    });

    test('errors if any future fails', () async {
      final errors = <Object>[];
      final b = bind<void>(ForkJoinFutures<int>(
        [
          Future.value(1),
          Future<int>.error(Exception('boom')),
        ],
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors, isNotEmpty);
      expect(b.probe.types, contains('error'));
    });
  });

  group('RaceFutures', () {
    test('emits the first future to complete', () async {
      final b = bind<void>(RaceFutures<String>([
        Future<String>.delayed(const Duration(milliseconds: 50), () => 'slow'),
        Future<String>.delayed(const Duration(milliseconds: 5), () => 'fast'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['fast']);
    });
  });

  group('FromFutureWithRetry', () {
    test('retries until the compute succeeds', () async {
      var calls = 0;
      final b = bind<void>(FromFutureWithRetry<int>(
        (_) async {
          calls++;
          if (calls < 3) throw Exception('transient');
          return 8;
        },
        maxAttempts: 4,
        delay: const Duration(milliseconds: 5),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 60));
      expect(b.probe.payloads, [8]);
      expect(calls, 3);
    });

    test('emits an error pulse after exhausting attempts', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFutureWithRetry<int>(
        (_) async => throw Exception('always'),
        maxAttempts: 2,
        delay: Duration.zero,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads.whereType<int>(), isEmpty);
      expect(errors, hasLength(1));
      expect(b.probe.types, contains('error'));
    });
  });

  group('FromFutureWithTimeout', () {
    test('drops a slow compute and reports TimeoutException', () async {
      final errors = <Object>[];
      final b = bind<int>(FromFutureWithTimeout<int>(
        (p) async {
          await Future<void>.delayed(Duration(
            milliseconds: (p.payload as int) == 1 ? 80 : 5,
          ));
          return p.payload as int;
        },
        timeout: const Duration(milliseconds: 20),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 120));
      expect(b.probe.payloads, contains(2));
      expect(errors.whereType<TimeoutException>(), isNotEmpty);
    });
  });

  group('FromFutureWithFallback', () {
    test('emits fallback when compute throws', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFutureWithFallback<int>(
        (_) async => throw Exception('x'),
        fallback: -1,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [-1]);
      expect(errors, hasLength(1));
      expect(b.probe.types, isNot(contains('error')));
    });

    test('emits the successful value when compute works', () async {
      final b = bind<void>(FromFutureWithFallback<int>(
        (_) async => 4,
        fallback: -1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [4]);
    });
  });

  group('MapToFuture', () {
    test('maps a typed payload through a future', () async {
      final b = bind<int>(MapToFuture<int, String>(
            (id) async => 'user-$id',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(7);
      await b.probe.settle();
      expect(b.probe.payloads, ['user-7']);
    });

    test('drops a mismatched payload and reports onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapToFuture<int, String>(
            (id) async => '$id',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(3);
      await probe.settle();
      expect(probe.payloads, ['3']);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('emitErrorPulse: false', () {

    test('FromFutureWithFallback still emits fallback with emitErrorPulse: false', () async {
      final errors = <Object>[];
      final b = bind<void>(FromFutureWithFallback<int>(
            (_) async => throw Exception('fallback-test'),
        fallback: 99,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [99]);
      expect(errors, hasLength(1));
      expect(b.probe.types, isNot(contains('error')));
    });
  });
}

