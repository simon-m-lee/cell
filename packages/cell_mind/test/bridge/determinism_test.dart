// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart' hide completion;

Pulse pulseWith(dynamic payload, {double? confidence}) =>
    Pulse<dynamic>.governed(
      payload: payload,
      context: PulseContext.fromEntries([
        Provenance.actor.entry('llm'),
        if (confidence != null) Provenance.confidence.entry(confidence),
      ]),
    );

void main() {
  group('bridge determinism', () {
    test('replaying a toolRouter run does not re-invoke the tool', () async {
      var calls = 0;
      final recording = RecordingJournal();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'echo': (args) async {
            calls++;
            return 'first-run';
          },
        },
        actor: 'llm',
        journal: recording,
      );
      final observed1 = <Pulse>[];
      final sub1 = Cell.observe(
          source: router,
          effect: (Pulse p) {
            observed1.add(p);
          });
      source.emit(pulseWith({'verb': 'echo', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((observed1.single.payload as Pulse).type, 'mind.tool.result.echo');
      sub1.stop();

      // Replay: asyncMap serves the recorded result; the tool must not
      // run again even though it would now return a different value.
      final replay = ReplayJournal(
        recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
      );
      final source2 = Cell.ingress<Pulse>();
      final router2 = toolRouter(
        source: source2.cell,
        tools: {
          'echo': (args) async {
            calls++;
            return 'second-run';
          },
        },
        actor: 'llm',
        journal: replay,
      );
      final observed2 = <Pulse>[];
      final sub2 = Cell.observe(
          source: router2,
          effect: (Pulse p) {
            observed2.add(p);
          });
      source2.emit(pulseWith({'verb': 'echo', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 1, reason: 'The tool never re-ran on replay.');
      final payload = (observed2.single.payload as Pulse).payload as Map;
      expect(payload['result'], 'first-run');
      sub2.stop();
    });

    test('completion runs produce identical payloads for identical futures',
        () async {
      final recording = RecordingJournal();
      final cell1 = completion(
        future: Future.value('answer'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        journal: recording,
      );
      final observed1 = <Pulse>[];
      final sub1 = Cell.observe(
          source: cell1,
          effect: (Pulse p) {
            observed1.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sub1.stop();

      final cell2 = completion(
        future: Future.value('answer'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        journal: RecordingJournal(
          clockSource: () => DateTime.utc(2026, 11, 15, 12),
        ),
      );
      final observed2 = <Pulse>[];
      final sub2 = Cell.observe(
          source: cell2,
          effect: (Pulse p) {
            observed2.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sub2.stop();

      expect(observed1.map((p) => p.payload), observed2.map((p) => p.payload));
      expect(observed1.first.type, observed2.first.type);
      expect(observed1.first.context.actor, observed2.first.context.actor);
    });

    test('bridge effects survive a journal round-trip', () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        journal: journal,
      );
      final sub = Cell.observe(source: cell, effect: (Pulse p) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sub.stop();
      final typed = journal
          .toJson()
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.completion')
          .single;
      final effect = bridgeEffectFromMap(
        (typed['rawOutput'] as Map).cast<String, dynamic>(),
      ) as MindCompletionEffect;
      expect(effect.actor, 'llm');
      expect(effect.confidence, 0.9);
    });

    test('the router journal contains the full dispatch sequence', () async {
      final journal = RecordingJournal();
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {'echo': (args) async => 'x'},
        actor: 'llm',
        journal: journal,
      );
      final sub = Cell.observe(source: router, effect: (Pulse p) {});
      source.emit(pulseWith({'verb': 'echo', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sub.stop();
      final labels = journal
          .toJson()
          .where((e) => e['kind'] == 'io')
          .map((e) => e['label'])
          .toList();
      expect(labels, contains('mind.tool.dispatch'));
      expect(labels, contains('mind.tool.result'));
    });
  });
}
