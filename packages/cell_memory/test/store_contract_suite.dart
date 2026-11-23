// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// The shared [MemoryStore] contract suite. Every backend runs it so the
// CAS rules cannot drift between implementations.

import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart' show testGeneration;

/// The fixed generation shared by the contract cases, exposed so the case
/// bodies can name it. One life: [env] uses it unless told otherwise.
const String suiteGeneration = testGeneration;

/// A second, distinct well-formed generation.
const String suiteGenerationB = 'fedcba9876543210fedcba9876543210';

/// Builds an envelope with the suite generation, so the cases read as
/// protocol statements instead of argument soup.
MemoryEnvelope env(
  String id,
  int revision,
  Object? payload, {
  String generation = suiteGeneration,
  String? codec,
}) =>
    MemoryEnvelope(
      generation: generation,
      id: id,
      revision: revision,
      payload: payload,
      codec: codec,
    );

/// Runs the contract cases every [MemoryStore] must satisfy.
void runStoreContractSuite(String name, MemoryStore Function() create) {
  group('$name: store contract', () {
    test('read of a missing id returns null', () async {
      final store = create();
      expect(await store.read('cart'), isNull);
    });

    test('expected 0 installs revision 1', () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      expect((await store.read('cart'))?.revision, 1);
    });

    test('expected N installs N+1; a stale writer gets MemoryConflict and '
        'the winner remains', () async {
      final store = create();
      for (var r = 1; r <= 4; r++) {
        await store.write(env('cart', r, r), expectedRevision: r - 1);
      }
      await store.write(env('cart', 5, 50), expectedRevision: 4);
      await expectLater(
        store.write(env('cart', 5, 99), expectedRevision: 4),
        throwsA(isA<MemoryConflict>()),
      );
      final read = await store.read('cart');
      expect(read?.revision, 5);
      expect(read?.payload, 50);
    });

    test('an equal payload at the same expected revision is a no-op',
        () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      await store.write(env('cart', 1, 1), expectedRevision: 1);
      expect((await store.read('cart'))?.revision, 1);
    });

    test('the lost-response retry (own payload at expected + 1) is a '
        'successful no-op', () async {
      final store = create();
      await store.write(env('cart', 1, 7), expectedRevision: 0);
      // The same write, retried after its commit response was lost.
      await store.write(env('cart', 1, 7), expectedRevision: 0);
      expect((await store.read('cart'))?.revision, 1);
      expect((await store.read('cart'))?.payload, 7);
    });

    test('a different payload at expected + 1 is a conflict, not a retry',
        () async {
      final store = create();
      await store.write(env('cart', 1, 7), expectedRevision: 0);
      await expectLater(
        store.write(env('cart', 1, 8), expectedRevision: 0),
        throwsA(isA<MemoryConflict>()),
      );
      expect((await store.read('cart'))?.payload, 7);
    });

    test('an envelope numbered wrong throws MemoryCorrupt and writes '
        'nothing', () async {
      final store = create();
      for (var r = 1; r <= 4; r++) {
        await store.write(env('cart', r, r), expectedRevision: r - 1);
      }
      await expectLater(
        store.write(env('cart', 9, 9), expectedRevision: 4),
        throwsA(isA<MemoryCorrupt>()),
      );
      expect((await store.read('cart'))?.revision, 4);
    });

    test('remove deletes and a second remove succeeds', () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      await store.remove('cart');
      expect(await store.read('cart'), isNull);
      await store.remove('cart');
    });

    test('list returns the stored ids', () async {
      final store = create();
      await store.write(env('a', 1, 1), expectedRevision: 0);
      await store.write(env('b', 1, 2), expectedRevision: 0);
      expect(await store.list(), unorderedEquals(['a', 'b']));
    });

    test('close is one-shot; later calls throw StateError', () async {
      final store = create();
      await store.close();
      await expectLater(store.close(), throwsA(isA<StateError>()));
      await expectLater(store.read('a'), throwsA(isA<StateError>()));
    });

    // ── generation (the ABA protocol) ──────────────────────────────────

    test('create with G, then revision 2 with G', () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      final g = (await store.read('cart'))!.generation;
      await store.write(env('cart', 2, 2), expectedRevision: 1);
      final read = await store.read('cart');
      expect(read?.revision, 2);
      expect(read?.generation, g);
    });

    test('revision 2 with a different generation at the right expected '
        'revision is MemoryConflict; the winner is unchanged and rides on '
        'the conflict', () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      final g = (await store.read('cart'))!.generation;
      try {
        await store.write(
            env('cart', 2, 2, generation: suiteGenerationB),
            expectedRevision: 1);
        fail('expected MemoryConflict');
      } on MemoryConflict catch (conflict) {
        expect(conflict.stored?.generation, g);
      }
      final read = await store.read('cart');
      expect(read?.revision, 1);
      expect(read?.payload, 1);
    });

    test('remove, create a new life, advance it until its revision equals '
        'the stale writer\'s next revision; the stale writer sends the old '
        'generation and conflicts', () async {
      final store = create();
      await store.write(env('cart', 1, 1), expectedRevision: 0);
      await store.remove('cart');
      // New life, generation B.
      await store.write(env('cart', 1, 10, generation: suiteGenerationB),
          expectedRevision: 0);
      await store.write(env('cart', 2, 11, generation: suiteGenerationB),
          expectedRevision: 1);
      // The stale writer (generation G) tries to write its revision 2.
      await expectLater(
        store.write(env('cart', 2, 99), expectedRevision: 1),
        throwsA(isA<MemoryConflict>()),
      );
      final read = await store.read('cart');
      expect(read?.revision, 2);
      expect(read?.payload, 11);
      expect(read?.generation, suiteGenerationB);
    });

    test('retry of the same revision, generation, and payload leaves one '
        'row', () async {
      final store = create();
      await store.write(env('cart', 1, 5), expectedRevision: 0);
      await store.write(env('cart', 1, 5), expectedRevision: 0);
      final read = await store.read('cart');
      expect(read?.revision, 1);
      expect(read?.payload, 5);
    });

    test('retry with the same payload and a new generation at expected + 1 '
        'is MemoryConflict', () async {
      final store = create();
      await store.write(env('cart', 1, 5), expectedRevision: 0);
      await expectLater(
        store.write(
            env('cart', 1, 5, generation: suiteGenerationB),
            expectedRevision: 0),
        throwsA(isA<MemoryConflict>()),
      );
      expect((await store.read('cart'))?.generation, suiteGeneration);
    });

    test('hostile ids are rejected before any write', () async {
      final store = create();
      for (final bad in ['.', '..', 'a/b', '', 'x' * 129]) {
        expect(
          () => store.read(bad),
          throwsA(isA<ArgumentError>()),
          reason: 'id "$bad" must be rejected',
        );
      }
      expect(await store.read('cart'), isNull);
    });
  });
}
