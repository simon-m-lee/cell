// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('static vs dynamic mode', () {
    test('static mode enforces without recording', () async {
      final gate = Cell.ingress<int>(
        context: ctxWithDomains('finance'),
        testRule: requiresDomainPolicy() + domainPolicy(),
      );
      final accepted = <int>[];
      final sub = Cell.observe(
          source: gate.cell,
          effect: (Pulse p) {
            accepted.add(p.payload as int);
          });
      await gate.ingest(governedPulse(payload: 1, domains: 'finance'));
      await gate.ingest(governedPulse(payload: 2, domains: 'marketing'));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, [1]);
      // Static mode has no handle — nothing to record into.
      sub.stop();
    });

    test('static enforcement + dynamic recording compose', () async {
      final gate = Cell.ingress<int>(
        context: ctxWithDomains('finance'),
        testRule: domainPolicy(),
      );
      final handle = cognitive(cell: gate.cell);
      await gate.ingest(governedPulse(payload: 1, domains: 'finance'));
      await gate.ingest(governedPulse(payload: 2, domains: 'marketing'));
      await Future<void>.delayed(Duration.zero);
      // Only the accepted pulse reached the view and was recorded.
      expect(handle.decisions, hasLength(1));
      expect(handle.decisions.single.verdict, isA<Accept>());
      expect(handle.decisions.single.pulse?.payload, 1);
    });

    test('dynamic mode adds policy enforcement to a bare cell', () async {
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final handle = cognitive(cell: src.cell, policy: domainPolicy());
      // The bare principal accepts anything...
      expect(src.emit(1), isTrue);
      // ...and the cognitive view records the pulse that reached it.
      await Future<void>.delayed(Duration.zero);
      expect(
        handle.decisions.where((d) => d.pulse != null),
        hasLength(1),
      );
      // Commands through the view are governed and recorded.
      final outcome = await handle.cognitive.apply<dynamic>((
        function: (int x) => x,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
      expect(outcome, isA<ApplyAccepted<dynamic>>());
      final commandDecisions =
          handle.decisions.where((d) => d.command != null).toList();
      expect(commandDecisions, hasLength(1));
      expect(commandDecisions.single.verdict, isA<Accept>());
    });

    test('a static-mode policy keeps working after handle creation', () async {
      final gate = Cell.ingress<int>(
        context: ctxWithDomains('finance'),
        testRule: domainPolicy(),
      );
      final handle = cognitive(cell: gate.cell);
      final accepted = <int>[];
      final sub = Cell.observe(
          source: gate.cell,
          effect: (Pulse p) {
            accepted.add(p.payload as int);
          });
      await gate.ingest(governedPulse(payload: 9, domains: 'marketing'));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isEmpty,
          reason: 'The principal still enforces its own static rule.');
      expect(handle.decisions, isEmpty,
          reason: 'The rejected pulse never reached the view.');
      sub.stop();
    });
  });
}
