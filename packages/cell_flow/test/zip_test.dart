// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/zip.dart';
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
  group('ZipWith', () {
    test('pairs by index, not by latest', () async {
      final right = Cell.ingress<String>();
      final b = bind(ZipWith<List<Object?>>([right.cell]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      await right.emitAsync('a');
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 'a'],
      ]);
    });

    test('queues extra values on one side', () async {
      final right = Cell.ingress<String>();
      final b = bind(ZipWith<List<Object?>>([right.cell]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await right.emitAsync('a');
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 'a'],
      ]);
      await right.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 'a'],
        [2, 'b'],
      ]);
    });

    test('project exceptions drop that pair', () async {
      final errors = <Object>[];
      final right = Cell.ingress<int>();
      final b = bind(ZipWith<int>(
        [right.cell],
        project: (row) {
          final sum = (row[0] as int) + (row[1] as int);
          if (sum == 3) throw StateError('zip');
          return sum;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await right.emitAsync(2);
      await b.gate.emitAsync(10);
      await right.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [11]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('Zip', () {
    test('arms then zips extra cells', () async {
      final a = Cell.ingress<int>();
      final c = Cell.ingress<int>();
      final b = bind(Zip<List<Object?>>([a.cell, c.cell]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await a.emitAsync(1);
      await c.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });
  });

  group('ZipAll', () {
    test('packs width items from one source', () async {
      final b = bind(ZipAll<int>(2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [
        [1, 2],
      ]);
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ZipAll<int>(
        2,
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

  group('edges', () {
    test('an unmatched leftover is not emitted', () async {
      final right = Cell.ingress<String>();
      final b = bind(ZipWith<List<Object?>>([right.cell]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('performance', () {
    test('ZipAll packs 200 items', () async {
      final sw = Stopwatch()..start();
      final b = bind(ZipAll<int>(2));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(100));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
