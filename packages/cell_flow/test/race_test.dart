// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/race.dart';
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
  group('Race', () {
    test('emits the first future to complete', () async {
      final b = bind<void>(Race<String>([
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
        Future<String>.delayed(const Duration(milliseconds: 5), () => 'fast'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 70));
      expect(b.probe.payloads, ['fast']);
    });

    test('a raw value beats a delayed future', () async {
      final b = bind<void>(Race<String>([
        Future<String>.delayed(const Duration(milliseconds: 40), () => 'late'),
        'now',
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['now']);
    });

    test('starts only on the first trigger', () async {
      var launches = 0;
      final b = bind<void>(Race<int>([
        Future(() {
          launches++;
          return 1;
        }),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(launches, 1);
    });

    test('marks lineage with Race', () async {
      final b = bind<void>(Race<int>([1]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.steps, contains('Race'));
    });
  });

  group('RaceFirst', () {
    test('emits only the first value of the winning stream', () async {
      final b = bind<void>(RaceFirst<String>([
        Stream.fromIterable(['a', 'b', 'c']),
        Future<String>.delayed(const Duration(milliseconds: 30), () => 'late'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 50));
      expect(b.probe.payloads, ['a']);
    });

    test('a completed future beats a delayed stream', () async {
      final b = bind<void>(RaceFirst<String>([
        Stream<String>.fromFuture(
          Future<String>.delayed(const Duration(milliseconds: 40), () => 'tick'),
        ),
        Future<String>.value('ready'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, ['ready']);
    });
  });

  group('RaceMap', () {
    test('races competitors derived from the payload', () async {
      final b = bind<int>(RaceMap<int, String>((id) => [
            Future<String>.delayed(
              const Duration(milliseconds: 40),
              () => 'net-$id',
            ),
            Future<String>.value('cache'),
          ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(7);
      await b.probe.settle();
      expect(b.probe.payloads, ['cache']);
    });

    test('a later trigger invalidates an in-flight race', () async {
      final b = bind<String>(RaceMap<String, String>((q) => [
            Future<String>.delayed(
              Duration(milliseconds: q == 'old' ? 50 : 10),
              () => q,
            ),
          ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('old');
      await b.gate.emitAsync('new');
      await b.probe.settle(const Duration(milliseconds: 80));
      expect(b.probe.payloads, ['new']);
    });

    test('wrong payload types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = RaceMap<int, int>(
        (n) => [n],
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });

    test('mapper exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind<int>(RaceMap<int, int>(
        (n) => throw StateError('map'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('RaceWith', () {
    test('side competitor can win', () async {
      final b = bind<int>(RaceWith<int, String>(
        (n) => Future<String>.delayed(
          const Duration(milliseconds: 40),
          () => 'src-$n',
        ),
        other: () => Future<String>.value('side'),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle(const Duration(milliseconds: 20));
      expect(b.probe.payloads, ['side']);
    });

    test('mapped source can win', () async {
      final b = bind<int>(RaceWith<int, String>(
        (n) => Future<String>.value('src-$n'),
        other: () => Future<String>.delayed(
          const Duration(milliseconds: 40),
          () => 'side',
        ),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, ['src-3']);
    });
  });

  group('RaceUntil', () {
    test('emits the value when it beats the timeout', () async {
      final b = bind<void>(RaceUntil<void, String>(
        (_) => Future<String>.value('ok'),
        timeout: const Duration(milliseconds: 40),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok']);
    });

    test('emits a TimeoutException error pulse when the timer wins', () async {
      final errors = <Object>[];
      final b = bind<void>(RaceUntil<void, String>(
        (_) => Future<String>.delayed(
          const Duration(milliseconds: 80),
          () => 'late',
        ),
        timeout: const Duration(milliseconds: 15),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 40));
      expect(errors.whereType<TimeoutException>(), isNotEmpty);
      expect(b.probe.types, contains('error'));
    });

    test('swallows the error pulse when emitErrorPulse is false', () async {
      final errors = <Object>[];
      final b = bind<void>(RaceUntil<void, String>(
        (_) => Future<String>.delayed(
          const Duration(milliseconds: 50),
          () => 'late',
        ),
        timeout: const Duration(milliseconds: 10),
        emitErrorPulse: false,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.probe.settle(const Duration(milliseconds: 30));
      expect(errors.whereType<TimeoutException>(), isNotEmpty);
      expect(b.probe.payloads, isEmpty);
    });
  });
}
