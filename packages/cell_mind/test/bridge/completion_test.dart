// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart' hide completion;

void main() {
  group('completion bridge', () {
    test('emits the resolved value as a governed pulse', () async {
      final completer = Completer<String>();
      final journal = RecordingJournal();
      final cell = completion(
        future: completer.future,
        actor: 'llm',
        prompt: '2+2',
        confidence: 0.9,
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      completer.complete('4');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed, hasLength(1));
      final pulse = observed.single;
      expect(pulse.payload, '4');
      expect(pulse.type, 'mind.completion.result');
      expect(pulse.context.actor, 'llm');
      expect(pulse.context.confidence, 0.9);
      sub.stop();
    });

    test('confidence and strategy flow into the pulse context', () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('x'),
        actor: 'agent-a',
        prompt: 'p',
        confidence: 0.77,
        strategy: ReasoningStrategy.stochastic,
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final pulse = observed.single;
      expect(pulse.context.confidence, 0.77);
      expect(pulse.context.strategy, ReasoningStrategy.stochastic);
      expect(pulse.context.purpose, 'COMPLETION');
      sub.stop();
    });

    test('a failing future emits a typed error pulse and journals it',
        () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future<String>.error(StateError('model down')),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed.single.type, 'mind.completion.error');
      expect(observed.single.payload, isNull);
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.completion.error',
        ),
        isTrue,
      );
      sub.stop();
    });

    test('journals the completion effect with the strategy', () async {
      final journal = RecordingJournal();
      completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        strategy: ReasoningStrategy.stochastic,
        journal: journal,
      );
      await Future<void>.delayed(Duration.zero);
      final json = journal.toJson();
      final effect = json
          .where((e) => e['kind'] == 'io' && e['label'] == 'mind.completion')
          .single;
      final raw = effect['rawOutput'] as Map;
      expect(raw['actor'], 'llm');
      expect(raw['confidence'], 0.9);
      expect(raw['strategy'], 'stochastic');
      expect(raw['version'], '1.0.0');
    });

    test('merges a baseContext into the emission provenance', () async {
      final base = PulseContext.fromEntries([
        Provenance.traceId.entry('trace-1'),
      ]);
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.9,
        baseContext: base,
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed.single.context.traceId, 'trace-1');
      sub.stop();
    });

    test('the returned cell composes with cognitive()', () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.99,
        journal: journal,
      );
      final handle = cognitive(
        cell: cell,
        policy: confidencePolicy(min: 0.85),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Accept>());
    });

    test('low-confidence completions are rejected by the cognitive layer',
        () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.3,
        journal: journal,
      );
      final handle = cognitive(
        cell: cell,
        policy: confidencePolicy(min: 0.85),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>());
    });
  });
}
