// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// MCP tool names round-trip real cell ids.
///
/// `name` is the escaped wire form (unsafe characters become `_`);
/// `dottedName` is the raw `<cellId>.<functionName>`. A host registers
/// `name` once, dispatches through `resolveMcpToolCall` (which accepts
/// both forms), and answers unknown names with the `unknown_tool` tool
/// result.
library;

import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

SkinManifest manifestWith(String cellId, String function) => SkinManifest(
      cells: [
        SkinCellDescriptor(
          cellId: cellId,
          description: 'a cell',
          functions: [SkinFunctionDescriptor(name: function)],
        ),
      ],
    );

void main() {
  test('both forms round-trip a dotted cell id', () {
    final manifest = manifestWith('home.living.thermostat', 'setTarget');
    final specs = mcpToolSpecs(manifest);
    final spec = specs.single;
    expect(spec.name, 'home_living_thermostat_setTarget');
    expect(spec.dottedName, 'home.living.thermostat.setTarget');
    expect(spec.toJson()['name'], 'home_living_thermostat_setTarget');

    final byName = resolveMcpToolCall(manifest, spec.name);
    expect(byName, isNotNull);
    expect(byName!.cellId, 'home.living.thermostat');
    expect(byName.functionName, 'setTarget');

    final byDotted = resolveMcpToolCall(manifest, spec.dottedName);
    expect(byDotted, isNotNull);
    expect(byDotted!.cellId, 'home.living.thermostat');
    expect(byDotted.functionName, 'setTarget');
  });

  test('other unsafe characters are replaced too', () {
    final specs = mcpToolSpecs(manifestWith('home/living room', 'set target'));
    expect(specs.single.name, 'home_living_room_set_target');
  });

  test('repeated underscores are not collapsed', () {
    final specs = mcpToolSpecs(manifestWith('a..b', 'c'));
    expect(specs.single.name, 'a__b_c');
  });

  test('dot-free parts work in both forms', () {
    final manifest = manifestWith('door', 'lock');
    final spec = mcpToolSpecs(manifest).single;
    expect(spec.name, 'door_lock');
    expect(spec.dottedName, 'door.lock');
    expect(resolveMcpToolCall(manifest, 'door_lock')!.cellId, 'door');
    expect(resolveMcpToolCall(manifest, 'door.lock')!.cellId, 'door');
  });

  test('an unknown name resolves to null and produces the unknown result',
      () {
    final manifest = manifestWith('door', 'lock');
    expect(resolveMcpToolCall(manifest, 'nope'), isNull);
    expect(resolveMcpToolCall(manifest, ''), isNull);
    final result = mcpUnknownToolResult();
    expect(result, {
      'isError': true,
      'content': [
        {'type': 'text', 'text': 'unknown_tool'},
      ],
    });
    expect(result.toString(), isNot(contains('nope')));
  });

  test('a collision throws before a list is returned', () {
    final manifest = SkinManifest(cells: [
      SkinCellDescriptor(
        cellId: 'home',
        description: '',
        functions: const [SkinFunctionDescriptor(name: 'set.target')],
      ),
      SkinCellDescriptor(
        cellId: 'home',
        description: '',
        functions: const [SkinFunctionDescriptor(name: 'set target')],
      ),
    ]);
    expect(
      () => mcpToolSpecs(manifest),
      throwsA(isA<StateError>().having(
        (e) => e.toString(),
        'message',
        allOf(contains('home.set.target'), contains('home.set target')),
      )),
    );
  });

  test('a dotted collision is caught too', () {
    final manifest = SkinManifest(cells: [
      SkinCellDescriptor(
        cellId: 'a.b',
        description: '',
        functions: const [SkinFunctionDescriptor(name: 'c')],
      ),
      SkinCellDescriptor(
        cellId: 'a',
        description: '',
        functions: const [SkinFunctionDescriptor(name: 'b.c')],
      ),
    ]);
    expect(
      () => mcpToolSpecs(manifest),
      throwsA(isA<StateError>().having(
        (e) => e.toString(),
        'message',
        contains('a.b.c'),
      )),
    );
  });

  test('a name longer than 64 characters throws', () {
    final manifest = manifestWith('a' * 70, 'f');
    expect(
      () => mcpToolSpecs(manifest),
      throwsA(isA<StateError>().having(
        (e) => e.toString(),
        'message',
        allOf(contains('64'), contains('72 characters')),
      )),
    );
  });

  test('a hidden binding is not a spec and resolves to null', () {
    final manifest = manifestWith('door', 'lock');
    expect(resolveMcpToolCall(manifest, 'home.front.door.lock'), isNull);
  });
}
