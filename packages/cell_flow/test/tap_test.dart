// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/tap.dart';
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
  group('Tap', () {
    test('forwards values after the side effect', () async {
      final seen = <int>[];
      final b = bind(Tap<int>(seen.add));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(seen, [1, 2]);
      expect(b.probe.payloads, [1, 2]);
      expect(b.probe.steps, contains('Tap'));
    });

    test('side-effect exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(Tap<int>(
        (n) {
          if (n == 2) throw StateError('tap');
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

    test('wrong types call onError and skip the tap', () async {
      final errors = <Object>[];
      final seen = <int>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Tap<int>(
        seen.add,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(seen, [1]);
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('TapAll', () {
    test('sees every pulse including wrong types', () async {
      final seen = <Object?>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = TapAll((p) => seen.add(p.payload)).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('x');
      await probe.settle();
      expect(seen, [1, 'x']);
      expect(probe.payloads, [1, 'x']);
    });

    test('onPulse exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(TapAll(
        (p) {
          if (p.payload == 2) throw StateError('all');
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TapWithIndex', () {
    test('passes a 0-based index that skips bad types', () async {
      final seen = <(int, int)>[];
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = TapWithIndex<int>(
        (n, i) => seen.add((n, i)),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(10);
      await gate.emitAsync('x');
      await gate.emitAsync(20);
      await probe.settle();
      expect(seen, [(10, 0), (20, 1)]);
      expect(errors.single, isA<FormatException>());
    });

    test('callback exceptions drop the pulse and do not advance index',
        () async {
      final errors = <Object>[];
      final seen = <int>[];
      final b = bind(TapWithIndex<int>(
        (n, i) {
          if (n == 2) throw StateError('idx');
          seen.add(i);
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(seen, [0, 1]);
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TapState', () {
    test('folds a snapshot without changing payloads', () async {
      final op = TapState<int, int>(0, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
      expect(op.snapshot.value, 3);
      expect(op.snapshot.seen, 2);
    });

    test('next exceptions drop the pulse and keep the snapshot', () async {
      final errors = <Object>[];
      final op = TapState<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('fold');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(op.snapshot.value, 4);
      expect(op.snapshot.seen, 2);
      expect(errors.single, isA<StateError>());
    });
  });
}
