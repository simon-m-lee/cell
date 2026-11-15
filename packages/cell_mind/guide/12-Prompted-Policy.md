# Guide 12 — Prompted Policy (`cell_mind 1.1.0`)

*Prompt-driven policy: turn a cell's `Context` into a prompt, query any
AI, and parse the answer back into a `Verdict`.*

| | |
|---|---|
| **Module** | `prompt` (Phase 8) |
| **Version** | Stable since `cell_mind 1.1.0` |
| **Public surface** | `promptedPolicy`, `promptedPolicyWith`, `PromptConfig`, `PromptExample`, `PromptConfigRegistry`, `conform`, `PromptEffect`, `renderContext`, `renderDecision`, `parseVerdict` |
| **Ships in** | `lib/src/prompt_policy.dart`, `lib/src/prompt_config.dart` |

---

## 1. What prompted policy is

The prompted policy layer is the mechanism that turns a cell's
`Context` into a prompt, sends it to an AI, and parses the AI's
response back into a `Verdict` that composes with the framework's
existing `cognitive()` pipeline.

The requirement it fulfils, restated:

> *A prompt configuration, universal to LLMs, can be provided to Mind
> to query the AI prompt for verdict.*

`PromptConfig` is the configuration. `promptedPolicyWith(config:)`
queries the AI. The result is a `Verdict` (`Accept` / `Reject` /
`Defer`) in the `verdictPolicy:` slot of `cognitive(...)`. Both modes
accept a user-provided adapter (`PromptFunction`), so they work with
any LLM without vendor coupling.

A minimal example:

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.policyDecider(),
  prompt: (prompt) async => mySdk.complete(prompt), // ~10-line adapter
  journal: journal,
);

final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),       // structural gate (runs first)
  verdictPolicy: policy,        // LLM nuance (runs second)
  onDeferred: approvalResolver(queue), // human approval (runs last)
);
```

The evaluation order is the trust model of the whole framework:

1. **Principal rule** (`cell.validate`)
2. **Structural policy** (`contextAware()`, `domainPolicy()`, …)
3. **LLM verdict** (`promptedPolicyWith`)
4. **Deferral** (`onDeferred` → `ApprovalQueue`)

The LLM can veto, but it can never override a structural rejection.

---

## 2. Two modes, one implementation

| Mode | API | Use case |
|---|---|---|
| **Inline** | `promptedPolicy(...)` | One-off prompts, quick integration |
| **Config** | `promptedPolicyWith(config:)` | Reusable, versionable, portable prompts |

`promptedPolicy(...)` is a **thin wrapper**: it constructs a
`PromptConfig` with a per-instance id (`_inline_<uuid>`) and delegates
to `promptedPolicyWith`. There is exactly one renderer, one parser, one
cache, and one journal effect — no duplicated pipeline. You choose the
mode at the call site; the behavior is identical.

```dart
// Inline — one-off.
final policy = promptedPolicy(
  prompt: mySdk.complete,
  journal: journal,
);

// Config — reusable and versionable.
PromptConfigRegistry.register(
  PromptConfig.policyDecider(),
);
final policy = promptedPolicyWith(
  configId: 'policy-decider',
  prompt: mySdk.complete,
  journal: journal,
);
```

**Cache behavior differs by mode:**

- **Inline mode:** per-instance cache. Two `promptedPolicy(...)` calls
  with identical parameters have separate caches. Predictable; matches
  user expectation.
- **Config mode:** the cache is keyed by `config.id + config.version`
  (plus content hashes). Two `cognitive()` calls sharing the same
  registry config share verdicts — required for A/B testing and
  cross-session caching.

---

## 3. Why Context IS the prompt

There is **no separate "prompt" field on `Context`**. Every `Ontology`
and `Mandate` dimension is prompt material. The renderer walks the
typed dimensions in the framework's **declaration order** and emits a
structured block:

```text
## Context

- domains: finance,audit
- constraints: {"max_amount":10000,"require_mfa":true}
- compliance: GDPR
- partOf: ledger_service
- authority: read,write      ← DeputyContext mandates
- isolation: scoped
```

**Determinism guarantees:**

- **Fixed iteration order** — `Ontology.values` then `Mandate.values`
  in declaration order, never map order.
- **Sorted JSON** — `constraints` and other map values render
  key-sorted, so insertion order never changes a byte.
- **ISO-8601 UTC** — every date value.
- **Empty dimensions omitted** — null, blank strings, empty
  lists/maps produce no line.

These guarantees are what make the content-addressed cache hit
reliably and make replay byte-exact. A custom renderer that iterates a
map in insertion order silently breaks both — §13 explains how to
extend without breaking the contract.

---

## 4. The three-stage pipeline

Every decision flows through three stages:

```
1. Render:  Context + Decision → prompt string
2. Call:    prompt string → PromptFunction → response string
3. Parse:   response string → Verdict (fail-closed)
```

Each stage is a **typed, replaceable primitive**:

```dart
typedef ContextRenderer = String Function(Context context);
typedef DecisionRenderer = String Function(
  dynamic object, {
  Cell? host,
  dynamic arguments,
});
typedef VerdictParser = Verdict Function(String rawResponse);
```

The inline mode passes these as parameters; the defaults are the
public functions `renderContext`, `renderDecision`, and `parseVerdict`
— so you can compose instead of replace:

```dart
final policy = promptedPolicy(
  prompt: mySdk.complete,
  journal: journal,
  contextRenderer: (context) =>
      '${renderContext(context)}\n- my_extra: ${context.identity}',
);
```

The call stage is your adapter (`PromptFunction`). The framework
governs, journals, caches, and parses; you handle transport, retries,
rate limits, and API keys.

---

## 5. Prompt format specification

### 5.1 Default system prompt (`policyDecider`)

```
You are a policy decision engine for the Cell framework.
Your task is to determine whether a decision should be ACCEPTED,
REJECTED, or DEFERRED based on the Context that governs it.

Rules:
- ACCEPT if the decision is within the Context's authority and
  complies with its constraints.
- REJECT if the decision violates authority, compliance, or
  constraints.
- DEFER if the decision is ambiguous and requires human review.

Respond ONLY with a JSON object matching the schema in the
## Expected Output section. Do not include prose, markdown fences,
or explanations outside the JSON.
```

### 5.2 Complete rendered prompt

The config renderer assembles the full prompt in a fixed layout:

```text
<systemPrompt>

### Example 1            ← few-shot examples, in order

Context:
- domains: finance,audit

Decision:
- type: pulse
- payload: {"amount":5000}

Response:
{"verdict":"accept","reason":"within limit"}

## Context               ← {{context}} substitution

- domains: finance,audit
- compliance: GDPR
- authority: read,write
- constraints: {"max_amount":10000,"require_mfa":true}

## Decision              ← {{decision}} substitution

- type: pulse
- payload: {"amount":5000,"customer":"acme"}
- source: ledger.ingress
- actor: system
- strategy: probabilistic
- confidence: 0.95
- purpose: TRANSACTION
- traceId: 7f3a-...

## Expected Output       ← the output schema, as JSON

{"type":"object","required":["verdict"],...}
```

### 5.3 Universality

| Provider | Compatible? | Why |
|---|---|---|
| GPT-4 | ✓ | Markdown + JSON Schema |
| Claude | ✓ | Same |
| Gemini | ✓ | Same |
| Llama / Mistral | ✓ | Same |
| Local models | ✓ | Same |

No vendor-specific tokens: no XML tags, no function-calling schema.
Adapters may post-process the rendered prompt (e.g. wrap it in tags
for models that prefer them); the framework's contract is the rendered
prompt, and transport is the adapter's job.

### 5.4 Determinism guarantees

The rendered prompt is **byte-for-byte identical** for the same
`(config, Context, Decision)` triple:

- Ontology iteration order is fixed.
- Map values are sorted key-by-key.
- Lists join with commas.
- Dates are ISO-8601 UTC.
- Empty dimensions are omitted.
- The pulse **timestamp is deliberately not rendered** — it changes on
  every emission and would break the cache and replay.

---

## 6. The trust boundary

The LLM **cannot bypass structural policy**. `cognitive()` evaluates:

1. **Principal rule** (`cell.validate`)
2. **Policy** (structural gates — Phase 1–3)
3. **VerdictPolicy** (LLM — Phase 8)
4. **`onDeferred`** if the verdict is `Defer`

If (1) or (2) rejects, the adapter is never invoked. This is tested by
`trust_boundary_test.dart` and demonstrated by the acceptance example.

**Recommended pattern:**

```dart
final handle = cognitive(
  cell: cell,
  policy: contextAware(),             // structural gate
  verdictPolicy: promptedPolicyWith(  // LLM for nuance
    config: PromptConfig.policyDecider(),
    prompt: myLLM,
    journal: journal,
  ),
  onDeferred: approvalResolver(queue),
);
```

**Anti-pattern — the LLM decides everything:**

```dart
// WRONG: no structural gate before the LLM.
cognitive(
  cell: cell,
  policy: TestCell.allowAll,  // ← empty structural gate
  verdictPolicy: promptedPolicyWith(...),
);
```

Why it is dangerous: a prompt-injected pulse payload, a hallucinated
"accept", or a model regression all become single points of failure.
The structural gate is cheap, deterministic, and auditable — the LLM
is expensive, stochastic, and opaque. Keep the boundary.

When the anti-pattern *is* acceptable: sandboxed experiments,
non-critical pipelines, and conformance runs — document it loudly.

---

## 7. Determinism via journal + cache

### 7.1 The content-addressed cache

Cache key:

```
sha256(config.id | config.version | contextHash | decisionHash | systemPromptHash)
```

- **Inline mode** ids are per-instance (`_inline_<uuid>`), so inline
  policies never collide.
- **Config mode** keys share per `(id, version)` — the A/B property.
- **A version bump forces a miss.** Changing the prompt must
  invalidate old verdicts; the version field is that switch.
- **`cacheTtl` bounds entry lifetime** (zero disables caching).
- **Errors are not cached** — only successful responses are stored.

### 7.2 The journal effect

Every decision journals one `PromptEffect` through the
`EffectJournal` (`label: 'mind.prompt'`), **including cache hits**:

```dart
final class PromptEffect {
  static const schemaVersion = '1.0.0';
  final String configId;
  final String configVersion;
  final String contextHash;
  final String decisionHash;
  final String prompt;    // full prompt text (audit)
  final String response;  // full response text (replay)
  final DateTime at;
  final Duration latency;
  ...
}
```

The effect carries the **full prompt and response**: replay needs the
exact response to reproduce the verdict, and audit needs the exact
prompt. If prompts contain sensitive data, apply redaction at the
journal layer (Phase 7's `EffectJournal` supports custom
serialization).

### 7.3 Replay

```dart
// Recording: cache miss → call LLM → journal PromptEffect.
// Replay:    journal serves the recorded response → no LLM call.
final recording = RecordingJournal();
// ... run decisions ...

final replay = ReplayJournal(
  recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
);
// ... run the SAME decisions with the SAME config ...
replay.assertExhausted();
```

`determinism_test.dart` verifies that `llmCalls` does not increase
during replay. A changed config between recording and replay diverges
loudly with `ReplayDivergenceException` — the replay input digest is
the full rendered prompt, so any prompt change is caught at the first
effect.

---

## 8. `PromptConfig` reference

```dart
final class PromptConfig {
  final String id;                  // stable identity
  final String version;             // semantic version — bump invalidates cache
  final String description;         // human-readable purpose
  final String systemPrompt;        // model instructions
  final String userTemplate;        // {{context}} / {{decision}}
  final Map<String, dynamic> outputSchema; // JSON Schema of the answer
  final List<PromptExample> examples;      // few-shot triples
  final Map<String, dynamic> parameters;   // temperature, json_mode, …
  final Duration cacheTtl;          // zero disables caching
  final int maxPromptChars;         // over-long prompts fail closed
}
```

**`version` is semantic versioning** (`'1.0.0'`). Bumping it
invalidates the cache — this is the primary upgrade mechanism for
configs.

**`parameters` is a hint map** (`temperature`, `json_mode`,
`max_tokens`). Adapters may interpret or ignore them; the framework
does not call the LLM itself and does not enforce these.

**The template has exactly two placeholders.** `{{context}}` and
`{{decision}}`. Any other `{{...}}` pattern is literal. Missing
placeholders are allowed (validation warns in this guide; it does not
reject).

**Factories:**

```dart
PromptConfig.policyDecider({String? systemPrompt});
PromptConfig.classifier({required List<String> labels, String? systemPrompt});
PromptConfig.extractor({required List<String> fields, String? systemPrompt});
PromptConfig.custom({required String id, ...}); // explicit defaults
```

**Serialization:**

```dart
final map = config.toMap();                     // JSON-encodable
final restored = PromptConfig.fromMap(map);     // exact round-trip
```

`cacheTtl` serializes as milliseconds. A config file ships without
source code — examples store rendered text, not live `Context`
objects.

**Validation (`validate()`) checks structure, not semantics:**

- `id`, `version`, `systemPrompt`, `userTemplate` non-empty
- `outputSchema` defines a response shape (`verdict`, `label`, or
  `fields`)
- each example's `response` parses against the schema
- `cacheTtl` non-negative; `maxPromptChars >= 100`

Whether the LLM will *comply* with the schema is measured by
`conform`, not `validate` — validation cannot know your model.

---

## 9. The three presets

### 9.1 `policyDecider` — accept / reject / defer

Id `policy-decider`, version `1.0.0`. The most common case: the model
answers with `{"verdict": "accept" | "reject" | "defer", ...}` and the
verdict flows into the decision log verbatim.

Ships three few-shot examples (accept / reject / defer) so fresh
models see the expected shape immediately.

### 9.2 `classifier` — label → verdict

Id `classifier`, version `1.0.0`. The model answers
`{"label": "<one of the labels>"}`; your `labelToVerdict` callback
converts the label:

```dart
promptedPolicyWith(
  config: PromptConfig.classifier(labels: ['spam', 'ham']),
  prompt: myLLM,
  journal: journal,
  labelToVerdict: (label) =>
      label == 'spam' ? const Reject('spam detected') : const Accept(),
);
```

Missing callback fails closed with `Reject('missing-label-to-verdict')`.

### 9.3 `extractor` — fields → verdict

Id `extractor`, version `1.0.0`. The model answers
`{"fields": {"amount": "25000"}}`; your `extractionToVerdict` callback
converts the map:

```dart
promptedPolicyWith(
  config: PromptConfig.extractor(fields: ['amount', 'currency']),
  prompt: myLLM,
  journal: journal,
  extractionToVerdict: (fields) =>
      int.parse(fields['amount'] as String) > 10000
          ? const Reject('amount too large')
          : const Accept(),
);
```

Missing callback fails closed with
`Reject('missing-extraction-to-verdict')`.

Presets are **plain instances** — copy one and change any field.

---

## 10. Serialization and versioning

### 10.1 The config as a file

```dart
import 'dart:convert';
import 'dart:io';

// Ship.
final encoded = jsonEncode(PromptConfig.policyDecider().toMap());
File('configs/policy-decider.json').writeAsStringSync(encoded);

// Load at startup.
final config = PromptConfig.fromMap(
  jsonDecode(File('configs/policy-decider.json').readAsStringSync())
      as Map<String, dynamic>,
);
PromptConfigRegistry.register(config);
```

### 10.2 The versioning workflow

1. Change the prompt: edit the file, **bump `version`**.
2. Load and register the new version.
3. `conform` the new version against the target model.
4. Deploy; the registry serves the highest version.
5. Roll back by pinning `configVersion:` — no code deploy.

Forgetting the version bump leaves stale cached verdicts in place —
the cache key includes the version precisely so that a bump forces a
miss.

---

## 11. The registry (A/B testing, rollback)

```dart
class PromptConfigRegistry {
  static void register(PromptConfig config);
  static PromptConfig? lookup(String id, {String? version});
  static List<PromptConfig> list({String? id});
  static void unregister(String id, {String? version});
}
```

- `register` — startup wiring; re-registering `(id, version)` replaces.
- `lookup(id)` — **highest semantic version wins** (`1.10.0` >
  `1.9.0`, numeric component comparison).
- `lookup(id, version: v)` — exact pinning; the rollback lever.
- `list` — introspection for dashboards and diagnostics.

`promptedPolicyWith` accepts either `config:` (direct) or `configId:`
(registry lookup, optionally `configVersion:`-pinned).

```dart
// A/B: 90% of instances pin the stable config, 10% pin the candidate.
final stable = promptedPolicyWith(
  configId: 'policy-decider', configVersion: '1.0.0', ...);
final candidate = promptedPolicyWith(
  configId: 'policy-decider', configVersion: '1.1.0', ...);

// Rollback: flip the default back.
PromptConfigRegistry.unregister('policy-decider', version: '1.1.0');
```

The registry is process-wide; apps register at startup. Cross-process
A/B testing needs the same registrations at every process start.

---

## 12. Conformance testing

`conform` is a **first-class API**, not a test helper: verify a config
against a specific LLM before production.

```dart
final report = await conform(
  config: config,
  prompt: myLLM,               // the REAL adapter — users pay per run
  cases: [
    ConformanceCase(
      context: context,
      decision: amountPulse(5000),
      expected: const Accept(),
    ),
    ConformanceCase(
      context: context,
      decision: amountPulse(25000),
      expected: const Reject('amount exceeds max_amount'),
    ),
    ConformanceCase(
      context: context,
      decision: amountPulse(9000),
      expected: const Defer('approval'),
    ),
  ],
);

if (!report.passedAll) {
  print('Block deploy: ${report.failures.length}/${report.total} failed');
}
```

**Comparison semantics:** same verdict runtime type; `Reject` also
compares `reason`; `Defer` also compares `resolver`. Annotations are
deliberately NOT compared — the parser adds `reason`/`confidence` to
annotations, which would make every hand-built expectation fail.

`cell_mind`'s own tests use mocks; your conformance runs cost real
model calls. Pass the optional `journal:` so a recorded run replays
for free:

```dart
final journal = RecordingJournal();
final report = await conform(..., journal: journal);
// Later: replay the same run without touching the model.
```

`conform` validates the config first — a malformed config throws
`ArgumentError` before any LLM call.

---

## 13. Custom renderers

The three primitives are replaceable; the defaults are public
functions so you can **compose, don't replace**:

```dart
final policy = promptedPolicy(
  prompt: myLLM,
  journal: journal,
  contextRenderer: (context) => '${renderContext(context)}\n'
      '- environment: prod',
  decisionRenderer: (object, {host, arguments}) =>
      '${renderDecision(object, host: host, arguments: arguments)}\n'
      '- myTag: ${object is Pulse ? object.context.traceId : '-'}',
  verdictParser: parseVerdict, // or a custom fail-closed parser
);
```

**Custom-renderer determinism contract (mandatory):**

- Sort map keys before emitting JSON.
- Never emit wall-clock values that change between runs (the pulse
  timestamp is omitted by the default for this reason).
- Keep the output a pure function of `(context, decision)` — no
  ambient state, no map iteration order dependence.
- Return `Reject(...)` from a custom parser; never throw — a throwing
  parser bypasses the fail-closed contract.

A custom parser owns the raw response entirely: the default
verdict/label/fields shape dispatch runs only when no custom parser is
supplied.

---

## 14. Cost control

The layer gives you four levers:

| Lever | Where | Effect |
|---|---|---|
| Structural gate first | `policy:` slot | rejects never reach the LLM |
| `cacheTtl` | `PromptConfig.cacheTtl` | repeat decisions are free |
| Version bumps | `PromptConfig.version` | deliberate invalidation |
| `maxPromptChars` | `PromptConfig.maxPromptChars` | over-long prompts fail closed without a call |

One LLM call per *distinct* `(config, context, decision)` per TTL
window — measured by the micro-benchmark at
`benchmark/micro/prompted_policy_cost.dart` (~2,000 full cognitive
cache-miss decisions/s with a microtask adapter; ~5,300/s on cache
hits).

Not in scope (user code): retries, rate limiting, cost budgeting,
sampling, multi-LLM voting.

Argument-level rule evaluations are **never** sent to the LLM: the
substrate validates each command argument through the rule, and the
prompted policy short-circuits those frames — the LLM decides about
the command *with* its arguments at the command decision, not about
raw argument values.

---

## 15. Common patterns

### 15.1 HIPAA-adjacent triage (structure + LLM + human)

```dart
final handle = cognitive(
  cell: recordsGate.cell,
  policy: compliancePolicy() + confidencePolicy(),
  verdictPolicy: promptedPolicyWith(
    config: PromptConfig.policyDecider(
      systemPrompt: '$defaultSystemPrompt\n'
          'Never accept decisions touching PHI unless the Context '
          'declares HIPAA compliance.',
    ),
    prompt: myLLM,
    journal: journal,
  ),
  onDeferred: approvalResolver(ApprovalQueue(journal: journal)),
);
```

### 15.2 Fraud screening (from `example/10_prompted_policy.dart`)

Constraints carry the limit (`constraints: {'max_amount': 10000}`); the
LLM compares the decision payload and answers `accept` / `reject` /
`defer`. Near-limit amounts defer to the approval queue; over-limit
amounts reject; structural gates stop malformed input before the LLM.

### 15.3 Customer-support routing (classifier)

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.classifier(labels: ['refund', 'billing', 'technical']),
  prompt: myLLM,
  journal: journal,
  labelToVerdict: (label) => label == 'refund'
      ? const Defer('support-approval')
      : const Accept(),
);
```

### 15.4 Document intake (extractor)

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.extractor(fields: ['customer', 'amount', 'due']),
  prompt: myLLM,
  journal: journal,
  extractionToVerdict: (fields) => fields['amount'] == null
      ? const Reject('missing amount')
      : const Accept({'fields': fields}),
);
```

### 15.5 A/B prompt rollout (registry)

```dart
PromptConfigRegistry.register(PromptConfig.policyDecider()); // 1.0.0
PromptConfigRegistry.register(newCandidate);                 // 1.1.0
// 90% of shards:
promptedPolicyWith(configId: 'policy-decider', configVersion: '1.0.0', ...);
// 10% of shards:
promptedPolicyWith(configId: 'policy-decider', configVersion: '1.1.0', ...);
```

### 15.6 Replayable audit (journal + replay)

Record with a `RecordingJournal`, store `toJson()`, rebuild with
`ReplayJournal` — decisions reproduce byte-for-byte and the adapter
never runs. See §7.3.

---

## 16. What prompted policy can't do

| Concern | Where it lives |
|---|---|
| LLM SDK adapters (OpenAI, Anthropic, Gemini) | Satellite packages / user code — wrap in `PromptFunction` |
| Retry logic, rate limiting, cost budgeting | User code inside the adapter |
| Prompt tuning from outcomes | Phase 9 |
| `promptedAnnotations()` (LLM as decision support) | Phase 9 |
| Sampling (LLM on N% of decisions) | v1.2 |
| Prompt versioning migration tool | v1.2 |
| Multi-LLM voting in one config | v1.2 — one config targets one prompt |
| Streaming verdicts | Out of scope — verdicts must be atomic |
| Adversarial prompt-injection defense | Phase 5's guardrail module + the structural-first boundary |
| Vendor-specific prompt optimization | Adapter layer — the framework's contract is the rendered prompt |

The layer is deliberately small: **render → call → parse**, governed
by the journal and the cache. Everything transport-shaped belongs
outside the framework.
