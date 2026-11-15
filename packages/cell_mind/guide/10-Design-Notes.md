# Design Notes — cell_mind

*A durable record of why every primitive exists, what the nine principles
constrain, and what Phase 0 discovered about the substrate.*

---

## The eleven principles

Every module in `cell_mind` is measured against these nine rules. When a
review question starts with "why can't we just …", the answer is one of
these principles.

### P1 — Nothing new in the runtime

`cell_mind` introduces **vocabulary**, not **mechanism**. Every primitive is
a composition of `Cell`, `TestCell`, `Pulse`, `Context`, `Mandate`,
`Ontology`, `Provenance`, `ApplyCommand`, and `EffectJournal`.

**Enables:** policies are `TestCell`s; the decision log is a `TissueList`;
the outcome channel is a `Cell`; the learner's output is an evolved
`Context`. Anything a user already knows how to observe, replay, or
transact on applies unchanged.

**Forbids:** a second event loop, a second scheduler, a private message
bus, or a `MindEngine` class that owns pulses. The moment `cell_mind` ships
its own runtime, provenance chains break: a pulse would have to know about
two dispatch systems.

**Phase 0 verification:** F2 (short-circuit), F4 (TissueList observation),
F7 (pulse context through `apply`), F12 (all pulse subtypes flow through
`Cell.ingress`).

### P2 — Provenance is mandatory

Every decision — including rejections — carries a record with the active
`Context` and its `version`. There are no anonymous decisions.

**Enables:** the audit story. A rejected pulse is as important as an
accepted one: it tells the trainer *which contexts are being blocked and
why*. An `ApplyReceipt` on approval actions gives HITL an audit trail.

**Forbids:** policies that return bare `bool` with no record of what was
checked. `cell_mind` policies are still `TestCell`s (P1), but the *runtime*
layer around them records the verdict, the context version, and the
evaluation time.

**Phase 0 verification:** F5 (receipt accuracy — but see the semantic
shift in §Discovered constraints), F7 (context survival).

### P3 — Governance is a gate, not a hook

`Context`-derived policies are `TestCell`s. They accept or reject. There
are no "on-rejection" callbacks that user code must remember to invoke.

**Enables:** composition. Two gates compose with `+` into one gate. A
policy that fires a callback on rejection cannot compose — the callback
ordering becomes part of the contract.

**Forbids:** `policy.onReject(...)`, side-effectful rejection paths inside
the policy layer, and "advisory" policies that log and pass. If you want a
log, that is the *runtime's* job (the decision log records the rejection);
the policy only decides.

**Phase 0 verification:** F2 — `TestCell.chain` short-circuits, so a
composite policy is an AND gate with deterministic evaluation order.

### P4 — Fail closed

Missing confidence → reject. Missing compliance → reject. Unknown verb →
reject. If a check cannot decide, it rejects. Every policy has an explicit
`allowMissing` flag for teams that opt out — but the default is denial.

**Enables:** safe defaults under partial metadata. Real systems carry
pulses with sparse provenance (`PulseContext.system` has nothing); a
permissive default silently disables the policy.

**Forbids:** policies that return `true` on missing metadata, "warn and
pass" behavior, and null-tolerant threshold checks (`(x ?? 0) >= min` is a
violation unless `allowMissing` is set).

**Phase 0 verification:** F11 — the framework's own defaults
(`PulseContext.systemInternal`) are complete, so fail-closed policies have
a well-defined substrate; where the substrate *is* sparse (plain `Pulse`),
fail-closed is exactly the behavior that protects the system.

### P5 — Learning is offline

No online gradient descent, no in-band updates. The trainer runs as a batch
job over the decision log. Runtime replay uses the `Context` version active
at decision time — determinism preserved.

**Enables:** replayable, auditable learning. The training run itself is an
effect (journaled). The learned artifact is a plain `Context` — diffable,
reviewable, and rollback-able.

**Forbids:** policies that mutate their own weights, runtime calls into a
trainer, and any learned rule that is applied *during* the run that
produced it.

**Phase 0 verification:** F8 — the `EffectJournal` boundary reproduces
recorded observations byte-for-byte; this is the machinery that makes
offline training runs replayable.

### P6 — Learned policy lives in `Ontology.constraints`

`Context.evolve` is attenuation-only for structural fields, but
`Ontology.constraints` is `evolvable: true` — a `Map<String, dynamic>` that
participates in the attenuation contract. That is where accumulated policy
lives: `Ontology.constraints['cell_mind.policy']`.

**Enables:** versioned, diffable, auditable learning. A training run is a
constraint-map diff; deployment is a `Context` swap; rollback is deploying
the previous `Context`.

**Forbids:** side tables (`TissueMap` of learned rules), side files, or a
custom `LearnedPolicyStore`. All three lose the attenuation contract and
the diffable audit trail.

**Phase 0 verification:** F1 — this is the riskiest contract in the whole
project, and it holds, with one sharp edge: replace-not-merge (see
§Discovered constraints).

### P7 — Effectful primitives require journals

Every `cell_mind` primitive that could produce an effect (trainer runs,
decision-log persistence, bridge transports) takes
`required EffectJournal journal`. There is no default. If you don't have a
journal, you don't get to use the primitive.

**Enables:** the determinism guarantee from P5. An effect without a journal
is a replay landmine.

**Forbids:** convenience overloads that default to a `NullJournal`, silent
no-op journals, and "best-effort" effect paths that swallow journal
failures. `NullJournal` fails loudly by design; `cell_mind` respects that.

**Phase 0 verification:** F8 — recording and replay journals round-trip;
the test also proves the replay side *does not run* the live closure.

### P8 — Every primitive declares its purity

- `policy` → `Purity.pure` (stateless `TestCell`s).
- `runtime` decision log → `Purity.readOnlyExternal` (observability).
- `learning` → `Purity.effectful` (writes a new `Context`).
- `bridge` → `Purity.effectful` (touches the outside world).

**Enables:** the replay engine's dispatch. `CellGraph` uses purity to decide
whether a cell participates in an exactly-replayable graph, a
journal-replayable graph, or only an effect-log-replayable path.

**Forbids:** a policy that reads the clock but declares `pure`
(`notOlderThan` declares `readOnlyExternal` and requires a clock), and a
recording wrapper that pretends to be `pure` while writing to a
`TissueList` (the recording happens in the receptor wrapper, which is
`readOnlyExternal`).

**Phase 0 verification:** F8 and F9 exercise the two purity-relevant
substrate mechanisms (journal boundary and TTL timers).

### P9 — Two modes, clearly separated

- **Static mode (preferred):** policy composed into a cell's `testRule` at
  construction. Pulses and `apply` are both governed by the standard
  receptor pipeline — no wrapper, no double-validation.
- **Dynamic mode (retrofit):** `cognitive(cell:, policy:)` layers a policy
  at runtime via a receptor wrapper. Both are governed, at the cost of
  double-validating the principal's rule and losing the concrete cell
  subtype on the cognitive view.

**Enables:** one policy vocabulary for greenfield and brownfield cells.

**Forbids:** pretending dynamic mode is free. The double-validation cost is
benchmarked (`benchmark/micro/recording_cost.dart`), and the guides say
"static for new code, dynamic for retrofit and for the decision log".

**Phase 0 verification:** F6 (deputy state sharing — the mechanism dynamic
mode builds on) and F7 (pulse round-trip through `apply`).

### P10 — Prompted verdicts memoize by content, not by identity (Phase 8/9)

- The verdict cache key is the sha256 of
  `(config.id | version | cell-context-fp | pulse-context-fp |
  decision-fp | session-fp)`; the prompt cache key is the sha256 of
  `(config.id | version | sha256(renderedPrompt))`. Identical content
  ⇒ identical key ⇒ identical verdict, across processes and time.
- Fingerprints cover exactly the dimensions the renderer emits
  (`traceId` included; pulse timestamps never rendered or hashed), so
  cache identity and prompt determinism cannot drift apart.
- `config.version` participates in every key — bumping a version is a
  deliberate, total invalidation; there is no accidental staleness
  path.

**Enables:** repeat decisions at ~5 µs (verdict-cache hit) instead of
a network round-trip; A/B testing via versioned registry keys.

**Forbids:** wall-clock timestamps in cache keys; identity-based
`==` on keys; serving a prompt-cache entry when the verdict cache
already answered (the tiers are strictly ordered).

### P11 — A conversation is journal state, not ambient state (Phase 8/9)

- Sessions are per-decision accumulators of `(user, assistant)` pairs
  with content-only fingerprints; empty sessions fingerprint `''` —
  stateless and empty-session decisions share keys and prompt layout.
- Every session mutation is a journal effect (`init`, `append`,
  `clear`, `compact`); compaction drops whole pairs only, never a
  partial turn.
- Cache population follows D14 order: append first, then store under
  the **post-append** key — a repeat decision hits the cache and does
  not create a new turn.

**Enables:** multi-turn chat, cross-policy shared windows, and replay
that reconstructs the exact conversation without re-invoking the LLM.

**Forbids:** timestamped fingerprints, partial-pair compaction, cache
stores under the pre-append key.

---

## How the principles constrain the API

Each principle is visible in concrete API shapes. This section is the
checklist used in every phase review.

| Principle | API shape it enables | API shape it forbids |
|---|---|---|
| P1 | `typedef Policy = TestCell<Cell>` | `class MindEngine` with its own dispatch |
| P2 | `Decision { contextVersion, verdict, pulse, command }` | bare-bool policy returns without records |
| P3 | policies compose with `+` / `TestCell.chain` | `onReject` callbacks in policy factories |
| P4 | `allowMissing` named flags, default `false` | null-tolerant acceptance defaults |
| P5 | `Future<TrainedPolicy> train({...})` batch API | `policy.update(...)` online APIs |
| P6 | learned block at `Ontology.constraints['cell_mind.policy']` | `TissueMap`-backed rule stores |
| P7 | `required EffectJournal journal` on effectful APIs | defaulted journals / no-journal overloads |
| P8 | purity declared per module and documented | clock-reading policies declared `pure` |
| P9 | `cognitive(...)` + `testRule: contextAware()` | silent automatic wrapping of every cell |
| P10 | `promptedPolicyWith(config:, prompt:, journal:)` + `VerdictCache` | timestamped cache keys, identity-based key equality |
| P11 | `PromptSession` + `SessionMode` + journaled session effects | partial-turn compaction, ambient conversation state |

### The static-mode contract

```dart
final gate = Cell.ingress<Payload>(
  context: Context(domains: 'finance'),
  testRule: domainPolicy(),            // P1: it's just a TestCell
);
```

`gate.emit(...)` runs the policy on every pulse; `gate.cell.apply(...)`
runs it on every command. No extra machinery. The only `cell_mind`-specific
knowledge the user needs is the factory name.

### The dynamic-mode contract

```dart
final handle = cognitive(
  cell: existing.cell,
  policy: requiresDomainPolicy() + domainPolicy(),
);
// Route traffic through handle.cognitive — pulses AND apply are governed.
```

The handle adds: a `TissueList<Decision>` log (P2), an outcome channel for
learning (P5), a bounded log (`maxDecisions`), and fail-closed `Defer`
resolution. The price: the principal's rule runs twice on accept, and
`handle.cognitive` is typed `Cell`, not the concrete subtype.

### The learning contract

```dart
final trained = await trainOffline(
  handle: handle,
  baseContext: handle.cell.context,
  reward: (decision, outcome) => outcome.payload is Success ? 1.0 : -1.0,
  trainer: contextualBandit(),
  journal: journal,                    // P7: no journal, no training
);
final redeployed = Cell.ingress<T>(
  context: trained.context,            // P6: learned block inside constraints
  testRule: contextAware(),
);
```

### What "Context accumulation" means, precisely

`Ontology.constraints` is a `Map<String, dynamic>` keyed dimension.
`Context.evolve` with a non-null resolver **replaces** the map for that
dimension and links the parent (see F1). Therefore accumulation is a
two-step operation:

1. Read the current constraints (`baseContext.constraints ?? {}`).
2. Merge the new rules into the `cell_mind.policy` sub-block.
3. Evolve once with the fully merged map.

The trainer owns step 2. Nothing else writes `cell_mind.policy`.

---

## Discovered constraints (from Phase 0)

Phase 0 exists to discover what `cell` *actually does*, not what its
documentation says. These findings are load-bearing for later phases.

### D1 — `Context.evolve` replaces, never merges

Verified by F1. The trainer must merge before evolving
(`_accumulate` helper). Static-pillar dims are simply not evolvable — see D2.

### D2 — Static pillars vs. fluid boundaries

In `cell` 1.1.0 the plan's assumption "every dimension is evolvable" is
wrong:

| Dimension | Evolvable | Set via |
|---|---|---|
| `Ontology.domains` | no | `Context(domains: ...)` / `fromEntries` |
| `Ontology.version` | no | constructor |
| `Ontology.taxonomy` / `topology` / `dataSources` | no | constructor |
| `Ontology.constraints` | **yes** | `evolve` or constructor |
| `Ontology.compliance` / `subDomains` / `stakeholders` / `isNot` / `partOf` / `type` / `identity` | yes | `evolve` or constructor |
| `Provenance.actor` / `compliance` / `sensitivity` / `traceId` / `parentTraceId` / `integrity` | no | `PulseContext.fromEntries` |
| `Provenance.reason` / `purpose` / `strategy` / `confidence` / `priority` / `auditLevel` | yes | `evolve` or `fromEntries` |
| `Mandate.role` / `version` | no | `DeputyContext` constructor |
| `Mandate.authority` / `isolation` / `clearance` / `sovereignty` / `auditLevel` / `justification` / `constraints` | yes | `DeputyContext` constructor / `evolve` |

Consequence for policies: **always read through the getters**
(`context.domains`, `pulse.context.confidence`), never assume an entry was
locally applied. The getters resolve the prototype chain; local-map peeking
does not exist in the public API anyway.

Consequence for fixtures and tests: build contexts with the right
mechanism per dimension (`test/helpers/fixtures.dart` encodes the table).

### D3 — `ApplyReceipt.vetted` means manifest membership

In `cell` 1.1.0, `vetted = modifiable.contains(command.function)`. It does
**not** mean "the integrity gate ran" — the gate runs on every `apply`
regardless. Phase 2's decision recording must map:

- `ApplyAccepted` + `vetted: true` → command was a declared capability.
- `ApplyAccepted` + `vetted: false` → gate accepted a non-manifest command.
- `ApplyRejected` → gate rejected.

The rc.9-era plan's F5 expectation (`ingress.apply` → `vetted: true`) is
outdated; the fitness test pins the live contract.

### D4 — `Pulse.governed` and `Pulse.batch` typing quirks

- The correct Dart 3 call syntax is `Pulse<int>.governed(...)`; the
  rc.9-era `Pulse.governed<int>(...)` spelling does not compile.
- `CollectivePulse<int>` implements `Pulse<Iterable<Pulse<int>>>` — a batch
  of ints is **not** a `Pulse<int>`. Policies that inspect payloads must
  handle the bundle shape.
- `Pulse.batch` returns the raw `Pulse` type; typed code needs an explicit
  cast.

### D5 — TTL is an inactivity window

`EphemeralPolicy.duration` arms on first interaction and restarts on every
interaction. A "hard deadline" approval TTL must be implemented by the
Phase 4 sweeper itself (a timer started at `submit`), not by reusing
`EphemeralPolicy` semantics unthinkingly.

### D6 — Replay spelling

There is no `JournalScope.replay(...)` in `cell` 1.1.0. Replay is:

```dart
final replay = ReplayJournal(
  recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
);
await JournalScope.run(replay, () => ...);
```

### D7 — Deputy sharing is behavioural, not structural

`deputy._nucleus` is library-private in `cell`; cross-package code cannot
probe it. Sharing is proven behaviourally: the deputy's synapses receive
the principal's transitions (F6). Dynamic mode leans on this — the
cognitive cell and the principal must see the same waves.

### D8 — Journal clocks store millis; derive durations from millis (Phase 9)

`RecordingJournal.clock()` returns microsecond wall-clock time, but
the clock *effect* stores epoch milliseconds — and replay restores
exactly the millis. Any duration computed by subtracting two
`clock()` return values can therefore disagree with the duration a
replay recomputes (floor of a sub-ms difference vs the ms-epoch
difference). `toolRouter`'s `_clockMs` truncates both instants to
milliseconds first (`_phase8_verdict.md` F9.6). New journal-driven
timing code must do the same.

### D9 — Replay requires the same config identity for prompted decisions

The prompted disposition's input is
`'${key.fingerprint}|${config.maxPromptChars}'` and the key includes
`config.id` — a recording and its replay must share the same config
instance (or identical id + version), or the first disposition
diverges loudly. This is intentional: cache identity and journal
identity are one hash.

---

## Mode analysis (static vs. dynamic)

A recurring review question: why ship dynamic mode at all if static mode is
preferred? The answer is three use cases static mode cannot serve:

1. **Retrofit.** An existing cell was built before a policy existed.
   Rebuilding every construction site is a migration, not a toggle.
2. **Decision log.** Static mode governs, but it does not *record*.
   Recording is the runtime layer's job; dynamic mode is the only way to
   add recording to a cell you don't own.
3. **Overlays.** A policy that changes per request context (e.g. a
   per-tenant policy resolved at the edge) is awkward to bake into a
   constructor.

Static mode remains preferred for new code because it has none of the
dynamic-mode costs:

| | Static | Dynamic |
|---|---|---|
| Governs pulses | yes | yes |
| Governs apply | yes | yes |
| Records decisions | no (until runtime layer) | yes |
| Double-validates principal rule | no | yes (documented) |
| Preserves concrete cell type | yes | no (`Cell` view) |
| Cycle-checker participation | standard | wrapper bypasses (inner receptor still checks) |
| Retrofit capability | no | yes |

The Phase 1 benchmarks measure the static-mode baseline
(`benchmark/micro/policy_cost.dart`); Phase 2 measures the dynamic tax
(`benchmark/micro/recording_cost.dart`).

---

## Deferred design questions (with current answers)

### Q1 — Where does learned policy live?

`Ontology.constraints['cell_mind.policy']`. Constraints is the only
evolvable map dimension; alternatives (`others`, custom dimensions) lose
the attenuation contract.

### Q2 — Is `Defer` in scope for the first release?

`Defer` ships with `approval` (Phase 4). Until then `Verdict` has `Accept`
and `Reject`; the sealed hierarchy is designed so the third variant is an
additive change.

### Q3 — Can the trainer remove rules?

Default no (accumulate-only — the Context grows monotonically). Opt-in via
`TrainingConfig.prune`; pruning is journaled as an effect.

### Q4 — Reward attribution

Reward is tied to `pulse.context.traceId` — the decision that originated
the causal chain. Downstream outcomes must carry the trace id; multi-hop
attribution is user policy via `pulse.lineage`.

### Q5 — Merging learned Contexts across agents

A *compose* operation, not an *evolve* (authority can only attenuate).
Deferred to post-1.0; v1.0 agents keep separate `Context`s and co-authorise
via `DeputyContext` chains.

---

## References

- Cell framework README — `packages/cell/README.md`
- Cell API barrel — `packages/cell/lib/cell.dart`
- Tissue API barrel — `packages/cell_tissue/lib/cell_tissue.dart`
- Phase plan — `research/Mind/Plan.md`
- Brainstorm (full design) — `research/Mind/Brain-Storm.md`
- Fitness suite — `test/fitness/cell_contract_test.dart`
- Known constraints — `KNOWN_ISSUES.md`

---

## Appendix A — Context versioning and replay

The decision log is only as good as the version stamps it carries.

### A.1 — What gets stamped

Every `Decision` records `contextVersion`, resolved at decision time from
`cell.context.version` (defaulting to `'0.0.0'` — "unversioned"). This is
the load-bearing field for replay:

- A decision made under version 2 was made against version 2's
  `Ontology.constraints['cell_mind.policy']`.
- Replaying it against version 3's constraints would silently change the
  verdict — the classic learning-on-learning instability (risk 5 in the
  plan).

### A.2 — The unversioned trap

`Context.system` and every context built without an explicit version
report `version == null` (getter) or `'0.0.0'` (decision stamp). A log
full of `'0.0.0'` stamps is not replayable across implementation changes —
the same signal the receptor `version` uses for its replay dispatch.

Consequence: teams that train in production must stamp their contexts.
The fixtures provide `ctxWithVersion(...)`; the guides repeat the rule:
**editing constraints without bumping `context.version` breaks replay.**

### A.3 — Version increments in the learning loop

Each training run emits `TrainedPolicy(context: evolved, ...)` where the
evolved context carries the merged `cell_mind.policy` block and a bumped
version. Rules inside the block carry their `trainedIn` version, so the
trainer can (opt-in) skip rules produced by the current version — the
feedback-loop guard.

### A.4 — Replay in three layers

| Layer | Mechanism | Guarantee |
|---|---|---|
| Pure policy evaluation | plain re-execution | exact (P8) |
| Clock/network-reading policy | `EffectJournal.clock()` / `.io()` | exact via recorded observations (F8) |
| Training run | journaled as an effect | effect-log replayable, not state-exact |

The fitness suite's F8 pins layer 2, which is the one `cell_mind` cannot
live without.

---

## Appendix B — Common review failures

A catalogue of shortcuts that violate a principle, and the principle they
break. Each one has been attempted in a review at least once.

### B.1 — "Just default the journal"

`cognitive(cell:, policy:, journal = NullJournal())` — breaks P7. The
NullJournal fails loudly by design; defaulting to it converts a loud
failure into a silent one the moment someone forgets the argument. The API
stays `required EffectJournal journal`.

### B.2 — "Record in the TestCell"

Putting `decisions.add(...)` inside the policy `TestCell` breaks P8 (a
`pure` rule with a side effect) and P3 (the gate now does logging work,
and the log writes happen even for evaluations that are not decisions).
Recording lives in the receptor wrapper, which is `readOnlyExternal`.

### B.3 — "Permissive by default, strict on request"

`domainPolicy()` accepting untagged pulses *is* in the design — but only
as the permissive base that `requiresDomainPolicy()` closes. The composite
default (`contextAware()`) is fail-closed. A factory whose *default* is
`allowMissing: true` breaks P4.

### B.4 — "Merge in evolve"

Assuming `evolve` deep-merges constraints breaks P6 as implemented —
D1 says it replaces. The merge helper is part of the trainer, tested by
Phase 3's `accumulation_test.dart`.

### B.5 — "The cognitive cell can be typed C"

Dynamic mode returns `Cell`, not `C` (design §9.3, P9 table). Attempts to
preserve `C` require private-cell access into `cell`. The guides redirect
ValueCell users to static mode.

### B.6 — "Use `EphemeralPolicy` for approval TTL"

`EphemeralPolicy` TTL restarts on interaction (D5) — an approval request
that keeps receiving observations would never expire. The approval queue
owns a one-shot sweeper timer per request instead.

### B.7 — "Check the gate ran via `vetted`"

`vetted` is manifest membership (D3), not gate execution. Audit code that
interprets it as gate execution will misreport non-manifest applies. Phase
2's recording maps the three receipt states explicitly.

---

## Appendix C — Decision shapes the modules consume

The exact information flow between the three layers, in one picture:

```
pulse ──► Policy (TestCell, pure) ──► bool ──► CognitiveReceptor
                                                   │
                              ┌────────────────────┤
                              │                    │
                        reject: drop          accept: inner receptor
                              │                    │
                              ▼                    ▼
                         Decision(Reject)     Decision(Accept)
                              │                    │
                              └────────┬───────────┘
                                       ▼
                              TissueList<Decision>
                                       │  (offline)
                                       ▼
                     Trainer joins decisions ⋈ outcomes
                                       │
                                       ▼
                     evolved Context.constraints['cell_mind.policy']
                                       │
                                       ▼
                     next runtime (static or dynamic deploy)
```

Four invariants hold at every step:

1. The policy never sees the log (P3).
2. The log always carries the context version active at decision time (P2).
3. The trainer only runs offline over the log (P5).
4. The learned artifact is a `Context`, not a model object (P6).

Any proposed feature that breaks one of these four arrows is out of scope
for v1.0 — it belongs in a different layer (`cell_flow` for orchestration,
`cell_organ` for the mesh) or a later version of `cell_mind`.

---

## Appendix D — What each later phase inherits from Phase 0

| Phase | Inherits | Fitness gate |
|---|---|---|
| 1 `policy` | F1 (constraints semantics), F2 (short-circuit), F3 (pulse context), D2 dimension table | F1–F3 |
| 2 `runtime` | F4 (TissueList), F5/D3 (receipts), F6 (deputy sharing), F7 (context through apply) | F1–F7 |
| 3 `learning` | F1/D1 (explicit merge), F8/D6 (journal replay), D2 | F1, F8 |
| 4 `approval` | F9/D5 (TTL semantics), F5 (receipt audit trail), transactions on ValueCell | F1–F9 |
| 5 `bridge` | F8 (journal boundary), F12/D4 (pulse subtypes), confidence policy from Phase 1 | F1–F12 |
| 6 `xai`/`agent` | F2 (composition), F6 (deputies), decisions from Phase 2, HITL from Phase 4 | all |

Phase 0's one-line summary for the record: **the substrate holds — with
replace-not-merge constraints, manifest-membership receipts, and static
pillars that must be read through getters rather than assumed evolvable.**


---

## Phase 1–6 constraint log (added in Phase 7)

This section completes the nine principles with the constraints the
phases *discovered* — each with the API shape it enabled, the shape
it forbade, and the test that verifies it.

### C1 — Policies are functions of provenance, never of payload

- **Rule:** a `Policy` may inspect the host context and the pulse's
  `PulseContext`; payload interpretation belongs to user code
  (`predicatePolicy`) or a `VerdictPolicy`.
- **Enables:** `domainPolicy`, `compliancePolicy`, `confidencePolicy`
  as pure, composable, testable factories.
- **Forbids:** payload-typed policy factories in the public surface.
- **Test:** `test/policy/pass_through_test.dart`.

### C2 — The recorder is a deputy, not a wrapper

- **Rule:** `cognitive()` builds `cell.deputy(testRule: recorder)`.
  The principal is untouched; recording only sees what the view sees.
- **Enables:** attribution per deputy view; multiple independent
  handles on one source (agents).
- **Forbids:** monkey-patching the principal's receptor; the rc.9-era
  `Nucleus.evolve`/`Receptor.clone` fix is unnecessary on the live
  substrate.
- **Test:** `test/runtime/receptor_fix_test.dart`.

### C3 — Learning is data, not state

- **Rule:** `TrainedPolicy` is a serializable block; `applyTo`
  returns a new `Context`. Training never mutates a live handle.
- **Enables:** portable, replay-deterministic training (recipe 13).
- **Forbids:** `TrainedPolicy` implementing `Context` (it would hide
  the evolve semantics).
- **Test:** `test/learning/determinism_test.dart`.

### C4 — Deferral is wave-honest

- **Rule:** a `Defer` verdict drops the pulse from the current wave;
  the resolver runs out-of-band and records a linked follow-up
  decision. The queue's `committed` cell is the delivery channel.
- **Enables:** human latency never blocks the reactive wave;
  `ApprovalQueue` pending state is fully observable.
- **Forbids:** re-injecting deferred pulses; awaiting `submit`
  before deciding (deadlock).
- **Test:** `test/approval/atomicity_test.dart`.

### C5 — Bridges are transport-agnostic and journaled

- **Rule:** `completion`/`toolRouter` take `Future` functions and
  journal every tool invocation as `mind.tool.call.<verb>` io effects.
- **Enables:** replay never re-invokes tools; four typed rejection
  classes with reasons.
- **Forbids:** an HTTP client inside `cell_mind`; unjournaled
  side-effectful bridges.
- **Test:** `test/bridge/journal_effects_test.dart`.

### C6 — Debates are single-round by construction

- **Rule:** agents are stateless between rounds and the substrate
  completes a pulse at its first terminal — re-routing cannot change
  a vote.
- **Enables:** `debate` with honest `rounds` accounting and
  journaled `MindDebateEffect`.
- **Forbids:** multi-round argument exchange in v1.0 (roadmap v1.1).
- **Test:** `test/agent/debate_test.dart`.

### C7 — XAI projects, never re-derives

- **Rule:** narratives and spans render the recorded `Decision`
  only; missing provenance is elided, never invented.
- **Enables:** `DecisionPath` as a stateless projection; `audit`/
  `ui`/`debug` templates pinned by tests.
- **Forbids:** model introspection claims; guessing reasons.
- **Test:** `test/xai/narrative_test.dart`.

### C8 — Cross-library boundaries are typed by gate kinds

- **Rule:** plain `cell` cells accept `TestCell` gates; organ stems
  accept `TestStem` gates. `cognitive()` must not cast one into the
  other (0.6.1 hotfix removed the crash; the deputy-host limitation
  is documented).
- **Enables:** ingress-hosted cognitive handles beside blends
  (recipes 10/11).
- **Forbids:** claiming organ stems host recorders in v1.0.
- **Test:** `test/integration/cross_library_test.dart`.
