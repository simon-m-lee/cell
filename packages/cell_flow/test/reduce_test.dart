// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/reduce.dart';
import 'package:test/test.dart';

// StartWith lives in start_with.dart / start_with_test.dart.

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
  group('Reduce', () {
    test('folds from the seed and exposes the snapshot', () async {
      final op = Reduce<int, int>(0, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(op.snapshot.value, 3);
      expect(op.snapshot.generation, 2);
      expect(b.probe.steps, contains('Reduce'));
    });

    test('reduce exceptions call onError and keep the previous acc', () async {
      final errors = <Object>[];
      final op = Reduce<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('reduce');
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
      expect(b.probe.payloads, [1, 4]);
      expect(op.snapshot.value, 4);
      expect(op.snapshot.generation, 2);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types do not touch the snapshot', () async {
      final errors = <Object>[];
      final op = Reduce<int, int>(
        0,
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(5);
      await probe.settle();
      expect(probe.payloads, [5]);
      expect(op.snapshot.value, 5);
      expect(op.snapshot.generation, 1);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ReduceSelect', () {
    test('projects a field', () async {
      final b = bind(ReduceSelect<Map<String, Object>, Object>((m) => m['name']!));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1, 'name': 'Ann'});
      await b.probe.settle();
      expect(b.probe.payloads, ['Ann']);
    });

    test('select exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(ReduceSelect<int, int>(
        (n) => throw StateError('select'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('ReduceMachine', () {
    test('applies transitions', () async {
      final op = ReduceMachine<String, int>(0, (acc, event) {
        return switch (event) {
          'inc' => acc + 1,
          'dec' => acc - 1,
          _ => acc,
        };
      });
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('inc');
      await b.gate.emitAsync('dec');
      await b.probe.settle();
      expect(b.probe.payloads, [1, 0]);
      expect(op.snapshot.value, 0);
    });

    test('emitIfUnchanged false drops no-op transitions', () async {
      final b = bind(ReduceMachine<String, int>(
        0,
        (acc, event) => event == 'inc' ? acc + 1 : acc,
        emitIfUnchanged: false,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('noop');
      await b.gate.emitAsync('inc');
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('transition exceptions call onError and keep the previous acc',
        () async {
      final errors = <Object>[];
      final op = ReduceMachine<String, int>(
        0,
        (acc, event) {
          if (event == 'boom') throw StateError('trans');
          return acc + 1;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('ok');
      await b.gate.emitAsync('boom');
      await b.gate.emitAsync('ok');
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
      expect(op.snapshot.value, 2);
      expect(errors.single, isA<StateError>());
    });
  });
}
