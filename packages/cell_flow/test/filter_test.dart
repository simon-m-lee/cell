// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:test/test.dart';

/// Collects payloads (and optional trace steps) from a downstream cell.
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

/// Bind [op] to an ingress gateway and attach a downstream probe.
///
/// Inputs must go through [FlowHandle.emitAsync] / [IngressHandle.emitAsync],
/// never through [Cell] — `Cell` has no `emit` / `emitAsync`.
({IngressHandle<T> gate, FlowHandle<T> out, _Probe probe}) bind<T>(
  FlowInstructionBase<Cell, Pulse, Pulse> op,
) {
  final gate = Cell.ingress<T>();
  final out = op.toHandle(source: gate.cell);
  final probe = _Probe(out.cell);
  return (gate: gate, out: out, probe: probe);
}

void main() {
  group('Filter', () {
    test('keeps values that satisfy the predicate, in order', () async {
      final b = bind(Filter<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4, 5]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [2, 4]);
    });

    test('drops wrong payload types and reports onError', () async {
      final errors = <Object>[];
      final b = bind<Object>(
        Filter<int>((n) => true, onError: (e, _) => errors.add(e)),
      );
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync('nope');
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors, hasLength(1));
      expect(errors.single, isA<FormatException>());
    });

    test('predicate exceptions are swallowed and reported', () async {
      final errors = <Object>[];
      final b = bind(
        Filter<int>((n) {
          if (n == 2) throw StateError('boom');
          return true;
        }, onError: (e, _) => errors.add(e)),
      );
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('marks lineage with Filter', () async {
      final b = bind(Filter<int>((n) => true));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(7);
      await b.probe.settle();
      expect(b.probe.steps, contains('Filter'));
    });
  });

  group('FilterNotNull', () {
    test('drops null and keeps typed values', () async {
      final b = bind(FilterNotNull<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync('hello');
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['hello']);
    });

    test('rejects non-S non-null payloads', () async {
      final errors = <Object>[];
      final b = bind<Object?>(
        FilterNotNull<String>(onError: (e, _) => errors.add(e)),
      );
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(42);
      await b.gate.emitAsync('ok');
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
      expect(errors, isNotEmpty);
    });
  });

  group('Distinct', () {
    test('suppresses only consecutive duplicates', () async {
      final b = bind(Distinct<int>());
      addTearDown(b.probe.stop);
      for (final n in [1, 1, 2, 2, 1, 3, 3]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 1, 3]);
    });

    test('uses a custom comparator', () async {
      final b = bind(Distinct<String>(
        comparator: (a, b) => a.toLowerCase() == b.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('Alice');
      await b.gate.emitAsync('alice');
      await b.gate.emitAsync('Bob');
      await b.probe.settle();
      expect(b.probe.payloads, ['Alice', 'Bob']);
    });

    test('first value always passes', () async {
      final b = bind(Distinct<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(0);
      await b.probe.settle();
      expect(b.probe.payloads, [0]);
    });
  });

  group('DistinctAll', () {
    test('drops any previously seen value', () async {
      final b = bind(DistinctAll<int>());
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 1, 3, 2, 1]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('keys values through keyOf', () async {
      final b = bind(DistinctAll<String>(
        keyOf: (s) => s.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('A');
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('B');
      await b.probe.settle();
      expect(b.probe.payloads, ['A', 'B']);
    });
  });

  group('FilterType', () {
    test('narrows heterogeneous streams', () async {
      final IngressHandle<Object> ingress = Cell.ingress<Object>();
      final out = FilterType<Object, String>().toHandle(source: ingress.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await ingress.emitAsync(42);
      await ingress.emitAsync('hello');
      await ingress.emitAsync(true);
      await probe.settle();
      expect(probe.payloads, ['hello']);
    });
  });

  group('FilterAllowed / FilterBlocked', () {
    test('whitelist keeps only listed values', () async {
      final b = bind(FilterAllowed<int>(allowed: {200, 201, 204}));
      addTearDown(b.probe.stop);
      for (final n in [200, 404, 201, 500, 204]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [200, 201, 204]);
    });

    test('blacklist drops listed values', () async {
      final b = bind(FilterBlocked<int>(blocked: {404, 500}));
      addTearDown(b.probe.stop);
      for (final n in [200, 404, 201, 500]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [200, 201]);
    });
  });

/*
  group('Take / Skip', () {
    test('Take emits only the first N values then stays closed', () async {
      final b = bind(Take<int>(3));
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 6; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('Take(0) emits nothing', () async {
      final b = bind(Take<int>(0));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('Skip drops the first N values', () async {
      final b = bind(Skip<int>(2));
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 5; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [3, 4, 5]);
    });

    test('Skip(0) is a pass-through', () async {
      final b = bind(Skip<int>(0));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(b.probe.payloads, [9]);
    });
  });
*/

  group('TakeWhile / SkipWhile', () {
    test('TakeWhile closes after the first failing predicate', () async {
      final b = bind(TakeWhile<int>((n) => n < 5));
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 7; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3, 4]);
    });

    test('TakeWhile stays closed after a predicate throw', () async {
      final errors = <Object>[];
      final b = bind(TakeWhile<int>(
        (n) {
          if (n == 3) throw FormatException('x');
          return true;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 5; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
      expect(errors, hasLength(1));
    });

    test('SkipWhile opens after the first failing predicate', () async {
      final b = bind(SkipWhile<int>((n) => n < 5));
      addTearDown(b.probe.stop);
      for (var i = 1; i <= 7; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [5, 6, 7]);
    });

    test('SkipWhile opens on predicate throw and keeps later values', () async {
      final errors = <Object>[];
      final b = bind(SkipWhile<int>(
        (n) {
          if (n == 2) throw StateError('open');
          return true;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 3]);
      expect(errors, hasLength(1));
    });
  });

  group('Debounce', () {
    test('emits only the last value after silence', () async {
      final b = bind(Debounce<String>(const Duration(milliseconds: 80)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('h');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await b.gate.emitAsync('he');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await b.gate.emitAsync('hello');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads, ['hello']);
    });

    test('separate bursts each emit', () async {
      final b = bind(Debounce<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('DebounceLeading', () {
    test('emits first immediately then last after silence', () async {
      final b = bind(DebounceLeading<int>(const Duration(milliseconds: 80)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads.first, 1);
      expect(b.probe.payloads.last, 3);
      expect(b.probe.payloads, [1, 3]);
    });
  });

  group('Throttle', () {
    test('leading+trailing emits first and last of a burst', () async {
      final b = bind(Throttle<int>(
        const Duration(milliseconds: 100),
        leading: true,
        trailing: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(b.probe.payloads.first, 1);
      expect(b.probe.payloads.last, 3);
      expect(b.probe.payloads, containsAllInOrder([1, 3]));
    });

    test('leading-only ignores the rest of the window', () async {
      final b = bind(Throttle<int>(
        const Duration(milliseconds: 80),
        leading: true,
        trailing: false,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads, [1]);
    });

    test('trailing-only emits the last value when the window closes', () async {
      final b = bind(Throttle<int>(
        const Duration(milliseconds: 80),
        leading: false,
        trailing: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads, [2]);
    });
  });

  group('FilterByTime', () {
    test('first value is immediate; early follow-ups wait', () async {
      final b = bind(FilterByTime<int>(const Duration(milliseconds: 80)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [1]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1, 2]);
    });

    test('Duration.zero is a pass-through', () async {
      final b = bind(FilterByTime<int>(Duration.zero));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('AsyncFilter', () {
    test('keeps values whose predicate resolves true, in input order', () async {
      final b = bind(AsyncFilter<String>((name) async {
        await Future<void>.delayed(Duration(
          milliseconds: name == 'slow-ok' ? 40 : 5,
        ));
        return name != 'taken';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow-ok');
      await b.gate.emitAsync('taken');
      await b.gate.emitAsync('jane');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads, ['slow-ok', 'jane']);
    });

    test('predicate errors drop the pulse and call onError', () async {
      final errors = <Object>[];
      final b = bind(AsyncFilter<int>(
        (n) async {
          if (n == 2) throw Exception('nope');
          return true;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 3]);
      expect(errors, hasLength(1));
    });
  });

  group('AsyncFilterConcurrent', () {
    test('may emit in completion order rather than input order', () async {
      final b = bind(AsyncFilterConcurrent<String>((name) async {
        await Future<void>.delayed(Duration(
          milliseconds: name == 'slow' ? 60 : 5,
        ));
        return true;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('slow');
      await b.gate.emitAsync('fast');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['fast', 'slow']);
    });
  });

  group('AsyncFilterLatest', () {
    test('ignores stale in-flight results', () async {
      final b = bind(AsyncFilterLatest<String>((name) async {
        await Future<void>.delayed(Duration(
          milliseconds: name == 'old' ? 60 : 10,
        ));
        return true;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['new']);
    });
  });

  group('AsyncFilterWithRetry', () {
    test('retries until the predicate succeeds', () async {
      var calls = 0;
      final b = bind(AsyncFilterWithRetry<int>(
        (n) async {
          calls++;
          if (calls < 3) throw Exception('transient');
          return true;
        },
        maxAttempts: 4,
        delay: const Duration(milliseconds: 5),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1]);
      expect(calls, 3);
    });

    test('reports onError after exhausting attempts', () async {
      final errors = <Object>[];
      final b = bind(AsyncFilterWithRetry<int>(
        (n) async => throw Exception('always'),
        maxAttempts: 2,
        delay: Duration.zero,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(b.probe.payloads, isEmpty);
      expect(errors, hasLength(1));
    });
  });

  group('AsyncFilterWithTimeout', () {
    test('drops pulses that exceed the timeout', () async {
      final errors = <Object>[];
      final b = bind(AsyncFilterWithTimeout<int>(
        (n) async {
          await Future<void>.delayed(Duration(milliseconds: n == 1 ? 80 : 5));
          return true;
        },
        timeout: const Duration(milliseconds: 25),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.probe.payloads, [2]);
      expect(errors.whereType<TimeoutException>(), isNotEmpty);
    });
  });

  group('AsyncFilterWithFallback', () {
    test('default fallback drops on error', () async {
      final errors = <Object>[];
      final b = bind(AsyncFilterWithFallback<int>(
        (n) async => throw Exception('x'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.probe.payloads, isEmpty);
      expect(errors, hasLength(1));
    });

    test('fallback: true keeps the pulse after an error', () async {
      final b = bind(AsyncFilterWithFallback<int>(
        (n) async => throw Exception('x'),
        fallback: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [9]);
    });

    test('successful true still passes', () async {
      final b = bind(AsyncFilterWithFallback<int>(
        (n) async => n > 0,
        fallback: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(-1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [1]);
    });
  });

  group('composition', () {
    test('Filter + Distinct can be chained with +', () async {
      // + is left-to-right: Filter runs first, then Distinct.
      // Input:        -1, 1, 1, 2, 0, 2
      // After Filter:     1, 1, 2,    2
      // After Distinct:   1,    2
      final op = Filter<int>((n) => n > 0) + Distinct<int>();
      final IngressHandle<int> ingress = Cell.ingress<int>();
      final out = op.toHandle(source: ingress.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      for (final n in [-1, 1, 1, 2, 0, 2]) {
        await ingress.emitAsync(n);
      }
      await probe.settle();
      expect(probe.payloads, [1, 2]);
    });

    test('Distinct + Filter keeps a later 2 because 0 broke consecutiveness', () async {
      // Distinct first: -1, 1, 2, 0, 2
      // Filter > 0:         1, 2,    2
      final op = Distinct<int>() + Filter<int>((n) => n > 0);
      final IngressHandle<int> ingress = Cell.ingress<int>();
      final out = op.toHandle(source: ingress.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      for (final n in [-1, 1, 1, 2, 0, 2]) {
        await ingress.emitAsync(n);
      }
      await probe.settle();
      expect(probe.payloads, [1, 2, 2]);
    });
  });

  group('type mismatches', () {
    test('time operators report onError for wrong types', () async {
      final errors = <Object>[];
      final IngressHandle<Object> ingress = Cell.ingress<Object>();
      final out = Debounce<int>(
        const Duration(milliseconds: 10),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: ingress.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await ingress.emitAsync('bad');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });
}
