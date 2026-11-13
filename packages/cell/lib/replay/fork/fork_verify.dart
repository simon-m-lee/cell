// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Fork-aware verification. A fork's `verify()` requires the parent
/// ledger's `verify()` to pass.
///
/// The verification steps are:
///
/// 1. **Parent ledger verification**: the parent must be intact. A fork
///    from a corrupt ledger is a fork from a lie.
/// 2. **Fork chain verification**: the fork's own chain (from
///    `ForkRecord.genesisHash` onward) must be intact.
/// 3. **Genesis binding verification**: the `ForkRecord.parentHeadHash`
///    must match the parent's hash at `divergedAt`. This is what makes
///    the fork a *fork* — a fork record whose `parentHeadHash` does
///    not match the parent's actual hash is either stale or forged.
extension ForkVerify on ForkHandle {
  /// Verifies the fork: parent intact, fork chain intact, genesis
  /// binding intact.
  ///
  /// Throws [ForkIntegrityException] on any failure.
  Future<void> verify() async {
    // 1. Verify the parent.
    try {
      await parent.verify();
    } catch (e) {
      throw ForkIntegrityException(
        forkId: record.forkId,
        reason: 'parent ledger verification failed: $e',
      );
    }

    // 2. Verify the fork's chain.
    try {
      await ledger.verify();
    } catch (e) {
      throw ForkIntegrityException(
        forkId: record.forkId,
        reason: 'fork ledger verification failed: $e',
      );
    }

    // 3. Verify the genesis binding.
    final parentHead = await parent.hashAtSeq(record.divergedAt);
    if (parentHead != record.parentHeadHash) {
      throw ForkIntegrityException(
        forkId: record.forkId,
        reason: 'fork genesis binding failed: '
            'recorded parentHeadHash=${record.parentHeadHash} but '
            'parent ledger at seq ${record.divergedAt} has hash '
            '$parentHead',
      );
    }

    // 4. Verify the embedded fork record (Phase-8.3 review fix): the
    //    fork FILE's synthetic seq-0 entry carries the record as its
    //    first positional argument. The record's own genesis hash must
    //    match the chain's, and every field must match the handle's —
    //    a tampered or stale fork file fails here.
    try {
      final synthetic = await ledger.entriesSince(0).first;
      final positional = synthetic.receipt.arguments.positionalArguments;
      final embedded = positional?.isNotEmpty == true
          ? positional!.first
          : null;
      if (embedded is! Map) {
        throw ForkIntegrityException(
          forkId: record.forkId,
          reason: 'fork ledger seq 0 does not carry the embedded '
              'ForkRecord (missing or malformed first positional '
              'argument)',
        );
      }
      final embeddedRecord = ForkRecord.fromJson(
        Map<String, Object?>.from(embedded),
      );
      if (embeddedRecord.genesisHash != record.genesisHash) {
        throw ForkIntegrityException(
          forkId: record.forkId,
          reason: 'embedded fork record genesis mismatch: the stored '
              'record hashes to ${embeddedRecord.genesisHash} but the '
              'fork chain genesis is ${record.genesisHash}',
        );
      }
      if (embeddedRecord.forkId != record.forkId ||
          embeddedRecord.divergedAt != record.divergedAt ||
          embeddedRecord.parentHeadHash != record.parentHeadHash ||
          embeddedRecord.originalSnapshotHash !=
              record.originalSnapshotHash) {
        throw ForkIntegrityException(
          forkId: record.forkId,
          reason: 'embedded fork record mismatch: the stored seq-0 '
              'record differs from the fork handle\'s record',
        );
      }
    } on ForkIntegrityException {
      rethrow;
    } catch (e, st) {
      throw ForkIntegrityException(
        forkId: record.forkId,
        reason: 'embedded fork record verification failed: $e\n$st',
      );
    }
  }
}

/// The parent ledger's hash at a given sequence.
extension ForkParentLookup on Ledger {
  /// The hash of the entry at [seq] (the parent's sequence numbering).
  Future<String> hashAtSeq(int seq) async {
    if (seq < 0) {
      throw ArgumentError.value(seq, 'seq', 'must be >= 0');
    }
    String? hash;
    var lastSeq = -1;
    await for (final entry in entriesSince(0)) {
      if (entry.seq > seq) break;
      hash = entry.hash;
      lastSeq = entry.seq;
    }
    if (lastSeq != seq) {
      throw StateError(
        'Ledger does not contain seq $seq (last seen $lastSeq)',
      );
    }
    return hash!;
  }
}

/// Thrown by [ForkVerify.verify] when a fork's parent ledger, fork
/// ledger, or genesis binding is invalid.
class ForkIntegrityException implements Exception {
  final String forkId;
  final String reason;

  ForkIntegrityException({required this.forkId, required this.reason});

  @override
  String toString() => 'ForkIntegrityException($forkId): $reason';
}
