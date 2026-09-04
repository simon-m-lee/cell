// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/exhaust_map.dart';
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
  group('ExhaustMap', () {
    test('drops triggers while an inner is running', () async {
      final b = bind(ExhaustMap<int, String>((n) async* {
        yield '$n-a';
        await Future<void>.delayed(const Duration(milliseconds: 40));
        yield '$n-b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['1-a', '1-b']);
    });

    test('admits a new trigger after the previous inner finishes', () async {
      final b = bind(ExhaustMap<int, int>((n) async {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        return n;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(b.probe.payloads, [1, 2]);
    });

    test('flattens an Iterable when admitted', () async {
      final b = bind(ExhaustMap<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('wrong types call onError and do not occupy the slot', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ExhaustMap<int, int>(
        (n) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return n;
        },
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(4);
      await probe.settle(const Duration(milliseconds: 50));
      expect(probe.payloads, [4]);
      expect(errors.single, isA<FormatException>());
    });

    test('mapper exceptions release the busy latch', () async {
      final errors = <Object>[];
      var calls = 0;
      final b = bind(ExhaustMap<int, int>(
        (n) {
          calls++;
          if (n == 1) throw StateError('fail');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(calls, 2);
      expect(b.probe.payloads, [2]);
      expect(errors.single, isA<StateError>());
    });

    test('marks lineage with ExhaustMap', () async {
      final b = bind(ExhaustMap<int, int>((n) => n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('ExhaustMap'));
    });
  });

  group('ExhaustMapTo', () {
    test('ignores the payload and drops a second click while running', () async {
      final b = bind(ExhaustMapTo<int, String>(() async* {
        yield 'ping';
        await Future<void>.delayed(const Duration(milliseconds: 30));
        yield 'pong';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 60));
      expect(b.probe.payloads, ['ping', 'pong']);
    });

    test('runs again after the inner completes', () async {
      final b = bind(ExhaustMapTo<void, String>(() => ['x']));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['x', 'x']);
    });
  });

  group('ExhaustAll', () {
    test('flattens a synchronous list before the next emitAsync', () async {
      // Iterable drain is synchronous, so the busy latch is already
      // released by the time the awaited emitAsync of ['a','b'] returns.
      final b = bind(ExhaustAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(['a', 'b']);
      await b.gate.emitAsync(['c']);
      await b.probe.settle();
      expect(b.probe.payloads, ['a', 'b', 'c']);
    });

    test('ignores a payload that arrives while a Stream is still draining',
        () async {
      final b = bind(ExhaustAll<String>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Stream<String>.fromFutures([
        Future.value('a'),
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'b'),
      ]));
      await b.gate.emitAsync(['c']);
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['a', 'b']);
    });

    test('flattens a Future payload', () async {
      final b = bind(ExhaustAll<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(Future.value(7));
      await b.probe.settle();
      expect(b.probe.payloads, [7]);
    });
  });

  group('ExhaustMapFirst', () {
    test('emits only the first inner item of the admitted trigger', () async {
      final b = bind(ExhaustMapFirst<int, String>((n) async* {
        yield '$n-a';
        await Future<void>.delayed(const Duration(milliseconds: 20));
        yield '$n-b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, ['1-a']);
    });

    test('still holds the busy latch until the inner finishes', () async {
      var started = 0;
      final b = bind(ExhaustMapFirst<int, int>((n) async* {
        started++;
        yield n;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        yield n + 10;
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(started, 1);
      expect(b.probe.payloads, [1]);
    });
  });

  group('ExhaustMapLatest', () {
    test('runs the last skipped trigger after the current inner ends', () async {
      final b = bind(ExhaustMapLatest<int, String>((n) async* {
        yield '$n-a';
        await Future<void>.delayed(const Duration(milliseconds: 30));
        yield '$n-b';
      }));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle(const Duration(milliseconds: 100));
      expect(b.probe.payloads, ['1-a', '1-b', '3-a', '3-b']);
    });

    test('with a single trigger behaves like ExhaustMap', () async {
      final b = bind(ExhaustMapLatest<int, int>((n) => [n, n + 1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(5);
      await b.probe.settle();
      expect(b.probe.payloads, [5, 6]);
    });

    test('wrong types do not replace a pending latest value', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = ExhaustMapLatest<int, String>(
        (n) async* {
          yield '$n';
          await Future<void>.delayed(const Duration(milliseconds: 30));
        },
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('bad');
      await gate.emitAsync(9);
      await probe.settle(const Duration(milliseconds: 90));
      expect(probe.payloads, ['1', '9']);
      expect(errors.single, isA<FormatException>());
    });
  });
}
