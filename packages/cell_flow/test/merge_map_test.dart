// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/merge_map.dart';
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
  group('MergeMap', () {
    test('emits in completion order', () async {
      final b = bind(MergeMap<String, String>((name) async {
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

    test('concurrency 1 serializes inners', () async {
      final seen = <int>[];
      final b = bind(MergeMap<int, int>(
        (n) async {
          seen.add(n);
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return n;
        },
        concurrency: 1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(seen, [1]);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, [1, 2]);
    });

    test('flattens an Iterable', () async {
      final b = bind(MergeMap<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('mapper exceptions call onError and keep going', () async {
      final errors = <Object>[];
      final b = bind(MergeMap<int, int>(
        (n) {
          if (n == 2) throw StateError('boom');
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
      final out = MergeMap<int, int>(
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(4);
      await probe.settle();
      expect(probe.payloads, [4]);
      expect(errors.single, isA<FormatException>());
    });

    test('inner future errors call onError', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(MergeMap<void, int>(
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

  group('MergeMapTo', () {
    test('starts the same inner on every trigger', () async {
      final b = bind(MergeMapTo<void, String>(() => 'ping'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ping', 'ping']);
    });

    test('factory exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(MergeMapTo<void, int>(
        () => throw FormatException('factory'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('MergeScan', () {
    test('emits a running total', () async {
      final b = bind(MergeScan<int, int>(0, (acc, n) => acc + n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
    });

    test('flattens an inner list and uses the last A as the next seed', () async {
      final b = bind(MergeScan<int, int>(0, (acc, n) => [acc + n, acc + n + 10]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 11]);
    });

    test('accumulate exceptions call onError and keep the previous seed',
        () async {
      final errors = <Object>[];
      final b = bind(MergeScan<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('scan');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 4]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError and do not touch the seed', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MergeScan<int, int>(
        0,
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(5);
      await probe.settle();
      expect(probe.payloads, [5]);
      expect(errors.single, isA<FormatException>());
    });
  });
}
