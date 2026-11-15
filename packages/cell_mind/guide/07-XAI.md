# XAI — the decision narrative layer

*Every decision becomes a readable, traceable explanation — without
the cognitive layer guessing why.*

---

## §1 — What XAI means for `cell_mind`

The decision log is already the evidence. XAI adds the **projection**:

- `DecisionPath` — a read-only view over one `Decision` with derived
  accessors (actor, strategy, confidence, …).
- `toNarrative()` — three templates for three audiences.
- `explain` / `explainPulse` / `explainSource` — find the decision
  that matters.
- `otelSpans` — OTel-compatible spans from the log via a minimal
  `Tracer` abstraction.

---

## §2 — `DecisionPath` — the read-only view

```dart
final path = explain(decision);
path.actor;        // provenance, null for action decisions
path.confidence;
path.verdict;
path.toNarrative(template: NarrativeTemplate.audit);
```

All data lives in the `Decision`; the path is a stateless projection.
Action-based decisions (no pulse) return `null` provenance accessors.

---

## §3 — The three narrative templates

| Template | Audience | Shape |
|---|---|---|
| `audit` | compliance, replay | timestamped, ids, verdict, actor/strategy/confidence/context-version/eval |
| `ui` | humans | "agent_a rejected the request: over-budget (confidence 80%)" |
| `debug` | developers | structured `DecisionPath(id: …, verdict: …, pulse: …, context: …)` |

Choose by audience: `audit` when traceability matters, `ui` when it
doesn't, `debug` for tooling.

---

## §4 — `explainPulse` and `explainSource`

```dart
final path = explainPulse(pulse, handle);   // by traceId, newest first
final paths = explainSource(cell, handle);  // by pulse.source.id
```

- `explainPulse` matches by `traceId` — evolved pulses find their
  root decision. `null` when the pulse never passed the handle.
- `explainSource` filters by the emitting cell's id — works for any
  `Cell` (including `cell_organ` Blends) with no extra dependency.

---

## §5 — OTel integration — the `Tracer` adapter

`cell_mind` has no tracing SDK dependency. Wrap yours:

```dart
class OTelAdapter implements Tracer {
  final opentelemetry.Tracer otel;
  OTelAdapter(this.otel);

  @override
  Span startSpan(String name, {SpanContext? parent, DateTime? startTime}) =>
      _OTelSpan(otel.startSpan(name)); // … wrap

  @override
  SpanContext get currentContext => _OTelContext(otel.currentSpan);
}
```

The interfaces are deliberately minimal: `startSpan`, `setAttribute`,
`setStatus`, `end`.

---

## §6 — Span reconstruction from decisions

`otelSpans(decisions, tracer: …)`:

1. Sorts decisions causally (`at`).
2. Starts one span per decision (name overridable via `spanName`).
3. Parents from `pulse.context.parentTraceId`; orphans become roots.
4. Attributes: `mind.actor`, `mind.strategy`, `mind.confidence`,
   `mind.verdict.type`, `mind.context.version`,
   `mind.evaluationTime.micros` (+ `extraAttributes`).
5. Status: Accept → ok, Reject → error. Every span ends.

---

## §7 — Common patterns

### §7.1 — Audit logs

```dart
for (final decision in handle.decisions) {
  log.info(DecisionPath(decision).toNarrative());
}
```

### §7.2 — Dashboards

Filter by verdict type, aggregate by actor/strategy/domain from the
path accessors — no payload inspection needed.

### §7.3 — Compliance reports

The `audit` template includes `contextVersion` — the replay
coordinates — and timestamps; ship it verbatim.

---

## §8 — What XAI can and cannot reconstruct

- **Can**: every field recorded in the `Decision` — verdict, policy
  version, provenance, evaluation time, context version.
- **Cannot**: the internal reasoning of an LLM behind a bridge
  (record the prompt/result in effect metadata if needed), nor
  decisions that never reached a `cognitive` handle.

---

## §9 — Reference

| Type | Kind |
|---|---|
| `DecisionPath` | projection over a `Decision` |
| `NarrativeTemplate` | `audit` / `ui` / `debug` |
| `explain(decision)` | wrap |
| `explainPulse(pulse, handle)` | trace-id lookup |
| `explainSource(cell, handle)` | emitter filter |
| `Tracer` / `Span` / `SpanContext` / `SpanStatus` | tracing abstractions |
| `otelSpans(decisions, {tracer, spanName, extraAttributes})` | span emission |

---

## §10 — Summary

XAI does not re-derive decisions — it projects them. The same log
that trains agents, feeds approvals, and audits compliance now reads
as prose and traces.

---

## §11 — Narrative format reference

### `audit`

```
[ISO-8601 UTC] decision <id>: ACCEPT|REJECT '<reason>'|DEFER '<resolver>'
  (actor=…, strategy=…, conf=…, purpose=…, ctx-version=…, eval=…ms)
```

Every field present is included; missing provenance is elided. The
timestamp and context version make the line replay-coordinate
complete.

### `ui`

- Accept: `agent_a accepted the request (confidence 82%)`
- Reject: `agent_a rejected the request: over-budget`
- Defer: `agent_a deferred the request to supervisor`
- Unknown actor: `An actor decided: accept`

No ids, no timestamps — human-facing by design.

### `debug`

```
DecisionPath(id: …, verdict: ACCEPT, pulse: Pulse<int>(42),
  context: v1.0.0, eval: 2ms)
```

Structured and parseable; payload runtime types are included.

---

## §12 — Span attribute reference

| Attribute | Source |
|---|---|
| `mind.verdict.type` | `decision.verdict.type` |
| `mind.context.version` | `decision.contextVersion` |
| `mind.actor` | pulse provenance |
| `mind.strategy` | pulse provenance (name) |
| `mind.confidence` | pulse provenance |
| `mind.evaluationTime.micros` | `decision.evaluationTime` |

Status: `ok` for `Accept`, `error` for `Reject` and `Defer`
(unresolved deferrals are not `ok`). Custom keys via
`extraAttributes`.

---

## §13 — Decision procedures

### 13.1 — "Why was this rejected?"

```dart
final path = explainPulse(rejectedPulse, handle);
print(path?.toNarrative()); // audit line with reason + metadata
```

### 13.2 — "What did this cell emit?"

```dart
final paths = explainSource(cell, handle);
```

### 13.3 — "Where does this fit in the trace?"

```dart
otelSpans(handle.decisions.where((d) => d.pulse != null),
    tracer: adapter);
```

Parent/child reconstruction comes from `parentTraceId` — pulses
evolved with `context.evolve` carry it automatically.

---

## §14 — FAQ

**Q: Why is `DecisionPath` not a chain?**
A single decision is the unit of explanation; chains are queries over
`handle.decisions` (filter by traceId or parentTraceId).

**Q: Why no OTel SDK dependency?**
Tracing backends are user choice; the adapter pattern keeps the
dependency surface at `cell` + `cell_tissue`.

**Q: What about action decisions?**
They render with verdict/command metadata; pulse-provenance
accessors are `null`.

**Q: Can narratives be replayed?**
They are pure functions of the decision log — replay the log, rerun
the narrative.

---

## §15 — What Phase 7 inherits

- `DecisionPath`/`otelSpans` — the cookbook's audit and tracing
  recipes.
- The projection pattern — the final API freeze documents it as the
  canonical explanation surface.
- The `Tracer` adapter — stabilization ships a reference adapter for
  the `opentelemetry` package.

---

## §16 — Summary

XAI is the reading lens over the decision log: prose for humans,
structure for tools, spans for tracers — all derived, never guessed.

---

## §17 — AI Agent Guide notes

1. **Never invent a decision.** Narratives render recorded data only;
   if the log lacks a field, the narrative elides it.
2. **Use `audit` for anything persisted** — it carries ids,
   timestamps, and context versions.
3. **Wrap your SDK once.** The `Tracer` adapter is ~20 lines; keep it
   beside your tracing setup, not per call site.
4. **Prefer `explainPulse` over manual scans** — trace-id matching
   survives pulse evolution.
5. **Remember action decisions have no provenance** — check
   `path.pulse == null` before reading actor/confidence.

---

## §18 — Worked walkthrough

A rejected purchase pulse, end to end:

1. The recorder logs
   `Decision(id: d-9, verdict: Reject('over-budget'), pulse: …)`.
2. `explainPulse(thePulse, handle)` finds d-9 by `traceId`.
3. The `audit` template renders the timestamped line with
   `actor`, `confidence`, `contextVersion`, and `eval`.
4. `otelSpans` emits a span with status `error` and the `mind.*`
   attributes — the dashboard can now show *why* without reading
   payloads.

No model introspection, no guesswork — the governance record is the
explanation.

---

## §19 — Template selection matrix

| Requirement | Template |
|---|---|
| Replay coordinates, compliance evidence | `audit` |
| End-user message, notification text | `ui` |
| Logs, tests, developer tooling | `debug` |
| Machine consumption | `otelSpans` (attributes), not narratives |

---

## §20 — Extending narratives

New templates are additive: add an enum value and a renderer branch.
Existing `audit`/`ui`/`debug` output is pinned by `narrative_test.dart`
— do not change their shapes without bumping the test expectations and
the CHANGELOG.

---

## §21 — Span hierarchy in practice

```dart
// Root: the model's decision (traceId t-1).
// Child: the tool call it triggered (parentTraceId t-1).
final spans = otelSpans(decisions, tracer: adapter);
// spans[0].parent == null; spans[1].parent == tracer.currentContext of 0.
```

Phase 5's `toolRouter` preserves pulse contexts, so chained tool
calls reconstruct as parent/child spans automatically when the model
emits child pulses with `parentTraceId` set.

---

## §22 — Summary table

| Entry point | Input | Output |
|---|---|---|
| `explain(decision)` | one decision | `DecisionPath` |
| `explainPulse(pulse, handle)` | a pulse + log | first match or null |
| `explainSource(cell, handle)` | a cell + log | all matches |
| `otelSpans(decisions, tracer)` | a log + adapter | ended spans |

The projection is the product: small, pure, and replayable.

---

## §23 — Integration checklist

- [ ] Pulses carry `traceId` (and `parentTraceId` for chains).
- [ ] The decision log is retained for the audit window.
- [ ] A `Tracer` adapter exists beside the tracing SDK setup.
- [ ] `audit` narratives are the persisted format (ids + versions).
- [ ] `ui` narratives never leak ids to end users.
- [ ] Action-only workflows handle `null` provenance accessors.
- [ ] Narrative shapes are pinned by tests before any template edit.

---

## §24 — Failure modes and answers

**No matching decision** — the pulse never passed the handle; check
which view the traffic actually flows through.

**All spans are roots** — `parentTraceId` missing; emit child pulses
with `Provenance.parentTraceId.entry(rootTraceId)`.

**Null actor in UI output** — the decision was action-based or the
pulse lacked provenance; the template falls back to "An actor".

**Spans out of causal order** — `otelSpans` sorts by `Decision.at`;
clock-skewed logs render skewed spans — the log is the truth.

---

## §25 — Closing note

XAI closes the loop the plan laid out: Phase 2 made decisions
visible, Phase 5 made the world observable, and now every decision —
accepted, rejected, or deferred — can be *read*. Phase 7 freezes
this surface.

---

## §26 — Reference: verdict labels

| Verdict | Audit label | Span status |
|---|---|---|
| `Accept` | `ACCEPT` | `ok` |
| `Reject(reason)` | `REJECT 'reason'` | `error` |
| `Defer(resolver)` | `DEFER 'resolver'` | `error` (unresolved) |

---

## §27 — Reference: accessor nullability

| Accessor | Null when |
|---|---|
| `actor`, `strategy`, `confidence`, `purpose`, `reason` | no pulse |
| `compliance`, `sensitivity`, `auditLevel`, `traceId` | no pulse / absent provenance |
| `command` | pulse-based decision |
| `pulse` | action-based decision |
| `evaluationTime` | not recorded |

---

## §28 — What "explainable" means here

Explainability in `cell_mind` is **reconstruction, not
interpretation**: the exact inputs (pulse provenance), the exact rule
result (verdict + annotations), and the exact coordinates (context
version, policy version, timestamps). Anything the log didn't record
is out of scope — and the log records what governance needs.
