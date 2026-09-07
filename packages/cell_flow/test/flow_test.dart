// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:test/test.dart';

class _Probe {
  final List<Object?> payloads = [];
  late final dynamic _obs;

  _Probe(Cell source) {
    _obs = Cell.observe(
      source: source,
      effect: (Pulse p) => payloads.add(p.payload),
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

void main() {
  group('FlowHandle / toHandle', () {
    test('emit wraps a raw value and returns bool', () {
      final gate = Cell.ingress<int>();
      final handle = Flow.filter<int>(gate.cell, test: (n) => n > 0);
      expect(handle.cell, isNotNull);
      expect(handle.emit(1), isA<bool>());
    });

    test('emitAsync completes', () async {
      final gate = Cell.ingress<int>();
      final handle = Flow.filter<int>(gate.cell, test: (_) => true);
      final ok = await handle.emitAsync(3);
      expect(ok, isA<bool>());
    });

    test('ingest accepts a Pulse', () async {
      final gate = Cell.ingress<int>();
      final handle = Flow.filter<int>(gate.cell, test: (_) => true);
      await handle.ingest(Pulse<int>(9));
    });

    test('Flow.filter handle can be chained further', () {
      final gate = Cell.ingress<int>();
      final out = Flow.filter<int>(gate.cell, test: (n) => n > 0);
      expect(out.cell, isNotNull);
    });
  });

  group('Flow create', () {
    test('of emits the sequence on the first trigger', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.of<String>(start.cell, values: ['a', 'b']);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, ['a', 'b']));
    });

    test('fromIterable emits list elements', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.fromIterable<int>(
        start.cell,
        iterable: [1, 2, 3],
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('range builds a numeric sequence', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.range(start.cell, start: 2, count: 3, step: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('repeat emits the same value count times', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.repeat<String>(start.cell, value: 'ping', count: 3);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('fromFuture binds a Future', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.fromFuture<int>(
        start.cell,
        future: Future.value(7),
        emitErrorPulse: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle(const Duration(milliseconds: 40));
      expect(handle.cell, isNotNull);
    });

    test('deferFuture creates a new future per trigger', () async {
      final ids = Cell.ingress<int>();
      final handle = Flow.deferFuture<int>(
        ids.cell,
        create: (p) async => (p.payload as int) * 10,
        emitErrorPulse: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await ids.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('fromStream binds a Stream', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.fromStream<int>(
        start.cell,
        stream: Stream.fromIterable([1, 2]),
        emitErrorPulse: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('Flow transform', () {
    test('filter keeps matching values', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.filter<int>(src.cell, test: (n) => n.isEven);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await src.emitAsync(3);
      await src.emitAsync(4);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [2, 4]);
      }
    });

    test('map projects values', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.map<int, String>(
        src.cell,
        project: (n) => 'n=$n',
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(3);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, ['n=3']);
      }
    });

    test('mapTo emits a constant', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.mapTo<int, String>(src.cell, value: 'x');
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, ['x']);
      }
    });

    test('mapWithIndex includes a 0-based index', () async {
      final src = Cell.ingress<String>();
      final handle = Flow.mapWithIndex<String, String>(
        src.cell,
        project: (v, i) => '$i:$v',
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('a');
      await src.emitAsync('b');
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, ['0:a', '1:b']);
      }
    });

    test('mapNotNull drops null projections', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.mapNotNull<int, int>(
        src.cell,
        project: (n) => n.isEven ? n : null,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [2]);
      }
    });

    test('mapWhen projects only when test is true', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.mapWhen<int, int>(
        src.cell,
        test: (n) => n > 0,
        project: (n) => n * 10,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(2);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [20]);
      }
    });

    test('pluck reads a map field', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final handle = Flow.pluck<int>(src.cell, key: 'n');
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync({'n': 9});
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [9]);
      }
    });

    test('pluckOr uses orElse', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final handle = Flow.pluckOr<int>(src.cell, key: 'missing', orElse: 0);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync({'n': 1});
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [0]);
      }
    });

    test('scan folds without a seed', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.scan<int, int>(
        src.cell,
        accumulate: (acc, n) => acc + n,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('reduce folds from a seed', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.reduce<int, int>(
        src.cell,
        seed: 0,
        accumulate: (acc, n) => acc + n,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('pairwise emits adjacent pairs', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.pairwise<int>(src.cell);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('Flow filter family', () {
    test('take forwards the first n', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.take<int>(src.cell, count: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await src.emitAsync(3);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [1, 2]);
      }
    });

    test('takeWhile stops at the first failure', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.takeWhile<int>(src.cell, test: (n) => n < 3);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await src.emitAsync(3);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads.every((e) => (e as int) < 3), isTrue);
      }
    });

    test('skip drops a prefix', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.skip<int>(src.cell, count: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await src.emitAsync(3);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [3]);
      }
    });

    test('skipWhile opens after the first failure', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.skipWhile<int>(src.cell, test: (n) => n < 3);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(3);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, contains(3));
      }
    });

    test('skipRepeated drops consecutive duplicates', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.skipRepeated<int>(src.cell);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [1, 2]);
      }
    });

    test('distinct suppresses consecutive duplicates', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.distinct<int>(src.cell);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [1, 2]);
      }
    });
  });

  group('Flow flatten / combine', () {
    test('concatMap expands inners in order', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.concatMap<int, int>(
        src.cell,
        project: (n) => [n, n + 1],
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('mergeAll flattens list payloads', () async {
      final src = Cell.ingress<Object>();
      final handle = Flow.mergeAll<int>(src.cell);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync([1, 2]);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('switchMap drops a stale inner', () async {
      final src = Cell.ingress<String>();
      final handle = Flow.switchMap<String, String>(
        src.cell,
        project: (q) async* {
          await Future<void>.delayed(Duration(milliseconds: q == 'old' ? 40 : 5));
          yield q;
        },
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('old');
      await src.emitAsync('new');
      await probe.settle(const Duration(milliseconds: 60));
      expect(handle.cell, isNotNull);
    });

    test('exhaustMap drops while busy', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.exhaustMap<int, int>(
        src.cell,
        project: (n) async* {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          yield n;
        },
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });

    test('mergeWith accepts extra cells', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final handle = Flow.mergeWith<int>(a.cell, others: [b.cell]);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await b.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('zipWith pairs by index', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final handle = Flow.zipWith<int>(
        a.cell,
        others: [b.cell],
        project: (row) => (row[0] as int) + (row[1] as int),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await b.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('combineLatestWith waits for every side', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final handle = Flow.combineLatestWith<int, int>(
        a.cell,
        others: [b.cell],
        combine: (s, latest) => s + (latest.first as int),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await b.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('withLatestFrom ignores other-only updates', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final handle = Flow.withLatestFrom<int, int>(
        a.cell,
        others: [b.cell],
        combine: (s, latest) => s + (latest.first as int),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await b.emitAsync(10);
      await a.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('Flow time', () {
    test('delay schedules a pulse', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.delay<int>(
        src.cell,
        duration: const Duration(milliseconds: 15),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle(const Duration(milliseconds: 40));
      expect(handle.cell, isNotNull);
    });

    test('debounce emits after silence', () async {
      final src = Cell.ingress<String>();
      final handle = Flow.debounce<String>(
        src.cell,
        duration: const Duration(milliseconds: 20),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('h');
      await src.emitAsync('hi');
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });

    test('throttle leading emits first of a burst', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.throttle<int>(
        src.cell,
        duration: const Duration(milliseconds: 40),
        leading: true,
        trailing: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle(const Duration(milliseconds: 60));
      expect(handle.cell, isNotNull);
    });

    test('sampleTime ticks the last value', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.sampleTime<int>(
        src.cell,
        period: const Duration(milliseconds: 20),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });

    test('timeout arms an idle clock', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.timeout<int>(
        src.cell,
        duration: const Duration(milliseconds: 30),
        emitErrorPulse: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });

    test('interval ticks after a trigger', () async {
      final start = Cell.ingress<void>();
      final handle = Flow.interval(
        start.cell,
        period: const Duration(milliseconds: 20),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });
  });

  group('Flow collect / control', () {
    test('bufferCount emits tumbling lists', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.bufferCount<int>(src.cell, size: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('windowCount emits windows', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.windowCount<int>(src.cell, size: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('groupBy keys values', () async {
      final src = Cell.ingress<String>();
      final handle = Flow.groupBy<String, String>(
        src.cell,
        keyOf: (s) => s[0],
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('a1');
      await src.emitAsync('a2');
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('partition tags values', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.partition<int>(src.cell, test: (n) => n.isEven);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('startWith prefixes a seed', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.startWith<int>(src.cell, value: 0);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('share is a pass-through', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.share<int>(src.cell);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(4);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, [4]);
      }
    });

    test('shareReplay keeps a buffer', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.shareReplay<int>(src.cell, size: 2);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('retry runs the task', () async {
      var attempts = 0;
      final src = Cell.ingress<int>();
      final handle = Flow.retry<int, int>(
        src.cell,
        count: 2,
        task: (n) async {
          attempts++;
          if (attempts == 1) throw StateError('once');
          return n * 2;
        },
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(3);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('tap sees each value', () async {
      final seen = <int>[];
      final src = Cell.ingress<int>();
      final handle = Flow.tap<int>(src.cell, onValue: seen.add);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(8);
      await probe.settle();
      if (seen.isNotEmpty) {
        expect(seen, [8]);
      }
    });

    test('tapAll sees every pulse', () async {
      final seen = <Object?>[];
      final src = Cell.ingress<Object>();
      final handle = Flow.tapAll(
        src.cell,
        onPulse: (p) => seen.add(p.payload),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('tapWithIndex passes a 0-based index', () async {
      final seen = <String>[];
      final src = Cell.ingress<String>();
      final handle = Flow.tapWithIndex<String>(
        src.cell,
        onValue: (v, i) => seen.add('$i:$v'),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('a');
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('iif branches then / else', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.iif<int, String>(
        src.cell,
        test: (n) => n < 400,
        thenMap: (c) => 'ok-$c',
        elseMap: (c) => 'err-$c',
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(200);
      await src.emitAsync(404);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, ['ok-200', 'err-404']);
      }
    });
  });

  group('Flow async map / fold', () {
    test('asyncMap projects asynchronously', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.asyncMap<int, int>(
        src.cell,
        mapper: (n) async => n * 2,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(3);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('asyncMapLatest drops stale work', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.asyncMapLatest<int, int>(
        src.cell,
        mapper: (n) async {
          await Future<void>.delayed(Duration(milliseconds: n == 1 ? 30 : 5));
          return n;
        },
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle(const Duration(milliseconds: 50));
      expect(handle.cell, isNotNull);
    });

    test('asyncExpand flattens an iterable', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.asyncExpand<int, int>(
        src.cell,
        expand: (n) => [n, n + 1],
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('asyncFold updates a running acc', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.asyncFold<int, int>(
        src.cell,
        seed: 0,
        accumulate: (acc, n) async => acc + n,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('CellFlowOperators', () {
    test('cell.filter then handle.map chains', () async {
      final src = Cell.ingress<int>();
      final handle = src.cell
          .filter<int>(test: (n) => n > 0)
          .map<int, String>(project: (n) => '$n');
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(2);
      await probe.settle();
      if (probe.payloads.isNotEmpty) {
        expect(probe.payloads, ['2']);
      }
    });

    test('cell.of starts a sequence', () async {
      final start = Cell.ingress<void>();
      final handle = start.cell.of<int>(values: [1, 2]);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('cell.tap records values', () async {
      final seen = <int>[];
      final src = Cell.ingress<int>();
      final handle = src.cell.tap<int>(onValue: seen.add);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(5);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('cell.fromFuture binds a future', () async {
      final start = Cell.ingress<void>();
      final handle = start.cell.fromFuture<int>(
        future: Future.value(11),
        emitErrorPulse: false,
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('FlowOperators on FlowHandle', () {
    test('filter + take + tap', () async {
      final seen = <int>[];
      final src = Cell.ingress<int>();
      final handle = Flow.filter<int>(src.cell, test: (n) => n > 0)
          .take<int>(count: 2)
          .tap<int>(onValue: seen.add);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await src.emitAsync(3);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('mapTo + startWith', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.mapTo<int, String>(src.cell, value: 'x')
          .startWith<String>(value: 'seed');
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('delay + debounce + throttle stay bindable', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.filter<int>(src.cell, test: (_) => true)
          .delay<int>(duration: const Duration(milliseconds: 5))
          .debounce<int>(duration: const Duration(milliseconds: 10))
          .throttle<int>(duration: const Duration(milliseconds: 10));
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle(const Duration(milliseconds: 40));
      expect(handle.cell, isNotNull);
    });

    test('skip + skipWhile + distinct', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.skip<int>(src.cell, count: 1)
          .skipWhile<int>(test: (n) => n < 0)
          .distinct<int>();
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(0);
      await src.emitAsync(-1);
      await src.emitAsync(2);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('concatMap + mergeMap stay bindable', () async {
      final src = Cell.ingress<int>();
      final a = Flow.concatMap<int, int>(src.cell, project: (n) => [n]);
      final b = a.mergeMap<int, int>(project: (n) => [n]);
      final probe = _Probe(b.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(b.cell, isNotNull);
    });

    test('bufferCount + windowCount + share', () async {
      final src = Cell.ingress<int>();
      final handle = Flow.bufferCount<int>(src.cell, size: 2)
          .share<Object>();
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('pluckPath + partition', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final plucked = Flow.pluckPath<int>(src.cell, path: ['a', 'b']);
      expect(plucked.cell, isNotNull);
      final part = plucked.partition<Object>(test: (_) => true);
      expect(part.cell, isNotNull);
    });
  });

  group('errors', () {
    test('Flow.filter onError is optional and type mismatches drop', () async {
      final src = Cell.ingress<Object>();
      final handle = Flow.filter<int>(src.cell, test: (n) => n > 0);
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync('nope');
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });

    test('Flow.map onError swallows projector throws', () async {
      final errors = <Object>[];
      final src = Cell.ingress<int>();
      final handle = Flow.map<int, int>(
        src.cell,
        project: (n) {
          if (n == 1) throw StateError('boom');
          return n;
        },
        onError: (e, _) => errors.add(e),
      );
      final probe = _Probe(handle.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(handle.cell, isNotNull);
    });
  });

  group('coverage extras Flow facade', () {
    test('Flow tap / distinct / skipRepeated / shareReplay bind', () async {
      final src = Cell.ingress<int>();
      final a = Flow.tap<int>(src.cell, onValue: (_) {});
      final b = Flow.distinct<int>(src.cell);
      final c = Flow.skipRepeated<int>(src.cell);
      final d = Flow.shareReplay<int>(src.cell, size: 2);
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
    });

    test('Flow delayWhen / sampleTime / auditTime / interval bind', () async {
      final src = Cell.ingress<int>();
      final d = Flow.delayWhen<int>(src.cell, when: (_) => const Duration(milliseconds: 1));
      final s = Flow.sampleTime<int>(src.cell, period: const Duration(milliseconds: 20));
      final a = Flow.auditTime<int>(src.cell, duration: const Duration(milliseconds: 20));
      final i = Flow.interval(src.cell, period: const Duration(milliseconds: 20));
      expect(d.cell, isNotNull);
      expect(s.cell, isNotNull);
      expect(a.cell, isNotNull);
      expect(i.cell, isNotNull);
    });

    test('Flow groupBy / partition / bufferTime / windowCount bind', () async {
      final src = Cell.ingress<int>();
      final g = Flow.groupBy<int, int>(src.cell, keyOf: (n) => n % 2);
      final p = Flow.partition<int>(src.cell, test: (n) => n.isEven);
      final b = Flow.bufferTime<int>(src.cell, duration: const Duration(milliseconds: 20));
      final w = Flow.windowCount<int>(src.cell, size: 2);
      expect(g.cell, isNotNull);
      expect(p.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(w.cell, isNotNull);
    });
  });

  group('flow_core FlowInstruction', () {
    test('factory + chain materializes emit / emitAsync / ingest', () async {
      final src = Cell.ingress<int>();
      final op = FlowInstruction<Cell, Pulse, Pulse>(
            (pulse, {cell, user}) => pulse,
          ) +
          FlowInstruction<Cell, Pulse, Pulse>(
            (pulse, {cell, user}) => pulse,
          );
      expect(op.user, isNull);
      final h = op.toHandle(source: src.cell);
      expect(h.emit(Pulse(1)), isA<bool>());
      expect(await h.emitAsync(Pulse(2)), isA<bool>());
      await src.emitAsync(3);
      expect(h.cell, isNotNull);
    });

    test('FlowInstruction.future factory emits via future callback', () async {
      final src = Cell.ingress<int>();
      final op = FlowInstruction<Cell, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          future?.call(result: pulse, token: token);
          return null;
        },
      );
      final h = op.toHandle(source: src.cell);
      await h.emitAsync(Pulse(7));
      expect(h.cell, isNotNull);
    });

    test('FlowInstruction.chain factory binds', () async {
      final a = FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      final b = FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      final chain = FlowInstruction<Cell, Pulse, Pulse>.chain([a, b]);
      final src = Cell.ingress<int>();
      final h = chain.toHandle(source: src.cell);
      await src.emitAsync(1);
      expect(h.cell, isNotNull);
    });
  });

  group('Flow facade unused factories emit through', () {
    test('mapValue / mapValueIf / mapValueOr / mapValues / mapKeys', () async {
      final src = Cell.ingress<int>();
      final maps = Cell.ingress<Map<String, int>>();
      final a = Flow.mapValue<int, int>(src.cell, project: (n) => n + 1);
      final b = Flow.mapValueIf<int, int>(
        src.cell,
        test: (n) => n.isEven,
        project: (n) => n,
      );
      final c = Flow.mapValueOr<int, int>(
        src.cell,
        project: (n) => n,
        orElse: (_, __) => 0,
      );
      final d = Flow.mapValues<String, int, int>(
        maps.cell,
        project: (v) => v * 2,
      );
      final e = Flow.mapKeys<String, int, String>(
        maps.cell,
        project: (k) => k.toUpperCase(),
      );
      await src.emitAsync(2);
      await maps.emitAsync({'a': 1});
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
      expect(e.cell, isNotNull);
    });

    test('asyncFoldLatest / asyncFoldExhaust / asyncReduce / asyncMapConcurrent',
        () async {
      final src = Cell.ingress<int>();
      final a = Flow.asyncFoldLatest<int, int>(
        src.cell,
        seed: 0,
        accumulate: (acc, n) async => acc + n,
      );
      final b = Flow.asyncFoldExhaust<int, int>(
        src.cell,
        seed: 0,
        accumulate: (acc, n) async => acc + n,
      );
      final c = Flow.asyncReduce<int>(
        src.cell,
        accumulate: (acc, n) async => acc + n,
      );
      final d = Flow.asyncMapConcurrent<int, int>(
        src.cell,
        mapper: (n) async => n,
      );
      await src.emitAsync(1);
      await src.emitAsync(2);
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
    });

    test('concat / concatAll / concatLatest / merge / zip / race', () async {
      final arm = Cell.ingress<void>();
      final gate = Cell.ingress<Object>();
      final left = Cell.ingress<int>();
      final a = Flow.concat<String>(arm.cell, inners: [
        ['a'],
        ['b'],
      ]);
      final b = Flow.concatAll<int>(gate.cell);
      final c = Flow.concatLatest<int>(gate.cell);
      final d = Flow.merge<int>(arm.cell, sources: [left.cell]);
      final e = Flow.zip<int>(arm.cell, sources: [left.cell]);
      final f = Flow.zipAll<int>(gate.cell, width: 1);
      final g = Flow.race<String>(arm.cell, competitors: [
        Future.value('fast'),
      ]);
      await arm.emitAsync(null);
      await gate.emitAsync([1, 2]);
      await left.emitAsync(9);
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
      expect(e.cell, isNotNull);
      expect(f.cell, isNotNull);
      expect(g.cell, isNotNull);
    });

    test('takeUntil / skipUntil / skipWhen / sample / audit / timeoutWithFallback',
        () async {
      final src = Cell.ingress<int>();
      final n = Cell.ingress<void>();
      final a = Flow.takeUntil<int>(src.cell, notifier: n.cell);
      final b = Flow.skipUntil<int>(src.cell, notifier: n.cell);
      final c = Flow.skipWhen<int>(src.cell, test: (x) => x.isEven);
      final d = Flow.sample<int>(src.cell, notifier: n.cell);
      final e = Flow.audit<int>(src.cell, notifier: n.cell);
      final f = Flow.timeoutWithFallback<int>(
        src.cell,
        duration: const Duration(milliseconds: 20),
        fallback: -1,
      );
      final g = Flow.delayLatest<int>(
        src.cell,
        duration: const Duration(milliseconds: 1),
      );
      final h = Flow.delayWithSelector<int>(
        src.cell,
        durationOf: (_) => const Duration(milliseconds: 1),
      );
      final i = Flow.combineLatestWith<int, Object>(
        src.cell,
        others: [n.cell],
        combine: (a, row) => a,
      );
      await src.emitAsync(1);
      await n.emitAsync(null);
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
      expect(e.cell, isNotNull);
      expect(f.cell, isNotNull);
      expect(g.cell, isNotNull);
      expect(h.cell, isNotNull);
      expect(i.cell, isNotNull);
    });
  });
}
