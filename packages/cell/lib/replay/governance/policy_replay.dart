// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Policy-tick journaling for [EphemeralPolicy].
///
/// The journal records timers and the engine deferred policy-tick reseeding.
/// The governance layer closes the loop: every tick of an `EphemeralPolicy` during
/// pulse processing is journaled as a `PolicyTickEffect`. On replay,
/// the tick is consumed from the journal and re-applied to the
/// `CycleChecker` — the cycle-checker reseed fix.
///
/// ### Honest boundary (review fix): the checker is reseeded, not the
/// policy's *state*
///
/// `ReplayJournal.policyTick` consumes the record and never calls
/// `policy.call` — that call is what updates the policy's event count,
/// arms the TTL timer, and reclaims the cell on the live path, and the
/// TTL timer itself is a raw Dart timer, not a journal effect.
/// Consequence: a governed cell can replay with matching deltas but a
/// different *lifetime* — an entry where the limit would have tripped
/// still commits, and later pulses that the recording dropped are not
/// dropped on replay. Full policy-state fidelity (TTL and event-limit
/// bookkeeping through the journal) is deferred work; what the current
/// engine guarantees is tick ORDER parity through the checker reseed.
abstract final class PolicyReplay {
  /// Records (or replays) a policy tick.
  ///
  /// Called from the receptor pipeline at the point where the cell's
  /// hosted `EphemeralPolicy` would be ticked. On the recording side
  /// the policy callback still runs (after the record is written); on
  /// the replay side `ReplayJournal.policyTick` only consumes the
  /// record — the caller does not re-invoke the policy callback.
  ///
  /// The journal input is the pulse's *payload* — the pulse object
  /// itself is not stable across record/replay, its payload is. The
  /// policy callback still receives the pulse (preserving the
  /// pre--7 contract) on the recording side only.
  static void tick({
    required EphemeralPolicy policy,
    required Cell cell,
    required PulseBase pulse,
  }) {
    final journal = JournalScope.current;
    if (journal is NullJournal) {
      // No journal: this tick is not being recorded. The graph is not
      // ledgered; call the policy as before.
      policy.call(pulse, cell: cell);
      return;
    }
    journal.policyTick(
      // runtimeType only: identity hashes differ between the recording
      // and replay processes, and the journal compares labels exactly.
      policyLabel: '${policy.runtimeType}',
      cellId: cell.id,
      input: pulse.payload,
    );
    if (journal is! ReplayJournal) {
      policy.call(pulse, cell: cell);
    }
  }
}
