// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A single cell's state change within a ledger entry.
///
/// Captured by `ValueCell.postProcessRule` immediately before and after
/// the commit, so `before` and `after` reflect the exact values the
/// receptor produced — not the values the caller *intended*. That
/// distinction matters: a receptor can transform its input, and the
/// ledger must record the transformed value, or replay will diverge.
///
/// ### Non-obvious: `before == after` is legal
///
/// A receptor can commit the same value (e.g., an idempotent `set`). The
/// delta is still recorded, because the *fact* that the pulse visited
/// the cell is part of the causal chain; the absence of a value change
/// is not the absence of an event.
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

  Map<String, Object?> toJson() => {
        'cellId': cellId,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        'at': at.toUtc().toIso8601String(),
      };

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
