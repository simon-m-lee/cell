// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  PromptConfig configWith(String id, String version, String prompt) =>
      PromptConfig.custom(
        id: id,
        version: version,
        description: 'test',
        systemPrompt: prompt,
        userTemplate: '{{context}}',
      );

  tearDown(() {
    for (final config in PromptConfigRegistry.list()) {
      PromptConfigRegistry.unregister(config.id);
    }
  });

  group('PromptConfigRegistry', () {
    test('register + lookup returns the same instance', () {
      final config = configWith('a', '1.0.0', 'p');
      PromptConfigRegistry.register(config);
      expect(identical(PromptConfigRegistry.lookup('a'), config), isTrue);
    });

    test('lookup with no version resolves the highest semver', () {
      PromptConfigRegistry.register(configWith('b', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('b', '1.9.0', 'v1.9'));
      PromptConfigRegistry.register(configWith('b', '1.10.0', 'v1.10'));
      expect(PromptConfigRegistry.lookup('b')!.version, '1.10.0');
    });

    test('lookup with a version resolves exactly', () {
      PromptConfigRegistry.register(configWith('c', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('c', '2.0.0', 'v2'));
      expect(PromptConfigRegistry.lookup('c', version: '1.0.0')!.systemPrompt,
          'v1');
      expect(PromptConfigRegistry.lookup('c', version: '2.0.0')!.systemPrompt,
          'v2');
    });

    test('lookup for an unknown id returns null', () {
      expect(PromptConfigRegistry.lookup('absent'), isNull);
    });

    test('lookup for an unknown version returns null', () {
      PromptConfigRegistry.register(configWith('d', '1.0.0', 'v1'));
      expect(PromptConfigRegistry.lookup('d', version: '9.9.9'), isNull);
    });

    test('list with an id returns only that config family', () {
      PromptConfigRegistry.register(configWith('e', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('e', '2.0.0', 'v2'));
      PromptConfigRegistry.register(configWith('f', '1.0.0', 'other'));
      expect(PromptConfigRegistry.list(id: 'e'), hasLength(2));
      expect(
        PromptConfigRegistry.list(id: 'e').map((c) => c.id).toSet(),
        {'e'},
      );
    });

    test('list without an id returns every registered config', () {
      PromptConfigRegistry.register(configWith('g', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('h', '1.0.0', 'v2'));
      expect(PromptConfigRegistry.list(), hasLength(2));
    });

    test('unregister with a version removes only that version', () {
      PromptConfigRegistry.register(configWith('i', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('i', '2.0.0', 'v2'));
      PromptConfigRegistry.unregister('i', version: '1.0.0');
      expect(PromptConfigRegistry.lookup('i')!.version, '2.0.0');
    });

    test('unregister without a version removes the whole family', () {
      PromptConfigRegistry.register(configWith('j', '1.0.0', 'v1'));
      PromptConfigRegistry.register(configWith('j', '2.0.0', 'v2'));
      PromptConfigRegistry.unregister('j');
      expect(PromptConfigRegistry.lookup('j'), isNull);
    });

    test('registering the same id+version replaces the previous config', () {
      final first = configWith('k', '1.0.0', 'first');
      final second = configWith('k', '1.0.0', 'second');
      PromptConfigRegistry.register(first);
      PromptConfigRegistry.register(second);
      expect(PromptConfigRegistry.lookup('k')!.systemPrompt, 'second');
    });

    test('semver resolution handles multi-digit components', () {
      PromptConfigRegistry.register(configWith('semver', '1.9.0', 'a'));
      PromptConfigRegistry.register(configWith('semver', '1.10.0', 'b'));
      PromptConfigRegistry.register(configWith('semver', '2.0.0', 'c'));
      expect(PromptConfigRegistry.lookup('semver')!.version, '2.0.0');
    });

    test('registry drives A/B-style rollback via configVersion pinning', () {
      PromptConfigRegistry.register(configWith('ab', '1.0.0', 'stable'));
      PromptConfigRegistry.register(configWith('ab', '1.1.0', 'candidate'));
      expect(PromptConfigRegistry.lookup('ab')!.systemPrompt, 'candidate');
      expect(
        PromptConfigRegistry.lookup('ab', version: '1.0.0')!.systemPrompt,
        'stable',
      );
    });
  });
}
