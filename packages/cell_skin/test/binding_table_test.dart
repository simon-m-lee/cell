// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('SkinBindingTable registers and looks up bindings', () {
    final handle = Cell.state<int>(initial: 1);
    final table = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'a',
        functionName: 'set',
        target: handle.cell,
        function: (int v) => handle.update(v),
      ));
    expect(table.lookup('a', 'set'), isNotNull);
    expect(table.lookup('a', 'missing'), isNull);
    expect(table.lookup('b', 'set'), isNull);
    expect(table.exposedCellIds, ['a']);
    expect(table.length, 1);
  });

  test('toApplyCommand decodes positional and named wire arguments', () {
    final handle = Cell.state<int>(initial: 1);
    final binding = SkinBinding(
      cellId: 'a',
      functionName: 'set',
      target: handle.cell,
      function: (int v) => handle.update(v),
    );
    final command = binding.toApplyCommand(WireRequest(
      cellId: 'a',
      function: 'set',
      positional: {'0': 7},
      named: {'reason': 'test'},
      correlationId: 'c',
    ));
    expect(command.arguments.positionalArguments, [7]);
    expect(command.arguments.namedArguments, {#reason: 'test'});
    expect(command.function, same(binding.function));
    expect(command.compensation, isNull);
  });

  test('whitelist gates exposure declaratively', () {
    final whitelist = SkinWhitelist({
      'a': {'set'},
    });
    expect(whitelist.allows('a', 'set'), isTrue);
    expect(whitelist.allows('a', 'other'), isFalse);
    expect(whitelist.allows('b', 'set'), isFalse);
    expect(SkinWhitelist.empty.allows('a', 'set'), isFalse);
  });
}
