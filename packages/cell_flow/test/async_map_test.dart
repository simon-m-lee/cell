// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/async_map.dart';
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
  group('AsyncMap', () {
    test('maps each value in source order', () async {
      final b = bind(AsyncMap<int, int>((n) async => n * 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 4]);
    });

    test('queues the second map until the first finishes', () async {
      final order = <String>[];
      final b = bind(AsyncMap<int, int>((n) async {
        order.add('start-$n');
        await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 5));
        order.add('end-$n');
        return n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(order, ['start-1']);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(order, ['start-1', 'end-1', 'start-2', 'end-2']);
    });

    test('map exceptions drop that pulse and continue', () async {
      final errors = <Object>[];
      final b = bind(AsyncMap<int, int>(
        (n) {
          if (n == 2) throw StateError('map');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = AsyncMap<int, int>(
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('AsyncMapSequential', () {
    test('is an alias of AsyncMap', () async {
      final b = bind(AsyncMapSequential<int, int>((n) => n + 1));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });
  });

  group('AsyncMapConcurrent', () {
    test('emits in completion order', () async {
      final b = bind(AsyncMapConcurrent<String, String>((name) async {
        await Future<void>.delayed(
          Duration(milliseconds: name == 'slow' ? 40 : 5),
        );
        return name;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow');
      await b.gate.emitAsync('fast');
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['fast', 'slow']);
    });

    test('inner errors call onError', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(AsyncMapConcurrent<void, int>(
        (_) => pending.future,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await Future<void>.delayed(Duration.zero);
      pending.completeError(StateError('inner'));
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('AsyncMapLatest', () {
    test('drops a stale projection', () async {
      final b = bind(AsyncMapLatest<String, String>((q) async {
        await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 8));
        return q;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['new']);
    });

    test('stale errors are not reported', () async {
      final errors = <Object>[];
      final stale = Completer<String>();
      final b = bind(AsyncMapLatest<String, String>(
        (q) => q == 'old' ? stale.future : 'new',
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await Future<void>.delayed(Duration.zero);
      stale.completeError(StateError('stale'));
      await b.probe.settle();
      expect(b.probe.payloads, ['new']);
      expect(errors, isEmpty);
    });
  });

  group('AsyncMapWithIndex', () {
    test('passes a 0-based index that skips failures', () async {
      final errors = <Object>[];
      final b = bind(AsyncMapWithIndex<int, String>(
        (n, i) {
          if (n == 2) throw StateError('idx');
          return '$i:$n';
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, ['0:1', '1:3']);
      expect(errors.single, isA<StateError>());
    });
  });

  group('AsyncMapWithRetry', () {
    test('succeeds after transient failures', () async {
      var n = 0;
      final errors = <Object>[];
      final b = bind(AsyncMapWithRetry<void, String>(
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
      expect(errors, hasLength(2));
    });

    test('gives up after count retries', () async {
      final errors = <Object>[];
      final b = bind(AsyncMapWithRetry<void, String>(
        (_) => throw StateError('always'),
        count: 1,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors, hasLength(2));
    });
  });

  group('AsyncMapWithTimeout', () {
    test('emits when the map finishes in time', () async {
      final b = bind(AsyncMapWithTimeout<int, int>(
        (n) async => n,
        duration: const Duration(milliseconds: 50),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('timeout calls onError and drops the value', () async {
      final errors = <Object>[];
      final b = bind(AsyncMapWithTimeout<void, String>(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return 'late';
        },
        duration: const Duration(milliseconds: 15),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<TimeoutException>());
    });
  });

  group('AsyncMapWithFallback', () {
    test('emits fallback when the map throws', () async {
      final errors = <Object>[];
      final b = bind(AsyncMapWithFallback<int, String>(
        (n) => throw StateError('nope'),
        fallback: 'n/a',
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, ['n/a']);
      expect(errors.single, isA<StateError>());
    });
  });

  group('edges', () {
    test('does not flatten a list result', () async {
      final b = bind(AsyncMap<int, List<int>>((n) => [n, n]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 1],
      ]);
    });

    test('sync mapper still emits through the future path', () async {
      final b = bind(AsyncMap<int, int>((n) => n + 1));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });
  });

  group('performance', () {
    test('AsyncMap handles 200 items', () async {
      final sw = Stopwatch()..start();
      final b = bind(AsyncMap<int, int>((n) => n));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(200));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('AsyncMapConcurrent overlaps 50 delayed maps', () async {
      final sw = Stopwatch()..start();
      final b = bind(AsyncMapConcurrent<int, int>((n) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return n;
      }));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 50; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle(const Duration(milliseconds: 120));
      sw.stop();
      expect(b.probe.payloads, hasLength(50));
      expect(sw.elapsedMilliseconds, lessThan(800));
    });
  });
}
