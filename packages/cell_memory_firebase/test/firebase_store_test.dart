// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// `FirebaseMemoryStore` against the scripted double. No network, no
// Firebase project, no Java. A green run here is NOT rules coverage; the
// Node harness in tool/rules is what evaluates `firestore.rules`.

import 'dart:convert';
import 'dart:io';

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';
import 'package:cell_memory_firebase/cell_memory_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scripted_firestore.dart';

/// Mirrors the core test harness's generation: one fixed life, never
/// exported from the package.
const String testGeneration = '0123456789abcdef0123456789abcdef';

/// A second, distinct well-formed generation.
const String testGenerationB = 'fedcba9876543210fedcba9876543210';

const uid = 'user-a';

FirebaseMemoryStore store(ScriptedFirestore db) =>
    FirebaseMemoryStore(firestore: db, uid: uid);

Map<String, dynamic> docAt(int revision, Object? payload,
        {String kind = 'value', String? codec = 'json'}) =>
    {
      'schema': 1,
      'generation': testGeneration,
      'id': 'counter',
      'kind': kind,
      'revision': revision,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 23)),
      'payload': jsonEncode(payload),
      if (codec != null) 'codec': codec,
    };

void main() {
  late ScriptedFirestore db;

  setUp(() {
    db = ScriptedFirestore();
  });

  test('read of a missing document returns null and creates nothing',
      () async {
    final s = store(db);
    expect(await s.read('counter'), isNull);
    expect(db.docs, isEmpty);
  });

  test('create: expectedRevision 0 writes revision 1 with a JSON-string '
      'payload', () async {
    final s = store(db);
    await s.write(
      MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: {'n': 1}),
      expectedRevision: 0,
    );
    final doc = db.docs['users/$uid/cell_memory/counter']!;
    expect(doc['revision'], 1);
    expect(doc['payload'], jsonEncode({'n': 1}));
    expect(doc['payload'], isA<String>());
  });

  test('round-trip: read returns the envelope with the payload decoded',
      () async {
    final s = store(db);
    await s.write(
      MemoryEnvelope(generation: testGeneration, 
          id: 'counter', revision: 1, payload: [1, 2], codec: 'json'),
      expectedRevision: 0,
    );
    final read = await s.read('counter');
    expect(read, isNotNull);
    expect(read!.payload, [1, 2]);
    expect(read.revision, 1);
    expect(read.codec, 'json');
    expect(read.updatedAt.isUtc, isTrue);
  });

  test('CAS: expecting 4 installs 5; a second writer still expecting 4 '
      'gets MemoryConflict and the document stays the winner', () async {
    db.seed(uid, 'counter', docAt(4, 100));
    final s = store(db);

    await s.write(
      MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 5, payload: 101),
      expectedRevision: 4,
    );
    expect(db.docs['users/$uid/cell_memory/counter']!['revision'], 5);
    expect(db.docs['users/$uid/cell_memory/counter']!['payload'],
        jsonEncode(101));

    await expectLater(
      s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 5, payload: 999),
        expectedRevision: 4,
      ),
      throwsA(isA<MemoryConflict>()),
    );
    expect(db.docs['users/$uid/cell_memory/counter']!['payload'],
        jsonEncode(101));
  });

  test('idempotent retry: this writer payload at expectedRevision + 1 '
      'returns success and does not set again', () async {
    db.seed(uid, 'counter', docAt(5, {'n': 1}));
    db.runHandlerTwice = true;
    final s = store(db);

    await s.write(
      MemoryEnvelope(generation: testGeneration, 
          id: 'counter', revision: 5, payload: {'n': 1}, codec: 'json'),
      expectedRevision: 4,
    );
    expect(db.handlerRuns, 2);
    expect(db.setCalls, 0,
        reason: 'the retry saw its own payload and returned without set');
    expect(db.docs['users/$uid/cell_memory/counter']!['revision'], 5);
  });

  test('lost race: a different payload at expectedRevision + 1 throws '
      'MemoryConflict and never sets', () async {
    db.seed(uid, 'counter', docAt(5, 'other-writer'));
    final s = store(db);

    await expectLater(
      s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 5, payload: 'mine'),
        expectedRevision: 4,
      ),
      throwsA(isA<MemoryConflict>()),
    );
    expect(db.setCalls, 0);
    expect(db.docs['users/$uid/cell_memory/counter']!['payload'],
        jsonEncode('other-writer'));
  });

  test('an envelope numbered wrong throws MemoryCorrupt and never sets',
      () async {
    db.seed(uid, 'counter', docAt(4, 1));
    final s = store(db);
    await expectLater(
      s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 9, payload: 1),
        expectedRevision: 4,
      ),
      throwsA(isA<MemoryCorrupt>()),
    );
    expect(db.setCalls, 0);
    expect(db.handlerRuns, 0);
  });

  test('permission denied surfaces as MemoryIoException and is not '
      'retried as contention', () async {
    db.permissionDenied = true;
    final s = store(db);
    await expectLater(
      s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 1),
        expectedRevision: 0,
      ),
      throwsA(isA<MemoryIoException>()),
    );
    expect(db.handlerRuns, 1);
  });

  test('remove deletes the document; a second remove succeeds', () async {
    db.seed(uid, 'counter', docAt(1, 1));
    final s = store(db);
    await s.remove('counter');
    expect(db.docs.containsKey('users/$uid/cell_memory/counter'), isFalse);
    await s.remove('counter');
  });

  test('list returns ids under this uid only', () async {
    db.seed(uid, 'a', docAt(1, 1));
    db.seed(uid, 'b', docAt(1, 2));
    db.seed('user-b', 'c', docAt(1, 3));
    final s = store(db);
    expect(await s.list(), unorderedEquals(['a', 'b']));
  });

  test('closed: read after close throws StateError; double close throws',
      () async {
    final s = store(db);
    await s.close();
    await expectLater(s.read('counter'), throwsA(isA<StateError>()));
    await expectLater(s.close(), throwsA(isA<StateError>()));
  });

  test('uid validation rejects empty ids and slashes', () {
    expect(() => FirebaseMemoryStore(firestore: db, uid: ''),
        throwsA(isA<ArgumentError>()));
    expect(() => FirebaseMemoryStore(firestore: db, uid: 'a/b'),
        throwsA(isA<ArgumentError>()));
  });

  test('memory id validation rejects hostile ids before any request', () {
    final s = store(db);
    for (final bad in ['../x', 'a/b', '', '.', '..', 'x' * 129]) {
      expect(() => s.read(bad), throwsA(isA<ArgumentError>()),
          reason: 'id "$bad" must be rejected');
    }
    expect(db.docs, isEmpty);
  });

  test('the same envelope fixture round-trips through the file store and '
      'the firestore store', () async {
    final dir = await Directory.systemTemp.createTemp('cell_memory_firebase');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final fixtures = <Object?>[
      {'n': 1},
      [1, 2, 3],
      null,
      'plain string',
    ];
    for (final payload in fixtures) {
      final envelope = MemoryEnvelope(generation: testGeneration, 
        id: 'counter',
        revision: 1,
        payload: payload,
        codec: 'json',
      );

      final fileStore = FileMemoryStore.directory(dir);
      await fileStore.write(envelope, expectedRevision: 0);
      final fromFile = await fileStore.read('counter');

      final freshDb = ScriptedFirestore();
      final s = FirebaseMemoryStore(firestore: freshDb, uid: uid);
      await s.write(envelope, expectedRevision: 0);
      final fromFirestore = await s.read('counter');

      expect(fromFirestore!.id, fromFile!.id);
      expect(fromFirestore.kind, fromFile.kind);
      expect(fromFirestore.revision, fromFile.revision);
      expect(fromFirestore.payload, fromFile.payload);
      expect(fromFirestore.codec, fromFile.codec);
      await fileStore.remove('counter');
    }
  });

  test('a newer-schema document at the expected revision is corrupt, not '
      'overwritten', () async {
    db.seed(uid, 'counter', docAt(4, 100)..['schema'] = 2);
    final s = store(db);
    await expectLater(
      s.write(MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 5, payload: 42),
          expectedRevision: 4),
      throwsA(isA<MemoryCorrupt>()),
    );
    expect(db.docs['users/$uid/cell_memory/counter']?['schema'], 2,
        reason: 'the newer-schema record is never overwritten');
    expect(db.docs['users/$uid/cell_memory/counter']?['revision'], 4);
  });

  test('an unencodable payload fails before any transaction', () async {
    final s = store(db);
    await expectLater(
      s.write(MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: double.nan),
          expectedRevision: 0),
      throwsA(isA<MemoryNotSerializable>()),
    );
    expect(db.handlerRuns, 0, reason: 'encoding happens before any I/O');
  });

  test('an oversized document fails with a clear error before any '
      'transaction', () async {
    final s = store(db);
    final payload = 'x' * (FirebaseMemoryStore.maxDocumentBytes + 1);
    await expectLater(
      s.write(MemoryEnvelope(generation: testGeneration, id: 'x', revision: 1, payload: payload),
          expectedRevision: 0),
      throwsA(isA<MemoryNotSerializable>()),
    );
    expect(db.handlerRuns, 0);
  });

  test('list fails closed on an id the grammar rejects and deletes nothing',
      () async {
    db.seed(uid, 'ok', docAt(1, 1)..['id'] = 'ok');
    // A document written by another tool whose id our grammar rejects:
    // rules stop a normal client from creating it, but not the Admin SDK.
    db.docs['users/$uid/cell_memory/bad id'] = docAt(1, 2)..['id'] = 'bad id';
    final s = store(db);
    await expectLater(s.list(), throwsA(isA<MemoryCorrupt>()));
    expect(db.docs.containsKey('users/$uid/cell_memory/ok'), isTrue);
    expect(db.docs.containsKey('users/$uid/cell_memory/bad id'), isTrue);
  });

  test('a document that exists with null data is corrupt and is never set',
      () async {
    db.nullDataPaths.add('users/$uid/cell_memory/counter');
    final s = store(db);
    await expectLater(
      s.write(MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 1),
          expectedRevision: 0),
      throwsA(isA<MemoryCorrupt>()),
    );
    expect(db.setCalls, 0);
  });

  test('a schema-2 document with wrapHandlerErrors still surfaces as '
      'MemoryCorrupt and never sets', () async {
    db.seed(uid, 'counter', docAt(4, 100)..['schema'] = 2);
    db.wrapHandlerErrors = true;
    final s = store(db);
    await expectLater(
      s.write(MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 5, payload: 42),
          expectedRevision: 4),
      throwsA(isA<MemoryCorrupt>()),
    );
    expect(db.setCalls, 0);
    expect(db.handlerRuns, 1);
  });

  test('close drains an in-flight write started before it', () async {
    final s = store(db);
    final writing = s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 7),
        expectedRevision: 0);
    final closing = s.close();
    await writing;
    await closing;
    expect(db.docs['users/$uid/cell_memory/counter']?['revision'], 1);
    await expectLater(s.close(), throwsA(isA<StateError>()));
  });

  test('the equal-revision retry shape is a no-op, matching the other '
      'stores', () async {
    db.seed(uid, 'counter', docAt(1, 5));
    final s = store(db);
    await s.write(
        MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 5, codec: 'json'),
        expectedRevision: 1);
    expect(db.setCalls, 0);
    expect(db.docs['users/$uid/cell_memory/counter']?['revision'], 1);
  });

  test('the equal-revision shape with a different payload is a conflict',
      () async {
    db.seed(uid, 'counter', docAt(1, 5));
    final s = store(db);
    await expectLater(
      s.write(
          MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 6, codec: 'json'),
          expectedRevision: 1),
      throwsA(isA<MemoryConflict>()),
    );
    expect(db.setCalls, 0);
    expect(db.docs['users/$uid/cell_memory/counter']?['revision'], 1);
  });

  test('reads and lists use the configured source (server by default)',
      () async {
    db.seed(uid, 'a', docAt(1, 1)..['id'] = 'a');
    final s = store(db);
    await s.read('a');
    expect(db.lastGetOptions?.source, Source.server);
    await s.list();
    expect(db.lastGetOptions?.source, Source.server);

    final cached = FirebaseMemoryStore(
        firestore: db, uid: uid, readSource: Source.cache);
    await cached.read('a');
    expect(db.lastGetOptions?.source, Source.cache);
  });

  test('permission-denied on read and list surfaces as MemoryIoException',
      () async {
    db.seed(uid, 'a', docAt(1, 1));
    db.permissionDenied = true;
    final s = store(db);
    await expectLater(s.read('a'), throwsA(isA<MemoryIoException>()));
    await expectLater(s.list(), throwsA(isA<MemoryIoException>()));
  });

  test('an update with a different generation at the right revision is '
      'MemoryConflict; the winner and its generation survive', () async {
    db.seed(uid, 'counter', docAt(1, 10));
    final s = store(db);
    try {
      await s.write(
        MemoryEnvelope(
            generation: testGenerationB,
            id: 'counter',
            revision: 2,
            payload: 99),
        expectedRevision: 1,
      );
      fail('expected MemoryConflict');
    } on MemoryConflict catch (conflict) {
      expect(conflict.actual, 1);
      expect(conflict.stored?.generation, testGeneration);
    }
    final row = db.docs['users/$uid/cell_memory/counter']!;
    expect(row['revision'], 1);
    expect(row['payload'], jsonEncode(10));
    expect(row['generation'], testGeneration);
  });

  test('the stale generation after remove-and-recreate is a conflict, not '
      'an ABA win', () async {
    db.seed(uid, 'counter', docAt(1, 1));
    final s = store(db);
    await s.remove('counter');
    // New life with generation B.
    await s.write(
        MemoryEnvelope(
            generation: testGenerationB, id: 'counter', revision: 1, payload: 10),
        expectedRevision: 0);
    await s.write(
        MemoryEnvelope(
            generation: testGenerationB, id: 'counter', revision: 2, payload: 11),
        expectedRevision: 1);
    // The stale writer still carries generation G at expected 1.
    await expectLater(
      s.write(
          MemoryEnvelope(
              generation: testGeneration,
              id: 'counter',
              revision: 2,
              payload: 99),
          expectedRevision: 1),
      throwsA(isA<MemoryConflict>()),
    );
    final row = db.docs['users/$uid/cell_memory/counter']!;
    expect(row['revision'], 2);
    expect(row['payload'], jsonEncode(11));
    expect(row['generation'], testGenerationB);
  });
}
