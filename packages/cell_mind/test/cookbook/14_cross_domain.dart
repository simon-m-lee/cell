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
  test('recipe 14: cross-domain capability handoff', () async {
    final marketing = Context.fromEntries([
      Ontology.domains.entry('marketing'),
    ]);
    final gate = Cell.ingress<int>(context: marketing);
    final financeDeputy = await gate.cell.deputy(
      context: DeputyContext(
        baseContext: Context.fromEntries([
          Ontology.domains.entry('finance'),
        ]),
        authority: 'settlement',
      ),
      testRule: authorityPolicy(additionalVerbs: const {}),
    );
    final handle = cognitive(
      cell: gate.cell,
      policy: domainPolicy(),
    );
    // Marketing-scoped gate: a marketing pulse flows; a finance
    // pulse is out of domain here and fails closed. The settlement
    // deputy (finance mandate) is where finance flows next.
    await gate.ingest(Pulse<int>.governed(
      payload: 1,
      context: PulseContext.fromEntries([Ontology.domains.entry('marketing')]),
    ));
    await gate.ingest(Pulse<int>.governed(
      payload: 2,
      context: PulseContext.fromEntries([Ontology.domains.entry('finance')]),
    ));
    await Future<void>.delayed(Duration.zero);
    final verdicts = handle.decisions
        .where((d) => d.pulse != null)
        .map((d) => d.verdict)
        .toList();
    expect(verdicts[0], isA<Accept>());
    expect(verdicts[1], isA<Reject>());
    expect(financeDeputy.context[Mandate.authority], 'settlement');
  });
}
