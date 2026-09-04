// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/group_by.dart';
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
  group('Grouped', () {
    test('equality is by key and value', () {
      expect(const Grouped('odd', 1), const Grouped('odd', 1));
      expect(const Grouped('odd', 1), isNot(const Grouped('even', 1)));
    });
  });

  group('GroupBy', () {
    test('tags each value with its key', () async {
      final b = bind(GroupBy<int, String>((n) => n.isEven ? 'even' : 'odd'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [
        const Grouped('odd', 1),
        const Grouped('even', 2),
        const Grouped('odd', 3),
      ]);
      expect(b.probe.steps, contains('GroupBy'));
    });

    test('keyOf exceptions drop the pulse and keep going', () async {
      final errors = <Object>[];
      final b = bind(GroupBy<int, String>(
        (n) {
          if (n == 2) throw StateError('key');
          return n.isEven ? 'even' : 'odd';
        },
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(b.probe.payloads, [
        const Grouped('odd', 1),
        const Grouped('odd', 3),
      ]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError and do not emit', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = GroupBy<int, String>(
        (n) => 'n',
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await gate.emitAsync(1);
      await probe.settle();
      expect(probe.payloads, [const Grouped('n', 1)]);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('GroupCollect', () {
    test('builds a running map after every pulse', () async {
      final op = GroupCollect<int, String>((n) => n.isEven ? 'even' : 'odd');
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(op.groups['odd'], [1, 3]);
      expect(op.groups['even'], [2]);
      expect(b.probe.payloads, hasLength(3));
      expect((b.probe.payloads.first as Map)['odd'], [1]);
      expect((b.probe.payloads.last as Map)['odd'], [1, 3]);
      expect(b.probe.steps, contains('GroupCollect'));
    });

    test('emitted maps are copies so later pulses do not mutate them', () async {
      final b = bind(GroupCollect<int, String>((n) => 'g'));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      final first = b.probe.payloads.first as Map;
      await b.gate.emitAsync(2);
      await b.probe.settle();
      expect(first['g'], [1]);
    });

    test('reuses a caller-supplied groups map', () async {
      final shared = <String, List<int>>{};
      final op = GroupCollect<int, String>((n) => 'g', groups: shared);
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(9);
      await b.probe.settle();
      expect(shared['g'], [9]);
      expect(identical(op.groups, shared), isTrue);
    });

    test('keyOf exceptions do not insert a group', () async {
      final errors = <Object>[];
      final op = GroupCollect<int, String>(
        (n) {
          if (n == 2) throw StateError('collect');
          return 'odd';
        },
        onError: (e, _) => errors.add(e),
      );
      final b = bind(op);
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      expect(op.groups.keys, ['odd']);
      expect(op.groups['odd'], [1, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError and leave groups empty', () async {
      final errors = <Object>[];
      final op = GroupCollect<int, String>(
        (n) => 'g',
        onError: (e, _) => errors.add(e),
      );
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = op.toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('bad');
      await probe.settle();
      expect(op.groups, isEmpty);
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });

  group('GroupByCount', () {
    test('emits a group only when it reaches size', () async {
      final b = bind(GroupByCount<String, String>((s) => s[0], 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a1');
      await b.gate.emitAsync('b1');
      await b.probe.settle();
      expect(b.probe.payloads, isEmpty);
      await b.gate.emitAsync('a2');
      await b.probe.settle();
      final first = b.probe.payloads.single as Grouped;
      expect(first.key, 'a');
      expect(first.value, ['a1', 'a2']);
    });

    test('clears a group after it is emitted', () async {
      final b = bind(GroupByCount<int, String>((n) => 'g', 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.gate.emitAsync(4);
      await b.probe.settle();
      final first = b.probe.payloads[0] as Grouped;
      final second = b.probe.payloads[1] as Grouped;
      expect(first.key, 'g');
      expect(first.value, [1, 2]);
      expect(second.key, 'g');
      expect(second.value, [3, 4]);
    });

    test('independent keys fill in parallel', () async {
      final b = bind(GroupByCount<String, String>((s) => s[0], 2));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync('a1');
      await b.gate.emitAsync('b1');
      await b.gate.emitAsync('b2');
      await b.gate.emitAsync('a2');
      await b.probe.settle();
      final first = b.probe.payloads[0] as Grouped;
      final second = b.probe.payloads[1] as Grouped;
      expect(first.key, 'b');
      expect(first.value, ['b1', 'b2']);
      expect(second.key, 'a');
      expect(second.value, ['a1', 'a2']);
    });

    test('keyOf exceptions drop the pulse and do not fill a bucket', () async {
      final errors = <Object>[];
      final b = bind(GroupByCount<int, String>(
        (n) {
          if (n == 1) throw StateError('count');
          return 'g';
        },
        2,
        onError: (e, _) => errors.add(e),
      ));
      addTearDown(b.probe.stop);
      await b.gate.emitAsync(1);
      await b.gate.emitAsync(2);
      await b.gate.emitAsync(3);
      await b.probe.settle();
      final first = b.probe.payloads.single as Grouped;
      expect(first.key, 'g');
      expect(first.value, [2, 3]);
      expect(errors.single, isA<StateError>());
    });

    test('wrong types call onError', () async {
      final errors = <Object>[];
      final IngressHandle<Object> gate = Cell.ingress<Object>();
      final out = GroupByCount<int, String>(
        (n) => 'g',
        2,
        onError: (e, _) => errors.add(e),
      ).toHandle(source: gate.cell);
      final probe = _Probe(out.cell);
      addTearDown(probe.stop);
      await gate.emitAsync('x');
      await probe.settle();
      expect(probe.payloads, isEmpty);
      expect(errors.single, isA<FormatException>());
    });
  });
}
