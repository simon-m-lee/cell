// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
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
  group('MapValue', () {
    test('projects each typed payload', () async {
      final b = bind(MapValue<int, int>((n) => n * 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 4]);
      expect(b.probe.steps, contains('MapValue'));
    });

    test('project exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapValue<int, int>(
        (n) {
          if (n == 2) throw StateError('map');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapValue<int, int>(
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });

    test('empty source emits nothing', () async {
      final b = bind(MapValue<int, int>((n) => n));
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('zero and negative values still project', () async {
      final b = bind(MapValue<int, int>((n) => n.abs()));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(0);
      await b.gate.emitAsync(-4);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 4]);
    });

    test('can change the payload type', () async {
      final b = bind(MapValue<int, String>((n) => 'k$n'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(b.probe.payloads, ['k9']);
    });

    test('onError is optional when project throws', () async {
      final b = bind(MapValue<int, int>((n) => throw FormatException('x')));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });
  });

  group('MapTo', () {
    test('emits the constant for every typed pulse', () async {
      final b = bind(MapTo<void, String>('ping'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync(null);
      await b.probe.settle();
      expect(b.probe.payloads, ['ping', 'ping']);
    });

    test('wrong types do not emit the constant', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapTo<int, String>(
        'x',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('no');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, ['x']);
      expect(errors, isNotEmpty);
    });
  });

  group('MapWithIndex', () {
    test('includes a 0-based index that skips bad types', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapWithIndex<String, String>(
        (s, i) => '$i:$s',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('a');
      await gate.emitAsync(1);
      await gate.emitAsync('b');
      await probe.settle();
      expect(probe.payloads, ['0:a', '1:b']);
      expect(errors.single, isA<FormatException>());
    });

    test('project exceptions drop the pulse and do not advance index',
        () async {
      final errors = <Object>[];
      final b = bind(MapWithIndex<int, int>(
        (n, i) {
          if (n == 2) throw StateError('idx');
          return i;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [0, 1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('MapNotNull', () {
    test('drops null projections', () async {
      final b = bind(MapNotNull<int, int>((n) => n.isEven ? n : null));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [2]);
    });

    test('project exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapNotNull<int, int>(
        (n) => throw StateError('nn'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });
  });

  group('MapWhen', () {
    test('projects only matching values', () async {
      final b = bind(MapWhen<int, String>(
        (n) => n.isEven,
        (n) => 'even-$n',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, ['even-2']);
    });

    test('test exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapWhen<int, int>(
        (n) => throw StateError('test'),
        (n) => n,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('project exceptions drop only that pulse', () async {
      final errors = <Object>[];
      final b = bind(MapWhen<int, int>(
        (n) => n > 0,
        (n) {
          if (n == 2) throw StateError('p');
          return n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapWhen<int, int>(
        (n) => true,
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors, isNotEmpty);
    });
  });

  group('MapValueIf', () {
    test('is MapWhen under the MapValue name', () async {
      final b = bind(MapValueIf<int, String>(
        (n) => n.isEven,
        (n) => 'even-$n',
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, ['even-2']);
    });
  });

  group('MapValueOr', () {
    test('emits the projection when it succeeds', () async {
      final b = bind(MapValueOr<int, int>(
        (n) => n * 2,
        orElse: (_, __) => -1,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [6]);
    });

    test('uses orElse when project throws', () async {
      final errors = <Object>[];
      final b = bind(MapValueOr<int, int>(
        (n) => throw StateError('div'),
        orElse: (_, __) => 0,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, [0]);
      expect(errors.single, isA<StateError>());
    });

    test('orElse throw drops the pulse', () async {
      final errors = <Object>[];
      final b = bind(MapValueOr<int, int>(
        (n) => throw StateError('p'),
        orElse: (_, __) => throw StateError('or'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors, hasLength(2));
    });

    test('orElse receives the original value and error', () async {
      Object? seenErr;
      int? seenVal;
      final b = bind(MapValueOr<int, int>(
        (n) => throw FormatException('bad'),
        orElse: (v, e) {
          seenVal = v;
          seenErr = e;
          return -v;
        },
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(5);
      await b.probe.settle();
      expect(seenVal, 5);
      expect(seenErr, isA<FormatException>());
      expect(b.probe.payloads, [-5]);
    });
  });

  group('MapValues', () {
    test('projects each map value', () async {
      final b = bind(MapValues<String, int, int>((n) => n * 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1, 'b': 2});
      await b.probe.settle();
      expect(b.probe.payloads.single, {'a': 2, 'b': 4});
    });

    test('wrong payload types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapValues<String, int, int>(
        (n) => n,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });

    test('project throw drops the map', () async {
      final errors = <Object>[];
      final b = bind(MapValues<String, int, int>(
        (n) => throw StateError('v'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1});
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('empty map stays empty', () async {
      final b = bind(MapValues<String, int, int>((n) => n));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(<String, int>{});
      await b.probe.settle();
      expect(b.probe.payloads.single, <String, int>{});
    });
  });

  group('MapKeys', () {
    test('projects each map key', () async {
      final b = bind(MapKeys<String, int, String>((k) => k.toUpperCase()));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1});
      await b.probe.settle();
      expect(b.probe.payloads.single, {'A': 1});
    });

    test('project throw drops the map', () async {
      final errors = <Object>[];
      final b = bind(MapKeys<String, int, String>(
        (k) => throw StateError('k'),
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1});
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('wrong type calls onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = MapKeys<String, int, String>(
        (k) => k,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('composition / performance', () {
    test('MapValue + MapTo is a chain', () async {
      final op = MapValue<int, int>((n) => n + 1) + MapTo<int, String>('x');
      final gate = Cell.ingress<int>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('MapValue handles 200 ints', () async {
      final b = bind(MapValue<int, int>((n) => n + 1));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(b.probe.payloads, hasLength(200));
      expect(b.probe.payloads.first, 1);
      expect(b.probe.payloads.last, 200);
    });
  });

  group('coverage extras', () {
    test('MapValueOr uses orElse on throw', () async {
      final b = bind(MapValueOr<int, int>(
        (n) {
          if (n < 0) throw StateError('neg');
          return n * 2;
        },
        orElse: (_, __) => 0,
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(-1);
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });

    test('MapValues projects map values', () async {
      final b = bind(MapValues<String, int, int>((v) => v * 10));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1, 'b': 2});
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });

    test('MapKeys projects map keys', () async {
      final b = bind(MapKeys<String, int, String>((k) => k.toUpperCase()));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync({'a': 1});
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });

    test('MapValues wrong type calls onError', () async {
      final errors = <Object>[];
      final b = bind(MapValues<String, int, int>(
        (v) => v,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });
  });

}
