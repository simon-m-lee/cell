// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('runtime × policy composition', () {
    test('contextAware records accepts and rejects', () async {
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final handle = cognitive(cell: src.cell, policy: contextAware());
      await src.ingest(governedPulse(
        payload: 1,
        domains: 'finance',
        confidence: 0.95,
      ));
      await src.ingest(governedPulse(
        payload: 2,
        domains: 'marketing',
        confidence: 0.95,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions, hasLength(2));
      expect(handle.decisions[0].verdict, isA<Accept>());
      expect(handle.decisions[1].verdict, isA<Reject>());
      expect((handle.decisions[1].verdict as Reject).reason, 'policy-rejected');
    });

    test('composed domain + confidence policies attribute jointly', () async {
      final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
      final handle = cognitive(
        cell: src.cell,
        policy: domainPolicy() + confidencePolicy(min: 0.85),
      );
      await src.ingest(governedPulse(
        payload: 1,
        domains: 'finance',
        confidence: 0.5,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions, hasLength(1));
      expect(
          (handle.decisions.single.verdict as Reject).reason, 'policy-rejected',
          reason: 'The composed policy is one gate from the runtime\'s '
              'perspective — attribution is composite-level (D3).');
    });

    test('recording-only handles log with the principal rule', () async {
      final positiveGate = TestCell<Cell>(
        (object, {host, arguments, user}) =>
            object is! Pulse || (object.payload as int) >= 0,
      );
      final src = Cell.ingress<int>(testRule: positiveGate);
      final handle = cognitive(cell: src.cell);
      src.emit(5);
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions, hasLength(1));
      expect(handle.decisions.single.verdict, isA<Accept>());
    });
  });
}
