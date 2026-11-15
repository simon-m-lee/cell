// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// SHA-256 of [input], hex-encoded. The content-addressing primitive
/// shared by the caches, fingerprints, and journal hashes.
String _sha256Hex(String input) =>
    sha256.convert(utf8.encode(input)).toString();

/// One cached LLM response with its parsed verdict and capture time.
final class _PromptCacheEntry {
  final String response;
  final Verdict verdict;
  final DateTime at;

  const _PromptCacheEntry({
    required this.response,
    required this.verdict,
    required this.at,
  });
}

/// The in-process, content-addressed prompt cache — the second-tier
/// fast path (D2).
///
/// Output-keyed: the key is
/// `sha256(config.id | config.version | sha256(renderedPrompt))`, so
/// any two inputs that render identically share an entry, including
/// across policy instances with the same config. The verdict cache
/// (input-keyed) is consulted first and skips rendering entirely.
///
/// Replay never consults it meaningfully — a replay session starts
/// with an empty cache and the `EffectJournal` serves the recorded
/// outcomes; the journal-driven disposition effect reproduces the
/// recorded branch.
final class _PromptCache {
  final Map<String, _PromptCacheEntry> _entries = {};

  /// The composite prompt-cache key for one rendered prompt.
  String keyFor({
    required String configId,
    required String configVersion,
    required String renderedPrompt,
  }) =>
      _sha256Hex('$configId|$configVersion|${_sha256Hex(renderedPrompt)}');

  /// The cached entry, or `null` on miss or expiry.
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

  /// Stores [response] / [verdict] under [key], stamped now.
  void put(String key, {required String response, required Verdict verdict}) {
    _entries[key] = _PromptCacheEntry(
      response: response,
      verdict: verdict,
      at: DateTime.now(),
    );
  }

  /// The number of live entries.
  int get size => _entries.length;
}
