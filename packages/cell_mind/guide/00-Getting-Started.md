# Getting started with `cell_mind`

*Five minutes to a working cognitive pipeline.*

---

## §1 — What you are building

`cell_mind` turns the Mitosis `Context` into an executable governance
layer:

- `Policy` factories decide whether a pulse or command may pass —
  fail closed by default.
- `cognitive()` wraps a cell in a recording deputy whose decision log
  (`CognitiveHandle.decisions`) is the audit trail.
- `trainOffline` turns recorded outcomes into a `TrainedPolicy` that
  folds back into a `Context`.
- `ApprovalQueue` makes `Defer` a first-class verdict for humans in
  the loop.
- `completion` / `toolRouter` connect LLMs; `DecisionPath` explains;
  `spawn` + `debate` orchestrate agents.

**The one-sentence mental model:** signals carry provenance; policies
are functions of that provenance; every decision is recorded; the
log trains the next policy.

---

## §2 — Installation

```yaml
dependencies:
  cell: ^1.1.0
  cell_tissue: ^1.0.0
  cell_mind: ^1.0.0
```

```dart
import 'package:cell_mind/cell_mind.dart';
```

`cell_mind 1.0.0` freezes the public API (see `FROZEN_API.md`).
Future releases follow semver: `1.0.x` patches, `1.x.0` additions,
`2.0.0` breaking.

---

## §3 — First pipeline (5 minutes)

```dart
import 'package:cell_mind/cell_mind.dart';

Future<void> main() async {
  // 1. A finance-scoped gate with governance.
  final gate = Cell.ingress<int>(
    context: Context.fromEntries([
      Ontology.domains.entry('finance'),
      Ontology.version.entry('1.0.0'),
    ]),
    testRule: domainPolicy(),
  );

  // 2. The recording layer.
  final handle = cognitive(cell: gate.cell);

  // 3. Traffic with provenance.
  await gate.ingest(Pulse<int>.governed(
    payload: 42,
    context: PulseContext.fromEntries([
      Provenance.actor.entry('alice'),
      Provenance.reason.entry('first-steps'),
      Provenance.confidence.entry(0.95),
      Provenance.strategy.entry(ReasoningStrategy.probabilistic),
      Ontology.domains.entry('finance'),
    ]),
  ));

  // 4. The decision is recorded.
  for (final decision in handle.decisions) {
    print('${decision.at}: ${decision.verdict.type}');
  }

  // 5. Explain it.
  print(explain(handle.decisions.last).toNarrative());
}
```

**What happened:** the pulse passed the domain gate, the recorder
wrote an `Accept` decision, and the XAI layer rendered the audit
line. Rejections follow the same path — they are decisions too.

---

## §4 — Architecture in one diagram

```
ingress ──pulse──▶ [Policy] ──▶ cognitive deputy ──▶ downstream state
                    (gate)     │
                               ├──▶ Decision log ──▶ explain/XAI
                               ├──▶ outcomes ──▶ trainOffline ──▶ Context
                               ├──▶ verdictPolicy ──▶ verdict cache ──▶ LLM
                               └──▶ Defer ──▶ ApprovalQueue ──▶ committed
```

- **Policies** are pure functions of provenance + host context.
- **The recorder** is a deputy view — it sees every pulse and command
  that passes, and records the verdict.
- **Learning** is offline and portable: a `TrainedPolicy` is data,
  not a live cell.
- **Prompted policies** (Phase 8/9) sit behind the structural gates:
  they render the Context into a prompt, query any AI, and memoize
  the verdict with a three-tier cache (verdict cache → prompt cache →
  LLM) plus optional stateful chat sessions.
- **Deferral** never blocks the wave: the resolution arrives
  out-of-band through `ApprovalQueue.committed`.

---

## §5 — The module map

| Module | Entry points | Guide |
|---|---|---|
| policies | `domainPolicy`, `authorityPolicy`, `compliancePolicy`, `sensitivityPolicy`, `confidencePolicy`, `strategyPolicy`, `auditLevelPolicy`, `actorPolicy`, `purposePolicy`, `notOlderThan`, `contextAware`, `paranoid`, `predicatePolicy`, `learnedPolicy` | `guide/01-Policies.md` |
| runtime | `cognitive`, `CognitiveHandle`, `Decision` | `guide/02-Runtime.md` |
| learning | `trainOffline`, `contextualBandit`, `TrainedPolicy`, `recordOutcomes` | `guide/03-Learning.md` |
| approval | `ApprovalQueue`, `approvalResolver`, `VerdictPolicy` | `guide/05-Approval.md` |
| bridges | `completion`, `streamCompletion`, `streamChunks`, `toolRouter` | `guide/06-Bridges.md` |
| xai | `DecisionPath`, `explainPulse`, `explainSource`, `otelSpans` | `guide/07-XAI.md` |
| agents | `AgentSpec`, `spawn`, `AgentRuntime`, `debate` | `guide/08-Agents.md` |
| prompt | `promptedPolicy`, `promptedPolicyWith`, `PromptedPolicy`, `PromptConfig`, `PromptConfigRegistry`, `conform`, `PromptSession`, `SessionMode`, `VerdictCache`, `InMemoryVerdictCache` | `guide/12-Prompted-Policy.md` |
| cross-cutting | `Verdict`, `Outcome`, journaling | `guide/09-Cookbook.md` |

The curated index lives at `lib/doc/api_chooser.dart` — read it when
you know the need but not the type.

---

## §6 — Five recurring patterns

### 6.1 — Gate first, record second

```dart
final gate = Cell.ingress<T>(context: context, testRule: contextAware());
final handle = cognitive(cell: gate.cell, policy: learnedPolicy());
```

The ingress gate does transport-level policy; `cognitive` adds the
recording layer. Both are optional — a bare `cognitive` records
everything.

### 6.2 — Every pulse carries provenance

```dart
Pulse<T>.governed(
  payload: value,
  source: gate.cell,          // optional: explains where it came from
  context: PulseContext.fromEntries([
    Provenance.actor.entry('alice'),
    Provenance.confidence.entry(0.9),
    Ontology.domains.entry('finance'),
  ]),
)
```

Policies read these entries; narratives render them; training buckets
on them. Untagged pulses fail domain/compliance gates.

### 6.3 — Humans approve the exceptional

```dart
verdictPolicy((object, {required host, arguments}) =>
    (object is Pulse && (object.payload as int) > limit)
        ? const Defer('approval')
        : const Accept())
```

Wire `approvalResolver(queue)` as `onDeferred`; approve/reject via
`queue.approve(id)` / `queue.reject(id, reason)`.

### 6.4 — Train from outcomes, deploy as context

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

### 6.5 — Explain the log

```dart
explainPulse(pulse, handle)?.toNarrative();   // audit line
otelSpans(handle.decisions, tracer: adapter); // tracing
```

### 6.6 — Ask an AI, once (verdict caching)

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.policyDecider(),
  prompt: (prompt) async => mySdk.complete(prompt), // your adapter
  journal: journal,
);

final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),     // structural gate runs first
  verdictPolicy: policy,      // LLM nuance, memoized
  onDeferred: approvalResolver(queue),
);
```

The same `(config, context, decision, session)` state is answered once:
a repeat decision is a verdict-cache hit — no prompt, no LLM call, no
new conversation turn. See `guide/12-Prompted-Policy.md`.

---

## §7 — Next steps

1. **Pick a recipe** from `guide/09-Cookbook.md` that matches your
   domain and run its test.
2. **Read the policy guide** — `guide/01-Policies.md` is the
   foundation; every other module composes with it.
3. **Read the runtime guide** — `guide/02-Runtime.md` explains the
   recording deputy and the decision record.
4. **Add humans** with `guide/05-Approval.md`, **add models** with
   `guide/06-Bridges.md`, **add prompt-driven verdicts** with
   `guide/12-Prompted-Policy.md` (Phase 8/9: caching + chat sessions).
5. **Check the limitations** in `KNOWN_ISSUES.md` before designing
   around them.

---

## §8 — Requirements and compatibility

| Requirement | Value |
|---|---|
| Dart SDK | `>=3.5.0 <4.0.0` |
| `cell` | `^1.1.0` |
| `cell_tissue` | `^1.0.0` |
| `cell_organ` (dev, integration tests) | `1.0.0` (workspace) |
| Platforms | android, ios, linux, macos, windows, web |

`cell_mind` adds no other runtime dependencies — the bridge layer is
transport-agnostic by design (bring your own HTTP client).

---

## §9 — The stability guarantee (v1.0 frozen, 1.1 additive)

Every public type, method, and typedef shipped in `1.0.0` is frozen
in `FROZEN_API.md`. A future PR that changes a signature must run:

```bash
dart tool/freeze_api.dart > /tmp/current_api.md
diff FROZEN_API.md /tmp/current_api.md
```

Any diff triggers either a deprecation cycle or a `2.0.0` bump.
Bugs ship as `1.0.x` patches; new capabilities as `1.x.0`.

`1.1.0` (Phase 8/9) added the **prompt** module additively —
prompted policy, verdict caching, and chat sessions. Its one
signature change is source-compatible: `VerdictPolicy.call` widened
to `FutureOr<Verdict>` (async verdict policies), which is why a
prompted policy can await an LLM.

---

## §10 — The acceptance pipeline

`example/09_acceptance.dart` is the definition of working: a
fraud-detection flow that runs every module end-to-end (policy →
deferral → approval → bridge → learning → deployment → debate →
XAI) with hard checks, in under 5 seconds.
`example/10_prompted_policy.dart` extends it with the Phase 8/9
surface: config mode, replay, defer, dedicated/shared sessions,
verdict-cache hits, classifier and extractor presets.
`example/11_payguard_live.dart` is the real-life version: a payment
gateway that queries a **live DeepSeek LLM** (settings from
`.deepcode/settings.json` at the repository root, or
`DEEPSEEK_API_KEY`) through the prompted-policy pipeline — with
verdict caching, chat sessions, HITL approval, offline learning, XAI
narratives, replay, and conformance. Without DeepSeek settings it
falls back to a deterministic mock, so it always runs. The full
walkthrough lives next to it: `example/11_payguard_live.md`.

```bash
dart run example/09_acceptance.dart
dart run example/10_prompted_policy.dart
dart run example/11_payguard_live.dart            # live DeepSeek
dart run example/11_payguard_live.dart --conformance
```

If those programs fail, the framework is not ready — they are also
the CI smoke tests.

---

## §11 — Where to go from here

- Cookbook: `guide/09-Cookbook.md` (16 recipes with tests)
- Prompted policy: `guide/12-Prompted-Policy.md` (Phase 8/9 —
  rendering, three-tier caching, chat sessions, conformance)
- Design rationale: `guide/10-Design-Notes.md`
- Architecture: `ARCHITECTURE-Mind.md` (phases 0–9, end to end)
- Maintainer view: `guide/11-Internals.md`
- Known limitations: `KNOWN_ISSUES.md`
- Migration from 0.x: `CHANGELOG.md` → `1.0.0` entry

---

## §12 — FAQ

**Q: Why is my pulse rejected with `policy-rejected`?**
Read the decision's verdict reason and check provenance: domain,
compliance, confidence, strategy, sensitivity, actor, purpose, and
clearance all have policies. `contextAware()` requires domain,
compliance, and confidence by default.

**Q: Why does `emit(value)` pass but my `ingest(pulse)` fail?**
`emit` wraps the raw value with the ingress's own context — host
domains are inherited. Ingested pulses carry only what you put in
`PulseContext`.

**Q: Where do deferred pulses go?**
They are dropped from the wave and delivered through
`ApprovalQueue.committed` after approval. Never re-ingest them.

**Q: How do I deploy a trained policy?**
`trained.applyTo(plainContext)` returns an evolved `Context`; build
the new gate/deputy with it. Apply to a **plain** `Context` — deputy
contexts do not expose the `Ontology.constraints` pillar.

**Q: Why is my debate single-round?**
Agents are stateless between rounds and the substrate completes a
pulse at its first terminal. Consensus is decided in round 1 or the
question fails.

**Q: Can I host `cognitive()` on a `cell_organ` Blend?**
Not in v1.0 — organ deputies accept only `TestStem` gates. Bind an
ingress to the blend and host the handle on the ingress (recipe 10).

**Q: How do I get OTel traces?**
`otelSpans` + a ~20-line `Tracer` adapter; no SDK dependency ships.

**Q: What is the replay story?**
`RecordingJournal` → `ReplayJournal(records)`. Tool invocations are
journaled io effects, so replay never re-invokes the world. Training
is deterministic under replay.

**Q: How do I query an LLM for a verdict?**
`promptedPolicyWith(config:, prompt:, journal:)` in the
`verdictPolicy:` slot. Repeat inputs are served from the verdict
cache without a call; `Defer` verdicts route to `onDeferred`. See
`guide/12-Prompted-Policy.md`.

**Q: Why did my prompted decision call the LLM twice?**
A successful decision appends a turn to the session (dedicated/shared
modes), which changes the verdict-cache key. Stateless configs never
do this; repeats in the same session state are cache hits.

---

## §13 — Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Reject `principal-rejected` | the host cell's own rule said no | check the gate's `testRule` |
| Reject `policy-rejected` | a `Policy` factory failed | inspect provenance vs the policy |
| Reject `defer-no-resolver` | `Defer` with no matching resolver | pass `onDeferred` |
| `StateError` on record | handle disposed or truncated | don't record after `dispose()` |
| Decision count 0 | traffic bypasses the view | route through `handle.cognitive` |
| Replay divergence | effect fingerprints differ | ms-truncate timestamps; exact maps |
| Debate no-vote | missing `routeIn` | pass `source.ingest` |
| Reject `prompt-too-long` | rendered prompt over `maxPromptChars` | shorten template/history or raise the bound |
| Reject `parse-error-*` / `prompt-error` | adapter output malformed or call failed | check `PromptConfig.outputSchema` and the adapter |
| Repeated decision still calls the LLM | session grew (key changed) | use stateless mode or repeat with the same session state |

---

## §14 — Summary

1. Put a gate on your ingress (`contextAware()`, `domainPolicy()`, …).
2. Wrap the cell with `cognitive()` and read `handle.decisions`.
3. Add `verdictPolicy` + `ApprovalQueue` where humans belong.
4. Record outcomes, train offline, apply to the next context.
5. Explain with `DecisionPath` and trace with `otelSpans`.
6. Orchestrate with `spawn` + `debate`.

The acceptance pipeline (`example/09_acceptance.dart`) shows all six
steps working together — copy its structure and swap in your domain.
