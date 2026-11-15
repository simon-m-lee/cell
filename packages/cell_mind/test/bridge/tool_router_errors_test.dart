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
  group('toolRouter rejections', () {
    test('unknown verb emits a distinct rejection pulse', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'known': (args) async => 1},
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'delete_everything', 'args': {}},
          confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerUnknown = observed.single.payload as Pulse;
      expect(innerUnknown.type, 'mind.tool.rejected.unknown-verb');
      final payload = innerUnknown.payload as Map;
      expect(payload['verb'], 'delete_everything');
      expect(payload['reason'], 'unknown-verb');
      sub.stop();
    });

    test('low confidence emits a distinct rejection pulse', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'known': (args) async => 1},
        actor: 'llm',
        journal: RecordingJournal(),
        minConfidence: 0.8,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'known', 'args': {}}, confidence: 0.3));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerLow = observed.single.payload as Pulse;
      expect(innerLow.type, 'mind.tool.rejected.low-confidence');
      final payload = innerLow.payload as Map;
      expect(payload['confidence'], 0.3);
      expect(payload['threshold'], 0.8);
      sub.stop();
    });

    test('non-map args emit a distinct rejection pulse', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'known': (args) async => 1},
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(
          pulseWith({'verb': 'known', 'args': 'not-a-map'}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((observed.single.payload as Pulse).type,
          'mind.tool.rejected.invalid-args');
      sub.stop();
    });

    test('non-map payload emits invalid-args', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'known': (args) async => 1},
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith('garbage', confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerNotMap = observed.single.payload as Pulse;
      expect(innerNotMap.type, 'mind.tool.rejected.invalid-args');
      final payload = innerNotMap.payload as Map;
      expect(payload['reason'], 'payload-not-a-map');
      sub.stop();
    });

    test('a throwing tool emits an error pulse with the stack trace', () async {
      final journal = RecordingJournal();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'boom': (args) async => throw StateError('tool exploded'),
        },
        actor: 'llm',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'boom', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final innerBoom = observed.single.payload as Pulse;
      expect(innerBoom.type, 'mind.tool.error.boom');
      final payload = innerBoom.payload as Map;
      expect(
        (payload['error'] as String).contains('tool exploded'),
        isTrue,
      );
      final json = journal.toJson();
      final errorEffect = json
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.tool.error')
          .single;
      final raw = errorEffect['rawOutput'] as Map;
      expect(raw['stackTrace'], isNotEmpty);
      sub.stop();
    });

    test('the four rejection classes are distinct types', () async {
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'boom': (args) async => throw StateError('x'),
        },
        actor: 'llm',
        journal: RecordingJournal(),
        minConfidence: 0.8,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'nope', 'args': {}},
          confidence: 0.9)); // unknown-verb
      await Future<void>.delayed(const Duration(milliseconds: 30));
      source.emit(pulseWith({'verb': 'boom', 'args': {}},
          confidence: 0.3)); // low-confidence
      await Future<void>.delayed(const Duration(milliseconds: 30));
      source.emit(pulseWith({'verb': 'boom', 'args': 7},
          confidence: 0.9)); // invalid-args
      await Future<void>.delayed(const Duration(milliseconds: 30));
      source.emit(pulseWith({'verb': 'boom', 'args': {}},
          confidence: 0.9)); // tool error
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed.map((p) => (p.payload as Pulse).type), [
        'mind.tool.rejected.unknown-verb',
        'mind.tool.rejected.low-confidence',
        'mind.tool.rejected.invalid-args',
        'mind.tool.error.boom',
      ]);
      sub.stop();
    });

    test('rejections are journaled', () async {
      final journal = RecordingJournal();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'known': (args) async => 1},
        actor: 'llm',
        journal: journal,
      );
      final sub = Cell.observe(source: router, effect: (Pulse p) {});
      source.emit(pulseWith({'verb': 'nope', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final json = journal.toJson();
      final rejected = json
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.tool.rejected')
          .single;
      final raw = rejected['rawOutput'] as Map;
      expect(raw['verb'], 'nope');
      expect(raw['reason'], 'unknown-verb');
      sub.stop();
    });
  });
}
