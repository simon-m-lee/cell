# Agents — deputy-scoped cognitive runtimes

*Multi-agent orchestration on the same substrate: every agent is a
deputy cell with its own handle, trace, and learning loop.*

---

## §1 — What an agent is

An agent is three things composed:

```dart
final agent = await spawn(
  AgentSpec(
    name: 'Risk',
    cell: source.cell,               // the shared cell it observes
    mandate: DeputyContext(
      baseContext: sourceCellContext, // must relate to the source
      authority: 'agent-Risk',
      role: 'reviewer',
    ),
    routeIn: (p) => source.ingest(p as Pulse<int>),
  ),
  journal: RecordingJournal(),
);
```

1. **A deputy view** of a shared source cell, scoped by a
   `DeputyContext` mandate.
2. **A `CognitiveHandle`** — the recording layer (its own decisions).
3. **Its own outcome log** — `recordOutcomes` at spawn time.

---

## §2 — `AgentSpec` — the mandate

| Field | Default | Meaning |
|---|---|---|
| `name` | required | identity for votes/logs |
| `cell` | required | the shared source |
| `mandate` | required | `DeputyContext` (authority, role, isolation, …) |
| `testRule` | `TestCell.allowAll` | the deputy's own gate |
| `allowedStrategies` | empty (any) | strategy allow-list |
| `policy` | `learnedPolicy()` | the cognitive bool policy |
| `verdictPolicy` | null | the cognitive verdict slot |
| `routeIn` | null | debate question injection |

The live substrate's plain-cell deputies are not emittable cells, so
`routeIn` is the debate channel: pass the source ingress's `ingest`
(usually `(p) => gate.ingest(p as Pulse<T>)`).

---

## §3 — `spawn` — creating an agent

`spawn(spec, {required journal})`:

1. Creates the deputy (`spec.cell.deputy(context: spec.mandate,
   testRule: spec.testRule)`).
2. Wraps it in `cognitive(policy: spec.policy ?? learnedPolicy(),
   verdictPolicy: spec.verdictPolicy)` — with `allowedStrategies`
   composed as a `strategyPolicy` prefix.
3. Wires `recordOutcomes`.
4. Returns the `AgentRuntime`.

The source cell is never modified; any number of agents can watch it.

---

## §4 — `AgentRuntime` — the live agent

| Field | Meaning |
|---|---|
| `name` | identity |
| `sourceCell` | the shared source |
| `agentView` | the deputy cell |
| `agentHandle` | the cognitive handle |
| `context` | the mandate |
| `trace` | `agentHandle.decisions` (alias) |
| `outcomes` | the agent's own outcome log |

---

## §5 — Independent learning

Each agent's trace and outcome log are isolated. `trainOffline` on
one agent's handle trains only that agent; the portable result
applies via `trained.applyTo(...)` (usually the source cell's plain
`Context` — deputy contexts lack the `Ontology.constraints` pillar).

---

## §6 — `debate` — single-round voting

```dart
final outcome = await debate(
  participants: agents,
  question: questionPulse,
  journal: journal,
  consensusThreshold: 0.7,
);
```

- Each participant votes via its cognitive layer (its policy IS its
  vote).
- Aggregation: ≥ threshold accepts → `Accept()`; ≥ threshold rejects
  → `Reject('consensus-reject')`; otherwise `Reject('no-consensus')`.
- Empty participants → `Reject('no-participants')` (fail closed).
- The result is journaled as one `mind.debate` effect.

**Single round by construction:** agents are stateless between
rounds, and the live substrate completes a pulse at its first
terminal — a second round cannot change the outcome. `maxRounds`
exists for forward compatibility; Phase 6 always resolves in round 1.

**Shared sources:** agents watching one source receive the question
from a single ingestion; votes are snapshotted per round before any
routing.

---

## §7 — Disposal and lifecycle

`agent.dispose()` stops the outcome subscription and disposes the
handle. Idempotent; other agents on the same source are unaffected.
The deputy view remains on the graph (the substrate owns it) — the
agent's recording layer is what stops.

---

## §8 — Composition with `cell_organ` Blends

A Blend is a `Cell` with an `id` — `explainSource(blend, handle)`
works, and agents can observe blend outputs like any source.
`cell_mind` has no `cell_organ` dependency; the duck-typed `id`
matching covers it.

---

## §9 — Common patterns

### §9.1 — Multi-agent approval

Spawn reviewers per domain; `debate` the question; require consensus
before `ApprovalQueue.approve`.

### §9.2 — Consensus gates

Three agents, `consensusThreshold: 0.7` — two of three must agree.

### §9.3 — Isolation

Distinct mandates (`authority`, `clearance`, `isolation`) per agent;
the substrate's deputy machinery enforces what the mandate allows.

---

## §10 — What agents can and cannot do (v1)

| Can | Cannot (v1) |
|---|---|
| Observe a shared source | Inter-agent communication beyond voting |
| Record/learn independently | Multi-round argument exchange |
| Vote in single-round debates | Distributed multi-process agents |
| Defer via `verdictPolicy` + `ApprovalQueue` | Learning transfer between agents |

---

## §11 — Phase 6 substrate findings (recorded)

- **The plan's Phase 2 receptor fix is unnecessary here.** The live
  implementation uses `cell.deputy(testRule: recorder)`, which already
  records pulses through the cognitive view (`receptor_fix_test.dart`
  pins it). `Nucleus.evolve`/`Receptor.clone` are library-private —
  the plan's rc.9-era approach doesn't exist on the live substrate.
- **Plain-cell deputies are not `OpenCell`s** — no public `emit`;
  debate routes through `AgentSpec.routeIn`.
- **The plain-cell deputy path accepts unrelated mandates** (no
  causal-integrity throw observed) — documented leniency.
- **A pulse is completed at its first terminal** — debates ingest
  once per shared source and never re-route.
- **`Verdict.type` added** (`accept`/`reject`/`defer` discriminants)
  for narrative and span code.

---

## §12 — Reference

| Type | Kind |
|---|---|
| `AgentSpec<C>` | immutable spawn specification |
| `spawn(spec, {journal})` | create an agent |
| `AgentRuntime<C>` | live agent (trace, outcomes, dispose) |
| `DebateOutcome` | winner, rounds, votes, consensus |
| `debate({participants, question, journal, …})` | single-round vote |
| `MindDebateEffect` | journaled outcome |

---

## §13 — Summary

Agents reuse the framework's own isolation machinery: a deputy's
mandate scopes what the agent sees, a cognitive handle records what
it decides, and its own outcome log trains what it learns. The v1
surface is intentionally small — voting, not negotiation — with the
hooks (`maxRounds`, `attempts`, learned rules) ready for v1.1.

---

## §14 — AI Agent Guide notes

1. **Always pass `routeIn`** when debates are expected — the live
   deputy view has no public `emit`.
2. **Keep mandates honest.** The plain-cell deputy path on the live
   substrate accepts unrelated mandates; enforce lineage in
   application code if it matters.
3. **Train against the source context**, not the deputy context —
   `Ontology.constraints` lives on the plain `Context`.
4. **Dispose agents** — outcome subscriptions and handles leak
   otherwise.
5. **Emit debate questions once per shared source.** The substrate
   completes pulses at terminals; never re-ingest the same pulse.

---

## §15 — Decision procedures

### 15.1 — "Which agent rejected this?"

`explainPulse(pulse, agent.agentHandle)` per agent, or scan each
`agent.trace` — the verdict and annotations name the reason.

### 15.2 — "How do I add a fourth reviewer?"

Spawn another `AgentSpec` on the same source with a new mandate;
include it in the next `debate` call.

### 15.3 — "How do I make one agent stricter?"

`policy: myStrictPolicy()` or `allowedStrategies: {…}` on its spec;
or train it on negative outcomes.

---

## §16 — FAQ

**Q: Why can't debates re-route in round 2?**
Agents are stateless between rounds, and the substrate completes the
question pulse at its first terminal — a second round is identical.

**Q: Why is `trace` an alias?**
No duplication: `agentHandle.decisions` is the only log.

**Q: Can agents approve through `ApprovalQueue`?**
Compose `verdictPolicy` (Defer) + `approvalResolver` exactly like
single-handle flows.

**Q: Are agents process-isolated?**
No — in-process isolation via deputy mandates; distributed agents are
out of scope.

---

## §17 — Lifecycle table

| Stage | Action |
|---|---|
| Define | `AgentSpec(...)` |
| Create | `spawn(spec, {journal})` |
| Observe | `agent.trace`, `agent.outcomes` |
| Decide | source traffic + `debate` |
| Train | `trainOffline(handle: agent.agentHandle, …)` |
| Retire | `agent.dispose()` (idempotent) |

---

## §18 — Summary

Agents compose the existing layers — deputies for scope, handles for
record, queues for approval, trainers for learning — into a
self-contained unit. The v1 surface keeps the orchestration surface
deliberately small, so every property (isolation, audit, learning) is
the framework's own, verified property.

---

## §19 — Multi-agent approval, step by step

```dart
// 1. Shared source.
final source = Cell.ingress<int>(context: financeContext);

// 2. Three reviewers.
final reviewers = <AgentRuntime>[
  for (final name in ['Risk', 'Compliance', 'Legal'])
    await spawn(AgentSpec(
      name: name,
      cell: source.cell,
      mandate: DeputyContext(
        baseContext: financeContext,
        authority: 'agent-$name',
      ),
      routeIn: (p) => source.ingest(p as Pulse<int>),
    ), journal: journal),
];

// 3. Vote on a purchase.
final outcome = await debate(
  participants: reviewers,
  question: purchasePulse,
  journal: journal,
  consensusThreshold: 0.7,
);

// 4. Commit only on consensus.
if (outcome.consensusReached && outcome.winner is Accept) {
  await queue.approve(pendingId);
} else {
  await queue.reject(pendingId, (outcome.winner as Reject).reason);
}

// 5. Train each reviewer on its own outcomes.
for (final agent in reviewers) {
  final trained = await trainOffline(
    handle: agent.agentHandle,
    outcomes: agent.outcomes,
    baseContext: agent.sourceCell.context,
    trainer: contextualBandit(),
    journal: journal,
  );
  // Re-spawn with trained.applyTo(...) when the mandate changes.
  agent.dispose();
}
```

---

## §20 — Isolation guarantees, tested

- **Traces never cross.** `a.trace` and `b.trace` are separate
  `TissueList`s (`spawn_test.dart`).
- **Outcomes never cross.** Rewards recorded on one handle appear
  only in its own log (`independent_learning_test.dart`).
- **Training is portable.** `trainOffline` returns a `TrainedPolicy`;
  nothing mutates another agent's context.
- **Disposal is local.** Disposing one agent leaves its siblings
  recording (`dispose_test.dart`).

---

## §21 — Composition matrix

| Layer | Agent use |
|---|---|
| `Policy` (Phase 1) | the agent's rules (`spec.policy`) |
| `CognitiveHandle` (Phase 2) | `agentHandle` — decisions |
| `TrainedPolicy` (Phase 3) | per-agent learning |
| `ApprovalQueue` (Phase 4) | deferred agent decisions |
| `toolRouter` (Phase 5) | the agent's actuators |
| `DecisionPath` (Phase 6) | explaining agent decisions |

---

## §22 — Performance notes

`spawn` cost is dominated by deputy construction and the recording
subscription (~microseconds; see `benchmark/micro/spawn_cost.dart`).
Debate cost is one ingestion per shared source plus a journal effect.

---

## §23 — What Phase 7 inherits

- `AgentRuntime`/`debate` — the cookbook's multi-agent recipes.
- The `routeIn` contract — documented as the live-substrate routing
  channel for agent questions.
- `MindDebateEffect` — the stabilization audit surface for
  consensus outcomes.

---

## §24 — Summary of the agent contract

1. One source, many deputy views.
2. Each view: one mandate, one handle, one trace, one outcome log.
3. Votes are policies applied; consensus is counting; learning is
   per-agent.
4. Nothing an agent learns or decides crosses its boundary unless
   the application moves it.

That is the multi-agent surface `cell_mind` ships: small, composed
from verified parts, and auditable end to end.

---

## §25 — Troubleshooting

**`debate` returns `source-not-routable`** — the agent spec lacks
`routeIn`; pass `(p) => source.ingest(p as Pulse<T>)`.

**Votes all identical but expected disagreement** — the policies are
identical; give each spec a different policy or learned context.

**Training produced no rules** — fewer outcomes than `minSupport`, or
the rewards don't separate verdicts; lower thresholds or collect more
traffic.

**Mandate violations did not throw** — the live plain-cell deputy
path accepts unrelated mandates (documented leniency); enforce
lineage explicitly where required.

**One agent's dispose broke the source** — dispose only stops the
agent's own subscription; source cells are untouched.

---

## §26 — Closing note

Agents were the last module of the v1 surface: scoped cognition,
independent learning, and consensus voting on top of everything
Phase 0–5 built. Phase 7 freezes this API and writes the cookbook.
