// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/skip.dart';
import 'package:test/test.dart' hide Skip;

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
  group('Skip', () {
    test('drops the first n values', () async {
      final b = bind(Skip<int>(2));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [3, 4]);
    });

    test('wrong types do not consume the quota', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = Skip<int>(
        1,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('nope');
      await gate.emitAsync(1);
      await gate.emitAsync(2);
      await probe.settle();
      expect(probe.payloads, [2]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('SkipWhile', () {
    test('drops a prefix then forwards the rest', () async {
      final b = bind(SkipWhile<int>((n) => n < 3));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [3, 4]);
    });

    test('stays closed after the first failure even if later values match',
        () async {
      final b = bind(SkipWhile<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      for (final n in [2, 4, 5, 6]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [5, 6]);
    });
  });

  group('SkipUntil', () {
    test('opens when the notifier emits', () async {
      final start = Cell.ingress<void>();
      final b = bind(SkipUntil<String>(start.cell));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('b');
      await start.emitAsync(null);
      await b.gate.emitAsync('c');
      await b.probe.settle();
      expect(b.probe.payloads, ['c']);
    });
  });

  group('SkipUntilTime', () {
    test('drops until the window opens', () async {
      final b = bind(SkipUntilTime<int>(const Duration(milliseconds: 40)));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [3]);
    });
  });

  group('SkipFirst', () {
    test('drops only the first value', () async {
      final b = bind(SkipFirst<int>());
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [2, 3]);
    });
  });

  group('SkipLast', () {
    test('emits values that have left the trailing buffer', () async {
      final b = bind(SkipLast<int>(2));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });

    test('SkipLast(0) is a pass-through', () async {
      final b = bind(SkipLast<int>(0));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2]);
    });
  });

  group('SkipRepeated', () {
    test('drops consecutive duplicates', () async {
      final b = bind(SkipRepeated<int>());
      addTearDown(b.probe.stop);
      for (final n in [1, 1, 2, 2, 1]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 2, 1]);
    });

    test('uses a custom equals', () async {
      final b = bind(SkipRepeated<String>(
        equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('A');
      await b.gate.emitAsync('a');
      await b.gate.emitAsync('B');
      await b.probe.settle();
      expect(b.probe.payloads, ['A', 'B']);
    });
  });

  group('SkipWhen', () {
    test('drops every matching value, not only a prefix', () async {
      final b = bind(SkipWhen<int>((n) => n.isEven));
      addTearDown(b.probe.stop);
      for (final n in [1, 2, 3, 4, 5]) {
        await b.gate.emitAsync(n);
      }
      await b.probe.settle();
      expect(b.probe.payloads, [1, 3, 5]);
    });

    test('predicate exceptions drop the pulse', () async {
      final errors = <Object>[];
      final b = bind(SkipWhen<int>(
        (n) {
          if (n == 2) throw StateError('x');
          return false;
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
  });
}
