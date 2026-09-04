// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/concat.dart';
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
  group('Concat', () {
    test('plays static inners in order after the arming pulse', () async {
      final b = bind(Concat<String>([
        ['a', 'b'],
        ['c'],
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b', 'c']);
    });

    test('a second arming pulse is ignored', () async {
      final b = bind(Concat<int>([
        [1],
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('inner errors call onError and continue', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(Concat<int>(
        [
          pending.future,
          [2],
        ],
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await Future<void>.delayed(Duration.zero);
      pending.completeError(StateError('inner'));
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('ConcatAll', () {
    test('queues inners in arrival order', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync([1, 2]);
      await b.gate.emitAsync([3]);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('a slow first inner delays the second', () async {
      final first = Completer<String>();
      final b = bind(ConcatAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(first.future);
      await b.gate.emitAsync(['b']);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      first.complete('a');
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b']);
    });

    test('inner errors call onError and keep the queue moving', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(ConcatAll<int>(onError: (e, _) => errors.add(e)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(pending.future);
      await b.gate.emitAsync([3]);
      await Future<void>.delayed(Duration.zero);
      pending.completeError(StateError('boom'));
      await b.probe.settle();
      expect(b.probe.payloads, [3]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('ConcatFirst', () {
    test('emits only the first item of each inner', () async {
      final b = bind(ConcatFirst<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(['a', 'b']);
      await b.gate.emitAsync(['c', 'd']);
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'c']);
    });

    test('empty inner emits nothing', () async {
      final b = bind(ConcatFirst<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(<int>[]);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('ConcatLatest', () {
    test('emits only the last item of each inner', () async {
      final b = bind(ConcatLatest<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(['a', 'b', 'c']);
      await b.gate.emitAsync(['d']);
      await b.probe.settle();
      expect(b.probe.payloads, ['c', 'd']);
    });

    test('empty inner emits nothing', () async {
      final b = bind(ConcatLatest<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(<int>[]);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('edges', () {
    test('null inner is a no-op', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync([1]);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('a string is not flattened as an iterable', () async {
      final b = bind(ConcatAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('hi');
      await b.probe.settle();
      expect(b.probe.payloads, ['hi']);
    });

    test('stream events are concatenated', () async {
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream.fromIterable([1, 2]));
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('performance', () {
    test('ConcatAll flattens 100 short lists', () async {
      final sw = Stopwatch()..start();
      final b = bind(ConcatAll<int>());
      addTearDown(b.probe.stop);
      for (var i = 0; i < 100; i++) {
        await b.gate.emitAsync([i, i]);
      }
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(200));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
