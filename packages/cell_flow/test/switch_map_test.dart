// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/switch_map.dart';
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

  Future<void> settle([Duration d = const Duration(milliseconds: 30)]) =>
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
  group('SwitchMap', () {
    test('drops a stale inner when a new trigger arrives', () async {
      final b = bind(SwitchMap<String, String>((q) async* {
        await Future<void>.delayed(Duration(
          milliseconds: q == 'old' ? 40 : 8,
        ));
        yield '$q-1';
        yield '$q-2';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['new-1', 'new-2']);
    });

    test('emits the full inner when it is the only trigger', () async {
      final b = bind(SwitchMap<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = SwitchMap<int, int>(
        (n) => [n],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });

    test('mapper exceptions call onError only for the current generation',
        () async {
      final errors = <Object>[];
      final b = bind(SwitchMap<int, int>(
        (n) {
          if (n == 1) throw StateError('map-1');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });

    test('inner future errors call onError', () async {
      final errors = <Object>[];
      final pending = Completer<int>();
      final b = bind(SwitchMap<void, int>(
        (_) => pending.future,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await Future<void>.delayed(Duration.zero);
      pending.completeError(StateError('inner'));
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('stale inner errors are not reported', () async {
      final errors = <Object>[];
      final stale = Completer<int>();
      final b = bind(SwitchMap<String, int>(
        (q) => q == 'old' ? stale.future : Future.value(2),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await Future<void>.delayed(Duration.zero);
      stale.completeError(StateError('stale'));
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
      expect(errors, isEmpty);
    });
  });

  group('SwitchMapTo', () {
    test('cancels the previous inner of the same factory', () async {
      final b = bind(SwitchMapTo<void, String>(() async* {
        yield 'ping';
        await Future<void>.delayed(const Duration(milliseconds: 40));
        yield 'pong';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, ['ping']);
    });

    test('factory exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(SwitchMapTo<void, int>(
        () => throw FormatException('factory'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('SwitchLatest', () {
    test('switches away from a slow inner payload', () async {
      final b = bind(SwitchLatest<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream.fromFutures([
        Future.value('a'),
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'late'),
      ]));
      await b.gate.emitAsync(['b']);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, contains('b'));
      expect(b.probe.payloads, isNot(contains('late')));
    });

    test('inner stream errors call onError', () async {
      final errors = <Object>[];
      final b = bind(SwitchLatest<int>(
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream<int>.error(StateError('stream')));
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('SwitchMapState', () {
    test('records generation and last trigger on the snapshot', () async {
      final snap = SwitchMapSnapshot<String, String>();
      final b = bind(SwitchMapState<String, String>(
        (q, state) async => 'q=$q gen=${state.generation}',
        state: snap,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle();
      expect(snap.generation, 2);
      expect(snap.lastTrigger, 'new');
      expect(b.probe.payloads.last, 'q=new gen=2');
      expect(snap.lastValue, 'q=new gen=2');
    });

    test('mapper exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(SwitchMapState<int, int>(
        (n, _) => throw StateError('state-map'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types do not bump generation', () async {
      final errors = <Object>[];
      final snap = SwitchMapSnapshot<int, int>();
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = SwitchMapState<int, int>(
        (n, _) => n,
        state: snap,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await gate.emitAsync(1);
      await probe.settle();
      expect(snap.generation, 1);
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });
}
