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
  test('recipe 1: domain-gated ingress', () async {
    final gate = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
      testRule: domainPolicy(),
    );
    final seen = <int>[];
    final sub = Cell.observe(
        source: gate.cell,
        effect: (Pulse p) {
          seen.add(p.payload as int);
        });
    await gate.ingest(Pulse<int>.governed(
      payload: 42,
      context: PulseContext.fromEntries([Ontology.domains.entry('finance')]),
    ));
    await gate.ingest(Pulse<int>.governed(payload: 7));
    await Future<void>.delayed(Duration.zero);
    expect(seen, [42]);
    sub.stop();
  });
}
