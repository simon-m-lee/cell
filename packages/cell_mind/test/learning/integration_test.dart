// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  Pulse<int> pulse(int payload, String domains) => Pulse<int>.governed(
        payload: payload,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('sim'),
          Provenance.reason.entry('learning-loop'),
          Provenance.traceId.entry(Identity.next()),
          Ontology.domains.entry(domains),
          Provenance.confidence.entry(1.0),
        ]),
      );

  group('learning loop', () {
    test('record → train → deploy changes runtime decisions', () async {
      // 1. A permissive static gate over three domains.
      final context = Context.fromEntries([
        Ontology.domains.entry('finance,marketing,audit'),
        Ontology.version.entry('1.0.0'),
      ]);
      final gate = Cell.ingress<int>(
        context: context,
        testRule: contextAware() + learnedPolicy(),
      );
      final handle = cognitive(cell: gate.cell);
      final outcomes = recordOutcomes(handle);

      // 2. Simulate traffic: marketing decisions always fail downstream,
      //    finance decisions succeed.
      for (var i = 0; i < 12; i++) {
        await gate.ingest(pulse(i, 'marketing'));
        await Future<void>.delayed(Duration.zero);
        final decision = handle.decisions.lastWhere((d) => d.pulse != null);
        handle.recordOutcome(decisionId: decision.id, reward: -1.0);
      }
      for (var i = 0; i < 6; i++) {
        await gate.ingest(pulse(100 + i, 'finance'));
        await Future<void>.delayed(Duration.zero);
        final decision = handle.decisions.lastWhere((d) => d.pulse != null);
        handle.recordOutcome(decisionId: decision.id, reward: 1.0);
      }
      await Future<void>.delayed(Duration.zero);

      // 3. Train.
      final journal = RecordingJournal();
      final trained = await trainOffline(
        handle: handle,
        outcomes: outcomes.log,
        baseContext: handle.cell.context,
        trainer: contextualBandit(),
        journal: journal,
        config: const TrainingConfig(minSupport: 5, minConfidence: 0.6),
      );
      expect(trained.decisionCount, greaterThanOrEqualTo(18));
      expect(trained.resolvedCount, 18);
      final rules = trained.policyBlock['rules'] as List;
      expect(rules, hasLength(2));
      final marketing = rules.singleWhere((r) {
        final when = (r as Map)['when'] as Map;
        return when['domains'] == 'marketing' && when['actor'] == 'sim';
      }) as Map;
      expect(marketing['action'], 'reject');
      expect(trained.policyBlock['version'], 1);

      // 4. Deploy: evolved context, same policy composition.
      final evolved = trained.applyTo(handle.cell.context);
      expect(evolved.domains, 'finance,marketing,audit',
          reason: 'Structural dimensions survive applyTo.');
      expect(evolved.version, '1.0.0');
      final newGate = Cell.ingress<int>(
        context: evolved,
        testRule: contextAware() + learnedPolicy(),
      );
      final newHandle = cognitive(cell: newGate.cell);

      // 5. The learned rule now rejects marketing before downstream.
      final observed = <int>[];
      final sub = Cell.observe(
          source: newHandle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await newGate.ingest(pulse(999, 'marketing'));
      await newGate.ingest(pulse(1000, 'finance'));
      await Future<void>.delayed(Duration.zero);
      expect(observed, [1000],
          reason: 'The marketing pulse was rejected by the learned rule; '
              'finance still flows.');
      sub.stop();
      outcomes.stop();
      handle.dispose();
      newHandle.dispose();
    });

    test('learned accept rules keep a domain flowing', () async {
      final context = Context.fromEntries([
        Ontology.domains.entry('finance,audit'),
      ]);
      final gate = Cell.ingress<int>(
        context: context,
        testRule: contextAware() + learnedPolicy(),
      );
      final handle = cognitive(cell: gate.cell);
      final outcomes = recordOutcomes(handle);
      for (var i = 0; i < 5; i++) {
        await gate.ingest(pulse(i, 'finance'));
        await Future<void>.delayed(Duration.zero);
        final decision = handle.decisions.lastWhere((d) => d.pulse != null);
        handle.recordOutcome(decisionId: decision.id, reward: 1.0);
      }
      await Future<void>.delayed(Duration.zero);
      final trained = await trainOffline(
        handle: handle,
        outcomes: outcomes.log,
        baseContext: handle.cell.context,
        trainer: contextualBandit(),
        journal: RecordingJournal(),
        config: const TrainingConfig(minSupport: 5),
      );
      final rules = trained.policyBlock['rules'] as List;
      expect(rules.single is Map, isTrue);
      expect((rules.single as Map)['action'], 'accept');
      outcomes.stop();
    });
  });
}
