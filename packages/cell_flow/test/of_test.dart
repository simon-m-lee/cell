// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/of.dart';
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
  group('Of', () {
    test('emits the values once', () async {
      final b = bind(Of<String>(['a', 'b']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b']);
      expect(b.probe.steps, contains('Of'));
    });

    test('ignores a second arming pulse', () async {
      final b = bind(Of<int>([1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });
  });

  group('FromIterable', () {
    test('emits each element', () async {
      final b = bind(FromIterable<int>([1, 2, 3]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('iterator exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(FromIterable<int>(
        _ThrowingIterable(),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(errors.single, isA<StateError>());
    });
  });

  group('Range', () {
    test('emits start for count steps', () async {
      final b = bind(Range(3, 3));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [3, 4, 5]);
    });

    test('honours step', () async {
      final b = bind(Range(0, 3, step: 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 2, 4]);
    });

    test('count 0 emits nothing', () async {
      final b = bind(Range(0, 0));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('Repeat', () {
    test('emits the value count times', () async {
      final b = bind(Repeat<String>('x', count: 3));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['x', 'x', 'x']);
    });
  });

  group('edges', () {
    test('Of of an empty list is silent', () async {
      final b = bind(Of<int>(const []));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('performance', () {
    test('Range emits 300 values', () async {
      final sw = Stopwatch()..start();
      final b = bind(Range(0, 300));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(300));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}

class _ThrowingIterable extends Iterable<int> {
  @override
  Iterator<int> get iterator => _ThrowingIterator();
}

class _ThrowingIterator implements Iterator<int> {
  @override
  int get current => 0;

  @override
  bool moveNext() => throw StateError('iter');
}
