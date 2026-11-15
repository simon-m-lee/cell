# Learning — the offline trainer

*The third layer of the cognitive loop: decisions become trainable, and
the trained result flows back into the Context.*

---

## §1 — What learning is

Learning in `cell_mind` is **offline, batch, and Context-shaped**:

- **Offline** — no online updates, no in-band gradient descent. The
  trainer runs as a job over a finished decision log.
- **Batch** — `trainOffline` consumes a snapshot of decisions and
  outcomes in one call.
- **Context-shaped** — the output is a `TrainedPolicy` whose
  `policyBlock` lives in `Ontology.constraints['cell_mind.policy']`. It
  is a typed, diffable governance record — not an opaque model.

The reference implementation is a **contextual bandit**: decisions are
bucketed by a context vector, per-action reward is aggregated per
bucket, and the higher-reward action becomes a learned `accept` or
`reject` rule.

```dart
final trained = await trainOffline(
  handle: handle,
  outcomes: outcomes.log,
  baseContext: handle.cell.context,
  trainer: contextualBandit(),
  journal: journal,
);
final evolved = trained.applyTo(handle.cell.context);
```

---

## §2 — The three stages

### §2.1 — Record (Decision + Outcome)

Phase 2 records every decision in `handle.decisions`. Phase 3 adds the
typed outcome log:

```dart
final outcomes = recordOutcomes(handle);
// ... traffic happens ...
handle.recordOutcome(decisionId: decision.id, reward: 1.0);
// ... later ...
outcomes.stop();
```

The join key is `decisionId` — exactly the id stamped on each
`Decision`.

### §2.2 — Train (Trainer + TrainedPolicy)

`trainOffline` snapshots `handle.decisions` and the outcome log, joins
them, computes rewards, buckets by context vector, and emits rules
under `minSupport` / `minConfidence` thresholds.

### §2.3 — Deploy (applyTo + learnedPolicy)

```dart
final evolved = trained.applyTo(context);
final gate = Cell.ingress<int>(
  context: evolved,
  testRule: contextAware() + learnedPolicy(),
);
```

Rebuilding with the evolved context is the preferred deployment.
`learnedPolicy()` reads the block at decision time and applies matching
rules.

---

## §3 — `recordOutcomes()` and the outcomes log

```dart
final recording = recordOutcomes(handle);
// recording.log : TissueList<Outcome> — observable, serializable
// recording.stop() : ends accumulation; the log remains readable
```

Channel contract (from Phase 2): each entry's payload is the outcome
`Pulse` (`type: 'mind.outcome'`), whose payload is the reward map.
`recordOutcomes` unwraps once and parses defensively — malformed
payloads are ignored, `Outcome.at` is the emission timestamp.

`Outcome` serializes with `toMap` / `fromMap`:

```dart
final class Outcome {
  final String decisionId;
  final double reward;
  final Map<String, dynamic>? metadata;
  final DateTime at;
}
```

---

## §4 — The bandit reduction

### §4.1 — Context vector

```dart
final class ContextVector {
  final String key;              // 'domains=finance|actor=agent-a|...'
  final Map<String, String> when; // rule 'when' block
}
```

Dimensions: `domains`, `compliance`, `authority`, `actor`, `strategy`,
`purpose` — read from the decision's context and pulse provenance.
Values are normalized: lowercase, sorted, comma-joined. Empty
dimensions are omitted. The canonical `key` gives O(1) bucketing with
stable ordering.

**The same vector builder runs at training time and at matching time**,
so a learned `{domains: 'marketing'}` rule matches a runtime pulse from
marketing — same normalization, same semantics.

### §4.2 — Bucketing

Samples are grouped by `vector.key`. Each bucket aggregates:

| Field | Meaning |
|---|---|
| `acceptCount` / `rejectCount` | samples per verdict |
| `acceptRewardSum` / `rejectRewardSum` | reward totals per verdict |
| `support` | `acceptCount + rejectCount` |
| `avgAccept` / `avgReject` | mean reward per verdict (0 when absent) |
| `confidence` | `|avgAccept − avgReject|`, clamped to [0, 1] |
| `preferredAction` | the verdict with the higher mean reward |

### §4.3 — Confidence and support

- **`minSupport`** (default 5): buckets with fewer observations are
  held out — no rules from a single unlucky decision.
- **`minConfidence`** (default 0.6): buckets whose verdicts are not
  clearly distinguished by reward are held out. Equal average rewards
  → confidence 0 → no rule.
- **`maxRules`** (default 100): the most confident rules survive.

### §4.4 — The emission loop

```
join(decisions, outcomes, window)
  → compute reward per sample
  → bucket by context vector
  → emit rule per bucket meeting thresholds
  → sort by confidence descending
  → cap at maxRules
  → merge with the existing block
  → journal the run
```

---

## §5 — `TrainedPolicy` and the policy block

```dart
final class TrainedPolicy {
  final Map<String, dynamic> policyBlock;
  final int decisionCount;
  final int resolvedCount;
  final DateTime trainedAt;   // journal time — replayable
  final String algorithm;
  final double averageReward;

  Context applyTo(Context base);
  Map<String, dynamic> toMap();
  static TrainedPolicy fromMap(Map<String, dynamic> map);
  int get ruleCount;
}
```

The block shape:

```json
{
  "version": 3,
  "algorithm": "contextualBandit",
  "rules": [
    {
      "when": {"actor": "agent-a", "domains": "marketing"},
      "action": "reject",
      "confidence": 1.0,
      "support": 12,
      "trainedIn": 3
    }
  ]
}
```

- `version` — monotonically increasing per run (replay dispatch).
- `trainedIn` — the run that emitted the rule (pruning by age).
- `when` — the context vector, parsed.
- Rules sorted by `confidence` descending.

`TrainedPolicy` is **not a Context** — it is a portable record.
`applyTo` merges the block into `base.constraints` and evolves once.
The same policy can apply to different bases.

**F1 is honored here:** the merge happens in the trainer (before any
evolve); `applyTo` is a straight write of the fully-merged block.

---

## §6 — Merge semantics (additive vs. pruning)

| `TrainingConfig.prune` | Behavior |
|---|---|
| `false` (default) | additive: new rules replace same-`when`-key rules; other existing rules are preserved with their original `trainedIn` |
| `true` | full replacement: only this run's rules survive |

The default protects against regression from a single unlucky run;
pruning gives fast-drifting policies a clean slate. Removed rules are
journaled (`mind.pruning` effect) for audit.

---

## §7 — Determinism and replay

Every run is journaled:

- `trainedAt` = `journal.clock()` — never `DateTime.now()`.
- `window` filtering measures against the same journal time.
- The run and any pruning are recorded as `io` effects
  (`mind.training`, `mind.pruning`) in a fixed order, so a
  `ReplayJournal` consumes the same sequence.

`determinism_test.dart` pins the contract: recording → replay produces
a byte-identical `TrainedPolicy.toMap()`. Note the replay side restores
clock epochs in local time; compare instants via `.toUtc()`.

---

## §8 — Composing `contextAware() + learnedPolicy()`

`contextAware()` is frozen at 0.1.0 and does **not** consult the
learned block. Compose explicitly:

```dart
final policy = contextAware() + learnedPolicy();
```

Evaluation order matters: structural gates run first (fail-closed on
missing metadata); the learned opinion runs last (pass-through when no
rule matches). A learned reject can only narrow a structural accept —
never widen it.

---

## §9 — Deploying the trained policy

**Rebuild (preferred):**

```dart
final evolved = trained.applyTo(context);
final gate = Cell.ingress<int>(
  context: evolved,
  testRule: contextAware() + learnedPolicy(),
);
```

**Deputy narrow:** `cell.deputy(context: evolvedContext)` — `Ontology.constraints`
accumulates because it is evolvable, so learned rules survive; the
deputy semantics still only narrow.

**Versioning:** bump the context version each training cycle so the
decision log distinguishes generations (`guide/04-Determinism.md`).

---

## §10 — Common patterns

### §10.1 — Fraud detection

Record every accepted transaction decision; reward +1 when it settles,
−1 when it chargebacks. After a training window, the bandit emits
`reject` rules for the failing context vectors (domain × actor ×
strategy). Redeploy; the rejects stop before state.

### §10.2 — LLM confidence gating

Record completions as decisions (Phase 5 bridges emit into the same
channel); reward by downstream acceptance. Learned rules per prompt
category (vector = `strategy: probabilistic` × `purpose`) reject the
categories that consistently fail.

### §10.3 — Attribute learning (preview)

Multi-agent learning (Phase 6) is the same loop with per-agent
handles: each agent's `decisions` + `outcomes` train independently;
contexts compose via `DeputyContext` chains.

---

## §11 — What learning can't do

- **Online updates.** The trainer never mutates a live policy.
- **Deep RL / Q-learning / PPO.** The reference implementation is the
  bandit; custom `Trainer`s can be anything — including a Python-backed
  bridge — but they are user code.
- **Command vectorization (0.3.0).** `learnedPolicy()` passes commands
  and links through; Phase 4 vectorizes commands.
- **Magic deployment.** Training never mutates the handle, the cell, or
  its context. Deployment is explicit (`applyTo`).
- **Unbounded context growth.** `maxRules` caps each run; `prune: true`
  resets; `trainedIn` enables age-based pruning later.

---

## §12 — AI Agent Guide notes

1. **Compose explicitly.** Generated runtimes that learn must use
   `contextAware() + learnedPolicy()` — never assume auto-composition.
2. **Reward every accepted decision** with
   `handle.recordOutcome(decisionId: decision.id, reward: ...)`; the
   join silently skips unrewarded decisions.
3. **Pass a journal.** `trainOffline` requires one; there is no
   default. Use `RecordingJournal()` for production recording.
4. **Stamp contexts.** The learned block bumps its own `version`, but
   the context `version` must be bumped manually per cycle or replay
   generation tracking breaks.
5. **Expect `actor` in `when` blocks.** The context vector includes
   pulse provenance; learned rules are actor-specific by default. To
   generalize across actors, set a stable actor value for a class of
   producers.
6. **Verify thresholds.** `minSupport`/`minConfidence` gate rule
   emission — a small synthetic log may produce zero rules by design.

---

## §13 — Reference table

| Type | Kind | Key members |
|---|---|---|
| `Outcome` | record | `decisionId`, `reward`, `metadata`, `at`, `toMap`/`fromMap` |
| `recordOutcomes(handle)` | function | returns `({TissueList<Outcome> log, void Function() stop})` |
| `RewardFunction` | typedef | `double Function(Decision, Outcome)` |
| `TrainingConfig` | immutable config | `minSupport`, `minConfidence`, `maxRules`, `window`, `prune` |
| `Trainer` | protocol | `Future<TrainedPolicy> train({...})` |
| `contextualBandit()` | factory | the reference trainer |
| `trainOffline({...})` | function | handle + outcomes + baseContext + trainer + journal |
| `TrainedPolicy` | record | `policyBlock`, counts, `trainedAt`, `applyTo`, `toMap`/`fromMap` |
| `learnedPolicy()` | factory | `Policy` reading `cell_mind.policy` |
| `ContextVector` | internal | canonical key + `when` map, subset matching |

---

## §14 — Test inventory

| File | Tests | Pins |
|---|---|---|
| `outcome_test.dart` | 5 | record construction + round-trips |
| `record_outcomes_test.dart` | 5 | accumulation, malformed, stop, multi-outcome |
| `trained_policy_test.dart` | 5 | serialization + `applyTo` portability |
| `bandit_test.dart` | 12 | bucketing, thresholds, cap, window, sorting |
| `accumulation_test.dart` | 4 | additive merge, version bumps |
| `pruning_test.dart` | 3 | full replacement + journaled removals |
| `determinism_test.dart` | 4 | recording → replay identity |
| `learned_policy_test.dart` | 8 | subset/first-match/pass-through/composition |
| `integration_test.dart` | 2 | the full record → train → deploy loop |

Total: 48 learning tests; the full suite stands at 232.

---

## §15 — Worked walkthrough

One marketing decision, end to end:

1. `gate.ingest(pulse)` — static gate accepts (domain is declared);
   the cognitive view records `Decision(id: d-7, Accept)`.
2. Downstream fails → `handle.recordOutcome(decisionId: 'd-7',
   reward: -1.0)` → the outcome log appends `Outcome('d-7', -1)`.
3. `trainOffline` joins the pair, vectorizes
   `{actor: sim, domains: marketing}`, buckets 12 such samples,
   computes `avgAccept = -1`, confidence 1.0 → emits
   `reject` (support 12, trainedIn 1).
4. `trained.applyTo(context)` writes the block into constraints.
5. The redeployed gate's `learnedPolicy()` matches the next marketing
   pulse against `{actor: sim, domains: marketing}` — subset of the
   pulse's vector — and rejects it. The decision log records the
   rejection; the loop has closed.

---

## §16 — Phase 3 findings (recorded)

- **`journal.now()` does not exist.** `trainedAt` uses
  `journal.clock()`; run/pruning effects are `journal.io(...)` records
  (`mind.training` / `mind.pruning`) — the live `EffectJournal` has no
  generic `record` primitive.
- **The outcome channel double-wraps** (Phase 2 contract), so
  `recordOutcomes` unwraps once before parsing.
- **The context vector includes pulse provenance** — learned rules are
  actor-specific by default (`when` contains `actor`). Tests pin the
  exact shape.
- **Replay restores clock epochs in local time** — determinism tests
  compare instants via `.toUtc()`.
- **`applyTo` evolves once with the merged block** — F1's
  replace-not-merge semantics are honored by merging in the trainer.

---

## §17 — Threshold tuning guide

Three knobs control what the bandit emits; tune them together.

### minSupport

How many observations before a bucket is trustworthy. Low (2–5) for
fast-moving domains with clean reward signals; high (50+) for noisy
rewards where a few lucky outcomes must not become rules.

```dart
const TrainingConfig(minSupport: 20)
```

### minConfidence

How clearly reward must separate the verdicts. 0.6 is a good default;
0.9 means "only near-unanimous signals become rules".

```dart
const TrainingConfig(minConfidence: 0.9)
```

### maxRules

The per-run rule budget. Combined with confidence-descending sorting,
this keeps the most useful rules when contexts explode.

### The interplay

| Goal | Config |
|---|---|
| Conservative, slow learning | `minSupport: 20, minConfidence: 0.8` |
| Aggressive, fast adaptation | `minSupport: 3, minConfidence: 0.4` |
| Bounded surface | `maxRules: 10` |
| Clean slate each run | `prune: true` |

### Window

`window` restricts training to recent decisions (measured in journal
time). Combine with `prune: true` for a strictly rolling policy.

---

## §18 — Reward shaping recipes

### Binary success

```dart
handle.recordOutcome(
  decisionId: decision.id,
  reward: success ? 1.0 : -1.0,
);
```

### Cost-weighted

```dart
final cost = metadata['costMs'] as int;
handle.recordOutcome(
  decisionId: decision.id,
  reward: success ? 1.0 : -(cost / 1000),
);
```

### Custom attribution at training time

```dart
RewardFunction weighted = (decision, outcome) {
  final latency = outcome.metadata?['latencyMs'] as int? ?? 0;
  return outcome.reward - latency / 10000;
};
```

---

## §19 — Deployment checklist

- [ ] The training gate was **permissive enough to observe failures**
      (a policy that rejects everything learns nothing).
- [ ] Every accepted decision received an outcome (the join silently
      skips unresolved ids).
- [ ] A journal was passed — no default exists.
- [ ] `applyTo` result is deployed via rebuild (preferred) or deputy.
- [ ] The context version was bumped for generation tracking.
- [ ] `learnedPolicy()` is composed explicitly.
- [ ] Thresholds were chosen with the log size in mind — a 10-decision
      log with default `minSupport: 5` may legitimately emit nothing.

---

## §20 — FAQ

**Q: Why did training emit zero rules?**
Support below `minSupport`, confidence below `minConfidence`, or no
resolved decisions (missing outcomes).

**Q: Why do rules contain `actor`?**
The context vector includes pulse provenance. Use a stable actor per
producer class to generalize; a per-request actor makes rules
per-request.

**Q: Does training mutate the live handle?**
No. The result is a record; deployment is explicit via `applyTo`.

**Q: Can I chain training runs?**
Yes — additive mode updates same-`when` rules and preserves the rest,
bumping `version` each run.

**Q: What happens to duplicate outcome ids?**
The first outcome for a decision id wins (documented).

**Q: Is the trainer pure?**
No — `Purity.effectful` by contract: it records effects. It requires a
journal; with the same inputs and journal time it is deterministic.

---

## §21 — What Phase 4 inherits

- `TrainedPolicy` and the `cell_mind.policy` block — approval decides
  *who* may deploy a trained policy (HITL as a `Defer` resolver).
- `Defer` rules in `learnedPolicy()` — Phase 4 adds the third action;
  0.3.0 treats `defer` as pass-through (forward-compatible).
- Command vectorization — Phase 4 extends `ContextVector` to
  `ApplyCommand` shapes so learned rules govern verbs too.
- The journaled training-run format (`mind.training` /
  `mind.pruning`) — replay machinery for approval decisions builds on
  it.

---

## §22 — The cognitive loop, complete

```
pulse ──► static gate (contextAware + learnedPolicy) ──► accept/reject
                              │
                              ▼
                    CognitiveHandle.decisions
                              │
                    downstream outcomes (reward per decision)
                              │
                              ▼
                    recordOutcomes → TissueList<Outcome>
                              │
                              ▼
              trainOffline (contextualBandit, journaled)
                              │
                              ▼
                    TrainedPolicy.policyBlock
                              │
                              ▼
                  applyTo → evolved Context vN+1
                              │
                              ▼
              redeployed gate — the loop closes
```

Each circuit through the loop narrows the policy with evidence, and
each narrowing is a typed, diffable `Context` change — the framework's
governance model, now self-improving.

---

## §23 — AI Agent review checklist for generated training code

- [ ] Outcomes are recorded for every accepted decision in the window.
- [ ] `trainOffline` receives `handle.decisions` snapshots and the
      `recordOutcomes` log — not hand-built lists that drift from the
      live shapes.
- [ ] The journal is a real `RecordingJournal` (or replay), never
      `NullJournal`.
- [ ] Thresholds match the log size; empty-rule outcomes are
      understood.
- [ ] The redeployed gate composes `learnedPolicy()` explicitly.
- [ ] The context version is bumped per cycle.
- [ ] `outcomes.stop()` and `handle.dispose()` appear in teardown.
- [ ] No generated code writes into `handle.decisions` or the policy
      block directly — only the trainer and `applyTo` may.

---

## §24 — Summary

Learning in `cell_mind` is the smallest loop that still closes:

1. Phase 1 made `Context` executable (`Policy`).
2. Phase 2 made decisions visible (`CognitiveHandle`, `Decision`).
3. Phase 3 makes decisions **trainable** — and puts the result back
   into the `Context` so the next runtime uses it.

The keystone remains the same as the design's: the learned artifact is
a **Context**, not a model. `TrainedPolicy` is the portable envelope;
`Ontology.constraints['cell_mind.policy']` is the durable home; the
contextual bandit is the reference learner. Everything else composes on
top.
