// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('Verdict serialization', () {
    test('Accept round-trips through toMap/verdictFromMap', () {
      final verdict = const Accept({'rule': 'domain'});
      final restored = verdictFromMap(verdict.toMap());
      expect(restored, isA<Accept>());
      expect((restored as Accept).annotations, {'rule': 'domain'});
    });

    test('Reject round-trips with its reason', () {
      final verdict = const Reject('out-of-domain', {'hint': 'finance only'});
      final restored = verdictFromMap(verdict.toMap());
      expect(restored, isA<Reject>());
      final reject = restored as Reject;
      expect(reject.reason, 'out-of-domain');
      expect(reject.annotations, {'hint': 'finance only'});
    });

    test('Defer round-trips with its resolver name', () {
      final verdict = const Defer('approval', {'threshold': 1000});
      final restored = verdictFromMap(verdict.toMap());
      expect(restored, isA<Defer>());
      final defer = restored as Defer;
      expect(defer.resolver, 'approval');
      expect(defer.annotations, {'threshold': 1000});
    });

    test('unknown type throws ArgumentError', () {
      expect(
        () => verdictFromMap({'type': 'maybe'}),
        throwsArgumentError,
      );
    });

    test('default annotations are the empty map', () {
      expect(const Accept().annotations, isEmpty);
      expect(const Reject('r').annotations, isEmpty);
      expect(const Defer('d').annotations, isEmpty);
    });
  });
}
