// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

// Lenient decode — the narrow reference-resolution rules of
// Plan-lenient.md §6. Lenient suppresses PulseDecodeError ONLY where a
// reference or codec resolution fails; structural corruption always
// throws.

Map<String, dynamic> _envelope({
  Object? payload = 1,
  Object? context,
  Object? parent,
  Object? children,
  Object? version = '1.0.0',
  Object? timestamp = '2026-11-17T09:14:32.000Z',
  List<String>? skipped,
}) =>
    {
      '__pulse__': version,
      'payload': payload,
      'type': null,
      'timestamp': timestamp,
      'source': null,
      'priority': 20,
      'context': context ?? PulseContextCodec.toJson(PulseContext.system),
      'step': null,
      'user': null,
      'parent': parent,
      'isComposite': false,
      'children': children,
      if (skipped != null) '__skipped__': skipped,
    };

Map<String, dynamic> _userOf(PulseBase pulse) =>
    (pulse.toJson()['user'] as Map).cast<String, dynamic>();

void main() {
  group('lenient decode — structural corruption still throws', () {
    test('missing __pulse__', () {
      expect(
        () => decodePulse({'payload': 1}, lenient: true),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('unsupported version', () {
      expect(
        () => decodePulse(_envelope(version: '2.0.0'), lenient: true),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('malformed parent', () {
      expect(
        () => decodePulse(_envelope(parent: 'nope'), lenient: true),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('malformed children', () {
      expect(
        () => decodePulse(
          {
            ..._envelope(),
            'isComposite': true,
            'children': 'nope',
          },
          lenient: true,
        ),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('malformed timestamp', () {
      expect(
        () => decodePulse(_envelope(timestamp: 'nope'), lenient: true),
        throwsA(isA<PulseDecodeError>()),
      );
    });
  });

  group('lenient decode — reference resolution', () {
    test('a context codec mismatch substitutes system and records', () {
      final json = _envelope(
        context: {'lineage': 'not-a-list'},
      );
      expect(
        () => decodePulse(json),
        throwsA(isA<PulseDecodeError>()),
      );
      final skipped = <String>[];
      final decoded = decodePulse(
        json,
        lenient: true,
        onSkipped: skipped.addAll,
      );
      expect(
        canonicalJsonEncode(PulseContextCodec.toJson(decoded.context)),
        canonicalJsonEncode(PulseContextCodec.toJson(PulseContext.system)),
      );
      expect(skipped, ['context']);
      final user = _userOf(decoded);
      expect(user['__skipped__'], {
        'wire': <String>[],
        'decode': ['context'],
      });
    });

    test('an unresolved source stays null (unchanged from the base plan)', () {
      final source = Cell.ingress<int>();
      final json = Pulse<int>(1, source: source.cell).toJson();
      final decoded = decodePulse(json, lenient: true);
      expect(decoded.source, isNull);
    });

    test('wire __skipped__ is preserved in user and aggregated', () {
      final json = _envelope(skipped: ['onComplete', 'policy']);
      final skipped = <String>[];
      final decoded = decodePulse(
        json,
        lenient: true,
        onSkipped: skipped.addAll,
      );
      expect(skipped, ['onComplete', 'policy']);
      final user = _userOf(decoded);
      expect(user['__skipped__'], {
        'wire': ['onComplete', 'policy'],
        'decode': <String>[],
      });
    });

    test('parent-chain skips produce qualified paths', () {
      final parentJson = _envelope(skipped: ['onComplete']);
      final json = _envelope(parent: parentJson, skipped: ['policy']);
      final skipped = <String>[];
      final decoded = decodePulse(
        json,
        lenient: true,
        onSkipped: skipped.addAll,
      );
      expect(decoded.payload, 1);
      expect(skipped, ['policy', 'parent.onComplete']);
    });

    test('onSkipped is not invoked in strict mode', () {
      final json = _envelope(skipped: ['policy']);
      final calls = <List<String>>[];
      decodePulse(json, onSkipped: calls.add);
      expect(calls, isEmpty);
    });
  });

  group('lenient round-tripping', () {
    test('lenient encode → strict decode does not throw', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      final json = pulse.toJson(lenient: true);
      final decoded = decodePulse(json);
      final user = _userOf(decoded);
      expect(user['__skipped__'], {
        'wire': ['onComplete'],
        'decode': <String>[],
      });
    });

    test('lenient encode → strict decode → strict re-encode round-trips', () {
      final pulse = Pulse.governed(payload: 1, onComplete: (_) {});
      final json = pulse.toJson(lenient: true);
      final decoded = decodePulse(json);
      // The decoded pulse has null callbacks/policy — the strict
      // re-encode succeeds and round-trips.
      final reencoded = decoded.toJson();
      expect(reencoded['payload'], 1);
      expect(reencoded, isNot(contains('__skipped__')));
      final again = decodePulse(reencoded);
      expect(again.payload, 1);
    });

    test('a leniently-decoded pulse with no overrides re-encodes strict', () {
      final json = _envelope(
        context: {'lineage': 'not-a-list'},
      );
      final decoded = decodePulse(json, lenient: true);
      final reencoded = decoded.toJson();
      expect(reencoded, isA<Map<String, dynamic>>());
    });
  });
}
