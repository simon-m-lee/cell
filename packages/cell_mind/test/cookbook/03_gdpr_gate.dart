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
  test('recipe 3: GDPR compliance gate', () async {
    final gate = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.compliance.entry('GDPR')]),
    );
    final handle = cognitive(cell: gate.cell, policy: compliancePolicy());
    await gate.ingest(Pulse<int>.governed(
      payload: 1,
      context: PulseContext.fromEntries([
        Provenance.compliance.entry('GDPR'),
      ]),
    ));
    await gate.ingest(Pulse<int>.governed(payload: 2));
    await Future<void>.delayed(Duration.zero);
    final decisions = handle.decisions.where((d) => d.pulse != null).toList();
    expect(decisions, hasLength(2));
    expect(decisions[0].verdict, isA<Accept>());
    expect(decisions[1].verdict, isA<Reject>());
  });
}
