// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert' show jsonEncode;
import 'dart:io';

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';
import 'package:test/test.dart';

import 'support/harness.dart' show testGeneration;

import 'store_contract_suite.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cell_memory_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  runStoreContractSuite('FileMemoryStore.directory', () {
    // A fresh directory per contract case.
    final dir = Directory('${root.path}/contract_${DateTime.now().microsecondsSinceEpoch}_${root.listSync().length}');
    dir.createSync(recursive: true);
    return FileMemoryStore.directory(dir);
  });

  group('FileMemoryStore.directory', () {
    test('writes pretty JSON with the documented key order', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(
        MemoryEnvelope(generation: testGeneration, 
          id: 'cart',
          revision: 1,
          updatedAt: DateTime.utc(2026, 11, 23),
          payload: {'n': 1},
          codec: 'json',
        ),
        expectedRevision: 0,
      );
      final text = await File('${root.path}/cart.json').readAsString();
      final lines = text.split('\n');
      expect(lines[0].trim(), '{');
      expect(lines[1].trim(), '"schema": 1,');
      expect(lines[2].trim(), '"id": "cart",');
      expect(lines[3].trim(), '"kind": "value",');
      expect(lines[4].trim(), '"revision": 1,');
      expect(lines[5].trim(), '"generation": "$testGeneration",');
      expect(lines[6].trim(), startsWith('"updatedAt": "2026-11-23T00:00:00.000Z"'));
      expect(lines[7].trim(), '"codec": "json",');
      expect(lines[8].trim(), '"payload": {');
      expect(File('${root.path}/cart.json.tmp').existsSync(), isFalse);
    });

    test('rejects ../x, a/b, backslash, and empty ids before any IO',
        () async {
      final store = FileMemoryStore.directory(root);
      for (final bad in ['../x', 'a/b', r'a\b', '', '.', '..', 'x' * 129]) {
        expect(
          () => store.read(bad),
          throwsA(isA<ArgumentError>()),
          reason: 'id "$bad" must be rejected',
        );
      }
      expect(await root.list().toList(), isEmpty);
    });

    test('read with tmp + json deletes tmp and keeps json', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 7),
          expectedRevision: 0);
      await File('${root.path}/a.json.tmp').writeAsString('partial');
      final read = await store.read('a');
      expect(read?.payload, 7);
      expect(File('${root.path}/a.json.tmp').existsSync(), isFalse);
    });

    test('tmp only throws MemoryCorrupt and does not promote it', () async {
      final store = FileMemoryStore.directory(root);
      await File('${root.path}/a.json.tmp').writeAsString('partial');
      await expectLater(store.read('a'), throwsA(isA<MemoryCorrupt>()));
      expect(File('${root.path}/a.json').existsSync(), isFalse);
    });

    test('round-trips a typed map with nested map, list, and JSON null',
        () async {
      final store = FileMemoryStore.directory(root);
      final payload = <String, Object?>{
        'name': 'cart',
        'nested': {'count': 3, 'tags': ['a', 'b']},
        'none': null,
      };
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'typed', revision: 1, payload: payload),
          expectedRevision: 0);
      final read = await store.read('typed');
      expect(read?.payload, payload);
      expect(read?.payload, isA<Map<String, Object?>>());
    });

    test('a stale lone tmp does not brick the id: write discards it and '
        'read keeps failing closed', () async {
      final store = FileMemoryStore.directory(root);
      await File('${root.path}/a.json.tmp').writeAsString('partial');

      await expectLater(store.read('a'), throwsA(isA<MemoryCorrupt>()));
      // The write path overwrites the tmp anyway; no record was ever
      // committed, so the id must recover.
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 7),
          expectedRevision: 0);
      expect((await store.read('a'))?.payload, 7);
      expect(File('${root.path}/a.json.tmp').existsSync(), isFalse);
    });

    test('rejects Windows reserved device names before any IO', () async {
      final store = FileMemoryStore.directory(root);
      for (final bad in ['CON', 'con', 'prn', 'aux', 'nul', 'com1', 'lpt9']) {
        expect(() => store.read(bad), throwsA(isA<ArgumentError>()),
            reason: 'id "$bad" must be rejected');
      }
      expect(await root.list().toList(), isEmpty);
    });

    test('a directory file whose JSON id disagrees with the filename fails '
        'closed and stays in place', () async {
      final store = FileMemoryStore.directory(root);
      await File('${root.path}/a.json').writeAsString(jsonEncode(MemoryEnvelope(
        generation: testGeneration,
        id: 'b',
        revision: 1,
        payload: 7,
      ).toJson()));
      await expectLater(store.read('a'), throwsA(isA<MemoryCorrupt>()));
      expect(File('${root.path}/a.json').existsSync(), isTrue,
          reason: 'the file is never deleted or rewritten');
      expect(await store.read('b'), isNull);
    });

    test('case-distinct names are refused: Cart then cart throws '
        'MemoryCorrupt, the first file is intact, and list fails while '
        'both exist', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(
          MemoryEnvelope(generation: testGeneration, id: 'Cart', revision: 1, payload: 1),
          expectedRevision: 0);
      if (File('${root.path}/cart.json').existsSync()) {
        // Case-insensitive filesystem (Windows, default macOS): the two
        // names are one file and cannot coexist; the collision rule has
        // nothing to catch here.
        markTestSkipped('filesystem is case-insensitive; two distinct '
            'case-variants cannot exist');
        return;
      }
      // The colliding name arrives hand-written, like a file created by
      // another tool.
      await File('${root.path}/cart.json').writeAsString(jsonEncode(MemoryEnvelope(
        generation: testGeneration,
        id: 'cart',
        revision: 1,
        payload: 2,
      ).toJson()));

      await expectLater(
        store.write(
            MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 2, payload: 3),
            expectedRevision: 1),
        throwsA(isA<MemoryCorrupt>()),
      );
      // Fail-closed reads: with both names present, read refuses too —
      // the case-insensitive interpretation of this directory is one
      // file with two names, so returning a row would pick a side.
      await expectLater(store.read('Cart'), throwsA(isA<MemoryCorrupt>()));
      // The first record is untouched: the raw file still carries the
      // Cart envelope the store wrote.
      final raw = await File('${root.path}/Cart.json').readAsString();
      expect(raw, contains('"id": "Cart"'));
      expect(raw, contains('"payload": 1'));
      await expectLater(store.list(), throwsA(isA<MemoryCorrupt>()));
      expect(File('${root.path}/Cart.json').existsSync(), isTrue);
      expect(File('${root.path}/cart.json').existsSync(), isTrue,
          reason: 'neither file is deleted');
    });

    test('a bad id file fails list closed and deletes nothing', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(
          MemoryEnvelope(generation: testGeneration, id: 'ok', revision: 1, payload: 1),
          expectedRevision: 0);
      await File('${root.path}/bad id.json').writeAsString(jsonEncode(MemoryEnvelope(
        generation: testGeneration,
        id: 'bad id',
        revision: 1,
        payload: 2,
      ).toJson()));
      await expectLater(store.list(), throwsA(isA<MemoryCorrupt>()));
      expect(File('${root.path}/ok.json').existsSync(), isTrue);
      expect(File('${root.path}/bad id.json').existsSync(), isTrue);
    });

    test('File.rename replaces an existing record on this platform', () async {
      final file = File('${root.path}/probe.json');
      final tmp = File('${root.path}/probe.json.tmp');
      await file.writeAsString('original');
      await tmp.writeAsString('replacement');
      await tmp.rename(file.path);
      expect(await file.readAsString(), 'replacement');
    });

    test('a failed write leaves the original json unchanged', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 7),
          expectedRevision: 0);
      final original = await File('${root.path}/a.json').readAsString();

      // Simulate a crash between flush and rename by pre-creating a tmp that
      // cannot be renamed over: the compare step still reads the original,
      // then the rename of a *directory-like* tmp fails. Instead, inject the
      // failure directly: make the tmp a directory so rename fails.
      await Directory('${root.path}/a.json.tmp').create();
      await expectLater(
        store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 2, payload: 8),
            expectedRevision: 1),
        throwsA(isA<MemoryIoException>()),
      );
      final after = await File('${root.path}/a.json').readAsString();
      expect(after, original);
    });

    test('reopen reads the same envelope', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 42),
          expectedRevision: 0);

      final reopened = FileMemoryStore.directory(root);
      final read = await reopened.read('a');
      expect(read?.revision, 1);
      expect(read?.payload, 42);
    });

    test('CAS conflict leaves the winner unchanged', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1),
          expectedRevision: 0);
      await expectLater(
        store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 2),
            expectedRevision: 0),
        throwsA(isA<MemoryConflict>()),
      );
      final read = await store.read('a');
      expect(read?.payload, 1);
    });

    test('list returns ids from *.json only', () async {
      final store = FileMemoryStore.directory(root);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1),
          expectedRevision: 0);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'b', revision: 1, payload: 2),
          expectedRevision: 0);
      await File('${root.path}/c.json.tmp').writeAsString('partial');
      expect(await store.list(), unorderedEquals(['a', 'b']));
    });
  });

  group('FileMemoryStore.file', () {
    test('stores one envelope, enforces its id, and unload does not delete '
        'it', () async {
      final file = File('${root.path}/single.json');
      final store = FileMemoryStore.file(file);
      await store.write(
          MemoryEnvelope(generation: testGeneration, id: 'session', revision: 1, payload: {'x': 1}),
          expectedRevision: 0);
      // read(id) returns the record only for its own id.
      final read = await store.read('session');
      expect(read?.id, 'session');
      expect(read?.payload, {'x': 1});
      expect(await store.read('anything'), isNull,
          reason: 'a single-file store holds one record; another id reads '
              'as absent');
      await store.close();
      expect(file.existsSync(), isTrue);
    });

    test('a second envelope id cannot overwrite the stored record', () async {
      final store = FileMemoryStore.file(File('${root.path}/single.json'));
      await store.write(
          MemoryEnvelope(generation: testGeneration, id: 'session', revision: 1, payload: 1),
          expectedRevision: 0);
      await expectLater(
        store.write(
            MemoryEnvelope(generation: testGeneration, id: 'other', revision: 1, payload: 2),
            expectedRevision: 0),
        throwsA(isA<MemoryCorrupt>()),
      );
      expect((await store.read('session'))?.payload, 1);
    });

    test('list returns the stored id or an empty list', () async {
      final store = FileMemoryStore.file(File('${root.path}/single.json'));
      expect(await store.list(), isEmpty);
      await store.write(
          MemoryEnvelope(generation: testGeneration, id: 'session', revision: 1, payload: 1),
          expectedRevision: 0);
      expect(await store.list(), ['session']);
    });

    test('corrupt JSON throws MemoryCorrupt and is left in place', () async {
      final file = File('${root.path}/single.json');
      await file.writeAsString('{not json');
      final store = FileMemoryStore.file(file);
      await expectLater(store.read('x'), throwsA(isA<MemoryCorrupt>()));
      expect(await file.readAsString(), '{not json');
    });
  });
}
