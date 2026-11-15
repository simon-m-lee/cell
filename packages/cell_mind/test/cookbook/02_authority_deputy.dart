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
  var runs = 0;
  void purchase() {
    runs++;
  }

  test('recipe 2: authority-gated deputy', () async {
    final gate = Cell.ingress<int>();
    final deputy = await gate.cell.deputy(
      context: DeputyContext(
        baseContext: gate.cell.context,
        authority: 'purchase',
      ),
      testRule: authorityPolicy(
        verbResolver: (function) => function == purchase ? 'purchase' : null,
      ),
    );
    await deputy.apply((
      function: purchase,
      arguments: (positionalArguments: null, namedArguments: null),
      compensation: null,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(runs, 1);
  });
}
