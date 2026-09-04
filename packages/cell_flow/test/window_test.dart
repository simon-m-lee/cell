// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/window.dart';
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
  group('WindowCount', () {
    test('emits tumbling windows of size n', () async {
      final b = bind(WindowCount<int>(2));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4, 5]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('overlapping skip emits sliding windows', () async {
      final b = bind(WindowCount<int>(2, skip: 1));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
        [2, 3],
      ]);
    });

    test('wrong types do not count toward the window', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = WindowCount<int>(
        2,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('x');
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [
        [1, 2],
      ]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('WindowSize', () {
    test('is an alias of WindowCount', () async {
      final b = bind(WindowSize<int>(2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });
  });

  group('WindowTime', () {
    test('flushes the buffer when the duration elapses', () async {
      final b = bind(WindowTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, isEmpty);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });

    test('skips empty windows by default', () async {
      final b = bind(WindowTime<int>(const Duration(milliseconds: 25)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 40));
      final afterFirst = b.probe.payloads.length;
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads.length, afterFirst);
    });

    test('wrong types are not buffered', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = WindowTime<int>(
        const Duration(milliseconds: 30),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(1);
      await probe.settle(const Duration(milliseconds: 50));
      expect(probe.payloads, [
        [1],
      ]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('WindowWhen', () {
    test('flushes when the closer emits', () async {
      final close = Cell.ingress<void>();
      final b = bind(WindowWhen<String>(close.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      await close.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [
        ['a', 'b'],
      ]);
    });

    test('skips an empty flush', () async {
      final close = Cell.ingress<void>();
      final b = bind(WindowWhen<int>(close.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await close.emitAsync(null);
      await close.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1],
      ]);
    });

    test('wrong types are not buffered', () async {
      final errors = <Object>[];
      final close = Cell.ingress<void>();
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = WindowWhen<String>(
        close.cell,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('a');
      await close.emitAsync(null);
      await probe.settle();
      expect(probe.payloads, [
        ['a'],
      ]);
      expect(errors.single, isA<FormatException>());
    });
  });
}
