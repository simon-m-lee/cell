// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// A typed reward record from the outcomes channel.
///
/// ### When to use
/// Read from the `TissueList<Outcome>` returned by [recordOutcomes].
/// Consumed by `Trainer.train` to compute rewards.
///
/// ### Non-obvious
/// - **`at` is the emission timestamp**, not the decision timestamp.
///   For latency analysis, join with `Decision.at`.
/// - **`metadata` is user-defined.** Common uses: tool name, model id,
///   error code. Trainers that need attribution should read this.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class Outcome {
  /// The id of the rewarded decision.
  final String decisionId;

  /// Positive for good, negative for bad, zero for neutral.
  final double reward;

  /// Optional user-defined context for the outcome.
  final Map<String, dynamic>? metadata;

  /// The emission timestamp.
  final DateTime at;

  const Outcome({
    required this.decisionId,
    required this.reward,
    required this.at,
    this.metadata,
  });

  /// Serializes this outcome for persistence.
  Map<String, dynamic> toMap() => {
        'decisionId': decisionId,
        'reward': reward,
        'metadata': metadata,
        'at': at.toUtc().toIso8601String(),
      };

  /// Reconstructs an outcome from [Outcome.toMap] output.
  static Outcome fromMap(Map<String, dynamic> map) => Outcome(
        decisionId: map['decisionId'] as String,
        reward: (map['reward'] as num).toDouble(),
        metadata: (map['metadata'] as Map?)?.cast<String, dynamic>(),
        at: DateTime.parse(map['at'] as String),
      );

  @override
  String toString() => 'Outcome($decisionId, $reward)';
}

/// Subscribes to [handle]'s outcome channel and accumulates a typed log.
///
/// ### When to use
/// Call this when starting a training window. Keep the returned `log`
/// in scope for the window; call `stop()` to end recording.
///
/// ### How it works
/// 1. Subscribes to `handle.outcomes.cell` via [Cell.observe].
/// 2. Unwraps the channel contract (entry payload = the outcome pulse)
///    and parses each `mind.outcome` pulse into an [Outcome].
/// 3. Ignores malformed payloads (defensive).
/// 4. Returns a record with the log and a `stop` function.
///
/// ### Non-obvious
/// - **The log is a `TissueList`**, not a plain list — observable and
///   serializable like any tissue.
/// - **`stop()` does not clear the log.** Accumulated outcomes remain
///   available after the subscription ends.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
({TissueList<Outcome> log, void Function() stop}) recordOutcomes(
  CognitiveHandle handle,
) {
  final log = TissueList<Outcome>();
  final sub = Cell.observe(
      source: handle.outcomes.cell,
      effect: (Pulse p) {
        // Channel contract (guide/02-Runtime.md §6): the entry's payload IS
        // the outcome pulse; its payload is the reward map.
        final outcomePulse =
            p.payload is Pulse ? p.payload as Pulse : p.payload;
        if (outcomePulse is! Pulse) return;
        if (outcomePulse.type != 'mind.outcome') return;
        final payload = outcomePulse.payload;
        if (payload is! Map) return;
        final decisionId = payload['decisionId'];
        final reward = payload['reward'];
        if (decisionId is! String) return;
        if (reward is! num) return;
        log.add(
          Outcome(
            decisionId: decisionId,
            reward: reward.toDouble(),
            metadata: (payload['metadata'] as Map?)?.cast<String, dynamic>(),
            at: p.timestamp,
          ),
        );
      });
  return (log: log, stop: sub.stop);
}
