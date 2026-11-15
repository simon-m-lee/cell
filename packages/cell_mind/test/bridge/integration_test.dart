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
  group('bridge integration', () {
    test('completion → cognitive() gates on confidence', () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('trusted'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.99,
        journal: journal,
      );
      final handle = cognitive(
        cell: cell,
        policy: confidencePolicy(min: 0.85),
      );
      final observed = <String>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as String);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed, ['trusted']);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Accept>());
      sub.stop();
    });

    test('toolRouter feeds results back into a second router', () async {
      final source = Cell.ingress<Pulse>();
      final first = toolRouter(
        source: source.cell,
        tools: {
          'plan': (args) async => {
                'verb': 'execute',
                'args': {'n': 42}
              },
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      // The model consumes the tool result and emits the next call.
      final model = Cell.asyncMap<Pulse, Pulse>(
        first,
        (pulse, {required journal}) async {
          // The asyncMap mapper receives the router's INNER pulse
          // directly (its payload is the result map).
          final result = (pulse.payload as Map)['result'] as Map;
          return Pulse<dynamic>.governed(
            payload: result,
            context: pulse.context,
          );
        },
        journal: RecordingJournal(),
      );
      final second = toolRouter(
        source: model,
        tools: {
          'execute': (args) async => 'executed-${args['n']}',
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: second,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'plan', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final innerExecute = observed.single.payload as Pulse;
      expect(innerExecute.type, 'mind.tool.result.execute');
      final payload = innerExecute.payload as Map;
      expect(payload['result'], 'executed-42');
      sub.stop();
    });

    test('high-value tools defer to approval before dispatch', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final source = Cell.ingress<Pulse>();
      final router = toolRouter(
        source: source.cell,
        tools: {
          'transfer': (args) async => 'transferred',
        },
        actor: 'llm',
        journal: RecordingJournal(),
      );
      final handle = cognitive(
        cell: router,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) {
            final outer = object is Pulse ? object.payload : null;
            final payload = outer is Pulse ? outer.payload : null;
            if (payload is Map && payload['verb'] == 'transfer') {
              return const Defer('approval');
            }
            return const Accept();
          },
        ),
        onDeferred: approvalResolver(queue),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p);
          });
      source.emit(pulseWith({'verb': 'transfer', 'args': {}}, confidence: 0.9));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(queue.pending, hasLength(1),
          reason: 'The transfer decision was deferred for approval.');
      expect(observed, isEmpty,
          reason: 'The deferred decision dropped from the wave.');
      await queue.approve(queue.pending.keys.single);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(queue.committed.value, isNull,
          reason: 'Command decisions commit no pre-execution payload.');
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      expect(decisions.last.verdict, isA<Accept>());
      sub.stop();
      await queue.dispose();
    });

    test('low-confidence completions never reach the router', () async {
      final journal = RecordingJournal();
      final cell = completion(
        future: Future.value('ok'),
        actor: 'llm',
        prompt: 'p',
        confidence: 0.2,
        journal: journal,
      );
      final handle = cognitive(
        cell: cell,
        policy: confidencePolicy(min: 0.85),
      );
      final observed = <String>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as String);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed, isEmpty);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>());
      sub.stop();
    });
  });
}
