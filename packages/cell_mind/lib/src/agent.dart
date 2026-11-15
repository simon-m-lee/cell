// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// A specification for spawning an agent.
///
/// ### When to use
/// Construct and pass to [spawn]. Describes the agent's identity, the
/// shared cell it observes, the mandate it operates under, and any
/// additional policy.
///
/// ### How it works
/// An immutable value object; [spawn] reads it to build the deputy
/// (`cell.deputy(context: mandate, testRule: testRule)`), the
/// recording handle, and the outcome subscription.
///
/// ### Non-obvious
/// - **`mandate` must descend from the cell's context.** `cell.deputy`
///   enforces causal integrity; violations throw at spawn time.
/// - **`policy` defaults to [learnedPolicy].** Agents use their own
///   learned rules by default; override to add structural policies.
/// - **`allowedStrategies`** gates the agent's verdicts by
///   `Provenance.strategy` when non-empty.
///
/// ### See also
/// - [spawn], [debate], `guide/08-Agents.md`.
///
/// ## AI Agent Guide
/// - Agents observe one shared source through deputy views; debates
///   route via `AgentSpec.routeIn`, never the agent view.
/// - Stateless agents vote identically — a second round cannot
///   change the outcome.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class AgentSpec<C extends Cell> {
  final String name;
  final C cell;
  final DeputyContext mandate;
  final TestCell testRule;
  final Set<ReasoningStrategy> allowedStrategies;
  final Policy? policy;
  final VerdictPolicy? verdictPolicy;

  /// Routes a debate question into this agent (usually the
  /// source ingress: `(p) => gate.ingest(p)`). The live
  /// substrate's deputies are not emittable cells, so debates
  /// inject through the shared source.
  final Future<void> Function(dynamic pulse)? routeIn;

  const AgentSpec({
    required this.name,
    required this.cell,
    required this.mandate,
    this.testRule = TestCell.allowAll,
    this.allowedStrategies = const {},
    this.policy,
    this.verdictPolicy,
    this.routeIn,
  });
}

/// A live agent — a deputy cell wrapped in a recording cognitive layer.
///
/// ### When to use
/// Read `trace` for the agent's decisions, `outcomes` for its
/// learning loop, and `dispose` when retiring it.
///
/// ### How it works
/// Owns the deputy view (`agentView`), the cognitive handle
/// (`agentHandle`), and the outcome subscription. Nothing crosses
/// agent boundaries unless the application moves it.
///
/// ### Non-obvious
/// - **`trace` is `agentHandle.decisions`.** The same tissue, two
///   names. No duplication.
/// - **`outcomes` is the agent's own outcome log.** Isolated from
///   other agents watching the same source.
///
/// ### See also
/// - [spawn], [debate], `guide/08-Agents.md`.
///
/// ## AI Agent Guide
/// - Agents observe one shared source through deputy views; debates
///   route via `AgentSpec.routeIn`, never the agent view.
/// - Stateless agents vote identically — a second round cannot
///   change the outcome.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class AgentRuntime<C extends Cell> {
  final String name;
  final C sourceCell;
  final Cell agentView;
  final CognitiveHandle agentHandle;
  final DeputyContext context;
  final TissueList<Decision> trace;
  final TissueList<Outcome> outcomes;

  final void Function() _stopOutcomes;
  final Future<void> Function(dynamic pulse)? _routeIn;
  bool _disposed = false;

  AgentRuntime._({
    required this.name,
    required this.sourceCell,
    required this.agentView,
    required this.agentHandle,
    required this.context,
    required this.trace,
    required this.outcomes,
    required void Function() stopOutcomes,
    Future<void> Function(dynamic pulse)? routeIn,
  })  : _stopOutcomes = stopOutcomes,
        _routeIn = routeIn;

  /// Stops the outcome subscription and disposes the handle.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopOutcomes();
    agentHandle.dispose();
  }

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;
}

/// Spawns an agent from a specification.
///
/// ### When to use
/// The primary agent construction path. Each spawned agent has its own
/// [CognitiveHandle], its own decision trace, and its own outcome log.
///
/// ### How it works
/// 1. Creates a deputy of `spec.cell` with `spec.mandate` and
///    `spec.testRule` (causal integrity enforced by the substrate).
/// 2. Wraps the deputy in [cognitive] with `spec.policy` (default
///    [learnedPolicy], gated by `allowedStrategies` when set) and
///    `spec.verdictPolicy`.
/// 3. Calls [recordOutcomes] to wire the agent's own outcome log.
/// 4. Returns the [AgentRuntime].
///
/// ### Non-obvious
/// - **`EffectJournal` is required** — deputy construction is
///   effectful.
/// - **The source cell is not modified.** All agent state lives on
///   the deputy view; multiple agents can watch the same source.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Future<AgentRuntime<C>> spawn<C extends Cell>(
  AgentSpec<C> spec, {
  required EffectJournal journal,
}) async {
  final viewOrFuture = spec.cell.deputy(
    context: spec.mandate,
    testRule: spec.testRule,
  );
  final agentView =
      viewOrFuture is Future<Cell> ? await viewOrFuture : viewOrFuture;

  var policy = spec.policy ?? learnedPolicy();
  if (spec.allowedStrategies.isNotEmpty) {
    policy = strategyPolicy(spec.allowedStrategies) + policy;
  }

  final handle = cognitive(
    cell: agentView,
    policy: policy,
    verdictPolicy: spec.verdictPolicy,
  );
  final recording = recordOutcomes(handle);
  return AgentRuntime<C>._(
    name: spec.name,
    sourceCell: spec.cell,
    agentView: agentView,
    agentHandle: handle,
    context: spec.mandate,
    trace: handle.decisions,
    outcomes: recording.log,
    stopOutcomes: recording.stop,
    routeIn: spec.routeIn,
  );
}

/// The outcome of a debate — the winning verdict plus per-round votes.
///
/// ### When to use
/// Inspect `winner` and `consensusReached` after [debate]; render
/// `votesByRound` for audit dashboards.
///
/// ### How it works
/// An immutable snapshot; votes are keyed `round-N` → agent name →
/// verdict. `agentStrategies` records the strategy each agent
/// voted under.
///
/// ### Non-obvious
/// - **`winner` fails closed.** `Reject('no-consensus')` or
///   `Reject('no-participants')` when nothing was decided.
/// - **`rounds` is 1 in practice** — stateless agents cannot
///   re-vote.
///
/// ### See also
/// - [spawn], [debate], `guide/08-Agents.md`.
///
/// ## AI Agent Guide
/// - Agents observe one shared source through deputy views; debates
///   route via `AgentSpec.routeIn`, never the agent view.
/// - Stateless agents vote identically — a second round cannot
///   change the outcome.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class DebateOutcome {
  final Verdict winner;
  final int rounds;
  final Map<String, Map<String, Verdict>> votesByRound;
  final bool consensusReached;
  final Map<String, String?> agentStrategies;

  const DebateOutcome({
    required this.winner,
    required this.rounds,
    required this.votesByRound,
    required this.consensusReached,
    required this.agentStrategies,
  });
}

/// Runs a single-round majority vote across the participants.
///
/// ### When to use
/// When multiple agents must agree on a decision. Each agent votes via
/// its own cognitive view; votes are aggregated.
///
/// ### How it works
/// 1. Routes the [question] once per shared source via each
///    participant's `AgentSpec.routeIn` (the live substrate's
///    deputies are not emittable, and a pulse completes at its
///    first terminal).
/// 2. Reads each agent's latest pulse decision as its vote.
/// 3. Aggregates:
///    - ≥ `consensusThreshold` accepts → `Accept()`, consensus.
///    - ≥ `consensusThreshold` rejects → `Reject('consensus-reject')`,
///      consensus.
///    - Otherwise, repeats up to `maxRounds` (stateless agents vote
///      identically, so practice resolves in round 1).
/// 4. On exhaustion → `Reject('no-consensus')`.
/// 5. Journals one `mind.debate` effect with the outcome.
///
/// ### Non-obvious
/// - **Empty participants → `Reject('no-participants')`**, fail closed.
/// - **Routing respects each agent's policy** — a rejected question is
///   that agent's vote.
///
/// ### See also
/// - [spawn], [debate], `guide/08-Agents.md`.
///
/// ## AI Agent Guide
/// - Agents observe one shared source through deputy views; debates
///   route via `AgentSpec.routeIn`, never the agent view.
/// - Stateless agents vote identically — a second round cannot
///   change the outcome.
///
/// {@category Organ}
/// {@category Agent}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Future<DebateOutcome> debate({
  required List<AgentRuntime> participants,
  required Pulse question,
  required EffectJournal journal,
  int maxRounds = 3,
  double consensusThreshold = 0.7,
}) async {
  if (participants.isEmpty) {
    return const DebateOutcome(
      winner: Reject('no-participants'),
      rounds: 0,
      votesByRound: {},
      consensusReached: false,
      agentStrategies: {},
    );
  }

  final votesByRound = <String, Map<String, Verdict>>{};
  final strategies = <String, String?>{};
  var consensusReached = false;
  Verdict winner = const Reject('no-consensus');
  var roundsUsed = 0;

  for (var round = 1; round <= maxRounds && !consensusReached; round++) {
    roundsUsed = round;
    final votes = <String, Verdict>{};
    // Snapshots before any routing: agents sharing a source all record
    // from a single ingestion.
    final beforeMap = {
      for (final agent in participants)
        agent: agent.trace.where((d) => d.pulse != null).length,
    };
    // Agents sharing a source receive the question from a single
    // ingestion; the live substrate completes a pulse at its first
    // terminal, so re-ingesting the same pulse is unsafe — in round 2+
    // (stateless agents), re-routing produces no new votes.
    final routedSources = LinkedHashSet<Cell>(
      equals: identical,
      hashCode: identityHashCode,
    );
    for (final agent in participants) {
      final before = beforeMap[agent]!;
      final routeIn = agent._routeIn;
      if (routeIn == null) {
        votes[agent.name] = const Reject('source-not-routable');
        strategies[agent.name] = null;
        continue;
      }
      if (!routedSources.contains(agent.sourceCell)) {
        routedSources.add(agent.sourceCell);
        await routeIn(question);
      }
      await Future<void>.delayed(Duration.zero);
      final pulseDecisions = agent.trace.where((d) => d.pulse != null).toList();
      if (pulseDecisions.length > before) {
        final vote = pulseDecisions.last;
        votes[agent.name] = vote.verdict;
        strategies[agent.name] = vote.pulse?.context.strategy?.name;
      } else {
        votes[agent.name] = const Reject('no-vote');
        strategies[agent.name] = null;
      }
    }
    votesByRound['round-$round'] = votes;

    final total = votes.length;
    final accepts = votes.values.whereType<Accept>().length;
    final rejects = votes.values.whereType<Reject>().length;
    if (total > 0 && accepts / total >= consensusThreshold) {
      winner = const Accept();
      consensusReached = true;
    } else if (total > 0 && rejects / total >= consensusThreshold) {
      winner = const Reject('consensus-reject');
      consensusReached = true;
    }
    // Stateless agents re-vote identically, and the live substrate
    // cannot re-ingest a completed pulse — a second round can never
    // change the outcome.
    if (!consensusReached) break;
  }

  final effect = MindDebateEffect(
    winner: winner.type,
    rounds: roundsUsed,
    votesByRound: votesByRound.map(
      (round, votes) => MapEntry(
        round,
        votes.map((agent, verdict) => MapEntry(agent, verdict.type)),
      ),
    ),
    consensusReached: consensusReached,
    at: journal.clock(),
  );
  await _recordBridgeEffect(journal, effect.toMap());

  return DebateOutcome(
    winner: winner,
    rounds: roundsUsed,
    votesByRound: votesByRound,
    consensusReached: consensusReached,
    agentStrategies: strategies,
  );
}
