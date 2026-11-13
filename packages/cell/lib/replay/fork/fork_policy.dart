// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// How a fork handles the parent graph's state.
///
/// Phase 6 supports only [isolated]. The other two are documented as
/// Phase 6.1 extensions, listed here so the public API is stable and
/// callers can write future-proof code.
enum ForkPolicy {
  /// **Default.** The fork gets a *fresh* graph and a *fresh* ledger
  /// store. The parent graph and parent ledger are untouched. The
  /// caller provides a factory that builds the fresh graph from the
  /// same `CellGraphBuilder` the original was built from.
  ///
  /// This is the only policy Phase 6 implements. It is correct for
  /// every case, at the cost of rebuilding the graph (which is fast —
  /// it is the same as the original build).
  isolated,

  /// **Phase 6.1.** The fork reuses the parent's `CellGraph` shape (same
  /// `Nucleus` instances) but with a fresh state. Requires the ability
  /// to clone a `Nucleus` without cloning its `Box`, which Phase 5.1's
  /// snapshot reconstruction provides.
  ///
  /// Using this in Phase 6 throws `UnimplementedError`.
  sharedTopology,

  /// **Phase 6.1.** A fork that stops *at* `divergedAt` — used by the
  /// CLI's `replay fork --at N --stop-at N` to produce a snapshot at a
  /// historical point without replaying forward. Phase 6 does not
  /// implement this because the CLI does not exist yet (Phase 8).
  dropUnreached,
}
