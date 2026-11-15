# Policies — the decision layer

*The stateless, context-aware decision primitives. Every other cell_mind
module consumes this one.*

---

## §1 — What a policy is

A `Policy` is nothing more than a `TestCell<Cell>`:

```dart
typedef Policy = TestCell<Cell>;
```

The cell substrate already knows how to run, compose, short-circuit, and
govern with `TestCell`s. `cell_mind`'s policy module adds **vocabulary**:
fifteen factories that read `Context`, `PulseContext`, and `DeputyContext`
dimensions and turn them into accept/reject decisions.

A policy reads three inputs:

| Input | Meaning |
|---|---|
| `host` | the cell being validated — `host.context` carries the acceptor's declared ontology/mandate |
| `object` | the thing being validated — a [Pulse] (reception), a [Function] (action invocation), or a [Cell] (link establishment) |
| `arguments` | for actions, the `ApplyArguments` record |

It returns `true` (accept) or `false` (reject). Nothing else: no state, no
callbacks, no side effects. Composition is the `+` operator — an AND gate
that short-circuits.

```dart
final gate = requiresDomainPolicy() + domainPolicy() + confidencePolicy();
Cell.ingress<String>(context: context, testRule: gate); // static mode
```

### The four rules every policy obeys

1. **Object-type dispatch is explicit.** A pulse policy passes actions and
   links through (`true`); an action policy passes pulses through. See §3.
2. **Fail-closed by default.** Missing metadata rejects. Every opt-out is a
   named flag (`allowMissing`, `allowUntagged`) the caller chooses.
3. **Purity is declared.** Every factory returns a pure `TestCell`; the one
   exception is `notOlderThan`, which declares `Purity.readOnlyExternal`.
4. **The Context is read through getters.** `cell` 1.1.0 resolves
   dimensions up the prototype chain via getters (`context.domains`,
   `pulse.context.confidence`). Policies never assume where a dimension was
   declared — see the static-pillar table in §6.

---

## §2 — The fifteen factories (plus the Phase 8/9 verdict factories)

### §2.1 — Domain: `domainPolicy`, `requiresDomainPolicy`

```dart
Policy domainPolicy({
  Set<String>? additionalDomains,
  bool allowUntagged = false,
});
Policy requiresDomainPolicy();
```

`domainPolicy` accepts pulses whose **origin domains** are a subset of the
acceptor's declared domains (plus `additionalDomains`). Origin resolution:

1. No source cell → the pulse's own `PulseContext.domains` claim.
2. Source cell untagged → the pulse's claim.
3. Pulse untagged → the source cell's declared domains.
4. Both tagged → the pulse claim must be a subset of the source's; a
   mismatch throws `StateError` (a provenance bug in the caller — fail
   loudly, don't silently reject).

Decision matrix:

| Acceptor domains | Pulse domains | Decision |
|---|---|---|
| none | none | accept (nothing to enforce) |
| none | tagged | accept |
| tagged | none | **reject** unless `allowUntagged: true` |
| tagged | tagged | `origin ⊆ host ∪ additionalDomains` |

`requiresDomainPolicy` is the strict existence companion: **both** sides
must declare at least one domain. It rejects an untagged acceptor outright.

```dart
final host = Cell.ingress<int>(context: Context(domains: 'finance'));
final gate = requiresDomainPolicy() + domainPolicy();
// finance → accept; marketing → reject; untagged → reject
```

**Sharp edge:** `domainPolicy` is fail-closed on untagged pulses when the
acceptor declares domains. Chaining `requiresDomainPolicy()` is therefore
about *both-sides-tagged* enforcement, not about closing an untagged gap.

### §2.2 — Compliance: `compliancePolicy`, `complianceOverlapPolicy`

```dart
Policy compliancePolicy({Set<String>? additionalCompliance});
Policy complianceOverlapPolicy();
```

`compliancePolicy` accepts when every marker required by
`host.context.compliance` (+ `additionalCompliance`) is present in
`pulse.context.compliance`. There is **no** `allowMissing` opt-out: a
tagged acceptor that receives a pulse missing a marker rejects it — the
data cannot be legally processed.

`complianceOverlapPolicy` is stricter: both sides must declare markers and
the sets must overlap. It is the compliance-zone boundary policy — two
systems must demonstrably share a framework before data crosses.

### §2.3 — Authority: `authorityPolicy`, `exactFunctionsPolicy`

```dart
Policy authorityPolicy({
  Set<String>? additionalVerbs,
  String? Function(Function)? verbResolver,
});
Policy exactFunctionsPolicy(Set<Function> whitelist);
```

`authorityPolicy` governs **actions** (the `Function` object). It reads the
whitelist from a [DeputyContext]'s `Mandate.authority`
(`context[Mandate.authority]` — `cell` 1.1.0 exposes the dimension through
the index operator, not a getter) plus `additionalVerbs`. The verb is
extracted from the function in three tiers:

1. The custom `verbResolver`, when provided.
2. The VM tear-off shape — `Closure: (int) => int from Function 'credit':.`
   → `'credit'`.
3. Nothing — extraction fails closed (reject).

An acceptor with no declared authority accepts everything (nothing is
being enforced). Anonymous lambdas cannot be extracted — use a
`verbResolver`, or `exactFunctionsPolicy` for curated surfaces.

`exactFunctionsPolicy` compares by function identity (`==`): exactly the
whitelisted tear-offs, nothing else. This is the reliable alternative to
heuristic verb extraction.

```dart
final balance = Cell.state<int>(initial: 0, testRule:
    authorityPolicy() + clearancePolicy());
// host context: DeputyContext(baseContext: ..., authority: 'read,write')
```

### §2.4 — Clearance: `clearancePolicy`, `ApplyCategory`

```dart
enum ApplyCategory { pulse, pureAction, structuralAction, crossDomainAction }

Policy clearancePolicy({
  Map<ApplyCategory, Clearance>? requirements,
  ApplyCategory Function(Function)? categoryResolver,
});
```

`clearancePolicy` maps the *kind* of operation to a required clearance and
checks `host`'s `Mandate.clearance` (a [DeputyContext] dimension; plain
contexts default to `Clearance.standard`):

| Object | Category | Default requirement |
|---|---|---|
| `Pulse` | `pulse` | `Clearance.minimal` |
| `Function` | `categoryResolver` or `pureAction` | `Clearance.standard` |
| `Cell` (link) | `structuralAction` | `Clearance.administrative` |

Override any mapping with `requirements`; classify functions with
`categoryResolver` (e.g. a `mount()` tear-off is structurally relevant).

### §2.5 — Isolation: `isolationPolicy`

```dart
Policy isolationPolicy();
```

Isolation is a deputy-mandate dimension; a plain `Context` carries none and
passes everything. For a [DeputyContext]:

| Level | Enforces |
|---|---|
| `shared` | accept everything |
| `scoped` | pulses must originate within the acceptor's domains |
| `restricted` | `scoped` + every required compliance marker present |
| `sandboxed` | only ephemeral pulses (`pulse.policy != null`); commands/links rejected |
| `total` | reject everything (air-gapped) |

Under `scoped`/`restricted`, commands on the host cell itself pass — the
deputy's own test rule governs its command surface; isolation constrains
what reaches the deputy.

### §2.6 — Sensitivity: `sensitivityPolicy`

```dart
Policy sensitivityPolicy({Sensitivity? defaultMax});
```

Accepts pulses whose `Provenance.sensitivity` is at or below the acceptor's
declared max, read from `constraints['max_sensitivity']` (enum name or
enum value). Missing declaration falls back to `defaultMax`, then
`Sensitivity.public` — the most restrictive default. A pulse with no
sensitivity declaration rejects.

### §2.7 — Confidence: `confidencePolicy`

```dart
Policy confidencePolicy({double min = 0.85, bool allowMissing = false});
```

Accepts pulses whose `Provenance.confidence ≥ min`. Missing confidence
rejects unless `allowMissing: true`. This is the gate for probabilistic
producers (LLM outputs, sensor fusion).

### §2.8 — Strategy: `strategyPolicy`

```dart
Policy strategyPolicy(Set<ReasoningStrategy> allowed,
    {bool allowMissing = false});
```

Accepts pulses whose `Provenance.strategy` is in the allowed set — e.g.
only `deterministic` and `formal` signals may reach an integrity gate.
Missing strategy rejects unless `allowMissing: true`.

### §2.9 — Audit: `auditLevelPolicy`

```dart
Policy auditLevelPolicy({AuditLevel min = AuditLevel.standard});
```

Accepts pulses whose `Provenance.auditLevel` is at least `min`. Missing
audit level rejects — an unauditable signal cannot enter an audited cell.
There is no `allowMissing` flag: silence is exactly what this policy
exists to block.

### §2.10 — Actor: `actorPolicy`

```dart
Policy actorPolicy(Set<String> allowed, {bool allowMissing = false});
```

Accepts pulses whose `Provenance.actor` is in the allowlist. Comparison is
exact (identifiers are case-sensitive). Missing actor rejects unless
`allowMissing: true`.

### §2.11 — Purpose: `purposePolicy`

```dart
Policy purposePolicy(Set<String> allowed, {bool allowMissing = false});
```

Accepts pulses whose `Provenance.purpose` is in the allowlist — mission
scoping (a payment cell only processes `TRANSACTION_COMMIT`).

### §2.12 — Time: `notOlderThan`

```dart
Policy notOlderThan(Duration window, {required DateTime Function() clock});
```

Accepts pulses whose `timestamp` is within `window` of `clock()`'s now.
Staleness gate for late-arriving signals.

Non-obvious properties:

- **Injected clock, never `DateTime.now()`** — replayable by construction.
  In a replayable graph, feed `journal.clock`.
- **Purity is `readOnlyExternal`**; version is `'1.0.0'` (stable
  implementation identity for the replay engine).
- **Future timestamps are fresh** — clock skew is not the pulse's fault.
- **A negative window is a construction-time `ArgumentError`.**

### §2.13 — Custom: `predicatePolicy`

```dart
Policy predicatePolicy(
  bool Function(dynamic object, {required Cell host}) predicate);
```

Wraps a plain predicate as a `Policy`. The predicate receives the same
object dispatch as every factory — decide yourself which types you govern;
return `true` for the rest. A `null` host fails closed.

**Note:** the predicate receives `(object, host:)` only. If a custom rule
needs the `ApplyArguments` record, write the `TestCell` directly — the
record is available in the `TestCell` callback's `arguments` parameter.

### §2.14 — Composition helpers: `contextAware`, `paranoid`

```dart
Policy contextAware({
  bool requireDomain = true,
  bool requireCompliance = false,
  bool requireClearance = false,
  double minConfidence = 0.85,
  bool allowMissingConfidence = false,
});
Policy paranoid();
```

`contextAware()` is the recommended default for governed entry points:

```
[requiresDomainPolicy?] + domainPolicy + [compliancePolicy?]
  + [clearancePolicy?] + confidencePolicy
```

`paranoid()` is the strictest composite — ten gates: both domain
policies, `complianceOverlapPolicy`, `authorityPolicy`, `clearancePolicy`,
`isolationPolicy`, `sensitivityPolicy`, `confidencePolicy`,
`strategyPolicy(all)`, `auditLevelPolicy`. Excluded by design:
`actorPolicy`/`purposePolicy` (need caller allowlists) and `notOlderThan`
(needs a clock) — compose them on top.

### §2.15 — Prompted policies (Phase 8/9)

`promptedPolicy` and `promptedPolicyWith` are **not** `TestCell`
factories — they are `VerdictPolicy` factories for the
`verdictPolicy:` slot of `cognitive()`. They render the decision's
`Context` into a prompt, query any AI through your adapter, and
memoize the parsed verdict with a three-tier cache (verdict cache →
prompt cache → LLM), optionally against a stateful chat session.

```dart
final handle = cognitive(
  cell: gate.cell,
  policy: contextAware(),               // structural gate runs FIRST
  verdictPolicy: promptedPolicyWith(    // LLM nuance, memoized
    config: PromptConfig.policyDecider(),
    prompt: myLLM,
    journal: journal,
  ),
  onDeferred: approvalResolver(queue),
);
```

The trust boundary is unchanged: a prompted verdict (or its cached
copy) can never accept what structural policy rejected. Full
reference: `guide/12-Prompted-Policy.md`.

---

## §3 — The object-type dispatch model

`TestCell` validates three phases, and nested `TestCell`s receive the
object for each phase through `call`:

| Phase | `object` | `arguments` |
|---|---|---|
| Pulse reception | [Pulse] | `null` |
| Action invocation | [Function] | `ApplyArguments` |
| Link establishment | [Cell] | `null` |

Every factory **explicitly declares which object types it governs** and
returns `true` for the others. Consequences:

- `domainPolicy` says nothing about actions — it passes them.
- `authorityPolicy` says nothing about pulses — it passes them.
- `clearancePolicy` is cross-cutting: all three shapes have a required
  clearance, so nothing passes through silently.
- `isolationPolicy` governs pulses (and commands/links under
  `sandboxed`/`total`); under `scoped`/`restricted` other shapes pass.

This is what makes composition safe: `domainPolicy() + authorityPolicy()`
governs pulses *and* commands without either gate leaking into the other's
domain. The contract is pinned by `test/policy/pass_through_test.dart`.

**How the substrate enforces it:** a `TestCell`'s rule function is called
with the pulse object during pulse validation, the action function during
action validation, and the link cell during link validation. A throwing
rule fails closed (returning `false` for `Exception`s); `StateError`s —
like `domainPolicy`'s provenance mismatch — propagate loudly because a
provenance mismatch is a caller bug, not a rejectable decision.

---

## §4 — Composition

### §4.1 — The `+` operator and short-circuit

`+` builds an AND chain. Evaluation is left-to-right and short-circuits:
a rejection at rule N prevents rules N+1..M from running. This is a
substrate guarantee (fitness test F2) and the reason policies compose
deterministically.

### §4.2 — `contextAware()`

The safe default. For an untagged acceptor with `allowMissingConfidence:
true`, an untagged, unconfident pulse is admitted; for a tagged acceptor,
the same pulse is rejected by `domainPolicy`'s fail-closed claim check.
Both behaviors are intentional and tested.

### §4.3 — `paranoid()`

Everything at once. Expect a *fully-declared* pulse — domains, compliance
(both sides), confidence, strategy, audit level, and sensitivity — or a
rejection.

### §4.4 — Composing with user policies

```dart
final mine = predicatePolicy(
    (object, {required host}) => object is! Pulse || object.payload is int);
final gate = contextAware() + mine;
```

User policies participate in the same short-circuit algebra. Remember the
dispatch contract in your predicate: return `true` for shapes you don't
govern.

---

## §5 — Fail-closed semantics

| Policy | Missing what? | Default | Opt-out |
|---|---|---|---|
| `domainPolicy` | pulse domains (tagged host) | reject | `allowUntagged: true` |
| `requiresDomainPolicy` | either side's domains | reject | — |
| `compliancePolicy` | required marker | reject | — |
| `complianceOverlapPolicy` | either side / overlap | reject | — |
| `authorityPolicy` | verb extraction | reject | `verbResolver` |
| `clearancePolicy` | sufficient clearance | reject | requirements map |
| `isolationPolicy` | (level-dependent) | reject per level | — |
| `sensitivityPolicy` | pulse sensitivity / max | reject / `public` | `defaultMax` |
| `confidencePolicy` | pulse confidence | reject | `allowMissing: true` |
| `strategyPolicy` | pulse strategy | reject | `allowMissing: true` |
| `auditLevelPolicy` | pulse audit level | reject | — |
| `actorPolicy` | pulse actor | reject | `allowMissing: true` |
| `purposePolicy` | pulse purpose | reject | `allowMissing: true` |
| `notOlderThan` | (age > window) | reject | window size |

Two deliberate **permissive** corners, both documented:

1. `domainPolicy` accepts everything when the acceptor itself is untagged —
   there is nothing to enforce.
2. `authorityPolicy` accepts everything when no authority is declared.

Both are "no constraint declared" cases, not "constraint failed" cases.

---

## §6 — Reading Context in `cell` 1.1.0

The plan was written against `cell` 1.0.0-rc.9. The live substrate has
**static pillars** — dimensions `Context.evolve` silently ignores:

| Dimension | Evolvable? | Read via |
|---|---|---|
| `Ontology.domains` | no (static pillar) | `context.domains` |
| `Ontology.version` | no | `context.version` |
| `Ontology.constraints` | **yes** | `context.constraints` |
| `Ontology.compliance` | yes | `context.compliance` |
| `Provenance.actor` | no | `pulse.context.actor` |
| `Provenance.confidence` | yes | `pulse.context.confidence` |
| `Provenance.compliance` / `sensitivity` | no | getters |
| `Mandate.authority` | yes (deputy) | `context[Mandate.authority]` |
| `Mandate.clearance` / `isolation` | yes (deputy) | `DeputyContext` getters |

Practical consequences:

- Build tagged contexts with `Context(domains: ...)` or
  `Context.fromEntries([...])` — never `evolve` for domains.
- Stamp pulse static pillars with `PulseContext.fromEntries([...])`.
- Always read through getters — they resolve the prototype chain.

`test/helpers/fixtures.dart` encodes the full table.

---

## §7 — Worked examples

### §7.1 — Domain-gated ingress

```dart
final gate = Cell.ingress<String>(
  context: Context(domains: 'finance,audit'),
  testRule: requiresDomainPolicy() + domainPolicy(),
);
final pulse = Pulse<String>.governed(
  payload: 'trade-001',
  context: PulseContext.fromEntries([
    Provenance.actor.entry('demo'),
    Provenance.traceId.entry(Identity.next()),
    Ontology.domains.entry('finance'),
  ]),
);
await gate.ingest(pulse); // accepted
```

Run `dart run example/01_hello_policy.dart` for the full walkthrough.

### §7.2 — Authority-gated deputy

```dart
final mandate = DeputyContext(
  baseContext: Context.system,
  authority: 'read,write',
  clearance: Clearance.standard,
);
final balance = Cell.state<int>(
  initial: 1000,
  testRule: authorityPolicy() + clearancePolicy(),
);
final deputy = await balance.cell.deputy(context: mandate);
// apply(credit) → verb 'credit' not in 'read,write' → ApplyRejected
```

### §7.3 — Compliance-gated pipeline

```dart
final regulated = Cell.ingress<Map<String, dynamic>>(
  context: Context(compliances: 'GDPR'),
  testRule: compliancePolicy() + sensitivityPolicy(),
);
// A pulse must assert the GDPR marker and stay within the
// declared max_sensitivity, or it never reaches state.
```

### §7.4 — Staleness gate with a journaled clock

```dart
final freshOnly = Cell.ingress<int>(
  testRule: notOlderThan(
    Duration(minutes: 5),
    clock: () => EffectJournal.current.clock(),
  ),
);
```

In production this runs inside a journal scope; in tests, a frozen clock
makes the policy fully deterministic.

---

## §8 — Testing policies

A policy is a function — unit-test it by calling it:

```dart
final host = Cell.ingress<int>(context: ctxWithDomains('finance')).cell;
final policy = domainPolicy();
expect(
  await policy.call(governedPulse(domains: 'finance'), host: host),
  isTrue,
);
```

The Phase 1 suite (119 tests) applies this matrix per policy:

1. target accept, 2. target reject, 3. non-target pass-through,
4. missing-metadata reject, 5. explicit opt-out, 6. edge cases,
7. composition.

Static-mode behaviour (policy inside `testRule`) is covered by the
composition suite; the substrate's own guarantees (short-circuit, pulse
context) are pinned by the Phase 0 fitness suite.

---

## §9 — What this module does NOT do

- No state, no pulses, no callbacks — policies are pure gates.
- No `verdictPolicy` — the `Verdict` type ships (for Phase 2's decision
  log), but the `bool ↔ Verdict` bridge belongs to the runtime, which
  knows how to honour `Defer`.
- No recording — the decision log is Phase 2.
- No learning — the trainer is Phase 3.
- **No prompted verdicts here** — `promptedPolicy` /
  `promptedPolicyWith` (Phase 8/9) are `VerdictPolicy` factories that
  compose with these gates, not replacements for them
  (`guide/12-Prompted-Policy.md`).
- No `cell_organ` hard dependency — policies compose with `TestStem` at
  the seam documented in `guide/10-Design-Notes.md`.

---

## §10 — Reference table

| Factory | Governs | Reads | Fail-closed on |
|---|---|---|---|
| `domainPolicy` | Pulse | host/pulse/source domains | untagged claim |
| `requiresDomainPolicy` | Pulse | both sides' domains | either untagged |
| `compliancePolicy` | Pulse | host/pulse compliance | missing marker |
| `complianceOverlapPolicy` | Pulse | both sides' compliance | no overlap |
| `authorityPolicy` | Function | `Mandate.authority` + verb | unresolvable verb |
| `exactFunctionsPolicy` | Function | whitelist `==` | not in set |
| `clearancePolicy` | Pulse/Function/Cell | `Mandate.clearance` | below tier |
| `isolationPolicy` | Pulse (level-dependent) | `Mandate.isolation` | per level |
| `sensitivityPolicy` | Pulse | `constraints['max_sensitivity']` | above max / missing |
| `confidencePolicy` | Pulse | `Provenance.confidence` | below min / missing |
| `strategyPolicy` | Pulse | `Provenance.strategy` | not allowed / missing |
| `auditLevelPolicy` | Pulse | `Provenance.auditLevel` | below min / missing |
| `actorPolicy` | Pulse | `Provenance.actor` | not allowed / missing |
| `purposePolicy` | Pulse | `Provenance.purpose` | not allowed / missing |
| `notOlderThan` | Pulse | `timestamp` vs injected clock | older than window |
| `predicatePolicy` | caller-defined | caller predicate | predicate false / null host |
| `contextAware` | composite | §2.14 | composite |
| `paranoid` | composite | §2.14 | composite |

---

## §11 — AI Agent Guide notes

For agents composing policies in generated code, the decision procedure:

1. **Name the gate.** Every BRD rule ("only finance may update the
   ledger") maps to one factory, not a hand-written `TestCell`.
2. **Prefer composition over invention.** `requiresDomainPolicy() +
   domainPolicy() + confidencePolicy()` beats a bespoke closure with the
   same logic — composition is tested, versioned, and documented.
3. **Declare contexts at construction.** `Context(domains: ...)` /
   `PulseContext.fromEntries([...])` — static pillars cannot be evolved.
4. **Keep opt-outs explicit.** Every `allowMissing`/`allowUntagged` in
   generated code must carry a comment naming the business reason; the
   default is denial.
5. **Respect the dispatch contract.** Custom predicates return `true` for
   shapes they do not govern — otherwise composition silently rejects
   unrelated operations.
6. **Do not invent policies.** The catalog is closed until a phase adds a
   factory: `Cell.gate`, `Cell.policy`, and `policy(domains: ...)` do not
   exist. The fifteen factories above are the whole surface.

### Checklist for reviewing a generated policy

- [ ] The host cell's `Context` is built with the correct mechanism per
      the static-pillar table (§6).
- [ ] Missing-metadata behavior is the documented default, or the opt-out
      flag is present with a comment.
- [ ] Non-governed object shapes pass through.
- [ ] Composition order is deliberate (short-circuit means the first
      rejector wins and later rules do not run).
- [ ] Time-reading policies receive an injected clock; effectful
      observability is journalled (§2.12).
- [ ] The policy's purity is understood: everything here is `pure` except
      `notOlderThan` (`readOnlyExternal`).

---

## §12 — Phase 1 findings (recorded)

- **`domainPolicy` is fail-closed on untagged pulses** when the acceptor
  declares domains (`allowUntagged = false` default). This tightens the
  Brain-Storm draft (which defaulted permissive); `requiresDomainPolicy`
  remains the explicit both-sides-tagged gate.
- **`predicatePolicy` follows the Plan.md signature**
  (`{required Cell host}` only) — Dart function subtyping requires a
  function to declare every named parameter of its type, so adding
  `arguments` would force every predicate to accept it. Predicates that
  need `ApplyArguments` write a `TestCell` directly.
- **`Mandate.authority` has no public getter** in `cell` 1.1.0; the index
  operator (`context[Mandate.authority]`) is the read path.
- **`policy_export.dart` is omitted** — the single-library barrel includes
  `policy.dart` directly as a part; there is nothing to re-export.
- **`TestCell.allowAll` is `TestCell<Never>`** in the substrate — it
  cannot be called with a typed host, so it is not part of `cell_mind`'s
  composition algebra.
- **Provenance mismatches throw `StateError`** (an `Error`, not an
  `Exception`) — they propagate loudly through `TestCell.call` rather
  than being swallowed into a rejection. This is intentional: spoofed
  provenance is a caller bug.
