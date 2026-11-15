# Runtime — the cognitive handle

*The recording layer: wrap a cell with a policy, log every decision,
capture outcomes.*

---

## §1 — What a cognitive handle is

A `CognitiveHandle<C>` is a bundle of five things:

| Member | Type | Meaning |
|---|---|---|
| `cell` | `C` | the principal — untouched, its behavior unchanged |
| `cognitive` | `Cell` | the governed, recording **view** (a deputy) |
| `policy` | `Policy` | the layered decision rule |
| `decisions` | `TissueList<Decision>` | the audit log |
| `outcomes` | `IngressHandle<Pulse>` | the reward channel for learning |

```dart
final handle = cognitive(
  cell: existing.cell,
  policy: domainPolicy(),
);
// Route traffic through handle.cognitive — governed AND recorded.
```

The handle is the **missing half of the cognitive loop**: Phase 1 made
`Context` executable; the handle makes decisions *visible and auditable*.

### Purity

The recording rule declares `Purity.readOnlyExternal` — it observes
(writes the log) but does not mutate the pulse or the graph. The
principal's purity is untouched.

---

## §2 — Quickstart

```dart
final src = Cell.ingress<int>(context: Context(domains: 'finance'));
final handle = cognitive(cell: src.cell, policy: contextAware());

// Pulse traffic: principal emissions flow through the view.
src.ingest(pulse); // accepted → logged as Accept
src.ingest(other); // rejected → logged as Reject('policy-rejected')

// Command traffic: apply through the view.
final outcome = await handle.cognitive.apply<int>((
  function: (int x) => x,
  arguments: (positionalArguments: [1], namedArguments: null),
  compensation: null,
));

// Audit.
for (final decision in handle.decisions) {
  print(decision); // Decision(id, Accept, 1.0.0)
}

// Reward (Phase 3 consumes this).
handle.recordOutcome(decisionId: id, reward: 1.0);
```

---

## §3 — Static mode vs dynamic mode

| | Static | Dynamic (`cognitive()`) |
|---|---|---|
| Policy enforcement | yes, at construction | yes, layered at runtime |
| Decision recording | no | yes |
| View type | concrete (`ValueCell`, `OpenCell`) | generic `Cell` |
| Principal rule evaluations | once | twice (chain + recorder) |
| Use | new code | retrofit + recording |

**Static mode** is preferred for new code:

```dart
final gate = Cell.ingress<int>(
  context: Context(domains: 'finance'),
  testRule: requiresDomainPolicy() + domainPolicy(),
);
```

**Dynamic mode** exists for retrofits and recording:

```dart
final handle = cognitive(cell: gate.cell);            // recording only
final governed = cognitive(cell: bare.cell,
    policy: domainPolicy());                          // policy + recording
```

**Both compose:** a statically-governed cell can be wrapped for
recording; the deputy chain adds the recorder on top of the static rule.

### The sharp edges (all documented, all tested)

1. **The original cell is not governed.** `handle.cell` bypasses the
   cognitive layer entirely. Route through `handle.cognitive`.
2. **`cognitive` is `Cell`, not `C`.** `ValueCell.value` and
   `OpenCell.emit` are unavailable on the view. Use `apply` for
   mutations, or static mode.
3. **The principal's rule runs twice on the deputy path.** The deputy
   chain evaluates `[principalRule, recorder]`, and the recorder
   re-runs the principal rule internally for attribution. Pure rules —
   the framework contract — make this a cost, not a semantic change.
4. **Principal rejections drop upstream.** The chain's first rule gates
   the recorder: a principal-rejected pulse or command never reaches the
   recorder and is **not logged**. See §5.

---

## §4 — The decision log

### §4.1 — The `Decision` record

```dart
final class Decision {
  final String id;               // Identity.next()
  final DateTime at;
  final Context context;         // context at decision time
  final String contextVersion;   // load-bearing for replay
  final Pulse? pulse;            // pulse decisions
  final ApplyCommand? command;   // action decisions
  final Verdict verdict;         // Accept / Reject (Defer in Phase 4)
  final String? policyVersion;
  final Duration? evaluationTime;
}
```

Three decision shapes are recorded: pulse reception, action invocation,
link establishment. Argument evaluations during action validation are
**enforcement-only** — they pass through silently, and a rejection during
argument validation is attributed to the command being validated.

### §4.2 — Querying and observing

The log is a `TissueList<Decision>` — every tissue capability applies:

```dart
final accepts = handle.decisions.where((d) => d.verdict is Accept);
final byVersion = handle.decisions
    .where((d) => d.contextVersion == '1.0.0');

final sub = Cell.observe(source: handle.decisions, effect: (Pulse p) {
  final decision = p.payload as Decision;
  // live audit stream
});
```

**Do not mutate the log from user code.** It is written by the recording
rule only; invented entries break the trainer's join (Phase 3).

### §4.3 — Serialization

`Decision.toMap()` preserves the audit shape — id, ISO timestamp, context
summary, verdict, versions, evaluation time, and `toString()`-reduced
pulse/command summaries. `Decision.fromMap()` restores the **record
shell**: live `Context` / `Pulse` / `ApplyCommand` objects are not
reconstructible (documented lossiness) and come back as `Context.system`
/ `null` / `null`. Verdicts, ids, timestamps, and versions round-trip
exactly.

### §4.4 — Truncation

`maxDecisions` (default 10000) bounds the log. When the cap is reached,
the **oldest** decision is dropped before the new one is appended. The
drop is observable through the `TissueList` removal pulse
(`type == Tissue.elementRemoved`).

```dart
final handle = cognitive(cell: cell, maxDecisions: 1000);
```

`maxDecisions: 0` (or negative) throws `ArgumentError` at construction.

---

## §5 — Attribution (principal vs policy rejection)

The recorder evaluates the two rules **sequentially** (not via
`TestCell.chain`, which does not expose which rule rejected):

| Reason | Meaning |
|---|---|
| `principal-rejected` | the cell's original `validate` returned false |
| `policy-rejected` | the layered policy returned false |
| `composite-rejected` | an `Exception` during evaluation (fail-closed) |

**Reachability on the deputy path:** the deputy chain runs the
principal's rule *first*, so a principal-rejected pulse or command never
reaches the recorder. `principal-rejected` therefore only appears when
the recorder is consulted standalone (or the principal rule is evaluated
inside it directly). `policy-rejected` is the common rejection in
dynamic mode. Both are pinned by tests.

**Composed policies attribute jointly:** `domainPolicy() +
confidencePolicy()` is one gate from the runtime's perspective — a
rejection is `policy-rejected`. Per-rule attribution is the trainer's job
(Phase 3).

**Fail-closed:** an `Exception` in the principal rule or policy records
`composite-rejected` and rejects. `Error`s (e.g. a provenance-mismatch
`StateError`) propagate loudly — they are caller bugs, not decisions.

---

## §6 — Outcomes and reward capture

The outcome channel is an `IngressHandle<Pulse>` — emittable *and*
observable. **Channel contract:** each entry's payload *is the outcome
pulse itself*:

```dart
final sub = Cell.observe(source: handle.outcomes.cell, effect: (Pulse p) {
  final outcome = p.payload as Pulse;   // unwrap once
  if (outcome.type == 'mind.outcome') {
    final map = outcome.payload as Map<String, dynamic>;
    print('${map['decisionId']} -> ${map['reward']}');
  }
});
```

The ergonomic path is `recordOutcome`:

```dart
handle.recordOutcome(
  decisionId: decision.id,
  reward: 1.0,                        // positive good, negative bad
  metadata: {'latencyMs': 12},        // optional
);
```

The flexible path emits any outcome pulse directly via
`handle.outcomes.emit(...)`. Multiple outcomes may target the same
decision id. `recordOutcome` does **not** verify the decision exists —
unresolved ids are dropped by the trainer.

---

## §7 — Lifecycle

`handle.dispose()` marks the handle disposed. In 0.2.0 this is a guard
for forward compatibility (Phase 6 agents): the log and outcome channel
remain readable, but `recordOutcome` throws after disposal. `dispose()`
is idempotent; `isDisposed` reports the state.

---

## §8 — Cross-layer composition

### §8.1 — With Phase 1 policies

Any `Policy` composes: `contextAware()`, `paranoid()`,
`domainPolicy() + confidencePolicy(min: 0.85)`, custom
`predicatePolicy(...)`. The runtime is policy-agnostic — it evaluates
whatever `TestCell` it is handed and records the composite verdict.

### §8.2 — With async policies

`TestCell` rules may return `Future<bool>`. The recorder awaits both the
principal rule and the policy and records **before** the caller observes
the result. Throwing async rules follow the substrate's fail-closed
contract.

### §8.3 — With `cell_organ`'s `TestStem`

A `Blend` is a `Cell` — `cognitive(cell: blend, policy: ...)` works and
records pulse-level decisions. The view is a generic `Cell`; stem
semantics (`.fields`, `.relations`) are unavailable on it. For
relationship-level policies use `cell_organ`'s `TestStem` composition
directly (documented in `guide/10-Design-Notes.md`).

---

## §9 — Testing a handle

The Phase 2 suite (49 tests) pins every contract in this guide:

- construction, identity, disposal (`handle_test.dart`)
- accept/reject recording on all three shapes (`recording_test.dart`)
- serialization round-trips (`decision_serialization_test.dart`)
- container sharing (`state_sharing_test.dart`)
- truncation boundaries + observability (`truncation_test.dart`)
- outcome channel contract (`outcomes_test.dart`,
  `record_outcome_test.dart`)
- mode distinction (`static_vs_dynamic_test.dart`)
- async policies (`async_recording_test.dart`)
- policy composition (`composition_test.dart`)
- end-to-end loop (`integration_test.dart`)

The canonical recipe for a new test:

```dart
final src = Cell.ingress<int>(context: ctxWithDomains('finance'));
final handle = cognitive(cell: src.cell, policy: domainPolicy());
await src.ingest(governedPulse(payload: 1, domains: 'finance'));
await Future<void>.delayed(Duration.zero);
expect(handle.decisions.single.verdict, isA<Accept>());
```

---

## §10 — AI Agent Guide notes

1. **Route through the view.** Generated code that applies commands or
   expects recording must use `handle.cognitive`, never `handle.cell`.
2. **Filter decisions by shape.** Pulse traffic, action traffic, link
   decisions, and argument-level rejections can all appear in the log —
   filter with `d.pulse != null` / `d.command != null` before asserting.
3. **Expect link decisions.** Observing the cognitive view (or any cell
   construction linking to it) records a link decision.
4. **Unwrap outcomes once.** `p.payload` of an outcome entry is the
   outcome pulse; its payload is the reward map.
5. **Stamp contexts.** The log records `contextVersion` — an unstamped
   context produces a wall of `0.0.0` entries that cannot be replayed
   across versions (`guide/04-Determinism.md`).
6. **Never write to `handle.decisions`.** Read and observe only.

---

## §11 — Phase 2 findings (recorded)

- **No receptor wrapper.** The public `Cell.deputy(testRule:)` path
  chains `[principalRule, recorder]` and shares the container, lock, and
  context — the wrapper from the draft design was unnecessary. The
  price: principal rules evaluate twice on the deputy path (pure rules
  make this safe) and principal rejections drop before the recorder.
- **The recorder widens its `host` parameter to `Cell?`.** The deputy
  chain passes the generic deputy cell as host; keeping `covariant C?`
  would throw for every `ValueCell` principal.
- **The principal rule receives the principal.** The recorder forwards
  `_cell` (not the deputy) to the principal rule — `ValueCell` rules
  enforce a covariant `ValueCell` host.
- **Argument evaluations are enforcement-only.** The substrate
  evaluates rules per argument; those evaluations pass through the log
  silently, and a rejection there is attributed to the command.
- **Outcome channel double-wraps.** `IngressHandle<Pulse>.emit` wraps
  the outcome pulse; the contract is "payload is the outcome pulse".
- **`Decision.command.compensation` is always null.** The `TestCell`
  dispatch forwards `(function, arguments)`, not the full
  `ApplyCommand`.

---

## §12 — Decision-shape reference

The log can contain entries with four shapes; filter before asserting.

| Shape | `pulse` | `command` | Produced by |
|---|---|---|---|
| Pulse decision | the pulse | null | a pulse evaluated through the view |
| Action decision | null | `(function, arguments)` | `apply` on the view |
| Link decision | null | null | an observer/cell linking to the view |
| Argument-level rejection | null | `(action, empty args)` | policy rejected an action argument |

Queries in practice:

```dart
final pulseDecisions = handle.decisions.where((d) => d.pulse != null);
final actionDecisions = handle.decisions.where((d) => d.command != null);
final linkDecisions = handle.decisions
    .where((d) => d.pulse == null && d.command == null);
```

## §13 — Error catalog

| Failure | Cause | Fix |
|---|---|---|
| `ArgumentError: maxDecisions` | cap ≤ 0 | pass a positive cap |
| `StateError: asynchronous Cell.deputy()` | custom cell returns a Future deputy | wrap the principal differently; `cognitive()` is synchronous by contract |
| `StateError: Cannot record an outcome on a disposed handle` | `recordOutcome` after `dispose()` | reorder teardown |
| `type '_Cell' is not a subtype of ... ValueCell` | pre-0.2.0 recorder covariant host bug | fixed in 0.2.0 — the recorder widens its host to `Cell?` |
| `Bad state: Cell construction failed: the upstream link was rejected` | the principal's rule rejects link objects, so the deputy cannot be constructed | make the principal's rule pass link objects (e.g. reject only `Function`s) |

## §14 — Recipes

### Recording-only retrofit

```dart
final handle = cognitive(cell: existing.cell);
// existing.cell keeps its behavior; handle.cognitive mirrors it with a log.
```

### Policy + recording on a bare cell

```dart
final handle = cognitive(
  cell: bare.cell,
  policy: contextAware(),
  maxDecisions: 1000,
);
```

### Live audit stream

```dart
final sub = Cell.observe(source: handle.decisions, effect: (Pulse p) {
  final decision = p.payload as Decision;
  if (decision.verdict is Reject) {
    alert(decision); // your monitoring hook
  }
});
```

### Bounded log with drop audit

```dart
final handle = cognitive(cell: cell, maxDecisions: 500);
Cell.observe(source: handle.decisions, effect: (Pulse p) {
  if (p.type == Tissue.elementRemoved) {
    archive(p.payload as Decision); // oldest rolled off
  }
});
```

### Reward the accepted decisions

```dart
for (final decision in handle.decisions) {
  if (decision.verdict is Accept) {
    handle.recordOutcome(decisionId: decision.id, reward: 1.0);
  }
}
```

### Static enforcement + dynamic recording

```dart
final gate = Cell.ingress<int>(
  context: Context(domains: 'finance'),
  testRule: domainPolicy(),
);
final handle = cognitive(cell: gate.cell); // recording on top
```

## §15 — Checklist for reviewing generated runtime code

- [ ] All governed traffic routes through `handle.cognitive`, never
      `handle.cell`.
- [ ] Decision-log assertions filter by shape (pulse / command / link).
- [ ] Link decisions are accounted for (observers produce them).
- [ ] Outcome observers unwrap exactly once
      (`p.payload as Pulse` → `.payload`).
- [ ] `maxDecisions` is positive; truncation behavior is understood.
- [ ] Contexts are version-stamped when replay matters.
- [ ] `dispose()` is called in teardown paths, before `recordOutcome`
      is impossible.
- [ ] The log is read/observed, never written by user code.
- [ ] Async policies are awaited through the recorder (they are).
- [ ] Principal rejections are understood to drop upstream (no log
      entry).

---

## §16 — Under the hood: how the view is built

`cognitive()` is a composition of public substrate primitives — no
private-cell access, no new runtime (P1):

```
cell.deputy(testRule: recorder)
  └─ Nucleus.evolve(principalNucleus,
       context: null,            // inherit the principal's context
       bind: principal,          // share container + lock
       testRule: chain([principalRule, recorder]),
       synapses: enabled)        // observe the principal's waves
```

The chain order is fixed by the substrate: **principal first, recorder
second**. Consequences, all tested:

1. **Policy enforcement on pulses.** The principal emits; the deputy
   (a bound observer) receives; its receptor validates with the chain;
   the recorder runs the policy and records.
2. **Policy enforcement on `apply`.** `handle.cognitive.apply(...)`
   routes through `CellBase.apply` → `validate.action(...)` → the same
   chain → recorded.
3. **Principal rejections drop upstream.** Chain short-circuit means a
   principal-rejected wave never reaches the recorder.
4. **The recorder re-runs the principal rule internally** for
   attribution, then the policy — sequential, not chained, because
   `TestCell.chain` cannot report *which* rule rejected.
5. **The recorder passes the principal to the principal rule** and the
   view to the policy. `ValueCell` rules enforce a covariant
   `ValueCell` host; the recorder's own `host` parameter is widened to
   `Cell?` because the substrate passes the deputy.

This is the smallest possible recording runtime: one deputy, one rule,
one log, one channel.

## §17 — Walkthrough: one accepted pulse

Trace a single pulse through every stage:

1. `src.ingest(pulse)` — the principal's receptor validates it against
   the principal's rule and broadcasts.
2. The deputy (bound observer) receives the wave; its receptor runs
   `cell.validate` — the chain `[principalRule, recorder]`.
3. The chain evaluates the principal rule (passes).
4. The chain evaluates the recorder: principal rule again (passes),
   then the policy (passes).
5. The recorder builds a `Decision` — fresh id, timestamp, the
   principal's context and version, the pulse, `Accept`, policy
   version, evaluation time — and appends it to the `TissueList`.
6. Downstream observers of `handle.cognitive` receive the pulse;
   observers of `handle.decisions` receive the decision.

The same walkthrough with a rejecting policy differs only at step 4:
the policy returns false, the recorder records
`Reject('policy-rejected')`, and the pulse is dropped before it reaches
the view's observers — the log is the only witness.

## §18 — Walkthrough: one applied command

1. `handle.cognitive.apply(command)` — `CellBase.apply` builds the
   receipt and calls `validate.action(...)`.
2. The chain runs its argument-validation phase: for each positional
   argument, the recorder evaluates principal + policy on the argument
   value. These evaluations are enforcement-only — silent on pass,
   attributed to the command on rejection.
3. The chain runs its action phase: the recorder evaluates principal +
   policy on the command function, reconstructs the command from
   `(function, arguments)`, and records the verdict.
4. The apply continues to execution (accept) or returns
   `ApplyRejected` (reject) — in both cases the decision is already in
   the log before the caller observes the outcome.

## §19 — Phase 2 test inventory

| File | Tests | Pins |
|---|---|---|
| `handle_test.dart` | 7 | construction, identity, disposal, cap validation |
| `recording_test.dart` | 8 | accept/reject provenance, pulse/link paths, attribution docs |
| `decision_serialization_test.dart` | 8 | verdict/id/time/version round-trips, lossiness |
| `state_sharing_test.dart` | 4 | container sharing, ungoverned principal |
| `truncation_test.dart` | 4 | cap boundaries, removal observability |
| `outcomes_test.dart` | 2 | channel contract, multi-outcome |
| `static_vs_dynamic_test.dart` | 4 | mode distinction |
| `async_recording_test.dart` | 4 | async accept/reject/throw/compose |
| `record_outcome_test.dart` | 3 | payload shape, metadata, ghost ids |
| `composition_test.dart` | 3 | contextAware + composed attribution |
| `integration_test.dart` | 3 | end-to-end loop |

Total: 50 runtime tests; 184 across the package.

---

## §20 — Cross-cutting notes for later phases

- **Phase 3 (learning)** consumes `handle.decisions` (joined with
  `handle.outcomes` by decision id) and the `contextVersion` stamps.
  The trainer must skip decisions without outcomes and dedupe the
  argument-level rejections (same command, two entries possible).
- **Phase 4 (approval)** adds `Defer` as a third verdict and an
  `onDeferred` resolver parameter — both are additive to the sealed
  `Verdict` hierarchy and the handle's constructor.
- **Phase 5 (bridges)** wraps tool dispatches with the same handle
  pattern: the router's decisions are decisions.
- **Phase 6 (agents)** gives `dispose()` its teeth — subscription
  teardown — and per-agent handles their own logs.
- **Phase 7 (stabilization)** freezes the attribution strings
  (`principal-rejected`, `policy-rejected`, `composite-rejected`) as
  part of the public contract; they are load-bearing for XAI
  narratives.

---

## §21 — API quick reference

```dart
// Construction
CognitiveHandle<C> cognitive<C extends Cell>({
  required C cell,
  Policy policy = TestCell.allowAll,
  int maxDecisions = 10000,
});

// Handle members
C get cell;                    // untouched principal
Cell get cognitive;            // governed, recording view
Policy get policy;             // layered rule
TissueList<Decision> get decisions;   // audit log
IngressHandle<Pulse> get outcomes;    // reward channel
bool get isDisposed;
int get maxDecisions;

void recordOutcome({
  required String decisionId,
  required double reward,
  Map<String, dynamic>? metadata,
});
void dispose();

// Decision
final class Decision {
  final String id;
  final DateTime at;
  final Context context;
  final String contextVersion;
  final Pulse? pulse;
  final ApplyCommand? command;
  final Verdict verdict;
  final String? policyVersion;
  final Duration? evaluationTime;
  Map<String, dynamic> toMap();
  static Decision fromMap(Map<String, dynamic> map);
}
```

Attribution reasons (stable strings): `'principal-rejected'`,
`'policy-rejected'`, `'composite-rejected'`.

Outcome channel contract: entry payload → outcome `Pulse`
(`type: 'mind.outcome'`) → reward map payload.
