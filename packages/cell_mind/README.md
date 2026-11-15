# cell_mind

**Cognitive policy for Cell — Context-aware decisions at runtime, Context
accumulation via learning, no new runtime.**

`cell_mind` is the cognitive layer of the Mitosis framework. It turns
`cell`'s typed governance metadata — `Context`, `Mandate`, `Provenance`,
`Ontology` — into autonomous runtime decisions, and it closes the loop by
letting those decisions accumulate back into `Context` through offline
reinforcement learning.

## What it enables

1. **Context-aware receptors.** A `TestCell` that reads `Ontology.domains`
   on the incoming pulse and the receiving cell, and accepts only when they
   intersect. Every pulse passes through a policy that knows *who is talking
   to whom about what*.
2. **Context-aware authority.** A `TestCell` that reads `Mandate.authority`
   from the cell's `Context` and accepts action commands only within the
   declared verb whitelist.
3. **Context-aware sensing and actuation.** A `Cell.ingress` or `Cell.state`
   whose `testRule` composes domain, compliance, clearance, isolation, and
   confidence policies.
4. **Context accumulation via learning.** An offline trainer reads a
   decision log (accept/reject/outcome), computes rewards, and produces an
   *evolved `Context`* whose `Ontology.constraints['cell_mind.policy']`
   carries learned rules. `Context` expands — typed and auditable — at each
   training cycle.

## Status

`0.6.0` — **Phase 6 (xai + agent) complete.** The v1 surface is
whole: policies, runtime recording, learning, approval, bridges,
explanations, and multi-agent orchestration. 393 tests pass.
`publish_to: none` remains until Phase 7 (stabilization).

The phase plan lives in `research/Mind/`:

| Phase | Ships |
|---|---|
| 0 | Fitness verification + repo scaffolding ✅ |
| 1 | Stateless `Policy` factories (`domainPolicy`, `authorityPolicy`, …) ✅ |
| 2 | `CognitiveHandle`, `Decision` log, receptor wrapper ✅ |
| 3 | `Trainer` (contextual bandit), `TrainedPolicy` ✅ |
| 4 | `ApprovalQueue` — HITL as a `Defer` resolver ✅ |
| 5 | `completion` + `toolRouter` bridges ✅ |
| 6 | `DecisionPath` (XAI) + `AgentRuntime` (multi-agent) ✅ |

## The XAI module (0.6.0)

```dart
final path = explainPulse(pulse, handle);
print(path!.toNarrative());                    // audit / ui / debug
final paths = explainSource(cell, handle);      // filter by emitter
otelSpans(handle.decisions, tracer: myAdapter); // OTel-compatible spans
```

- `DecisionPath` — read-only projection with derived provenance
  accessors.
- Three narrative templates (`audit`, `ui`, `debug`).
- `Tracer`/`Span`/`SpanContext` abstractions — no OTel SDK
  dependency; wrap yours in ~20 lines.

## The agent module (0.6.0)

```dart
final agent = await spawn(
  AgentSpec(
    name: 'Risk',
    cell: source.cell,
    mandate: DeputyContext(baseContext: ctx, authority: 'agent-Risk'),
    routeIn: (p) => source.ingest(p as Pulse<int>),
  ),
  journal: journal,
);
final outcome = await debate(
  participants: agents,
  question: purchasePulse,
  journal: journal,
);
```

- `AgentSpec` / `spawn` / `AgentRuntime` — deputy-scoped cognitive
  agents with isolated traces, outcomes, and learning loops.
- `debate` — single-round majority voting with journaled
  `MindDebateEffect` outcomes.
- Phase 2 recording claims pinned (`receptor_fix_test.dart`).

```dart
dart run example/07_multi_agent.dart   # spawn → vote → learn
dart run example/08_xai_audit.dart     # narratives + spans
```

See `guide/07-XAI.md`, `guide/08-Agents.md`, and
`_phase6_verdict.md` for the substrate findings.

## The bridge module (0.5.0)

```dart
final answer = completion(
  future: client.chat(prompt),      // transport is user code
  actor: 'openai-gpt4',
  prompt: prompt,
  confidence: 0.9,                  // required — governed calls only
  journal: journal,
);
final handle = cognitive(cell: answer, policy: confidencePolicy(min: 0.85));

final inbound = Cell.ingress<Pulse>();
final router = toolRouter(
  source: inbound.cell,             // pulses with {verb, args} payloads
  tools: {'fetch_user': (args) async => ...},
  actor: 'llm',
  journal: journal,
  minConfidence: 0.8,
);
Cell.observe(source: router, effect: (Pulse p) {
  final inner = p.payload as Pulse; // unwrap once
  print('${inner.type}: ${inner.payload}');
});
```

- `completion(...)` — single-shot `Future<String>` → governed cell;
  typed error pulses; confidence flows through provenance.
- `streamCompletion(...)` / `streamChunks(...)` — per-token governed
  pulses with opt-in lossless buffering.
- `toolRouter(...)` — closed-verb dispatch, await-by-default,
  `fireAndForget` opt-in, four rejection classes as distinct pulse
  types, journaled tool invocations (replay never re-runs tools).
- Seven typed, versioned journal effects + `bridgeEffectFromMap`.

```dart
dart run example/06_llm_bridge.dart    # completion + router + streaming
```

See `guide/06-Bridges.md` for the full reference and
`_phase5_verdict.md` for the substrate findings.

## The approval module (0.4.0)

```dart
final queue = ApprovalQueue<int>(journal: journal, ttl: Duration(minutes: 5));
final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),                       // bool slot (Phase 1–3)
  verdictPolicy: verdictPolicy((object, {required host, arguments}) {
    if (object is! Pulse) return const Accept();
    return object.payload > 1000
        ? const Defer('approval', {'reason': 'large-amount'})
        : const Accept();
  }) + learnedVerdictPolicy(),                 // verdict slot (defer rules)
  onDeferred: approvalResolver(queue),
);

// The deferred pulse is recorded as a Defer decision and dropped from
// the wave (human latency never blocks a gate). A reviewer then:
await queue.approve(queue.pending.keys.first);
// → commits the value to queue.committed and records an
//   Accept({'deferredBy': 'approval', 'decisionId': ...}) decision.
```

- `VerdictPolicy` / `verdictPolicy()` — full-verdict rules with
  `+` composition (short-circuit on Accept/Reject; Defer propagates).
- `learnedVerdictPolicy()` — honours learned
  `accept`/`reject`/`defer` rules; `learnedPolicy()` stays bool-only.
- `ApprovalQueue<T>` — `TissueMap` pending + `ValueCell<T?>`
  committed; `Cell.txApply` atomic approve/reject; TTL sweeper;
  `mind.approval.*` journal effects; disposal completes pending.
- `approvalResolver(queue)` — routes `Defer('approval')` to the queue.
- Wave-honest Defer: request + resolution recorded as a linked
  decision pair — the complete "who asked / who answered" audit trail.

```dart
dart run example/05_approval_defer.dart   # Defer → approve → reject
```

See `guide/05-Approval.md` for the full reference, and
`_phase4_verdict.md` for the Day-1 substrate precursor findings.

## The learning module (0.3.0)

```dart
final gate = Cell.ingress<int>(
  context: context,
  testRule: contextAware() + learnedPolicy(),
);
final handle = cognitive(cell: gate.cell);
final outcomes = recordOutcomes(handle);

// ... traffic; reward every accepted decision ...
handle.recordOutcome(decisionId: decision.id, reward: success ? 1 : -1);

final trained = await trainOffline(
  handle: handle,
  outcomes: outcomes.log,
  baseContext: handle.cell.context,
  trainer: contextualBandit(),           // offline, journaled
  journal: journal,                      // required — no default
  config: const TrainingConfig(minSupport: 5, minConfidence: 0.6),
);

final evolved = trained.applyTo(handle.cell.context);
final redeployed = Cell.ingress<int>(
  context: evolved,
  testRule: contextAware() + learnedPolicy(),  // learned rules now apply
);
```

- `Outcome` + `recordOutcomes()` — typed reward log from the outcome
  channel.
- `Trainer` protocol + `contextualBandit()` — buckets by context vector
  `(domains, compliance, authority, actor, strategy, purpose)`, emits
  `accept`/`reject` rules under support/confidence thresholds.
- `TrainedPolicy` — portable record (`toMap`/`fromMap`/`applyTo`),
  deterministic under a `ReplayJournal`.
- `learnedPolicy()` — subset-matching, first-match-wins, pass-through
  when silent; compose explicitly with `contextAware()`.

```dart
dart run example/04_learning_loop.dart   # record → train → deploy
```

See `guide/03-Learning.md` for the full reference.

## The runtime module (0.2.0)

```dart
final src = Cell.ingress<int>(context: Context(domains: 'finance'));
final handle = cognitive(cell: src.cell, policy: contextAware());

src.ingest(pulse);                        // accepted → logged
await handle.cognitive.apply<int>(cmd);   // governed → logged
handle.recordOutcome(decisionId: id, reward: 1.0);

for (final decision in handle.decisions) {
  print(decision); // Decision(id, Accept, 1.0.0)
}
```

- `CognitiveHandle<C>` — principal + governed view + `TissueList<Decision>`
  log + `IngressHandle<Pulse>` outcome channel.
- `Decision` — id, timestamp, context version, verdict, pulse/command,
  policy version, evaluation time; serializable via `toMap`/`fromMap`.
- Attribution — `principal-rejected` / `policy-rejected` /
  `composite-rejected` (composite-level; per-rule attribution is the
  trainer's job).
- Bounded log — `maxDecisions` rolls off the oldest, observably.

```dart
dart run example/02_authority_deputy.dart  # authority-gated API
dart run example/03_decision_log.dart      # query + observe + reward
```

See `guide/02-Runtime.md` and `guide/04-Determinism.md`.

## The policy module (0.1.0)

```dart
import 'package:cell_mind/cell_mind.dart';

final gate = Cell.ingress<String>(
  context: Context(domains: 'finance,audit'),
  testRule: requiresDomainPolicy() + domainPolicy(),
);
```

Fifteen factories, all `TestCell<Cell>` compositions, all fail-closed by
default:

| Family | Factories |
|---|---|
| Domain | `domainPolicy`, `requiresDomainPolicy` |
| Compliance | `compliancePolicy`, `complianceOverlapPolicy` |
| Authority | `authorityPolicy`, `exactFunctionsPolicy` |
| Clearance | `clearancePolicy` (+ `ApplyCategory`) |
| Isolation | `isolationPolicy` |
| Data/trust | `sensitivityPolicy`, `confidencePolicy`, `strategyPolicy`, `auditLevelPolicy` |
| Identity | `actorPolicy`, `purposePolicy` |
| Time | `notOlderThan` (injected clock, `readOnlyExternal`) |
| Custom/composition | `predicatePolicy`, `contextAware`, `paranoid` |

```dart
dart run example/01_hello_policy.dart   # domain-gated ingress walkthrough
```

See `guide/01-Policies.md` for the full reference.

## When it fits

- The same cell must behave differently depending on its `Context`
  (e.g. a `ValueCell` that enforces different compliance rules in `finance`
  vs. `marketing`).
- Multi-agent systems where each agent's `DeputyContext` defines its
  decision envelope.
- Pipelines that need auditable, replayable decisions with a learning loop
  on top.
- HITL approval flows — approval is one implementation of a `Defer`
  resolver, not a bolt-on.

## When it doesn't

- **You need an AI SDK.** No LLM clients, no model serving, no vendor
  adapters. `cell_mind` is the policy layer around such systems: since
  `1.1.0` it *queries* them through your ~10-line `PromptFunction`
  adapter, but it never transports.
- **You need a new runtime.** Every primitive is a composition of `cell`
  types (`TestCell`, `Pulse`, `Context`, `ApplyCommand`, `EffectJournal`).
- **You need a decision engine that replaces a cell's receptor.** `cell_mind`
  layers policy on the same substrate; the reactive pipeline stays in
  `cell`, the relational mesh in `cell_organ`, and orchestration logic in
  `cell_flow`.

## Quickstart

```dart
final gate = Cell.ingress<int>(
  context: Context.fromEntries([Ontology.domains.entry('finance')]),
  testRule: domainPolicy(),
);
final handle = cognitive(cell: gate.cell);
await gate.ingest(Pulse<int>.governed(
  payload: 42,
  context: PulseContext.fromEntries([Ontology.domains.entry('finance')]),
));
print(handle.decisions.last.verdict.type); // accept
```

### Prompted policy (1.1.0)

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.policyDecider(),
  prompt: (prompt) async => mySdk.complete(prompt), // your adapter
  journal: journal,
);
final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),          // structural gate — runs first
  verdictPolicy: policy,           // LLM nuance — runs second
  onDeferred: approvalResolver(queue),
);
```

The LLM can veto; it can never override the structural gate. See
[Prompted Policy](guide/12-Prompted-Policy.md) and
`example/10_prompted_policy.dart`.

## Documentation

- [Getting Started](guide/00-Getting-Started.md) — five minutes to a
  working pipeline
- [API Chooser](lib/doc/api_chooser.dart) — pick the right type in
  seconds (humans and AI agents)
- [Policies](guide/01-Policies.md) · [Runtime](guide/02-Runtime.md) ·
  [Learning](guide/03-Learning.md) ·
  [Determinism](guide/04-Determinism.md) ·
  [Approval](guide/05-Approval.md) · [Bridges](guide/06-Bridges.md) ·
  [XAI](guide/07-XAI.md) · [Agents](guide/08-Agents.md)
- [Prompted Policy](guide/12-Prompted-Policy.md) — the 1.1.0 prompt
  layer: `PromptConfig`, both modes, the cache, replay, conformance
- [Cookbook](guide/09-Cookbook.md) — 16 recipes, each with a test
- [Design Notes](guide/10-Design-Notes.md) ·
  [Internals](guide/11-Internals.md)
- [Architecture](ARCHITECTURE-Mind.md) — the design and implementation
  architecture across phases 0–9

## Stability

`cell_mind 1.0.0` is the frozen API; `1.1.0` adds the prompt module —
prompted policy, two-tier verdict caching, and stateful chat sessions
(additive; one source-compatible widening of `VerdictPolicy.call` to
`FutureOr<Verdict>`). See
[`FROZEN_API.md`](FROZEN_API.md) for the complete manifest. Future
versions follow semver: `1.0.x`/`1.1.x` (patches), `1.x.0` (new APIs),
`2.0.0` (breaking changes with a documented migration).

```bash
dart tool/freeze_api.dart > /tmp/current_api.md
diff FROZEN_API.md /tmp/current_api.md
```

Any diff requires a deprecation cycle or a MAJOR bump.

## Quick orientation

| Want | Read |
|---|---|
| The design principles (P1–P9 + phase findings) | `guide/10-Design-Notes.md` |
| What `cell` guarantees `cell_mind` relies on | `test/fitness/cell_contract_test.dart` |
| Known limitations + post-1.0 roadmap | `KNOWN_ISSUES.md` |
| Phase roadmap | `research/Mind/Plan.md` |
| The definition of working | `example/09_acceptance.dart` |

## Development

```bash
dart pub get
dart analyze --fatal-infos --fatal-warnings   # 0 issues
dart format --set-exit-if-changed lib/ test/ example/ benchmark/ tool/  # exit 0
dart test                                     # 400+ tests pass
dart test test/cookbook/*.dart                # 15 recipe tests
dart doc --validate-links                     # 0 warnings, 0 errors
dart pub publish --dry-run                    # publishable
```

CI runs the fitness suite **first** — a `cell` regression breaks the
pipeline at the entry point — then analyze, tests, cookbook, doc
build, coverage gate (88% line), and publish dry-run
(`.github/workflows/cell_mind.yml`).

## License

MIT OR Apache-2.0 — see `LICENSE`.
