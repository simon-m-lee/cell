// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// How a fork handles the parent graph's state.
///
/// The fork engine supports only [isolated]. The other two are documented as
/// later extensions, listed here so the public API is stable and
/// callers can write future-proof code.
enum ForkPolicy {
  /// **Default.** The fork gets a *fresh* graph and a *fresh* ledger
  /// store. The parent graph and parent ledger are untouched. The
  /// caller provides a factory that builds the fresh graph from the
  /// same `CellGraphBuilder` the original was built from.
  ///
  /// This is the only policy the fork engine implements. It is correct for
  /// every case, at the cost of rebuilding the graph (which is fast —
  /// it is the same as the original build).
  isolated,

  /// **Later revision.** The fork reuses the parent's `CellGraph` shape (same
  /// `Nucleus` instances) but with a fresh state. Requires the ability
  /// to clone a `Nucleus` without cloning its `Box`, which snapshot
  /// snapshot reconstruction provides.
  ///
  /// Using this today throws `UnimplementedError`.
  sharedTopology,

  /// **Later revision.** A fork that stops *at* `divergedAt` — used by the
  /// CLI's `replay fork --at N --stop-at N` to produce a snapshot at a
  /// historical point without replaying forward. The fork engine does not
  /// implement this because the CLI predates it.
  dropUnreached,
}
