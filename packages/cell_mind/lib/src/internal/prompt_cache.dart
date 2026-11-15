// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// SHA-256 of [input], hex-encoded. The content-addressing primitive
/// shared by the prompt cache and the journal hashes.
String _sha256Hex(String input) =>
    sha256.convert(utf8.encode(input)).toString();

/// One cached LLM response with its capture time (for TTL expiry).
final class _PromptCacheEntry {
  final String response;
  final DateTime at;

  const _PromptCacheEntry(this.response, this.at);
}

/// The in-process, content-addressed cache for prompted verdicts.
///
/// Recording-side optimization: identical `(config, context, decision)`
/// triples within one process (and within [cacheTtl]) reuse the first
/// LLM response. Replay never consults it meaningfully — a replay
/// session starts with an empty cache and the `EffectJournal` serves
/// the recorded response without invoking the adapter.
///
/// Keys are `sha256(config.id | config.version | contextHash |
/// decisionHash | systemPromptHash)` per Phase 8 D10. A version bump
/// therefore always misses.
final class _PromptCache {
  final Map<String, _PromptCacheEntry> _entries = {};

  /// The composite cache key for one decision.
  String keyFor({
    required String configId,
    required String configVersion,
    required String contextHash,
    required String decisionHash,
    required String systemPromptHash,
  }) =>
      _sha256Hex(
        '$configId|$configVersion|$contextHash|$decisionHash|$systemPromptHash',
      );

  /// The cached response, or `null` on miss or expiry.
  ///
  /// A [ttl] of [Duration.zero] disables caching entirely; a negative
  /// ttl is rejected by config validation before it reaches here.
  _PromptCacheEntry? get(String key, {required Duration ttl}) {
    if (ttl == Duration.zero) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (ttl.isNegative || DateTime.now().difference(entry.at) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry;
  }

  /// Stores [response] under [key], stamped with the current time.
  void put(String key, String response) {
    _entries[key] = _PromptCacheEntry(response, DateTime.now());
  }

  /// The number of live entries. Test-visible via the library's
  /// internal surface.
  int get size => _entries.length;
}
