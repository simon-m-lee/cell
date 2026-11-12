// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The persistence backend for a [Ledger].
///
/// A store is responsible for:
///
/// * **Atomic append** — appending an entry either succeeds completely or
///   has no effect. A crash mid-append must not corrupt the ledger.
/// * **Sequential read** — reading entries in `seq` order, starting at a
///   given sequence number.
/// * **Last hash** — returning the current head, or `null` if the store
///   is empty.
///
/// The store does **not** validate hashes — that is `Ledger.verify`'s
/// job. This separation is deliberate: the store may be a network
/// service that cannot compute hashes efficiently, but the ledger can
/// always verify on top of any store.
abstract class LedgerStore {
  /// The genesis hash the store was created with. [Ledger.open] asserts
  /// this matches the chain genesis, so a store created for graph `G`
  /// can never silently serve graph `H`.
  String get genesisHash;

  /// Append [entry] to the store.
  ///
  /// Must be atomic. If `entry.seq` is not `lastSeq + 1`, must throw
  /// [StateError]. If the store is empty, `entry.seq` must be 0 and
  /// `entry.prevHash` must equal the store's genesis hash.
  Future<void> append(LedgerEntry entry);

  /// The last sequence number, or `-1` if the store is empty.
  Future<int> get lastSeq;

  /// The current head hash, or `null` if the store is empty.
  Future<String?> get lastHash;

  /// Iterate entries from `fromSeq` (inclusive) to the end.
  Stream<LedgerEntry> entriesSince(int fromSeq);

  /// Close the store. Any subsequent operation must fail.
  Future<void> close();
}
