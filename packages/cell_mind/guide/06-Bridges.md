# Bridges — sensors and actuators for the cognitive layer

*Connecting `cell_mind` to LLMs, tools, and streams — without owning
transport.*

---

## §1 — What a bridge is

### §1.1 — Sensors vs actuators

- **Sensors** bring the outside world in: `completion` (a single LLM
  answer), `streamCompletion` / `streamChunks` (streaming tokens).
- **Actuators** send decisions out: `toolRouter` dispatches closed-verb
  tool calls and observes the result.

### §1.2 — Why bridges are cells

Every bridge returns a `Cell`:

```dart
final cell = completion(future: ..., actor: 'llm', prompt: 'p',
    confidence: 0.9, journal: journal);
final handle = cognitive(cell: cell, policy: confidencePolicy(min: 0.85));
```

Because a bridge is a cell, it composes with the whole cognitive
layer: `cognitive()`, observers, journals, training loops, approval.

---

## §2 — The transport-agnostic boundary

### §2.1 — Why no HTTP client

Transport is a legitimate concern — it is just not `cell_mind`'s.
The framework governs decisions; OpenAI SDKs, REST clients, and
websockets are user code or satellite packages.

### §2.2 — Writing your own glue

```dart
// 5 lines of glue between your HTTP client and the bridge:
Future<String> askLlm(String prompt) async {
  final response = await http.post(uri, body: {'prompt': prompt});
  return response.body;
}

final cell = completion(
  future: askLlm('What is 2+2?'),
  actor: 'openai-gpt4',
  prompt: 'What is 2+2?',
  confidence: 0.9,                       // ← required; no default
  journal: journal,
);
```

---

## §3 — `completion`

### §3.1 — Required confidence

`confidence` is a required parameter. An LLM call without a declared
confidence is ungovernable. The escape hatch is `Cell.fromFuture` —
the framework's baseline, which does not pretend to be governed.

The confidence flows into the emitted pulse's provenance:

```dart
final p = /* observed pulse */;
p.context.actor;       // 'openai-gpt4'
p.context.confidence;  // 0.9
p.context.strategy;    // ReasoningStrategy.probabilistic
p.context.purpose;     // 'COMPLETION'
```

Downstream `confidencePolicy(min: 0.85)` therefore gates the
completion automatically.

### §3.2 — Custom strategy

```dart
completion(
  future: ...,
  actor: 'rules-engine',
  prompt: 'route this',
  confidence: 1.0,
  strategy: ReasoningStrategy.deterministic,
  journal: journal,
);
```

### §3.3 — Error handling

A failing future never throws into the graph. The bridge emits a
typed `mind.completion.error` pulse (payload null) and journals the
error with its stack trace.

---

## §4 — Streaming

### §4.1 — `streamCompletion`

One governed pulse per token, in order:

```dart
final cell = streamCompletion(
  tokens: llmStream('...'),
  actor: 'openai-gpt4',
  prompt: '...',
  journal: journal,
);
Cell.observe(source: cell, effect: (Pulse p) {
  print(p.payload); // each token
});
```

Default confidence is 0.5 — streams do not declare their own.
Override via `baseContext` for governed streams.

### §4.2 — `streamChunks` and buffering

`buffer: Duration.zero` (default) matches per-chunk behavior. A
positive buffer coalesces chunks arriving within the window — **not
lossy**: every chunk lands in exactly one joined emission, and the
pending buffer flushes on stream close and on error.

### §4.3 — When to buffer

Buffer when the downstream policy is expensive per pulse (e.g., a
classifier call per token). A 50 ms window turns ~100 pulses/second
into ~20 without dropping a single token.

---

## §5 — `toolRouter`

### §5.1 — The closed-verb pattern

The model chooses from a known verb set; the router validates and
dispatches:

```dart
final inbound = Cell.ingress<Pulse>();
final router = toolRouter(
  source: inbound.cell,
  tools: {
    'fetch_user': (args) async => {'id': args['id']},
    'compute': (args) async => args['a'] + args['b'],
  },
  actor: 'llm',
  journal: journal,
  minConfidence: 0.8,
);
```

The source cell emits governed pulses whose payloads are
`{'verb': ..., 'args': ...}` maps.

**Consumer contract:** the router's emissions carry the result PULSE
as the payload — unwrap once:

```dart
Cell.observe(source: router, effect: (Pulse p) {
  final inner = p.payload as Pulse;
  print('${inner.type}: ${inner.payload}');
  // mind.tool.result.fetch_user: {verb: fetch_user, result: {id: 42}}
});
```

### §5.2 — The four rejection classes

| Failure | Pulse type | Payload |
|---|---|---|
| Unknown verb | `mind.tool.rejected.unknown-verb` | `{verb, reason}` |
| Low confidence | `mind.tool.rejected.low-confidence` | `{verb, confidence, threshold}` |
| Invalid args | `mind.tool.rejected.invalid-args` | `{verb, reason}` |
| Tool error (awaited) | `mind.tool.error.<verb>` | `{verb, error}` |
| Success (awaited) | `mind.tool.result.<verb>` | `{verb, result}` |
| Dispatched (fire-and-forget) | `mind.tool.dispatched.<verb>` | the call map |

Order matters: unknown verb beats low confidence beats invalid args —
first match wins.

### §5.3 — Why tools are functions, not cells

A tool is a capability: the model picks its name, the user provides
its implementation. Wrapping every tool in a cell would force
reactive machinery onto plain functions. Audit comes from the journal
effects and pulse provenance. If per-tool decision receipts are
required, wrap the tool in `cognitive(...)` — that's a Phase 4
pattern, not Phase 5.

### §5.4 — `exhaust` semantics (live substrate)

`toolRouter` hard-codes `exhaust: true`: dispatches serialize, and
arrivals that occur while a tool is running are **dropped**. For LLM
tool loops this is the correct contract — the model waits for the
result before the next call, so nothing is lost. Emit sequentially;
do not fire bursts of tool calls through one router.

### §5.5 — `fireAndForget` trade-offs

`fireAndForget: true` dispatches without awaiting and emits the
`mind.tool.dispatched.<verb>` step. Tool results are unobserved and
tool errors are swallowed — correct for telemetry/logging side
effects, wrong for anything that needs error visibility.

---

## §6 — Journal effects and replay

### §6.1 — The typed effect records

| Class | `type` | Carries |
|---|---|---|
| `MindCompletionEffect` | `mind.completion` | actor, prompt, confidence, strategy |
| `MindCompletionErrorEffect` | `mind.completion.error` | error, stackTrace |
| `MindStreamChunkEffect` | `mind.stream.chunk` | actor, chunk |
| `MindToolDispatchEffect` | `mind.tool.dispatch` | actor, verb, args |
| `MindToolResultEffect` | `mind.tool.result` | verb, result, duration |
| `MindToolErrorEffect` | `mind.tool.error` | verb, error, stackTrace |
| `MindToolRejectedEffect` | `mind.tool.rejected` | verb, reason, details |

All versioned (`1.0.0`) and reconstructible via `bridgeEffectFromMap`.

### §6.2 — Deterministic replay (live-substrate contract)

The live `EffectJournal` has no generic `record(...)`; effects persist
through `journal.io(...)`. Because `Cell.asyncMap` **re-runs the
mapper** under a replay journal, the tool invocation itself is
journaled as `mind.tool.call.<verb>` — replay serves the recorded
output and does NOT re-invoke the tool. `determinism_test.dart` pins
this: a tool returning `'second-run'` on replay still yields
`'first-run'`.

Effect timestamps truncate to milliseconds: the replay clock restores
epochs at millisecond precision, and wall-clock durations would never
fingerprint-match (see `_phase5_verdict.md` B2). Phase 9 hardened this
further: **durations computed from journal clocks must use
millisecond-truncated instants** — the recording journal stores clock
effects as epoch millis, so `endAt.difference(startAt)` over
microsecond-precision `clock()` return values flapped `durationMillis`
at ms boundaries and made `mind.tool.result` replay inputs diverge
intermittently. `toolRouter` now uses `_clockMs` for both instants
(`_phase8_verdict.md` F9.6).

### §6.3 — What replay does (and doesn't) do

- Replays the pulse OUTPUTS through the journal (`toolRouter`).
- Does NOT re-invoke external tools (journaled `io`).
- Does NOT re-run `completion`'s future — completion emissions are
  recorded effects, not a replayable verdict stream; consumers
  reconstruct the audit trail from the typed records.

---

## §7 — Composition

### §7.1 — With `cognitive()`

```dart
final handle = cognitive(
  cell: completion(...),
  policy: contextAware(),          // gates on provenance
);
```

### §7.2 — With `ApprovalQueue`

```dart
final handle = cognitive(
  cell: router,
  verdictPolicy: verdictPolicy((object, {required host, arguments}) {
    final outer = object is Pulse ? object.payload : null;
    final payload = outer is Pulse ? outer.payload : null;
    if (payload is Map && payload['verb'] == 'transfer') {
      return const Defer('approval');
    }
    return const Accept();
  }),
  onDeferred: approvalResolver(queue),
);
```

Note the double unwrap: the router emission's payload is the inner
pulse, whose payload is the call/result map.

### §7.3 — With learned verdict policies

```dart
verdictPolicy: learnedVerdictPolicy(),  // learned defer rules apply
```

---

## §8 — Common patterns

### §8.0 — Bridges vs prompted policies (Phase 8/9)

Two ways to involve an LLM, and they solve different problems:

| | Bridge (`completion` / `toolRouter`) | Prompted policy (`promptedPolicyWith`) |
|---|---|---|
| Role | Sensor/actuator — the model produces *data* | Decision layer — the model produces a *verdict* |
| Position | Upstream cell; its pulses flow into `cognitive()` | The `verdictPolicy:` slot inside `cognitive()` |
| Output | Pulses (`mind.completion.result`, `mind.tool.result.*`) | `Accept` / `Reject` / `Defer` in the decision log |
| Caching | None | Three-tier (verdict cache → prompt cache → LLM) |
| Sessions | None | `PromptSession` with three `SessionMode`s |
| Replay | Journaled effects, tools never re-invoked | Disposition-driven; adapter never invoked |

They compose: a `toolRouter` gathers facts, then a prompted policy
judges the gathered pulse. See `guide/12-Prompted-Policy.md`.

### §8.1 — LLM chat completion

```dart
final answer = completion(
  future: client.chat(prompt),
  actor: 'openai-gpt4',
  prompt: prompt,
  confidence: 0.9,
  journal: journal,
);
final handle = cognitive(cell: answer, policy: confidencePolicy(min: 0.8));
```

### §8.2 — RAG pipeline

`streamCompletion` for the streaming answer; each token pulse feeds an
observable UI; the journal records the full token stream for audit.

### §8.3 — Function calling

The router validates the model's verb choice; results feed back to
the model (which maps the result into the next call — see the
integration test). `exhaust` serializes the loop; rejections never
crash the pipeline.

### §8.4 — Streaming with confidence gating

Provide a `baseContext` carrying a real confidence when the stream
source declares one; otherwise 0.5 keeps the stream observable but
gated by `confidencePolicy` downstream.

---

## §9 — What Phase 5 does not cover

| Concern | Where it lives |
|---|---|
| HTTP clients / provider SDKs | User code or satellites |
| Vector DB clients | User code |
| Prompt templating / schema validation | User code |
| Retry / circuit breaker / backoff | User code |
| Parallel tool dispatch | `exhaust` drops in-flight arrivals by design |
| Per-tool `ApplyReceipt` | Wrap in `cognitive()` |
| XAI narratives for tool calls | Phase 6 (`DecisionPath`) |

---

## §10 — Phase 5 findings (recorded)

- **`PulseContext.aiInference` does not exist** — contexts are composed
  from `Provenance` entries via `PulseContext.fromEntries`.
- **`Cell.ingress.emit` takes the value, not a pulse** — the bridges
  emit governed pulses through an `OpenCell.perform` pass-through,
  the public surface that can `emit(Pulse)`.
- **`asyncMap` re-runs the mapper on replay** — tool invocations are
  journaled `io` calls so replay serves recorded outputs.
- **`exhaust: true` drops in-flight arrivals** — not a queue.
- **Replay clocks truncate to milliseconds** — effect timestamps
  truncate likewise or fingerprints diverge.
- **`Future<Never>.catchError` handlers must return `Never`** — use
  `.then<void>(...)` for swallowed fire-and-forget errors.

---

## §11 — AI Agent Guide notes

1. **Always pass a journal.** Every bridge requires one — there is no
   default.
2. **Declare confidence.** `completion` rejects omission at the type
   level; ungoverned futures belong in `Cell.fromFuture`.
3. **Unwrap router pulses once.** `p.payload as Pulse` — then read
   `inner.type` and `inner.payload`.
4. **Emit tool calls sequentially.** `exhaust` drops arrivals while a
   tool runs.
5. **Use `fireAndForget: false` for anything that needs results or
   error visibility.**
6. **Never await a tool call inside a mapper without journaling it** —
   replay would re-invoke the tool; use `journal.io(...)`.

---

## §12 — Reference table

| Type | Kind | Notes |
|---|---|---|
| `Tool` | typedef | `Future<Object?> Function(Map<String, dynamic>)` |
| `completion(...)` | factory → `Cell` | governed single-shot |
| `streamCompletion(...)` | factory → `Cell` | per-token governed pulses |
| `streamChunks(...)` | factory → `Cell` | opt-in buffering |
| `toolRouter(...)` | factory → `Cell` | closed-verb dispatch, four rejections |
| `Mind*Effect` | records | 7 typed journal effects |
| `bridgeEffectFromMap(map)` | dispatcher | reconstructs typed effects |

---

## §13 — Summary

Phase 5 gives the cognitive layer its sensory surface:

1. **Confidence is structural.** `completion` cannot exist without a
   declared confidence — the bridge layer enforces the framework's
   fail-closed principle.
2. **Rejections are typed pulses.** Four distinct failure classes make
   dashboards, XAI, and training bucket them independently.
3. **Tools replay safely.** The journaled `mind.tool.call.<verb>` io
   makes replay serve recorded outputs without re-invoking the world.

---

## §14 — Deployment checklist

- [ ] Every bridge has a real `RecordingJournal` — no null journals.
- [ ] `completion` calls declare a confidence (and a strategy that
      matches the source).
- [ ] Router sources emit governed pulses whose payloads are
      `{verb, args}` maps.
- [ ] Tool calls are emitted sequentially (exhaust drops in-flight
      arrivals).
- [ ] Consumers unwrap router emissions once (`p.payload as Pulse`).
- [ ] Fire-and-forget mode is reserved for error-tolerant side
      effects.
- [ ] Journals are retained — the typed records are the audit trail.
- [ ] Streaming sources that need confidence gating pass a
      `baseContext` with a real confidence.

---

## §15 — FAQ

**Q: Why is `confidence` required on `completion`?**
An LLM call without a declared confidence is ungovernable. Use
`Cell.fromFuture` for ungoverned futures.

**Q: Why does the router wrap its result in a pulse?**
The result pulse carries the rejection/result TYPE and the governed
provenance — the audit contract. Unwrap once.

**Q: Why does `exhaust` drop arrivals?**
The substrate's exhaust map ignores new values while busy. LLM tool
loops are sequential by design, so nothing is lost in practice; emit
sequentially.

**Q: Does replay re-invoke my tools?**
No — the tool call is a journaled `io`; replay serves the recorded
output.

**Q: What happens when a tool throws?**
A typed `mind.tool.error.<verb>` pulse, journaled with the stack
trace. The pipeline never crashes.

**Q: Can I chain two routers directly?**
No — insert a model step that maps the first result into the next
call (the pattern in the integration test).

**Q: Why millisecond timestamps in effects?**
The replay clock restores epochs at millisecond precision; matching
fingerprints require truncation on both sides.

---

## §16 — What Phase 6 inherits

- `toolRouter`'s four rejection pulse types — `DecisionPath` (XAI)
  reconstructs why a call failed without inspecting payloads.
- `completion`/stream journal effects — agent narratives replay model
  behaviour from the ledger.
- The bridge-cell composition pattern — `AgentRuntime` wires each
  agent's LLM loop through `cognitive()` + bridges.
- `ApprovalQueue` composition — multi-agent decisions defer to the
  same HITL primitive.

---

## §17 — Summary

The cognitive layer is now connected: governed completions, streaming
tokens, and closed-verb tool dispatch — all journaled, all composable
with the policy, learning, and approval layers. The next phase makes
the loop explainable and multi-agent.
