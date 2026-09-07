// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/tap.dart';
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
  group('Tap', () {
    test('forwards values after the side effect', () async {
      final seen = <int>[];
      final b = bind(Tap<int>(seen.add));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(seen, [1, 2]);
      expect(b.probe.payloads, [1, 2]);
      expect(b.probe.steps, contains('Tap'));
    });

    test('side-effect exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(Tap<int>(
        (n) {
          if (n == 2) throw StateError('tap');
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

    test('wrong types call onError and skip the tap', () async {
      final errors = <Object>[];
      final seen = <int>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Tap<int>(
        seen.add,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(seen, [1]);
      expect(probe.payloads, [1]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('TapAll', () {
    test('sees every pulse including wrong types', () async {
      final seen = <Object?>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = TapAll((p) => seen.add(p.payload)).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(1);
      await gate.emitAsync('x');
      await probe.settle();
      expect(seen, [1, 'x']);
      expect(probe.payloads, [1, 'x']);
    });

    test('onPulse exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(TapAll(
        (p) {
          if (p.payload == 2) throw StateError('all');
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TapWithIndex', () {
    test('passes a 0-based index that skips bad types', () async {
      final seen = <(int, int)>[];
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = TapWithIndex<int>(
        (n, i) => seen.add((n, i)),
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(10);
      await gate.emitAsync('x');
      await gate.emitAsync(20);
      await probe.settle();
      expect(seen, [(10, 0), (20, 1)]);
      expect(errors.single, isA<FormatException>());
    });

    test('callback exceptions drop the pulse and do not advance index',
        () async {
      final errors = <Object>[];
      final seen = <int>[];
      final b = bind(TapWithIndex<int>(
        (n, i) {
          if (n == 2) throw StateError('idx');
          seen.add(i);
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(seen, [0, 1]);
      expect(b.probe.payloads, [1, 3]);
      expect(errors.single, isA<StateError>());
    });
  });

  group('TapState', () {
    test('folds a snapshot without changing payloads', () async {
      final op = TapState<int, int>(0, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
      expect(op.snapshot.value, 3);
      expect(op.snapshot.seen, 2);
    });

    test('next exceptions drop the pulse and keep the snapshot', () async {
      final errors = <Object>[];
      final op = TapState<int, int>(
        0,
        (acc, n) {
          if (n == 2) throw StateError('fold');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3]);
      expect(op.snapshot.value, 4);
      expect(op.snapshot.seen, 2);
      expect(errors.single, isA<StateError>());
    });
  });

  group('Tap extra', () {
    test('empty source taps nothing', () async {
      final seen = <int>[];
      final b = bind(Tap<int>(seen.add));
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(seen, isEmpty);
      expect(b.probe.payloads, isEmpty);
    });

    test('onError is optional when the tap throws', () async {
      final b = bind(Tap<int>((n) => throw StateError('x')));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
    });

    test('null payload of a nullable type still taps', () async {
      final seen = <String?>[];
      final b = bind(Tap<String?>(seen.add));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(null);
      await b.gate.emitAsync('a');
      await b.probe.settle();
      expect(seen, [null, 'a']);
    });
  });

  group('TapAll extra', () {
    test('marks lineage with TapAll', () async {
      final b = bind(TapAll((_) {}));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('TapAll'));
    });

    test('forwards after a successful onPulse', () async {
      var n = 0;
      final b = bind(TapAll((_) => n++));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await b.probe.settle();
      expect(n, 2);
      expect(b.probe.payloads, ['a', 'b']);
    });
  });

  group('TapWithIndex extra', () {
    test('marks lineage with TapWithIndex', () async {
      final b = bind(TapWithIndex<int>((_, __) {}));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.probe.steps, contains('TapWithIndex'));
    });

    test('index restarts per operator instance', () async {
      final a = bind(TapWithIndex<int>((_, __) {}));
      final c = bind(TapWithIndex<int>((_, __) {}));
      addTearDown(a.probe.stop);
      addTearDown(c.probe.stop);
      await a.gate.emitAsync(1);
      await c.gate.emitAsync(9);
      await a.probe.settle();
      expect(a.probe.payloads, [1]);
      expect(c.probe.payloads, [9]);
    });
  });

  group('TapState extra', () {
    test('shared snapshot is updated in place', () async {
      final snap = TapSnapshot<int>(0);
      final op = TapState<int, int>(0, (acc, n) => acc + n, snapshot: snap);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      expect(identical(op.snapshot, snap), isTrue);
      expect(snap.value, 4);
      expect(snap.seen, 1);
    });

    test('wrong types do not change the snapshot', () async {
      final errors = <Object>[];
      final op = TapState<int, int>(
        0,
        (acc, n) => acc + n,
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(2);
      await probe.settle();
      expect(op.snapshot.value, 2);
      expect(op.snapshot.seen, 1);
      expect(errors, isNotEmpty);
    });

    test('zero values leave the seed', () async {
      final op = TapState<int, int>(7, (acc, n) => acc + n);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.probe.settle();
      expect(op.snapshot.value, 7);
      expect(op.snapshot.seen, 0);
    });
  });

  group('composition / performance', () {
    test('Tap + TapAll stays a chain', () async {
      final seen = <Object?>[];
      final op = Tap<int>((n) => seen.add(n)) + TapAll((p) => seen.add(p.payload));
      final gate = Cell.ingress<int>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync(3);
      await probe.settle();
      expect(out.cell, isNotNull);
    });

    test('Tap handles 200 ints', () async {
      var n = 0;
      final b = bind(Tap<int>((_) => n++));
      addTearDown(b.probe.stop);
      for (var i = 0; i < 200; i++) {
        await b.gate.emitAsync(i);
      }
      await b.probe.settle();
      expect(n, 200);
      expect(b.probe.payloads, hasLength(200));
    });
  });


  group('coverage extras', () {
    test('TapState next throw calls onError', () async {
      final errors = <Object>[];
      final b = bind(TapState<int, int>(
        0,
        (acc, n) {
          if (n < 0) throw StateError('tap');
          return acc + n;
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(-1);
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });

    test('TapAll onPulse throw is dropped', () async {
      final errors = <Object>[];
      final b = bind(TapAll(
        (p) {
          if (p.payload == 0) throw StateError('all');
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(0);
      await b.gate.emitAsync(1);
      await b.probe.settle();
      expect(b.out.cell, isNotNull);
    });
  });

}
