// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/combine_latest.dart';
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
  group('CombineLatestWith', () {
    test('waits until every Cell has a value', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<String>();
      final out = CombineLatestWith<int, String>(
        [b.cell],
        (n, latest) => '$n-${latest.single}',
      ).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, isEmpty);
      await b.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, ['1-x']);
    });

    test('re-emits when the source or an other Cell updates', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<String>();
      final out = CombineLatestWith<int, String>(
        [b.cell],
        (n, latest) => '$n-${latest.single}',
      ).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await b.emitAsync('x');
      await a.emitAsync(2);
      await b.emitAsync('y');
      await probe.settle();
      expect(probe.payloads, ['1-x', '2-x', '2-y']);
    });

    test('combine exceptions call onError', () async {
      final errors = <Object>[];
      final a = Cell.ingress<int>();
      final b = Cell.ingress<String>();
      final out = CombineLatestWith<int, String>(
        [b.cell],
        (n, latest) {
          if (latest.single == 'bad') throw StateError('combine');
          return '$n-${latest.single}';
        },
        onError: (e, _) => errors.add(e),
      ).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync(1);
      await b.emitAsync('bad');
      await b.emitAsync('ok');
      await probe.settle();
      expect(probe.payloads, ['1-ok']);
      expect(errors.single, isA<StateError>());
    });
  });

  group('CombineLatest', () {
    test('arms on the gate and combines extra Cells only', () async {
      final gate = Cell.ingress<void>();
      final left = Cell.ingress<int>();
      final right = Cell.ingress<String>();
      final out = CombineLatest<String>(
        [left.cell, right.cell],
        (latest) => '${latest[0]}-${latest[1]}',
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(null);
      await left.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, isEmpty);
      await right.emitAsync('x');
      await left.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, ['1-x', '2-x']);
    });
  });

  group('WithLatestFrom', () {
    test('ignores other-Cell updates and pairs only source pulses', () async {
      final s = Cell.ingress<int>();
      final o = Cell.ingress<String>();
      final out = WithLatestFrom<int, String>(
        [o.cell],
        (n, latest) => '$n-${latest.single}',
      ).toHandle(source: s.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await s.emitAsync(1);
      await o.emitAsync('y');
      await o.emitAsync('z');
      await s.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, ['2-z']);
    });

    test('drops source pulses before others have a value', () async {
      final s = Cell.ingress<int>();
      final o = Cell.ingress<String>();
      final out = WithLatestFrom<int, String>(
        [o.cell],
        (n, latest) => '$n-${latest.single}',
      ).toHandle(source: s.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await s.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, isEmpty);
    });
  });

  group('CombineLatest2', () {
    test('types the pair as (A, B)', () async {
      final a = Cell.ingress<int>();
      final b = Cell.ingress<String>();
      final out = CombineLatest2<int, String, String>(
        b.cell,
        (n, s) => '$n:$s',
      ).toHandle(source: a.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await a.emitAsync(3);
      await b.emitAsync('ok');
      await probe.settle();
      expect(probe.payloads, ['3:ok']);
    });
  });
}
