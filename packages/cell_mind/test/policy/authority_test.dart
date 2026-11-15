// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  Cell hostWith(Context context) => Cell.ingress<int>(context: context).cell;

  group('authorityPolicy', () {
    test('accepts a verb present in the mandate whitelist', () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy();
      expect(await policy.call(read, host: host), isTrue);
    });

    test('rejects a verb absent from the mandate whitelist', () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy();
      expect(await policy.call(delete, host: host), isFalse);
    });

    test('accepts additionalVerbs beyond the mandate', () async {
      final host = hostWith(ctxWithAuthority('read'));
      final policy = authorityPolicy(additionalVerbs: {'delete'});
      expect(await policy.call(delete, host: host), isTrue);
    });

    test('accepts everything when no authority is declared', () async {
      final host = hostWith(Context.system);
      final policy = authorityPolicy();
      expect(await policy.call(delete, host: host), isTrue);
    });

    test('uses the custom verbResolver when provided', () async {
      final host = hostWith(ctxWithAuthority('CUSTOM_VERB'));
      final policy = authorityPolicy(
        verbResolver: (function) => function == read ? 'CUSTOM_VERB' : null,
      );
      expect(await policy.call(read, host: host), isTrue);
    });

    test('rejects anonymous lambdas (verb extraction fails closed)', () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy();
      // A local function is an anonymous closure: its toString carries no
      // "from Function 'name':" marker, so verb extraction fails.
      int addOne(int x) => x + 1;
      expect(await policy.call(addOne, host: host), isFalse);
    });

    test('rejects when the custom resolver cannot resolve', () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy(verbResolver: (function) => null);
      expect(await policy.call(read, host: host), isFalse);
    });

    test('passes non-function objects through', () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy();
      expect(
        await policy.call(governedPulse(domains: 'marketing'), host: host),
        isTrue,
      );
      expect(await policy.call(host, host: host), isTrue);
    });
  });

  group('exactFunctionsPolicy', () {
    test('accepts functions present in the whitelist', () async {
      final host = hostWith(Context.system);
      final policy = exactFunctionsPolicy({read, delete});
      expect(await policy.call(read, host: host), isTrue);
      expect(await policy.call(delete, host: host), isTrue);
    });

    test('rejects functions absent from the whitelist', () async {
      final host = hostWith(Context.system);
      final policy = exactFunctionsPolicy({read});
      expect(await policy.call(delete, host: host), isFalse);
    });

    test('passes non-function objects through', () async {
      final host = hostWith(Context.system);
      final policy = exactFunctionsPolicy({read});
      expect(await policy.call(governedPulse(), host: host), isTrue);
    });
  });

  group('authority composition', () {
    test('authorityPolicy + exactFunctionsPolicy narrows the surface',
        () async {
      final host = hostWith(ctxWithAuthority('read,write'));
      final policy = authorityPolicy() + exactFunctionsPolicy({read});
      expect(await policy.call(read, host: host), isTrue);
      // In the mandate AND whitelisted, but `write` is not in the exact set.
      expect(await policy.call(write, host: host), isFalse);
      expect(await policy.call(delete, host: host), isFalse);
    });
  });
}

int read(int x) => x;
void delete(int x) {}
void write(int x) {}
