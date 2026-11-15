// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:cell_organ/cell_organ.dart' hide Reject;
import 'package:test/test.dart';

void main() {
  test('recipe 11: compose with TestStem', () async {
    final source = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
    );
    final blend = Blend(
      'Gate',
      fields: [ValueField<Blend, String>(name: #label, value: 'g')],
      testRule: TestStem.allowAll,
    );
    expect(blend, isA<Cell>());
    final handle = cognitive(cell: source.cell, policy: domainPolicy());
    await source.ingest(Pulse<int>.governed(
      payload: 9,
      context: PulseContext.fromEntries([Ontology.domains.entry('finance')]),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(handle.decisions.last.verdict, isA<Accept>());
  });
}
