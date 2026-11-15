// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('approval integration', () {
    test('defer → queue → approve commits the value and audits both steps',
        () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) {
            if (object is! Pulse) return const Accept();
            final amount = object.payload as int;
            return amount > 1000
                ? const Defer('approval', {'reason': 'large-amount'})
                : const Accept();
          },
        ),
        onDeferred: approvalResolver(queue),
      );

      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });

      await gate.ingest(Pulse<int>(50));
      await Future<void>.delayed(Duration.zero);
      expect(observed, [50]);
      expect(queue.pending, isEmpty);

      // The deferred pulse is held by the queue and dropped from the
      // wave — human latency never blocks the gate.
      await gate.ingest(Pulse<int>(5000));
      await Future<void>.delayed(Duration.zero);
      expect(queue.pending, hasLength(1));
      expect(observed, [50]);

      await queue.approve(queue.pending.keys.single);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.committed.value, 5000,
          reason: 'Approval delivers the value through `committed`.');
      expect(observed, [50]);

      final decisions = handle.decisions.where((d) => d.pulse != null);
      final large = decisions.where((d) => d.pulse?.payload == 5000);
      expect(large, hasLength(2),
          reason: 'One Defer record + one resolution record.');
      final defer = large.first.verdict as Defer;
      expect(defer.annotations['reason'], 'large-amount');
      final resolution = large.last.verdict as Accept;
      expect(resolution.annotations['deferredBy'], 'approval');
      expect(resolution.annotations['reason'], 'large-amount');
      expect(resolution.annotations['decisionId'], large.first.id);
      sub.stop();
      await queue.dispose();
    });

    test('defer → queue → reject resolves false without a commit', () async {
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) =>
              object is Pulse ? const Defer('approval') : const Accept(),
        ),
        onDeferred: approvalResolver(queue),
      );
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(1));
      await Future<void>.delayed(Duration.zero);
      await queue.reject(queue.pending.keys.single, 'human-said-no');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(observed, isEmpty);
      expect(queue.committed.value, isNull);
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      expect((decisions.last.verdict as Reject).reason, 'defer-rejected');
      sub.stop();
      await queue.dispose();
    });

    test('learned defer rules route into the queue', () async {
      final context = Context.fromEntries([
        Ontology.domains.entry('finance,audit'),
        Ontology.constraints.entry({
          'cell_mind.policy': {
            'version': 1,
            'rules': [
              {
                'when': {'domains': 'audit'},
                'action': 'defer',
                'resolver': 'approval',
                'confidence': 0.9,
                'support': 10,
                'trainedIn': 1,
              },
            ],
          },
        }),
      ]);
      final queue = ApprovalQueue<int>(journal: RecordingJournal());
      final gate = Cell.ingress<int>(context: context);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: learnedVerdictPolicy(),
        onDeferred: approvalResolver(queue),
      );

      await gate.ingest(
        Pulse<int>.governed(
          payload: 1,
          context: PulseContext.fromEntries([
            Provenance.actor.entry('auditor'),
            Ontology.domains.entry('audit'),
          ]),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(queue.pending, hasLength(1));
      await queue.approve(queue.pending.keys.single);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.committed.value, 1);
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      expect(decisions.last.verdict, isA<Accept>());
      await queue.dispose();
    });

    test('TTL expiry resolves the deferred decision as rejected', () async {
      var now = DateTime.utc(2026, 11, 15, 12);
      final queue = ApprovalQueue<int>(
        journal: RecordingJournal(clockSource: () => now),
        ttl: const Duration(milliseconds: 60),
      );
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) =>
              object is Pulse ? const Defer('approval') : const Accept(),
        ),
        onDeferred: approvalResolver(queue),
      );
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(1));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(observed, isEmpty);
      expect(queue.committed.value, isNull);
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      expect((decisions.last.verdict as Reject).reason, 'defer-rejected',
          reason: 'The resolver returned false after expiry.');
      sub.stop();
      await queue.dispose();
    });
  });
}
