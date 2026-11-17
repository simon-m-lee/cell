// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A forked history.
///
/// ### When to use
/// Created by [CellGraphFork.fork] (or directly, for tests). It carries:
///
/// * [graph] — the *fresh* graph the fork replays into. Its state has
///   already been brought to the parent's state at `divergedAt` (the
///   baseline replay inside `fork`).
/// * [ledger] — the fork's own ledger. Its `seq 0` is the `ForkRecord`.
/// * [record] — the `ForkRecord`, exposed for auditing.
/// * [parent] — the parent ledger the fork was taken from.
///
/// ### Non-obvious: the fork's ledger is *written during the fork*, not
/// copied
///
/// A forked ledger's entries are produced by the fork's own replay
/// ([ReplayEngineFork.replayFork] appends each replayed pulse). The
/// parent ledger's entries are *not* copied — the fork's chain starts at
/// the `ForkRecord` and goes forward from the fork point. This is what
/// makes the fork compact: a fork at seq 100 of a 1M-entry ledger has
/// (roughly) 1M-100 entries if it replays to the end, or however many
/// the caller wants.
///
/// ### Non-obvious: the fork's hash chain is independent
///
/// [ForkRecord.genesisHash] is the fork's chain genesis. Every
/// subsequent entry's `prevHash` is the previous *fork* entry's `hash`,
/// not the parent's. This means an auditor verifying a fork must verify
/// both chains: the fork from its `ForkRecord`, and the parent from
/// its own genesis. The two chains only meet at the `ForkRecord`'s
/// `parentHeadHash` field.
///
/// See also:
/// * [CellGraphFork.fork] — the factory that produces a handle.
/// * [ForkVerify.verify] — verifies both chains and their binding.
/// {@category Replay}
class ForkHandle {
  /// The fresh graph the fork replays into.
  final CellGraph graph;

  /// The fork's own ledger.
  final Ledger ledger;

  /// The `ForkRecord` that seeds the fork's chain.
  final ForkRecord record;

  /// The parent ledger the fork was taken from.
  final Ledger parent;

  const ForkHandle._({
    required this.graph,
    required this.ledger,
    required this.record,
    required this.parent,
  });
}
