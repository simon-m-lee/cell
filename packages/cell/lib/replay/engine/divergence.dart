// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A single point at which a replay diverged from its recording.
///
/// ### How it works
/// The report is designed to be **actionable**. It carries:
///
/// * [seq] — which ledger entry diverged. A human reading the report
///   can `grep 'seq: 47' ledger.jsonl` and see exactly what was recorded.
/// * [expected] / [actual] — the divergence's observable values. For a
///   delta mismatch, these are the `after` values; for a receipt
///   mismatch, the receipt digests; for a journal mismatch, the effect
///   fingerprints.
/// * [lastEffect] — the last effect the replay consumed before
///   diverging. This is what tells you "the receptor reached the
///   network call at ordinal 5, then diverged" — the single most
///   valuable diagnostic for an effectful receptor that has changed.
/// * [reason] — a human-readable explanation.
///
/// ### Non-obvious: the report is per-divergence, not per-pulse
///
/// A single pulse can produce multiple divergences (a delta mismatch
/// *and* a receipt mismatch), which is why `ReplayResult.divergences`
/// is a list of `DivergenceReport`s, not a single report. The CLI's
/// `replay diff` prints them all; [ReplayEngine] in strict mode
/// throws on the first.
///
/// See also:
/// * [ReplayResult] — the list these reports accumulate into.
/// * [ReplayDivergenceException] — what strict replay throws.
/// {@category Replay}
class DivergenceReport {
  /// The sequence number of the ledger entry that diverged.
  final int seq;

  /// The expected value (from the ledger).
  final Object? expected;

  /// The actual value (from the replayed graph).
  final Object? actual;

  /// The last effect consumed before the divergence, if the divergence
  /// is at least partly about effects. For a pure-delta divergence, this
  /// is `null`.
  final EffectRecord? lastEffect;

  /// A human-readable reason.
  final String reason;

  /// Creates a [DivergenceReport].
  ///
  /// ### Parameters:
  /// - [seq]: The sequence number of the ledger entry that diverged.
  /// - [expected]: The expected value (from the ledger).
  /// - [actual]: The actual value (from the replayed graph).
  /// - [lastEffect]: The last effect consumed before the divergence.
  /// - [reason]: A human-readable reason.
  const DivergenceReport({
    required this.seq,
    required this.expected,
    required this.actual,
    this.lastEffect,
    required this.reason,
  });

  @override
  String toString() {
    final effect = lastEffect == null
        ? ''
        : ' [after ${lastEffect!.kind}@${lastEffect!.ordinal}]';
    return 'DivergenceReport(seq: $seq, reason: $reason$effect, '
        'expected: $expected, actual: $actual)';
  }
}
