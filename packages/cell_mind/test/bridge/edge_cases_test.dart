// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

Pulse pulseWith(dynamic payload, {double? confidence}) =>
    Pulse<dynamic>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('llm'),
        if (confidence != null) Provenance.confidence.entry(confidence),
      ]),
    );

void main() {
  group('bridge edge cases', () {
    test('a tool returning null emits a result pulse with null', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'noop': (args) async => null},
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'noop', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerNoop = observed.single.payload as Pulse;
      expect(innerNoop.type, 'mind.tool.result.noop');
      expect((innerNoop.payload as Map)['result'], isNull);
      sub.stop();
    });

    test('an empty args map dispatches', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'ping': (args) async => 'pong'},
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'ping', 'args': <String, dynamic>{}},
          confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((observed.single.payload as Pulse).type, 'mind.tool.result.ping');
      sub.stop();
    });

    test('a complex tool result survives as a nested map', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'fetch': (args) async => {
                'id': 1,
                'tags': ['a', 'b']
              },
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
      source.emit(pulseWith({'verb': 'fetch', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerFetch = observed.single.payload as Pulse;
      final payload = innerFetch.payload as Map;
      expect((payload['result'] as Map)['tags'], ['a', 'b']);
      sub.stop();
    });

    test('concurrent dispatches serialize (exhaust)', () async {
      final active = <String>[];
      final order = <String>[];
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'work': (args) async {
            final id = args['id'] as String;
            active.add(id);
            order.add('start-$id');
            await Future<void>.delayed(const Duration(milliseconds: 20));
            order.add('end-$id');
            active.remove(id);
            return id;
          },
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final sub = Cell.observe(source: router, effect: (Pulse p) {});
      source.emit(pulseWith({
        'verb': 'work',
        'args': {'id': 'a'}
      }, confidence: 0.9));
      source.emit(pulseWith({
        'verb': 'work',
        'args': {'id': 'b'}
      }, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // exhaust: true drops arrivals that occur while a tool is
      // running — the second dispatch never starts.
      expect(order, ['start-a', 'end-a']);
      expect(active, isEmpty);
      sub.stop();
    });

    test('fireAndForget tool errors are swallowed', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'log': (args) async => throw StateError('telemetry down'),
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
      source.emit(pulseWith({'verb': 'log', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
          (observed.single.payload as Pulse).type, 'mind.tool.dispatched.log');
      expect(observed, hasLength(1),
          reason: 'No error pulse is emitted in fire-and-forget mode.');
      sub.stop();
    });
  });
}
