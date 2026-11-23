// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert' show jsonEncode;

import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart' show testGeneration;

void main() {
  group('MemoryEnvelope', () {
    test('round-trips through toJson / fromJson, including generation', () {
      final envelope = MemoryEnvelope(
        generation: testGeneration,
        id: 'cart',
        revision: 3,
        updatedAt: DateTime.utc(2026, 11, 23, 12, 30),
        payload: {'items': [1, 2]},
        codec: 'json',
        sourceCellId: 'nucleus:x',
      );
      final restored = MemoryEnvelope.fromJson(envelope.toJson());
      expect(restored.id, envelope.id);
      expect(restored.kind, envelope.kind);
      expect(restored.revision, envelope.revision);
      expect(restored.generation, envelope.generation);
      expect(restored.schema, envelope.schema);
      expect(restored.updatedAt, envelope.updatedAt);
      expect(restored.payload, envelope.payload);
      expect(restored.codec, envelope.codec);
      expect(restored.sourceCellId, envelope.sourceCellId);
    });

    test('mintGeneration returns 32 lowercase hex characters, unique', () {
      final a = MemoryEnvelope.mintGeneration();
      final b = MemoryEnvelope.mintGeneration();
      expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(b, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(a, isNot(b));
    });

    test('omits null optionals', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: null)
              .toJson();
      expect(json.containsKey('codec'), isFalse);
      expect(json.containsKey('sourceCellId'), isFalse);
      expect(json['payload'], isNull);
    });

    test(
        'key order is stable: schema, id, kind, revision, generation, '
        'updatedAt, codec, sourceCellId, payload', () {
      final json = MemoryEnvelope(
        generation: testGeneration,
        id: 'a',
        revision: 1,
        payload: 1,
        codec: 'json',
        sourceCellId: 'nucleus:x',
      ).toJson();
      expect(json.keys.toList(), [
        'schema',
        'id',
        'kind',
        'revision',
        'generation',
        'updatedAt',
        'codec',
        'sourceCellId',
        'payload',
      ]);
    });

    test('a missing generation is MemoryCorrupt', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1).toJson()
            ..remove('generation');
      expect(() => MemoryEnvelope.fromJson(json),
          throwsA(isA<MemoryCorrupt>()));
    });

    test('an uppercase generation is MemoryCorrupt', () {
      expect(
        () => MemoryEnvelope(
            generation: '0123456789ABCDEF0123456789ABCDEF',
            id: 'a',
            revision: 1,
            payload: 1),
        throwsA(isA<MemoryCorrupt>()),
      );
    });

    test('a 31-character generation is MemoryCorrupt', () {
      expect(
        () => MemoryEnvelope(
            generation: '0123456789abcdef0123456789abcde',
            id: 'a',
            revision: 1,
            payload: 1),
        throwsA(isA<MemoryCorrupt>()),
      );
    });

    test('kind pulse is MemoryCorrupt', () {
      expect(
        () => MemoryEnvelope(
            generation: testGeneration,
            id: 'a',
            kind: 'pulse',
            revision: 1,
            payload: 1),
        throwsA(isA<MemoryCorrupt>()),
      );
    });

    test('sameContent is false when only the generation differs', () {
      final a = MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1);
      final b = MemoryEnvelope(
          generation: 'fedcba9876543210fedcba9876543210',
          id: 'a',
          revision: 1,
          payload: 1);
      expect(a.sameContent(b), isFalse);
    });

    test('two maps that differ only by key order have the same canonical '
        'payload and the same toJson bytes', () {
      final a = MemoryEnvelope(
        generation: testGeneration,
        id: 'a',
        revision: 1,
        payload: {'b': 1, 'a': 2},
      );
      final b = MemoryEnvelope(
        generation: testGeneration,
        id: 'a',
        revision: 1,
        payload: {'a': 2, 'b': 1},
      );
      expect(JsonPayloadKey.canonical(a.payload), JsonPayloadKey.canonical(b.payload));
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
      expect(a.sameContent(b), isTrue);
    });

    test('unknown schema throws MemoryCorrupt', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1).toJson()
            ..['schema'] = 2;
      expect(() => MemoryEnvelope.fromJson(json),
          throwsA(isA<MemoryCorrupt>()));
    });

    test('unknown key throws MemoryCorrupt', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1).toJson()
            ..['extra'] = true;
      expect(() => MemoryEnvelope.fromJson(json),
          throwsA(isA<MemoryCorrupt>()));
    });

    test('missing id throws MemoryCorrupt', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1).toJson()
            ..remove('id');
      expect(() => MemoryEnvelope.fromJson(json),
          throwsA(isA<MemoryCorrupt>()));
    });

    test('missing payload throws MemoryCorrupt', () {
      final json =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1).toJson()
            ..remove('payload');
      expect(() => MemoryEnvelope.fromJson(json),
          throwsA(isA<MemoryCorrupt>()));
    });

    test('updatedAt is UTC', () {
      final envelope = MemoryEnvelope(
        generation: testGeneration,
        id: 'a',
        revision: 1,
        updatedAt: DateTime.parse('2026-11-23T12:30:00+02:00'),
        payload: 1,
      );
      expect(envelope.updatedAt.isUtc, isTrue);
      expect(envelope.updatedAt.toIso8601String().endsWith('Z'), isTrue);
    });

    test('revision 0 is rejected', () {
      expect(
        () => MemoryEnvelope(
            generation: testGeneration, id: 'a', revision: 0, payload: 1),
        throwsA(isA<MemoryCorrupt>()),
      );
    });
  });
}
