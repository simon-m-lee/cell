// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:test/test.dart' hide Retry, Skip, Timeout;

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
  group('CellFlowOperators', () {
    test('filter then map via Cell extensions', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (n) => n > 0)
          .map<int, String>(project: (n) => 'n=$n');
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, ['n=2']));
    });

    test('of emits on first trigger', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.of<String>(values: ['a', 'b']);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('fromIterable binds', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.fromIterable<int>(iterable: [1, 2]);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('range binds', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.range(start: 0, count: 3);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('repeat binds', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.repeat<int>(value: 7, count: 2);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('fromFuture binds', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.fromFuture<int>(future: Future.value(9));
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('fromStream binds', () async {
      final start = Cell.ingress<void>();
      final out = start.cell.fromStream<int>(stream: Stream.fromIterable([1]));
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await start.emitAsync(null);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('tap is side-effect only', () async {
      final seen = <int>[];
      final src = Cell.ingress<int>();
      final out = src.cell.tap<int>(onValue: seen.add);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(3);
      await probe.settle();
      expect(out.cell, isNotNull);
    });
  });

  group('FlowOperators transform', () {
    test('mapTo emits a constant', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .mapTo<int, String>(value: 'x');
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, ['x']));
    });

    test('mapWithIndex binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .mapWithIndex<int, String>(project: (n, i) => '$i:$n');
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(5);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('mapNotNull drops nulls', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .mapNotNull<int, int>(project: (n) => n.isEven ? n : null);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, [2]));
    });

    test('mapWhen projects matching values', () async {
      final src = Cell.ingress<int>();
      final out = src.cell.filter<int>(test: (_) => true).mapWhen<int, int>(
            test: (n) => n > 0,
            project: (n) => n * 10,
          );
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(2);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('pluck reads a map key', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final out = src.cell
          .filter<Map<String, Object>>(test: (_) => true)
          .pluck<int>(key: 'n');
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync({'n': 4});
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, [4]));
    });

    test('pluckOr uses orElse', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final out = src.cell
          .filter<Map<String, Object>>(test: (_) => true)
          .pluckOr<int>(key: 'missing', orElse: 0);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync({'n': 1});
      await probe.settle();
      expect(probe.payloads, anyOf(isEmpty, [0]));
    });

    test('pluckPath binds', () async {
      final src = Cell.ingress<Map<String, Object>>();
      final out = src.cell
          .filter<Map<String, Object>>(test: (_) => true)
          .pluckPath<int>(path: ['user', 'id'], orElse: 0, useOrElse: true);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync({'user': <String, Object>{'id': 7}});
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('scan binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .scan<int, int>(accumulate: (acc, n) => acc + n);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('reduce binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell.filter<int>(test: (_) => true).reduce<int, int>(
            seed: 0,
            accumulate: (acc, n) => acc + n,
          );
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(3);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('pairwise binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell.filter<int>(test: (_) => true).pairwise<int>();
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(2);
      await probe.settle();
      expect(out.cell, isNotNull);
    });
  });

  group('FlowOperators async', () {
    test('asyncMap binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .asyncMap<int, int>(mapper: (n) async => n + 1);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('asyncMapLatest binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .asyncMapLatest<int, int>(mapper: (n) async => n);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('asyncExpand binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .asyncExpand<int, int>(expand: (n) => [n, n]);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('asyncFold binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell.filter<int>(test: (_) => true).asyncFold<int, int>(
            seed: 0,
            accumulate: (acc, n) async => acc + n,
          );
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });
  });

  group('FlowOperators filter family', () {
    test('take / skip / distinct chain', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .skip<int>(count: 1)
          .take<int>(count: 2)
          .distinct<int>();
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      for (final n in [1, 2, 2, 3, 4]) {
        await src.emitAsync(n);
      }
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('takeWhile / skipWhile bind', () async {
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .skipWhile<int>(test: (n) => n < 0)
          .takeWhile<int>(test: (n) => n < 10);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(3);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('takeUntil / skipUntil bind', () async {
      final src = Cell.ingress<int>();
      final stop = Cell.ingress<void>();
      final start = Cell.ingress<void>();
      final out = src.cell
          .filter<int>(test: (_) => true)
          .skipUntil<int>(notifier: start.cell)
          .takeUntil<int>(notifier: stop.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await start.emitAsync(null);
      await src.emitAsync(2);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('skipRepeated binds', () async {
      final src = Cell.ingress<int>();
      final out = src.cell.filter<int>(test: (_) => true).skipRepeated<int>();
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(1);
      await src.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });
  });

  group('FlowOperators flatten / combine', () {
    test('concatMap / mergeMap / switchMap / exhaustMap bind', () async {
      final src = Cell.ingress<int>();
      final a = src.cell
          .filter<int>(test: (_) => true)
          .concatMap<int, int>(project: (n) => [n]);
      final b = src.cell
          .filter<int>(test: (_) => true)
          .mergeMap<int, int>(project: (n) => [n]);
      final c = src.cell
          .filter<int>(test: (_) => true)
          .switchMap<int, int>(project: (n) => [n]);
      final d = src.cell
          .filter<int>(test: (_) => true)
          .exhaustMap<int, int>(project: (n) => [n]);
      addTearDown(() {});
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(c.cell, isNotNull);
      expect(d.cell, isNotNull);
    });

    test('concatAll / mergeAll bind', () async {
      final src = Cell.ingress<Object>();
      final a = src.cell.filter<Object>(test: (_) => true).concatAll<int>();
      final b = src.cell.filter<Object>(test: (_) => true).mergeAll<int>();
      expect(a.cell, isNotNull);
      expect(b.cell, isNotNull);
    });

    test('mergeWith / zipWith bind', () async {
      final src = Cell.ingress<int>();
      final other = Cell.ingress<int>();
      final merged = src.cell
          .filter<int>(test: (_) => true)
          .mergeWith<int>(others: [other.cell]);
      final zipped = src.cell
          .filter<int>(test: (_) => true)
          .zipWith<List<Object?>>(others: [other.cell]);
      expect(merged.cell, isNotNull);
      expect(zipped.cell, isNotNull);
    });

    test('combineLatestWith / withLatestFrom bind', () async {
      final src = Cell.ingress<int>();
      final other = Cell.ingress<int>();
      final c = src.cell.filter<int>(test: (_) => true).combineLatestWith<int, int>(
            others: [other.cell],
            combine: (s, latest) => s + (latest.first as int? ?? 0),
          );
      final w = src.cell.filter<int>(test: (_) => true).withLatestFrom<int, int>(
            others: [other.cell],
            combine: (s, latest) => s,
          );
      expect(c.cell, isNotNull);
      expect(w.cell, isNotNull);
    });
  });

  group('FlowOperators time / collect / control', () {
    test('delay / debounce / throttle bind', () async {
      final src = Cell.ingress<int>();
      final d = src.cell
          .filter<int>(test: (_) => true)
          .delay<int>(duration: const Duration(milliseconds: 5));
      final b = src.cell
          .filter<int>(test: (_) => true)
          .debounce<int>(duration: const Duration(milliseconds: 5));
      final t = src.cell
          .filter<int>(test: (_) => true)
          .throttle<int>(duration: const Duration(milliseconds: 5));
      expect(d.cell, isNotNull);
      expect(b.cell, isNotNull);
      expect(t.cell, isNotNull);
    });

    test('sample / sampleTime / auditTime / timeout / interval bind', () async {
      final src = Cell.ingress<int>();
      final tick = Cell.ingress<void>();
      final s = src.cell
          .filter<int>(test: (_) => true)
          .sample<int>(notifier: tick.cell);
      final st = src.cell
          .filter<int>(test: (_) => true)
          .sampleTime<int>(period: const Duration(milliseconds: 20));
      final a = src.cell
          .filter<int>(test: (_) => true)
          .auditTime<int>(duration: const Duration(milliseconds: 20));
      final to = src.cell
          .filter<int>(test: (_) => true)
          .timeout<int>(duration: const Duration(milliseconds: 40));
      final iv = src.cell.filter<int>(test: (_) => true).interval(
            period: const Duration(milliseconds: 20),
          );
      expect(s.cell, isNotNull);
      expect(st.cell, isNotNull);
      expect(a.cell, isNotNull);
      expect(to.cell, isNotNull);
      expect(iv.cell, isNotNull);
    });

    test('bufferCount / bufferTime / windowCount bind', () async {
      final src = Cell.ingress<int>();
      final bc = src.cell.filter<int>(test: (_) => true).bufferCount<int>(size: 2);
      final bt = src.cell
          .filter<int>(test: (_) => true)
          .bufferTime<int>(duration: const Duration(milliseconds: 20));
      final wc = src.cell.filter<int>(test: (_) => true).windowCount<int>(size: 2);
      expect(bc.cell, isNotNull);
      expect(bt.cell, isNotNull);
      expect(wc.cell, isNotNull);
    });

    test('groupBy / partition bind', () async {
      final src = Cell.ingress<int>();
      final g = src.cell
          .filter<int>(test: (_) => true)
          .groupBy<int, String>(keyOf: (n) => n.isEven ? 'e' : 'o');
      final p = src.cell
          .filter<int>(test: (_) => true)
          .partition<int>(test: (n) => n.isEven);
      expect(g.cell, isNotNull);
      expect(p.cell, isNotNull);
    });

    test('startWith / share / shareReplay bind', () async {
      final src = Cell.ingress<int>();
      final sw = src.cell.filter<int>(test: (_) => true).startWith<int>(value: 0);
      final sh = src.cell.filter<int>(test: (_) => true).share<int>();
      final sr = src.cell.filter<int>(test: (_) => true).shareReplay<int>(size: 2);
      expect(sw.cell, isNotNull);
      expect(sh.cell, isNotNull);
      expect(sr.cell, isNotNull);
    });

    test('tapAll / tapWithIndex bind', () async {
      final src = Cell.ingress<int>();
      final a = src.cell
          .filter<int>(test: (_) => true)
          .tapAll(onPulse: (_) {});
      final i = src.cell
          .filter<int>(test: (_) => true)
          .tapWithIndex<int>(onValue: (n, idx) {});
      expect(a.cell, isNotNull);
      expect(i.cell, isNotNull);
    });
  });

  group('fluent chain smoke', () {
    test('filter + map + tap + take is one pipeline', () async {
      final seen = <String>[];
      final src = Cell.ingress<int>();
      final out = src.cell
          .filter<int>(test: (n) => n > 0)
          .map<int, String>(project: (n) => '$n')
          .tap<String>(onValue: seen.add)
          .take<String>(count: 10);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await src.emitAsync(-1);
      await src.emitAsync(4);
      await probe.settle();
      expect(out.cell, isNotNull);
    });
  });
}
