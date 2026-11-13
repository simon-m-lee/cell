// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Classifies a [Receptor] or [TestCell] by its effect footprint.
///
/// The [CellGraph] uses this to decide whether a cell participates in a
/// replayable graph:
///
/// * [pure] cells can always be replayed — their output is a function of
///   their inputs alone.
/// * [readOnlyExternal] cells observe the outside world (a clock, a
///   read-only database, an environment variable) but do not mutate it.
///   They *can* be replayed, but only through an `EffectJournal`
///   that records every read so the same observations replay identically.
/// * [effectful] cells both read and write the outside world (network,
///   disk, notifications). They must be journalled; without a journal they
///   cannot be recorded at all, so a cell whose receptor is [effectful] is
///   *not* replayable in the strict sense — only the *effect log* is.
///
/// ### Why this matters for replay
///
/// Replay is only meaningful if the same pulse sequence through the same
/// cell produces the same state. If a receptor calls `DateTime.now()`, that
/// is an observable non-determinism — a pure receptor that happens to read
/// the clock is not pure at all. The framework cannot *prevent* user code
/// from doing this, but it can force the user to **declare** it, and the
/// `CellGraph` can then refuse to treat a declared-effectful cell as if it
/// were replayable.
///
/// See the purity boundary and the journal for the enforcement
/// mechanism (the `Effectful` mixin).
enum Purity {
  /// No observable effect on the outside world; replay is exact.
  pure,

  /// Reads external state (clocks, environment, read-only I/O) but does
  /// not mutate it. Replayable only with an `EffectJournal` that records
  /// every read.
  readOnlyExternal,

  /// Mutates external state (network writes, disk writes, event bus
  /// emissions). Not replayable in the strict sense; only the *effect log*
  /// is reproducible.
  effectful;

  /// Whether this purity is compatible with exact (journal-free) replay.
  bool get isExactlyReplayable => this == Purity.pure;

  /// Whether this purity requires an `EffectJournal` to replay.
  bool get requiresJournal => this != Purity.pure;
}
