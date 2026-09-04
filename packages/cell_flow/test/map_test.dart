// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
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
  group('MapValue', () {
    test('projects each typed payload', () async {
      final b = bind(MapValue<int, int>((n) => n * 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 4]);
      expect(b.probe.steps, contains('MapValue'));
    });

    test('project exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapValue<int, int>(
        (n) {
          if (n == 2) throw StateError('map');
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

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapValue<int, int>(
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('MapTo', () {
    test('emits the constant for every typed pulse', () async {
      final b = bind(MapTo<void, String>('ping'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ping', 'ping']);
    });
  });

  group('MapWithIndex', () {
    test('includes a 0-based index that skips bad types', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapWithIndex<String, String>(
        (s, i) => '$i:$s',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('a');
      await gate.emitAsync(1);
      await gate.emitAsync('b');
      await probe.settle();
      expect(probe.payloads, ['0:a', '1:b']);
      expect(errors.single, isA<FormatException>());
    });

    test('project exceptions drop the pulse and do not advance index',
        () async {
      final errors = <Object>[];
      final b = bind(MapWithIndex<int, int>(
        (n, i) {
          if (n == 2) throw StateError('idx');
          return i;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('MapNotNull', () {
    test('drops null projections', () async {
      final b = bind(MapNotNull<int, int>((n) => n.isEven ? n : null));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('project exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapNotNull<int, int>(
        (n) => throw StateError('nn'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('MapWhen', () {
    test('projects only matching values', () async {
      final b = bind(MapWhen<int, String>(
        (n) => n.isEven,
        (n) => 'even-$n',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, ['even-2']);
    });

    test('test exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapWhen<int, int>(
        (n) => throw StateError('test'),
        (n) => n,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });
}
