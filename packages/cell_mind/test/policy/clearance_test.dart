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
  Cell linkCell() => Cell.ingress<int>().cell;

  group('clearancePolicy', () {
    test('accepts pulse reception at standard clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy();
      expect(await policy.call(governedPulse(), host: host), isTrue);
    });

    test('rejects pulse reception at observational clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.observational));
      final policy = clearancePolicy();
      expect(await policy.call(governedPulse(), host: host), isFalse);
    });

    test('accepts actions at standard clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy();
      expect(await policy.call(someFunction, host: host), isTrue);
    });

    test('rejects actions at minimal clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.minimal));
      final policy = clearancePolicy();
      expect(await policy.call(someFunction, host: host), isFalse);
    });

    test('accepts links at administrative clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.administrative));
      final policy = clearancePolicy();
      expect(await policy.call(linkCell(), host: host), isTrue);
    });

    test('rejects links at standard clearance', () async {
      final host = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy();
      expect(await policy.call(linkCell(), host: host), isFalse);
    });

    test('honours custom requirement overrides', () async {
      final host = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy(requirements: {
        ApplyCategory.pureAction: Clearance.privileged,
      });
      expect(await policy.call(someFunction, host: host), isFalse);
      final privileged = hostWith(ctxWithClearance(Clearance.privileged));
      expect(await policy.call(someFunction, host: privileged), isTrue);
    });

    test('honours the custom categoryResolver', () async {
      final standard = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy(
        categoryResolver: (function) => function == mount
            ? ApplyCategory.structuralAction
            : ApplyCategory.pureAction,
      );
      // `someFunction` is a pure action (standard required) — allowed.
      expect(await policy.call(someFunction, host: standard), isTrue);
      // `mount` is classified structural (administrative required) —
      // rejected at standard clearance.
      expect(await policy.call(mount, host: standard), isFalse);
      // ...and accepted at administrative clearance.
      final admin = hostWith(ctxWithClearance(Clearance.administrative));
      expect(await policy.call(mount, host: admin), isTrue);
    });

    test('passes unknown object types through', () async {
      final host = hostWith(ctxWithClearance(Clearance.standard));
      final policy = clearancePolicy();
      expect(await policy.call('a string', host: host), isTrue);
    });
  });
}

int someFunction(int x) => x;
void mount() {}
