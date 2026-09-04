// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/distinct.dart';
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
  group('DistinctUntilChanged', () {
    test('suppresses only consecutive duplicates', () async {
      final b = bind(DistinctUntilChanged<int>());
      addTearDown(b.probe.stop);
      for (final n in [1, 1, 2, 2, 1, 3, 3]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 1, 3]);
    });

    test('the first value always passes', () async {
      final b = bind(DistinctUntilChanged<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(0);
      await b.probe.settle();
      expect(b.probe.payloads, [0]);
    });

    test('uses a custom equals comparator', () async {
      final b = bind(DistinctUntilChanged<String>(
        equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('Alice');
      await b.gate.emitAsync('alice');
      await b.gate.emitAsync('Bob');
      await b.probe.settle();
      expect(b.probe.payloads, ['Alice', 'Bob']);
    });

    test('equals exceptions call onError and drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(DistinctUntilChanged<int>(
        equals: (a, b) {
          if (b == 2) throw StateError('cmp');
          return a == b;
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

    test('wrong types are dropped and do not poison memory', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = DistinctUntilChanged<int>(
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('nope');
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [1, 2]);
      expect(errors.single, isA<FormatException>());
    });

    test('marks lineage with DistinctUntilChanged', () async {
      final b = bind(DistinctUntilChanged<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('DistinctUntilChanged'));
    });
  });

  group('DistinctUntilKeyChanged', () {
    test('compares keys and forwards the original payload', () async {
      final b = bind(DistinctUntilKeyChanged<String, String>(
        (s) => s.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('Alice');
      await b.gate.emitAsync('ALICE');
      await b.gate.emitAsync('Bob');
      await b.probe.settle();
      expect(b.probe.payloads, ['Alice', 'Bob']);
    });

    test('a later return to a previous key still passes', () async {
      final b = bind(DistinctUntilKeyChanged<String, int>((s) => s.length));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('aa');
      await b.gate.emitAsync('bb');
      await b.gate.emitAsync('ccc');
      await b.gate.emitAsync('dd');
      await b.probe.settle();
      expect(b.probe.payloads, ['aa', 'ccc', 'dd']);
    });

    test('keyOf exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(DistinctUntilKeyChanged<int, int>(
        (n) {
          if (n == 2) throw FormatException('key');
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
      expect(errors.single, isA<FormatException>());
    });
  });

  group('Distinct', () {
    test('drops any previously seen value', () async {
      final b = bind(Distinct<int>());
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 1, 3, 2, 1]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('custom equals treats different instances as the same', () async {
      final b = bind(Distinct<String>(
        equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('A');
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('B');
      await b.probe.settle();
      expect(b.probe.payloads, ['A', 'B']);
    });

    test('first value always passes', () async {
      final b = bind(Distinct<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(b.probe.payloads, [9]);
    });
  });

  group('DistinctKey', () {
    test('keeps the first payload for each key', () async {
      final b = bind(DistinctKey<Map<String, Object>, Object>((m) => m['id']!));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1, 'name': 'Ann'});
      await b.gate.emitAsync({'id': 1, 'name': 'Ann-2'});
      await b.gate.emitAsync({'id': 2, 'name': 'Bea'});
      await b.probe.settle();
      expect(b.probe.payloads, [
        {'id': 1, 'name': 'Ann'},
        {'id': 2, 'name': 'Bea'},
      ]);
    });

    test('keyOf exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(DistinctKey<int, int>(
        (n) {
          if (n < 0) throw StateError('neg');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(-1);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });
}
