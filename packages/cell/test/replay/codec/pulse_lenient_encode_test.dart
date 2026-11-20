// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

// Lenient encode — the substitution table of Plan-lenient.md §5.1.
// Every testable row asserts the substituted value AND the recorded
// `__skipped__` entry. `scrutinize` and empty-`id` sources are not
// constructible from the public API; the encoder's checks for them are
// defensive (reviewed, not unit-tested).

PulseEphemeralPolicy _policy() => PulseEphemeralPolicy(
      onEvent: (cell, {required policy}) => (hops: 0),
      onInvalidate: (pulse) => true,
    );

void main() {
  group('lenient encode — substitution table', () {
    test('onComplete → null, recorded', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['onComplete']);
    });

    test('onError → null, recorded', () {
      final pulse = Pulse.governed(
        payload: 1,
        onError: (pulse, error, {stackTrace}) {},
      );
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['onError']);
    });

    test('onProgress → null, recorded', () {
      final pulse = Pulse.governed(
        payload: 1,
        onProgress: (pulse, cell, {message}) {},
      );
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['onProgress']);
    });

    test('policy → null, recorded (the pulse becomes immortal)', () {
      final pulse = Pulse.governed(payload: 1, policy: _policy());
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['policy']);
    });

    test('non-JSON payload → null, recorded', () {
      final pulse = Pulse<Object>(Object());
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['payload']);
      expect(json['payload'], isNull);
    });

    test('non-String type → null, recorded (amendment)', () {
      final pulse = Pulse<int>(1, type: Object());
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], ['type']);
      expect(json['type'], isNull);
    });

    test('strict mode still throws for every suppressed field', () {
      expect(
        () => encodePulse(
          Pulse.governed(payload: 1, onComplete: (_) {}) as PulseBase,
        ),
        throwsA(isA<PulseNotSerializable>()),
      );
      expect(
        () => encodePulse(Pulse<Object>(Object()) as PulseBase),
        throwsA(isA<PulseNotSerializable>()),
      );
      expect(
        () => encodePulse(Pulse<int>(1, type: Object()) as PulseBase),
        throwsA(isA<PulseNotSerializable>()),
      );
    });
  });

  group('lenient encode — __skipped__ contract', () {
    test('multiple skipped fields are sorted lexicographically', () {
      // governed's type parameter is String?, so the non-String type row
      // is covered by its own single-field test above.
      final pulse = Pulse.governed(
        payload: Object(),
        onComplete: (_) {},
        policy: _policy(),
      );
      final json = encodePulse(pulse as PulseBase, lenient: true);
      expect(json['__skipped__'], [
        'onComplete',
        'payload',
        'policy',
      ]);
    });

    test('a fully-serialisable pulse is byte-identical to strict', () {
      final pulse = Pulse.governed(
        payload: {
          'a': 1,
          'b': [true, null]
        },
        type: 'save',
        priority: 30,
        context: PulseContext.fromEntries([
          Provenance.actor.entry('agent'),
        ]),
      );
      final strict = canonicalJsonEncode(encodePulse(pulse as PulseBase));
      final lenient = canonicalJsonEncode(
        encodePulse(pulse as PulseBase, lenient: true),
      );
      expect(lenient, strict);
      expect(
        encodePulse(pulse as PulseBase, lenient: true),
        isNot(contains('__skipped__')),
      );
    });

    test('parent-chain skips are recorded per level', () {
      final root = Pulse.governed(payload: 1, onComplete: (_) {});
      final leaf = root.evolve(
        pulse: Pulse.governed(payload: 2, policy: _policy()),
      );
      final json = encodePulse(leaf as PulseBase, lenient: true);
      final parent = json['parent'] as Map<String, dynamic>;
      expect(json['__skipped__'], ['policy']);
      expect(parent['__skipped__'], ['onComplete']);
    });

    test('Pulse.toJson(lenient: true) works through the extension', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      final json = pulse.toJson(lenient: true);
      expect(json['__skipped__'], ['onComplete']);
    });
  });
}
