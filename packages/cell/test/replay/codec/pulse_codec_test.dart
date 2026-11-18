// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  group('encodePulse — non-serializable fields', () {
    test('onComplete fails loudly', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      expect(
        () => encodePulse(pulse as PulseBase),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onComplete'),
        ),
      );
    });

    test('onError fails loudly', () {
      final pulse = Pulse.governed(
        payload: 1,
        onError: (pulse, error, {stackTrace}) {},
      );
      expect(
        () => encodePulse(pulse as PulseBase),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onError'),
        ),
      );
    });

    test('onProgress fails loudly', () {
      final pulse = Pulse.governed(
        payload: 1,
        onProgress: (pulse, cell, {message}) {},
      );
      expect(
        () => encodePulse(pulse as PulseBase),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onProgress'),
        ),
      );
    });

    test('policy fails loudly', () {
      final pulse = Pulse.governed(
        payload: 1,
        policy: PulseEphemeralPolicy(
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) => true,
        ),
      );
      expect(
        () => encodePulse(pulse as PulseBase),
        throwsA(
          isA<PulseNotSerializable>().having((e) => e.field, 'field', 'policy'),
        ),
      );
    });

    test('a non-JSON-encodable payload fails loudly', () {
      final pulse = Pulse<Object>(Object());
      expect(
        () => encodePulse(pulse as PulseBase),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'payload'),
        ),
      );
    });

    test('a callback deep in the parent chain fails loudly', () {
      final root = Pulse.governed(payload: 1, onComplete: (_) {});
      final leaf = root.evolve(pulse: Pulse<int>(2, step: 'derived'));
      expect(
        () => encodePulse(leaf as PulseBase),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onComplete'),
        ),
      );
    });
  });

  group('decodePulse — decode failures', () {
    test('missing version discriminator', () {
      expect(
        () => decodePulse({'payload': 1}),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('unsupported version', () {
      expect(
        () => decodePulse({
          '__pulse__': '2.0.0',
          'payload': 1,
          'timestamp': '2026-11-17T09:14:32.000Z',
          'context': <String, Object?>{},
        }),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('malformed context', () {
      expect(
        () => decodePulse({
          '__pulse__': '1.0.0',
          'payload': 1,
          'timestamp': '2026-11-17T09:14:32.000Z',
          'context': 'not-a-map',
        }),
        throwsA(isA<PulseDecodeError>()),
      );
    });
  });

  group('encodePulse — round-trips', () {
    test('plain Pulse<int>', () {
      final pulse = Pulse<int>(7, type: 'count', priority: 42);
      final decoded = decodePulse(encodePulse(pulse as PulseBase));
      expect(decoded.payload, 7);
      expect(decoded.type, 'count');
      expect(decoded.priority, 42);
      expect(decoded.isComposite, isFalse);
    });

    test('governed pulse keeps its context', () {
      final context = PulseContext.fromEntries([
        Provenance.actor.entry('agent_7'),
        Provenance.confidence.entry(0.85),
        Provenance.compliance.entry('GDPR'),
      ]);
      final pulse = Pulse.governed(
        payload: 'token',
        type: 'session',
        context: context,
        priority: 60,
      );
      final decoded = decodePulse(encodePulse(pulse as PulseBase));
      expect(decoded.context.actor, 'agent_7');
      expect(decoded.context.confidence, 0.85);
      expect(decoded.context.compliance, 'GDPR');
      expect(decoded.priority, 60);
    });

    test('parent chain round-trips with the full trace', () {
      final root = Pulse<int>(1, step: 'root');
      final mid = root.evolve(pulse: Pulse<int>(2, step: 'mid'));
      final leaf = mid.evolve(pulse: Pulse<int>(3, step: 'leaf'));
      final decoded = decodePulse(encodePulse(leaf as PulseBase));
      expect(decoded.payload, 3);
      expect(decoded.trace, ['root', 'mid', 'leaf']);
      expect(decoded.root.payload, 1);
    });

    test('a 10-level parent chain round-trips', () {
      var pulse = Pulse<dynamic>(0, step: 's0');
      for (var i = 1; i <= 10; i++) {
        pulse = pulse.evolve(pulse: Pulse<int>(i, step: 's$i'));
      }
      final decoded = decodePulse(encodePulse(pulse as PulseBase));
      expect(decoded.trace, [for (var i = 0; i <= 10; i++) 's$i']);
    });

    test('collective pulse round-trips its children', () {
      final batch = Pulse.batch<int>(
        [Pulse<int>(1), Pulse<int>(2), Pulse<int>(3)],
        type: 'batch',
      );
      final json = encodePulse(batch as PulseBase);
      expect(json['isComposite'], isTrue);
      final decoded = decodePulse(json);
      expect(decoded.isComposite, isTrue);
      expect((decoded.payload as Iterable<Pulse<dynamic>>).length, 3);
      expect(decoded.type, 'batch');
      expect(
        [for (final child in decoded.payload as Iterable) child.payload],
        [1, 2, 3],
      );
    });

    test('a null payload round-trips', () {
      final pulse = Pulse<int?>(null);
      final decoded = decodePulse(encodePulse(pulse as PulseBase));
      expect(decoded.payload, isNull);
    });

    test('a DateTime payload encodes to millisecond ISO-8601', () {
      final pulse = Pulse<DateTime>(DateTime.utc(2026, 11, 17, 9, 14, 32, 456));
      final json = encodePulse(pulse as PulseBase);
      expect(json['payload'], '2026-11-17T09:14:32.456Z');
    });

    test('List and Map payloads round-trip', () {
      final listPulse = Pulse<List<int>>([3, 1, 2]);
      expect(
          decodePulse(encodePulse(listPulse as PulseBase)).payload, [3, 1, 2]);
      final mapPulse = Pulse<Map<String, int>>({'b': 2, 'a': 1});
      final decodedMap =
          decodePulse(encodePulse(mapPulse as PulseBase)).payload;
      expect(decodedMap, {'b': 2, 'a': 1});
    });

    test('non-String types encode as null', () {
      final pulse = Pulse<int>(1, type: Object());
      expect(encodePulse(pulse as PulseBase)['type'], isNull);
    });
  });

  group('canonicality', () {
    test('logically-equal pulses produce identical bytes', () {
      final a = Pulse<int>(1, type: 't', priority: 3);
      final b = Pulse<int>(1, type: 't', priority: 3);
      final bytesA = canonicalJsonEncode(encodePulse(a as PulseBase));
      final bytesB = canonicalJsonEncode(encodePulse(b as PulseBase));
      expect(bytesA, bytesB);
    });

    test('re-encoding a decoded pulse is byte-identical', () {
      final context = PulseContext.fromEntries([
        Provenance.actor.entry('agent'),
        Provenance.confidence.entry(0.5),
      ]);
      final pulse = Pulse.governed(
        payload: {
          'k': [1, 2]
        },
        type: 'structured',
        context: context,
        priority: 9,
      );
      final first = canonicalJsonEncode(encodePulse(pulse as PulseBase));
      final decoded = decodePulse(encodePulse(pulse as PulseBase));
      final second = canonicalJsonEncode(encodePulse(decoded));
      expect(second, first);
    });
  });
}
