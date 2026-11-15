// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  final hostContext = Context.fromEntries([
    Ontology.domains.entry('finance'),
    Ontology.version.entry('1.0.0'),
  ]);

  group('defer routing', () {
    test('verdictPolicy Accept is recorded with annotations', () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) =>
              const Accept({'via': 'verdict'}),
        ),
      );
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Accept>());
      expect((decision.verdict as Accept).annotations, {'via': 'verdict'});
    });

    test('verdictPolicy Reject is recorded with reason and annotations',
        () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) => const Reject(
            'not-allowed',
            {'code': 403},
          ),
        ),
      );
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      final verdict = decision.verdict as Reject;
      expect(verdict.reason, 'not-allowed');
      expect(verdict.annotations, {'code': 403});
    });

    test('Defer without a resolver fails closed', () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) => const Defer('approval'),
        ),
      );
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      expect(observed, isEmpty);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>());
      expect((decision.verdict as Reject).reason, 'defer-no-resolver');
      sub.stop();
    });

    test('Defer is recorded, drops the wave, and records the resolution',
        () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) =>
              const Defer('supervisor', {'level': 2}),
        ),
        onDeferred: (decision, verdict) async => true,
      );
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The deferred pulse is dropped from the wave (human latency must
      // never block a pulse wave); the resolution is recorded.
      expect(observed, isEmpty);
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions, hasLength(2));
      final defer = decisions.first.verdict as Defer;
      expect(defer.resolver, 'supervisor');
      expect(defer.annotations, {'level': 2});
      final resolution = decisions.last.verdict as Accept;
      expect(resolution.annotations['deferredBy'], 'supervisor');
      expect(resolution.annotations['level'], 2,
          reason: 'The Defer\'s annotations survive into the resolution.');
      expect(resolution.annotations['decisionId'], decisions.first.id,
          reason: 'The resolution links back to the deferred decision.');
      sub.stop();
    });

    test('a rejecting resolver records defer-rejected', () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) => const Defer('approval'),
        ),
        onDeferred: (decision, verdict) async => false,
      );
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(observed, isEmpty);
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      final resolution = decisions.last.verdict as Reject;
      expect(resolution.reason, 'defer-rejected');
      expect(resolution.annotations['deferredBy'], 'approval');
      sub.stop();
    });

    test('a throwing resolver fails closed with defer-resolver-failed',
        () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) => const Defer('approval'),
        ),
        onDeferred: (decision, verdict) async {
          throw StateError('resolver down');
        },
      );
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final decisions = handle.decisions.where((d) => d.pulse != null);
      expect(decisions.first.verdict, isA<Defer>());
      final resolution = decisions.last.verdict as Reject;
      expect(resolution.reason, 'defer-resolver-failed');
      expect(resolution.annotations['deferredBy'], 'approval');
      expect(
        (resolution.annotations['error'] as String).contains('resolver down'),
        isTrue,
      );
    });

    test('Defer during argument validation fails closed', () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(
        cell: gate.cell,
        verdictPolicy: verdictPolicy(
          (object, {required host, arguments}) {
            if (arguments is Function) return const Defer('approval');
            return const Accept();
          },
        ),
      );
      int push(int x) => x;
      final outcome = await handle.cognitive.apply<Object>(
        (
          function: push,
          arguments: (positionalArguments: [1], namedArguments: null),
          compensation: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(outcome, isA<ApplyRejected>());
      final decision = handle.decisions.lastWhere((d) => d.command != null);
      expect(
          (decision.verdict as Reject).reason, 'defer-in-argument-validation');
    });

    test('no verdictPolicy preserves Phase 2 semantics', () async {
      final gate = Cell.ingress<int>(context: hostContext);
      final handle = cognitive(cell: gate.cell);
      final observed = <int>[];
      final sub = Cell.observe(
          source: handle.cognitive,
          effect: (Pulse p) {
            observed.add(p.payload as int);
          });
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      expect(observed, [7]);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Accept>());
      sub.stop();
    });
  });
}
