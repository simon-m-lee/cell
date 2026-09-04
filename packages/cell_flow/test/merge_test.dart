// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/merge.dart';
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

void main() {
  group('MergeWith', () {
    test('forwards the source and pulses from others after arming', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final out = MergeWith<int>([b.cell]).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync(0);
      await a.emitAsync(1);
      await b.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [0, 1, 2]);
      expect(probe.steps, containsAll(['MergeWith.source', 'MergeWith.other']));
    });

    test('pulses on others before arming are not forwarded', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<int>();
      final out = MergeWith<int>([b.cell]).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await b.emitAsync(9);
      await a.emitAsync(1);
      await b.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [1, 2]);
    });

    test('wrong types on the source call onError', () async {
      final errors = <Object>[];
      final a = Cell.ingress<Object>();
      final b = Cell.ingress<int>();
      final out = MergeWith<int>(
        [b.cell],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync('bad');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('Merge', () {
    test('does not forward the arming pulse', () async {
      final gate = Cell.ingress<void>();
      final left = Cell.ingress<int>();
      final right = Cell.ingress<int>();
      final out =
          Merge<int>([left.cell, right.cell]).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(null);
      await left.emitAsync(10);
      await right.emitAsync(20);
      await probe.settle();
      expect(probe.payloads, [10, 20]);
    });

    test('forwardSource keeps the arming pulse when it matches S', () async {
      final gate = Cell.ingress<int>();
      final other = Cell.ingress<int>();
      final out = Merge<int>(
        [other.cell],
        forwardSource: true,
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await other.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [1, 2]);
    });
  });

  group('MergeAll', () {
    test('flattens list payloads concurrently', () async {
      final gate = Cell.ingress<Object>();
      final out = MergeAll<String>().toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(['a', 'b']);
      await gate.emitAsync(['x']);
      await probe.settle();
      expect(probe.payloads, ['a', 'b', 'x']);
    });

    test('overlapping delayed streams can interleave', () async {
      final gate = Cell.ingress<Object>();
      final out = MergeAll<String>().toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(Stream.fromFutures([
        Future.value('slow-a'),
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow-b'),
      ]));
      await gate.emitAsync(Stream.fromFutures([
        Future.value('fast'),
      ]));
      await probe.settle(const Duration(milliseconds: 70));
      expect(probe.payloads, containsAll(['slow-a', 'fast', 'slow-b']));
      expect(probe.payloads.indexOf('fast'), lessThan(probe.payloads.indexOf('slow-b')));
    });

    test('inner exceptions call onError', () async {
      final errors = <Object>[];
      final gate = Cell.ingress<Object>();
      final out = MergeAll<int>(
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      final pending = Completer<int>();
      await gate.emitAsync(pending.future);
      pending.completeError(StateError('boom'));
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });
}
