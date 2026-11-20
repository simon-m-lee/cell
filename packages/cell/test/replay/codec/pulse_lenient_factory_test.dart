// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

// The factory's lenient interaction (Plan-lenient.md §8): overrides vs
// lenient fallbacks, and the re-encodability rules.

PulseEphemeralPolicy _policy() => PulseEphemeralPolicy(
      onEvent: (cell, {required policy}) => (hops: 0),
      onInvalidate: (pulse) => true,
    );

void main() {
  group('Pulse.fromJson — lenient interaction', () {
    test('lenient decode of a lenient-encoded pulse works and reports', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      final json = pulse.toJson(lenient: true);
      final skipped = <String>[];
      final decoded =
          Pulse.fromJson(json, lenient: true, onSkipped: skipped.addAll);
      expect(decoded.payload, 1);
      expect(skipped, ['onComplete']);
    });

    test('an override wins over the lenient fallback', () {
      final pulse = Pulse.governed(payload: 1, policy: _policy());
      final json = pulse.toJson(lenient: true);
      final reattached = Pulse.fromJson(
        json,
        lenient: true,
        policy: _policy(),
      );
      expect(reattached.policy, isNotNull);
    });

    test(
        'a decoded pulse with an onComplete override refuses strict '
        're-encode', () {
      final decoded = Pulse.fromJson(
        Pulse<int>(1).toJson(),
        onComplete: (_) {},
      );
      expect(() => decoded.toJson(), throwsA(isA<PulseNotSerializable>()));
    });

    test('the same override re-encodes leniently and records again', () {
      final decoded = Pulse.fromJson(
        Pulse<int>(1).toJson(),
        onComplete: (_) {},
      );
      final json = decoded.toJson(lenient: true);
      expect(json['__skipped__'], ['onComplete']);
    });

    test('a pulse decoded with lenient but no overrides re-encodes strict', () {
      final json =
          Pulse.governed(payload: 1, onComplete: (_) {}).toJson(lenient: true);
      final decoded = Pulse.fromJson(json, lenient: true);
      expect(decoded.toJson(), isA<Map<String, dynamic>>());
      expect(decoded.toJson(), isNot(contains('__skipped__')));
    });
  });
}
