// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The input identity of one cached verdict.
///
/// ### When to use
/// Constructed by the prompted policy per decision; also readable from
/// [VerdictCacheHitEffect]. Distinguish entries by their component
/// fingerprints rather than by raw objects — the cache is
/// content-addressed.
///
/// ### How it works
/// A value object of the five inputs that define a verdict: the config
/// `(id, version)`, the cell-context fingerprint, the pulse-context
/// fingerprint (empty for commands), the decision fingerprint, and the
/// session fingerprint (empty when stateless). [fingerprint] is the
/// sha256 of the joined components — the map key.
///
/// ### Non-obvious
/// - **`config.version` participates.** Bumping the config version
///   always invalidates every verdict cache entry.
/// - **`sessionFingerprint` participates.** Any session change
///   invalidates entries for that session state.
/// - **Values are opaque hashes** — compare keys, never parse them.
///
/// ### See also
/// - [VerdictCache], [VerdictCacheEntry], `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Treat keys as opaque; build them through the prompted policy,
///   not by hand.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class VerdictCacheKey {
  /// The config id.
  final String configId;

  /// The config version.
  final String configVersion;

  /// SHA-256 of the cell's `Ontology` + `Mandate` dimensions.
  final String cellContextFingerprint;

  /// SHA-256 of the pulse's `Provenance` dimensions (`''` for
  /// command decisions).
  final String pulseContextFingerprint;

  /// SHA-256 of the decision shape (payload + type + source, or
  /// function + arguments).
  final String decisionFingerprint;

  /// SHA-256 of the session content (`''` when stateless/empty).
  final String sessionFingerprint;

  const VerdictCacheKey({
    required this.configId,
    required this.configVersion,
    required this.cellContextFingerprint,
    required this.pulseContextFingerprint,
    required this.decisionFingerprint,
    required this.sessionFingerprint,
  });

  /// The composite cache key: sha256 of the joined components.
  String get fingerprint => _sha256Hex(
        '$configId|$configVersion'
        '|$cellContextFingerprint'
        '|$pulseContextFingerprint'
        '|$decisionFingerprint'
        '|$sessionFingerprint',
      );

  /// The raw joined components (`configId|configVersion|...`), kept
  /// for audit and diagnostics. [fingerprint] is the sha256 of this
  /// string.
  String get composite => '$configId|$configVersion'
      '|$cellContextFingerprint'
      '|$pulseContextFingerprint'
      '|$decisionFingerprint'
      '|$sessionFingerprint';

  /// Serializes this key.
  Map<String, dynamic> toMap() => {
        'configId': configId,
        'configVersion': configVersion,
        'cellContextFingerprint': cellContextFingerprint,
        'pulseContextFingerprint': pulseContextFingerprint,
        'decisionFingerprint': decisionFingerprint,
        'sessionFingerprint': sessionFingerprint,
      };

  /// Reconstructs a key from [VerdictCacheKey.toMap] output.
  static VerdictCacheKey fromMap(Map<String, dynamic> map) => VerdictCacheKey(
        configId: map['configId'] as String,
        configVersion: map['configVersion'] as String,
        cellContextFingerprint: map['cellContextFingerprint'] as String,
        pulseContextFingerprint:
            map['pulseContextFingerprint'] as String? ?? '',
        decisionFingerprint: map['decisionFingerprint'] as String,
        sessionFingerprint: map['sessionFingerprint'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is VerdictCacheKey && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;

  @override
  String toString() =>
      'VerdictCacheKey($configId@$configVersion, ${fingerprint.substring(0, 12)}…)';
}

/// One stored verdict with its capture time and provenance metadata.
///
/// ### When to use
/// Stored by [VerdictCache.store] and returned by
/// [VerdictCache.lookup]. The [storedAt] stamp drives TTL expiry in
/// [InMemoryVerdictCache]; [originalLatency] and [fromPromptCache]
/// record how the verdict was first produced (audit).
///
/// ### How it works
/// An immutable value object with `toMap` / `fromMap`.
///
/// ### Non-obvious
/// - **The verdict is the source of truth.** Caches serve the stored
///   verdict, never a re-parse of a stored response.
/// - **`fromPromptCache` marks second-tier hits.** The entry was
///   first produced by an LLM call when `false`; `true` means it was
///   populated from a prompt-cache hit (and `originalLatency` is
///   [Duration.zero]).
///
/// ### See also
/// - [VerdictCache], [VerdictCacheKey]
///
/// ## AI Agent Guide
/// - Read entries, never mutate them; reconstruct via
///   [VerdictCacheEntry.fromMap].
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class VerdictCacheEntry {
  /// The stored verdict.
  final Verdict verdict;

  /// The capture time (TTL reference).
  final DateTime storedAt;

  /// The latency of the original LLM call that produced this verdict.
  /// Zero for entries populated from a prompt-cache hit.
  final Duration originalLatency;

  /// Whether the verdict came from a full LLM call (`false`) or from
  /// a prompt-cache hit (`true`).
  final bool fromPromptCache;

  const VerdictCacheEntry({
    required this.verdict,
    required this.storedAt,
    this.originalLatency = Duration.zero,
    this.fromPromptCache = false,
  });

  /// Serializes this entry.
  Map<String, dynamic> toMap() => {
        'verdict': verdict.toMap(),
        'storedAt': _isoAt(storedAt),
        'originalLatencyMillis': originalLatency.inMilliseconds,
        'fromPromptCache': fromPromptCache,
      };

  /// Reconstructs an entry from [VerdictCacheEntry.toMap] output.
  static VerdictCacheEntry fromMap(Map<String, dynamic> map) =>
      VerdictCacheEntry(
        verdict: verdictFromMap(
          (map['verdict'] as Map).cast<String, dynamic>(),
        ),
        storedAt:
            DateTime.parse(map['storedAt'] as String? ?? map['at'] as String),
        originalLatency:
            Duration(milliseconds: map['originalLatencyMillis'] as int? ?? 0),
        fromPromptCache: map['fromPromptCache'] as bool? ?? false,
      );
}

/// The pluggable memoization layer for prompted verdicts.
///
/// ### When to use
/// Pass a shared instance to multiple `promptedPolicyWith` calls for
/// cross-policy caching, or implement the interface for a distributed
/// backend (Redis, Memcached). The default is
/// [InMemoryVerdictCache].
///
/// ### How it works
/// [lookup] returns the stored entry for a [VerdictCacheKey];
/// [store] writes one. Implementations own TTL and eviction.
///
/// ### Non-obvious
/// - **`lookup` and `store` are synchronous.** The verdict cache sits
///   on the hot path of every decision; async would add an `await`
///   per decision. Distributed caches should wrap their async client
///   in a synchronous in-memory layer for hot keys.
///
/// ### See also
/// - [InMemoryVerdictCache], [VerdictCacheKey], [VerdictCacheEntry]
///
/// ## AI Agent Guide
/// - Implementations must be deterministic per key: same key, same
///   verdict — the journal relies on it.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
abstract interface class VerdictCache {
  /// The stored entry for [key], or `null` on miss or expiry.
  VerdictCacheEntry? lookup(VerdictCacheKey key);

  /// Stores [entry] under [key].
  void store(VerdictCacheKey key, VerdictCacheEntry entry);

  /// Removes every entry.
  void clear();

  /// The number of live entries.
  int get size;

  /// Removes all expired entries.
  void evictExpired();
}

/// The default [VerdictCache]: TTL-bounded, LRU-evicted, in-memory.
///
/// ### When to use
/// The default instance created by `promptedPolicyWith` (configured
/// via `PromptConfig.verdictCacheTtl` and
/// `PromptConfig.maxVerdictCacheEntries`), or any time a
/// process-local memoization layer is enough.
///
/// ### How it works
/// A `LinkedHashMap` keeps insertion order; a [lookup] hit moves its
/// entry to the most-recent position (LRU). Entries older than [ttl]
/// are treated as misses. [store] evicts the least-recently-used
/// entries beyond [maxEntries].
///
/// ### Non-obvious
/// - **TTL is wall-clock**, evaluated per lookup — expired entries
///   also vanish on [evictExpired]. Accessing an entry does not
///   extend its TTL.
/// - **`ttl: Duration.zero`** makes every lookup a miss (disabled).
/// - **Access-order LRU since 1.1.0.** The plan's first draft
///   described insert-order eviction; the shipped implementation
///   refreshes recency on every hit (strict LRU). See
///   `_phase8_verdict.md` F9.2.
///
/// ### See also
/// - [VerdictCache], [VerdictCacheEntry]
///
/// ## AI Agent Guide
/// - Size the cache by hot decision cardinality, not by memory alone;
///   10,000 entries is the default for a reason.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class InMemoryVerdictCache implements VerdictCache {
  final Duration ttl;
  final int maxEntries;
  final Map<VerdictCacheKey, VerdictCacheEntry> _entries = {};

  InMemoryVerdictCache({
    this.ttl = const Duration(hours: 1),
    this.maxEntries = 10000,
  }) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be >= 1');
    }
    if (ttl.isNegative) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be non-negative');
    }
  }

  @override
  VerdictCacheEntry? lookup(VerdictCacheKey key) {
    if (ttl == Duration.zero) return null;
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      evictExpired();
      return null;
    }
    // LRU: re-insert at the most-recent end.
    _entries[key] = entry;
    return entry;
  }

  @override
  void store(VerdictCacheKey key, VerdictCacheEntry entry) {
    _entries.remove(key);
    _entries[key] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  void clear() => _entries.clear();

  @override
  int get size => _entries.length;

  /// The keys currently stored, least-recently-used first.
  ///
  /// Read-only diagnostic view — useful for audit ("what is cached?")
  /// and manual inspection without mutating LRU order.
  List<VerdictCacheKey> get keys => _entries.keys.toList(growable: false);

  @override
  void evictExpired() {
    final now = DateTime.now();
    _entries.removeWhere((_, entry) => now.difference(entry.storedAt) > ttl);
  }
}
