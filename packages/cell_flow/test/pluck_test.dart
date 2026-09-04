// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/pluck.dart';
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
  group('Pluck', () {
    test('reads a map field', () async {
      final b = bind(Pluck<String>('name'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1, 'name': 'Ann'});
      await b.probe.settle();
      expect(b.probe.payloads, ['Ann']);
      expect(b.probe.steps, contains('Pluck'));
    });

    test('reads a list index', () async {
      final b = bind(Pluck<int>(1));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync([10, 20, 30]);
      await b.probe.settle();
      expect(b.probe.payloads, [20]);
    });

    test('wrong field type calls onError', () async {
      final errors = <Object>[];
      final b = bind(Pluck<String>(
        'id',
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1});
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });

    test('unsupported source type calls onError', () async {
      final errors = <Object>[];
      final b = bind(Pluck<int>(
        'x',
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(42);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });

    test('out of range list index calls onError', () async {
      final errors = <Object>[];
      final b = bind(Pluck<int>(
        5,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync([1, 2]);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<RangeError>());
    });
  });

  group('PluckOr', () {
    test('uses orElse when the key is missing', () async {
      final b = bind(PluckOr<String>('city', orElse: 'n/a'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1});
      await b.probe.settle();
      expect(b.probe.payloads, ['n/a']);
    });

    test('uses orElse when the source cannot be plucked', () async {
      final errors = <Object>[];
      final b = bind(PluckOr<int>(
        'x',
        orElse: 0,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(true);
      await b.probe.settle();
      expect(b.probe.payloads, [0]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('PluckAll', () {
    test('collects the requested keys', () async {
      final b = bind(PluckAll(['id', 'name']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1, 'name': 'Ann', 'extra': true});
      await b.probe.settle();
      expect(b.probe.payloads.single, {'id': 1, 'name': 'Ann'});
    });

    test('useOrElse fills holes', () async {
      final b = bind(PluckAll(
        ['id', 'city'],
        useOrElse: true,
        orElse: 'n/a',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'id': 1});
      await b.probe.settle();
      expect(
        (b.probe.payloads.single as Map)['id'],
        1,
      );
    });
  });

  group('PluckPath', () {
    test('walks a nested map', () async {
      final b = bind(PluckPath<String>(['user', 'name']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({
        'user': {'name': 'Ann'},
      });
      await b.probe.settle();
      expect(b.probe.payloads, ['Ann']);
    });

    test('broken path calls onError', () async {
      final errors = <Object>[];
      final b = bind(PluckPath<String>(
        ['user', 'name'],
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'user': 1});
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors, isNotEmpty);
    });

    test('useOrElse returns the default on a broken path', () async {
      final b = bind(PluckPath<String>(
        ['user', 'name'],
        orElse: 'n/a',
        useOrElse: true,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'user': 1});
      await b.probe.settle();
      expect(b.probe.payloads, ['n/a']);
    });
  });
}
