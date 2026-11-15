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
  test('recipe 10: Blend + cognitive (via bound ingress)', () async {
    final source = Cell.ingress<int>(
      context: Context.fromEntries([Ontology.domains.entry('finance')]),
    );
    final blend = Blend(
      'User',
      fields: [ValueField<Blend, String>(name: #name, value: 'ada')],
    );
    expect(blend, isA<Cell>());
    final handle = cognitive(cell: source.cell);
    source.emit(1);
    await Future<void>.delayed(Duration.zero);
    expect(handle.decisions.where((d) => d.pulse != null), hasLength(1));
    expect(handle.decisions.last.verdict, isA<Accept>());
    // v1.0: organ stems cannot host a TestCell recorder (their deputy
    // API accepts TestStem only) — the ingress hosts the handle.
    expect(blend.id, isNotNull);
  });
}
