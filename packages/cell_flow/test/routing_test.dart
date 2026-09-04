// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/routing.dart';
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
  group('Iif', () {
    test('uses thenMap when the predicate is true', () async {
      final b = bind(Iif<int, String>(
        (c) => c < 400,
        thenMap: (c) => 'ok-$c',
        elseMap: (c) => 'err-$c',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(200);
      await b.probe.settle();
      expect(b.probe.payloads, ['ok-200']);
      expect(b.probe.steps, contains('Iif.then'));
    });

    test('uses elseMap when the predicate is false', () async {
      final b = bind(Iif<int, String>(
        (c) => c < 400,
        thenMap: (c) => 'ok-$c',
        elseMap: (c) => 'err-$c',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(404);
      await b.probe.settle();
      expect(b.probe.payloads, ['err-404']);
      expect(b.probe.steps, contains('Iif.else'));
    });

    test('predicate exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(Iif<int, String>(
        (c) => throw StateError('pred'),
        thenMap: (c) => 'ok',
        elseMap: (c) => 'err',
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types are dropped', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Iif<int, String>(
        (c) => c < 400,
        thenMap: (c) => 'ok',
        elseMap: (c) => 'err',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('RouteWhen', () {
    test('uses the first matching case', () async {
      final b = bind(RouteWhen<int, String>([
        RouteCase((n) => n < 10, (_) => 'small'),
        RouteCase((n) => n < 100, (_) => 'mid'),
      ], orElse: (_) => 'big'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(40);
      await b.gate.emitAsync(400);
      await b.probe.settle();
      expect(b.probe.payloads, ['small', 'mid', 'big']);
      expect(b.probe.steps, containsAll(['RouteWhen.0', 'RouteWhen.1', 'RouteWhen.else']));
    });

    test('drops the pulse when nothing matches and orElse is omitted', () async {
      final b = bind(RouteWhen<int, String>([
        RouteCase((n) => n.isEven, (n) => 'even'),
      ]));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, ['even']);
    });

    test('case exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(RouteWhen<int, String>(
        [RouteCase((n) => throw FormatException('when'), (_) => 'x')],
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('RouteByKey', () {
    test('dispatches through the handler table', () async {
      final b = bind(RouteByKey<({String method, String path}), String, String>(
        (r) => r.method,
        routes: {
          'GET': (r) => 'GET ${r.path}',
          'POST': (r) => 'POST ${r.path}',
        },
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync((method: 'GET', path: '/users'));
      await b.gate.emitAsync((method: 'POST', path: '/users'));
      await b.probe.settle();
      expect(b.probe.payloads, ['GET /users', 'POST /users']);
    });

    test('orElse handles an unknown key', () async {
      final b = bind(RouteByKey<String, String, String>(
        (s) => s,
        routes: {'a': (s) => 'hit-$s'},
        orElse: (s) => 'miss-$s',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('z');
      await b.probe.settle();
      expect(b.probe.payloads, ['hit-a', 'miss-z']);
      expect(b.probe.steps, contains('RouteByKey.else'));
    });

    test('unknown keys are dropped when orElse is omitted', () async {
      final b = bind(RouteByKey<String, String, String>(
        (s) => s,
        routes: {'a': (s) => 'hit'},
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('z');
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('keyOf exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(RouteByKey<int, int, int>(
        (n) => throw StateError('key'),
        routes: {1: (n) => n},
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('PartitionTag', () {
    test('tags each value with the predicate result', () async {
      final b = bind(PartitionTag<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [
        (matched: true, value: 2),
        (matched: false, value: 3),
      ]);
      expect(b.probe.steps, containsAll(['PartitionTag.then', 'PartitionTag.else']));
    });

    test('predicate exceptions call onError', () async {
      final errors = <Object>[];
      final b = bind(PartitionTag<int>(
        (n) => throw StateError('tag'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });
}
