// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The persistence backend for a [Ledger].
///
/// [LedgerStore] is the **Storage Contract** between the hash-chained
/// [Ledger] and whatever medium holds its entries — memory, a JSONL
/// file, or (in future) a network service. It defines atomic append,
/// sequential read, and head lookup, and nothing else.
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
/// ### Why it is used
/// Separating persistence from verification lets the ledger run on top of
/// any medium: an in-memory list for tests, a JSONL file for durability,
/// or a remote service that cannot compute hashes cheaply. The ledger's
/// integrity guarantees are independent of the store's implementation.
///
/// ### How it works
/// [Ledger] calls [append] with a fully formed, hash-linked entry; the
/// store persists it atomically. [Ledger.verify] later reads every entry
/// through [entriesSince] and recomputes the chain. The store never
/// validates hashes — that is the ledger's job.
///
/// ### Technical Details
/// - **Non-obvious: the store does not validate hashes.** This is
///   deliberate: the store may be a network service that cannot compute
///   hashes efficiently, but the ledger can always verify on top of any
///   store.
/// - **Genesis binding.** Each store records the [genesisHash] it was
///   created with; [Ledger.open] asserts it matches the chain genesis, so
///   a store created for graph `G` can never silently serve graph `H`.
///
/// See also:
/// - [InMemoryLedgerStore] — an ephemeral store for tests.
/// - `FileLedgerStore` — a durable JSONL-backed store (`dart:io`).
/// - [Ledger] — the hash-chained record that consumes this store.
/// {@category Replay}
/// {@category Ledger}
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