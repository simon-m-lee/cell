# Known Issues

## v1.1.0 — Prompted policy (final state)

All Phase 8 findings are documented and resolved or accepted. The
prompt module is additive on the frozen 1.0 API; the one signature
change is the source-compatible widening of `VerdictPolicy.call` to
`FutureOr<Verdict>` (see `_phase8_verdict.md` F8.1 and
`CHANGELOG.md`).

### Accepted limitations

- **No LLM SDK adapters, no retries, no rate limits.** The framework
  queries the model through your `PromptFunction`; transport is user
  code (guide 12 §16).
- **No framework-side timeout.** A `TimeoutException` thrown by the
  adapter is captured as `Reject('prompt-timeout')`; enforcing a
  deadline is adapter code.
- **Conformance ignores annotations** — comparison is by verdict type,
  `Reject.reason`, and `Defer.resolver` (parser-added `reason` /
  `confidence` would fail every hand-built expectation).
- **Cache TTL is wall-clock, per process.** Cross-process caching is
  out of scope; the journal is the durable layer.
- **Prompts store rendered text** (including the few-shot examples).
  If prompts carry sensitive data, redact at the journal layer.
- **`conform` targets verdict-shaped configs.** The classifier /
  extractor shapes have no conformance path in 1.1.0 (their converters
  are user code).
- **The `others` catch-all map is not rendered** — the public
  `Context` interface does not expose it through a getter.

### Post-1.1 roadmap (deferred)

- `promptedAnnotations()` (LLM as decision support) and prompt tuning
  from outcomes (Phase 9)
- Sampling (LLM on N% of decisions), multi-LLM voting, prompt
  versioning migration tool (v1.2)
- `cell_mind_openai` / `cell_mind_anthropic` satellite adapters

## v1.0.0 — Final state

All Phase 0–6 findings are documented and resolved or accepted.
The public API is stable (see `FROZEN_API.md`).

### Accepted limitations

- **`debate()` is single-round.** Multi-round debate with argument
  exchange is deferred to v1.1. Consensus is reached in round 1 or
  the question fails.
- **No HTTP client.** `cell_mind` is transport-agnostic. Use a
  satellite package or ~5 lines of glue (see `guide/06-Bridges.md`).
- **OTel is abstract.** `Tracer` / `Span` interfaces require an
  adapter (~20 lines; see `guide/07-XAI.md` §5).
- **Streaming confidence is 0.5.** Streams don't declare their own
  confidence. Override `baseContext` for governed streams.
- **`fireAndForget: true` swallows tool errors.** Documented; use
  `false` for visibility.
- **Organ stems cannot host `cognitive()` recorders.** Their
  `deputy` accepts only `TestStem` gates, not `TestCell` recorders.
  Host the handle on a bound ingress (recipe 10). The 0.6.1 adaptive
  host-rule dispatch removed the construction crash.
- **Bound organ blends with pass-through receptors throw on async
  ingest.** Keep cognitive handles on the ingress, not the blend.
- **`debate` requires `AgentSpec.routeIn`** — live deputies are not
  emittable cells.

### Post-1.0 roadmap (deferred to v1.1)

- Multi-round debate with argument exchange
- Inter-agent communication (agents observe each other's votes)
- `explainBlend` as a distinct method (currently `explainSource`)
- Command-based learning (`ApplyCommand` vectorization)
- Streaming debounce
- Multi-tool parallel dispatch (`exhaust: false`)
- `TrainedPolicy.diff(TrainedPolicy)` for audit
- `cell_mind_openai` / `cell_mind_anthropic` satellites
- Python trainer bridge

### Out of scope (deliberate)

- HTTP clients, provider SDKs
- Vector DB clients
- Prompt templating
- Model serving / inference
- Training loops / fine-tuning
- Emergent behavior

---

## Verified against

- `cell`: 1.1.0 — monorepo commit `6f22ec3b2cc129324812a62cf72e50e74d07e2e4`
  (2026-11-14)
- `cell_tissue`: 1.0.0 — same monorepo commit
- `cell_organ`: 1.0.0 — workspace source
- Dart SDK: 3.11.5 (stable)
- Platform: Windows x64 (fitness suite is platform-independent; CI runs
  ubuntu-latest)

## Phase 0 findings

### F1 — `Context.evolve` semantics for `Ontology.constraints`

**Verified outcome:** replace on non-null; preserve on null.

- `c1 = system.evolve((_) => Ontology.constraints.entry({'a': 1}))` →
  `c1.constraints == {'a': 1}`
- `c2 = c1.evolve((_) => null)` → `c2.constraints == {'a': 1}` (parent
  inherited)
- `c3 = c1.evolve((_) => Ontology.constraints.entry({'b': 2}))` →
  `c3.constraints == {'b': 2}` (**no merge**)

**Implication:** the Phase 3 trainer must merge existing constraints with
new rules **before** calling `evolve` (the `_accumulate` helper in
`guide/03-Learning.md` §4). This is the design's documented behavior, not a
`cell` bug.

### F2 — `TestCell.chain` short-circuit

**Verified outcome:** short-circuits correctly. Rejection on rule N prevents
rules N+1..M from running. Policy composition (P3, P9) is load-bearing.

### F3 — `Pulse.context` inheritance

**Verified outcome:** context inherits through `evolve`; `trace` accumulates.
Note the live call syntax is `Pulse<int>.governed(...)` — the
`Pulse.governed<int>(...)` spelling from the rc.9-era plan does not compile
on Dart 3.

### F4 — `TissueList` observation

**Verified outcome:** observation emits pulses; `stop()` halts them.

### F5 — `ApplyReceipt.vetted`

**Verified outcome (semantic shift vs. the rc.9-era plan):** in `cell`
1.1.0, `vetted` records **capability-manifest membership**
(`modifiable.contains(command.function)`), not "did the integrity gate run".
The gate runs on **every** apply — including non-manifest functions — so:

- a manifest-listed verb → `ApplyAccepted` with `vetted: true`;
- a non-manifest function → `ApplyAccepted` with `vetted: false`;
- an unmodifiable view → `ApplyRejected`.

The plan's expectation (`Cell.ingress` apply → `vetted: true`) was written
against rc.9. The fitness test now pins the live contract; Phase 2's audit
code must treat `vetted` as manifest membership, not gate execution.

### F6 — `Cell.deputy` state sharing

**Verified outcome:** deputies share the principal's container — an update
emitted by the principal is observed through the deputy's synapses. The
rc.9-era test accessed the private `_nucleus.bind`, which is impossible
cross-package; the fitness test proves sharing behaviourally instead.

### F7 — `Pulse.context` survives `apply`

**Verified outcome:** a governed pulse routed back through a cell's receptor
keeps its provenance (`actor` survives the round-trip).

### F8 — `EffectJournal` replay determinism

**Verified outcome:** a `RecordingJournal` replayed through a `ReplayJournal`
(built from `EffectRecord.fromJson`) reproduces recorded clock/uuid/io
observations byte-for-byte. The rc.9-era `JournalScope.replay(...)` helper
does not exist in `cell` 1.1.0; replay is `JournalScope.run(replayJournal, ...)`.

### F9 — `EphemeralPolicy` TTL

**Verified outcome:** TTL is an **inactivity window** — the timer arms on
first interaction and restarts on every interaction. The Phase 4 approval
TTL sweeper must model expiry this way (or use its own timer semantics
explicitly).

### F10 — `Identity.next()`

**Verified outcome:** unique across 100 generations.

### F11 — `PulseContext.systemInternal` defaults

**Verified outcome:** actor `system_daemon`, strategy `deterministic`,
confidence `1.0`, auditLevel `minimal`, priority `35`, purpose
`MAINTENANCE`, reason `automated internal task`, sensitivity `public`.

### F12 — `Cell.ingress` pulse-subtype handling

**Verified outcome:** plain, governed, lineage-evolved and collective pulses
all flow through. Note a `CollectivePulse<int>` is a
`Pulse<Iterable<Pulse<int>>>` (payload = the bundle) and `Pulse.batch`
returns the raw `Pulse` type — bridges and policies that inspect payloads
must account for both quirks.

## Static-pillar discoveries (rc.9-era plan → cell 1.1.0)

The plan's fixtures assumed every dimension is evolvable. In `cell` 1.1.0:

- `Ontology.domains`, `Ontology.version`, `Ontology.taxonomy`,
  `Ontology.topology`, `Ontology.dataSources` are **static pillars**
  (`evolvable: false`) — `Context.evolve((_) => Ontology.domains.entry(...))`
  silently produces nothing. They must be set at construction
  (`Context(domains: ...)`, `Context.fromEntries(...)`).
- `Ontology.constraints` **is** evolvable — the learning loop's home is safe.
- `Provenance.actor`, `Provenance.compliance`, `Provenance.sensitivity`,
  `Provenance.traceId` are static pillars on `PulseContext`; use
  `PulseContext.fromEntries([...])` to stamp them.
- `Provenance.confidence`, `Provenance.reason`, `Provenance.purpose`,
  `Provenance.strategy`, `Provenance.priority`, `Provenance.auditLevel` are
  evolvable.

`test/helpers/fixtures.dart` encodes all of this; Phase 1's policy factories
must read contexts through the getters (which resolve the parent chain),
never assume an entry was applied via `evolve`.

## `cell` bugs blocking cell_mind

(None as of Phase 0. F1's replace semantics is a documented contract, not a
bug.)

## Deferred / mitigated

| Item | Phase | Status |
|---|---|---|
| `Context.merge` for multi-agent learned contexts | 1.1 (post-1.0) | Design open question Q5; `DeputyContext` composition is the 1.0 path |
| Persistent decision log (disk) | post-1.0 | `maxDecisions` rolling cap ships in Phase 2 |
| `Pulse.batch` raw-return typing | — | worked around in F12; upstream `cell` polish item |

## Verification report (Phase 0, Day 5)

```bash
dart pub get                                          # ok
dart analyze --fatal-infos --fatal-warnings           # No issues found
dart format --set-exit-if-changed lib/ test/          # exit 0
dart test test/fitness/ -r expanded                   # 16/16 pass
dart run benchmark/micro/policy_cost.dart             # prints "Phase 1"
```

Tier 1: all green. **Phase 0 verdict: PROCEED.**

## Phase 1 findings

### P1 — `domainPolicy` fail-closed default

The Phase-1 design (D2) tightened the Brain-Storm draft: a tagged acceptor
rejects untagged pulses by default (`allowUntagged = false`). Chaining
`requiresDomainPolicy()` enforces *both-sides-tagged*; it is not the
untagged-gap closer anymore. Pinned by `test/policy/domain_test.dart`.

### P2 — `Mandate.authority` has no public getter

`cell` 1.1.0 stores authority as a `Mandate` dimension but exposes no
getter on `DeputyContext`. `cell_mind` reads it through the context index
operator: `context[Mandate.authority]`.

### P3 — `predicatePolicy` signature

Dart function subtyping requires a function to declare every named
parameter of its target type — so the predicate signature is the Plan.md
one (`{required Cell host}` only). Predicates needing `ApplyArguments`
must write a `TestCell` directly (documented in `guide/01-Policies.md`
§2.13).

### P4 — `TestCell.allowAll` is `TestCell<Never>`

The substrate's allow-all singleton cannot be called with a typed host,
so it is excluded from `cell_mind`'s composition algebra (the rc.9-era
plan's `allowAll + X == X` test is inapplicable).

### P5 — `policy_export.dart` omitted

The single-library barrel includes `src/policy.dart` directly as a part;
there is nothing for a re-export file to do.

### P6 — Provenance mismatch throws (loudly)

`_originDomains` throws `StateError` on pulse-claim vs. source-cell
mismatch. `StateError` is an `Error`, so `TestCell.call` does *not*
swallow it into a rejection — the mismatch propagates as a caller bug,
by design.

## Verification report (Phase 1)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/policy/ -r expanded              # 119/119 pass
dart test                                       # 135/135 pass (incl. fitness)
dart run example/01_hello_policy.dart           # expected output
dart run benchmark/micro/policy_cost.dart       # prints ns/decision table
wc -l guide/01-Policies.md                      # 632 lines (≥ 600)
```

## Phase 2 findings

### R1 — No receptor wrapper: `Cell.deputy` is the view

`cell._nucleus` is library-private, so the plan's
`Nucleus.evolve(cell._nucleus, ...)` sketch is impossible cross-package.
The live public path — `cell.deputy(testRule: recorder)` — chains
`[principalRule, recorder]`, inherits the principal's context
(`DeputyContext.system` → null), and shares container/lock/bind.
Consequences (all documented and tested):

- the principal rule evaluates twice on the deputy path (pure rules);
- principal rejections drop before the recorder — `principal-rejected`
  is only produced when the recorder runs standalone;
- `cognitive()` is synchronous and fails loudly on a Future-returning
  `deputy()`.

### R2 — The recorder widens `host` and forwards the principal

The deputy chain passes the generic `_Cell` deputy as host; a
`covariant C? host` override would throw for every `ValueCell`
principal. The recorder declares `Cell? host`, evaluates the principal
rule with the principal (`ValueCell` covariant check satisfied), and
the policy with the view.

### R3 — Argument evaluations are enforcement-only

`TestCell` validates each action argument through the same chain. The
recorder skips silent recording for passing argument evaluations and
attributes a rejection there to the command. Without this, every
positional argument would duplicate the log entry; without the
rejection attribution, an argument-rejected apply would leave no
record (short-circuit).

### R4 — `Decision.command.compensation` is always null

The `TestCell` dispatch forwards `(function, arguments)`, not the full
`ApplyCommand`. Documented on `Decision`.

### R5 — Outcome channel double-wraps

`IngressHandle<Pulse>.emit` wraps the outcome pulse. Contract: entry
payload = outcome `Pulse` (`type: 'mind.outcome'`), whose payload is
the reward map. Observers unwrap once.

### R6 — Link decisions appear in the log

Observing the cognitive view (or any cell construction linking to it)
records a link decision. Tests filter by `pulse`/`command` shape;
`guide/02-Runtime.md` §12 tabulates the four shapes.

## Verification report (Phase 2)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/runtime/ -r expanded             # 50/50 pass
dart test                                       # 184/184 pass (fitness+policy+runtime)
dart run example/02_authority_deputy.dart       # authority log walkthrough
dart run example/03_decision_log.dart           # log query + reward walkthrough
dart run benchmark/micro/recording_cost.dart    # ns/apply table
wc -l guide/02-Runtime.md                       # 616 lines (≥ 600)
wc -l guide/04-Determinism.md                   # 315 lines (≥ 300)
```

### R7 — Recording overhead is dominated by the TissueList write

Phase 2's microbenchmark on the dev machine: bare apply ≈ 3.2 µs,
cognitive apply ≈ 228 µs. Profiling shows `TissueList.add` (forensic
tracing) ≈ 40 µs/entry — the dominant cost, not policy evaluation or
`Decision` construction (`Identity.next` ≈ 0.9 µs, clock ≈ 0.1 µs).
The plan's ≤3× target applies to CI-recorded baselines; local numbers
are informational. Options for later phases: a dedicated append-only
recording structure, or batching log writes. Deferred.

## Phase 3 findings

### L1 — `EffectJournal` has no `now()` / `record(...)`

The plan's `journal.now()` and `journal.record(...)` do not exist in
`cell` 1.1.0. Adaptations: `trainedAt = journal.clock()`; training and
pruning runs are recorded as `journal.io(...)` effects with labels
`mind.training` / `mind.pruning` and serialized outputs. Replay consumes
the same effect sequence (fixed order: clock → pruning → training).

### L2 — The context vector includes pulse provenance

`when` blocks contain `actor` (and `strategy`/`purpose` when present).
Learned rules are therefore actor-specific by default; generalizing
across actors requires a stable producer-class actor value. Pinned by
tests.

### L3 — Replay restores epochs in local time

`ReplayJournal.clock()` returns
`DateTime.fromMillisecondsSinceEpoch(...)` — local. Direct `DateTime ==`
between the recorded UTC and replayed local values fails despite equal
instants; determinism tests compare `.toUtc()`.

### L4 — Map equality is identity, not deep

Learned-rule tests must use field-wise predicates or the `equals`
matcher when comparing `when` maps (Dart map `==` is identity-based).
A recurring test-writing trap; not an API issue.

## Verification report (Phase 3)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/learning/ -r expanded            # 48/48 pass
dart test                                       # 232/232 pass (all modules)
dart run example/04_learning_loop.dart          # record → train → deploy
dart run benchmark/micro/training_cost.dart     # decisions/s at 100/1k/10k
wc -l guide/03-Learning.md                      # 606 lines (≥ 600)
```

## Phase 4 findings

### A1 — Async rules are evaluated twice per pulse with distinct objects

The substrate's receptor validates an async rule once in the base
entry and once in the async drain, using different pulse objects.
Per-evaluation futures diverge (two submissions, wave never resumes);
identity/lineage cache keys all miss. Adaptation: wave-honest Defer —
record `Defer`, drop the wave, resolve out-of-band, record the
resolution as a linked follow-up decision. Details in
`_phase4_verdict.md` and `guide/05-Approval.md` §3.2.

### A2 — `EffectJournal.timer` is un-cancellable

The sweeper uses a cancellable `dart:async` Timer; expirations remain
journaled explicitly (`mind.approval.expired`).

### A3 — `StateError` is an `Error`, not an `Exception`

Resolver `catchError` must catch any throwable; failures record
`defer-resolver-failed` with the error text.

### A4 — Static generic method call syntax

`Class<T>.fromMap(...)` does not resolve for a static method with its
own type parameter; use `Class.fromMap<T>(...)`.

### A5 — `TissueMap` gating uses `TestTissue`

`TissueMap(properties: TissueMapNucleus(testRule: TestTissue(...)))`.

### A6 — Pinned matcher has no `completes(...)`

Use `completion(...)` (matcher 0.12.x).

### A7 — Deferral audit is a decision pair

`Defer` request + resolution decision linked via
`annotations['decisionId']`; filters must expect two entries.

## Verification report (Phase 4)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/approval/                        # 59/59 pass
dart test                                       # 291/291 pass (all modules)
dart run example/05_approval_defer.dart         # Defer → approve → reject
dart run benchmark/micro/approval_roundtrip.dart # ~1.1k–2.5k round-trips/s
wc -l guide/05-Approval.md                      # 501 lines (≥ 500)
```

## Phase 5 findings

### B1 — `PulseContext.aiInference` does not exist

Bridge contexts compose `Provenance` entries via
`PulseContext.fromEntries(entries, parent: baseContext)`.

### B2 — Replay clocks truncate to milliseconds

Effect `at` fields truncate via `_isoAt`, or re-created maps never
fingerprint-match recorded inputs. Wall-clock durations in effects
also diverge — the router derives `duration` from journal clocks.

### B3 — `Future<Never>.catchError` handlers must return `Never`

Throwing `async` tools infer `Future<Never>`; use `.then<void>` for
swallowed fire-and-forget errors.

### B4 — `Pulse.evolve(pulse: X)` replaces the payload with X

The plan's evolve-based result pulses would nest pulses and lose the
type; the router emits fresh governed pulses.

### B5 — The pinned matcher has no `completes(...)`; the name also
clashes with the bridge's `completion(...)`

Bridge tests hide the matcher import.

### B6 — `Cell.asyncMap` passes payloads, not pulses; `exhaust` drops

The router sources pulses as payloads; in-flight arrivals drop (not
queued). Both documented in `guide/06-Bridges.md` §5.4.

## Verification report (Phase 5)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/bridge/                          # 54/54 pass
dart test                                       # 345/345 pass (all modules)
dart run example/06_llm_bridge.dart             # completion + router + stream
dart run benchmark/micro/bridge_cost.dart       # ~2.8k–3.9k governed ops/s
wc -l guide/06-Bridges.md                       # 472 lines (≥ 450)
```

## Phase 6 findings

### C1 — The plan's Phase 2 receptor fix is unnecessary here

The live `cognitive()` uses `cell.deputy(testRule: recorder)` — pulses
through the cognitive view ARE recorded (pinned by
`receptor_fix_test.dart`). `Nucleus`/`Receptor` are library-private;
the rc.9-era fix path does not exist. No runtime change shipped.

### C2 — Plain-cell deputies are not emittable

`agent.agentView` is not an `OpenCell` — debate questions route
through `AgentSpec.routeIn` (the source ingress).

### C3 — The plain-cell deputy path accepts unrelated mandates

The causal-integrity throw was not observed for unrelated
`DeputyContext`s; documented leniency.

### C4 — A pulse completes at its first terminal

Debates ingest once per shared source and never re-route; stateless
agents make round 2 moot (single-round voting).

### C5 — Agent training uses plain `Context`s

`TrainedPolicy.applyTo` writes `Ontology.constraints`; deputy contexts
do not expose that pillar.

### C6 — `Verdict.type` added

`accept`/`reject`/`defer` discriminants for narratives and spans.

## Verification report (Phase 6)

```bash
dart analyze --fatal-infos --fatal-warnings     # No issues found
dart format --set-exit-if-changed lib/ test/ example/ benchmark/  # exit 0
dart test test/xai/ test/agent/ test/runtime/receptor_fix_test.dart  # 48/48
dart test                                       # 393/393 pass (all modules)
dart run example/07_multi_agent.dart            # spawn → vote → learn
dart run example/08_xai_audit.dart              # narratives + spans
dart run benchmark/micro/xai_cost.dart          # narrative/span cost
dart run benchmark/micro/spawn_cost.dart        # agent construction cost
wc -l guide/07-XAI.md guide/08-Agents.md        # 416 / 421 (each ≥ 400)
```
