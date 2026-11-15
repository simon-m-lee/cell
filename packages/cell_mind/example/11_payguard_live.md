# Walkthrough — `example/11_payguard_live.dart`

*A real-life payment gateway governed by `cell_mind`, driven by a live
DeepSeek LLM — every phase of the framework in one executable.*

| | |
|---|---|
| **File** | `example/11_payguard_live.dart` (~670 lines) |
| **Scenario** | PayGuard: a payment gateway with LLM risk review, caching, chat sessions, human approval, offline learning, XAI, and replay |
| **Live LLM** | DeepSeek chat completions via `.deepcode/settings.json` (repository root) or `DEEPSEEK_*` environment variables |
| **Offline fallback** | Deterministic mock adapter — the example always runs, even with no API key |
| **Run** | `dart run example/11_payguard_live.dart [--conformance]` |

---

## 1. What this example is

PayGuard is a fictional payment processor. Every transaction that
arrives is governed in five narrowing layers:

```
customer pulse
   │
   ▼ 1. structural policy      domain + compliance + confidence  (Phase 1)
   │
   ▼ 2. prompted verdict       DeepSeek LLM, three-tier cache    (Phase 8/9)
   │
   ▼ 3. deferral               large amounts → ApprovalQueue     (Phase 4)
   │
   ▼ 4. decision log           every outcome recorded            (Phase 2)
   │
   ▼ 5. learning + XAI         outcomes train a bandit;          (Phases 3/6)
   │                           narratives explain the log
```

The example walks this pipeline **twice over**: once forward with a
live model, and once **backward** through `ReplayJournal` — where the
adapter never runs and the recorded verdicts reproduce exactly.

**Hard vs soft checks.** The run prints `✓` for every satisfied
check. *Hard* checks pin framework guarantees (caching, journaling,
defer routing, replay) and fail the run when violated. *Soft* checks
pin model behaviour — a live LLM can legitimately deviate, so they
warn (`⚠`) without failing.

---

## 2. The scenario data

| Transaction | Amount | Merchant | Expected model verdict | Framework path |
|---|---|---|---|---|
| TX-1001 | 125 | blue-bottle-coffee | accept | live call → verdict cache → prompt cache |
| TX-1002 | 9500 | luxury-watch | defer → approval | ApprovalQueue, two-decision audit pair |
| TX-1003 | 300 | suspicious-crypto | reject | recorded business rejection |
| TX-1004 | 42 | book-store | accept | session history visible in prompt |
| refund | 300 | command `approveRefund` | accept | command decision with arguments |
| TX-1005 | 4999 | stationery-co | accept × 2 | two reviewers, one shared session |
| TX-9001 | 125 | replay-cafe | accept | recorded once, replayed without the LLM |
| TX-8001 | 9999 | conformance-check | defer `approval` | `--conformance` deploy gate |

The **system prompt** given to DeepSeek encodes the same rules
(rule 1 suspicious merchant → reject, rule 2 amount ≥ 5000 → defer
with resolver exactly `approval`, rule 3 commands → accept, rule 4
otherwise → accept with confidence 0.9–1.0). The mock adapter
implements the identical rules, so offline runs exercise the same
paths.

---

## 3. Prerequisites and DeepSeek configuration

No new dependencies — the adapter is `dart:io` + `dart:convert`.

The example resolves the LLM configuration in this order:

1. `settings.json` next to the working directory;
2. `.deepcode/settings.json` — the repository-root DeepSeek settings;
3. `../settings.json`, `../.deepcode/settings.json`,
   `../../settings.json`, `../../.deepcode/settings.json`;
4. environment variables `DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL`
   (default `https://api.deepseek.com`), `DEEPSEEK_MODEL` (default
   `deepseek-chat`).

The repository-root file has this shape (an `env` wrapper is also
tolerated as flat top-level keys):

```json
{
  "env": {
    "MODEL": "deepseek-v4-pro",
    "BASE_URL": "https://api.deepseek.com",
    "API_KEY": "sk-…"
  }
}
```

When **nothing** is found, the example prints a notice and runs the
deterministic mock adapter — every section still executes, every hard
check still passes.

Run it:

```bash
cd packages/cell_mind
dart run example/11_payguard_live.dart               # live DeepSeek
dart run example/11_payguard_live.dart --conformance # + deploy gate
```

Expect 8 live calls (9 with `--conformance`), roughly 15–40 seconds
depending on the model. Repeats cost nothing — that is the point of
the cache tiers.

---

## 4. The live output, end to end

```text
=== PayGuard — a live cell_mind payment gateway ===
DeepSeek settings: ../../.deepcode/settings.json
Model: deepseek-v4-pro   Base URL: https://api.deepseek.com

── 1. Structural gate — Phase 1 policy
  ✓ dedicated session auto-created

── 2. TX-1001 coffee — live verdict, then cached repeats
  ✓ the DeepSeek adapter was called exactly once
  ✓ model accepted the low-risk purchase
  ✓ the successful decision appended one (user, assistant) turn
  ✓ repeat decision was a verdict-cache hit (zero LLM calls)
  ✓ repeat served the cached verdict
  ✓ a cache hit does NOT append a conversation turn (D14)
  ✓ fresh verdict cache + warm prompt cache = prompt-cache hit (no LLM)
  ✓ the prompt-cache hit produced a decision

── 3. TX-1002 luxury watch — Defer → ApprovalQueue
  ✓ model deferred the large amount
  ✓ the approval queue received the request
  ✓ the approved value flows through queue.committed
  ✓ approval committed a follow-up Accept decision
  ✓ the audit shows the request + resolution pair

── 4. TX-1003 suspicious crypto — model rejection
  ✓ model rejected the suspicious merchant

── 5. TX-1004 book store — the conversation follows the money
  ✓ four gateway decisions accumulated eight messages
  ✓ the live prompt carried the conversation history
  ✓ the current request is separated from the history

── 6. Refund command — command decision with arguments
  ✓ the command decision was recorded

── 7. Shared session — two prompted reviewers, one window
  reviewer A: Instance of 'Accept'
  reviewer B: Instance of 'Accept'
  ✓ both reviewers called the LLM (different history each time)
  ✓ the shared window accumulated both agents' turns
  ✓ both verdicts are assistant turns in the shared window
  ✓ both reviewers accepted the compliant transaction

── 8. Outcomes feed the offline bandit (Phase 3 learning)
  ✓ outcomes were recorded per decision
  ✓ the trainer consumed the whole decision log
  learned 2 rule(s): {"version":1,"algorithm":"contextualBandit",
    "rules":[{"when":{"actor":"customer-app","compliance":"pci-dss",
    "domains":"payments","purpose":"purchase"},"action":"accept",
    "confidence":1.0,"support":6,"trainedIn":1}, …]}
  ✓ the bandit emitted at least one learned rule

── 9. XAI — explain the deferred transaction
  narrative: customer-app deferred the request to approval (confidence 95%)
  ✓ the narrative names the deferral
  ✓ explainPulse surfaces the follow-up resolution (newest first)

── 10. Replay — recorded governance re-runs without DeepSeek
  ✓ recording the replay scenario called the LLM once
  ✓ replay never re-invoked the DeepSeek adapter
  ✓ replay reproduced the recorded verdict
  ✓ replay journal exhausted cleanly

── Summary
  gateway decisions: 7  {accept: 5, defer: 1, reject: 1}
  DeepSeek calls: 8
  journal records: 23
  session turns: 10

=== PayGuard example complete: all hard checks passed ===
```

With `--conformance` one extra block appears:

```text
── 11. Conformance — deploy gate against the live model
  conformance: PASS (1/1, 100%)
```

---

## 5. Architecture of the example

```
 _DeepSeekSettings ── _loadSettings()   settings.json / .deepcode / env
        │
        ▼
 _Adapter.call(String) ── PromptFunction for every promptedPolicyWith
   ├─ live: POST {BASE_URL}/chat/completions (system/user split)
   ├─ mock: rule-based verdicts (same rules as the system prompt)
   ├─ counters: calls / failures / lastPrompt   ← the example's proof hooks
        │
        ▼
 PromptConfig "payguard-risk-review" (dedicated session)
        │
        ▼
 promptedPolicyWith ──▶ PromptedPolicy ──▶ cognitive(verdictPolicy:)
        │                                     │
        │                                     ├─ policy: contextAware + confidence
        │                                     ├─ onDeferred: approvalResolver(queue)
        │                                     └─ outcomes: recordOutcomes(handle)
        │
        ├─ TX-1001 … TX-1004, refund command ──▶ Decision log
        ├─ TX-1005 ×2 reviewers (SessionMode.shared, one window)
        └─ TX-9001 recorded → ReplayJournal → replayed (no adapter)
```

**Why the adapter counts calls and keeps the last prompt.** Caching,
replay, and session history are invisible from outside the framework;
the example *proves* them by observing the only external side effect
the pipeline has — the adapter invocation — plus the public
`PromptedPolicy.session`, the decision log, and the journal records.

---

## 6. Section-by-section walkthrough

### 6.1 — Structural gate (Phase 1 policy)

```dart
final gate = Cell.ingress<Map<String, dynamic>>(context: _paymentsContext);
final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(requireCompliance: true) + confidencePolicy(min: 0.7),
  verdictPolicy: riskPolicy,
  onDeferred: approvalResolver(queue),
);
```

`_paymentsContext` declares `domains: 'payments'`,
`compliances: 'PCI-DSS'`, and `constraints: {'max_amount': 5000}`.
Every transaction pulse carries matching provenance
(`Provenance.compliance.entry('PCI-DSS')`, confidence 0.95, a
`traceId`). The gate rejects anything without a compliance marker or
with confidence below 0.7 **before** the LLM is consulted — the
trust boundary that caching never crosses.

The first check — `riskPolicy.session != null` — confirms that
`SessionMode.dedicated` auto-created the conversation window.

### 6.2 — TX-1001: live verdict, then both cache tiers (Phase 8/9)

```dart
final tx1 = await ingestTx('TX-1001', 125, 'blue-bottle-coffee');
_expect(adapter.calls == 1, 'the DeepSeek adapter was called exactly once');
```

`ingestTx` ingests the pulse and **polls** the decision log until the
verdict lands — a live LLM call is asynchronous, so the fixed-delay
style of the other examples would race. This is an important
practical pattern for any real adapter.

Then the same transaction is re-ingested:

```dart
final callsBeforeRepeat = adapter.calls;
final tx1Repeat = await ingestTx('TX-1001', 125, 'blue-bottle-coffee');
_expect(adapter.calls == callsBeforeRepeat, '… verdict-cache hit …');
_expect(jsonEncode(tx1Repeat.verdict.toMap()) == jsonEncode(tx1.verdict.toMap()),
    'repeat served the cached verdict');
_expect(riskPolicy.session!.length == 2,
    'a cache hit does NOT append a conversation turn (D14)');
```

What happens inside: the fingerprints match → **verdict cache hit** →
`VerdictCacheHitEffect` journaled → the stored verdict is returned.
No render, no prompt cache, no adapter, and — per D14 — no new
conversation turn. (The verdict is reconstructed from its map, so the
check compares serialized forms rather than object identity.)

The **second tier** is exercised with a fresh policy instance over
the same config:

```dart
final secondHandle = cognitive(
  cell: secondGate.cell,
  policy: TestCell.allowAll,
  verdictPolicy: promptedPolicyWith(
    config: _riskConfig(id: 'payguard-risk-review', mode: SessionMode.dedicated),
    prompt: adapter.call, journal: RecordingJournal(),
  ),
);
```

The new instance gets a fresh per-instance verdict cache (miss), but
its first decision renders the **identical empty-session prompt** —
so the output-keyed **prompt cache** serves it and the adapter is
never called. This is the design distinction: the verdict cache is
input-keyed (skips rendering), the prompt cache is output-keyed
(skips the LLM but still renders and appends).

### 6.3 — TX-1002: Defer → ApprovalQueue (Phase 4)

```dart
final tx2 = await ingestTx('TX-1002', 9500, 'luxury-watch');
_expect(tx2.verdict is Defer, 'model deferred the large amount', hard: …);
_expect(queue.pending.length == 1, 'the approval queue received the request');
final requestId = queue.pending.keys.single;
await queue.approve(requestId);
await _awaitDecisions(handle, decisionsBeforeApprove + 1);
_expect(queue.committed.value?['id'] == 'TX-1002',
    'the approved value flows through queue.committed');
```

Wave-honest deferral: the pulse is dropped from the wave, the `Defer`
decision is recorded immediately, `approvalResolver(queue)` submits
the request out-of-band, and the human (here simulated by
`queue.approve`) commits a **follow-up `Accept` decision** linked by
`decisionId`. The final check counts two TX-1002 decisions — the
audit pair. The approved value travels through `queue.committed`, not
through re-ingestion.

### 6.4 — TX-1003: model rejection

The merchant `suspicious-crypto` triggers the prompt's rule 1. The
verdict is a plain `Reject('suspicious merchant')` recorded in the
log — a legitimate business decision (and therefore cached, unlike
`prompt-error`/`parse-error` verdicts).

### 6.5 — TX-1004: conversation history in the prompt (Phase 8.1)

After four gateway decisions the dedicated session holds eight
messages. The example asserts on the adapter's captured prompt:

```dart
_expect(adapter.lastPrompt.contains('## Conversation History'), …);
_expect(adapter.lastPrompt.contains('## Current Request'), …);
```

The renderer inserted the prior `(user, assistant)` turns between
the few-shot examples and the current request. The user turns carry
the context+decision blocks of their own decision; assistant turns
carry the raw JSON the model produced. This is what makes the LLM's
later verdicts context-aware without any extra plumbing.

### 6.6 — The refund command: command decisions with arguments

```dart
await handle.cognitive.apply<Object?>(_commandFor(_approveRefund, [300]));
_expect(handle.decisions.toList().last.command != null, …);
```

Command decisions render the **function and its arguments** — the
model decides about the command *with* its arguments, in one decision,
and the `Decision` record stores the `command` shape. The mock adapter
recognizes `approveRefund`; the live prompt's rule 3 covers commands.

### 6.7 — Two reviewers, one shared window (Phase 8.1 `SessionMode.shared`)

```dart
final window = PromptSession(id: 'reviewers');
final sharedConfig = _riskConfig(
    id: 'payguard-shared-review', mode: SessionMode.shared);
…
final reviewerPolicy = promptedPolicyWith(
  config: sharedConfig, prompt: adapter.call,
  journal: RecordingJournal(), session: window,
);
```

`SessionMode.shared` **requires** the `session:` argument (it is
ignored in other modes). Reviewer A's decision appends a pair to the
shared window; reviewer B's prompt therefore renders reviewer A's
turn — a different prompt, hence a different cache key, hence a
second live call. The hard checks pin: two calls, four messages in
the window, both assistant turns in place.

### 6.8 — Outcomes → offline bandit (Phase 3)

```dart
final outcomes = recordOutcomes(handle);        // subscribed BEFORE traffic
…
for (final decision in handle.decisions.toList()) {
  handle.recordOutcome(decisionId: decision.id, reward: …);
}
final trained = await trainOffline(
  handle: handle, outcomes: outcomes.log,
  baseContext: _paymentsContext,
  trainer: contextualBandit(), journal: journal,
  config: const TrainingConfig(minSupport: 1, minConfidence: 0.5, maxRules: 20),
);
```

Rewards: `Accept → 1.0`, `Reject → -1.0`, `Defer → 0.5`. The bandit
buckets the decision vectors and emits learned rules (the live run
learned two accept rules: one narrow `actor×compliance×domains×purpose`
rule with support 6, one broader `compliance×domains` rule with
support 1). Deploying the result is `trained.applyTo(context)` — the
example prints the block so you can see exactly what would be
deployed. The subscription happens **before** traffic; recording an
outcome after the fact would miss it.

### 6.9 — XAI: the deferral narrative (Phase 6)

```dart
final deferDecision = …firstWhere((d) => d.verdict is Defer …);
final path = explain(deferDecision);
print(path.toNarrative(template: NarrativeTemplate.ui));
// customer-app deferred the request to approval (confidence 95%)
```

Then `explainPulse(deferDecision.pulse!, handle)` — which returns the
**newest** decision for that traceId: the follow-up `Accept`. This is
deliberate: "what happened to this pulse, most recently?" is the
approval resolution, while `explain(deferDecision)` answers "why was
it deferred?".

### 6.10 — Replay: the journal replays without the LLM

```dart
// Recording pass (fresh config id → guaranteed LLM call):
final replayHandle = cognitive(… promptedPolicyWith(
    config: replayConfig, prompt: adapter.call, journal: replayRecording));
await replayGate.ingest(_txPulse('TX-9001', 125, 'replay-cafe'));
_expect(adapter.calls == callsBeforeReplayRecording + 1, …);

// Replay pass:
final replayJournal = ReplayJournal(
    replayRecording.toJson().map(EffectRecord.fromJson).toList(growable: false));
… promptedPolicyWith(config: replayConfig, prompt: adapter.call,
                      journal: replayJournal) …
await replayGate2.ingest(_txPulse('TX-9001', 125, 'replay-cafe'));
_expect(adapter.calls == callsBeforeReplay, 'replay never re-invoked …');
replayJournal.assertExhausted();
```

The recording pass uses a **fresh config id** (`payguard-replay`) so
no existing prompt-cache entry can interfere — the recording itself
must contain an LLM-call disposition. The replay pass serves that
disposition: same branch, no adapter, recorded verdict reproduced,
every effect consumed. The same config instance and an identical
pulse (same payload, same `traceId`) are required — the disposition
input hash includes the config id and the cell-context fingerprint.

### 6.11 — Conformance: the deploy gate (`--conformance`)

```dart
final report = await conform(
  config: _riskConfig(id: 'payguard-conformance'),
  prompt: adapter.call,
  cases: [
    ConformanceCase(
      context: _paymentsContext,
      decision: _txPulse('TX-8001', 9999, 'conformance-check'),
      expected: const Defer('approval'),
    ),
  ],
);
```

`conform` bypasses both caches and sessions — it measures model
behaviour, not memoization — and compares verdict type plus
`Reject.reason` / `Defer.resolver`. The expected deferral matches
rule 2 of the system prompt. This is the pattern to run in CI before
shipping a prompt change.

---

## 7. What the example proves about the framework

| Guarantee | Pinned by |
|---|---|
| Structural policy runs before the LLM | gate + `policy-rejected` impossible for compliant pulses; compliance marker required |
| Verdict-cache hit skips render, LLM, and session append | TX-1001 repeat: calls unchanged, session length unchanged |
| Prompt-cache hit skips the LLM but records a decision | fresh policy over the same config |
| D14 population order (append → store under post-append key) | repeat hits while the session *has* grown |
| Wave-honest `Defer` + two-decision audit pair | TX-1002: `Defer` + follow-up `Accept(deferredBy)` |
| Session history is rendered for the model | `lastPrompt` contains both history headings |
| `SessionMode.shared` windows accumulate across policies | TX-1005 reviewers, 4 messages in one window |
| Command decisions carry their arguments to the verdict layer | refund command decision |
| Outcomes join decisions and train offline | learned rules from the bandit |
| XAI reconstructs from the log only | narratives for defer + resolution |
| Replay never invokes the adapter and reproduces verdicts | TX-9001 recording vs `ReplayJournal` |
| Conformance bypasses caches | `--conformance` pass against the live model |

---

## 8. Adapter internals

### 8.1 — Live path

```dart
final request = await _client!.postUrl(
    Uri.parse('${settings.baseUrl}/chat/completions'));
request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${settings.apiKey}');
request.add(utf8.encode(jsonEncode({
  'model': settings.model,
  'messages': [ {'role': 'system', 'content': system},
                {'role': 'user', 'content': user} ],
  'temperature': 0,
  'stream': false,
  'response_format': {'type': 'json_object'},
})));
```

The `PromptFunction` contract hands the adapter the **full rendered
prompt** (system prompt + examples + context + decision + schema).
The adapter splits it back into a system/user message pair when the
rendered text starts with the known system prompt; otherwise it sends
the whole text as one user message.

The returned `choices[0].message.content` is passed through
unchanged — the shipped `parseVerdict` unwraps markdown fences and
tolerates surrounding prose, so a model that wraps its JSON in
```` ```json ```` still parses.

Failures are thrown; the prompted pipeline converts them into
`Reject('prompt-error')`, which is journaled but **never cached**
(D17) — a transient network failure is not a verdict.

### 8.2 — Mock path

The mock implements the same four rules with two subtleties worth
noting:

- **Last occurrence wins.** In a session-aware prompt the history
  precedes the current request, so the mock reads the *last*
  `"merchant":` and `"amount":` occurrences — exactly what a careful
  local rule must do to model the LLM's view.
- The system prompt's rule text mentions `suspicious-crypto` without
  the `"merchant": "…"` quoting, so the regex only ever matches real
  decision payloads.

### 8.3 — Robustness flags

`calls` counts invocations, `failures` counts thrown live calls. When
a live call failed, model-dependent hard checks degrade to soft —
cache tiers and replay checks stay hard because the pipeline itself
is still deterministic, but a `prompt-error` verdict is a legitimate
(uncached) outcome that would break the model-expectation checks.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `No DeepSeek settings.json … found` | settings not on the search path | run from `packages/cell_mind`, or export `DEEPSEEK_API_KEY` |
| `DeepSeek HTTP 401` | wrong/expired API key | update `.deepcode/settings.json` |
| `DeepSeek HTTP 400` / 404 model | `MODEL` not served at that base URL | set a valid model (e.g. `deepseek-chat`) |
| A soft `⚠ model deviated` | the model didn't follow a prompt rule | strengthen the system prompt; the run still passes |
| A hard `✗` on a cache check after a failed call | `prompt-error` verdicts are not cached (D17), so repeats re-call | fix connectivity; re-run |
| Run hangs at a section | a live call in flight | the 90 s HTTP timeout plus the 95 s decision poll bound every step |
| `ReplayDivergenceException` | config id or pulse differs between recording and replay | keep the same config instance and identical pulse (incl. `traceId`) |
| `No element` on a decision lookup | the decision wasn't recorded yet | use the `_awaitDecisions` polling pattern, not fixed sleeps |

---

## 10. Adapting the example

- **Different domain:** change `_paymentsContext`, the pulse builder,
  and the system prompt rules — the structural policy and the cache
  tiers need no changes.
- **Different provider:** only `_Adapter._completeLive` is
  DeepSeek-specific; replace the HTTP block with any vendor SDK.
- **Real humans:** replace `await queue.approve(requestId)` with a UI
  that observes `queue.pending` (see `guide/05-Approval.md` §9).
- **Deploy learned rules:** add
  `final evolved = trained.applyTo(_paymentsContext);` and rebuild
  the gate with `contextAware() + learnedPolicy()` — the example
  already prints the block to deploy.
- **More reviewers:** loop `reviewOnce` over more names; the shared
  window and cache keys keep working (content-addressed).
- **Persist the audit:** write `journal.toJson()` and
  `handle.decisions` serializations to disk; replay later with
  `ReplayJournal`.

---

## 11. Reference map

| Example construct | Framework concept | Guide |
|---|---|---|
| `_expect(hard:)` | framework guarantees vs model behaviour | — |
| `contextAware + confidencePolicy` | structural gate, trust boundary | `guide/01-Policies.md` |
| `cognitive(…, verdictPolicy:, onDeferred:)` | recording runtime | `guide/02-Runtime.md` |
| `recordOutcomes` + `trainOffline` + `contextualBandit` | offline learning loop | `guide/03-Learning.md` |
| `ApprovalQueue` + `approvalResolver` | wave-honest HITL | `guide/05-Approval.md` |
| `explain` / `explainPulse` / `toNarrative` | decision narratives | `guide/07-XAI.md` |
| `promptedPolicyWith` + `PromptConfig` + adapter | prompted policy, two modes | `guide/12-Prompted-Policy.md` |
| `SessionMode.dedicated` / `.shared` + `PromptSession` | chat sessions, compaction | `guide/12-Prompted-Policy.md` §9 |
| verdict cache / prompt cache / D14 | three-tier fast path | `guide/12-Prompted-Policy.md` §4/§8 |
| `ReplayJournal` + `assertExhausted` | disposition-driven replay | `guide/04-Determinism.md` §3–4 |
| `conform` + `ConformanceCase` | deploy gate (bypasses caches) | `guide/12-Prompted-Policy.md` §17 |
| `_awaitDecisions` polling | async verdict wave | `guide/02-Runtime.md` |
| DeepSeek settings resolution | transport-agnostic adapter | `guide/06-Bridges.md` §2 |

The full cross-phase architecture is documented in
`ARCHITECTURE-Mind.md`; the cookbook recipe 16
(`guide/09-Cookbook.md`) is the compact version of this walkthrough.
