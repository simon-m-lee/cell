// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  final host = Cell.ingress<int>().cell;

  group('predicatePolicy', () {
    test('accepts when the predicate returns true', () async {
      final policy = predicatePolicy(
        (object, {required host}) =>
            object is Pulse && (object.payload as int) >= 0,
      );
      expect(await policy.call(governedPulse(payload: 42), host: host), isTrue);
    });

    test('rejects when the predicate returns false', () async {
      final policy = predicatePolicy(
        (object, {required host}) =>
            object is Pulse && (object.payload as int) >= 0,
      );
      expect(
          await policy.call(governedPulse(payload: -1), host: host), isFalse);
    });

    test('receives the action object itself', () async {
      Function? seenFunction;
      final policy = predicatePolicy(
        (object, {required host}) {
          seenFunction = object as Function;
          return true;
        },
      );
      await policy.call(someFunction, host: host);
      expect(seenFunction, same(someFunction));
    });

    test('fails closed when the host is null', () async {
      final policy = predicatePolicy(
        (object, {required host}) => true,
      );
      expect(await policy.call(governedPulse()), isFalse);
    });

    test('composes with built-in policies', () async {
      final financeHost = Cell.ingress<int>(
        context: ctxWithDomains('finance'),
      ).cell;
      final policy = domainPolicy() +
          predicatePolicy(
            (object, {required host}) =>
                object is! Pulse || (object.payload as int) != 13,
          );
      expect(
        await policy.call(governedPulse(payload: 13, domains: 'finance'),
            host: financeHost),
        isFalse,
        reason: 'The custom predicate rejects the unlucky payload.',
      );
      expect(
        await policy.call(governedPulse(payload: 42, domains: 'finance'),
            host: financeHost),
        isTrue,
      );
    });
  });
}

int someFunction(int x) => x;
