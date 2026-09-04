// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/concat_map.dart';
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
  group('ConcatMap', () {
    test('expands each trigger in FIFO order', () async {
      final b = bind(ConcatMap<String, String>((id) async* {
        yield '$id:a';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        yield '$id:b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('ORD-1');
      await b.gate.emitAsync('ORD-2');
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [
        'ORD-1:a',
        'ORD-1:b',
        'ORD-2:a',
        'ORD-2:b',
      ]);
    });

    test('flattens an Iterable synchronously', () async {
      final b = bind(ConcatMap<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(10);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 10, 11]);
    });

    test('awaits a Future and emits the single value', () async {
      final b = bind(ConcatMap<int, int>((n) async => n * 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [6]);
    });

    test('null mapper result emits nothing', () async {
      final b = bind(ConcatMap<int, int>((n) => n.isEven ? n : null));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('wrong payload type is dropped and reported', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ConcatMap<int, int>(
        (n) => [n],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(4);
      await probe.settle();
      expect(probe.payloads, [4]);
      expect(errors.single, isA<FormatException>());
    });

    test('mapper exceptions call onError and continue', () async {
      final errors = <Object>[];
      final b = bind(ConcatMap<int, int>(
        (n) {
          if (n == 2) throw StateError('boom');
          return [n];
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

    test('marks lineage with ConcatMap', () async {
      final b = bind(ConcatMap<int, int>((n) => n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('ConcatMap'));
    });
  });

  group('ConcatMapTo', () {
    test('ignores the trigger payload and repeats the same inner', () async {
      final b = bind(ConcatMapTo<int, String>(() async* {
        yield 'ping';
        yield 'pong';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(99);
      await b.probe.settle();
      expect(b.probe.payloads, ['ping', 'pong', 'ping', 'pong']);
    });

    test('queues inners so they do not interleave', () async {
      final b = bind(ConcatMapTo<void, String>(() async* {
        yield 'a';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        yield 'b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['a', 'b', 'a', 'b']);
    });

    test('factory exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(ConcatMapTo<void, int>(
        () => throw FormatException('x'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ConcatAll', () {
    test('flattens list payloads in arrival order', () async {
      final b = bind(ConcatAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(['a', 'b']);
      await b.gate.emitAsync(['c']);
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b', 'c']);
    });

    test('flattens a Stream payload', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream.fromIterable([1, 2, 3]));
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('awaits a Future payload', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Future.value(7));
      await b.probe.settle();
      expect(b.probe.payloads, [7]);
    });

    test('raw matching values pass through', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(5);
      await b.probe.settle();
      expect(b.probe.payloads, [5]);
    });

    test('does not treat a String as an iterable of graphemes', () async {
      final b = bind(ConcatAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('ab');
      await b.probe.settle();
      expect(b.probe.payloads, ['ab']);
    });
  });

  group('ConcatMapLatest', () {
    test('ignores stale in-flight inners', () async {
      final b = bind(ConcatMapLatest<String, String>((q) async* {
        await Future<void>.delayed(Duration(
          milliseconds: q == 'old' ? 40 : 8,
        ));
        yield '$q-1';
        yield '$q-2';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['new-1', 'new-2']);
    });

    test('emits the full inner when it is the only trigger', () async {
      final b = bind(ConcatMapLatest<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types are reported', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ConcatMapLatest<int, int>(
        (n) => [n],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ConcatMapFirst', () {
    test('drops triggers while an inner is running', () async {
      final b = bind(ConcatMapFirst<int, String>((n) async* {
        yield '$n-a';
        await Future<void>.delayed(const Duration(milliseconds: 40));
        yield '$n-b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['1-a', '1-b']);
    });

    test('accepts a new trigger after the previous inner finishes', () async {
      final b = bind(ConcatMapFirst<int, int>((n) async {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        return n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 2]);
    });

    test('mapper exceptions release the busy latch', () async {
      final errors = <Object>[];
      var calls = 0;
      final b = bind(ConcatMapFirst<int, int>(
        (n) {
          calls++;
          if (n == 1) throw StateError('fail');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(calls, 2);
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });
  });
}
