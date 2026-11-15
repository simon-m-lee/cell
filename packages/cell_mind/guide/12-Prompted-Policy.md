# Guide 12 — Prompted Policy (`cell_mind 1.1.0`)

*Prompt-driven policy: turn a cell's `Context` into a prompt, query any
AI, parse the answer back into a `Verdict` — with verdict caching and
stateful chat sessions.*

| | |
|---|---|
| **Module** | `prompt` (Phase 8 + 8.1) |
| **Version** | Stable since `cell_mind 1.1.0` |
| **Public surface** | `promptedPolicy`, `promptedPolicyWith`, `PromptedPolicy`, `PromptConfig`, `PromptExample`, `PromptConfigRegistry`, `PromptSession`, `ChatMessage`, `ChatRole`, `SessionMode`, `VerdictCache`, `InMemoryVerdictCache`, `VerdictCacheKey`, `VerdictCacheEntry`, `conform`, `PromptEffect`, `VerdictCacheHitEffect`, `SessionInitializedEffect`, `SessionAppendedEffect`, `SessionClearedEffect`, `SessionCompactedEffect`, `renderContext`, `renderDecision`, `parseVerdict` |
| **Ships in** | `lib/src/prompt_policy.dart`, `lib/src/prompt_config.dart`, `lib/src/prompt_session.dart`, `lib/src/verdict_cache.dart` |

---

## 1. What prompted policy is

The prompted policy layer turns a cell's `Context` into a prompt, sends
it to an AI, and parses the AI's response back into a `Verdict`
(`Accept` / `Reject` / `Defer`) that composes with `cognitive()`.

The requirement it fulfils, restated:

> *A prompt configuration, universal to LLMs, can be provided to Mind
> to query the AI prompt for verdict. The verdict for a given policy on
> a Pulse with a given PulseContext should be saved so that the same
> verdict can be served without a prompt call. The configuration should
> be able to connect to a dedicated or user-defined Context window (or
> chat session).*

Three orthogonal capabilities over one shared pipeline:

1. **Prompted policy** — inline and config-driven modes.
2. **Verdict caching** — a two-tier fast path (verdict cache → prompt
   cache → LLM).
3. **Chat sessions** — a stateful conversation window, dedicated to one
   policy or shared across policies.

A minimal example:

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.policyDecider(),
  prompt: (prompt) async => mySdk.complete(prompt), // ~10-line adapter
  journal: journal,
);

final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),        // structural gate (runs first)
  verdictPolicy: policy,         // LLM nuance (runs second)
  onDeferred: approvalResolver(queue),
);
```

The evaluation order is the trust model of the framework:

1. **Principal rule** (`cell.validate`)
2. **Structural policy** (`contextAware()`, `domainPolicy()`, …)
3. **LLM verdict** — behind both cache tiers
4. **Deferral** (`onDeferred` → `ApprovalQueue`)

---

## 2. Two modes (inline + config)

| Mode | API | Session default | Cache |
|---|---|---|---|
| **Inline** | `promptedPolicy(...)` | `stateless` | Per-instance |
| **Config** | `promptedPolicyWith(config:)` | `config.sessionMode` | Config-keyed |

`promptedPolicy(...)` constructs a `PromptConfig` with a per-instance
id (`_inline_<uuid>`) and `SessionMode.stateless`, then delegates to
`promptedPolicyWith`. One renderer, one parser, two caches, one
journal-effect family — no duplicated pipeline.

```dart
// Inline — one-off, per-instance caches.
final policy = promptedPolicy(
  prompt: mySdk.complete,
  journal: journal,
  verdictCache: sharedCache, // optional shared memoization
);

// Config — reusable, versionable, session-capable.
PromptConfigRegistry.register(PromptConfig.policyDecider());
final policy = promptedPolicyWith(
  configId: 'policy-decider',
  prompt: mySdk.complete,
  journal: journal,
);
```

Inline mode does not support dedicated/shared sessions directly —
sessions are a stateful concern that belongs in a portable config.
Inline mode still benefits from verdict caching.

---

## 3. Why Context IS the prompt

There is **no separate "prompt" field on `Context`**. Every `Ontology`
and `Mandate` dimension is prompt material. The renderer walks the
typed dimensions in the framework's **declaration order**:

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

- **Fixed iteration order** — `Ontology.values` then `Mandate.values`,
  never map order.
- **Sorted JSON** — map values render key-sorted.
- **ISO-8601 UTC** — every date value.
- **Empty dimensions omitted.**
- **Pulse timestamps are not rendered** — they change on every
  emission and would break both caches and replay.

These guarantees are what make the fingerprints, the caches, and the
replay byte-exact. A custom renderer that iterates a map in insertion
order silently breaks all three — §18 explains how to extend safely.

---

## 4. The three-tier pipeline (verdict cache → prompt cache → LLM)

Every decision flows through **three lookup points**:

```
Decision arrives
      │
      ▼
Compute fingerprints        (fast: SHA-256 incl. session)
      │
      ▼
┌──────────────────────────────┐
│ Verdict cache lookup          │  Key: hash(config, ctx-fp, pulse-ctx-fp,
│ Hit → return Verdict          │        decision-fp, session-fp)
│ Skip render, prompt cache,    │
│ LLM; NO session mutation      │
└────────────┬─────────────────┘
             │ Miss
             ▼
Render prompt (incl. session)
             │
             ▼
┌──────────────────────────────┐
│ Prompt cache lookup           │  Key: hash(config, renderedPrompt)
│ Hit → append to session,      │  Skip LLM
│ populate verdict cache,       │
│ journal cache-hit effect      │
└────────────┬─────────────────┘
             │ Miss
             ▼
LLM call → parse → Verdict
             │
             ▼
Append to session (if active)
             │
             ▼
Populate prompt cache + verdict cache
             │
             ▼
Return Verdict
```

**Why two caches?**

- **Verdict cache** — input-keyed. Skips rendering and the prompt-cache
  lookup. Correct when the same `(policy, context, pulse, session)`
  recurs.
- **Prompt cache** — output-keyed. Skips the LLM call but still
  renders. Correct when two inputs render identically (e.g. a fresh
  policy instance with the same config and an empty session).

The default is **both on**; each has an independent TTL
(`PromptConfig.cacheTtl`, `PromptConfig.verdictCacheTtl`) and either
can be disabled with `Duration.zero`.

Measured (micro-benchmark, microtask adapter): ~1.7k full cache-miss
decisions/s, ~5.8k prompt-cache-hit decisions/s, ~6.5k verdict-cache-hit
decisions/s. Against a real LLM (500 ms–2 s) the verdict-cache hit is a
~100,000× speedup.

---

## 5. Prompt format schema

### 5.1 Stateless prompt

```text
<systemPrompt>

### Example 1
...

## Context

- domains: finance,audit
- constraints: {"max_amount":10000}

## Decision

- type: pulse
- payload: {"amount":5000}
- actor: system
- confidence: 0.95

## Expected Output

{"type":"object","required":["verdict"],...}
```

### 5.2 Session-aware prompt

A non-empty session inserts the history between the examples and the
current request:

```text
<systemPrompt>

### Example 1
...

## Conversation History

### User
## Context
- domains: finance
- constraints: {"max_amount":10000}

## Decision
- type: pulse
- payload: {"amount":20000}

### Assistant
{"verdict":"reject","reason":"amount exceeds max_amount"}

## Current Request

## Context
...

## Decision
...

## Expected Output

{ JSON schema }
```

- **User messages include the Context.** If the cell's context changes
  between turns, the LLM sees the change — the Context governs the
  decision, not the session.
- **Assistant messages are raw JSON.** The full verdict response is
  preserved.
- **An empty session renders exactly like a stateless prompt** — and
  shares the stateless cache keys (its fingerprint is `''`).

---

## 6. The trust boundary

The LLM **cannot bypass structural policy**. `cognitive()` evaluates:

1. **Principal rule** (`cell.validate`)
2. **Policy** (structural gates)
3. **VerdictPolicy** — the prompted policy, behind both caches
4. **`onDeferred`** if the verdict is `Defer`

If (1) or (2) rejects, no fingerprint is computed, no cache is
consulted, and the adapter is never invoked. Caching and sessions are
post-structural by construction (D16).

**Recommended pattern:**

```dart
final handle = cognitive(
  cell: cell,
  policy: contextAware(),
  verdictPolicy: promptedPolicyWith(
    config: PromptConfig.policyDecider(),
    prompt: myLLM,
    journal: journal,
  ),
  onDeferred: approvalResolver(queue),
);
```

**Anti-pattern — the LLM decides everything:**

```dart
cognitive(
  cell: cell,
  policy: TestCell.allowAll,  // ← empty structural gate
  verdictPolicy: promptedPolicyWith(...),
);
```

Dangerous because a prompt-injected payload, a hallucinated "accept",
or a model regression becomes a single point of failure. Acceptable
only for sandboxed experiments and non-critical pipelines — document
it loudly.

---

## 7. Determinism via journal + caches

### 7.1 The journal effects

Six effect types cover the whole decision surface (`EffectJournal`
labels in parentheses):

| Effect | Label | When |
|---|---|---|
| `PromptEffect` | `mind.prompt` | LLM call — full prompt + response, `cacheKey`, `sessionFingerprint`, `sessionId` |
| `VerdictCacheHitEffect` | `mind.prompt.cache.hit` | Either cache served the verdict — `cacheKey` + verdict |
| `SessionInitializedEffect` | `mind.session.init` | First decision with an active session |
| `SessionAppendedEffect` | `mind.session.append` | Successful decision — the `(user, assistant)` pair |
| `SessionClearedEffect` | `mind.session.clear` | `clearSession()` |
| `SessionCompactedEffect` | `mind.session.compact` | Compaction — the dropped-pair count |

Plus one internal **disposition** record (`mind.prompt.disposition`)
per decision: the journal-driven dispatcher that records which branch
(verdict hit / prompt hit / LLM / too-long) the decision took.

### 7.2 Replay

Recording and replay take **identical branches** because the
disposition is journaled: replay serves the recorded disposition, so a
recorded verdict-cache hit never falls through to an LLM call, and a
recorded LLM call never turns into a cache hit. Session exchanges are
applied from the served effect maps on both sides, so the conversation
is reconstructed exactly — the next decision's fingerprints match.

```dart
final recording = RecordingJournal();
// ... run decisions with the same config instance ...

final replay = ReplayJournal(
  recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
);
// ... re-run the SAME decisions with the SAME config instance ...
replay.assertExhausted();
```

- **The adapter never runs on replay.**
- **A changed config or session state diverges loudly**
  (`ReplayDivergenceException`) at the first mismatched input digest —
  stronger than a silent fail-closed reject.
- **Replay requires the same config instance** for dedicated sessions
  (the config id participates in the verdict cache key, which is the
  disposition input). For stateless replay with fixed-id configs, the
  ids match by construction.

---

## 8. Verdict cache deep dive

```dart
abstract interface class VerdictCache {
  VerdictCacheEntry? lookup(VerdictCacheKey key);
  void store(VerdictCacheKey key, VerdictCacheEntry entry);
  void clear();
  int get size;
  void evictExpired();
}
```

- **`VerdictCacheKey`** — the five input fingerprints:
  `(configId, configVersion, cellContextFingerprint,
  pulseContextFingerprint, decisionFingerprint, sessionFingerprint)`.
  `fingerprint` is the sha256 of the joined components — the map key.
- **`VerdictCacheEntry`** — `(verdict, at)`; `at` drives TTL.
- **`InMemoryVerdictCache`** — the default: TTL-bounded, LRU-evicted
  (`ttl`, `maxEntries`; defaults from the config's `verdictCacheTtl` /
  `maxVerdictCacheEntries`).

**Identity rules (D3):**

- `config.version` participates — a version bump invalidates
  everything.
- `sessionFingerprint` participates — any conversation change
  invalidates entries for that session state.
- Fingerprints cover exactly the dimensions the renderer emits
  (`traceId` included; pulse timestamps never rendered and never
  fingerprinted).

**Design notes:**

- `lookup` / `store` are **synchronous** — the cache sits on the hot
  path. Distributed backends should wrap their async client in a
  synchronous in-memory layer for hot keys.
- `ttl: Duration.zero` disables the cache; expired entries miss on
  lookup and vanish on `evictExpired`.
- **Population order (D14):** append to the session first, then store
  under the **post-append** key — a repeat of the same decision with
  the evolved session state hits the entry; a repeat decision does
  **not** create a new conversation turn.

---

## 9. Session deep dive — `ChatMessage`, `PromptSession`, `SessionMode`, compaction

### 9.1 Primitives

```dart
enum ChatRole { system, user, assistant }

final class ChatMessage {
  final ChatRole role;
  final String content;
  // toMap / fromMap, value equality
}

final class PromptSession {
  final String id;
  final int maxMessages;   // default 40
  final int maxChars;      // default 20000
  List<ChatMessage> get messages;   // unmodifiable view
  int get length;
  int get totalChars;
  bool get isEmpty;
  void append(ChatMessage message);
  void appendExchange(ChatMessage user, ChatMessage assistant);
  void clear();
  String fingerprint();
  // toMap / fromMap
}
```

- **Sessions are per-decision, not per-prompt.** The session
  accumulates `user` + `assistant` pairs as decisions are made.
- **Append-only between clears.** No editing, no deleting individual
  messages; `clear()` resets entirely.
- **Fingerprints exclude timestamps** — two sessions with identical
  content fingerprint identically, so identical conversations share
  verdict cache keys even when created at different times.
- **Empty sessions fingerprint to `''`** — stateless and empty-session
  decisions share cache keys and prompt layouts.

### 9.2 Session modes

```dart
enum SessionMode { stateless, dedicated, shared }
```

| Mode | Creation | Sharing | Use case |
|---|---|---|---|
| `stateless` | None | N/A | Independent decisions (default) |
| `dedicated` | Auto | One policy | Per-policy conversation tracking |
| `shared` | User | Many policies | Multi-agent coordination |

- `dedicated`: the factory auto-creates a session exposed via
  `PromptedPolicy.session`.
- `shared`: the `session:` argument is **required** (throws otherwise)
  and used directly — mutations are visible immediately across every
  policy holding it.
- A `session:` argument is ignored in every other mode.
- Inline mode is always `stateless`.

### 9.3 Compaction (deterministic, journaled)

| Trigger | Action |
|---|---|
| `messages.length > maxMessages` | Drop oldest non-system pairs until under |
| `totalChars > maxChars` | Drop oldest non-system pairs until under |
| No pairs left, still over | Drop oldest system message (except the first) |
| Nothing droppable | Keep (never partially destroy a pair) |

- Pairs are **never partially dropped**.
- System messages are protected while pairs remain droppable.
- Every compaction journals `SessionCompactedEffect` with the
  dropped-pair count; replay validates the count against its own
  deterministic compaction.
- The same message sequence with the same thresholds always produces
  the same compacted state.

---

## 10. Session rendering format

A non-empty session renders as Markdown blocks (§5.2):

```
## Conversation History

### User
<turn 1 user content>

### Assistant
<turn 1 verdict JSON>

### System
<system message content>     ← if present

## Current Request

<current template substitution>
```

- **Roles choose the heading** — `User` / `Assistant` / `System`.
- **User messages store the template-substituted current request** of
  their turn (context + decision blocks for the default template).
- **Assistant messages store the raw response JSON** — the LLM sees
  exactly what it produced.
- The history is byte-for-byte deterministic; custom session rendering
  is deferred to v1.2.

---

## 11. Session journal + replay

**Effect flow per decision with an active session:**

1. `SessionInitializedEffect` — first decision only; input = the
   session fingerprint at init (dedicated: empty; shared:
   pre-populated state).
2. Disposition — the recorded branch.
3. Branch effects — `VerdictCacheHitEffect` (cache hits; **no** append)
   or `PromptEffect` + `SessionAppendedEffect` (+
   `SessionCompactedEffect` on drops).
4. `SessionClearedEffect` — fire-and-forget on `clearSession()`, in
   journal invocation order.

**Replay reconstruction:** the disposition is served; append effects
are applied from the served maps (never from the live closures), so
both sides mutate the session identically; compaction counts are
validated by input digests; the next decision's fingerprint inputs
therefore match the recording.

**Failure modes:** a mutated session between recording and replay
surfaces as a `ReplayDivergenceException` at the first fingerprint
mismatch. This is the stronger, loud version of the plan's
`Reject('session-mismatch')`.

**Note:** calling `session.clear()` directly does not journal; use
`PromptedPolicy.clearSession()` for replayable clears.

---

## 12. Session + cache interaction

- **The session fingerprint is part of the verdict cache key.** The
  same decision with a different history is a different key — the LLM
  sees different context and may legitimately answer differently.
- **Verdict cache hits do NOT append to the session** (D14). A repeat
  decision is not a new conversation turn.
- **Prompt cache hits DO append** — the decision renders, the exchange
  is appended, and the effective cache hit is journaled.
- **Population order is strict** (D14): LLM → parse → append →
  populate prompt cache → populate verdict cache (post-append key) →
  journal → return.
- **Failed calls and parse failures neither append nor cache** (D17):
  `Reject('parse-error-*')`, `Reject('prompt-error')`,
  `Reject('prompt-timeout')`, `unknown-verdict` are excluded.
  Classifier business rejects are **not** excluded — they are
  legitimate decisions.
- **Session sharing across policies:** identical fingerprints across
  two sessions imply identical keys — content-addressing makes the
  sharing safe by construction.

---

## 13. `PromptConfig` reference

```dart
final class PromptConfig {
  final String id;
  final String version;                 // bump invalidates both caches
  final String description;
  final String systemPrompt;
  final String userTemplate;            // {{context}} / {{decision}}
  final Map<String, dynamic> outputSchema;
  final List<PromptExample> examples;
  final Map<String, dynamic> parameters;
  final Duration cacheTtl;              // prompt cache TTL; zero disables
  final Duration verdictCacheTtl;       // verdict cache TTL; zero disables
  final int maxVerdictCacheEntries;     // default 10000
  final SessionMode sessionMode;        // default stateless
  final int maxSessionMessages;         // default 40
  final int maxSessionChars;            // default 20000
  final int maxPromptChars;             // default 32000
}
```

**Factories:** `policyDecider`, `classifier(labels:)`,
`extractor(fields:)`, `custom(...)` — the presets are plain instances;
copy one and change any field.

**`render`** now accepts an optional `session:` and returns the
session-aware layout when the session is non-empty.

**Serialization** round-trips every field (`cacheTtl` /
`verdictCacheTtl` in milliseconds, `sessionMode` by name).

**`validate()`** checks structure, not semantics: non-empty
id/version/systemPrompt/userTemplate; a response shape in the schema;
non-negative TTLs; `maxVerdictCacheEntries >= 1`;
`maxSessionMessages >= 2`; `maxSessionChars >= 100`;
`maxPromptChars >= 100`; example responses parse against the schema.
Whether the LLM will comply is measured by `conform`, not `validate`.

---

## 14. The three presets

### 14.1 `policyDecider` — accept / reject / defer

Id `policy-decider`, version `1.0.0`. The model answers
`{"verdict": ...}` with reason/resolver/confidence/annotations; the
verdict flows into the decision log verbatim. Ships three few-shot
examples.

### 14.2 `classifier` — label → verdict

Id `classifier`, version `1.0.0`. The model answers
`{"label": "<one of the labels>"}`; `labelToVerdict` converts:

```dart
promptedPolicyWith(
  config: PromptConfig.classifier(labels: ['spam', 'ham']),
  prompt: myLLM,
  journal: journal,
  labelToVerdict: (label) =>
      label == 'spam' ? const Reject('spam detected') : const Accept(),
);
```

### 14.3 `extractor` — fields → verdict

Id `extractor`, version `1.0.0`. The model answers
`{"fields": {...}}`; `extractionToVerdict` converts:

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

Missing converters fail closed with `Reject('missing-label-to-verdict')`
/ `Reject('missing-extraction-to-verdict')`.

---

## 15. Serialization and versioning

### 15.1 The config as a file

```dart
import 'dart:convert';
import 'dart:io';

final encoded = jsonEncode(PromptConfig.policyDecider().toMap());
File('configs/policy-decider.json').writeAsStringSync(encoded);

final config = PromptConfig.fromMap(
  jsonDecode(File('configs/policy-decider.json').readAsStringSync())
      as Map<String, dynamic>,
);
PromptConfigRegistry.register(config);
```

### 15.2 Session persistence

Sessions are in-memory; save via `toMap()` and restore via
`PromptSession.fromMap(...)` — pass the restored session as `session:`
in `SessionMode.shared`.

### 15.3 The versioning workflow

1. Change the prompt; **bump `version`** (invalidates both caches).
2. Load, register, `conform` against the target model.
3. Deploy; the registry serves the highest version.
4. Roll back by pinning `configVersion:` — no code deploy.

---

## 16. The registry (A/B testing, rollback)

```dart
class PromptConfigRegistry {
  static void register(PromptConfig config);
  static PromptConfig? lookup(String id, {String? version});
  static List<PromptConfig> list({String? id});
  static void unregister(String id, {String? version});
}
```

- `lookup(id)` resolves the **highest semantic version** (`1.10.0` >
  `1.9.0`).
- `lookup(id, version: v)` pins exactly — the rollback lever.
- `promptedPolicyWith(configId:, configVersion:)` wires registry
  lookup directly.

```dart
// A/B: 90% stable, 10% candidate.
final stable = promptedPolicyWith(
  configId: 'policy-decider', configVersion: '1.0.0', ...);
final candidate = promptedPolicyWith(
  configId: 'policy-decider', configVersion: '1.1.0', ...);
```

---

## 17. Conformance testing

`conform` is a first-class API, not a test helper — the deploy gate for
a config against a specific LLM.

```dart
final report = await conform(
  config: config,
  prompt: myLLM,               // the REAL adapter — users pay per run
  cases: [
    ConformanceCase(context: ctx, decision: d1, expected: const Accept()),
    ConformanceCase(
      context: ctx,
      decision: d2,
      expected: const Reject('amount exceeds max_amount'),
    ),
    ConformanceCase(context: ctx, decision: d3, expected: const Defer('approval')),
  ],
);
if (!report.passedAll) { /* block deploy */ }
```

- **Comparison:** same verdict type; `Reject` also compares `reason`;
  `Defer` also compares `resolver`. Annotations are deliberately not
  compared (the parser adds `reason`/`confidence`).
- **`conform` bypasses caches and sessions** (D18) — it measures LLM
  behavior, not cache behavior.
- Pass the optional `journal:` so a recorded run replays for free.
- `conform` validates the config first — malformed configs throw
  `ArgumentError` before any LLM call.

---

## 18. Custom renderers

The primitives are replaceable; the defaults are public functions so
you can **compose, don't replace**:

```dart
final policy = promptedPolicy(
  prompt: myLLM,
  journal: journal,
  contextRenderer: (context) => '${renderContext(context)}\n- env: prod',
  decisionRenderer: (object, {host, arguments}) =>
      '${renderDecision(object, host: host, arguments: arguments)}\n- tag: x',
  verdictParser: parseVerdict, // or a custom fail-closed parser
);
```

**Determinism contract (mandatory):**

- Sort map keys before emitting JSON.
- Never emit wall-clock values that change between runs.
- Keep the output a pure function of `(context, decision)`.
- A custom parser owns the raw response entirely (the default
  verdict/label/fields dispatch runs only without one) and must return
  `Reject(...)` instead of throwing.

---

## 19. Cost control

| Lever | Where | Effect |
|---|---|---|
| Structural gate first | `policy:` slot | rejects never reach the caches or LLM |
| `verdictCacheTtl` | `PromptConfig` | repeat decisions skip render AND LLM |
| `cacheTtl` | `PromptConfig` | near-duplicate prompts skip the LLM |
| Version bumps | `PromptConfig.version` | deliberate invalidation |
| `maxSessionMessages` / `maxSessionChars` | `PromptConfig` | bounded history |
| `maxVerdictCacheEntries` | `PromptConfig` | bounded memory |
| `maxPromptChars` | `PromptConfig` | over-long prompts fail closed without a call |
| Shared `VerdictCache` | `promptedPolicyWith(verdictCache:)` | cross-policy memoization |

One adapter call per *distinct* `(config, context, decision, session)`
state per TTL window. Argument-level rule evaluations never reach the
LLM — the adapter decides about the command *with* its arguments at
the command decision.

Not in scope (user code): retries, rate limiting, cost budgeting,
sampling, multi-LLM voting, distributed cache backends.

---

## 20. Common patterns

### 20.1 Multi-turn chat (dedicated session)

```dart
final policy = promptedPolicyWith(
  config: PromptConfig.custom(
    id: 'chat',
    version: '1.0.0',
    description: 'multi-turn',
    systemPrompt: defaultSystemPrompt,
    userTemplate: '{{context}}\n\n{{decision}}',
    sessionMode: SessionMode.dedicated,
  ),
  prompt: myLLM,
  journal: journal,
);
// Decisions 2+ render the conversation history; policy.session
// exposes the accumulated turns.
```

### 20.2 Per-policy sessions (dedicated, N policies)

Each factory call creates its own session — independent conversations
for independent gates.

### 20.3 Cross-agent coordination (shared session)

```dart
final window = PromptSession(id: 'agents');
final agentA = promptedPolicyWith(
  config: config, prompt: llmA, journal: journal, session: window);
final agentB = promptedPolicyWith(
  config: config, prompt: llmB, journal: journal, session: window);
// Each agent's decisions become turns the other agent sees.
```

### 20.4 Verdict-cache demo

Emit the same pulse twice: the second decision is a verdict cache hit
— the adapter is not called, no session turn is appended, and a
`VerdictCacheHitEffect` is journaled.

### 20.5 HIPAA-adjacent triage (structure + LLM + human)

```dart
final handle = cognitive(
  cell: recordsGate.cell,
  policy: compliancePolicy() + confidencePolicy(),
  verdictPolicy: promptedPolicyWith(
    config: PromptConfig.policyDecider(systemPrompt: '$defaultSystemPrompt\n'
        'Never accept decisions touching PHI unless the Context declares '
        'HIPAA compliance.'),
    prompt: myLLM,
    journal: journal,
  ),
  onDeferred: approvalResolver(ApprovalQueue(journal: journal)),
);
```

### 20.6 A/B rollout + replayable audit

Registry pinning (§16) plus recording/replay (§7.2): record with a
`RecordingJournal`, rebuild with `ReplayJournal` — decisions, sessions,
and cache branches reproduce byte-for-byte and the adapter never runs.

---

## 21. What prompted policy can't do

| Concern | Where it lives |
|---|---|
| LLM SDK adapters (OpenAI, Anthropic, Gemini) | Satellite packages / user code — wrap in `PromptFunction` |
| Distributed verdict caches (Redis, …) | User implementation of `VerdictCache` |
| Session persistence to disk | User code (`toMap` / `fromMap`) |
| Session summarization / hierarchical compaction | Phase 9 |
| `promptedAnnotations()` + prompt tuning from outcomes | Phase 9 |
| Retries, rate limiting, cost budgeting | User code inside the adapter |
| Sampling, multi-LLM voting, session branching | v1.2 |
| Streaming verdicts | Out of scope — verdicts must be atomic |
| Adversarial prompt-injection defense | Phase 5's guardrail module + the structural-first boundary |
| Vendor-specific prompt optimization | Adapter layer |

The layer is deliberately small: **fingerprint → cache → render →
cache → call → parse → session**, governed by the journal. Everything
transport-shaped belongs outside the framework.

---

## Appendix A — Effect field reference

### `PromptEffect` (`label: 'mind.prompt'`, schema `1.1.0`)

| Field | Type | Meaning |
|---|---|---|
| `configId` | `String` | The config id |
| `configVersion` | `String` | The config version |
| `cacheKey` | `String` | The verdict cache key fingerprint |
| `contextHash` | `String` | SHA-256 of the rendered context fragment |
| `decisionHash` | `String` | SHA-256 of the rendered decision fragment |
| `sessionFingerprint` | `String?` | Session fingerprint at call time; `null` when stateless |
| `sessionId` | `String?` | Session id; `null` when stateless |
| `prompt` | `String` | The full rendered prompt (audit) |
| `response` | `String` | The full model response (replay) |
| `at` | `DateTime` | Millisecond-truncated capture time |
| `latency` | `Duration` | Call latency |

### `VerdictCacheHitEffect` (`label: 'mind.prompt.cache.hit'`)

| Field | Type | Meaning |
|---|---|---|
| `configId` / `configVersion` | `String` | The config |
| `cacheKey` | `String` | The verdict cache key that hit |
| `verdict` | `Verdict` | The served verdict |
| `at` / `lookupLatency` | `DateTime` / `Duration` | Timing |

### Session effects

| Effect | `label` | Payload |
|---|---|---|
| `SessionInitializedEffect` | `mind.session.init` | `sessionId`, `initialMessages[]`, `at` |
| `SessionAppendedEffect` | `mind.session.append` | `sessionId`, `userMessage`, `assistantMessage`, `at` |
| `SessionClearedEffect` | `mind.session.clear` | `sessionId`, `at` |
| `SessionCompactedEffect` | `mind.session.compact` | `sessionId`, `droppedPairs`, `at` |

All four reconstruct via `sessionEffectFromMap`; the cache-hit effect
via `verdictCacheHitEffectFromMap`; the prompt effect via
`promptEffectFromMap`.

---

## Appendix B — Journal label quick reference

| Label | Recorded by | Replay behavior |
|---|---|---|
| `mind.prompt.disposition` | Every decision | Serves the recorded branch (verdict-hit / prompt-hit / llm / too-long) |
| `mind.prompt.cache.hit` | Cache-served decisions | Serves the recorded verdict; no adapter, no render |
| `mind.prompt` | LLM-call decisions | Serves the recorded response; input digest = full prompt |
| `mind.session.init` | First decision with a session | Validates the initial session fingerprint |
| `mind.session.append` | Successful decisions (session active) | Serves the recorded pair; applied identically on both sides |
| `mind.session.compact` | Compaction drops | Validates the post-compaction fingerprint + drop count |
| `mind.session.clear` | `clearSession()` | Validates the pre-clear fingerprint; fire-and-forget, invocation-ordered |

---

## Appendix C — Fail-closed reason vocabulary (cache + session)

| Reason | Origin |
|---|---|
| `prompt-too-long` | Rendered prompt exceeds `maxPromptChars` (no call, no cache) |
| `prompt-error` / `prompt-timeout` | Adapter failure (journaled, never cached, never appended) |
| `parse-error-invalid-json` / `parse-error-no-json` | Malformed / missing JSON (never cached) |
| `missing-verdict` / `unknown-verdict:<v>` | Schema violations (never cached) |
| `missing-reason` / `defer-missing-resolver` | Reject/Defer shape violations (never cached) |
| `missing-label-to-verdict` / `missing-extraction-to-verdict` | Missing preset converters (never cached) |
| `label-to-verdict-failed` / `extraction-to-verdict-failed` | Converter threw (never cached) |
| `missing-label` / `missing-fields` | Non-string label / non-map fields (never cached) |

Business rejections produced by the model (any other `Reject` reason,
including classifier labels) ARE cached and ARE appended to sessions.

---

## Appendix D — FAQ

**Q: Why does a repeat decision sometimes still call the LLM?**

Because a successful decision appended a turn to the session: the
session fingerprint changed, so the new key is different. Repeat the
decision again without a session change and it hits. Stateless
policies never have this effect.

**Q: Why do I see `mind.prompt.disposition` in my journal?**

It is the internal dispatcher that makes recording and replay take the
same branch. It is not a public effect type and is intentionally
separate from the audit effects.

**Q: Can I share one session across two different configs?**

Yes — `SessionMode.shared` with the same `PromptSession`. The
fingerprint is content-only, so both policies see the same history and
key off it consistently.

**Q: Does clearing the session clear the caches?**

No. `clearSession()` resets the conversation only. The verdict cache
keys include the session fingerprint, so cleared-state decisions key
differently from pre-clear entries; the prompt cache keys include the
rendered prompt, so an empty-session render may legitimately hit a
stateless-era entry — that is correct output-keyed behavior.

**Q: How do I make replay work across process restarts?**

Persist `recording.toJson()` and re-load the config (`fromMap`) with
the same id/version, then re-run the identical decision sequence under
a `ReplayJournal`. Sessions must be re-populated identically
(`PromptSession.fromMap`) before replay.

**Q: What happens if my cache returns a stale verdict after an LLM
provider change?**

Bump `PromptConfig.version` — the version participates in every cache
key and invalidates both tiers. This is the documented upgrade path.
