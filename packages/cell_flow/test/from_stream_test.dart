// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/from_stream.dart';
import 'package:test/test.dart';

class _Probe {
  final List<Object?> payloads = [];
  final List<String?> types = [];
  final List<String> steps = [];
  late final dynamic _obs;

  _Probe(Cell source) {
    _obs = Cell.observe(
      source: source,
      effect: (Pulse p) {
        payloads.add(p.payload);
        types.add(p.type);
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
  group('FromStream', () {
    test('emits every event after the arming pulse', () async {
      final b = bind(FromStream<int>(Stream.fromIterable([1, 2, 3])));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
      expect(b.probe.steps, contains('FromStream'));
    });

    test('a second arming pulse does not resubscribe', () async {
      final b = bind(FromStream<int>(Stream.fromIterable([1])));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });

    test('stream errors call onError and emit an error pulse', () async {
      final errors = <Object>[];
      final controller = StreamController<int>();
      final b = bind(FromStream<int>(
        controller.stream,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      addTearDown(controller.close);
      await b.gate.emitAsync(null);
      await Future<void>.delayed(Duration.zero);
      controller.addError(StateError('boom'));
      await b.probe.settle();
      expect(errors.single, isA<StateError>());
      expect(b.probe.types, contains('error'));
    });

    test('emitErrorPulse false only calls onError', () async {
      final errors = <Object>[];
      final controller = StreamController<int>();
      final b = bind(FromStream<int>(
        controller.stream,
        emitErrorPulse: false,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      addTearDown(controller.close);
      await b.gate.emitAsync(null);
      await Future<void>.delayed(Duration.zero);
      controller.addError(StateError('hidden'));
      await b.probe.settle();
      expect(errors.single, isA<StateError>());
      expect(b.probe.types, isNot(contains('error')));
    });
  });

  group('DeferStream', () {
    test('creates a new stream on every trigger', () async {
      var n = 0;
      final b = bind(DeferStream<int>(() {
        n++;
        return Stream.fromIterable([n]);
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('ConcatFromStream', () {
    test('plays streams in trigger order', () async {
      final b = bind(ConcatFromStream<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream.fromIterable([1, 2]));
      await b.gate.emitAsync(Stream.fromIterable([3]));
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
    });

    test('a slow first stream delays the second', () async {
      final first = StreamController<int>();
      final b = bind(ConcatFromStream<int>());
      addTearDown(b.probe.stop);
      addTearDown(first.close);
      await b.gate.emitAsync(first.stream);
      await b.gate.emitAsync(Stream.fromIterable([9]));
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      first.add(1);
      await first.close();
      await b.probe.settle();
      expect(b.probe.payloads, [1, 9]);
    });

    test('wrong payload types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ConcatFromStream<int>(
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await probe.settle();
      expect(probe.payloads, isNotEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('MergeFromStream', () {
    test('interleaves overlapping streams', () async {
      final a = StreamController<String>();
      final c = StreamController<String>();
      final b = bind(MergeFromStream<String>());
      addTearDown(b.probe.stop);
      addTearDown(a.close);
      addTearDown(c.close);
      await b.gate.emitAsync(a.stream);
      await b.gate.emitAsync(c.stream);
      a.add('a');
      c.add('c');
      await b.probe.settle();
      expect(b.probe.payloads, containsAll(['a', 'c']));
    });
  });

  group('SwitchFromStream', () {
    test('drops events from the previous stream', () async {
      final old = StreamController<String>();
      final b = bind(SwitchFromStream<String>());
      addTearDown(b.probe.stop);
      addTearDown(old.close);
      await b.gate.emitAsync(old.stream);
      await b.gate.emitAsync(Stream.fromIterable(['new']));
      old.add('stale');
      await b.probe.settle();
      expect(b.probe.payloads, ['new']);
    });
  });

  group('MapToStream', () {
    test('projects each value to a stream and concatenates', () async {
      final b = bind(MapToStream<String, String>(
        (s) => Stream.fromIterable(['$s-1', '$s-2']),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('x');
      await b.gate.emitAsync('y');
      await b.probe.settle();
      expect(b.probe.payloads, ['x-1', 'x-2', 'y-1', 'y-2']);
    });

    test('project exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(MapToStream<int, int>(
        (n) => throw StateError('proj'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(errors.single, isA<StateError>());
    });
  });

  group('edges', () {
    test('an empty stream emits nothing', () async {
      final b = bind(FromStream<int>(const Stream.empty()));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('single-subscription stream can only be armed once', () async {
      final b = bind(FromStream<int>(Stream.fromIterable([1])));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
    });
  });

  group('performance', () {
    test('FromStream emits 200 events', () async {
      final sw = Stopwatch()..start();
      final b = bind(FromStream<int>(Stream.fromIterable(List.generate(200, (i) => i))));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      sw.stop();
      expect(b.probe.payloads, hasLength(200));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
