// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Whitelist warnings tell the truth.
///
/// `SkinUnlisted.hide` (the default) is quiet about bindings it
/// intentionally omits; `SkinUnlisted.expose` is the opt-in that makes
/// unmentioned bindings reachable — and warns about each one, once, at
/// open. The typo warning is identical in both modes, and a duplicate
/// registration still throws.
library;

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  SkinWhitelist thermostatOnly({SkinUnlisted unlisted = SkinUnlisted.hide}) =>
      SkinWhitelist(
        {
          'home.living.thermostat': {'setTarget'},
          // Mentioned, so its functions stay hidden and silent in both
          // modes — dim sits on a cell the map mentions.
          'home.living.light': <String>{},
        },
        unlisted: unlisted,
      );

  test('hide is quiet about the bindings it omits', () async {
    final warnings = <String>[];
    final f = await SkinFixture.build(
      whitelist: thermostatOnly(),
      onPolicyWarning: warnings.add,
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    expect(warnings, isEmpty);
    expect(f.membrane.isExposed('home.front.door'), isFalse);
    expect(f.membrane.isExposed('home.living.light'), isFalse);
  });

  test('expose warns about what it will expose — and means it', () async {
    final warnings = <String>[];
    final f = await SkinFixture.build(
      whitelist: thermostatOnly(unlisted: SkinUnlisted.expose),
      onPolicyWarning: warnings.add,
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final lockWarnings = warnings.where((w) =>
        w.contains('home.front.door.lock') && w.contains('will be exposed'));
    expect(lockWarnings, hasLength(1),
        reason: 'one warning per unmentioned binding');
    expect(
      warnings.any((w) => w.contains('setTarget')),
      isFalse,
      reason: 'listed bindings are not warned about',
    );
    expect(f.membrane.isExposed('home.front.door'), isTrue);
    // dim sits on a cell the map does mention, so it stays hidden and
    // silent in both modes. The unmentioned color cell, in contrast, is
    // exposed and warned about like the door.
    expect(f.membrane.isExposed('home.living.light'), isFalse);
    expect(warnings.any((w) => w.contains('dim')), isFalse);
    expect(
      warnings.any((w) =>
          w.contains('home.living.light.color.setColor') &&
          w.contains('will be exposed')),
      isTrue,
    );
  });

  test('the typo warning is identical in both modes', () async {
    for (final unlisted in SkinUnlisted.values) {
      final warnings = <String>[];
      final f = await SkinFixture.build(
        whitelist: SkinWhitelist(
          {
            'home.living.thermostat': {'setTarget'},
            'home.living.thermostt': {'explodeTypo'},
          },
          unlisted: unlisted,
        ),
        onPolicyWarning: warnings.add,
      );
      await f.membrane.close();
      await f.ledger.close();

      final typos = warnings
          .where((w) => w.contains('explodeTypo') && w.contains('likely a typo'));
      expect(typos, hasLength(1), reason: '$unlisted');
      expect(typos.single, contains('whitelist entry "home.living.thermostt.explodeTypo" has no registered binding (likely a typo)'));
    }
  });

  test('a duplicate registration still throws', () async {
    final table = SkinBindingTable();
    final binding = SkinBinding.state(
      cellId: 'dup.cell',
      functionName: 'f',
      target: Cell.state<int>(initial: 0).cell,
      nextValue: (int v) => v,
    );
    table.register(binding);
    expect(() => table.register(binding), throwsStateError);
  });
}
