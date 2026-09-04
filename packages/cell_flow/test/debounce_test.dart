// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/debounce.dart';
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
  group('Debounce', () {
    test('emits only the last value after silence', () async {
      final b = bind(Debounce<String>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('h');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await b.gate.emitAsync('he');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await b.gate.emitAsync('hello');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['hello']);
    });

    test('separate bursts each emit', () async {
      final b = bind(Debounce<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [1, 2]);
    });

    test('emits nothing if silence never arrives before teardown wait is short',
        () async {
      final b = bind(Debounce<int>(const Duration(milliseconds: 80)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, isEmpty);
    });

    test('marks lineage with Debounce', () async {
      final b = bind(Debounce<int>(const Duration(milliseconds: 20)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(7);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(b.probe.steps, contains('Debounce'));
    });

    test('wrong payload types call onError and emit nothing', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Debounce<int>(
        const Duration(milliseconds: 20),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('DebounceLeading', () {
    test('emits first immediately then last after silence', () async {
      final b = bind(DebounceLeading<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1, 3]);
    });

    test('a lone pulse emits only the leading value', () async {
      final b = bind(DebounceLeading<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [9]);
    });

    test('a new burst after silence leads again', () async {
      final b = bind(DebounceLeading<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('DebounceLeadingOnly', () {
    test('emits only the first value of a burst', () async {
      final b = bind(DebounceLeadingOnly<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.probe.payloads, [1]);
    });

    test('admits a new leading value after the window closes', () async {
      final b = bind(DebounceLeadingOnly<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('DebounceWith', () {
    test('uses the latest value duration and cancels the previous timer',
        () async {
      final b = bind(DebounceWith<String>(
        (s) => Duration(milliseconds: s == 'wait' ? 80 : 20),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('wait');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await b.gate.emitAsync('go');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.probe.payloads, ['go']);
    });

    test('emits the long-wait value when it is left alone', () async {
      final b = bind(DebounceWith<String>(
        (s) => Duration(milliseconds: s == 'wait' ? 40 : 80),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('wait');
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['wait']);
    });

    test('durationOf exceptions call onError and drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(DebounceWith<int>(
        (n) {
          if (n == 1) throw StateError('bad duration');
          return const Duration(milliseconds: 10);
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('AuditTime', () {
    test('emits the last value when the window opened by the first pulse closes',
        () async {
      final b = bind(AuditTime<int>(const Duration(milliseconds: 50)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await b.gate.emitAsync(3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.probe.payloads, [3]);
    });

    test('opens a new window after the previous one emits', () async {
      final b = bind(AuditTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('SampleTime', () {
    test('emits the last value seen in the period', () async {
      final b = bind(SampleTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.probe.payloads, [2]);
    });

    test('does not emit on a tick with no new value', () async {
      final b = bind(SampleTime<int>(const Duration(milliseconds: 30)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      final afterFirst = List<Object?>.from(b.probe.payloads);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(b.probe.payloads, afterFirst);
    });
  });
}
