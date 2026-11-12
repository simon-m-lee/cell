// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The declarative marker for effectful receptors and rules.
///
/// Mixing in [Effectful] does **not** automatically route effects through
/// a journal — the receptor body must call `journal.clock()`,
/// `journal.io(...)`, etc. explicitly. What the mixin provides is:
///
/// 1. **A compiler-enforced contract** at the retrofit sites. Phase 3
///    changes `asyncMap` and friends to accept a non-optional `journal:`
///    parameter, and the `Effectful` mixin is how the framework
///    signatures communicate "this receptor must be journalled".
///
/// 2. **A stable `purity` override.** Any class mixing in `Effectful`
///    reports [Purity.effectful] from [Receptor.purity] and
///    [TestCell.purity]. The [CellGraph] uses this in Phase 5 to refuse
///    an *exact* (journal-free) replay of a cell whose purity is
///    `effectful` — so a user who forgets to journal gets a loud failure
///    at graph construction, not a silent divergence during replay.
///
/// ### Non-obvious: this is *not* a base class
///
/// `Effectful` is a mixin, not a class, so receptors can extend their
/// existing hierarchy (e.g. `_Receptor` in `receptor.dart`) without
/// multiple inheritance. The mixin's only member is
/// `Purity get purity => Purity.effectful`, which the retrofit sites
/// already declare on their own classes — the mixin exists so *user*
/// receptors can opt in without writing the override by hand.
mixin Effectful {
  /// Effectful receptors are not exactly replayable; they require a
  /// journal. Overrides the default `pure`.
  Purity get purity => Purity.effectful;
}

/// A variant of [Effectful] for receptors that *read* the outside world
/// but do not mutate it (clocks, environment variables, read-only
/// database lookups). Reports [Purity.readOnlyExternal].
///
/// Phase 3 introduces this to distinguish the two journaling costs:
/// recording a *read* is one effect per observation; recording a *write*
/// is also one effect, but a write cannot be replayed at all (only its
/// effects log is), so `readOnlyExternal` is *more* replayable than
/// `effectful`.
mixin EffectfulReadOnly {
  Purity get purity => Purity.readOnlyExternal;
}
