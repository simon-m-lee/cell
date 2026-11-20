// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

// The consequences of lenient substitutions (Plan-lenient.md §7):
// dropped policy makes the pulse immortal, dropped callbacks remove
// the side effects, and both losses are recorded — never silent.
// (scrutinize is not constructible from the public API; the encoder's
// check is defensive, and the guide warns against lenient use there.)

PulseEphemeralPolicy _policy() => PulseEphemeralPolicy(
      onEvent: (cell, {required policy}) => (hops: 0),
      onInvalidate: (pulse) => true,
    );

void main() {
  group('consequences of lenient substitutions', () {
    test('dropped policy makes the pulse immortal — and records it', () {
      final governed = Pulse.governed(payload: 1, policy: _policy());
      expect(governed.policy, isNotNull);

      final json = governed.toJson(lenient: true);
      final decoded = Pulse.fromJson(json, lenient: true);
      expect(decoded.policy, isNull, reason: 'No TTL survives the wire.');
      expect(json['__skipped__'], ['policy']);
    });

    test('the recovery path re-attaches a policy via the override', () {
      final json =
          Pulse.governed(payload: 1, policy: _policy()).toJson(lenient: true);
      final recovered = Pulse.fromJson(json, policy: _policy());
      expect(recovered.policy, isNotNull);
    });

    test('dropped callbacks remove side effects — and record them', () {
      var fired = false;
      final json = Pulse.governed(
        payload: 1,
        onComplete: (_) => fired = true,
      ).toJson(lenient: true);

      final decoded = Pulse.fromJson(json, lenient: true);
      // The decoded pulse re-encodes in strict mode: no callback state
      // survived the wire.
      expect(decoded.toJson(), isNot(contains('__skipped__')));
      expect(json['__skipped__'], ['onComplete']);
      // The original callback belongs to the ORIGINAL pulse only.
      expect(fired, isFalse);
    });

    test('lenient mode never suppresses structural corruption', () {
      final governed = Pulse.governed(payload: 1, policy: _policy());
      final json = governed.toJson(lenient: true);
      json['__pulse__'] = '2.0.0';
      expect(
        () => Pulse.fromJson(json, lenient: true),
        throwsA(isA<PulseDecodeError>()),
      );
    });
  });
}
