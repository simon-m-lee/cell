// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A single cell's state change within a ledger entry.
///
/// [StateDelta] is the **Atomic Record of Change**: the smallest unit of
/// forensic history the ledger stores. It captures one cell's value
/// before and after a commit, together with the wall-clock time of the
/// commit, so an auditor can trace every state transition.
///
/// Captured by `ValueCell.postProcessRule` immediately before and after
/// the commit, so `before` and `after` reflect the exact values the
/// receptor produced — not the values the caller *intended*. That
/// distinction matters: a receptor can transform its input, and the
/// ledger must record the transformed value, or replay will diverge.
///
/// ### Why it is used
/// - **Replay Fidelity**: Replay must reproduce the exact value the
///   receptor committed, not the caller's intent, or the reconstructed
///   graph diverges from the original.
/// - **Causal Traceability**: The delta ties a value change to a cell id
///   and a timestamp, so the ledger's causal chain is queryable.
/// - **Tamper Evidence**: Each delta's digest is folded into the entry
///   hash, so altering a stored value breaks the chain.
///
/// ### How it works
/// 1. `ValueCell.postProcessRule` observes `(before, after)` around the
///    commit.
/// 2. It constructs a [StateDelta] and hands it to the active
///    `LedgerScope.captureDelta`.
/// 3. The scope bundles the deltas with the pulse's receipt and effects
///    into a `LedgerEntry`, whose hash chain binds them permanently.
///
/// ### Technical Details
/// - **Non-obvious: `before == after` is legal.** A receptor can commit
///   the same value (e.g., an idempotent `set`). The delta is still
///   recorded, because the *fact* that the pulse visited the cell is part
///   of the causal chain; the absence of a value change is not the
///   absence of an event.
/// - **Forensic only timestamp.** Replay does not compare `at` — a
///   wall-clock time cannot be reproduced — it is recorded for auditors,
///   not for replay equality.
/// - **Null vs missing key.** `toJson` drops null `before`/`after` keys,
///   so a digest cannot distinguish "the value was null" from "the key
///   was dropped". This is deliberate: an explicit null marker would
///   change every stored delta digest and invalidate existing ledgers;
///   the hash chain is what makes tampering loud.
///
/// See also:
/// - [LedgerEntry] — the row that carries this delta.
/// - [LedgerScope] — the ambient that captures deltas during a commit.
/// {@category Replay}
/// {@category Ledger}
class StateDelta {
  /// The registered id of the cell whose value changed.
  final String cellId;

  /// The value immediately before the commit. Encoded with the cell's
  /// payload codec; the store treats it as opaque JSON.
  final Object? before;

  /// The value immediately after the commit.
  final Object? after;

  /// Wall-clock time of the commit. Recorded because replay needs to
  /// reproduce ordering *and* because a forensic auditor's first question
  /// is "when did this happen". Forensic only: replay does not compare
  /// `at` (a wall-clock time cannot be reproduced).
  final DateTime at;

  /// Creates a [StateDelta].
  ///
  /// ### Parameters:
  /// - [cellId]: The registered id of the cell whose value changed.
  /// - [before]: The value immediately before the commit.
  /// - [after]: The value immediately after the commit.
  /// - [at]: Wall-clock time of the commit (forensic only).
  const StateDelta({
    required this.cellId,
    required this.before,
    required this.after,
    required this.at,
  });

  /// Whether the value actually changed. This is not the same as
  /// `before != after` — `Object?` equality in Dart is by `==`, which may
  /// not be the delta the caller cares about. Callers that want a
  /// semantic comparison should encode both values and compare digests.
  bool get changed => before != after;

  /// Serialises this delta to its canonical JSON map.
  Map<String, Object?> toJson() => {
    'cellId': cellId,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
    'at': at.toUtc().toIso8601String(),
  };

  /// Reconstructs a [StateDelta] from [toJson]'s output.
  ///
  /// ### Non-obvious: a `null` value and a missing key parse identically
  ///
  /// `toJson` drops null `before`/`after` keys, so a digest cannot
  /// distinguish "the value was null" from "the key was dropped"
  /// (round-tripping preserves the null either way). Recorded deltas
  /// always carry both fields through `_encodeForLedger` — a genuine
  /// null encodes as a dropped key — and the hash chain is what makes
  /// tampering with the stored JSON loud; an explicit null marker was
  /// deliberately not introduced because it would change every stored
  /// delta digest and invalidate existing ledgers.
  ///
  /// ### Parameters:
  /// - [json]: The map produced by [toJson].

  factory StateDelta.fromJson(Map<String, Object?> json) => StateDelta(
    cellId: json['cellId'] as String,
    before: json['before'],
    after: json['after'],
    at: DateTime.parse(json['at'] as String),
  );

  /// A stable fingerprint of the delta, used by `LedgerEntry.hash` and by
  /// the `Ledger.verify` mismatch report.
  String get digest => fingerprint(toJson());
}