// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  test('recipe 12: custom Defer resolver', () async {
    final journal = RecordingJournal();
    final gate = Cell.ingress<int>();
    final handle = cognitive(
      cell: gate.cell,
      verdictPolicy: verdictPolicy((object, {required host, arguments}) {
        if (object is! Pulse) return const Accept();
        return const Defer('audit');
      }),
      onDeferred: (decision, verdict) async {
        if (verdict is! Defer || verdict.resolver != 'audit') return false;
        await journal.io(
          label: 'custom.audit.deferred',
          input: decision.toMap(),
          run: () async => true,
        );
        return true;
      },
    );
    await gate.ingest(Pulse<int>.governed(payload: 1));
    await Future<void>.delayed(Duration.zero);
    final decisions = handle.decisions.where((d) => d.pulse != null).toList();
    expect(decisions, hasLength(2)); // Defer + resolution
    expect(decisions[0].verdict, isA<Defer>());
    expect(decisions[1].verdict, isA<Accept>());
    expect((decisions[1].verdict as Accept).annotations['deferredBy'], 'audit');
    expect(
      journal.records
          .whereType<IoEffect>()
          .any((e) => e.label == 'custom.audit.deferred'),
      isTrue,
    );
  });
}
