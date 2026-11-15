// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  final context = Context.fromEntries([
    Ontology.domains.entry('finance'),
  ]);

  group('explainPulse', () {
    test('finds the decision by trace id', () async {
      final gate = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: gate.cell);
      final pulse = Pulse<int>.governed(
        payload: 7,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('agent-a'),
          Provenance.traceId.entry('trace-xyz'),
        ]),
      );
      await gate.ingest(pulse);
      await Future<void>.delayed(Duration.zero);
      final path = explainPulse(pulse, handle);
      expect(path, isNotNull);
      expect(path!.id, handle.decisions.last.id);
      expect(path.actor, 'agent-a');
    });

    test('returns null for a pulse never routed through the handle', () async {
      final gate = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: gate.cell);
      final foreign = Pulse<int>.governed(
        payload: 1,
        context: PulseContext.fromEntries([
          Provenance.traceId.entry('elsewhere'),
        ]),
      );
      expect(explainPulse(foreign, handle), isNull);
    });

    test('returns null for pulses without trace ids', () async {
      final gate = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: gate.cell);
      expect(explainPulse(Pulse<int>(1), handle), isNull);
    });

    test('scans most-recent-first', () async {
      final gate = Cell.ingress<int>(context: context);
      final handle = cognitive(cell: gate.cell);
      final traceId = 'trace-repeat';
      for (var i = 0; i < 3; i++) {
        await gate.ingest(
          Pulse<int>.governed(
            payload: i,
            context: PulseContext.fromEntries([
              Provenance.traceId.entry(traceId),
            ]),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
      final path = explainPulse(
        Pulse<int>.governed(
          payload: 99,
          context: PulseContext.fromEntries([
            Provenance.traceId.entry(traceId),
          ]),
        ),
        handle,
      );
      expect(path!.pulse!.payload, 2,
          reason: 'The most recent matching decision wins.');
    });
  });
}
