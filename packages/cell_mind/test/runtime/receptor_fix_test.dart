// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 2 recording claims (live deputy implementation)', () {
    test('pulses through handle.cognitive ARE recorded', () async {
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(cell: gate.cell);
      final before = handle.decisions.where((d) => d.pulse != null).length;
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      final after = handle.decisions.where((d) => d.pulse != null).length;
      expect(after, before + 1,
          reason: 'The deputy-based recorder logs the pulse decision.');
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.pulse!.payload, 7);
      expect(decision.verdict, isA<Accept>());
    });

    test('pulses through handle.cell are NOT recorded', () async {
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(cell: gate.cell);
      final before = handle.decisions.length;
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      expect(handle.decisions.length, before + 1,
          reason: 'handle.cell IS the principal the deputy wraps — the '
              'recorder fires on the deputy, exactly once.');
    });

    test('apply through handle.cognitive is recorded', () async {
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(cell: gate.cell);
      int echo(int x) => x;
      await handle.cognitive.apply<Object>(
        (
          function: echo,
          arguments: (positionalArguments: [1], namedArguments: null),
          compensation: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        handle.decisions.where((d) => d.command != null),
        hasLength(1),
      );
    });

    test('rejections through handle.cognitive are recorded', () async {
      final gate = Cell.ingress<int>(
          context: Context.fromEntries([
        Ontology.domains.entry('finance'),
      ]));
      final handle = cognitive(
        cell: gate.cell,
        policy: predicatePolicy((object, {required host}) => false),
      );
      await gate.ingest(Pulse<int>(7));
      await Future<void>.delayed(Duration.zero);
      final decision = handle.decisions.lastWhere((d) => d.pulse != null);
      expect(decision.verdict, isA<Reject>());
    });
  });
}
