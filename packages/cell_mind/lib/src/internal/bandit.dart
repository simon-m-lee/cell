// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// One joined (decision, outcome, reward) triple for bucketing.
final class _Sample {
  final ContextVector vector;
  final Verdict verdict;
  final double reward;

  const _Sample({
    required this.vector,
    required this.verdict,
    required this.reward,
  });
}

/// Per-context-vector reward aggregation.
final class _Bucket {
  final ContextVector vector;
  int acceptCount = 0;
  int rejectCount = 0;
  double acceptRewardSum = 0;
  double rejectRewardSum = 0;

  _Bucket(this.vector);

  void add(_Sample sample) {
    if (sample.verdict is Accept) {
      acceptCount++;
      acceptRewardSum += sample.reward;
    } else {
      // Defer counts as "not accepted" for the bandit (Phase 4 will
      // treat it explicitly).
      rejectCount++;
      rejectRewardSum += sample.reward;
    }
  }

  int get support => acceptCount + rejectCount;

  double get avgAccept => acceptCount == 0 ? 0 : acceptRewardSum / acceptCount;

  double get avgReject => rejectCount == 0 ? 0 : rejectRewardSum / rejectCount;

  /// |avg reward(accept) − avg reward(reject)|, clamped to [0, 1].
  double get confidence => (avgAccept - avgReject).abs().clamp(0.0, 1.0);

  /// The preferred verdict for this bucket: the higher-reward action.
  String get preferredAction => avgAccept >= avgReject ? 'accept' : 'reject';
}

/// The contextual bandit trainer.
///
/// ### How it works
/// 1. Joins decisions with outcomes by `decisionId` (within `window`).
/// 2. Computes each sample's context vector and reward.
/// 3. Buckets samples by vector key and aggregates reward per verdict.
/// 4. Emits one rule per bucket meeting `minSupport`/`minConfidence`,
///    sorted by confidence descending, capped at `maxRules`.
/// 5. Merges with the existing `cell_mind.policy` block (additive by
///    default; full replacement with `prune: true`) and returns the
///    merged block in a [TrainedPolicy].
///
/// ### Non-obvious
/// - **The merge happens before the evolve.** F1 proved `Context.evolve`
///   replaces the constraints map; the trainer merges first and
///   [TrainedPolicy.applyTo] evolves once.
/// - **Journaled.** `trainedAt` comes from `journal.clock()`; the run
///   and any pruning are recorded as `io` effects (`mind.training` /
///   `mind.pruning`) so replay consumes the same effect sequence.
final class _ContextualBanditTrainer implements Trainer {
  @override
  Future<TrainedPolicy> train({
    required Iterable<Decision> decisions,
    required Iterable<Outcome> outcomes,
    required Context baseContext,
    required EffectJournal journal,
    RewardFunction? reward,
    TrainingConfig? config,
  }) async {
    final cfg = config ?? const TrainingConfig();
    final decisionList = decisions.toList();
    final now = journal.clock();

    final joined = _join(decisionList, outcomes, cfg.window, now);
    final samples = <_Sample>[];
    for (final (decision, outcome) in joined) {
      final r = reward?.call(decision, outcome) ?? outcome.reward;
      samples.add(
        _Sample(
          vector: ContextVector.of(decision),
          verdict: decision.verdict,
          reward: r,
        ),
      );
    }

    final buckets = _bucket(samples);
    final nextVersion = _nextPolicyVersion(baseContext);
    final emitted = _emitRules(buckets, cfg, nextVersion);
    final existing = _readPolicyBlock(baseContext);
    final merged = _mergePolicyBlock(
      existing: existing,
      emitted: emitted,
      config: cfg,
      version: nextVersion,
    );

    // Effects, in a fixed order so replay consumes the same sequence:
    // clock → [pruning] → training.
    if (cfg.prune) {
      final existingRules = (existing['rules'] as List?) ?? const [];
      final emittedKeys = emitted.map(_ruleKey).toSet();
      final removed = existingRules
          .where((rule) => rule is Map && !emittedKeys.contains(_ruleKey(rule)))
          .map((rule) => _canonicalWhen(rule['when'] is Map
              ? rule['when'] as Map<dynamic, dynamic>
              : const {}))
          .toList();
      if (removed.isNotEmpty) {
        await journal.io<Object?>(
          label: 'mind.pruning',
          input: nextVersion,
          run: () async => null,
          serializeOutput: (_) => {
            'version': nextVersion,
            'removed': removed,
            'at': now.toUtc().toIso8601String(),
          },
        );
      }
    }

    final averageReward = samples.isEmpty
        ? 0.0
        : samples.map((s) => s.reward).reduce((a, b) => a + b) / samples.length;

    final result = TrainedPolicy(
      policyBlock: merged,
      decisionCount: decisionList.length,
      resolvedCount: samples.length,
      trainedAt: now,
      algorithm: 'contextualBandit',
      averageReward: averageReward,
    );

    await journal.io<Object?>(
      label: 'mind.training',
      input: nextVersion,
      run: () async => null,
      serializeOutput: (_) => {
        'version': nextVersion,
        'algorithm': 'contextualBandit',
        'decisionCount': decisionList.length,
        'resolvedCount': samples.length,
        'averageReward': averageReward,
        'ruleCount': result.ruleCount,
        'at': now.toUtc().toIso8601String(),
      },
    );

    return result;
  }

  Iterable<(Decision, Outcome)> _join(
    Iterable<Decision> decisions,
    Iterable<Outcome> outcomes,
    Duration? window,
    DateTime now,
  ) sync* {
    final byId = <String, Outcome>{};
    for (final outcome in outcomes) {
      // First outcome wins for duplicate decision ids (documented).
      byId.putIfAbsent(outcome.decisionId, () => outcome);
    }
    for (final decision in decisions) {
      if (window != null && now.difference(decision.at) > window) continue;
      final outcome = byId[decision.id];
      if (outcome == null) continue;
      yield (decision, outcome);
    }
  }

  Map<String, _Bucket> _bucket(Iterable<_Sample> samples) {
    final buckets = <String, _Bucket>{};
    for (final sample in samples) {
      buckets
          .putIfAbsent(sample.vector.key, () => _Bucket(sample.vector))
          .add(sample);
    }
    return buckets;
  }

  List<Map<String, dynamic>> _emitRules(
    Map<String, _Bucket> buckets,
    TrainingConfig cfg,
    int version,
  ) {
    final rules = <Map<String, dynamic>>[];
    for (final bucket in buckets.values) {
      if (bucket.support < cfg.minSupport) continue;
      if (bucket.confidence < cfg.minConfidence) continue;
      rules.add({
        'when': bucket.vector.when,
        'action': bucket.preferredAction,
        'confidence': bucket.confidence,
        'support': bucket.support,
        'trainedIn': version,
      });
    }
    rules.sort(
      (a, b) => ((b['confidence'] as num).toDouble())
          .compareTo((a['confidence'] as num).toDouble()),
    );
    return rules.length > cfg.maxRules ? rules.sublist(0, cfg.maxRules) : rules;
  }
}
