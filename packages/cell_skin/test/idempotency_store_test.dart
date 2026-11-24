// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The memory idempotency store, directly.
library;

import 'dart:async';

import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

IdempotencyRecord recordFor(String fingerprint) => IdempotencyRecord(
      fingerprint: fingerprint,
      responseType: 'rest.apply.response.accepted',
      outcomeJson: const {'kind': 'accepted', 'result': true, 'receipt': {}},
      storedAt: DateTime.now(),
    );

void main() {
  test('single flight: own, wait, replay', () async {
    final store = MemoryIdempotencyStore();
    expect(await store.claim('k'), isA<IdempotencyOwned>());

    final waiter = await store.claim('k');
    expect(waiter, isA<IdempotencyWait>());
    final settled = (waiter as IdempotencyWait).settled;

    var released = false;
    unawaited(settled.then((_) => released = true));

    final record = recordFor('f');
    await store.complete('k', record);
    expect(await settled, same(record));

    final third = await store.claim('k');
    expect(third, isA<IdempotencyReplay>());
    expect((third as IdempotencyReplay).record, same(record));
    expect(released, isTrue);
  });

  test('abort frees the key for a new owner', () async {
    final store = MemoryIdempotencyStore();
    expect(await store.claim('k'), isA<IdempotencyOwned>());

    final waiter = await store.claim('k') as IdempotencyWait;
    await store.abort('k');
    expect(await waiter.settled, isNull);

    expect(await store.claim('k'), isA<IdempotencyOwned>());
  });

  test('an in-flight key is never the eviction victim', () async {
    final store = MemoryIdempotencyStore(maxEntries: 1);
    expect(await store.claim('a'), isA<IdempotencyOwned>());

    // Completing B fills the single completed slot.
    await store.complete('b', recordFor('b'));

    // Completing A must evict the completed entry (B), not the in-flight
    // claim on A.
    await store.complete('a', recordFor('a'));

    final a = await store.claim('a');
    expect(a, isA<IdempotencyReplay>());

    final b = await store.claim('b');
    expect(b, isA<IdempotencyOwned>(),
        reason: 'B was the oldest completed record and was evicted');
  });

  test('a record past its ttl is claimed anew', () async {
    var now = DateTime(2026, 1, 1);
    final store = MemoryIdempotencyStore(
      ttl: const Duration(hours: 24),
      clock: () => now,
    );
    expect(await store.claim('k'), isA<IdempotencyOwned>());
    await store.complete(
      'k',
      IdempotencyRecord(
        fingerprint: 'f',
        responseType: 'rest.apply.response.accepted',
        outcomeJson: const {'kind': 'accepted', 'result': true, 'receipt': {}},
        storedAt: now,
      ),
    );

    now = now.add(const Duration(hours: 24, seconds: 1));
    expect(await store.claim('k'), isA<IdempotencyOwned>());
  });

  test('a maxEntries below one is refused', () {
    expect(() => MemoryIdempotencyStore(maxEntries: 0), throwsArgumentError);
  });
}
