// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The result of a [ReplayEngine.replay] call.
///
/// A successful replay has `success == true` and `divergences == []`.
/// A lenient replay (with `failOnDivergence: false`) can have
/// `success == false` *and* a non-empty `divergences` list, while
/// `entriesReplayed == entries.length` — the replay ran to completion
/// but every entry did not match. A strict replay throws
/// [ReplayDivergenceException] on the first divergence; the
/// `ReplayResult` is only returned for successful replays.
///
/// ### Non-obvious: `newSnapshot` is the state at the *end* of replay
///
/// Not at the divergence point. A caller that wants a snapshot at a
/// specific sequence should use `ReplayEngine.replay` with
/// `options.maxEntries: seq + 1`. This is deliberate: reconstructing a
/// snapshot at every step is expensive; the caller knows which step
/// they care about, and the `maxEntries` option gives them a cheap way
/// to get there.
class ReplayResult {
  /// Whether the replay succeeded with no divergences.
  final bool success;

  /// Number of entries actually replayed. Can be less than the ledger's
  /// length if `options.maxEntries` was set.
  final int entriesReplayed;

  /// The sequence number of the first divergence, or `null` on success.
  /// Only set when `success == false` (lenient replay) — strict replay
  /// throws instead of returning a result with this field set.
  final int? divergedAt;

  /// All divergences recorded during the replay. Empty on success.
  /// Strict replay throws on the first divergence, so a result with
  /// this list non-empty is only returned for lenient replays.
  final List<DivergenceReport> divergences;

  /// The graph's state at the end of replay, as a [CellGraphSnapshot].
  final CellGraphSnapshot newSnapshot;

  const ReplayResult({
    required this.success,
    required this.entriesReplayed,
    required this.divergedAt,
    required this.divergences,
    required this.newSnapshot,
  });
}
