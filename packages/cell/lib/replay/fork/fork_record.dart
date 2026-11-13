// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The genesis record of a fork ledger.
///
/// A fork ledger's `seq 0` is always a `ForkRecord`. It carries enough
/// information for an auditor to answer three questions:
///
/// * **Where did the fork start?** `divergedAt` is the parent ledger's
///   sequence number at which the fork was taken.
/// * **What was the state at the fork point?** `originalSnapshotHash` is
///   the parent graph's snapshot hash at `divergedAt`. It binds the
///   fork to a specific parent state, so two forks at the same `atSeq`
///   with different snapshot hashes are distinguishable.
/// * **Which fork is this?** `forkId` is a UUID; two forks of the same
///   parent at the same `atSeq` get different ids.
///
/// ### Non-obvious: the fork record is *not* a `LedgerEntry`
///
/// It has a different shape and different verification rules (the
/// genesis `prevHash` is not the graph's genesis hash, it is the fork
/// record's own genesis hash; the `hash` is computed from the synthetic
/// entry's fields by the fork ledger store). `ForkLedgerStore` presents
/// the fork record as a synthetic seq-0 entry so `Ledger.verify` runs
/// unmodified, and the fork's real entries chain from it.
class ForkRecord {
  /// UUID identifying this fork.
  final String forkId;

  /// UUID of the parent ledger's graph.
  final String originalLedgerId;

  /// Sequence number in the parent ledger at which the fork was taken.
  /// The fork's baseline is parent entries `0..divergedAt` inclusive;
  /// the fork replays `divergedAt + 1` onward.
  final int divergedAt;

  /// The parent graph's snapshot hash at `divergedAt`. Used to bind the
  /// fork to a specific parent state.
  final String originalSnapshotHash;

  /// The hash of the parent ledger's entry at `divergedAt`.
  final String parentHeadHash;

  /// Wall-clock time the fork was created.
  final DateTime at;

  const ForkRecord({
    required this.forkId,
    required this.originalLedgerId,
    required this.divergedAt,
    required this.originalSnapshotHash,
    required this.parentHeadHash,
    required this.at,
  });

  /// The fork's chain genesis. This is *not* the graph's genesis hash
  /// (that would defeat the point — the fork's chain must be
  /// distinguishable from the parent's). It is a hash of the fork
  /// record itself, so the fork is identifiable by its own genesis.
  String get genesisHash => fingerprint({
        'forkId': forkId,
        'originalLedgerId': originalLedgerId,
        'divergedAt': divergedAt,
        'originalSnapshotHash': originalSnapshotHash,
        'parentHeadHash': parentHeadHash,
      });

  Map<String, Object?> toJson() => {
        'forkId': forkId,
        'originalLedgerId': originalLedgerId,
        'divergedAt': divergedAt,
        'originalSnapshotHash': originalSnapshotHash,
        'parentHeadHash': parentHeadHash,
        'at': at.toUtc().toIso8601String(),
      };

  factory ForkRecord.fromJson(Map<String, Object?> json) => ForkRecord(
        forkId: json['forkId'] as String,
        originalLedgerId: json['originalLedgerId'] as String,
        divergedAt: json['divergedAt'] as int,
        originalSnapshotHash: json['originalSnapshotHash'] as String,
        parentHeadHash: json['parentHeadHash'] as String,
        at: DateTime.parse(json['at'] as String),
      );
}
