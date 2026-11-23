// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Document mapping, exercised with no Firestore instance. The wire format:
// `payload` is always a JSON string; `updatedAt` is a server timestamp on
// the wire and a UTC DateTime on the envelope; null optionals are omitted.

import 'dart:convert' show jsonEncode;

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory_firebase/src/firebase_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the core test harness's generation: one fixed life.
const String testGeneration = '0123456789abcdef0123456789abcdef';

void main() {
  group('encodeDocument', () {
    test('payload is always a JSON string, including null, list, map',
        () {
      for (final payload in <Object?>[
        null,
        false,
        7,
        'hello',
        [1, 2],
        {'a': 1},
      ]) {
        final doc = encodeDocument(
            MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: payload));
        expect(doc['payload'], isA<String>(), reason: '$payload');
      }
    });

    test('a string payload whose characters are [1, 2] stays a string', () {
      final doc = encodeDocument(
          MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: '[1, 2]'));
      expect(doc['payload'], '"[1, 2]"');
      expect(doc['payload'], isNot('[1, 2]'));
    });

    test('omits null codec and sourceCellId; server-timestamps updatedAt',
        () {
      final doc = encodeDocument(
          MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1, codec: 'json'));
      expect(doc.containsKey('codec'), isTrue);
      expect(doc.containsKey('sourceCellId'), isFalse);
      expect(doc['updatedAt'], isA<FieldValue>());

      final bare =
          encodeDocument(MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1));
      expect(bare.containsKey('codec'), isFalse);
      expect(bare.containsKey('sourceCellId'), isFalse);
    });

    test('the document contains the generation', () {
      final doc = encodeDocument(
          MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1));
      expect(doc['generation'], testGeneration);
    });

    test('payload is stored canonically: {"b": 1, "a": 2} serialises with '
        'the a key first', () {
      final doc = encodeDocument(MemoryEnvelope(
          generation: testGeneration,
          id: 'x',
          revision: 1,
          payload: {'b': 1, 'a': 2}));
      expect(doc['payload'], jsonEncode({'a': 2, 'b': 1}));
      // A reversed-key retry therefore matches the stored string.
      final retry = encodeDocument(MemoryEnvelope(
          generation: testGeneration,
          id: 'x',
          revision: 1,
          payload: {'a': 2, 'b': 1}));
      expect(retry['payload'], doc['payload']);
    });
  });

  group('decodeDocument', () {
    test('round-trips every JSON shape', () {
      for (final payload in <Object?>[
        null,
        false,
        7,
        'hello',
        [1, 2],
        {'a': 1},
      ]) {
        final envelope = MemoryEnvelope(generation: testGeneration, 
          id: 'x',
          revision: 3,
          payload: payload,
          codec: 'json',
          sourceCellId: 'nucleus:y',
        );
        final decoded = decodeDocument(
            'x', encodeDocument(envelope)..['updatedAt'] = Timestamp.fromDate(
                  DateTime.utc(2026, 11, 23, 12, 0),
                ));
        expect(decoded.payload, payload, reason: '$payload');
        expect(decoded.revision, 3);
        expect(decoded.codec, 'json');
        expect(decoded.sourceCellId, 'nucleus:y');
        expect(decoded.updatedAt.isUtc, isTrue);
      }
    });

    test('the string "[1, 2]" decodes as a string, not a list', () {
      final envelope =
          MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: '[1, 2]');
      final decoded = decodeDocument(
          'x', encodeDocument(envelope)..['updatedAt'] = DateTime.now());
      expect(decoded.payload, isA<String>());
      expect(decoded.payload, '[1, 2]');
    });

    test('a missing payload throws MemoryCorrupt', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..remove('payload')
        ..['updatedAt'] = DateTime.now();
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });

    test('a missing generation throws MemoryCorrupt', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..remove('generation')
        ..['updatedAt'] = DateTime.now();
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });

    test('a non-string payload throws MemoryCorrupt', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..['payload'] = [1, 2]
        ..['updatedAt'] = DateTime.now();
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });

    test('a schema other than 1 throws MemoryCorrupt', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..['schema'] = 2
        ..['updatedAt'] = DateTime.now();
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });

    test('an id that does not match the path throws MemoryCorrupt', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..['id'] = 'y'
        ..['updatedAt'] = DateTime.now();
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });

    test('unknown keys throw MemoryCorrupt, matching the file envelope', () {
      final doc = encodeDocument(
              MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: 1))
        ..['updatedAt'] = DateTime.now()
        ..['extra'] = true;
      expect(() => decodeDocument('x', doc), throwsA(isA<MemoryCorrupt>()));
    });
  });
}
