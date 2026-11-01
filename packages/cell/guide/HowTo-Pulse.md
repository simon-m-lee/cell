# HowTo-Pulse.md

**Working with Signals in the Mitosis Framework**
*A guide for human developers and AI prompt agents*

---

## Abstract

A `Pulse` is the fundamental unit of communication in Mitosis. It is not an inert value passed to an API — it is a **participant** with identity, provenance, lifecycle, and authority. Every signal that moves through the framework is a `Pulse` (or a subclass: `TissuePulse`, `RelatablePulse`, `EvolvedPulse`, `CollectivePulse`). Every mutation, every observation, every handshake is carried by a Pulse.

This guide covers the full surface of `Pulse`: how to construct one, how to evolve one, how to trace its lineage, how to attach lifecycle policies to it, how to shell it defensively, and how to interpret the reciprocal handshake between a pulse and a receptor. It is written in two parts:

- **Part I — Human Guide.** Prose sections for developers learning the model. Read sequentially.
- **Part II — AI Coding Agent Decision Tree.** A dedicated procedural section for AI prompt agents generating pulse-related code. AI agents should jump directly to Part II.

Both parts cover the same underlying material.

---

## Table of Contents

**Part I — Human Guide**
1. [What a Pulse Is](#1-what-a-pulse-is)
2. [Constructing a Pulse](#2-constructing-a-pulse)
3. [Governed Pulses and Context](#3-governed-pulses-and-context)
4. [Lifecycle: `PulseEphemeralPolicy`](#4-lifecycle-pulseephemeralpolicy)
5. [Evolving a Pulse](#5-evolving-a-pulse)
6. [Tracing a Pulse](#6-tracing-a-pulse)
7. [Collective Pulses](#7-collective-pulses)
8. [The Pulse Shell](#8-the-pulse-shell)
9. [The Reciprocal Handshake](#9-the-reciprocal-handshake)
10. [Comparing Pulses](#10-comparing-pulses)
11. [Serialising and Inspecting](#11-serialising-and-inspecting)
12. [Common Human Patterns](#12-common-human-patterns)
13. [Anti-Patterns](#13-anti-patterns)

**Part II — AI Coding Agent Decision Tree**
14. [How to Use This Section](#14-how-to-use-this-section)
15. [Decision Tree: What Do You Need to Do with a Pulse?](#15-decision-tree-what-do-you-need-to-do-with-a-pulse)
16. [Procedure A: Construct an Ungoverned Pulse](#16-procedure-a-construct-an-ungoverned-pulse)
17. [Procedure B: Construct a Governed Pulse](#17-procedure-b-construct-a-governed-pulse)
18. [Procedure C: Attach a `PulseEphemeralPolicy`](#18-procedure-c-attach-a-pulseephemeralpolicy)
19. [Procedure D: Evolve a Pulse](#19-procedure-d-evolve-a-pulse)
20. [Procedure E: Add a Trace Step](#20-procedure-e-add-a-trace-step)
21. [Procedure F: Build a Collective Pulse](#21-procedure-f-build-a-collective-pulse)
22. [Procedure G: Defensively Shell a Pulse](#22-procedure-g-defensively-shell-a-pulse)
23. [Procedure H: Scrutinize a Pulse Against a Receptor](#23-procedure-h-scrutinize-a-pulse-against-a-receptor)
24. [Procedure I: Filter or Transform a Pulse in a Receptor](#24-procedure-i-filter-or-transform-a-pulse-in-a-receptor)
25. [Procedure J: Persist Pulse Provenance](#25-procedure-j-persist-pulse-provenance)
26. [Verification Checklist for AI Agents](#26-verification-checklist-for-ai-agents)
27. [References](#27-references)

---

# Part I — Human Guide

## 1. What a Pulse Is

A `Pulse` is an immutable message that carries:

- **`payload`** — the actual data (any type `P`).
- **`type`** — a semantic classification (a `String` tag or a richer classifier).
- **`priority`** — an urgency value (0–100, higher = more urgent).
- **`context`** — provenance metadata (`PulseContext`).
- **`trace`** — a breadcrumb trail of transformation steps.
- **`policy`** — lifecycle governance (`PulseEphemeralPolicy`).
- **`source`** — the cell that emitted the pulse.
- **`timestamp`** — the moment the pulse was created.
- **`root`** — the primordial ancestor of the pulse's lineage.
- **`parent`** — the immediate ancestor (for evolved pulses).

A pulse is **immutable**. To "update" a pulse, you call `evolve(...)`, which produces a new pulse that links back to the original.

### Why a Pulse Is More Than a Value

In conventional reactive frameworks, a signal is a value. It has no identity, no history, no authority. The framework's machinery decides whether it moves.

In Mitosis, a pulse is a **participant**. It has an identity (`timestamp` + `source`), it has a history (`trace` + `parent`), and it has the **authority to refuse** — a pulse can reject the receptor it is about to enter, and it can invalidate itself.

This makes signals in Mitosis first-class citizens of the reactive graph rather than passive data.

---

## 2. Constructing a Pulse

### 2.1 The Simple Form

```dart
final pulse = Pulse('Hello, World!');
```

This creates an ungoverned pulse with:
- `payload: 'Hello, World!'`
- `type: null`
- `priority: Pulse.defaultPriority` (20)
- `context: PulseContext.system`
- `policy: null`

### 2.2 The Typed Form

```dart
final pulse = Pulse<int>(42, type: 'counter', priority: 60);
```

Explicit typing on the payload helps downstream code reason about the payload's type.

### 2.3 Non-String Types

The `type` parameter accepts any classifier, not just `String`:

```dart
enum MailAction { update, archive }

final pulse = Pulse<String>('New Email', type: MailAction.update);
```

Downstream code can `switch` on the type:

```dart
switch (pulse.type) {
  case MailAction.update:
    handleUpdate(pulse);
  case MailAction.archive:
    handleArchive(pulse);
}
```

### 2.4 Setting a Timestamp

```dart
final pulse = Pulse<int>(42, timestamp: DateTime.now());
```

Providing a timestamp makes `compareTo` ordering deterministic — useful in tests or when replaying pulses.

### 2.5 Setting a Trace Step

```dart
final pulse = Pulse<int>(42, step: 'origin');
```

The `step` parameter seeds the pulse's trace with an initial breadcrumb.

---

## 3. Governed Pulses and Context

An **ungoverned** pulse has no explicit context or policy. A **governed** pulse has at least one:

```dart
final pulse = Pulse.governed<int>(
  payload: 42,
  context: PulseContext(
    actor: 'user_42',
    reason: 'Manual adjustment',
    sensitivity: Sensitivity.confidential,
    auditLevel: AuditLevel.full,
  ),
  policy: PulseEphemeralPolicy(
    duration: Duration(seconds: 30),
    hopLimit: 5,
  ),
  type: 'counter.adjustment',
);
```

The `isGoverned` getter returns `true` for such pulses:

```dart
print(pulse.isGoverned); // true
```

### When to Govern a Pulse

- **Security-sensitive operations** — a governed pulse carries provenance that integrity gates can inspect.
- **Audited operations** — governed pulses are logged with full forensic detail.
- **Lifecycle-bounded operations** — a governed pulse can carry its own TTL or hop limit.
- **Regulatory-compliance paths** — governed pulses can carry compliance metadata.

For high-frequency, low-sensitivity signals, prefer ungoverned pulses.

---

## 4. Lifecycle: `PulseEphemeralPolicy`

A `PulseEphemeralPolicy` attaches a TTL, a hop limit, or both to a pulse:

```dart
final policy = PulseEphemeralPolicy(
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

### Behaviour

- **`duration:`** — the pulse expires after this wall-clock duration.
- **`hopLimit:`** — the pulse expires after this many hops.
- **`onEvent:`** — invoked at each hop. The return value updates the policy's state.
- **`onInvalidate:`** — invoked once when the terminal condition is met. If it returns `true`, the pulse is neutralised.

### Checking the Pulse's Lifecycle

```dart
if (pulse.isInvalidated) {
  // The pulse has expired; ignore it
  return;
}
```

An invalidated pulse refuses to propagate further. This is a manifestation of the pulse's authority — it decides its own life cycle.

---

## 5. Evolving a Pulse

`evolve(...)` produces a new pulse that links back to the original:

```dart
final original = Pulse<int>(42);
final evolved = original.evolve(step: 'validated');

print(evolved.parent == original); // true
print(evolved.payload);            // 42 (inherited from original)
print(evolved.trace);              // ['validated']
```

### Parameters

- **`pulse`** — an optional sub-pulse to append.
- **`step`** — an optional description to add to the trace.
- **`context`** — an optional new context. Must be a **direct descendant** of the current context.

At least one of `pulse`, `step`, or `context` must be non-null.

### Causal Integrity

The new context must descend from the current pulse's context. Attempting to "jump" to an unrelated context throws an assertion error:

```dart
final unrelatedContext = Context.system.evolve(...); // Unrelated to pulse's context
final bad = original.evolve(context: unrelatedContext); // AssertionError
```

This preserves the **Chain of Evidence** — a pulse's provenance cannot be forged.

---

## 6. Tracing a Pulse

### 6.1 The Trace

The `trace` field accumulates step names from all ancestors:

```dart
final evolved = original
    .withStep('validation')
    .withStep('transformation')
    .withStep('persistence');

print(evolved.trace); // ['validation', 'transformation', 'persistence']
```

### 6.2 The Parent Chain

```dart
print(evolved.parent); // the pulse after 'transformation'
print(evolved.root);   // the original pulse
```

### 6.3 Full Lineage

The `lineage<T>(arg)` method traverses the entire chain:

```dart
final history = pulse.lineage<double>(Pulse.payload);
print(history); // [100.0, 115.0, 103.5]
```

Returns values in **chronological order** (root first).

### 6.4 Walking History Backwards

```dart
Pulse? current = evolved;
while (current != null) {
  print(current.payload);
  current = current is EvolvedPulse ? current.parent : null;
}
```

This is useful for debugging — you can walk backwards to find the exact origin.

---

## 7. Collective Pulses

A **CollectivePulse** bundles multiple independent pulses into one atomic wave:

```dart
final p1 = Pulse<int>(1);
final p2 = Pulse<String>('hello');
final collective = Pulse.batch([p1, p2]);
```

Or, with the `+` operator:

```dart
final combined = p1 + p2; // equivalent
```

### Key Properties

- The collective's `payload` is an `Iterable<Pulse<P>>` — the bundled pulses.
- Each sub-pulse retains its own identity, trace, and parent chain.
- The collective is **flat** — no causal relationship between members.
- The collective's callbacks fire **once** for the batch, not per sub-pulse.

### Iterating a Collective

```dart
for (final p in collective.payload) {
  print(p.payload); // 1, hello
}
```

**Important:** Iterating the collective itself yields the collective as a single item. To access the individual pulses, iterate `collective.payload`.

---

## 8. The Pulse Shell

A **PulseShell** is a defensive proxy that hides the pulse's payload until the receiver authenticates:

```dart
final shell = pulse.shell;

// In the receiver:
final unlocked = shell.scrutinize(thisReceptor, null);
if (unlocked != null) {
  // Process the payload
}
```

### Properties

- The shell is **terminal** — cannot be evolved or combined.
- The shell hides the payload and most metadata.
- The shell forces the receiver to complete the **reciprocal handshake** before revealing the payload.

### When to Use a Shell

- Passing a pulse to untrusted code (a plugin, an external integration).
- Cross-boundary propagation where zero-trust is required.
- Compliance scenarios where access must be authenticated at every hop.

For trusted internal propagation, use the pulse directly.

---

## 9. The Reciprocal Handshake

The **reciprocal handshake** is the protocol that authenticates a pulse to a receptor before the pulse reveals its payload.

### How It Works

When a governed pulse reaches a governed receptor:

1. The receptor presents its context to the pulse (via the pulse's `scrutinize` method).
2. The pulse evaluates the receptor's authority.
3. If the receptor's authority satisfies the pulse's mandate, the pulse reveals its payload.
4. If not, the pulse returns `null` — the signal is neutralised.

### Why It Is Reciprocal

The handshake is bidirectional. The framework's integrity gate can reject a pulse; the pulse can reject the receptor. Neither side has unilateral authority.

### Manual Invocation

```dart
final unlocked = pulse.scrutinize(receptor, null);
if (unlocked != null) {
  // The receptor passed the handshake
}
```

You rarely invoke this manually — the framework does it automatically during propagation.

---

## 10. Comparing Pulses

Pulses implement `Comparable<Pulse>`. The comparison order is:

1. **Chronological** — earlier timestamps first.
2. **Priority** — higher priority first.
3. **Trace depth** — shallower traces first.

```dart
final p1 = Pulse<int>(1, timestamp: t1, priority: 50);
final p2 = Pulse<int>(2, timestamp: t2, priority: 80);

print(p1.compareTo(p2)); // positive: p2 has priority
```

This ordering ensures deterministic dispatch when multiple pulses are queued.

---

## 11. Serialising and Inspecting

### The Payload

```dart
print(pulse.payload); // the raw payload
```

For a collective, `payload` is an `Iterable<Pulse>`.

### The Envelope

```dart
print(pulse.type);          // dynamic classifier
print(pulse.priority);      // 0–100
print(pulse.timestamp);     // DateTime
print(pulse.source);        // Cell?
print(pulse.trace);         // List<String>
print(pulse.isComposite);   // true for CollectivePulse
print(pulse.isInvalidated); // true if policy expired
print(pulse.isGoverned);    // true if Context or Policy is set
```

### The Lineage

```dart
print(pulse.root);          // primordial ancestor
print(pulse.parent);        // immediate ancestor (for evolved)
```

### Unmodifiable View

```dart
final frozen = pulse.unmodifiable;
// frozen.evolve(...) still creates a new pulse, but frozen itself is sealed
```

Note: An "unmodifiable" pulse still allows evolution — evolution creates a **new** pulse. The unmodifiable envelope simply blocks direct mutations of this specific instance's metadata.

---

## 12. Common Human Patterns

### 12.1 Tracing a Value's History

```dart
final history = finalPulse.lineage<double>(Pulse.payload);
print(history); // [original, ...intermediate..., current]
```

### 12.2 Batching Independent Signals

```dart
final batch = Pulse.batch([addEvent, removeEvent, updateEvent]);
await receptor.async.call(batch);
```

### 12.3 Governed Pulse for Audited Operations

```dart
final auditPulse = Pulse.governed<String>(
  payload: 'Sensitive Operation',
  context: PulseContext(
    actor: 'admin',
    reason: 'Manual override',
    sensitivity: Sensitivity.restricted,
    auditLevel: AuditLevel.full,
  ),
);
```

### 12.4 Hop-Limited Pulse

```dart
final bounded = Pulse.governed<int>(
  payload: 42,
  policy: PulseEphemeralPolicy(
    hopLimit: 3,
    onInvalidate: (p) => true,
  ),
);
```

### 12.5 Defensive Propagation

```dart
final shell = pulse.shell;
// Send shell to untrusted consumer
sendToPlugin(shell);
```

---

## 13. Anti-Patterns

❌ **Mutating a pulse directly.** Pulses are immutable. Use `evolve(...)` to derive a new pulse.

❌ **Attempting to evolve a shell.** Shells are terminal. Unlock first via `scrutinize`.

❌ **Iterating a collective expecting sub-pulses.** Iterate `collective.payload` for sub-pulses.

❌ **Assuming `payload` is null after invalidation.** The payload remains accessible; only propagation is blocked.

❌ **Replacing a pulse's context with an unrelated one.** Contexts must follow causal lineage.

❌ **Using a shell on trusted internal paths.** Shells add unnecessary handshake overhead.

❌ **Forgetting to check `isInvalidated`.** An invalidated pulse should not be acted upon.

---

# Part II — AI Coding Agent Decision Tree

## 14. How to Use This Section

This section is a procedural specification for AI prompt agents that generate pulse-related code.

**Rules for AI agents:**

1. **Follow the decision tree first.** Do not skip to the procedures.
2. **Do not read Part I first.** Everything an agent needs is here.
3. **Follow the numbered steps in order.**
4. **✅ marks a post-condition.** Verify before proceeding.
5. **⚠️ marks a failure mode.** If observed, stop and report.
6. **❌ marks a prohibition.** Never violate.
7. **📋 marks a canonical template.** Adapt names and types; preserve structure.
8. **🔁 marks a loop invariant.** Check on each iteration.

When the requirement is ambiguous, ask a clarifying question **before** choosing a procedure.

---

## 15. Decision Tree: What Do You Need to Do with a Pulse?

Start at Step 1.

### Step 1 — Create a new pulse?

Ask: "Does the code need to create a new pulse?"

- **Yes, ungoverned** → Go to **Procedure A** (§16).
- **Yes, governed** → Go to **Procedure B** (§17).
- **No** → Go to Step 2.

### Step 2 — Attach a lifecycle?

Ask: "Does the pulse need a TTL, hop limit, or invalidation callback?"

- **Yes** → Go to **Procedure C** (§18).
- **No** → Go to Step 3.

### Step 3 — Derive a new pulse from an existing one?

Ask: "Does the code need to evolve or extend a pulse?"

- **Yes, evolve the envelope** → Go to **Procedure D** (§19).
- **Yes, add a trace step** → Go to **Procedure E** (§20).
- **No** → Go to Step 4.

### Step 4 — Bundle multiple pulses?

Ask: "Does the code need to combine several pulses into one atomic wave?"

- **Yes** → Go to **Procedure F** (§21).
- **No** → Go to Step 5.

### Step 5 — Defensively share a pulse?

Ask: "Does the pulse need to be shared with untrusted code?"

- **Yes** → Go to **Procedure G** (§22).
- **No** → Go to Step 6.

### Step 6 — Manually authenticate a pulse to a receptor?

Ask: "Does the code need to invoke the reciprocal handshake manually?"

- **Yes** → Go to **Procedure H** (§23).
- **No** → Go to Step 7.

### Step 7 — Process incoming pulses?

Ask: "Does the code need to process pulses inside a receptor?"

- **Yes** → Go to **Procedure I** (§24).
- **No** → Go to Step 8.

### Step 8 — Persist provenance?

Ask: "Does the code need to persist the pulse's trace or lineage?"

- **Yes** → Go to **Procedure J** (§25).
- **No** → Verify with the checklist in §26.

---

## 16. Procedure A: Construct an Ungoverned Pulse

Purpose: Create a simple pulse with no explicit context or policy.

### Steps

1. **Identify the payload type.** Determine the type `P` of the payload.
2. **Identify the payload value.** This is the actual data.
3. **Optionally identify the `type`.** A classifier for routing (a `String` or an `enum`).
4. **Optionally identify the `priority`.** A value between 0 and 100. Omit to use the default (20).
5. **Optionally identify the `source`.** The emitting cell.
6. **Optionally identify the `step`.** An initial trace breadcrumb.
7. **Emit the call.**

📋 Canonical template:

```dart
final pulse = Pulse<P>(
  payload,              // Required
  type: 'some.tag',     // Optional
  priority: 60,         // Optional
  source: cell,         // Optional
  step: 'origin',       // Optional
);
```

✅ Post-condition: `pulse.isGoverned` is `false`.

⚠️ Failure mode: If the payload's type does not match `P`, Dart throws a type error at compile time.

❌ Prohibition: Do not pass `context` or `policy` — those are reserved for `Pulse.governed`.

---

## 17. Procedure B: Construct a Governed Pulse

Purpose: Create a pulse with explicit context or policy.

### Steps

1. **Decide whether a context is needed.** If the operation is security-sensitive or audited, yes.
2. **Decide whether a policy is needed.** If the pulse needs a TTL or hop limit, yes.
3. **If context is needed, create the `PulseContext`** (see the companion guide `HowTo-Context.md`, Procedure C).
4. **If policy is needed, create the `PulseEphemeralPolicy`** (see Procedure C, below).
5. **Emit the call.**

📋 Canonical template:

```dart
final pulse = Pulse.governed<P>(
  payload: value,                    // Required
  context: pulseContext,             // Optional but recommended for governed pulses
  policy: pulsePolicy,               // Optional
  type: 'some.tag',                  // Optional
  priority: 60,                      // Optional
  source: cell,                      // Optional
);
```

✅ Post-condition: `pulse.isGoverned` is `true`.

⚠️ Failure mode: If neither `context` nor `policy` is provided, the pulse is not actually governed. Warn the user and suggest Procedure A instead.

❌ Prohibition: Do not mix `Pulse(...)` and `Pulse.governed(...)` syntax. Use one or the other.

---

## 18. Procedure C: Attach a `PulseEphemeralPolicy`

Purpose: Provide a lifecycle bound for a pulse.

### Steps

1. **Determine the expiry mechanism.** TTL, hop limit, or both.
2. **Determine the `duration`.** Required if TTL.
3. **Determine the `hopLimit`.** Required if hop limit.
4. **Determine the `onEvent` callback.** Optional; used to update policy state on each hop.
5. **Determine the `onInvalidate` callback.** Required; decides whether to invalidate.
6. **Emit the policy, then attach it to a governed pulse.**

📋 Canonical template:

```dart
final policy = PulseEphemeralPolicy(
  duration: Duration(seconds: 30),
  hopLimit: 5,
  onEvent: (pulse, {required policy}) => (hops: policy.hops + 1),
  onInvalidate: (pulse) {
    // Optionally log or notify
    return true;
  },
);

final pulse = Pulse.governed<int>(
  payload: 42,
  policy: policy,
);
```

✅ Post-condition: The pulse's `isInvalidated` becomes `true` after the TTL expires or the hop limit is reached.

⚠️ Failure mode: If neither `duration` nor `hopLimit` is set, the policy has no effect. Warn the user.

❌ Prohibition: Do not return `false` from `onInvalidate` unless the user has a specific reason. Returning `false` keeps the pulse alive.

---

## 19. Procedure D: Evolve a Pulse

Purpose: Derive a new pulse from an existing one, adding a trace step, sub-pulse, or new context.

### Steps

1. **Identify the base pulse.** This is the pulse to evolve from.
2. **Determine what is being added:**
    - A **step** (trace breadcrumb) — pass `step: 'description'`.
    - A **sub-pulse** — pass `pulse: subPulse`.
    - A **new context** — pass `context: newContext`. The new context must descend from the current one.
3. **Emit the call.**

📋 Canonical template:

```dart
final evolved = basePulse.evolve(
  step: 'validation',                    // Optional
  pulse: someSubPulse,                   // Optional
  context: basePulse.context.evolve(...), // Optional, must be descendant
);
```

✅ Post-condition: `evolved.parent == basePulse`.

⚠️ Failure mode: If none of `step`, `pulse`, or `context` is provided, an assertion error is thrown.

⚠️ Failure mode: If the new context is not a descendant of the current one, an assertion error is thrown.

❌ Prohibition: Do not use `evolve` to change the payload. Use a new `Pulse` instead.

---

## 20. Procedure E: Add a Trace Step

Purpose: Add a step to the pulse's trace without creating a causal branch.

### Steps

1. **Identify the pulse.**
2. **Determine the step description.** This is a `String`.
3. **Emit the call.**

📋 Canonical template:

```dart
final stepped = basePulse.withStep('sanitized');
```

✅ Post-condition: `stepped.trace` includes the new step.

⚠️ Failure mode: `withStep` does not create a new `EvolvedPulse`; it merely lengthens the trace. If a causal branch is needed, use `evolve` (Procedure D) instead.

❌ Prohibition: Do not call `withStep` on a `PulseShell`.

---

## 21. Procedure F: Build a Collective Pulse

Purpose: Bundle multiple independent pulses into one atomic wave.

### Steps

1. **Identify the pulses to bundle.** They can be of any payload type.
2. **Choose the construction method:**
    - Use `Pulse.batch([...])` for explicit bundling.
    - Use the `+` operator for ad-hoc pairing.
3. **Emit the call.**

📋 Canonical template:

```dart
final collective = Pulse.batch([p1, p2, p3]);

// Or
final combined = p1 + p2;
```

✅ Post-condition: `collective.isComposite` is `true` and `collective.payload` is an `Iterable<Pulse>`.

⚠️ Failure mode: Iterating the collective yields the collective itself, not its sub-pulses. To iterate sub-pulses, iterate `collective.payload`.

❌ Prohibition: Do not assume callbacks attached to individual sub-pulses fire separately. On a collective, callbacks fire once for the batch.

---

## 22. Procedure G: Defensively Shell a Pulse

Purpose: Prepare a pulse for untrusted propagation.

### Steps

1. **Identify the pulse.**
2. **Create the shell.**
3. **Send the shell to the untrusted receiver.**

📋 Canonical template:

```dart
final shell = pulse.shell;
untrustedReceiver.receive(shell);
```

✅ Post-condition: `shell is PulseShell` is `true`.

⚠️ Failure mode: Shells cannot be evolved. If the receiver needs to evolve the pulse, unlock it first via `scrutinize` (Procedure H).

❌ Prohibition: Do not shell pulses on trusted internal paths. The handshake overhead is not justified.

---

## 23. Procedure H: Scrutinize a Pulse Against a Receptor

Purpose: Perform the reciprocal handshake manually.

### Steps

1. **Identify the pulse or shell.**
2. **Identify the receptor.** This must have the authority to unlock the pulse.
3. **Emit the call.**

📋 Canonical template:

```dart
final unlocked = pulse.scrutinize(receptor, positionalArguments);
if (unlocked == null) {
  // Handshake failed; the pulse was neutralised
  return;
}
// Process the unlocked pulse
```

✅ Post-condition: If `unlocked != null`, the receptor passed the handshake.

⚠️ Failure mode: If `unlocked` is `null`, the receptor does not have sufficient authority. Do not attempt to bypass.

❌ Prohibition: Do not catch exceptions from `scrutinize` and continue. A failed handshake is a security outcome, not an error to be swallowed.

---

## 24. Procedure I: Filter or Transform a Pulse in a Receptor

Purpose: Implement receptor logic that inspects, filters, or transforms incoming pulses.

### Steps

1. **Identify the receptor's contract.** What pulses does it accept? What does it produce?
2. **Decide the transformation logic:**
    - **Pass-through** — return the pulse unchanged.
    - **Transform** — create a new pulse via `evolve` (Procedure D) or a fresh `Pulse` (Procedure A or B).
    - **Filter** — return `null` to drop the pulse.
3. **Emit the receptor function.**

📋 Canonical template — pass-through:

```dart
Receptor((cell, pulse, {user}) => pulse);
```

📋 Canonical template — transform:

```dart
Receptor((cell, pulse, {user}) {
  final newPayload = transform(pulse.payload);
  return Pulse(newPayload, type: 'transformed');
});
```

📋 Canonical template — filter:

```dart
Receptor((cell, pulse, {user}) {
  if (shouldDrop(pulse)) return null;
  return pulse;
});
```

✅ Post-condition: The receptor returns a `Pulse?` — `null` means the pulse is dropped.

⚠️ Failure mode: If the receptor throws, the framework catches the exception and drops the pulse. Ensure your logic is defensive.

❌ Prohibition: Do not return a `Pulse` of a different type parameter without a cast. Use a new pulse if the payload's type changes.

---

## 25. Procedure J: Persist Pulse Provenance

Purpose: Extract and persist the pulse's forensic metadata.

### Steps

1. **Identify the fields to persist:**
    - `trace` — the ordered list of steps.
    - `root` — the primordial ancestor.
    - `source` — the emitting cell.
    - `context` — the `PulseContext` (if governed).
    - `timestamp` — the creation moment.
2. **Serialise each field using its natural `toString` or a custom serialiser.**
3. **Persist the serialised form.**

📋 Canonical template:

```dart
final record = {
  'trace': pulse.trace,
  'root_timestamp': pulse.root.timestamp.toIso8601String(),
  'source': pulse.source?.toString(),
  'type': pulse.type,
  'priority': pulse.priority,
  'timestamp': pulse.timestamp.toIso8601String(),
  'is_governed': pulse.isGoverned,
};

await persist(record);
```

✅ Post-condition: The persisted record can be used for audit or debugging.

⚠️ Failure mode: If the pulse is a collective, `trace` reflects the collective's own trace, not sub-pulses'. Iterate `pulse.payload` for sub-pulse traces.

❌ Prohibition: Do not persist the payload's raw contents unless required. Payloads may contain sensitive data.

---

## 26. Verification Checklist for AI Agents

Before returning generated pulse code, verify all of the following:

### Type Correctness

✅ The payload type matches the declared generic `P`.
✅ The `context` is a `PulseContext` (not a `Context` or `DeputyContext`).
✅ The `policy` is a `PulseEphemeralPolicy` (not an `EphemeralPolicy`).

### Required Fields

✅ A pulse has a non-null payload (unless the payload is intentionally `null`).
✅ A governed pulse has at least one of `context` or `policy` set.
✅ An `evolve` call has at least one of `pulse`, `step`, or `context`.

### Lifecycle

✅ A `PulseEphemeralPolicy` has at least one of `duration` or `hopLimit` set.
✅ `onInvalidate` returns a `bool`.
✅ After invalidation, the code does not attempt to propagate the pulse further.

### Lineage

✅ Evolved pulses link to their parent.
✅ Trace steps accumulate correctly.
✅ New contexts descend from current contexts.

### Shelling

✅ Shells are sent only to untrusted receivers.
✅ Shells are not evolved before being unlocked.
✅ Failed handshakes are handled, not swallowed.

### Correctness

✅ The generated code compiles.
✅ Any ambiguity has been resolved with the user.
✅ The chosen procedure matches the decision tree's outcome.

If any check fails, correct the code before returning it. If a check cannot be verified, ask the user for clarification.

---

## 27. References

| Document | Purpose |
|---|---|
| [`README.md`](README.md) | Package overview. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Design rationale for the substrate. |
| [`HowTo-Start.md`](HowTo-Start.md) | Getting started with `cell`. |
| [`HowTo-Context.md`](HowTo-Context.md) | Working with contexts, deputies, and pulse contexts. |
| [`HowTo-Transaction.md`](HowTo-Transaction.md) | The `Cell.transaction` surface. |
| [`HowTo-TransactionOnApply.md`](HowTo-TransactionOnApply.md) | The `Cell.txApply` surface. |
| [`HowTo-Advanced.md`](HowTo-Advanced.md) | Index of governance machinery. |
| [`packages/cell_organ/guide/HowTo-Relations.md`](../cell_organ/guide/HowTo-Relations.md) | Working with relations (which emit `RelatablePulse`). |
| [`packages/cell_organ/guide/Conactive_Model_Reference.md`](../cell_organ/guide/Conactive_Model_Reference.md) | The biological vocabulary explained. |

---

*If a guide and the source disagree, the source is current.*