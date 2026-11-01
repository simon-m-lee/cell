# HowTo-Context.md

**Working with Authority, Provenance, and Governance in Mitosis**
*A guide for human developers and AI prompt agents*

---

## Abstract

`Context` is the framework's authority protocol. It attaches metadata to cells, pulses, and deputies that describes **who** is acting, **why**, under **what authority**, with **what provenance**, and for **how long**. Contexts are not labels; they are participants in the framework's security and audit model, consulted at every integrity gate and preserved across every signal.

This guide walks through the three `Context` variants — `Context`, `DeputyContext`, and `PulseContext` — along with their companions `EphemeralPolicy` and `PulseEphemeralPolicy`. It shows when each is used, how they compose, how they are resolved, and how they participate in the reciprocal handshake between signals and receptors.

**The document is organized into two parts:**

- **Part I — Human Guide.** Prose sections for developers who are learning the model. Read sequentially.
- **Part II — AI Coding Agent Decision Tree.** A dedicated, procedural section for AI prompt agents. Do not read Part I first; jump straight to Part II if you are an agent generating context-related code.

Both parts cover the same underlying material. They differ only in presentation.

---

## Table of Contents

**Part I — Human Guide**
1. [The Three Context Variants](#1-the-three-context-variants)
2. [Context: The Base Authority Protocol](#2-context-the-base-authority-protocol)
3. [Named Context Factories](#3-named-context-factories)
4. [DeputyContext: Delegation and Mandate](#4-deputycontext-delegation-and-mandate)
5. [PulseContext: Provenance for a Single Signal](#5-pulsecontext-provenance-for-a-single-signal)
6. [EphemeralPolicy: Lifecycle Governance](#6-ephemeralpolicy-lifecycle-governance)
7. [PulseEphemeralPolicy: Signal Lifecycle](#7-pulseephemeralpolicy-signal-lifecycle)
8. [Context Resolution and the Principal Chain](#8-context-resolution-and-the-principal-chain)
9. [The Reciprocal Handshake](#9-the-reciprocal-handshake)
10. [Composing and Evolving Contexts](#10-composing-and-evolving-contexts)
11. [Auditing and Sensitivity](#11-auditing-and-sensitivity)
12. [Common Human Patterns](#12-common-human-patterns)
13. [Anti-Patterns](#13-anti-patterns)

**Part II — AI Coding Agent Decision Tree**
14. [How to Use This Section](#14-how-to-use-this-section)
15. [Decision Tree: Which Context to Create](#15-decision-tree-which-context-to-create)
16. [Procedure A: Create a Base `Context`](#16-procedure-a-create-a-base-context)
17. [Procedure B: Create a `DeputyContext`](#17-procedure-b-create-a-deputycontext)
18. [Procedure C: Create a `PulseContext`](#18-procedure-c-create-a-pulsecontext)
19. [Procedure D: Create an `EphemeralPolicy`](#19-procedure-d-create-an-ephemeralpolicy)
20. [Procedure E: Create a `PulseEphemeralPolicy`](#20-procedure-e-create-a-pulseephemeralpolicy)
21. [Procedure F: Attach a Context to a Cell, Tissue, or Organism](#21-procedure-f-attach-a-context-to-a-cell-tissue-or-organism)
22. [Procedure G: Evolve a Context](#22-procedure-g-evolve-a-context)
23. [Procedure H: Sanitize a Pulse Based on Sensitivity](#23-procedure-h-sanitize-a-pulse-based-on-sensitivity)
24. [Verification Checklist for AI Agents](#24-verification-checklist-for-ai-agents)
25. [References](#25-references)

---

# Part I — Human Guide

## 1. The Three Context Variants

The framework uses three context variants, each attached to a different kind of node:

| Variant | Attached to | Purpose |
|---|---|---|
| **`Context`** | A `Cell`, `Tissue`, or `One` | The operational authority, provenance, and metadata of a live node. |
| **`DeputyContext`** | A deputy (proxy) | The mandate under which a restricted view acts. |
| **`PulseContext`** | A single `Pulse` | The provenance, actor, and clearance of a specific signal. |

`Context` is the base class. Both `DeputyContext` and `PulseContext` are specializations. Every cell has a context — the default is `Context.system`. Every pulse has a context — the default is `PulseContext.system`.

A deputy's context is called its **mandate**; it must be a descendant of the principal's context.

---

## 2. `Context`: The Base Authority Protocol

### 2.1 What a Context Carries

A `Context` is a set of typed metadata dimensions. The standard dimensions are:

| Dimension | Type | Meaning |
|---|---|---|
| `type` | `String` | The kind of operation this context performs (e.g., `'command'`, `'telemetry'`). |
| `identity` | `String` | The specific instance name. |
| `domains` | `String` | The high-level functional areas (e.g., `'Finance'`, `'Security'`). |
| `subDomains` | `String` | Specialized zones within domains. |
| `taxonomy` | `String` | The categorical identity (e.g., `'module'`, `'enclave'`). |
| `topology` | `String` | Network role (e.g., `'Principal'`, `'Leaf'`). |
| `version` | `String` | Schema version. |
| `dataSources` | `String` | Permitted input sources. |
| `stakeholders` | `String` | Entities accountable for state transitions. |
| `constraints` | `Map<String, dynamic>` | Operational guardrails. |
| `isNot` | `String` | Explicit exclusionary boundaries. |
| `compliance` | `String` | Regulatory frameworks (e.g., `'GDPR'`). |
| `partOf` | `String` | The parent container or module. |

Dimensions marked **static pillars** (e.g., `taxonomy`, `topology`) are fixed at construction and cannot be changed via `evolve`. Dimensions marked **fluid boundaries** (e.g., `constraints`, `compliance`, `stakeholders`) are evolvable.

### 2.2 Creating a Context

```dart
final context = Context(
  taxonomy: 'module',
  domains: 'Finance',
  subDomains: 'Tax_Calculation',
  stakeholders: 'Finance_Admin, Compliance_Bot',
  constraints: {'max_amount': 1000, 'requires_approval': true},
);
```

Or, from entries:

```dart
final context = Context.fromEntries([
  Ontology.taxonomy.entry('module'),
  Ontology.domains.entry('Finance'),
  Ontology.subDomains.entry('Tax_Calculation'),
  Ontology.constraints.entry({'max_amount': 1000}),
]);
```

Use the factory constructor for explicit, readable contexts. Use `Context.fromEntries(...)` when building contexts dynamically.

### 2.3 The Default Context

The default is `Context.system`:

```dart
final cell = Cell.ingress<int>(0);      // uses Context.system implicitly
```

Every cell that does not explicitly declare a context uses `Context.system`. `Context.system` is the root of all context evolution — any specialized context is a descendant.

---

## 3. Named Context Factories

For common roles, the framework provides pre-configured factory methods that pre-fill sensible defaults.

### 3.1 `Context.core`

```dart
final gatewayContext = Context.core(
  'Gateway',
  identity: 'Public_Ingress_01',
  partOf: 'Edge_Service',
);
```

Use for system-level infrastructure nodes: gateways, hubs, orchestrators, load balancers. Sets `taxonomy: 'core'`, `domains: 'system'`, `priority: 0`.

### 3.2 `Context.module`

```dart
final paymentContext = Context.module(
  'PaymentEngine',
  identity: 'V3_Processor',
  partOf: 'Checkout_Service',
);
```

Use for application-level business logic. Sets `taxonomy: 'module'`, `domains: 'logic'`, `priority: 10`. This is the standard choice for most application cells.

### 3.3 `Context.secureEnclave`

```dart
final cryptoContext = Context.secureEnclave(
  partOf: 'CryptoModule',
  compliances: 'FIPS-140-2, PCI-DSS',
  constraints: {'min_key_size': 2048},
);
```

Use for security-critical nodes: cryptography, PII processing, admin overrides. Sets `taxonomy: 'enclave'`, `domains: 'security'`, `sensitivity: 'restricted'`, `audit_level: 'full'`, `priority: 0`.

### 3.4 `Context.publicInterface`

```dart
final apiContext = Context.publicInterface(
  partOf: 'Public_Web_API',
  domains: 'Web/v1',
  stakeholders: 'Mobile_App_Users, Partner_SDK',
);
```

Use for boundary nodes: API gateways, webhook endpoints, public ingress. Sets `taxonomy: 'interface'`, `sensitivity: 'public'`, `audit_level: 'none'`, `priority: 50`.

### 3.5 `Context.shieldedCortex`

```dart
final tradingContext = Context.shieldedCortex(
  partOf: 'Trading_Floor_A',
  domains: 'Finance/HighFreq',
  compliances: 'SEC, FINRA',
  constraints: {'max_position': 1000000},
);
```

Use for autonomous reasoning nodes that need a clean environment. Sets `taxonomy: 'cortex'`, `strategy: 'formal'`, `sensitivity: 'restricted'`, `audit_level: 'detailed'`, `priority: 10`.

### 3.6 Other Factories

The framework also provides `Context.receptor`, `Context.integrityGate`, `Context.homeostasis`, `Context.sandbox`, `Context.auditLog`, and `Context.transientTask`. Refer to the `cell` package's `context.dart` for details.

Prefer named factories over manual construction when the role matches. Named factories set `taxonomy`, `domains`, `sensitivity`, and `audit_level` sensibly.

---

## 4. `DeputyContext`: Delegation and Mandate

### 4.1 What a DeputyContext Is

A `DeputyContext` is the **mandate** under which a deputy acts. A deputy is a restricted view of a principal cell; the deputy's context describes what the deputy is authorized to do and for how long.

### 4.2 Creating a DeputyContext

```dart
final housekeepingMandate = DeputyContext(
  baseContext: room302,
  authority: 'Room_302_Master',        // The "Sovereign Resident"
  role: 'Housekeeping',                // Who is acting
  clearance: Clearance.standard,       // Access tier
  justification: 'Daily cleaning cycle',
  lease: Duration(hours: 1),
);
```

Always provide `baseContext` and `authority`. `role` and `justification` are optional but recommended for audit. `clearance` determines the access tier. `lease` defines the deputy's TTL.

### 4.3 Using a DeputyContext

```dart
final principal = Cell.state<int>(initial: 0);
final deputy = await principal.cell.deputy(
  context: housekeepingMandate,
  testRule: TestCell.readOnly,
);
```

Pass the `DeputyContext` to `.deputy()`. The deputy inherits the principal's state and lock. The deputy's test rule layers additively on top of the principal's rule.

### 4.4 Contextual Lineage

A deputy's context must be a **direct descendant** of the principal's context. Attempting to jump to an unrelated context tree triggers an assertion error. This prevents privilege escalation — a deputy can only narrow, never widen.

### 4.5 Common Clearance Tiers

| Tier | Meaning |
|---|---|
| `Clearance.observational` | Read-only access; no mutations permitted. |
| `Clearance.standard` | Standard operations within the deputy's mandate. |
| `Clearance.operational` | Elevation for operational tasks (batch jobs, maintenance). |
| `Clearance.administrative` | Full authority for configuration and policy changes. |

Default to `Clearance.standard`. Downgrade to `Clearance.observational` for read-only views. Only escalate to `Clearance.administrative` for infrastructure operations.

---

## 5. `PulseContext`: Provenance for a Single Signal

### 5.1 What a PulseContext Is

A `PulseContext` describes the provenance of a single signal. It is attached to a `Pulse` at construction and travels with the pulse through the graph.

### 5.2 Creating a PulseContext

```dart
final context = PulseContext(
  baseContext: Context.module('PaymentEngine'),
  actor: 'user_42',
  reason: 'User initiated checkout',
  purpose: 'Order fulfillment',
  strategy: ReasoningStrategy.deterministic,
  confidence: 1.0,
  priority: 60,
  sensitivity: Sensitivity.confidential,
  auditLevel: AuditLevel.full,
);
```

Provide `actor`, `reason`, and `purpose` when creating a governed pulse. `traceId` is auto-generated if not provided. `parentTraceId` links this pulse to a preceding pulse (lineage).

### 5.3 Using a PulseContext

```dart
final pulse = Pulse.governed<int>(
  payload: 42,
  context: context,
  type: 'payment.initiated',
);
```

Pass the `PulseContext` to `Pulse.governed(...)`. The pulse's `isGoverned` returns `true`. Governed pulses undergo additional validation and audit at every step.

### 5.4 Pulse Context Inheritance

When a pulse evolves via `.withStep(...)` or `.evolve(...)`, its context is preserved unless explicitly replaced. Use `.evolve(context: newContext)` only when the new context is a **direct descendant** of the current one. Attempting to replace the context with an unrelated context breaks causal integrity.

### 5.5 Trace and TraceId

Every `PulseContext` carries a `traceId` (auto-generated) and an optional `parentTraceId`. The `traceId` identifies this signal's causal wave; the `parentTraceId` links to the wave that emitted this one. Use both for forensic reconstruction.

---

## 6. `EphemeralPolicy`: Lifecycle Governance

### 6.1 What an Ephemeral Policy Is

An `EphemeralPolicy` governs a cell's or tissue's lifetime. It can set a TTL, an event limit, or a custom invalidation condition.

### 6.2 Creating an Ephemeral Policy

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onInvalidate: (nucleus) {
    print('Cell ${nucleus} expired');
    return true;
  },
);
```

`duration:` sets the TTL. `onInvalidate:` is invoked once when the terminal condition is met. If it returns `true`, the cell is neutralised.

### 6.3 Attaching an Ephemeral Policy

```dart
final cell = Cell.governed(
  ephemeralPolicy: policy,
  context: Context.module('TransientTask'),
);
```

Pass `ephemeralPolicy:` to any factory that accepts it. The policy is hosted in the cell's nucleus — the cell is governed. When the policy's terminal condition is met, the cell's `isInvalidated` becomes `true`.

### 6.4 Invalidation Cascade

When a principal is invalidated, all its deputies are automatically invalidated. This prevents stale deputies from continuing to broadcast. The cascade is automatic.

### 6.5 Ephemeral Policy vs. Context

`Context` describes **what** the cell is and **who** it acts for. `EphemeralPolicy` describes **how long** the cell lives. Both can be attached to the same cell. A cell with a policy is **governed** — its `isGoverned` returns `true`.

---

## 7. `PulseEphemeralPolicy`: Signal Lifecycle

### 7.1 What a Pulse Ephemeral Policy Is

A `PulseEphemeralPolicy` governs a single pulse's lifetime. It can set a TTL, a hop limit, or a custom invalidation condition.

### 7.2 Creating a Pulse Ephemeral Policy

```dart
final pulsePolicy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 5,
  onEvent: (pulse, {required policy}) {
    return (hops: policy.hops + 1);
  },
  onInvalidate: (pulse) {
    print('Pulse expired');
    return true;
  },
);
```

`duration:` sets the TTL. `hopLimit:` limits how many nodes the pulse can traverse. `onEvent:` is invoked at each hop. `onInvalidate:` is invoked once when the terminal condition is met.

### 7.3 Attaching a Pulse Ephemeral Policy

```dart
final pulse = Pulse.governed<int>(
  payload: 42,
  policy: pulsePolicy,
  context: context,
);
```

Pass `policy:` to `Pulse.governed(...)`. When the pulse's TTL expires or its hop limit is reached, its `isInvalidated` becomes `true`. An invalidated pulse refuses to propagate further — it neutralises itself.

### 7.4 The "Pulse Rejects Self" Property

An invalidated pulse does not wait for the framework to prune it; it refuses to hop. This is a manifestation of the "pulse as participant" principle.

---

## 8. Context Resolution and the Principal Chain

### 8.1 Tiered Resolution

When a cell's context is accessed, the framework resolves it in this order:

1. **Local override** — if the cell's nucleus has a local context.
2. **Prototype inheritance** — if the cell is a deputy, walks up the `principal` chain.
3. **Causal binding** — if the cell has a `bind` upstream, adopts the bound cell's context.
4. **Global default** — `Context.system`.

### 8.2 Context Immutability

Once a cell is created, its context cannot be changed. The context is established during the **Reciprocal Handshake** at the cell's synthesis.

### 8.3 The Principal Chain

A deputy's context is a descendant of its principal's context. Walking the principal chain resolves the ultimate ancestor. The chain terminates at `Context.system`.

---

## 9. The Reciprocal Handshake

### 9.1 What the Handshake Is

The **reciprocal handshake** is the protocol that authenticates a pulse to a receptor before the pulse reveals its payload.

### 9.2 How It Works

When a governed pulse reaches a governed receptor:

1. The receptor presents its context to the pulse.
2. The pulse evaluates the receptor's authority.
3. If the receptor's authority satisfies the pulse's mandate, the pulse reveals its payload.
4. If not, the pulse returns `null` — the signal is neutralised.

The handshake is bidirectional — both sides validate each other. A pulse with `Sensitivity.confidential` requires a receptor with matching or higher clearance.

### 9.3 PulseShell

A `PulseShell` is the pulse's defensive form. It hides the payload until the handshake completes.

```dart
final shell = pulse.shell;

// In the receptor:
final unlocked = shell.scrutinize(thisReceptor, null);
if (unlocked != null) {
  // Process the payload
}
```

Shells are terminal — they cannot be evolved or combined.

### 9.4 Practical Implications

Governed pulses are more expensive than ungoverned ones — the handshake runs at each node. Use governed pulses for security-sensitive operations. Use ungoverned pulses for high-frequency, low-sensitivity signals.

---

## 10. Composing and Evolving Contexts

### 10.1 Evolving a Context

```dart
final baseContext = Context.module('PaymentEngine');

final evolved = baseContext.evolve((evolvable) {
  if (evolvable == Ontology.subDomains) {
    return Ontology.subDomains.entry('Tax_Calculation');
  }
  if (evolvable == Ontology.constraints) {
    return Ontology.constraints.entry({'max_amount': 500});
  }
  return null;
});
```

`evolve(...)` returns a new context that inherits from the current one. Only **fluid boundaries** (evolvable dimensions) can be changed. Static pillars are inherited unchanged. Returning `null` from the resolver means "inherit from the parent."

### 10.2 Combining Contexts

`Context` does not overload `+` for composition. Use `Context.fromEntries(...)` to build a context from a list of entries, or `evolve(...)` to derive a context with modified fluid boundaries.

### 10.3 Lineage Tracing

```dart
final lineage = context.lineage(Ontology.subDomains);
print(lineage); // ['system', 'logic', 'Finance', 'Tax_Calculation']
```

`lineage(dimension)` walks the parent chain and returns the ordered list of values for the given dimension.

---

## 11. Auditing and Sensitivity

### 11.1 Sensitivity Levels

| Level | Meaning |
|---|---|
| `Sensitivity.public` | Safe for any audience. |
| `Sensitivity.internal` | Restricted to internal systems. |
| `Sensitivity.private` | Restricted to specific roles. |
| `Sensitivity.confidential` | Restricted to specific actors. |
| `Sensitivity.restricted` | Highest restriction. |

### 11.2 Audit Levels

| Level | Meaning |
|---|---|
| `AuditLevel.none` | No audit. |
| `AuditLevel.minimal` | Log the fact of the operation. |
| `AuditLevel.standard` | Log the operation and its context. |
| `AuditLevel.detailed` | Log the operation, context, and full trace. |
| `AuditLevel.full` | Log everything; suitable for compliance. |

### 11.3 Sanitization

```dart
final sanitized = Cell.sanitized<UserPulse>(
  source: internalUserStore,
  redact: (pulse) => Pulse(
    pulse.payload.copyWith(email: '***@example.com'),
    type: 'ui.safe_view',
  ),
  minSensitivity: Sensitivity.confidential,
);
```

`Cell.sanitized(...)` redacts pulses whose sensitivity meets or exceeds `minSensitivity`. The original source remains intact — redaction happens at the sanitization cell.

---

## 12. Common Human Patterns

### 12.1 Scoped Read-Only View

```dart
final readOnly = await user.deputy(
  context: DeputyContext(
    baseContext: user.context,
    authority: 'system',
    role: 'UI_View',
    clearance: Clearance.observational,
  ),
  testRule: TestOne.readOnly,
);
```

### 12.2 Temporary Access with Lease

```dart
final temporary = await user.deputy(
  context: DeputyContext(
    baseContext: user.context,
    authority: 'system',
    role: 'Temp_Task',
    clearance: Clearance.operational,
    lease: Duration(minutes: 5),
  ),
  ephemeralPolicy: EphemeralPolicy(
    duration: Duration(minutes: 5),
    onInvalidate: (nucleus) => true,
  ),
);
```

### 12.3 Audited Transaction

```dart
final tx = Cell.txApply();

final auditContext = PulseContext(
  actor: 'system',
  reason: 'Scheduled batch',
  sensitivity: Sensitivity.private,
  auditLevel: AuditLevel.full,
);

tx.apply(user.name, () => user.name.set('Alice'),
  compensate: () => user.name.set(user.name.value),
);

await tx.commit();
```

### 12.4 Sanitization at the Boundary

```dart
final publicView = Cell.sanitized<UserPulse>(
  source: internalStore,
  redact: (pulse) => Pulse(pulse.payload.copyWith(email: '***')),
  minSensitivity: Sensitivity.confidential,
);
```

Place sanitization at the boundary between internal and external systems.

---

## 13. Anti-Patterns

❌ **Mutating contexts after creation.** Contexts are immutable. Create a new one instead.

❌ **Using unrelated contexts for deputies.** The deputy's context must descend from the principal's context.

❌ **Widening authority through a deputy.** A deputy can only narrow, never widen.

❌ **Attaching a `PulseContext` to a cell.** Use `Context` for cells, `PulseContext` for pulses.

❌ **Using `Context.describe(...)` as a legal basis.** `describe` stores text; it is not a policy enforcement.

❌ **Ignoring sensitivity.** A governed pulse with `Sensitivity.confidential` will be rejected by receptors with insufficient clearance.

❌ **Long leases for elevated mandates.** Use the shortest lease that satisfies the task.

❌ **Using `AuditLevel.full` on high-frequency operations.** The performance cost is significant.

---

# Part II — AI Coding Agent Decision Tree

## 14. How to Use This Section

This section is a procedural specification for AI prompt agents that generate context-related code. It is designed to be consumed **before** any code is written.

**Rules for AI agents:**

1. **Follow the decision tree first.** Do not skip to the procedures.
2. **Do not read Part I first.** Everything an agent needs is in Part II.
3. **Follow the numbered steps in order.** Do not reorder.
4. **✅ marks a post-condition.** Verify before proceeding.
5. **⚠️ marks a failure mode.** If observed, stop and report.
6. **❌ marks a prohibition.** Never violate.
7. **📋 marks a canonical template.** Adapt names and types; preserve structure.
8. **🔁 marks a loop invariant.** Check on each iteration.

When the user's requirement is ambiguous, ask a clarifying question **before** choosing a procedure. Never guess.

---

## 15. Decision Tree: Which Context to Create

Start at Step 1. Follow the branch that matches the user's requirement.

### Step 1 — What is the target?

Ask: "What is this context being attached to?"

- **A live cell, tissue, or organism** → Go to Step 2.
- **A deputy (restricted view)** → Go to **Procedure B** (§17).
- **A single signal (pulse)** → Go to **Procedure C** (§18).
- **A lifecycle limit for a cell** → Go to **Procedure D** (§19).
- **A lifecycle limit for a pulse** → Go to **Procedure E** (§20).
- **A cell, tissue, or organism that also needs a base context** → Go to Step 2, then **Procedure F** (§21).

✅ Post-condition: You have identified the correct procedure.

⚠️ Failure mode: If the requirement mentions multiple targets, handle each in sequence.

### Step 2 — Is the role well-known?

Ask: "Does the node fit a common role?"

- **Infrastructure (gateway, hub, orchestrator)** → Use `Context.core`. Go to **Procedure A** (§16), variant A1.
- **Application logic (business module, feature)** → Use `Context.module`. Go to **Procedure A**, variant A2.
- **Security-critical (crypto, PII, admin)** → Use `Context.secureEnclave`. Go to **Procedure A**, variant A3.
- **Boundary (API, webhook, public input)** → Use `Context.publicInterface`. Go to **Procedure A**, variant A4.
- **Autonomous reasoning (trading, medical triage)** → Use `Context.shieldedCortex`. Go to **Procedure A**, variant A5.
- **None of the above** → Go to **Procedure A**, variant A6 (manual construction).

✅ Post-condition: You have selected a Context factory variant.

⚠️ Failure mode: If the role is ambiguous, choose `Context.module` — it is the safest default.

### Step 3 — Does the node need lifecycle governance?

Ask: "Should this node automatically expire?"

- **Yes, cells/tissues/organisms** → Also run **Procedure D** (§19).
- **Yes, pulses** → Also run **Procedure E** (§20).
- **No** → Skip lifecycle policies.

✅ Post-condition: The lifecycle requirement is either addressed or explicitly declined.

### Step 4 — Does the node need provenance for emitted pulses?

Ask: "Will this node emit signals that need provenance?"

- **Yes** → Also run **Procedure C** (§18) for each pulse that needs provenance.
- **No** → Skip.

### Step 5 — Does the node need to be attached to a cell, tissue, or organism?

Ask: "Is this context going to be used immediately?"

- **Yes** → Run **Procedure F** (§21) to attach the context.
- **No** → The context is prepared for later use. Return it to the caller.

### Step 6 — Verify

Run the **Verification Checklist** (§24) before returning code.

---

## 16. Procedure A: Create a Base `Context`

Purpose: Produce a `Context` instance suitable for a cell, tissue, or organism.

### A1 — `Context.core` (Infrastructure)

📋 Canonical template:

```dart
Context.core(
  type,                    // String, e.g., 'Gateway', 'Hub', 'Orchestrator'
  identity: 'Public_Ingress_01',  // Optional String
  partOf: 'Edge_Service',          // Optional String
  others: {'rate_limit': 1000},    // Optional Map<String, dynamic>
);
```

Steps:

1. Ask the user for the `type` (e.g., `'Gateway'`). This is required.
2. Ask for `identity` (unique instance name). If not provided, omit.
3. Ask for `partOf` (parent module). If not provided, omit.
4. Ask for any custom `others` metadata. If not provided, omit.
5. Emit the `Context.core(...)` call.

✅ Post-condition: The returned context has `taxonomy: 'core'`, `domains: 'system'`, and `priority: 0` implicitly set.

⚠️ Failure mode: If `type` is empty, reject the input.

### A2 — `Context.module` (Application Logic)

📋 Canonical template:

```dart
Context.module(
  type,                    // String, e.g., 'PaymentEngine', 'UserService'
  identity: 'V3_Processor',        // Optional
  partOf: 'Checkout_Service',      // Optional
  others: {'currency': 'USD'},     // Optional
);
```

Steps: same as A1.

✅ Post-condition: `taxonomy: 'module'`, `domains: 'logic'`, `priority: 10`.

### A3 — `Context.secureEnclave` (Security)

📋 Canonical template:

```dart
Context.secureEnclave(
  partOf: 'CryptoModule',          // Required
  compliances: 'FIPS-140-2',       // Required
  constraints: {'min_key_size': 2048},  // Optional
  others: {'hsm_id': 'HSM-01'},    // Optional
);
```

Steps:

1. Ask for `partOf` (the enclosing module). Required.
2. Ask for `compliances` (comma-separated regulatory standards). Required.
3. Ask for `constraints`. Optional.
4. Emit the call.

✅ Post-condition: `taxonomy: 'enclave'`, `domains: 'security'`, `sensitivity: 'restricted'`, `audit_level: 'full'`.

### A4 — `Context.publicInterface` (Boundary)

📋 Canonical template:

```dart
Context.publicInterface(
  partOf: 'Public_Web_API',        // Required
  domains: 'Web/v1',               // Required
  stakeholders: 'Mobile_App_Users', // Optional
  others: {'rate_limit': 100},     // Optional
);
```

Steps:

1. Ask for `partOf`. Required.
2. Ask for `domains`. Required.
3. Ask for `stakeholders`. Optional.
4. Emit the call.

✅ Post-condition: `taxonomy: 'interface'`, `sensitivity: 'public'`, `audit_level: 'none'`.

### A5 — `Context.shieldedCortex` (Autonomous Reasoning)

📋 Canonical template:

```dart
Context.shieldedCortex(
  partOf: 'Trading_Floor_A',       // Required
  domains: 'Finance/HighFreq',     // Required
  compliances: 'SEC, FINRA',       // Required
  constraints: {'max_position': 1000000},  // Optional
  others: {'model': 'v2'},         // Optional
);
```

Steps:

1. Ask for `partOf`, `domains`, `compliances`. All required.
2. Ask for `constraints`, `others`. Optional.
3. Emit the call.

✅ Post-condition: `taxonomy: 'cortex'`, `strategy: 'formal'`, `sensitivity: 'restricted'`, `audit_level: 'detailed'`.

### A6 — Manual `Context(...)` Construction

📋 Canonical template:

```dart
Context(
  type: 'CustomModule',
  identity: 'Instance_01',
  taxonomy: 'custom',
  domains: 'Custom/Domain',
  subDomains: 'SubZone',
  stakeholders: 'Team_A, Team_B',
  constraints: {'key': 'value'},
  compliances: 'Internal_Policy_v2',
  partOf: 'Parent_Module',
);
```

Steps:

1. Ask the user for `type`, `taxonomy`, and `domains` — these are the minimum required for a meaningful context.
2. Ask for other dimensions. Omit any that are not provided.
3. Do **not** set `taxonomy` to `'core'`, `'module'`, `'enclave'`, `'interface'`, or `'cortex'` — these are reserved by the named factories.
4. Emit the call.

✅ Post-condition: The context is constructed and its dimensions are consistent.

⚠️ Failure mode: If `taxonomy` is one of the reserved values, warn the user and suggest the corresponding named factory.

❌ Prohibition: Do not attempt to construct a context without `taxonomy` and `domains`. The framework expects them.

---

## 17. Procedure B: Create a `DeputyContext`

Purpose: Produce a `DeputyContext` for a deputy of an existing principal.

### Steps

1. **Ask for the principal's context.** This must be a live `Context` (or a `Context` that has already been created in the current session).

2. **Ask for the `authority`.** This is the sovereign resident (a String). It is required.

3. **Ask for the `role`.** This is the deputy's function (a String). Optional but recommended.

4. **Ask for the `clearance`.** Use one of `Clearance.observational`, `Clearance.standard`, `Clearance.operational`, or `Clearance.administrative`. Default to `Clearance.standard`.

5. **Ask for the `lease`.** This is a `Duration`. Optional.

6. **Ask for the `justification`.** This is a String for audit. Optional.

7. **Emit the call:**

📋 Canonical template:

```dart
DeputyContext(
  baseContext: principal.context,   // Required
  authority: 'Room_302_Master',     // Required
  role: 'Housekeeping',             // Optional
  clearance: Clearance.standard,    // Default: standard
  lease: Duration(hours: 1),        // Optional
  justification: 'Daily cleaning',  // Optional
);
```

✅ Post-condition: The returned `DeputyContext` has `parent == principal.context`.

⚠️ Failure mode: If the principal's context is `Context.system`, verify that the user intended this. Escalating from `Context.system` requires explicit acknowledgement.

⚠️ Failure mode: If `clearance` is `Clearance.administrative` and `lease` is longer than an hour, warn the user and ask for confirmation.

❌ Prohibition: Do not construct a `DeputyContext` with a `baseContext` that is not the principal's actual context (or a descendant of it). The framework's handshake will reject it.

---

## 18. Procedure C: Create a `PulseContext`

Purpose: Produce a `PulseContext` for a governed pulse.

### Steps

1. **Ask for the `actor`.** This is the identifier of the entity emitting the pulse (a String). Required.

2. **Ask for the `reason`.** This is the immediate cause (a String). Required.

3. **Ask for the `purpose`.** This is the strategic intent (a String). Optional but recommended.

4. **Ask for the `sensitivity`.** Default to `Sensitivity.internal` if the user does not specify.

5. **Ask for the `auditLevel`.** Default to `AuditLevel.standard` if the user does not specify.

6. **Ask for the `traceId`.** If not provided, the framework auto-generates one. Omit the parameter.

7. **Ask for the `parentTraceId`.** If this pulse is emitted in response to another pulse, provide the parent's `traceId`. Otherwise, omit.

8. **Emit the call:**

📋 Canonical template:

```dart
PulseContext(
  baseContext: Context.module('PaymentEngine'),  // Optional
  actor: 'user_42',                              // Required
  reason: 'User initiated checkout',              // Required
  purpose: 'Order fulfillment',                   // Optional
  sensitivity: Sensitivity.confidential,          // Default: internal
  auditLevel: AuditLevel.full,                    // Default: standard
  parentTraceId: previousPulse.context.traceId,   // Optional
);
```

✅ Post-condition: The returned `PulseContext` has a non-null `traceId`.

⚠️ Failure mode: If `actor` or `reason` is empty, reject the input.

⚠️ Failure mode: If `sensitivity` is `Sensitivity.confidential` or higher and `auditLevel` is `AuditLevel.none`, warn the user. High-sensitivity data should be audited.

❌ Prohibition: Do not use `PulseContext` for a cell's context. Use `Context` or `DeputyContext`.

---

## 19. Procedure D: Create an `EphemeralPolicy`

Purpose: Produce an `EphemeralPolicy` that governs a cell's, tissue's, or organism's lifetime.

### Steps

1. **Ask for the `duration` (TTL).** Required if the user wants time-based expiry.

2. **Ask for the `onInvalidate` callback.** Required. The callback receives the nucleus and returns a `bool`.

3. **Determine the callback's behaviour:**
    - If the user wants the cell to be invalidated unconditionally, return `true`.
    - If the user wants to inspect the nucleus and decide, implement the logic and return accordingly.

4. **Emit the call:**

📋 Canonical template:

```dart
EphemeralPolicy(
  duration: Duration(minutes: 5),   // Required
  onInvalidate: (nucleus) => true,  // Required
);
```

✅ Post-condition: The policy has a valid `duration` and a valid `onInvalidate` callback.

⚠️ Failure mode: If `duration` is `Duration.zero` or negative, reject the input.

❌ Prohibition: Do not return `false` from `onInvalidate` without a clear reason. Returning `false` keeps the cell alive, which contradicts the policy's purpose.

---

## 20. Procedure E: Create a `PulseEphemeralPolicy`

Purpose: Produce a `PulseEphemeralPolicy` that governs a single pulse's lifetime.

### Steps

1. **Ask for the `duration`.** Optional — if omitted, the pulse has no TTL.

2. **Ask for the `hopLimit`.** Optional — if omitted, the pulse has no hop limit.

3. **Ask for the `onEvent` callback.** Optional. If provided, it is invoked at each hop and can update the policy state.

4. **Ask for the `onInvalidate` callback.** Required. The callback receives the pulse and returns a `bool`.

5. **Emit the call:**

📋 Canonical template:

```dart
PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 5,
  onEvent: (pulse, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) => true,
);
```

✅ Post-condition: The policy has at least one of `duration` or `hopLimit` set.

⚠️ Failure mode: If neither `duration` nor `hopLimit` is set, the policy does nothing. Warn the user.

---

## 21. Procedure F: Attach a Context to a Cell, Tissue, or Organism

Purpose: Attach a previously created `Context` to a live cell, tissue, or organism.

### Steps

1. **Identify the target factory.** Determine whether the target is a `Cell`, a `Tissue`, or a `One` (organism).

2. **Identify the correct parameter name.** All three use the `context:` parameter.

3. **Emit the call:**

📋 Canonical template — Cell:

```dart
Cell(
  context: myContext,
  // other parameters
);
```

📋 Canonical template — Tissue:

```dart
final list = TissueList<int>(
  context: myContext,
);
```

📋 Canonical template — Organism:

```dart
final user = User();
final scopedUser = await user.deputy(
  context: DeputyContext(
    baseContext: user.context,
    authority: 'system',
    role: 'UI_View',
    clearance: Clearance.observational,
  ),
);
```

4. **Verify the type.** The parameter accepts `Context` for cells and tissues. For deputies, it accepts `DeputyContext`.

✅ Post-condition: The target is constructed with the provided context.

⚠️ Failure mode: Passing a `PulseContext` to a cell's `context:` parameter is a type error. Reject.

❌ Prohibition: Do not attempt to change a cell's context after construction. The context is immutable.

---

## 22. Procedure G: Evolve a Context

Purpose: Derive a new context from an existing one, modifying only fluid boundaries.

### Steps

1. **Identify the base context.** This is the context to evolve from.

2. **Identify the dimensions to change.** These must be **fluid boundaries** (evolvable dimensions). Check the `Ontology` enum to confirm.

3. **Emit the call:**

📋 Canonical template:

```dart
final evolved = baseContext.evolve((evolvable) {
  if (evolvable == Ontology.subDomains) {
    return Ontology.subDomains.entry('New_SubDomain');
  }
  if (evolvable == Ontology.constraints) {
    return Ontology.constraints.entry({'new_key': 'new_value'});
  }
  return null; // inherit from parent
});
```

4. **Return `null` for dimensions not being changed.**

✅ Post-condition: The evolved context inherits static pillars from the base.

⚠️ Failure mode: Attempting to change a static pillar (e.g., `taxonomy`, `domains`) via `evolve(...)` has no effect. If the user asks to change a static pillar, explain that a new context must be created instead.

❌ Prohibition: Do not return a `GovernanceEntry` whose key does not match the `evolvable` argument.

---

## 23. Procedure H: Sanitize a Pulse Based on Sensitivity

Purpose: Redact sensitive fields from pulses before they reach a boundary.

### Steps

1. **Identify the source.** This is the cell emitting the sensitive pulses.

2. **Identify the redact function.** This function receives a pulse and returns a sanitized pulse.

3. **Determine the `minSensitivity`.** This is the threshold at which redaction is triggered. Default to `Sensitivity.confidential`.

4. **Emit the call:**

📋 Canonical template:

```dart
final sanitized = Cell.sanitized<UserPulse>(
  source: internalUserStore,
  redact: (pulse) => Pulse(
    pulse.payload.copyWith(email: '***@example.com'),
    type: 'ui.safe_view',
  ),
  minSensitivity: Sensitivity.confidential,
);
```

5. **Verify the redact function is pure.** It should not perform I/O or side effects.

✅ Post-condition: Pulses with `sensitivity >= minSensitivity` are redacted before propagating downstream.

⚠️ Failure mode: If the redact function throws, the pulse is dropped. Ensure it handles all valid inputs.

❌ Prohibition: Do not redact at the source. Place sanitization at the boundary between internal and external systems.

---

## 24. Verification Checklist for AI Agents

Before returning generated code, verify all of the following:

### Type Correctness

✅ The context type matches the target:
- `Context` for cells, tissues, organisms.
- `DeputyContext` for deputies.
- `PulseContext` for pulses.
- `EphemeralPolicy` for cell/tissue/organism lifecycle.
- `PulseEphemeralPolicy` for pulse lifecycle.

### Required Fields

✅ `Context`: `taxonomy` and `domains` are set (unless a named factory sets them).
✅ `DeputyContext`: `baseContext` and `authority` are provided.
✅ `PulseContext`: `actor` and `reason` are provided.
✅ `EphemeralPolicy`: `duration` (or equivalent) and `onInvalidate` are provided.
✅ `PulseEphemeralPolicy`: at least one of `duration` or `hopLimit` is set, plus `onInvalidate`.

### Lineage

✅ A deputy's `baseContext` descends from the principal's context.
✅ A pulse's `parentTraceId`, if provided, refers to an actual parent pulse.
✅ A deputy's `clearance` is at most equal to the principal's clearance.

### Immutability

✅ The context is not mutated after construction.
✅ Static pillars are set correctly at construction (not evolved).

### Security

✅ Sensitive pulses have `sensitivity` set to `confidential` or higher.
✅ High-sensitivity pulses have `auditLevel` set to `detailed` or `full`.
✅ Sanitization is applied at boundaries.
✅ Leases are used for elevated or temporary mandates.

### Correctness

✅ The generated code compiles.
✅ Any ambiguity in the requirement has been resolved with the user.
✅ The chosen procedure matches the decision tree's outcome.

If any check fails, correct the code before returning it. If a check cannot be verified, ask the user for clarification.

---

## 25. References

| Document | Purpose |
|---|---|
| [`README.md`](README.md) | Package overview. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Design rationale for the substrate. |
| [`HowTo-Start.md`](HowTo-Start.md) | Getting started with `cell`. |
| [`HowTo-Advanced.md`](HowTo-Advanced.md) | Index of governance machinery. |
| [`HowTo-Transaction.md`](HowTo-Transaction.md) | The `Cell.transaction` surface. |
| [`HowTo-TransactionOnApply.md`](HowTo-TransactionOnApply.md) | The `Cell.txApply` surface. |
| [`packages/cell_organ/guide/HowTo-Start.md`](../cell_organ/guide/HowTo-Start.md) | Getting started with organisms. |
| [`packages/cell_organ/guide/HowTo-Relations.md`](../cell_organ/guide/HowTo-Relations.md) | Working with relations. |
| [`packages/cell_organ/guide/Conactive_Model_Reference.md`](../cell_organ/guide/Conactive_Model_Reference.md) | The biological vocabulary explained. |

---

*If a guide and the source disagree, the source is current.*