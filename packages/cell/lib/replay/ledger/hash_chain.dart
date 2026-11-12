// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The rolling hash chain that binds ledger entries.
///
/// Each entry's `hash` is `H(prevHash || seq || pulseDigest ||
/// receiptDigest || effectsDigest || deltaDigest || at)`. The genesis
/// entry's `prevHash` is the graph id's fingerprint — a `Ledger` tied to
/// graph `G` cannot be confused with a `Ledger` tied to graph `H`, even
/// if their entries happen to be identical, because the genesis hash
/// differs.
///
/// ### Non-obvious: why a chain, not a Merkle tree
///
/// A Merkle tree allows *log n* membership proofs — an auditor can be
/// convinced that entry `k` was recorded without reading the whole
/// ledger. That is a real benefit, but it comes at the cost of
///
/// * a tree structure that must be rebuilt on every append (O(n) unless
///   you grow it incrementally, which complicates the store contract);
/// * a larger on-disk format (each internal node is a row);
/// * a decision about how to handle *forked* ledgers (Phase 6) that is
///   different for a tree than for a chain.
///
/// A hash chain gives the *linearity* guarantee — any tamper breaks the
/// chain from the tampered entry onward, and `verify()` catches it in a
/// single sequential pass. That is the guarantee Phase 4 needs. Merkle
/// proofs are a Phase 6+ concern; if they are added, `HashChain` becomes
/// the leaf hash and a parallel `MerkleTree` sits alongside it.
class HashChain {
  /// The graph id that seeds the chain. Stored as the genesis `prevHash`.
  final String genesisHash;

  const HashChain(this.genesisHash);

  /// The hash of the entry that would come next, given the chain's
  /// current head.
  String nextHash({
    required String prevHash,
    required int seq,
    required String pulseDigest,
    required String receiptDigest,
    required String effectsDigest,
    required String deltaDigest,
    required DateTime at,
  }) {
    // Field order is frozen. Reordering this input is a **breaking
    // schema change** (bump `CellGraphSnapshot.currentSchemaVersion`).
    return fingerprint({
      'prevHash': prevHash,
      'seq': seq,
      'pulseDigest': pulseDigest,
      'receiptDigest': receiptDigest,
      'effectsDigest': effectsDigest,
      'deltaDigest': deltaDigest,
      'at': at.toUtc().toIso8601String(),
    });
  }
}
