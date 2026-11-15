# ARCHITECTURE — `cell_mind`

*Design and implementation architecture of the `cell_mind` package,
phases 0–9, as shipped in `1.1.0`.*

---

## 1. Purpose and scope

`cell_mind` is the **cognitive governance layer** of the Mitosis
ecosystem. It turns the reactive substrate (`cell`), the value
store (`cell_tissue`), and the composition layer (`cell_organ`)
into a governed, auditable, learnable, and AI-queryable decision
system.

One sentence: **every pulse and command that enters a governed cell
passes structural policy, optionally an AI or learned verdict, and a
human when necessary — with every decision recorded, replayable, and
explainable.**

The package deliberately does **not** own transport: no HTTP client,
no LLM SDK, no telemetry exporter. Every external touchpoint is a
user-supplied closure behind a journaled interface.

| Version | Phases | Surface |
|---|---|---|
| `0.1.0`–`0.6.1` | 1–6 iterative | policy, runtime, learning, approval, bridge, xai, agent |
| `1.0.0` | 7 (stabilization) | API freeze, `FROZEN_API.md`, docs, acceptance example |
| `1.1.0` | 8, 8.1, 9 (prompt) | prompted policy, verdict caching, chat sessions |

---

## 2. The phase map

| Phase | Module | What it shipped | Verified by |
|---|---|---|---|
| 0 | foundations | fitness suite pinning the `cell` substrate contract | `test/fitness/` |
| 1 | `policy` | 15 stateless `TestCell` factories, composition, fail-closed | `test/policy/` |
| 2 | `runtime` | `cognitive()`, `CognitiveHandle`, `Decision` log, attribution | `test/runtime/` |
| 3 | `learning` | offline bandit trainer, `TrainedPolicy`, outcomes join | `test/learning/` |
| 4 | `approval` | `Defer` resolver contract, `ApprovalQueue`, TTL, audit pair | `test/approval/` |
| 5 | `bridge` | `completion`, streaming, `toolRouter`, typed effects | `test/bridge/` |
| 6 | `xai` + `agent` | `DecisionPath`, narratives, OTel spans; `spawn`/`debate` | `test/xai/`, `test/agent/` |
| 7 | stabilization | freeze, docs, cookbook, cross-library verification | `test/fitness/`, CI |
| 8 | `prompt` | `promptedPolicy`, `PromptConfig`, presets, registry, `conform` | `test/prompt/` |
| 8.1 | prompt supplement | verdict cache, sessions, six journal effects, guide 12 | `test/prompt/` |
| 9 | prompt revised | three-tier cache alignment, entry provenance, public fingerprints, clock-precision fix | `test/prompt/`, `test/bridge/` |

Each phase was strictly additive after Phase 7's freeze: the only
signature change in `1.1.0` is the source-compatible widening of
`VerdictPolicy.call` to `FutureOr<Verdict>`.

---

## 3. Architectural overview

```
                        ┌────────────────────────────────────────────┐
                        │                cell substrate              │
                        │  pulses, commands, links, deputies, waves   │
                        └───────────────┬────────────────────────────┘
                                        │
                 ┌──────────────────────▼──────────────────────┐
                 │  1. Principal rule (the cell's own gate)    │  reject → no record
                 └──────────────────────┬──────────────────────┘
                                        │ pass
                 ┌──────────────────────▼──────────────────────┐
                 │  2. Structural policy (Policy = TestCell)   │  reject → Decision(policy-rejected)
                 │     domain/compliance/confidence/… chains   │
                 └──────────────────────┬──────────────────────┘
                                        │ pass
                 ┌──────────────────────▼──────────────────────┐
                 │  3. Verdict policy (VerdictPolicy)          │
                 │     learnedVerdictPolicy | promptedPolicy   │
                 │     ┌─────────────────────────────────────┐ │
                 │     │ prompted pipeline (Phase 8/9):      │ │
                 │     │  fingerprints → verdict cache →     │ │
                 │     │  render → prompt cache → LLM →      │ │
                 │     │  session append → store (D14)       │ │
                 │     └─────────────────────────────────────┘ │
                 └──────┬──────────────┬──────────────┬────────┘
                        │ Accept       │ Reject       │ Defer
                        ▼              ▼              ▼
                 ┌───────────┐  ┌───────────┐  ┌─────────────────┐
                 │ Decision  │  │ Decision  │  │ onDeferred →    │
                 │ recorded  │  │ recorded  │  │ ApprovalQueue   │
                 └─────┬─────┘  └─────┬─────┘  │ → follow-up     │
                       ▼              ▼        │   Decision      │
              ┌────────────────────────────────┴─────────────────┐
              │  Decision log ──▶ XAI narratives ──▶ OTel spans   │
              │  Outcomes ──────▶ trainOffline ──▶ Context vN+1  │
              │  Journal (io/clock effects) ──▶ ReplayJournal    │
              └──────────────────────────────────────────────────┘
```

Three design commitments hold the diagram together:

1. **Purity hierarchy.** Policies are pure; effectful primitives
   (trainer, bridges, prompted policies) require an `EffectJournal`.
2. **Narrowing only.** Each later layer can only reject what an
   earlier layer accepted — a verdict can never widen a structural
   reject, and a cached verdict cannot bypass a structural gate.
3. **Journal as source of truth.** Everything that touches the
   outside world records an effect; replay re-serves those effects
   instead of touching the world again.

---

## 4. The decision pipeline in detail

### 4.1 — Layer 1: principal rule

The host cell's own `validate` runs inside the substrate. A
principal rejection records `Reject('principal-rejected')` and never
reaches policy. `cell_mind` treats the principal as infrastructure:
it can only be *narrowed*, never bypassed.

### 4.2 — Layer 2: structural policy

`Policy = TestCell<Cell>` — the same type the substrate itself
uses, so policies compose into `testRule` (static mode) or wrap a
cell via `cognitive()` (dynamic mode). Composition is the `+`
operator: left-to-right, short-circuit, fail-closed. Every factory
declares which object shapes it governs (pulse / command / link) and
passes the others — this is what makes `domainPolicy() +
authorityPolicy()` govern both pulses and commands without leaking.

### 4.3 — Layer 3: verdict policy

`VerdictPolicy` produces the sealed `Verdict` hierarchy
(`Accept` / `Reject` / `Defer`). `VerdictPolicy.+` short-circuits on
Accept/Reject and lets `Defer` fall through to the next rule.
Since `1.1.0`, `call` returns `FutureOr<Verdict>` — the prompted
policy awaits the LLM (or a cache hit) inside the wave; the
recording runtime awaits the future.

### 4.4 — Layer 4: deferral

`Defer` drops the pulse from the wave (wave-honest, fail-closed) and
invokes `onDeferred` out-of-band. The resolver's result is a second
`Decision` linked by `decisionId` — the audit trail shows the request
and the resolution as separate facts.

### 4.5 — Recording

`cognitive()` wraps the cell in a recorder deputy
(`_RecordingTestCell`). Every accepted/rejected/deferred pulse and
command becomes a `Decision`:

```
Decision { id, at, context, contextVersion, pulse|command,
           verdict, policyVersion, evaluationTime }
```

Attribution reasons are stable strings: `'principal-rejected'`,
`'policy-rejected'`, `'composite-rejected'`.

---

## 5. Policy layer (Phase 1)

**Files:** `lib/src/policy.dart`, `lib/src/internal/policy_helpers.dart`,
`lib/src/internal/decisions.dart`, `lib/src/internal/verdicts.dart`.

- **Factories** (15): `domainPolicy`, `requiresDomainPolicy`,
  `compliancePolicy`, `complianceOverlapPolicy`, `authorityPolicy`,
  `exactFunctionsPolicy`, `clearancePolicy`, `isolationPolicy`,
  `sensitivityPolicy`, `confidencePolicy`, `strategyPolicy`,
  `auditLevelPolicy`, `actorPolicy`, `purposePolicy`,
  `notOlderThan`, `predicatePolicy`, plus the composites
  `contextAware` and `paranoid`.
- **Dispatch model:** each factory governs a subset of
  `{Pulse, Function, Cell}` and passes the others; throwing rules
  fail closed, `StateError`s propagate loudly (caller bugs).
- **Fail-closed vocabulary:** `missing-metadata`, `below-minimum`,
  `not-in-allowlist`, `too-old`, `unresolvable-verb`, and their
  per-factory specializations.
- **Purity:** all factories are pure functions of provenance +
  host context; `notOlderThan` alone takes an injected clock
  (`readOnlyExternal`).

**Invariants:** a composite rejection cannot be attributed to a
policy that never ran (short-circuit); `contextAware()` never
consults learned state; `Policy` and `VerdictPolicy` are distinct
types and never compose with each other.

---

## 6. Runtime layer (Phase 2)

**Files:** `lib/src/runtime.dart`,
`lib/src/internal/recording_test_cell.dart`.

- `cognitive<C extends Cell>({cell, policy, verdictPolicy,
  onDeferred, maxDecisions})` returns a `CognitiveHandle<C>` with
  `cell` (untouched principal), `cognitive` (recording view),
  `decisions` (bounded `TissueList`), `outcomes` (reward channel),
  `recordOutcome`, `dispose`.
- **Static vs dynamic:** static = policy composed into `testRule`
  (one validation); dynamic = `cognitive()` deputy wrap (recording +
  double validation, benchmarked).
- **Serialization:** `Decision.toMap`/`fromMap` round-trips; the
  shell restores, live objects do not (documented lossiness).
- **Truncation:** beyond `maxDecisions`, recording stops and a
  truncated decision is appended (auditable bound).
- **Outcomes:** `recordOutcome(decisionId, reward, metadata)` emits
  into the outcomes ingress — the join key for Phase 3 training.

**Async verdict policies (1.1.0):** the recorder awaits
`FutureOr<Verdict>`; the prompt pipeline (below) is the only shipped
async verdict policy.

---

## 7. Learning layer (Phase 3)

**Files:** `lib/src/learning.dart`, `lib/src/internal/bandit.dart`,
`lib/src/internal/context_vector.dart`, `lib/src/outcomes.dart`.

```
decisions ──┐
            ├─▶ trainOffline(baseContext, trainer: contextualBandit())
outcomes ───┘        │
                     ▼
              TrainedPolicy { policyBlock, applyTo(Context) }
                     │
                     ▼
              evolved Context ──▶ gate with contextAware() + learnedPolicy()
```

- **Record** — decisions + outcomes joined by id.
- **Train** — the bandit vectorizes each decision (domain × actor ×
  strategy × …), buckets it, and emits accept/reject rules with
  confidence + support; `minSupport`, `minConfidence`, `maxRules`,
  `prune`, `window` bound the block.
- **Deploy** — `applyTo` returns an evolved plain `Context`
  (learned rules live at `Ontology.constraints['cell_mind.policy']`);
  `learnedPolicy()` reads them. Training never mutates live state.
- **Determinism** — a training run is a journaled effect; replay
  re-reads the log from the journal and reproduces the identical
  block (`test/cookbook/13_deterministic_train.dart`).

**Composition since 1.1.0:** `contextAware() + learnedPolicy()` in
the `policy:` slot, prompted policy in the `verdictPolicy:` slot —
structural → learned → LLM, narrowing at every step. Outcomes can be
recorded for prompted decisions; the trainer learns which prompted
verdicts worked.

---

## 8. Approval layer (Phase 4)

**File:** `lib/src/approval.dart`.

- **Contract:** `Future<bool> Function(Decision, Verdict)?`
  as `onDeferred`; `approvalResolver(queue)` is the reference
  resolver.
- **Wave honesty:** the deferred pulse is dropped from the wave;
  resolution is out-of-band; delivery is the resolver's job via
  `ApprovalQueue.committed`. The substrate evaluates async rules
  twice per pulse with distinct objects, so waiting inside a wave is
  impossible — Phase 4's shape follows that constraint.
- **`ApprovalQueue`:** `submit` (recorded), `pending`,
  `approve`/`reject` (recorded), `committed` stream, TTL sweeper
  (recorded expiry), `dispose` (recorded). Atomicity rides on
  `Cell.txApply` staging; the decision pair is the audit unit.
- **Journal labels:** `mind.approval.submitted`, `.decided`,
  `.expired`, `.disposed`.
- **Prompted Defer:** an LLM-issued (or cached) `Defer` routes
  through the same resolver — no special case.

---

## 9. Bridge layer (Phase 5)

**Files:** `lib/src/bridge.dart`, `lib/src/internal/bridge_effects.dart`,
`lib/src/internal/buffered_chunks.dart`.

- **Sensors/actuators as cells:** `completion` (one future),
  `streamCompletion` (chunked), `streamChunks` (buffering),
  `toolRouter` (closed-verb function dispatch with four rejection
  classes and `exhaust`/`fireAndForget` semantics).
- **Typed effects:** `mind.completion`, `mind.completion.error`,
  `mind.stream.chunk`, `mind.tool.dispatch`, `mind.tool.result`,
  `mind.tool.error`, `mind.tool.rejected` — all versioned and
  reconstructible via `bridgeEffectFromMap`.
- **Replay:** the tool invocation is `journal.io('mind.tool.call.<verb>')`;
  replay serves the recorded output and never re-invokes the tool.
- **Clock precision (F9.6):** clock effects store epoch **millis**;
  `toolRouter` derives `startAt`/`endAt` from millisecond-truncated
  journal clocks (`_clockMs`) so `durationMillis` never flaps at ms
  boundaries on replay.

**Relationship to prompted policy:** bridges produce *data* (pulses
that then get governed); prompted policies produce *verdicts* inside
governance. They compose: gather with `toolRouter`, judge with
`promptedPolicyWith`.

---

## 10. XAI layer (Phase 6)

**Files:** `lib/src/xai.dart`, `lib/src/internal/narrative.dart`.

- `DecisionPath` — read-only projection over a `Decision`.
- Three narrative templates: `audit` (persisted), `ui` (human),
  `debug` (tooling). Missing provenance is elided, never invented.
- `explainPulse` (traceId, newest first) and `explainSource`
  (source cell) locate the decision that matters.
- `otelSpans` — spans reconstructed from the log through a minimal
  `Tracer` abstraction (~20-line adapter; no SDK dependency).
- Prompted decisions explain through the verdict's
  `reason`/`resolver`/annotations; the prompt/response pair in the
  journal is the evidence boundary — the model's internal reasoning
  is deliberately not reconstructable.

---

## 11. Agent layer (Phase 6)

**File:** `lib/src/agent.dart`, `lib/src/internal/debate_effects.dart`.

- `AgentSpec` — immutable mandate (name, cell, mandate context,
  verdict policy, route-in).
- `spawn(spec, {journal})` → `AgentRuntime` with its own decision
  log, outcomes, and trace.
- `debate({participants, question, journal})` — single-round voting
  (substrate completes a pulse at its first terminal), consensus
  threshold, recorded `MindDebateEffect`.
- **Prompted agents (1.1.0):** per-agent prompted policies;
  `SessionMode.shared` gives several agents one conversation window
  (content-addressed session fingerprints keep cache keys correct).

---

## 12. Prompt layer — phases 8, 8.1, 9

**Files:** `lib/src/prompt_policy.dart`, `prompt_config.dart`,
`prompt_session.dart`, `verdict_cache.dart`, and the `internal/`
helpers (`fingerprint.dart`, `prompt_effect.dart`, `prompt_cache.dart`,
`config_renderer.dart`, `session_renderer.dart`,
`config_validation.dart`, `config_presets.dart`, `conformance.dart`,
`decision_renderer.dart`, `context_renderer.dart`,
`verdict_parser.dart`, `policy_helpers.dart`).

### 12.1 — Two modes, one pipeline

| Mode | Factory | Session | Cache |
|---|---|---|---|
| Inline | `promptedPolicy(...)` | stateless | per-instance |
| Config | `promptedPolicyWith(config:/configId:)` | `config.sessionMode` | config-keyed |

Both share one renderer, one parser, two caches, and one
journal-effect family. `promptedPolicyWith` returns a public
`PromptedPolicy` (implements `VerdictPolicy`) exposing `.session`,
`.config`, and journaled `clearSession()`.

### 12.2 — The prompt substrate

The `Context` **is** the prompt: `renderContext` walks `Ontology`
then `Mandate` in declaration order, sorted-JSON map values, ISO-8601
UTC dates, empty dimensions omitted. `renderDecision` emits the
pulse/command shape; pulse timestamps are never rendered.
`PromptConfig.render` substitutes `{{context}}`/`{{decision}}` into
the user template, prepends the system prompt and few-shot examples,
appends the output schema, and — when a session is non-empty —
inserts `## Conversation History` before `## Current Request`.

### 12.3 — The three-tier fast path

```
Decision (post-structural)
   │
   ▼ compute fingerprints (sha256, incl. session fp)
   │
   ▼ Verdict cache lookup            input-keyed
   │    hit → VerdictCacheHitEffect; no render, no LLM, NO session append
   ▼ Render prompt (session-aware)
   ▼ Prompt cache lookup             output-keyed: sha256(id|ver|sha256(prompt))
   │    hit → append session → populate verdict cache (D14) → HitEffect
   ▼ LLM call (journaled io) → parse (fail-closed)
   ▼ Append session → populate prompt cache → populate verdict cache
   │    (post-append key, D14) → PromptEffect → return
```

- **Verdict cache** — `VerdictCache` interface (sync by design);
  `InMemoryVerdictCache` (TTL + access-order LRU + `keys` view);
  `VerdictCacheKey` (six fingerprints + `composite` +
  `fingerprint`); `VerdictCacheEntry` (`verdict`, `storedAt`,
  `originalLatency`, `fromPromptCache`).
- **Prompt cache** — static per `(config.id, config.version)`;
  the rendered prompt participates through its hash.
- **TTL controls** — `cacheTtl` (prompt tier) and `verdictCacheTtl`
  (verdict tier) independently disable-able with `Duration.zero`;
  `maxVerdictCacheEntries` bounds memory.

### 12.4 — Fingerprints

`cellContextFingerprint`, `pulseContextFingerprint`,
`decisionFingerprint` are **public** (D9 manual diagnostics) and
cover exactly the dimensions the renderer emits — `traceId`
included, timestamps excluded. The session fingerprint is
content-only (`PromptSession.fingerprint()`; `''` when empty), so
stateless and empty-session decisions share keys by design.

### 12.5 — Sessions

`PromptSession` (id, `maxMessages` 40, `maxChars` 20000) holds
`ChatMessage(role, content)` history; `SessionMode`
(`stateless` / `dedicated` / `shared`) decides creation and sharing.
Compaction drops the oldest `(user, assistant)` **pairs** first,
then non-initial system messages; a pair is never partially dropped.
Every mutation journals: `mind.session.init` / `.append` /
`.clear` / `.compact`.

### 12.6 — Journal effects and replay

| Label | Effect | Semantics |
|---|---|---|
| `mind.prompt` | `PromptEffect` v1.1.0 | full prompt + response, `cacheKey`, `contextHash`, `decisionHash`, `sessionFingerprint?`, `sessionId?`, latency |
| `mind.prompt.cache.hit` | `VerdictCacheHitEffect` (map `type: mind.verdict_cache_hit`) | served verdict + key |
| `mind.session.init/append/clear/compact` | session effects | reconstruct the conversation |
| `mind.prompt.disposition` | internal dispatcher | `verdict-cache-hit` / `prompt-cache-hit` / `llm` / `prompt-too-long` |

The **disposition** is the replay linchpin: recording computes it
from live caches inside the effect's run closure; replay serves it,
so both sides take the identical branch without re-consulting caches
or the adapter. Its input is
`'${key.fingerprint}|${config.maxPromptChars}'` — the config id is
therefore part of journal identity (recording and replay must share
the config instance).

Fail-closed paths (`prompt-error`, `prompt-timeout`,
`parse-error-*`, `missing-verdict`, `unknown-verdict`,
`missing-reason`, `defer-missing-resolver`, converter failures)
journal but never populate caches or append sessions (D17);
business rejections (including classifier labels) are cached.

### 12.7 — Config, registry, conformance

- `PromptConfig` — id, version, system prompt, user template,
  output schema, examples, parameters, TTLs, session bounds;
  `validate()` checks structure, not model compliance.
- Presets — `policyDecider`, `classifier(labels:)` +
  `labelToVerdict`, `extractor(fields:)` + `extractionToVerdict`.
- `PromptConfigRegistry` — highest-version lookup, pinned-version
  lookup, list, unregister (A/B + rollback).
- `conform(config:, prompt:, cases:)` — deploy gate against a real
  adapter; **bypasses caches and sessions** (D14 in the revised
  plan), compares verdict type + `Reject.reason` + `Defer.resolver`.

---

## 13. Journal architecture (cross-cutting)

The `EffectJournal` contract from the `cell` substrate is the
durability spine:

```
RecordingJournal.clock()   → ClockEffect(epochMillis)      [replay: millis]
RecordingJournal.io(...)   → IoEffect(label, inputDigest, outputDigest, rawOutput)
RecordingJournal.timer/uuid → recorded for replay
ReplayJournal  — serves recorded effects; divergences throw
                 ReplayDivergenceException (loud, latched)
```

Rules every `cell_mind` primitive follows:

1. External reads/writes go through `journal.io` — replay never
   executes the live closure.
2. Timestamps come from `journal.clock()`; **durations derived from
   two clocks must use millisecond-truncated instants** (`_clockMs`,
   F9.6) because clock effects store millis.
3. Effect inputs are fingerprint-exact maps; a changed value
   diverges loudly (changed key order does not).
4. `NullJournal` fails loudly; nothing defaults a journal.

---

## 14. Trust model

```
structural policy ──(narrow)──▶ learned policy ──(narrow)──▶ prompted verdict ──(escalate)──▶ human
```

- **Structural-first, always.** Caches, LLMs, and learned rules are
  post-structural; a cache hit cannot accept what policy rejected
  (D11).
- **Fail closed.** Missing metadata rejects; malformed LLM output
  rejects; resolver failure rejects; over-long prompts reject
  without a call.
- **Content-addressed memoization.** Cache identity is content, not
  identity or time; version bumps are the only invalidation lever.
- **Journaled escalation.** Deferral and its resolution are two
  decisions; prompts and cache hits are journal effects; the audit
  trail never loses a step.

---

## 15. Determinism and replay

- **Decision log** — serializable, version-stamped, replayable in
  shape.
- **Training** — identical logs under `ReplayJournal` produce
  identical `TrainedPolicy` blocks.
- **Bridges** — tools are journaled io effects; replay serves
  recorded results.
- **Prompted decisions** — the disposition effect makes recording
  and replay take identical branches; sessions rebuild from served
  appends; the adapter never runs on replay.
- **Known sharp edges** — replay needs the same config identity
  (disposition input hash); session mismatches surface as
  `ReplayDivergenceException`; journal-clock durations must be
  ms-derived.

---

## 16. File map

| File | Responsibility |
|---|---|
| `lib/cell_mind.dart` | barrel (`part` files), exports, categories |
| `lib/doc/api_chooser.dart` | curated API index |
| `lib/src/policy.dart` | policy factories, `Verdict` |
| `lib/src/runtime.dart` | `cognitive`, `CognitiveHandle` |
| `lib/src/learning.dart` | trainer, `TrainedPolicy` |
| `lib/src/outcomes.dart` | `Outcome`, `recordOutcomes` |
| `lib/src/approval.dart` | `ApprovalQueue`, resolver |
| `lib/src/bridge.dart` | completion/streams/toolRouter, `_clockMs` |
| `lib/src/xai.dart` | `DecisionPath`, `explain*`, `otelSpans` |
| `lib/src/agent.dart` | `AgentSpec`, `spawn`, `debate` |
| `lib/src/prompt_policy.dart` | prompted policy, `conform`, disposition pipeline |
| `lib/src/prompt_config.dart` | config, examples, registry, `SessionMode` |
| `lib/src/prompt_session.dart` | session primitives, compaction |
| `lib/src/verdict_cache.dart` | cache interface, in-memory impl, key/entry |
| `lib/src/internal/fingerprint.dart` | public fingerprint functions |
| `lib/src/internal/prompt_effect.dart` | prompt/cache/session effects |
| `lib/src/internal/prompt_cache.dart` | output-keyed prompt cache |
| `lib/src/internal/config_renderer.dart` | template substitution |
| `lib/src/internal/session_renderer.dart` | history block |
| `lib/src/internal/context_renderer.dart` | `## Context` block |
| `lib/src/internal/decision_renderer.dart` | `## Decision` block |
| `lib/src/internal/verdict_parser.dart` | fail-closed parsing |
| `lib/src/internal/config_validation.dart` | structural config checks |
| `lib/src/internal/config_presets.dart` | three presets |
| `lib/src/internal/conformance.dart` | conformance runner |
| `lib/src/internal/bridge_effects.dart` | bridge effect schema |
| `lib/src/internal/debate_effects.dart` | debate effect |
| `lib/src/internal/bandit.dart` | bandit trainer |
| `lib/src/internal/context_vector.dart` | vectorization |
| `lib/src/internal/narrative.dart` | narrative templates |
| `lib/src/internal/recording_test_cell.dart` | recorder deputy |
| `lib/src/internal/decisions.dart` | `Decision` record |
| `lib/src/internal/verdicts.dart` | verdict classes |

---

## 17. End-to-end walkthroughs

### 17.1 — An accepted pulse

`ingest(pulse)` → principal passes → `contextAware()` passes →
`verdictPolicy` (none) → recorder deputy appends
`Decision(accept)` → downstream state transitions; the wave
completes.

### 17.2 — A prompted decision (first sight of an input)

`ingest(pulse)` → principal + structural pass → fingerprints →
verdict-cache miss → render (session empty → stateless layout) →
prompt-cache miss → `journal.io('mind.prompt', input: fullPrompt)`
invokes the adapter → parse JSON schema → `Accept` →
no session to append → populate prompt cache → populate verdict
cache under the post-append key → journal `PromptEffect` →
`Decision(accept)`.

### 17.3 — A prompted decision (repeat input)

Same input: fingerprints → verdict-cache hit → journal
`VerdictCacheHitEffect` → `Decision(accept)` with the served
verdict. No render, no adapter, no session mutation, no prompt-cache
touch.

### 17.4 — A prompted decision (dedicated session, new input)

Fingerprints (session fp ≠ previous) → miss → render with
`## Conversation History` → LLM → parse → append the
`(user, assistant)` pair (journal `mind.session.append`) → populate
prompt cache → populate verdict cache under the **post-append** key
→ return. Repeating this exact decision now hits the verdict cache
and does not create a new turn (D14).

### 17.5 — A deferral to a human

Prompted verdict `Defer('approval')` → pulse dropped from the wave
→ `Decision(defer)` recorded → resolver enqueues in
`ApprovalQueue` → human approves → `Decision(accept, deferredBy)`
linked by id → committed stream delivers.

### 17.6 — Replay of the above

`ReplayJournal(recording.toJson().map(EffectRecord.fromJson))` →
re-run the identical decisions with the same config instance →
dispositions served (`llm`, `verdict-cache-hit`), session appends
served, adapter never invoked, `assertExhausted()` passes; any
fingerprint mismatch throws `ReplayDivergenceException`.

---

## 18. Performance characteristics

| Operation | Measured | Note |
|---|---|---|
| Prompt render | ~22k/s | benchmark |
| Response parse | ~246k/s | benchmark |
| Verdict-cache-hit decision | ~6.9k/s | full cognitive wave, mock adapter |
| Prompt-cache-hit decision | ~5.8k/s | render + hash, no LLM |
| Full cache-miss decision | ~1.7k/s | mock adapter dominates |
| Real-LLM latency | 500–2000 ms | user adapter |
| Recording | deputy validation + append | `recording_cost.dart` |
| Bandit training | tens of thousands of decisions/s | `training_cost.dart` |

The verdict cache turns repeat decisions into microseconds of
hashing and a map lookup — the practical win against any real
network is orders of magnitude.

---

## 19. Guarantees and invariants (maintainer checklist)

1. Policies are pure; effectful primitives require journals.
2. Composition is left-to-right, short-circuiting, narrowing only.
3. Attribution strings are frozen and load-bearing for XAI.
4. Training never mutates live policy or context; deployment is
   explicit.
5. Deferral drops the wave and resolves out-of-band; the audit is a
   two-decision pair.
6. Tool invocations are journaled io effects; replay never calls the
   world.
7. Clock-derived durations use millisecond-truncated instants
   (`_clockMs`).
8. Cache keys are content hashes including `config.version`;
   timestamps never participate.
9. Session mutations are journaled; compaction never splits a pair;
   cache population follows D14 (append first, store post-append).
10. Replay needs the recording's config identity; divergence is loud.
11. `FROZEN_API.md` is the frozen surface — regeneration must be a
    fixed point (`dart tool/freeze_api.dart`), and the 1.1.0 diff is
    additive except the documented `FutureOr<Verdict>` widening.
12. The fitness suite pins the substrate contract and is never
    modified by `cell_mind` phases.

---

## 20. Evolution and deferred work

| Concern | Where |
|---|---|
| `promptedAnnotations()` (LLM as decision support) | planned (prompt tuning) |
| Prompt tuning from outcomes | planned |
| Session summarization / hierarchical compaction | planned |
| Sampling, multi-LLM voting, session branching | later |
| LLM SDK adapters (`cell_mind_openai`, …) | satellite packages |
| Distributed verdict caches (Redis, …) | user `VerdictCache` implementations |
| Strict-LRU `accessOrder` flag | unnecessary — access-order LRU shipped |

---

## 21. Documents and references

- Guides: `guide/00-Getting-Started.md` … `guide/12-Prompted-Policy.md`
- Plans and verdicts: `research/Mind/Phase-0.md` … `Phase-9.md`,
  `packages/cell_mind/_phase*_verdict.md`
- Frozen API: `FROZEN_API.md`; changes: `CHANGELOG.md`;
  limitations: `KNOWN_ISSUES.md`
- Runnables: `example/09_acceptance.dart`,
  `example/10_prompted_policy.dart`, `benchmark/micro/*`,
  `test/cookbook/*`
