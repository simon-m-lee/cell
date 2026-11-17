// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Strictness flags that control the replay engine's behaviour when the
/// replayed state diverges from the recorded state.
///
/// ### When to use
/// The default is **strict** for everything. This is deliberate: a
/// divergence means the receptor, test rule, or graph topology has
/// changed since the recording was taken, and continuing past it would
/// silently produce a state that no ledger entry explains. A caller who
/// wants lenient replay (e.g. for a "best-effort" what-if) opts in
/// explicitly, which is the correct ergonomic for a forensic tool.
///
/// ### How it works
/// [failOnDivergence] decides throw-vs-continue, [verifyReceipts] gates
/// the back-filled receipt checks, [settleAfterDispatch] drains one
/// event-loop turn per dispatch, and [maxEntries] bounds the replay
/// length.
///
/// See also:
/// * [ReplayEngine.replay] — consumes these options.
/// * [ReplayResult] — the outcome a lenient replay returns.
/// {@category Replay}
class ReplayOptions {
  /// If `true` (default), throw [ReplayDivergenceException] on the first
  /// divergence. If `false`, record the divergence in [ReplayResult]
  /// and continue replaying.
  ///
  /// Continuing is **never** safe for verification — the resulting state
  /// is not the recorded state — but it is useful for the CLI's
  /// `replay diff` command, which wants the *full* list of
  /// divergences, not just the first.
  final bool failOnDivergence;

  /// If `true` (default), verify each entry's `receipt.ledgerSeq` and
  /// `receipt.pulseDigest` against the entry itself. A ledger
  /// constructed by hand (not by `Ledger.appendInternal`) has these
  /// fields `null`, which this check rejects as a divergence.
  ///
  /// Disable only for tests that build ledger entries by hand.
  final bool verifyReceipts;

  /// If `true` (default), the engine settles the event-loop microtask
  /// queue after each dispatch before checking the journal and deltas.
  /// Asynchronous receptor continuations (asyncMap mappers, deferred
  /// timer fires) complete in microtasks; without the settle the engine
  /// would assert exhaustion before the receptor had consumed its
  /// effects. (The engine design called this flag `reseedCycleChecker`;
  /// the cycle-checker reseed itself is a governance concern, so the flag
  /// carries the settle behaviour that is actually load-bearing for
  /// the engine's acceptance criteria.)
  ///
  /// ### Non-obvious: one settle is one event-loop turn
  ///
  /// A chain of N unawaited timers needs one turn per hop; a single
  /// settle covers one level. Deep unawaited chains (and real-timer
  /// waits longer than a microtask flush) are the pulse-tagged-window
  /// territory of a later revision — receptors that await their work are fully
  /// covered by the single turn.
  final bool settleAfterDispatch;

  /// Maximum number of entries to replay. `null` means unlimited. Used
  /// by the CLI's `--limit` flag; also useful for property tests that
  /// want to explore a prefix of a ledger.
  final int? maxEntries;

  /// Creates a [ReplayOptions] set.
  ///
  /// ### Parameters:
  /// - [failOnDivergence]: If `true` (default), throw on the first
  ///   divergence.
  /// - [verifyReceipts]: If `true` (default), verify each entry's
  ///   back-filled receipt fields.
  /// - [settleAfterDispatch]: If `true` (default), settle the event-loop
  ///   microtask queue after each dispatch.
  /// - [maxEntries]: Maximum number of entries to replay (`null` =
  ///   unlimited).
  const ReplayOptions({
    this.failOnDivergence = true,
    this.verifyReceipts = true,
    this.settleAfterDispatch = true,
    this.maxEntries,
  });

  /// Lenient preset for the CLI's `replay diff` mode.
  static const ReplayOptions diff = ReplayOptions(
    failOnDivergence: false,
  );

  /// Strict preset for production verification (the default).
  static const ReplayOptions strict = ReplayOptions();
}
