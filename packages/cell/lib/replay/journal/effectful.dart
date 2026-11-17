// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The declarative marker for effectful receptors and rules.
///
/// ### How it works
/// Mixing in [Effectful] does **not** automatically route effects through
/// a journal — the receptor body must call `journal.clock()`,
/// `journal.io(...)`, etc. explicitly. What the mixin provides is:
///
/// 1. **A compiler-enforced contract** at the retrofit sites. The journal
///    changes `asyncMap` and friends to accept a non-optional `journal:`
///    parameter, and the `Effectful` mixin is how the framework
///    signatures communicate "this receptor must be journalled".
///
/// 2. **A stable `purity` override.** Any class mixing in `Effectful`
///    reports [Purity.effectful] from [Receptor.purity] and
///    [TestCell.purity]. The [CellGraph] uses this in the engine to refuse
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
///
/// See also:
/// * [EffectfulReadOnly] — the read-only variant.
/// * [Purity] — the classification this marker reports.
mixin Effectful {
  /// Effectful receptors are not exactly replayable; they require a
  /// journal. Overrides the default `pure`.
  Purity get purity => Purity.effectful;
}

/// A variant of [Effectful] for receptors that *read* the outside world
/// but do not mutate it (clocks, environment variables, read-only
/// database lookups). Reports [Purity.readOnlyExternal].
///
/// ### How it works
/// This distinguishes the two journaling costs:
/// recording a *read* is one effect per observation; recording a *write*
/// is also one effect, but a write cannot be replayed at all (only its
/// effects log is), so `readOnlyExternal` is *more* replayable than
/// `effectful`.
mixin EffectfulReadOnly {
  Purity get purity => Purity.readOnlyExternal;
}

/// An effectful pass-through receptor used by the retrofitted operators
/// (`asyncMap`, `fromStream`, `fromFuture`). It behaves exactly like
/// `Receptor.passThrough` but reports [Purity.effectful], so
/// `CellGraph.purityOf` classifies the operator's cell correctly and
/// The engine refuses an exact (journal-free) replay.
class _EffectfulPassThroughReceptor extends _Receptor<Cell>
    with Effectful {
  _EffectfulPassThroughReceptor() : super();
}

/// A time-observing pass-through receptor used by `debounce`/`throttle`.
/// Waiting for a timer is an observation of the outside world (time), not
/// a mutation, so it reports [Purity.readOnlyExternal].
class _ReadOnlyExternalPassThroughReceptor extends _Receptor<Cell>
    with EffectfulReadOnly {
  _ReadOnlyExternalPassThroughReceptor() : super();
}
