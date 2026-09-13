# Features — NL instruction → TissueSet (Flow + Tissue)

**Companion to:** `nl-instruction-tissue-set-Demo.dart`
**Audience:** operators and reviewers evaluating what the demo
demonstrates and what it deliberately leaves out.

---

## Contents

1. [Feature catalogue](#1-feature-catalogue)
  - [Sentence ingress (TestCell)](#11-sentence-ingress-testcell)
  - [Interpreter instruction (Flow)](#12-interpreter-instruction-flow)
  - [Classification filter (Flow)](#13-classification-filter-flow)
  - [Dispatch instruction (Flow)](#14-dispatch-instruction-flow)
  - [Membership books (Tissue)](#15-membership-books-tissue)
  - [Interpreter port (I/O seam)](#16-interpreter-port-io-seam)
  - [Compliance deputy](#17-compliance-deputy)
  - [Mode selection and config](#18-mode-selection-and-config)
2. [Scenario catalogue](#2-scenario-catalogue)
3. [What the demo does not do (deliberately)](#3-what-the-demo-does-not-do-deliberately)
4. [Operator cheat sheet](#4-operator-cheat-sheet)
5. [Acceptance checklist](#5-acceptance-checklist)
6. [See also](#6-see-also)

---

## 1. Feature catalogue

### 1.1 Sentence ingress (TestCell)

| Feature | Where | Behaviour |
|---|---|---|
| Non-empty sentence shape | `_commandShape` on `commandIn` | Rejects `''`. |
| Length bound | `_commandShape` on `commandIn` | Rejects any sentence over 200 chars. |
| String type check | `_commandShape` on `commandIn` | Requires `String`; rejects non-strings. |
| Pulse unwrapping | `_commandShape` | Rule reads `Pulse.payload`, not the wrapper. Without this the rule sees a `Pulse<String>` and rejects every emission. |
| Cache-on-accept | `commandIn.emit` | Rejected sentences do **not** reach the interpreter. `say(...)` returns `false` without incrementing `commands`. |
| Zero-delay drain | `say(...)` | Awaits a short sequence of `Duration(milliseconds: 2)` futures so the interpreter round trip drains before the scenario's assertions print. |

### 1.2 Interpreter instruction (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Single instruction, single materialisation | `interpretedInstruction.toHandle` | One `toHandle` call for the whole demo. |
| Closed verb list | `verbByName` from `ai_tissue_command_domain.dart` | The model cannot invent a verb; unknown strings become `Reject(reason: 'unknown-verb')`. |
| `TissueCommand` reply shape | `AiTissueCommand` future callback | Success → `Pulse<TissueCommand>`. |
| `Reject` reply shape | `AiTissueCommand` future callback | Failure → `Pulse<Reject>`. |
| Interpreter errors routed to port's log | `onError` handler in `install` | `HttpInterpreter.log.error(e)` or `StubInterpreter.log.error(e)`. |
| Timeout injection | `AiTissueCommand.injectTimeoutOnce` | One-shot throw from `complete(...)` on the next call. Works offline and live. |
| Latest-wins semantics | `AiTissueCommand` generation counter | A newer sentence abandons the previous in-flight call. |
| Causal provenance preserved | `_out<T>` helper in `ai_tissue_command.dart` | Every emitted pulse inherits source, priority, and type from the trigger. |

### 1.3 Classification filter (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Drop `Reject` | `Flow.filter<Object>` | `Reject` pulses are dropped and counted. |
| Count accepted classifications | `Flow.filter<Object>` | `TissueCommand` pulses increment `interpretedCount` and pass. |
| Pass unknown payloads | `Flow.filter<Object>` | Anything that is neither `TissueCommand` nor `Reject` returns `false` and is dropped. |
| Single filter, single classification pass | `filtered = Flow.filter<Object>(...)` | Exactly one filter in the pipeline. |

### 1.4 Dispatch instruction (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Verb → tear-off registry | `_registry(host)` | Returns a `Map<TissueVerb, Function>` for the current host. |
| `modifiable` gate | `_runDispatch` | `host.modifiable.contains(tearOff)` must be `true` before the tear-off is called. |
| Denial prints the verb and args | `_runDispatch` | `[dispatch] ${verb.name}(${args.single}) denied (not in modifiable)`. |
| Unknown verb denial | `_runDispatch` | `[dispatch] ${verb.name} denied (no tear-off)`. |
| Arg-shape table | `_runDispatch` switch | `add` / `addAll` / `remove` / `removeAll` / `clear` / `retainAll` all driven. |
| Predicate verbs rejected | `_runDispatch` switch | `removeWhere` / `retainWhere` print `denied (predicate)`. |
| Exception containment | `_runDispatch` try/catch | A tear-off that throws is caught; the message is printed; the pipeline continues. |
| Host swap without graph rebuild | `_dispatchHost` (`Box<TissueSet<int>>`) | Scenario 8 swaps in `auditor` and back, no `toHandle` call. |
| Counter increments on success only | `dispatchedCount++` | Only after the tear-off returns without throwing. |

### 1.5 Membership books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Element shape rule | `_elementRule` on `tags` | `>= 0`. Rejects any negative int at the tissue boundary. |
| Live observability | `TissueSet<int>` | Every `add` / `remove` / `clear` takes the tissue lock and emits a `TissuePulse`. |
| Duplicate suppression | `Set<int>` container | A second `add 1` runs the tear-off and the rule, then the container rejects the duplicate without emitting an event. |
| Batch add | `tags.addAll([4, 5])` | Emits one `ElementAdded` per accepted element. |
| Multi-element removal | `tags.removeAll` | Emits one `ElementRemoved` per removed element. |
| Zero-arg clear | `tags.clear` | Emits `ElementRemoved` rows for every member. |
| Retain filtering | `tags.retainAll` | Removes members not in the argument iterable. |
| Runtime swappable host | `_dispatchHost.value = ...` | Point the dispatch at `tags` or `auditor` without touching the graph. |
| Initial population is silent | `TissueSet<int>(const <int>[], ...)` | Observers only see **post-create** mutations. |

### 1.6 Interpreter port (I/O seam)

| Feature | Where | Behaviour |
|---|---|---|
| Offline default | `NlTissueHarness.offline` | No network. Deterministic stub. |
| Live HTTP | `NlTissueHarness.live` | OpenAI-compatible chat-completions endpoint. |
| Config-file | `NlTissueHarness.fromConfigFile` | Reads a JSON file via `AiConfig.fromJsonFile`. |
| Traffic log — system prompt | `TrafficLog.systemPrompt` | Full prompt printed the first time, truncated afterwards. |
| Traffic log — request | `TrafficLog.request` | Endpoint, model, sentence, full JSON body. |
| Traffic log — response | `TrafficLog.response` | HTTP status and full body. |
| Traffic log — parsed | `TrafficLog.parsed` | Verb, args, confidence. |
| Traffic log — refused | `TrafficLog.refused` | Refusal reason. |
| Traffic log — error | `TrafficLog.error` | Exception from the transport or the parser. |
| Timeout injection — offline | `StubInterpreter.injectTimeoutOnce` | Deterministic throw on the next call. |
| Timeout injection — live | `HttpInterpreter.injectTimeoutOnce` | Throws **before** the HTTP request is made, so the demo stays fast and deterministic. |
| Two envelopes accepted | `HttpInterpreter._parse` | OpenAI-shaped `choices[0].message.content` **and** bare `{"verb": ...}` objects. |
| Fail-closed parsing | `_parse` in both interpreters | Every parse failure returns a `Reject`, never throws. |
| Client lifecycle | `dispose()` in the harness | Closes the HTTP client if the interpreter is live. |

### 1.7 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Read-only view of the set | `tags.unmodifiable` | Live projection in the general case; snapshot in this build. |
| Empty `modifiable` | `auditor.modifiable` | `contains(...)` is always `false`. |
| Dispatch denial without a lock | `_runDispatch` gate | The denial is printed before any tissue lock is taken. |
| Read-only reads | `auditor.contains`, `auditor.length` | Direct reads from the container. |
| Host swap | `useAuditorHost()` / `useMutableHost()` | The dispatch host is swapped; the graph is untouched. |

### 1.8 Mode selection and config

| Feature | Where | Behaviour |
|---|---|---|
| `--live` flag | `main` argument parsing | Enables HTTP mode with env vars. |
| `--config <path>` flag | `main` argument parsing | Enables HTTP mode from a JSON file. Overrides `--live`. |
| `--print-config` flag | `main` argument parsing | Writes a template JSON to `<path>` (default `ai_config.json`) and exits. |
| Env-var precedence | `_selectHarness` | `--config` wins; then `--live`; then offline. |
| No env fallback when config is supplied | `fromConfigFile` | The interpreter reads only the file. |
| Graceful fallback on config error | `_selectHarness` | Catches, writes to `stderr`, falls back to offline. |
| Single-return harness selection | `_selectHarness` | Every branch terminates in `return`; `main` assigns `h` exactly once. |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | Bus + interpreter armed, no mutation | `tags.isEmpty=true` |
| 1 | Sentence → verb → Tissue | `[dispatch] add(1) allowed`, `contains(1)=true length=1` |
| 2 | Duplicate suppression by the Set | `[dispatch] add(1) allowed`, `grew=false` |
| 3 | Second distinct element | `[tags] +2`, `tags={1, 2}` |
| 4 | Remove | `[dispatch] remove(1) allowed`, `tags={2}` |
| 5 | Zero-arg clear | `[dispatch] clear() allowed`, `tags={}` |
| 6 | Model refusal | `dispatched=false tags={}` |
| 7 | Element rule rejection | `[dispatch] add(-1) allowed`, `[tags] reject -1`, `tags={}` |
| 8 | Deputy `modifiable` empty | `[dispatch] add(3) denied (not in modifiable)`, `tags={}` |
| 9 | Multi-arg verb | `[dispatch] addAll([4, 5]) allowed`, `tags={4, 5}` |
| 10 | Interpreter timeout → `Reject` | `dispatched=false tags={4, 5}` |
| 11 | Ingress shape rejection | `empty accepted=false`, `oversized accepted=false`, `interpret ran=false` |
| 12 | Extension hook | `skipped (no live interpreter)` |
| Trailer | Counters + snapshot note | `commands=8 interpreted=6 dispatched=5 rejected=2` |

---

## 3. What the demo does **not** do (deliberately)

| Missing feature | Why it is out of scope | Where it would live |
|---|---|---|
| Real LLM streaming | A streaming reply requires a different reply shape. | `HttpInterpreter` with `stream: true` + a `Synthesis` over token pulses. |
| Multi-turn conversation | The demo is one sentence per scenario. | A second `Cell.ingress` for the reply, and a `Synthesis` to keep context. |
| Argument type coercion | The dispatch relies on the interpreter's arg shape. | A `TestTissue` on `TissueCommand` before the dispatch. |
| Approval queue for high-risk verbs | The demo trusts the model's verb choice. | A `TissueQueue<TissueCommand>` + a second consumer + `Sovereignty.supervised`. |
| Persistent command audit | The demo keeps no log of accepted commands. | A `TissueList<TissueCommand>` alongside `tags`. |
| Rate limiting per operator | Single-operator demo. | A `TestTissue` on `tags` keyed on a sliding window, or a `TissueMap<String, int>` for per-actor quotas. |
| Verb composition | One sentence, one verb. | A `Synthesis` over the interpreter output, then a second dispatch. |
| Multi-model fallback | One interpreter per run. | A `Synthesis` over two interpreters, `First-To-Succeed`. |
| Sandboxed execution | The set is either mutable or read-only; no virtualized layer. | `DeputyContext.sandbox` + `Isolation.sandboxed`. |
| Real auditor parity | `.unmodifiable` is a snapshot in this build. | A live `.deputy(TestTissue.readOnly)` per the ride-hail demo. |
| `removeWhere` / `retainWhere` driven | The model cannot safely produce a predicate. | A `TestTissue` that whitelists a fixed predicate vocabulary. |
| Error budget on the interpreter | Timeout is one-shot per call. | A `TissueValue<int>` for consecutive failures, plus a circuit breaker. |
| Signature / encryption on `TissueCommand` | Out of scope for v1. | A `Provenance.integrity` field set by the interpreter port. |
| Per-verb confidence threshold | Confidence is carried but not gated. | A `TestTissue` on `TissueCommand` that rejects below a threshold. |
| Locale-aware parsing | English only. | A second prompt template per locale. |
| Cost / usage accounting | The demo does not measure token spend. | A `TissueValue<int>` incremented from `usage` in the interpreter reply. |

---

## 4. Operator cheat sheet

### 4.1 Common operations

| Want | Call |
|---|---|
| Send a sentence | `await h.say('add 3 to the tissue')` |
| Send an empty string | `await h.say('')` — returns `false` |
| Force a timeout | `h.interpretedInstruction.injectTimeoutOnce()` before `say(...)` |
| Switch to the auditor host | `h.useAuditorHost()` before `say(...)` |
| Switch back to the mutable host | `h.useMutableHost()` after `say(...)` |
| Print the set | `h.tagsAsString()` |
| Inject a fake interpreter | Call `install()` then replace `interpretedInstruction`'s interpreter field — not supported by the current harness; a rebuild is required |
| Shut down cleanly | `h.dispose()` |

### 4.2 Inspection

| Want | Read |
|---|---|
| Current members | `tags` (iterable) |
| Member count | `tags.length` |
| Read-only view | `tags.unmodifiable` |
| Auditor's `modifiable` set | `auditor.modifiable` (always empty) |
| Commands accepted at ingress | `commands` |
| `TissueCommand` pulses past the filter | `interpretedCount` |
| Successful tear-off runs | `dispatchedCount` |
| `Reject` pulses dropped | `rejectedCount` |
| Current dispatch host | `_dispatchHost.value` |

### 4.3 Inspecting a `TissueCommand`

A `TissueCommand` has four fields:

| Field | Meaning |
|---|---|
| `verb` | A `TissueVerb` enum value |
| `args` | The arg list; shape depends on `verb` (see §Domain) |
| `confidence` | The model's reliability estimate (0.0–1.0) |
| `source` | The original sentence |

A common query is “which commands did we accept from the model?”:

```dart
// Not persisted in this demo; inspect at the dispatch point:
// _runDispatch receives each TissueCommand.
```

### 4.4 Inspecting a `Reject`

A `Reject` has two fields:

| Field | Meaning |
|---|---|
| `source` | The original sentence |
| `reason` | A short reason (`no-permitted-verb`, `unknown-verb`, `empty-reply`, `interpreter-error`, `parse-error: ...`, `retries-exhausted: ...`) |

### 4.5 Diagnosing a missing dispatch

1. **Did the sentence reach the interpreter?**
   Check `commands` before and after. If unchanged, `_commandShape`
   rejected the sentence. See the `accepted=` line from `say(...)`.
2. **Did the interpreter return a `TissueCommand`?**
   Check `interpretedCount`. If unchanged, the interpreter returned a
   `Reject`. Look in the traffic log for `REFUSED`.
3. **Did the dispatch gate accept the verb?**
   Check the `[dispatch]` line. If it says `denied (no tear-off)`, the
   registry has no entry — usually because the host was swapped to the
   auditor and back incorrectly.
4. **Was the verb in `modifiable`?**
   Check `[dispatch] ... denied (not in modifiable)`. The auditor's
   `modifiable` is always empty.
5. **Did the tissue rule reject the element?**
   Look for `[tags] reject ...`. The `_elementRule` is `>= 0`.

### 4.6 Diagnosing a double dispatch

- Check that `install()` was called exactly **once**. A second call
  attaches a second filter and a second dispatch instruction to the
  same interpreter.
- Check that `toHandle` was not called from the interpreter's
  `onError` handler. The handler only prints.
- Check that the interpreter's `injectTimeoutOnce` was not fired
  mid-scenario by a previous call. `injectTimeoutOnce` is one-shot.

### 4.7 Diagnosing a stuck interpreter

- Check the traffic log for a `REQUEST` block with no matching
  `RESPONSE` block. This means `complete(...)` never returned.
- In live mode, check `AI_ENDPOINT`, `AI_API_KEY`, and `AI_MODEL`.
  A missing endpoint or key falls back to offline and prints a
  diagnostic.
- Check the harness's `interpreter` field. `StubInterpreter` should
  return almost instantly; `HttpInterpreter` may take seconds.

### 4.8 Diagnosing a traffic-log mismatch

The demo's console is dominated by the traffic log. A common
confusion: the traffic log's `PARSED` block says `add 3` but the
`[dispatch]` line says `add(3) denied (not in modifiable)`. That is
**not** a mismatch — the interpreter succeeded and the dispatch
gate refused. Check the host (`useAuditorHost()` vs
`useMutableHost()`).

### 4.9 Priority of failure sites

When two failures might apply, the earlier one wins:

1. **Ingress**: `_commandShape` on `commandIn`. Empty / oversized
   sentences die here. The interpreter never runs.
2. **Interpreter**: `AiTissueCommand`. Transport failures,
   timeouts, and unparseable replies become `Reject` pulses.
3. **Filter**: `Flow.filter<Object>`. `Reject` pulses are dropped.
4. **Dispatch**: `_runDispatch`. The `modifiable` gate denies the
   verb, or the tear-off throws.
5. **Tissue rule**: `_elementRule` on `tags`. Negative integers are
   rejected at the container boundary.

A failure at step 1 means steps 2–5 never run. A failure at step 5
means step 4 succeeded — the `[dispatch] ... allowed` line will
appear before the `[tags] reject ...` line.

### 4.10 Mode selection precedence

| Flags | Environment | Behaviour |
|---|---|---|
| `--config <path>` | *(ignored)* | Reads the file. Fails → offline. |
| `--live` | `AI_ENDPOINT` + `AI_API_KEY` set | Live HTTP with env-var config. |
| `--live` | either env var missing | Prints diagnostic; falls back to offline. |
| *(none)* | *(ignored)* | Offline stub. |
| `--print-config` | *(ignored)* | Writes a template file and exits. |

The config file is authoritative. When `--config` is present, the
env vars are **not** consulted.

---

## 5. Acceptance checklist

The demo is done when **all** of the following hold:

1. `dart run nl-instruction-tissue-set-Demo.dart` matches the
   scenario **Result** column in
   `nl-instruction-tissue-set-WalkThrough.md`.
2. Exactly **one** explicit `toHandle(` call on
   `AiTissueCommand`, inside `install()`. The dispatch stage's
   `MapValue` materialises its own handle internally; the demo
   does not call `toHandle` on it a second time.
3. `_runDispatch` contains no `await`, no `tags.add` before the
   `modifiable` gate, and no direct write to `tags` other than
   the tear-off call.
4. Scenario 6 prints `dispatched=false` and does not touch `tags`.
5. Scenario 7 prints `[dispatch] add(-1) allowed` **and**
   `[tags] reject -1`, and `tags` is unchanged.
6. Scenario 8 prints `[dispatch] add(3) denied (not in modifiable)`
   and `tags` is unchanged.
7. Scenario 10 prints `dispatched=false` and does not touch
   `tags`.
8. Scenario 11 prints `empty accepted=false`,
   `oversized accepted=false`, and `interpret ran=false`.
9. Every `TissueSet` / `.unmodifiable` call passes **`TestTissue`**
   (or omits the argument and takes `TestTissue.allowAll`). Grep
   must show **zero** `testRule: TestCell` on those calls.
10. The trailer's counters match
    `commands=8 interpreted=6 dispatched=5 rejected=2`.
11. The trailer prints `auditorLength=0` with the deviation note.
12. `--live` without `AI_ENDPOINT` / `AI_API_KEY` falls back to
    offline and prints a diagnostic.
13. `--config <path>` reads only the file; env vars are not
    consulted.
14. Full traffic logging is preserved offline and live.
15. `dispose()` is called in a `finally` block.
16. The Dart file's header diagram matches the walkthrough's
    architecture figure.
17. `TissueVerb.removeWhere` and `TissueVerb.retainWhere` are
    present in the enum but are rejected by `_runDispatch`.

---

## 6. See also

| File | Purpose |
|---|---|
| `nl-instruction-tissue-set-Demo.dart` | Executable implementation. |
| `nl-instruction-tissue-set-WalkThrough.md` | Requirement document and scenario contract. |
| `ai_tissue_command.dart` | The `AiTissueCommand` family (single-sentence, batch, retry). |
| `ai_tissue_command_domain.dart` | The `Interpreter` port, `HttpInterpreter`, `StubInterpreter`, `TrafficLog`, `AiConfig`. |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility sibling — same graph shape, different domain. |
| `card-auth-pipeline(tissue)-Demo.dart` | Payments sibling. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |