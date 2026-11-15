# Cookbook — fifteen real-world recipes

*Copy a recipe, adapt it, move on. Every recipe below is compiled and
asserted by `test/cookbook/NN_*.dart`.*

---

## Recipe 1 — Domain-gated ingress

**Context:** only finance-domain pulses may enter the pipeline. The
gate rejects everything else before it reaches state.

```dart
final gate = Cell.ingress<int>(
  context: Context.fromEntries([Ontology.domains.entry('finance')]),
  testRule: domainPolicy(),
);
await gate.ingest(Pulse<int>.governed(
  payload: 42,
  context: PulseContext.fromEntries([Ontology.domains.entry('finance')]),
));
// Accepted. A pulse without the finance domain is dropped.
```

**Non-obvious:** `emit(value)` wraps the raw value with the ingress's
own context — the host domains are inherited, so plain emits pass.
Untagged *ingested* pulses fail.

**See:** `guide/01-Policies.md` §3.

---

## Recipe 2 — Authority-gated deputy

**Context:** the main pipeline may run anything; a deputy view may
only approve purchases.

```dart
final gate = Cell.ingress<int>();
final deputy = await gate.cell.deputy(
  context: DeputyContext(
    baseContext: gate.cell.context,
    authority: 'purchase',
  ),
  testRule: authorityPolicy(additionalVerbs: const {}),
);
await deputy.apply(ApplyCommand(
  function: () => 'purchase',
  compensation: null,
));
// Accepted: the verb matches the mandate.
```

**Non-obvious:** the gate itself is untouched — attenuation happens
at the deputy, not at the source.

**See:** `guide/01-Policies.md` §4.

---

## Recipe 3 — GDPR compliance gate

**Context:** pulses must carry the `GDPR` compliance marker.

```dart
final gate = Cell.ingress<int>(
  context: Context.fromEntries([Ontology.compliance.entry('GDPR')]),
);
final handle = cognitive(
  cell: gate.cell,
  policy: compliancePolicy(),
);
```

Pulses without `Provenance.compliance.entry('GDPR')` are rejected by
the policy (fail closed). The handle records the reason for audit.

**See:** `guide/01-Policies.md` §5.

---

## Recipe 4 — Sensitivity redaction

**Context:** confidential payloads must not leave the pipeline; a
`Policy` rejects them before they reach any observer.

```dart
final gate = Cell.ingress<String>(
  context: Context.fromEntries([Ontology.domains.entry('finance')]),
);
final handle = cognitive(
  cell: gate.cell,
  policy: sensitivityPolicy(defaultMax: Sensitivity.public) +
      predicatePolicy((object, {required host, arguments}) {
    if (object is! Pulse) return true;
    return !(object.payload as String).contains('secret');
  }),
);
```

**Non-obvious:** policies compose with `+` — the strictest layer
wins; the rejection narrative names the failing rule.

**See:** `guide/01-Policies.md` §9.

---

## Recipe 5 — LLM confidence gating

**Context:** low-confidence completions must not reach downstream
state.

```dart
final model = completion(
  invoke: (input) async => 'answer',
  actor: 'model',
  journal: RecordingJournal(),
  confidence: 0.95, // optional static confidence
);
final gate = Cell.ingress<int>();
final handle = cognitive(
  cell: gate.cell,
  policy: confidencePolicy(min: 0.9),
);
```

Pulses with `confidence < 0.9` are rejected with
`Reject('policy-rejected')`; the decision log carries the exact
confidence value for the audit.

**See:** `guide/06-Bridges.md` §3.

---

## Recipe 6 — HITL approval for high-value actions

**Context:** purchases above a threshold defer to a human.

```dart
final queue = ApprovalQueue<int>(journal: journal, ttl: ttl);
final gate = Cell.ingress<int>();
final handle = cognitive(
  cell: gate.cell,
  verdictPolicy: verdictPolicy((object, {required host, arguments}) {
    if (object is! Pulse) return const Accept();
    return (object.payload as int) > 1000
        ? const Defer('approval')
        : const Accept();
  }),
  onDeferred: approvalResolver(queue),
);
await gate.ingest(Pulse<int>.governed(payload: 5000));
final id = queue.pending.keys.single;
await queue.approve(id); // committed.value == 5000
```

**Non-obvious:** the deferred pulse is dropped from the wave — the
queue's `committed` cell is the delivery channel, never re-injection.

**See:** `guide/05-Approval.md` §4.

---

## Recipe 7 — Multi-agent debate with consensus

**Context:** three reviewers vote; two of three must agree.

```dart
final source = Cell.ingress<int>();
final agents = [
  for (final name in ['risk', 'compliance', 'supervisor'])
    await spawn(
      AgentSpec(
        name: name,
        cell: source.cell,
        mandate: DeputyContext(
          baseContext: source.cell.context,
          authority: 'agent-$name',
        ),
        routeIn: (p) => source.ingest(p as Pulse<int>),
      ),
      journal: journal,
    ),
];
final outcome = await debate(
  participants: agents,
  question: question,
  journal: journal,
  consensusThreshold: 0.7,
);
```

**Non-obvious:** debates are single-round by construction — agents
are stateless between rounds and the substrate completes a pulse at
its first terminal.

**See:** `guide/08-Agents.md` §6.

---

## Recipe 8 — Learning from rejections

**Context:** every rejection is a negative outcome; train and deploy
the learned rule.

```dart
final outcomes = recordOutcomes(handle);
// … traffic …
handle.recordOutcome(decisionId: rejectionId, reward: -1.0);
final trained = await trainOffline(
  handle: handle,
  outcomes: outcomes.log,
  baseContext: handle.cell.context,
  trainer: contextualBandit(),
  journal: journal,
);
final evolved = trained.applyTo(handle.cell.context);
// Rebuild the gate with contextAware() + learnedPolicy() on `evolved`.
```

**See:** `guide/03-Learning.md` §4.

---

## Recipe 9 — Replay a decision log

**Context:** prove the past with a `ReplayJournal`.

```dart
final recording = RecordingJournal();
// … run the pipeline with `recording` …
final replay = ReplayJournal(entries: recording.entries);
// Re-run: effect inputs must match exactly — tool invocations are
// journaled as io calls, so replay never re-invokes them.
```

**See:** `guide/02-Runtime.md` §7.

---

## Recipe 10 — Blend + cognitive

**Context:** a `cell_organ` Blend carries the domain model; the
cognitive handle records the signals that flow through its bound
ingress.

```dart
final source = Cell.ingress<int>();
final blend = Blend(
  'User',
  fields: [ValueField<Blend, String>(name: #name, value: 'ada')],
);
final handle = cognitive(cell: source.cell);
source.emit(1); // recorded beside the blend's model
```

**Non-obvious (v1.0):** `cognitive(cell: blend)` itself is not
supported — organ's `deputy` accepts only `TestStem` gates, not
`TestCell` recorders. Bind an ingress to the blend and put the
handle on the ingress. (0.6.1 removed the `TestCell` cast that
crashed on organ cells.)

**See:** `guide/11-Internals.md` §9.

---

## Recipe 11 — Compose with `TestStem`

**Context:** organ's own gate type composes with `cell_mind` policy
evaluation when both gate the same ingress.

```dart
final blend = Blend(
  'Gate',
  fields: [ValueField<Blend, String>(name: #label, value: 'g')],
  testRule: TestStem.allowAll,
);
final handle = cognitive(
  cell: source.cell,
  policy: domainPolicy(),
);
```

**See:** `test/integration/cross_library_test.dart`.

---

## Recipe 12 — Custom `Defer` resolver

**Context:** defer to a named resolver that writes an audit trail
instead of a queue.

```dart
final journal = RecordingJournal();
final handle = cognitive(
  cell: gate.cell,
  verdictPolicy: verdictPolicy((object, {required host, arguments}) =>
      const Defer('audit')),
  onDeferred: (decision, verdict) async {
    if (verdict is! Defer || verdict.resolver != 'audit') return false;
    await journal.io(
      label: 'custom.audit.deferred',
      input: decision.toMap(),
      run: () async => true,
    );
    return true;
  },
);
```

**Non-obvious:** returning `false` means "this resolver does not
handle the deferral" — the recorder then records
`Reject('defer-no-resolver')`.

**See:** `guide/05-Approval.md` §7.

---

## Recipe 13 — Deterministic training

**Context:** the same decision log must produce the same trained
policy.

```dart
final journal = RecordingJournal();
final first = await trainOffline(
  handle: handle,
  outcomes: outcomes.log,
  baseContext: context,
  trainer: contextualBandit(),
  journal: journal,
);
final replay = ReplayJournal(entries: journal.entries);
final second = await trainOffline(
  handle: handle,
  outcomes: outcomes.log,
  baseContext: context,
  trainer: contextualBandit(),
  journal: replay,
);
expect(second.toMap(), equals(first.toMap()));
```

**See:** `guide/04-Determinism.md`.

---

## Recipe 14 — Cross-domain capability handoff

**Context:** a pulse travels from the marketing domain to the
finance domain through a deputy with a new mandate.

```dart
final financeDeputy = await gate.cell.deputy(
  context: DeputyContext(
    baseContext: Context.fromEntries([
      Ontology.domains.entry('finance'),
      Mandate.authority.entry('settle'),
    ]),
    authority: 'settlement',
  ),
);
final handle = cognitive(
  cell: gate.cell,
  policy: requiresDomainPolicy(),
);
```

The deputy's `DeputyContext` is a direct descendant of the source
context; escalation beyond the mandate fails closed.

**See:** `guide/01-Policies.md` §13.

---

## Recipe 15 — XAI compliance report

**Context:** after a decision, render the audit line and spans.

```dart
final path = explainPulse(pulse, handle);
print(path?.toNarrative()); // audit template: ids + versions
otelSpans(
  handle.decisions.where((d) => d.pulse != null),
  tracer: myOtelAdapter,
);
```

**Non-obvious:** the `audit` template is the persisted format — it
carries ids, timestamps, and the context version.

**See:** `guide/07-XAI.md` §11.

---

## Cookbook summary

| # | Recipe | Modules |
|---|---|---|
| 1 | Domain-gated ingress | policy |
| 2 | Authority-gated deputy | policy + deputy |
| 3 | GDPR compliance gate | policy + runtime |
| 4 | Sensitivity redaction | policy + runtime |
| 5 | LLM confidence gating | policy + bridge |
| 6 | HITL approval | approval + runtime |
| 7 | Multi-agent debate | agent |
| 8 | Learning from rejections | learning |
| 9 | Replay a decision log | runtime + replay |
| 10 | Blend + cognitive | cross-library |
| 11 | Compose with TestStem | cross-library |
| 12 | Custom Defer resolver | approval |
| 13 | Deterministic training | learning + replay |
| 14 | Cross-domain handoff | policy + deputy |
| 15 | XAI compliance report | xai |

Each recipe is pinned by `test/cookbook/NN_*.dart` — CI catches any
drift between the printed code and the real API.
