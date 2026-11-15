// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  VerdictCacheKey key(String session) => VerdictCacheKey(
        configId: 'c',
        configVersion: '1.0.0',
        cellContextFingerprint: 'a',
        pulseContextFingerprint: 'b',
        decisionFingerprint: 'd',
        sessionFingerprint: session,
      );

  group('VerdictCacheKey', () {
    test('fingerprint joins all components and is 64 hex chars', () {
      final fp = key('s').fingerprint;
      expect(fp, hasLength(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(fp), isTrue);
    });

    test('equal components produce equal keys', () {
      expect(key('s'), key('s'));
      expect(key('s').hashCode, key('s').hashCode);
    });

    test('any component change changes the fingerprint', () {
      final base = key('s');
      expect(
        key('t').fingerprint,
        isNot(base.fingerprint),
        reason: 'session fingerprint participates',
      );
      expect(
        VerdictCacheKey(
          configId: 'c',
          configVersion: '2.0.0',
          cellContextFingerprint: 'a',
          pulseContextFingerprint: 'b',
          decisionFingerprint: 'd',
          sessionFingerprint: 's',
        ).fingerprint,
        isNot(base.fingerprint),
        reason: 'config version participates',
      );
    });

    test('round-trips through toMap/fromMap', () {
      final restored = VerdictCacheKey.fromMap(key('s').toMap());
      expect(restored, key('s'));
      expect(restored.fingerprint, key('s').fingerprint);
    });

    test('fromMap tolerates legacy maps without the new fields', () {
      final restored = VerdictCacheKey.fromMap({
        'configId': 'c',
        'configVersion': '1.0.0',
        'cellContextFingerprint': 'a',
        'decisionFingerprint': 'd',
      });
      expect(restored.pulseContextFingerprint, '');
      expect(restored.sessionFingerprint, '');
    });
  });

  group('VerdictCacheEntry', () {
    test('round-trips through toMap/fromMap', () {
      final entry = VerdictCacheEntry(
        verdict: const Reject('no', {'k': 'v'}),
        at: DateTime.utc(2026, 11, 15, 12),
      );
      final restored = VerdictCacheEntry.fromMap(entry.toMap());
      expect(restored.verdict, isA<Reject>());
      expect((restored.verdict as Reject).reason, 'no');
      expect(restored.at, DateTime.utc(2026, 11, 15, 12));
    });
  });

  group('InMemoryVerdictCache', () {
    test('store then lookup returns the entry', () {
      final cache = InMemoryVerdictCache();
      final entry = VerdictCacheEntry(
        verdict: const Accept(),
        at: DateTime.now(),
      );
      cache.store(key('s'), entry);
      expect(cache.lookup(key('s')), same(entry));
      expect(cache.size, 1);
    });

    test('lookup for a missing key returns null', () {
      final cache = InMemoryVerdictCache();
      expect(cache.lookup(key('s')), isNull);
    });

    test('ttl expiry turns lookups into misses', () {
      final cache = InMemoryVerdictCache(
        ttl: const Duration(milliseconds: 20),
      );
      cache.store(
        key('s'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      expect(cache.lookup(key('s')), isNotNull);
      // Insert an already-expired entry.
      cache.store(
        key('t'),
        VerdictCacheEntry(
          verdict: const Accept(),
          at: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      );
      expect(cache.lookup(key('t')), isNull);
    });

    test('ttl zero disables the cache entirely', () {
      final cache = InMemoryVerdictCache(ttl: Duration.zero);
      cache.store(
        key('s'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      expect(cache.lookup(key('s')), isNull);
    });

    test('LRU eviction beyond maxEntries keeps the newest entries', () {
      final cache = InMemoryVerdictCache(maxEntries: 2);
      for (var i = 0; i < 3; i++) {
        cache.store(
          key('s$i'),
          VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
        );
      }
      expect(cache.size, 2);
      expect(cache.lookup(key('s0')), isNull, reason: 'oldest insert evicted');
      expect(cache.lookup(key('s1')), isNotNull);
      expect(cache.lookup(key('s2')), isNotNull);
    });

    test('a lookup hit refreshes LRU recency', () {
      final cache = InMemoryVerdictCache(maxEntries: 2);
      cache.store(
        key('s0'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      cache.store(
        key('s1'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      expect(cache.lookup(key('s0')), isNotNull); // s0 now most recent
      cache.store(
        key('s2'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      expect(cache.lookup(key('s1')), isNull,
          reason: 's1 was least recently used');
      expect(cache.lookup(key('s0')), isNotNull);
    });

    test('store overwrites an existing key without growing', () {
      final cache = InMemoryVerdictCache(maxEntries: 2);
      cache.store(
        key('s'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      cache.store(
        key('s'),
        VerdictCacheEntry(
          verdict: const Reject('no'),
          at: DateTime.now(),
        ),
      );
      expect(cache.size, 1);
      expect((cache.lookup(key('s'))!.verdict as Reject).reason, 'no');
    });

    test('clear removes everything', () {
      final cache = InMemoryVerdictCache();
      cache.store(
        key('s'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      cache.clear();
      expect(cache.size, 0);
      expect(cache.lookup(key('s')), isNull);
    });

    test('evictExpired removes only expired entries', () {
      final cache = InMemoryVerdictCache(ttl: const Duration(hours: 1));
      cache.store(
        key('fresh'),
        VerdictCacheEntry(verdict: const Accept(), at: DateTime.now()),
      );
      cache.store(
        key('stale'),
        VerdictCacheEntry(
          verdict: const Accept(),
          at: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      cache.evictExpired();
      expect(cache.size, 1);
      expect(cache.lookup(key('stale')), isNull);
    });

    test('construction validates bounds', () {
      expect(() => InMemoryVerdictCache(maxEntries: 0), throwsArgumentError);
      expect(
        () => InMemoryVerdictCache(ttl: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });
}
