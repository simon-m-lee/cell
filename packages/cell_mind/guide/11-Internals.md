# Internals — for maintainers

*What happens between the pulse and the decision — the classes, the
flows, and the invariants that keep `cell_mind` honest.*

---

## §1 — The decision path (one pulse, end to end)

```
ingress ──▶ host validate ──▶ _RecordingTestCell
                                  │ 1. principalRule (host's own rule)
                                  │ 2. policy (bool)
                                  │ 3. verdictPolicy (Accept/Reject/Defer)
                                  ▼
                            Decision → handle._record → decisions
```

`cognitive()` never modifies the source cell. It builds a
`_RecordingTestCell<C>` and hands it to `cell.deputy(testRule:)`.
Everything the deputy view validates is therefore recorded.

**Invariant:** the recorder delegates to `handle._record`, which owns
truncation (`maxDecisions`) and the disposed check. No other writer
touches `decisions`.

---

## §2 — `_RecordingTestCell` (lib/src/internal/recording_test_cell.dart)

Attribution logic, in evaluation order:

1. **`principalRule`** — the host cell's own `validate`, adaptively
   wrapped (plain cells expose `TestCell`; organ stems expose a
   `TestStem` with the same call contract — 0.6.1). Reject →
   `Reject('principal-rejected')`.
2. **`policy`** — the bool policy. Reject → `Reject('policy-rejected')`.
3. **No verdict policy** → `Accept()`.
4. **`verdictPolicy`**:
   - `Accept`/`Reject` → recorded as-is.
   - `Defer` → **wave-honest resolution** (§4).

Non-pulse objects (links, commands) are validated but never deferred
— a deferred link would break `Cell.observe` upstream
(`upstream link rejected`).

**Why it is a `TestCell` and not a `TestStem`:** it must sit in the
`cell` deputy chain; organ's deputy API accepts only `TestStem`, which
is why organ stems cannot host recorders in v1.0.

---

## §3 — `CognitiveHandle` (lib/src/runtime.dart)

| Field | Meaning |
|---|---|
| `cell` | the principal (unrecorded traffic) |
| `cognitive` | the deputy view (recorded traffic) |
| `policy` | the active bool policy (read-only) |
| `decisions` | `TissueList<Decision>` — the log |
| `outcomes` | `IngressHandle<Pulse>` — outcome injection |

`recordOutcome({decisionId, reward, metadata})` emits an `Outcome`
pulse and throws `StateError` when disposed. `maxDecisions` truncates
the log (oldest first) and is surfaced through
`Decision.truncated`.

---

## §4 — Wave-honest `Defer`

When the verdict policy returns `Defer(resolver)`:

1. The `Defer` decision is recorded.
2. The pulse is **dropped from the wave** (returns null to the
   receptor — human latency never blocks a wave).
3. If `onDeferred` is null → follow-up `Reject('defer-no-resolver')`.
4. Otherwise `onDeferred(decision, verdict)` runs **out-of-band**;
   `true` → `Accept({'deferredBy': resolver, 'decisionId': id})`;
   `false` → `Reject('defer-no-resolver')`; throw →
   `Reject('defer-resolver-failed')`.

The substrate validates async rules twice per pulse with **distinct
pulse objects**, so identity/lineage caches all miss — the recorder
must be idempotent per logical pulse (it is: one recording per
evaluation).

---

## §5 — `_ContextualBanditTrainer` (lib/src/internal/bandit.dart)

The bucketing and merge algorithm:

1. **Vectorize** each resolved decision from the pulse context:
   actor, reason, domains, strategy, confidence band — plus the
   host context's domains/version (`lib/src/internal/context_vector.dart`).
2. **Bucket** outcomes by `when`-key; accumulate reward sums and
   counts; thresholds: `minSupport`, `minConfidence`, `maxRules`.
3. **Merge additively by `when`-key** into the existing policy block
   read from the base context.
4. **Emit** a `TrainedPolicy` — a serializable block; `applyTo` writes
   it into `Ontology.constraints['cell_mind.policy']` in **one**
   evolve (replacing, not merging — F1 semantics).
5. Journal `mind.training` / `mind.pruning` io effects.

`learnedPolicy()` evaluates the block at decision time; when absent
it passes (never blocks a fresh context).

---

## §6 — `_bufferedChunks` (lib/src/internal/buffered_chunks.dart)

Stream buffering for `streamChunks`: tokens accumulate until
`bufferEvery`/`bufferSize` thresholds, then flush as one governed
pulse. Flush timestamps use the journal clock (ms) for replay
fidelity; replay does **not** re-read the upstream stream — chunks
are replayed from recorded effects.

---

## §7 — Journal effect schema (all seven typed effects)

All in `lib/src/internal/bridge_effects.dart` + `debate_effects.dart`:

| Effect | When |
|---|---|
| `MindCompletionEffect` | `completion` result |
| `MindStreamEffect` | `streamCompletion` result |
| `MindChunkEffect` | `streamChunks` buffer flush |
| `MindToolCallEffect` | `toolRouter` dispatch |
| `MindToolResultEffect` | tool result |
| `MindToolErrorEffect` | tool rejection (4 classes) |
| `MindDebateEffect` | debate outcome |

Serialization rules: `_isoAt` truncates to **milliseconds**; durations
are journal-clocked, never wall-clock; `_encodable` drops functions
and symbols. Replay fingerprints inputs exactly — maps must match
deeply.

---

## §8 — The decision log flow (record → observe → train)

```
record → handle.decisions (TissueList)
observe → recordOutcomes(handle) → outcomes.log (TissueList<Outcome>)
train   → trainOffline(handle, outcomes.log, baseContext, trainer, journal)
deploy  → trained.applyTo(plainContext) → new gate with learnedPolicy()
```

Training is **offline** and **portable**: `TrainedPolicy` is data; the
live handle is never mutated; replay gives byte-identical policy
blocks (recipe 13).

---

## §9 — `AgentRuntime` + `debate` (lib/src/agent.dart)

- `spawn` = `deputy(context: mandate, testRule: spec.testRule)` →
  `cognitive(policy: strategyPolicy + learnedPolicy)` →
  `recordOutcomes`.
- `debate` snapshots vote counts **before** any routing; agents
  sharing a source receive one ingestion (identity set); the
  question pulse is never re-ingested across rounds (completed at
  its first terminal); a no-consensus round breaks the loop.
- `routeIn` exists because live deputies are not `OpenCell`s — the
  source ingress is the only injection point.

---

## §10 — `DecisionPath` and `otelSpans` (lib/src/xai.dart)

- `DecisionPath` is a stateless projection; provenance accessors are
  null for action decisions.
- `explainPulse` matches by `traceId`, most-recent-first — the
  follow-up resolution decision wins over the original `Defer`.
- `otelSpans` sorts causally, parents via `parentTraceId`, status:
  Accept → ok, Reject/Defer → error; attributes are `mind.*`.

---

## §11 — The adaptive principal-rule (0.6.1 hotfix)

`cognitive()` previously cast `cell.validate as TestCell<C>`. Organ
stems expose a `TestStem` object with a compatible `call(Object?,
{Cell? host, dynamic arguments})`; the cast crashed. The fix wraps
the host's validate in a closure dispatched dynamically. The
remaining organ limitation is API-level: organ `deputy` accepts only
`TestStem` — documented in `KNOWN_ISSUES.md`, tested in
`test/integration/cross_library_test.dart`.

---

## §12 — Invariants (the maintainer checklist)

1. The recorder is the **only** writer of `decisions`.
2. Link decisions never `Defer`.
3. `recordOutcome` after `dispose` throws (`StateError`).
4. `TrainedPolicy.applyTo` never mutates its base argument.
5. Journal timestamps are ms-truncated; durations journal-clocked.
6. Tool calls are journaled `io` — replay never re-invokes them.
7. Debates ingest once per shared source, one round when stateless.
8. Narratives render recorded fields only.
9. Training base contexts are plain `Context`s (not deputy contexts).
10. The fitness suite (`test/fitness/`) is the substrate contract —
    never modified by `cell_mind` phases.

---

## §13 — File map

| File | Contents |
|---|---|
| `lib/src/policy.dart` | 18 policy factories + `Verdict` |
| `lib/src/runtime.dart` | `cognitive`, `CognitiveHandle`, `Decision` |
| `lib/src/learning.dart` | `Trainer`, `TrainedPolicy`, `trainOffline` |
| `lib/src/approval.dart` | `ApprovalQueue`, `approvalResolver` |
| `lib/src/bridge.dart` | `completion`, `stream*`, `toolRouter` |
| `lib/src/xai.dart` | `DecisionPath`, `explain*`, `otelSpans` |
| `lib/src/agent.dart` | `AgentSpec`, `spawn`, `debate` |
| `lib/src/outcomes.dart` | `Outcome`, `recordOutcomes` |
| `lib/src/internal/recording_test_cell.dart` | the recorder |
| `lib/src/internal/bandit.dart` | bandit trainer |
| `lib/src/internal/context_vector.dart` | decision vectorization |
| `lib/src/internal/bridge_effects.dart` | effect schema |
| `lib/src/internal/buffered_chunks.dart` | stream buffering |
| `lib/src/internal/narrative.dart` | narrative templates |
| `lib/src/internal/debate_effects.dart` | debate effect |
| `lib/src/internal/policy_helpers.dart` | verb/domain helpers |
| `lib/src/internal/decisions.dart` | `Decision` record |
| `lib/src/internal/verdicts.dart` | verdict classes |

---

## §14 — Summary for the next maintainer

The system is four moving parts composed deliberately: a **gate**
(policy), a **mirror** (recorder deputy), a **ledger** (decision +
outcome lists), and a **fold** (trainer). Everything else — approval,
bridges, agents, XAI — is those parts wired to a use case. When
debugging, find which of the four is lying; the invariants in §12
name the expected truth.

---

## §15 — Replay determinism, in detail

The rule that makes training byte-identical under replay:

1. **Clocks come from the journal.** Every timestamp the trainer
   consumes goes through `journal.clock()`, which truncates to
   milliseconds. Wall-clock jitter never reaches the policy block.
2. **Effects are fingerprints.** `journal.io(label, input, run,
   serializeOutput)` records the label + input digest + output
   digest. On replay the `run` closure **never executes**; the
   recorded raw output is returned.
3. **Tool calls are effects.** `toolRouter` journals
   `mind.tool.call.<verb>` — a replay of a session that called tools
   re-serves the results instead of re-calling the world.
4. **Maps must match deeply.** Replay fingerprints exact input maps;
   a changed key order is fine, a changed value is not (divergence
   throws).

`test/cookbook/13_deterministic_train.dart` pins the property:
two training runs — one recording, one replay — produce equal
`policyBlock`s.

---

## §16 — `toolRouter` drop semantics

- **`exhaust: true`** (default): arrivals during an in-flight tool
  call are **dropped** (latest-request-wins) — the router is
  designed for idempotent verb dispatch, not queues.
- Results and errors leave as fresh governed pulses:
  `mind.tool.result.<verb>` / `mind.tool.error.<verb>` with the
  four rejection classes (`bad_request`, `not_authorized`,
  `not_found`, `conflict`) carrying reasons.
- Router emissions carry the result **pulse as the payload** of the
  outer pulse — observers unwrap one level.

---

## §17 — Narrative rendering (lib/src/internal/narrative.dart)

Three templates, pure functions of `Decision`:

- `audit` — timestamped ids, verdict, actor/strategy/confidence,
  context version, evaluation time. The persisted format.
- `ui` — one sentence, no ids ("agent_a rejected the request: …").
- `debug` — structured `DecisionPath(...)` for tooling.

Missing provenance is elided; nothing is invented. Pinned by
`test/xai/narrative_test.dart`.

---

## §18 — Debug playbook

| Symptom | Look at |
|---|---|
| Decision missing | was the pulse routed through `handle.cognitive` (not `handle.cell`)? |
| Reject `principal-rejected` | the host's own `validate` — reduce the gate's `testRule` |
| Reject `policy-rejected` | which policy? bisect the `+` chain |
| Defer never resolves | `onDeferred` null or the resolver returns `false` |
| Outcomes empty at train | subscribe `recordOutcomes` **before** traffic |
| Trained rules absent | `minSupport` too high for the outcome count |
| Replay divergence | effect count/order changed; compare records |
| Debate no-vote | `AgentSpec.routeIn` missing |
| Organ crash in `cognitive` | organ stems can't host recorders — host the ingress |
| Narrative null provenance | action decision (no pulse) — expected |

---

## §19 — Performance notes

- Decision recording is a deputy validation + list append —
  `benchmark/micro/recording_cost.dart` measures it.
- Bandit training is O(decisions × features) per run;
  `benchmark/micro/training_cost.dart` reports tens of thousands of
  decisions/s.
- Approval round-trips are bounded by `TissueMap.apply` transactions;
  `benchmark/micro/approval_roundtrip.dart`.
- Bridge cost is dominated by the provided `Future`;
  `benchmark/micro/bridge_cost.dart`.
- `spawn_cost.dart` and `xai_cost.dart` bound agent construction and
  narrative rendering.

---

## §20 — Closing notes

Maintainers own three promises: **record everything the view sees**,
**fail closed on every gate**, and **keep training portable and
replayable**. The tests that pin those promises are the fitness
suite (substrate), the module suites (behavior), and the cookbook
(drift detection). When in doubt, extend a cookbook recipe — that is
where regressions surface first.
