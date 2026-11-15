# Changelog

All notable changes to `cell_mind` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and the package
adheres to [Semantic Versioning](https://semver.org/).

## 1.1.0

**Prompt-driven policy, verdict caching, and stateful chat sessions.**
A `Context` becomes a prompt, any AI answers, and the answer becomes a
`Verdict` in the existing `cognitive()` pipeline — memoized by a
two-tier cache and embedded in a journaled conversation window.

### Added

- **`promptedPolicy(...)`** — inline mode: one-off prompts with
  per-instance caches, always stateless.
- **`promptedPolicyWith(config: / configId:)`** — config mode: the
  primary API; shares one renderer, parser, cache, and journal-effect
  family with inline mode.
- **`PromptedPolicy`** — the returned `VerdictPolicy` with
  `.session` access and journaled `clearSession()`.
- **`PromptConfig`** — portable, JSON-serializable, semantically
  versioned configuration (`policyDecider` / `classifier` /
  `extractor` presets + `custom`); now with `verdictCacheTtl`,
  `maxVerdictCacheEntries`, `sessionMode`, `maxSessionMessages`,
  `maxSessionChars`, and session-aware `render`.
- **`PromptExample`** — structured few-shot triples.
- **`PromptConfigRegistry`** — versioned lookup: A/B testing and
  runtime rollback.
- **Verdict caching (three-tier fast path)** —
  `VerdictCache` / `InMemoryVerdictCache` (TTL + LRU) /
  `VerdictCacheKey` / `VerdictCacheEntry`, plus the output-keyed
  prompt cache: verdict-cache hits skip rendering and the LLM;
  prompt-cache hits skip the LLM.
- **Chat sessions** — `PromptSession` / `ChatMessage` / `ChatRole` /
  `SessionMode` (`stateless` / `dedicated` / `shared`); deterministic
  pair-granular compaction; content-only fingerprints that
  participate in the verdict cache key.
- **`conform`** — first-class conformance testing against a specific
  LLM (`ConformanceCase`, `PromptConformanceReport`,
  `ConformanceFailure`); bypasses caches and sessions.
- **Journal effects** — `PromptEffect` (v1.1.0: `cacheKey`,
  `sessionFingerprint`, `sessionId`), `VerdictCacheHitEffect`,
  `SessionInitializedEffect`, `SessionAppendedEffect`,
  `SessionClearedEffect`, `SessionCompactedEffect`, each with
  replay semantics.
- **`PromptFunction`, `ContextRenderer`, `DecisionRenderer`,
  `VerdictParser`** — the typed, replaceable pipeline primitives.
- **`renderContext`, `renderDecision`, `parseVerdict`** — the default
  deterministic renderer and the fail-closed parser as public
  functions.
- `crypto: ^3.0.0` dependency (the only new dependency).
- `guide/12-Prompted-Policy.md` (21 sections + appendices),
  `example/10_prompted_policy.dart` (session + cache demos),
  `benchmark/micro/prompted_policy_cost.dart` (verdict-cache-hit /
  prompt-cache-hit / session-render costs), 22 test files under
  `test/prompt/` (230+ tests).

### Changed

- **`VerdictPolicy.call` may now return `Future<Verdict>`** (return
  type widened to `FutureOr<Verdict>`); the recording runtime awaits
  it. **Source-compatible** with every 1.0 implementation — rules
  that return `Verdict` still compile unchanged. This is the only
  signature change in the frozen manifest (see `FROZEN_API.md`).
- `verdictPolicy(...)` accepts `FutureOr<Verdict>` rules.
- Argument-level rule evaluations no longer reach a prompted policy:
  the LLM decides about the command *with* its arguments at the
  command decision (adapter cost is one call per decision).
- `tool/freeze_api.dart` now emits a deterministic manifest header —
  CI can diff a fresh generation against the committed file without
  timestamp noise.

### Fixed

- Replay divergences from the prompt journal now propagate loudly
  (`ReplayDivergenceException`) instead of being recorded as
  `composite-rejected` decisions.
- Verdict-cache population follows D14 order (append to the session
  first, then store under the post-append key) so repeated decisions
  hit without polluting the conversation.

### Migration from 1.0.0

- **No breaking changes.** Every 1.0 public API is preserved; the
  `VerdictPolicy` widening is source-compatible.
- The LLM adapter is your code: wrap your SDK in ~10 lines of
  `(String prompt) async => response`.
- Replay requires the same config instance (or a config with the
  same id + version) as the recording — the config id participates in
  the verdict cache key that identifies journal dispositions.

### Phase 8 + 8.1 — prompt

- `FROZEN_API.md` diff is additive for the prompt module; the one
  signature change (`VerdictPolicy.call` → `FutureOr<Verdict>`) is
  documented above and in `_phase8_verdict.md`.

### Known issues

See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## 1.0.0

**Cell Mind reaches 1.0.** The public API is now stable — every type,
method, and typedef shipped in this release is frozen for the `1.x`
series. See [`FROZEN_API.md`](FROZEN_API.md) for the complete manifest.

### Highlights

- **Context as policy.** `Policy` factories translate `Context` into
  runtime decisions. Fail-closed by default.
- **Decision log with replay.** `CognitiveHandle` records every
  accept/reject/defer with the context version active at decision
  time.
- **Offline learning.** `trainOffline` produces a `TrainedPolicy`
  that `learnedPolicy()` applies back to a `Context`.
- **Human-in-the-loop.** `ApprovalQueue` and `approvalResolver` make
  `Defer` a first-class verdict.
- **LLM bridges.** `completion`, `streamCompletion`, `toolRouter` —
  transport-agnostic, journaled, four rejection classes.
- **XAI.** `DecisionPath.toNarrative` and `otelSpans` for audit logs.
- **Multi-agent.** `spawn` + `debate` for orchestrated consensus.

### Migration from 0.x

If you're upgrading from `0.6.x`:

- **No breaking changes.** Every 0.6 public API is preserved.
- **`cognitive()` host adaptation (0.6.1).** The host's `validate` is
  now wrapped adaptively instead of cast to `TestCell` — organ stems
  no longer crash `cognitive()`. Hosting recorders on organ stems
  remains unsupported (their `deputy` accepts only `TestStem`); host
  the handle on a bound ingress.
- **`api_chooser.dart` added.** See the file for the guided index.
- **`Verdict.type`** was added in 0.6.0 (`accept`/`reject`/`defer`).

### Phase 7 — stabilization

- `example/09_acceptance.dart` — the fraud-detection acceptance
  pipeline exercising every module end-to-end with hard checks.
- `test/integration/acceptance_test.dart`,
  `test/integration/cross_library_test.dart` — end-to-end and
  `cell` ↔ `cell_tissue` ↔ `cell_organ` composition.
- `test/fitness/doc_completeness_test.dart` — the doc audit gate.
- `test/cookbook/*.dart` — 15 recipe tests.
- `tool/freeze_api.dart` + `FROZEN_API.md` — the semver contract.
- `lib/doc/api_chooser.dart` — the curated index.
- `guide/00-Getting-Started.md`, `guide/09-Cookbook.md`,
  `guide/10-Design-Notes.md` (phase findings), `guide/11-Internals.md`.
- Stability notes on every public doc block
  (`Stable since cell_mind 1.0.0`).
- CI: doc build (`dart doc --validate-links`), coverage gate
  (88% line), publish dry-run, explicit cookbook discovery.

### Known issues

See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## 0.6.1

### Fixed

- `cognitive()` no longer casts the host's `validate` to `TestCell`
  (crash with `cell_organ` stems). The host rule is dispatched
  adaptively; organ stems with the same call contract work as far as
  their own `deputy` API allows.

### Notes

- Organ stems still cannot **host** recorders: their `deputy` accepts
  only `TestStem` gates. Host the cognitive handle on a bound
  ingress (recipe 10). Documented in `KNOWN_ISSUES.md`.

## 0.6.0

### Added — Phase 6 (xai + agent)

- `DecisionPath` — read-only projection over a `Decision` with derived
  provenance accessors and `toNarrative()`.
- `NarrativeTemplate` — `audit` / `ui` / `debug` rendering.
- `explain(decision)` / `explainPulse(pulse, handle)` /
  `explainSource(cell, handle)` — the three explanation entry points
  (trace-id and emitter-id matching).
- `Tracer` / `Span` / `SpanContext` / `SpanStatus` — minimal tracing
  abstractions (no OTel SDK dependency).
- `otelSpans(decisions, {tracer, spanName, extraAttributes})` — causal
  span reconstruction with parent/child from `parentTraceId`.
- `AgentSpec<C>` / `spawn(spec, {journal})` / `AgentRuntime<C>` —
  deputy-scoped cognitive agents with isolated traces, outcomes, and
  `routeIn` debate channel; `dispose()` lifecycle.
- `DebateOutcome` / `debate({participants, question, journal,
  maxRounds, consensusThreshold})` — single-round majority vote with
  journaled `MindDebateEffect`.
- `Verdict.type` discriminants (`accept`/`reject`/`defer`).
- `receptor_fix_test.dart` — pins the Phase 2 recording claims on the
  live deputy implementation (already true; no runtime change).
- 48 Phase 6 tests; full suite at 393.
- `guide/07-XAI.md` (416 lines), `guide/08-Agents.md` (421 lines),
  `example/07_multi_agent.dart`, `example/08_xai_audit.dart`,
  `benchmark/micro/xai_cost.dart`, `benchmark/micro/spawn_cost.dart`,
  `_phase6_verdict.md`.

### Notes

- The plan's Phase 2 receptor fix is unnecessary on the live
  substrate: `cognitive()` uses `cell.deputy(testRule: recorder)`,
  which already records pulses through the cognitive view.
- Plain-cell deputies are not emittable (`OpenCell`) — debates route
  through `AgentSpec.routeIn`.
- The plain-cell deputy path accepts unrelated mandates (documented
  leniency; the causal-integrity throw was not observed).
- A pulse completes at its first terminal — debates ingest once per
  shared source and never re-route; stateless agents make round 2
  moot.
- Agent training applies to the source cell's plain `Context`
  (`Ontology.constraints` does not exist on deputy contexts).

## 0.5.0

### Added — Phase 5 (bridge)

- `Tool` typedef — `Future<Object?> Function(Map<String, dynamic>)`.
- `completion({future, actor, prompt, confidence, journal, baseContext,
  strategy})` — single-shot governed bridge; **confidence required**;
  typed `mind.completion.result` / `mind.completion.error` pulses.
- `streamCompletion({tokens, actor, prompt, journal, baseContext,
  cancelOnError})` — per-token governed pulses.
- `streamChunks({chunks, actor, journal, buffer})` — opt-in lossless
  buffering (flush on close/error).
- `toolRouter({source, tools, actor, journal, minConfidence,
  fireAndForget})` — closed-verb dispatch; awaits by default;
  `fireAndForget` opt-in; four rejection classes as distinct pulse
  types (`mind.tool.rejected.unknown-verb` / `low-confidence` /
  `invalid-args`, `mind.tool.error.<verb>`); result pulses ride as
  payloads (unwrap once).
- Seven typed, versioned journal effects (`MindCompletionEffect`,
  `MindCompletionErrorEffect`, `MindStreamChunkEffect`,
  `MindToolDispatchEffect`, `MindToolResultEffect`,
  `MindToolErrorEffect`, `MindToolRejectedEffect`) +
  `bridgeEffectFromMap` dispatcher.
- Replay-safe tool invocation: `mind.tool.call.<verb>` journaled io —
  replay serves recorded outputs without re-invoking tools.
- 54 bridge tests across 9 files; full suite at 345.
- `guide/06-Bridges.md` (472 lines), `example/06_llm_bridge.dart`,
  `benchmark/micro/bridge_cost.dart`, `_phase5_verdict.md`.

### Notes

- `PulseContext.aiInference` does not exist in `cell` 1.1.0 — bridge
  contexts compose `Provenance` entries via `PulseContext.fromEntries`.
- `IngressHandle.emit` takes the value, not a pulse — bridges emit
  governed pulses through an `OpenCell.perform` pass-through.
- `Cell.asyncMap` passes the source cell's PAYLOAD to the mapper; the
  router sources pulses as payloads to retain provenance access.
- `exhaust: true` (hard-coded in `toolRouter`) DROPS arrivals while a
  tool runs — LLM loops emit sequentially.
- Replay clocks truncate to milliseconds; effect `at` fields truncate
  likewise for fingerprint stability.
- `Future<Never>` tool futures use `.then<void>` for swallowed
  fire-and-forget errors (`catchError` handlers must return `Never`).

## 0.4.0

### Added — Phase 4 (approval)

- `VerdictPolicy` — a first-class policy type returning full verdicts
  (`Accept` / `Reject` / `Defer`), separate from bool `Policy`;
  `+` short-circuits on Accept/Reject, Defer propagates.
- `verdictPolicy(fn)` factory for user-authored verdict rules.
- `cognitive({..., verdictPolicy, onDeferred})` — the two new slots;
  Phase 1–3 call sites unchanged.
- `ApprovalQueue<T>` — HITL primitive: `TissueMap` pending +
  `ValueCell<T?>` committed; `Cell.txApply` atomic approve/reject
  (rollback verified against the live substrate); cancellable TTL
  sweeper; `maxPending` capacity; disposal completes pending futures.
- `ApprovalRequest<T>` — full-decision audit record with
  `toMap`/`fromMap`.
- `approvalResolver(queue, {resolverName})` — routes `Defer` verdicts
  to the queue.
- `learnedVerdictPolicy()` — honours learned `accept`/`reject`/`defer`
  rules (`learnedPolicy()` remains bool-only and defer-transparent).
- Journaled effects: `mind.approval.submitted` / `.decided` /
  `.expired` / `.disposed`.
- Wave-honest Defer semantics: the `Defer` is recorded and the pulse
  drops from the wave; the resolver runs out-of-band and its result is
  recorded as a follow-up decision linked by `decisionId` — the
  request/resolution audit pair.
- 59 approval tests across 11 files; full suite at 291.
- `guide/05-Approval.md` (501 lines), `example/05_approval_defer.dart`,
  `benchmark/micro/approval_roundtrip.dart`, `_phase4_verdict.md`.

### Notes

- `TissueMap.apply(tx:)` and `ValueCell.apply(tx:)` stage correctly on
  the live substrate — the primary D3 pattern ships; no fallback.
- The substrate evaluates async rules twice per pulse with distinct
  pulse objects — awaiting human latency inside a wave is unsafe,
  hence wave-honest Defer (see `_phase4_verdict.md` A1).
- `EffectJournal.timer` is un-cancellable — the sweeper uses a
  cancellable `dart:async` Timer and journals expirations explicitly.
- `StateError` is an `Error`, not an `Exception` — resolver failures
  catch any throwable and fail closed with `defer-resolver-failed`.
- Static generic methods are called `Class.fromMap<T>(...)`, not
  `Class<T>.fromMap(...)` (language constraint, pinned by tests).
- `TissueMap` gating uses `TestTissue`/`TissueMapNucleus`, not
  `TestCell`.

## 0.3.0

### Added — Phase 3 (learning)

- `Outcome` typed reward record + `recordOutcomes(handle)` —
  accumulates the outcome channel into an observable
  `TissueList<Outcome>` (record return: `log` + `stop`).
- `Trainer` protocol and `contextualBandit()` reference implementation:
  joins decisions ⋈ outcomes by decision id, buckets by canonical
  context vector, emits `accept`/`reject` rules under
  `minSupport`/`minConfidence`/`maxRules`, sorted by confidence.
- `TrainedPolicy` — portable record (`toMap`/`fromMap`/`applyTo`),
  journal-time `trainedAt`, deterministic under `ReplayJournal`.
- `trainOffline({handle, outcomes, baseContext, trainer, journal,
  reward, config})` — the loop's train stage.
- `TrainingConfig` — immutable thresholds (`minSupport: 5`,
  `minConfidence: 0.6`, `maxRules: 100`, `window`, `prune`).
- `learnedPolicy()` — reads
  `Ontology.constraints['cell_mind.policy']`, subset-matches
  confidence-ordered rules, pass-through when silent; commands/links
  pass through in 0.3.0.
- `ContextVector` — canonical vector shared by the trainer and the
  runtime matcher.
- Additive merge (default) vs. `prune: true` full replacement;
  pruned rules are journaled (`mind.pruning`).
- 48 learning tests across 9 files; full suite at 232.
- `guide/03-Learning.md` (606 lines), `example/04_learning_loop.dart`,
  `benchmark/micro/training_cost.dart`.

### Notes

- The live `EffectJournal` has no `now()`/`record(...)` — `trainedAt`
  uses `journal.clock()` and runs are recorded as `journal.io(...)`
  effects (`mind.training`, `mind.pruning`).
- The context vector includes pulse provenance, so learned rules are
  actor-specific by default (`when` contains `actor`).
- Replay restores clock epochs in local time — determinism tests
  compare instants via `.toUtc()`.
- `applyTo` evolves once with the fully-merged block, honoring Phase
  0's F1 replace-not-merge finding.

## 0.2.0

### Added — Phase 2 (runtime)

- `CognitiveHandle<C>` — principal + governed recording view +
  `TissueList<Decision>` log + `IngressHandle<Pulse>` outcome channel +
  `recordOutcome` + guarded `dispose`.
- `cognitive(cell:, policy:, maxDecisions:)` — dynamic mode via the
  public `Cell.deputy(testRule:)` path (no receptor wrapper, no
  private-cell access).
- `Decision` — id, timestamp, context + version, pulse/command,
  verdict, policy version, evaluation time; `toMap` / `fromMap`
  (documented lossy for live objects).
- `_RecordingTestCell` — sequential principal-then-policy evaluation
  with composite-level attribution (`principal-rejected` /
  `policy-rejected` / `composite-rejected`), fail-closed on
  exceptions, `Purity.readOnlyExternal`, version `1.0.0`.
- Bounded log: `maxDecisions` rolling drop, observable via the
  `TissueList` removal pulse.
- 50 runtime tests across 11 files; full suite at 184.
- `guide/02-Runtime.md` (616 lines), `guide/04-Determinism.md`
  (315 lines).
- `example/02_authority_deputy.dart`, `example/03_decision_log.dart`.
- `benchmark/micro/recording_cost.dart` — bare apply vs. cognitive
  apply.

### Notes

- No `_CognitiveReceptor`: the live `Cell.deputy(testRule:)` API chains
  `[principalRule, recorder]` and shares container/lock/context. The
  documented costs: the principal rule evaluates twice on the deputy
  path (pure rules make this safe) and principal rejections drop before
  the recorder (not logged).
- The recorder widens its `host` parameter to `Cell?` and forwards the
  *principal* to the principal rule — required because `ValueCell`
  rules enforce a covariant `ValueCell` host.
- Argument evaluations during action validation are enforcement-only;
  a rejection there is attributed to the command.
- `Decision.command.compensation` is always `null` — the `TestCell`
  dispatch forwards `(function, arguments)`, not the full command.
- Outcome channel contract: each entry's payload is the outcome pulse
  (`type: 'mind.outcome'`, payload = reward map).

## 0.1.0

### Added — Phase 1 (policy)

- `Policy` typedef — `TestCell<Cell>` composition contract.
- Domain: `domainPolicy` (fail-closed on untagged claims, opt-out
  `allowUntagged`), `requiresDomainPolicy`, provenance-aware origin
  resolution (pulse claim ⊆ source cell claim, else `StateError`).
- Compliance: `compliancePolicy`, `complianceOverlapPolicy`.
- Authority: `authorityPolicy` (mandate verb whitelist + custom
  `verbResolver`), `exactFunctionsPolicy` (identity whitelist).
- Clearance: `clearancePolicy` with `ApplyCategory` (pulse / pure /
  structural / crossDomain) and custom requirement maps.
- Isolation: `isolationPolicy` for all five `Isolation` levels.
- Data/trust: `sensitivityPolicy`, `confidencePolicy`,
  `strategyPolicy`, `auditLevelPolicy`.
- Identity: `actorPolicy`, `purposePolicy`.
- Time: `notOlderThan` (required injected clock,
  `Purity.readOnlyExternal`, version `1.0.0`).
- Custom/composition: `predicatePolicy`, `contextAware`, `paranoid`.
- `Verdict` sealed type (`Accept`, `Reject`, `Defer`) with
  `toMap` / `verdictFromMap` — consumed by Phase 2's decision log.
- Shared `{@template}` policy guidance in `lib/src/internal/macros.dart`.
- 119 policy tests across 14 files (dispatch matrix, fail-closed matrix,
  composition, serialization).
- `guide/01-Policies.md` reference and `example/01_hello_policy.dart`.
- `benchmark/micro/policy_cost.dart` — ns/decision at 1/3/10-deep
  composition vs. a manual baseline.

### Notes

- `policy_export.dart` is intentionally omitted: the single-library
  barrel includes `policy.dart` directly as a part.
- `predicatePolicy` matches the Plan.md signature (`{required Cell host}`
  only); Dart function subtyping forbids optional `arguments` without
  forcing every predicate to declare it.
- `Mandate.authority` is read through the context index operator in
  `cell` 1.1.0 (`context[Mandate.authority]` — no public getter).

## 0.1.0-dev

### Added — Phase 0 (Foundations)

- Repository scaffolding: `pubspec.yaml`, `analysis_options.yaml`, CI
  workflow (`.github/workflows/cell_mind.yml`), barrel stub
  (`lib/cell_mind.dart`), shared doc templates (`lib/src/internal/macros.dart`).
- Fitness suite (`test/fitness/cell_contract_test.dart`) — 16 canary tests
  verifying the five `cell` primitives `cell_mind` cannot survive without
  (Tier 1: F1–F5), three non-blocking verifications (Tier 2: F6–F8), and
  four structural verifications (Tier 3: F9–F12).
- Test fixtures (`test/helpers/fixtures.dart`) aligned to the live
  `cell` 1.1.0 API.
- Benchmark scaffolding (`benchmark/`) — four skeletons to be filled in by
  Phases 1–3.
- `guide/10-Design-Notes.md` — the durable artifact recording the nine
  design principles (P1–P9) and Phase 0 findings.
- `KNOWN_ISSUES.md` — verified-against baseline and discovered constraints.

### Notes

- No user-facing API. The barrel exports only `cell` and `cell_tissue`.
- Phase 0 verified `Context.evolve` **replaces** `Ontology.constraints` on a
  non-null resolver (no deep merge) — the Phase 3 trainer must merge the
  `cell_mind.policy` block explicitly. See `KNOWN_ISSUES.md` §F1.
