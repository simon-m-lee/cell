// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/share.dart';
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
  group('Share', () {
    test('passes values through and counts them', () async {
      final op = Share<int>();
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
      expect(op.seen, 2);
      expect(b.probe.steps, contains('Share'));
    });

    test('wrong types call onError and do not increment seen', () async {
      final errors = <Object>[];
      final op = Share<int>(onError: (e, _) => errors.add(e));
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [1]);
      expect(op.seen, 1);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ShareLatest', () {
    test('keeps the last value', () async {
      final op = ShareLatest<String>();
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b']);
      expect(op.buffer.latest, 'b');
      expect(op.buffer.values, ['b']);
    });

    test('wrong types do not overwrite latest', () async {
      final errors = <Object>[];
      final op = ShareLatest<int>(onError: (e, _) => errors.add(e));
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('x');
      await probe.settle();
      expect(op.buffer.latest, 1);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('ShareReplay', () {
    test('keeps a sliding window', () async {
      final op = ShareReplay<int>(size: 2);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 3]);
      expect(op.buffer.values, [2, 3]);
      expect(op.buffer.seen, 3);
    });

    test('shares a buffer instance', () async {
      final buf = ShareBuffer<int>(size: 2);
      final op = ShareReplay<int>(buffer: buf);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(buf.values, [9]);
    });
  });

  group('ShareReplayStart', () {
    test('replays the buffer then the live value', () async {
      final buf = ShareBuffer<int>(size: 2)
        ..push(2)
        ..push(3);
      final b = bind(ShareReplayStart<int>(buf));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 3, 4]);
      expect(buf.values, [3, 4]);
    });

    test('includeCurrent false replays only the buffer', () async {
      final buf = ShareBuffer<int>(size: 2)..push(1);
      final b = bind(ShareReplayStart<int>(buf, includeCurrent: false));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(buf.values, [1, 2]);
    });

    test('wrong types call onError and do not replay', () async {
      final errors = <Object>[];
      final buf = ShareBuffer<int>(size: 2)..push(1);
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ShareReplayStart<int>(
        buf,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [1, 2]);
      expect(errors.single, isA<FormatException>());
    });
  });
}
