// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart' show testGeneration;

import 'store_contract_suite.dart';

void main() {
  runStoreContractSuite('InMemoryMemoryStore', InMemoryMemoryStore.new);

  group('InMemoryMemoryStore', () {
    test('never aliases caller state: mutating a written payload or a read '
        'result cannot change history', () async {
      final store = InMemoryMemoryStore();
      final payload = <String, Object?>{'n': 1};
      final envelope =
          MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: payload);
      await store.write(envelope, expectedRevision: 0);

      payload['n'] = 999; // mutate what the caller handed in
      final read1 = await store.read('a');
      expect(read1?.payload, {'n': 1},
          reason: 'the store holds a copy, not the caller object');

      (read1!.payload! as Map)['n'] = 555; // mutate the read result
      final read2 = await store.read('a');
      expect(read2?.payload, {'n': 1},
          reason: 'each read returns a fresh copy');
    });

    test('read of a missing id returns null', () async {
      final store = InMemoryMemoryStore();
      expect(await store.read('cart'), isNull);
    });

    test('CAS installs revision 1 from expected 0', () async {
      final store = InMemoryMemoryStore();
      final envelope =
          MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: {'n': 1});
      await store.write(envelope, expectedRevision: 0);
      final read = await store.read('cart');
      expect(read?.revision, 1);
      expect(read?.payload, {'n': 1});
    });

    test('a second writer still expecting 0 gets MemoryConflict', () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: 1),
          expectedRevision: 0);

      await expectLater(
        store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: 2),
            expectedRevision: 0),
        throwsA(isA<MemoryConflict>()),
      );
      final read = await store.read('cart');
      expect(read?.payload, 1, reason: 'the first payload remains');
    });

    test('equal payload at the same expected revision is a no-op', () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: 1),
          expectedRevision: 0);
      // The idempotent retry: the same envelope, still expecting 1.
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: 1),
          expectedRevision: 1);
      expect((await store.read('cart'))?.revision, 1);
    });

    test('an envelope numbered wrong throws MemoryCorrupt', () async {
      final store = InMemoryMemoryStore();
      // Seed revision 4 so the conflict check passes and the numbering
      // check is what rejects the bad envelope.
      for (var r = 1; r <= 4; r++) {
        await store.write(
            MemoryEnvelope(generation: testGeneration, id: 'cart', revision: r, payload: r),
            expectedRevision: r - 1);
      }
      await expectLater(
        store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 9, payload: 1),
            expectedRevision: 4),
        throwsA(isA<MemoryCorrupt>()),
      );
      expect((await store.read('cart'))?.revision, 4);
    });

    test('remove deletes; a second remove succeeds', () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'cart', revision: 1, payload: 1),
          expectedRevision: 0);
      await store.remove('cart');
      expect(await store.read('cart'), isNull);
      await store.remove('cart');
    });

    test('list returns the stored ids', () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'a', revision: 1, payload: 1),
          expectedRevision: 0);
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'b', revision: 1, payload: 2),
          expectedRevision: 0);
      expect(await store.list(), unorderedEquals(['a', 'b']));
    });

    test('close is one-shot; the second call throws', () async {
      final store = InMemoryMemoryStore();
      await store.close();
      await expectLater(store.close(), throwsA(isA<StateError>()));
      await expectLater(store.read('a'), throwsA(isA<StateError>()));
    });
  });
}
