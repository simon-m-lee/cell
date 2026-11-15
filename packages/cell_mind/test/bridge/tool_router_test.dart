// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

Pulse toolPulse(
  Map<String, dynamic> payload, {
  double? confidence,
}) =>
    Pulse<Map<String, dynamic>>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('llm'),
        if (confidence != null) Provenance.confidence.entry(confidence),
      ]),
    );

void main() {
  group('toolRouter', () {
    test('dispatches a known verb and emits the awaited result', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'add': (args) async => (args['a'] as int) + (args['b'] as int),
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({
        'verb': 'add',
        'args': {'a': 2, 'b': 3}
      }, confidence: 0.95));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed, hasLength(1));
      final inner = observed.single.payload as Pulse;
      expect(inner.type, 'mind.tool.result.add');
      final payload = inner.payload as Map;
      expect(payload['verb'], 'add');
      expect(payload['result'], 5);
      sub.stop();
    });

    test('awaits the tool by default — result lands only after completion',
        () async {
      final gate = Completer<Object?>();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'slow': (args) => gate.future,
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({'verb': 'slow', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed, isEmpty);
      gate.complete('done');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final innerSlow = observed.single.payload as Pulse;
      expect(innerSlow.type, 'mind.tool.result.slow');
      sub.stop();
    });

    test('serializes dispatches with exhaust: true', () async {
      final order = <String>[];
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'first': (args) async {
            order.add('first-start');
            await Future<void>.delayed(const Duration(milliseconds: 30));
            order.add('first-end');
            return 1;
          },
          'second': (args) async {
            order.add('second-start');
            return 2;
          },
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final sub = Cell.observe(source: router, effect: (Pulse p) {});
      source.emit(toolPulse({'verb': 'first', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      source.emit(toolPulse({'verb': 'second', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(order, ['first-start', 'first-end', 'second-start'],
          reason: 'Sequential dispatches run in order.');
      sub.stop();
    });

    test('supports multiple verbs', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'a': (args) async => 'A',
          'b': (args) async => 'B',
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({'verb': 'a', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      source.emit(toolPulse({'verb': 'b', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed.map((p) => (p.payload as Pulse).type), [
        'mind.tool.result.a',
        'mind.tool.result.b',
      ]);
      sub.stop();
    });

    test('null confidence dispatches (no confidence gate)', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'ping': (args) async => 'pong',
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({'verb': 'ping', 'args': {}}));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((observed.single.payload as Pulse).type, 'mind.tool.result.ping');
      sub.stop();
    });

    test('confidence exactly at the threshold dispatches', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'ping': (args) async => 'pong',
        },
        actor: 'llm',
        journal: RecordingJournal(),
        minConfidence: 0.85,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({'verb': 'ping', 'args': {}}, confidence: 0.85));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((observed.single.payload as Pulse).type, 'mind.tool.result.ping');
      sub.stop();
    });

    test('fireAndForget dispatches without awaiting and emits the step',
        () async {
      final calls = <int>[];
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'log': (args) async {
            calls.add(1);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return null;
          },
        },
        actor: 'llm',
        journal: RecordingJournal(),
        fireAndForget: true,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(toolPulse({'verb': 'log', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, [1]);
      expect(
          (observed.single.payload as Pulse).type, 'mind.tool.dispatched.log',
          reason: 'Dispatched step, not a result pulse.');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(observed, hasLength(1),
          reason: 'No result pulse is ever emitted.');
      sub.stop();
    });

    test('journals dispatch and result effects', () async {
      final journal = RecordingJournal();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'ping': (args) async => 'pong',
        },
        actor: 'llm',
        journal: journal,
      );
      final sub = Cell.observe(source: router, effect: (Pulse p) {});
      source.emit(toolPulse({
        'verb': 'ping',
        'args': {'x': 1}
      }, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.tool.dispatch',
        ),
        isTrue,
      );
      final result = json
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.tool.result')
          .single;
      final raw = result['rawOutput'] as Map;
      expect(raw['verb'], 'ping');
      expect(raw['result'], 'pong');
      sub.stop();
    });
  });
}
