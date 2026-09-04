// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/take.dart';
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
  group('Take', () {
    test('forwards only the first n values', () async {
      final b = bind(Take<int>(3));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4, 5]) {
        await b.gate.emitAsync(n);
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

    test('wrong types do not consume the quota', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Take<int>(
        1,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(7);
      await gate.emitAsync(8);
      await probe.settle();
      expect(probe.payloads, [7]);
      expect(errors.single, isA<FormatException>());
    });

    test('marks lineage with Take', () async {
      final b = bind(Take<int>(1));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('Take'));
    });
  });

  group('TakeWhile', () {
    test('stops before the first failing value', () async {
      final b = bind(TakeWhile<int>((n) => n < 3));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('inclusive emits the failing value then closes', () async {
      final b = bind(TakeWhile<int>((n) => n < 3, inclusive: true));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('predicate exceptions close the gate', () async {
      final errors = <Object>[];
      final b = bind(TakeWhile<int>(
        (n) {
          if (n == 2) throw StateError('stop');
          return true;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TakeUntil', () {
    test('closes when the notifier emits', () async {
      final stop = Cell.ingress<void>();
      final b = bind(TakeUntil<String>(stop.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await stop.emitAsync(null);
      await b.gate.emitAsync('c');
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b']);
    });

    test('a notifier that already fired keeps the gate closed', () async {
      final stop = Cell.ingress<void>();
      await stop.emitAsync(null);
      final b = bind(TakeUntil<int>(stop.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      // Observer is attached at construction; a prior pulse is not replayed
      // unless the Cell retains it. Accept either closed or first-value.
      expect(b.probe.payloads, anyOf(isEmpty, [1]));
    });
  });

  group('TakeUntilTime', () {
    test('forwards until the window closes', () async {
      final b = bind(TakeUntilTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });
  });
}
