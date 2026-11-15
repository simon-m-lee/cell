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
  test('recipe 4: sensitivity redaction pipeline', () async {
    final gate = Cell.ingress<String>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
    );
    final handle = cognitive(
      cell: gate.cell,
      policy: sensitivityPolicy(defaultMax: Sensitivity.public) +
          predicatePolicy((object, {required host, arguments}) {
            if (object is! Pulse) return true;
            return !(object.payload as String).contains('secret');
          }),
    );
    final seen = <String>[];
    final sub = Cell.observe(
        source: handle.cognitive,
        effect: (Pulse p) {
          seen.add(p.payload as String);
        });
    await gate.ingest(Pulse<String>.governed(
      payload: 'plain',
      context: PulseContext.fromEntries([
        Ontology.domains.entry('finance'),
        Provenance.sensitivity.entry(Sensitivity.public),
      ]),
    ));
    await gate.ingest(Pulse<String>.governed(
      payload: 'the secret key',
      context: PulseContext.fromEntries([
        Ontology.domains.entry('finance'),
        Provenance.sensitivity.entry(Sensitivity.public),
      ]),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['plain']);
    expect(
      handle.decisions.last.verdict,
      isA<Reject>(),
    );
    sub.stop();
  });
}
