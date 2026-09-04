// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/start_with.dart';
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
  group('StartWith', () {
    test('emits the seed then the source payloads', () async {
      final b = bind(StartWith<String>('seed'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, ['seed', 'a', 'b']);
      expect(b.probe.steps, containsAll(['StartWith.seed', 'StartWith']));
    });

    test('replaceFirst swaps the first payload for the seed', () async {
      final b = bind(StartWith<String>('seed', replaceFirst: true));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, ['seed', 'b']);
    });

    test('wrong types call onError and do not consume first', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = StartWith<String>(
        'seed',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('a');
      await probe.settle();
      expect(probe.payloads, ['seed', 'a']);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('StartWithValue', () {
    test('is an alias of StartWith', () async {
      final b = bind(StartWithValue<int>(0));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 1]);
    });
  });

  group('StartWithMany', () {
    test('emits every seed then the source', () async {
      final b = bind(StartWithMany<String>(['x', 'y']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('z');
      await b.probe.settle();
      expect(b.probe.payloads, ['x', 'y', 'z']);
      expect(b.probe.steps, containsAll(['StartWithMany.seed', 'StartWithMany']));
    });

    test('replaceFirst drops the first source payload', () async {
      final b = bind(StartWithMany<int>([0, 1], replaceFirst: true));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 1, 2]);
    });

    test('an empty prefix is a pass-through after first pulse', () async {
      final b = bind(StartWithMany<int>([]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types call onError and do not emit the prefix', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = StartWithMany<String>(
        ['x'],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('z');
      await probe.settle();
      expect(probe.payloads, ['x', 'z']);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('StartWithFactory', () {
    test('builds the prefix from the first payload', () async {
      final b = bind(StartWithFactory<String>((first) => ['pre-$first']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('hi');
      await b.probe.settle();
      expect(b.probe.payloads, ['pre-hi', 'hi']);
    });

    test('seedOf exceptions call onError and drop the first pulse', () async {
      final errors = <Object>[];
      final b = bind(StartWithFactory<int>(
        (first) => throw StateError('seed'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });
  });
}
