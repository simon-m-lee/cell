// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// A portable record of a training run.
///
/// ### When to use
/// Read the result of [trainOffline]. Persist via `toMap` / `fromMap`.
/// Apply to a base [Context] via [applyTo].
///
/// ### Non-obvious
/// - **Not a `Context`.** `TrainedPolicy` is a portable record; the
///   enriched `Context` is derived by [applyTo]. The same policy can
///   apply to different base contexts.
/// - **`policyBlock` is the source of truth.** The other fields are
///   audit metadata; the rules live in `policyBlock`.
/// - **`trainedAt` is journal time.** In a journaled run it is the
///   recorded clock value, so replays reproduce it exactly.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
final class TrainedPolicy {
  /// The learned policy block — the `cell_mind.policy` shape.
  final Map<String, dynamic> policyBlock;

  /// Total decisions in the training log.
  final int decisionCount;

  /// Resolved decisions (those with outcomes).
  final int resolvedCount;

  /// Timestamp of the training run (journal time, replayable).
  final DateTime trainedAt;

  /// Algorithm identifier (`'contextualBandit'`).
  final String algorithm;

  /// Average reward across resolved decisions (0.0 when empty).
  final double averageReward;

  const TrainedPolicy({
    required this.policyBlock,
    required this.decisionCount,
    required this.resolvedCount,
    required this.trainedAt,
    required this.algorithm,
    required this.averageReward,
  });

  /// Applies this policy block to [base].
  ///
  /// ### How it works
  /// Merges `policyBlock` into
  /// `base.constraints['cell_mind.policy']` and evolves once — the
  /// trainer already merged existing rules, so this is a straight
  /// write. Other constraint keys are preserved.
  Context applyTo(Context base) => base.evolve((gov) {
        if (gov != Ontology.constraints) return null;
        return Ontology.constraints.entry({
          ...?base.constraints,
          'cell_mind.policy': policyBlock,
        });
      });

  /// Serializes this training record for persistence.
  Map<String, dynamic> toMap() => {
        'decisionCount': decisionCount,
        'resolvedCount': resolvedCount,
        'trainedAt': trainedAt.toUtc().toIso8601String(),
        'algorithm': algorithm,
        'averageReward': averageReward,
        'policyBlock': policyBlock,
      };

  /// Reconstructs a training record from [TrainedPolicy.toMap] output.
  static TrainedPolicy fromMap(Map<String, dynamic> map) => TrainedPolicy(
        decisionCount: map['decisionCount'] as int,
        resolvedCount: map['resolvedCount'] as int,
        trainedAt: DateTime.parse(map['trainedAt'] as String),
        algorithm: map['algorithm'] as String,
        averageReward: (map['averageReward'] as num).toDouble(),
        policyBlock: (map['policyBlock'] as Map).cast<String, dynamic>(),
      );

  /// The number of rules in the block (0 when absent).
  int get ruleCount => ((policyBlock['rules'] as List?) ?? const []).length;

  @override
  String toString() => 'TrainedPolicy($algorithm, $ruleCount rules, '
      '$resolvedCount/$decisionCount resolved)';
}

/// The reward function. Called once per resolved decision.
///
/// ### Signature
/// [decision] — the record being rewarded.
/// [outcome] — the typed outcome emitted for it.
///
/// ### Return
/// A double. Positive for good outcomes, negative for bad, zero for
/// neutral.
/// ### When to use
/// The declared purpose is stated above; this section pins the
/// canonical entry point and its prerequisites.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the `fromMap` entry
///   point paired with this type.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// {@category Organ}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
typedef RewardFunction = double Function(Decision decision, Outcome outcome);

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
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
/// Configuration for a training run.
///
/// ### Non-obvious
/// - **All fields have safe defaults.** `TrainingConfig()` uses
///   `minSupport: 5`, `minConfidence: 0.6`, `maxRules: 100`, no window,
///   no pruning. Rules below the thresholds are not emitted.
/// - **`window` filters decisions by `Decision.at`**, measured against
///   journal time when the run is journaled — replay reproduces
///   identical windows.
/// - **`prune: true` replaces all existing rules.** See
///   `guide/03-Learning.md` §6.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class TrainingConfig {
  /// Minimum observations required to emit a rule.
  final int minSupport;

  /// Minimum |avg reward(accept) − avg reward(reject)| required.
  final double minConfidence;

  /// Maximum rules emitted per run.
  final int maxRules;

  /// Rolling window of decisions to train on; null = all.
  final Duration? window;

  /// Full replacement of existing rules when true; additive default.
  final bool prune;

  const TrainingConfig({
    this.minSupport = 5,
    this.minConfidence = 0.6,
    this.maxRules = 100,
    this.window,
    this.prune = false,
  });
}

/// ### When to use
/// The declared purpose above names the entry point; this
/// section pins its prerequisites and its place in the pipeline.
///
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
/// The trainer protocol. Implementations are offline batch jobs.
///
/// ### Non-obvious
/// - **Not a `Cell`.** Trainers are pure functions of their inputs:
///   the same log, outcomes, context, and journal time produce the same
///   [TrainedPolicy].
/// - **Always journal-aware.** The [journal] parameter is required —
///   trainers declare `Purity.effectful` and record their effects.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
abstract class Trainer {
  /// Trains a policy from decision and outcome logs.
  Future<TrainedPolicy> train({
    required Iterable<Decision> decisions,
    required Iterable<Outcome> outcomes,
    required Context baseContext,
    required EffectJournal journal,
    RewardFunction? reward,
    TrainingConfig? config,
  });
}

/// The default trainer — a contextual bandit.
///
/// See `guide/03-Learning.md` §4 for the algorithm.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### When to use
/// The declared purpose is stated above; this section pins the
/// canonical entry point and its prerequisites.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the `fromMap` entry
///   point paired with this type.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
Trainer contextualBandit() => _ContextualBanditTrainer();

/// Trains a policy from a [handle]'s decision log and an [outcomes] log.
///
/// ### Parameters
/// * [handle] — the cognitive handle whose decisions to train on.
/// * [outcomes] — the `TissueList<Outcome>` from [recordOutcomes].
/// * [baseContext] — the starting context, usually
///   `handle.cell.context`.
/// * [trainer] — the trainer to run.
/// * [journal] — effect journal for the run (required; no default).
/// * [reward] — optional custom reward function; when null the
///   `Outcome.reward` value is used.
/// * [config] — optional training configuration.
///
/// ### Non-obvious
/// The returned [TrainedPolicy] is applied with `applyTo(...)`; nothing
/// mutates the handle or its context.
///
/// {@category Organ}
/// {@category Learning}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### When to use
/// The declared purpose is stated above; this section pins the
/// canonical entry point and its prerequisites.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
Future<TrainedPolicy> trainOffline({
  required CognitiveHandle handle,
  required TissueList<Outcome> outcomes,
  required Context baseContext,
  required Trainer trainer,
  required EffectJournal journal,
  RewardFunction? reward,
  TrainingConfig? config,
}) =>
    trainer.train(
      decisions: handle.decisions.toList(),
      outcomes: outcomes.toList(),
      baseContext: baseContext,
      journal: journal,
      reward: reward,
      config: config,
    );
