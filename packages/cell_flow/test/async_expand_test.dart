// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/async_expand.dart';
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
  group('AsyncExpand', () {
    test('flattens inners in source order', () async {
      final b = bind(AsyncExpand<String, String>((s) => ['$s-1', '$s-2']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, ['a-1', 'a-2', 'b-1', 'b-2']);
    });

    test('queues a second inner until the first finishes', () async {
      final order = <String>[];
      final b = bind(AsyncExpand<String, String>((s) async {
        order.add('start-$s');
        await Future<void>.delayed(Duration(milliseconds: s == 'a' ? 40 : 5));
        order.add('end-$s');
        return s;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(order, ['start-a']);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(order, ['start-a', 'end-a', 'start-b', 'end-b']);
      expect(b.probe.payloads, ['a', 'b']);
    });

    test('null inner is a no-op', () async {
      final b = bind(AsyncExpand<int, int>((n) => n == 1 ? null : n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('expand exceptions call onError and keep the queue moving', () async {
      final errors = <Object>[];
      final b = bind(AsyncExpand<int, int>(
        (n) {
          if (n == 2) throw StateError('expand');
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

    test('wrong types call onError and do not enqueue', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = AsyncExpand<int, int>(
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

  group('AsyncExpandConcurrent', () {
    test('emits in completion order', () async {
      final b = bind(AsyncExpandConcurrent<String, String>((name) async {
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

    test('inner future errors call onError', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(AsyncExpandConcurrent<void, int>(
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

  group('AsyncExpandLatest', () {
    test('drops a stale inner', () async {
      final b = bind(AsyncExpandLatest<String, String>((q) async {
        await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 8));
        return '$q-1';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['new-1']);
    });

    test('stale inner errors are not reported', () async {
      final errors = <Object>[];
      final stale = Completer<int>();
      final b = bind(AsyncExpandLatest<String, int>(
        (q) => q == 'old' ? stale.future : Future.value(2),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await Future<void>.delayed(Duration.zero);
      stale.completeError(StateError('stale'));
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors, isEmpty);
    });
  });

  group('AsyncExpandExhaust', () {
    test('ignores a trigger while busy', () async {
      final b = bind(AsyncExpandExhaust<String, String>((s) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return s;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('first');
      await b.gate.emitAsync('ignored');
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['first']);
    });

    test('accepts a trigger after the inner completes', () async {
      final b = bind(AsyncExpandExhaust<int, int>((n) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 40));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('edges', () {
    test('empty iterable emits nothing', () async {
      final b = bind(AsyncExpand<int, int>((n) => <int>[]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('string is not flattened as an iterable', () async {
      final b = bind(AsyncExpand<String, String>((s) => s));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('hi');
      await b.probe.settle();
      expect(b.probe.payloads, ['hi']);
    });

    test('nested list is flattened recursively', () async {
      final b = bind(AsyncExpand<int, int>((n) => [
            [n],
            n + 1,
          ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('stream events are flattened', () async {
      final b = bind(AsyncExpand<int, int>((n) => Stream.fromIterable([n, n + 1])));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [3, 4]);
    });
  });

  group('performance', () {
    test('AsyncExpand handles a burst of 200 items', () async {
      final sw = Stopwatch()..start();
      final b = bind(AsyncExpand<int, int>((n) => n));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, List<int>.generate(200, (i) => i));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('AsyncExpandConcurrent overlaps 50 delayed inners', () async {
      final sw = Stopwatch()..start();
      final b = bind(AsyncExpandConcurrent<int, int>((n) async {
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
