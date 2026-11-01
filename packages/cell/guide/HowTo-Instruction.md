# HowTo-Synapses.md

**Working with the Distribution Network in the Mitosis Framework**
*A guide for human developers and AI prompt agents*

---

## Abstract

`Synapses` is the distribution fabric of a `Cell`. When a cell's state changes and a `Pulse` is emitted, the synapses decide **who** receives the pulse, **in what form** (via filters), and **when** (via propagation policies). It is the egress half of the framework's signal flow — the counterpart to the receptor, which handles ingress.

This guide covers the full surface of `Synapses`: how to configure downstream observers, how to attach `FilterRule`s to transform or redact outgoing pulses, how to apply `PropagationPolicy`s to control timing, how to manage link and unlink at runtime, and how to reason about cycle safety and forensic tagging. It is written in two parts:

- **Part I — Human Guide.** Prose sections for developers learning the model.
- **Part II — AI Coding Agent Decision Tree.** A dedicated procedural section for AI prompt agents generating synapse-related code. AI agents should jump directly to Part II.

Both parts cover the same underlying material.

---

## Table of Contents

**Part I — Human Guide**
1. [What Synapses Are](#1-what-synapses-are)
2. [The Two Named Constants](#2-the-two-named-constants)
3. [Constructing Synapses](#3-constructing-synapses)
4. [Linking and Unlinking at Runtime](#4-linking-and-unlinking-at-runtime)
5. [Filters: Transforming Pulses Before Broadcast](#5-filters-transforming-pulses-before-broadcast)
6. [Propagation Policies: Timing Control](#6-propagation-policies-timing-control)
7. [The `relay` Override](#7-the-relay-override)
8. [Cycle Safety](#8-cycle-safety)
9. [Forensic Tagging](#9-forensic-tagging)
10. [Async Broadcasts](#10-async-broadcasts)
11. [Common Human Patterns](#11-common-human-patterns)
12. [Anti-Patterns](#12-anti-patterns)

**Part II — AI Coding Agent Decision Tree**
13. [How to Use This Section](#13-how-to-use-this-section)
14. [Decision Tree: What Kind of Synapse Configuration Do You Need?](#14-decision-tree-what-kind-of-synapse-configuration-do-you-need)
15. [Procedure A: Use `Synapses.enabled` (Default)](#15-procedure-a-use-synapsesenabled-default)
16. [Procedure B: Use `Synapses.disabled` (Terminal Node)](#16-procedure-b-use-synapsesdisabled-terminal-node)
17. [Procedure C: Configure Downstream Observers](#17-procedure-c-configure-downstream-observers)
18. [Procedure D: Attach a `FilterRule`](#18-procedure-d-attach-a-filterrule)
19. [Procedure E: Compose Filters with `+`](#19-procedure-e-compose-filters-with-)
20. [Procedure F: Configure a `PropagationPolicy`](#20-procedure-f-configure-a-propagationpolicy)
21. [Procedure G: Link and Unlink at Runtime](#21-procedure-g-link-and-unlink-at-runtime)
22. [Procedure H: Attach a Custom `relay`](#22-procedure-h-attach-a-custom-relay)
23. [Verification Checklist for AI Agents](#23-verification-checklist-for-ai-agents)
24. [References](#24-references)

---

# Part I — Human Guide

## 1. What Synapses Are

Every `Cell` has two signal-flow boundaries:

- **Ingress** — the `Receptor` handles incoming pulses.
- **Egress** — the `Synapses` handles outgoing pulses.

`Synapses` is the egress fabric. When a cell changes state and emits a pulse, the pulse passes through the cell's synapses, and the synapses decide:

1. **Who** receives the pulse — the registered downstream cells.
2. **In what form** — filters can transform or redact the pulse.
3. **When** — propagation policies can debounce, throttle, or batch delivery.

### The Four Parts of a Synapse Configuration

| Part | Purpose |
|---|---|
| **Downstreams** | The list of cells that will receive pulses. |
| **Filter** | A `FilterRule` that transforms or suppresses pulses before broadcast. |
| **Policy** | A `PropagationPolicy` that governs timing. |
| **Relay** | An optional override for the broadcast logic. |

You rarely construct a `Synapses` from scratch. The framework uses `Synapses.enabled` by default, and configuration happens through the cell's factory parameters.

---

## 2. The Two Named Constants

The framework provides two predefined synapse configurations.

### 2.1 `Synapses.enabled` (Default)

```dart
final cell = Cell(); // uses Synapses.enabled by default
```

`Synapses.enabled` signals the framework to allocate a fresh, empty observer registry when the cell is activated. It is a **flyweight placeholder**, not the actual registry.

**When to use:** For any cell that should broadcast to observers.

### 2.2 `Synapses.disabled` (Terminal)

```dart
final terminal = Cell(synapses: Synapses.disabled);
```

`Synapses.disabled` makes the cell a **terminal node** — a sink that emits no signals.

**When to use:** For cells that only consume pulses (observers, loggers, terminal UI bindings). Terminal cells have no observer registry, which saves memory.

### 2.3 Verifying Terminality

```dart
print(terminal.isTerminal); // true
```

`isTerminal` returns `true` for cells configured with `Synapses.disabled`.

---

## 3. Constructing Synapses

For fine-grained control, construct `Synapses` directly:

📋 **Canonical template:**

```dart
final synapses = Synapses(
  downstreams: [logger, analytics, uiUpdater],
  filter: redactFilter,
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
```

Then pass it to a cell factory:

```dart
final cell = Cell(synapses: synapses);
```

### Parameters

- **`downstreams`** — the initial observers to link.
- **`filter`** — a `FilterRule` applied to every outgoing pulse.
- **`policy`** — a `PropagationPolicy` governing timing.
- **`relay`** — a custom function that overrides the default broadcast.

The `Synapses` constructor is typically used when you need to pre-wire observers or customise the egress behaviour.

---

## 4. Linking and Unlinking at Runtime

Cells can be linked and unlinked dynamically:

📋 **Canonical template:**

```dart
final synapses = cell._nucleus.synapses;

final linked = await synapses.link(source, downstreamCell: observer);
if (linked) {
// observer now receives pulses
}

synapses.unlink(source, downstreamCell: observer);
// observer no longer receives pulses
```

### Validation

Linking is governed by the host cell's `TestCell` rules. If the rules reject the link, `link` returns `false`.

### Deputies and Principals

Deputies and their principals are considered equivalent for linking. Linking a deputy is equivalent to linking its principal.

### Unlinking

`unlink` returns `true` if the link was found and removed; `false` otherwise.

---

## 5. Filters: Transforming Pulses Before Broadcast

### 5.1 What a Filter Does

A `FilterRule` intercepts every outgoing pulse and can:

- **Transform** — return a new pulse.
- **Suppress** — return `null` to drop the pulse.
- **Pass through** — return the pulse unchanged.

### 5.2 Constructing a Filter

📋 **Canonical template:**

```dart
final redactFilter = FilterRule<UserData>((pulse, {user}) {
  final data = pulse.payload;
  return Pulse(data.copyWith(email: '***', phone: '***'));
});
```

The filter receives the outgoing pulse and optional `user` metadata. It returns a `Pulse` to continue or `null` to drop.

### 5.3 Filtering vs. Suppressing

```dart
// Filter — drop negative values
final positiveFilter = FilterRule<int>((pulse, {user}) {
  return pulse.payload > 0 ? pulse : null;
});
```

### 5.4 Attaching a Filter to Synapses

```dart
final cell = Cell(
  synapses: Synapses(
    downstreams: [uiObserver],
    filter: redactFilter,
  ),
);
```

The filter runs before any observer receives the pulse.

---

## 6. Propagation Policies: Timing Control

### 6.1 What a Propagation Policy Does

A `PropagationPolicy` controls **when** a pulse is delivered to downstream observers. Common strategies:

- **Immediate** — deliver synchronously (default).
- **Debounced** — deliver only after a period of silence.
- **Throttled** — deliver at a bounded rate.
- **Batched** — collect pulses and deliver them together.

### 6.2 Configuring a Debounce Policy

📋 **Canonical template:**

```dart
final debouncedSynapses = Synapses(
  downstreams: [searchHandler],
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
```

### 6.3 Composing with Filters

Filters and policies compose. The filter runs first, then the policy governs delivery timing:

```dart
final synapses = Synapses(
  downstreams: [handler],
  filter: normaliseFilter,
  policy: PropagationPolicy(
    strategy: PropagationStrategy.throttled,
    throttleTime: Duration(seconds: 1),
  ),
);
```

The resulting pipeline: `emit → filter → policy → observers`.

---

## 7. The `relay` Override

### 7.1 What `relay` Does

The `relay` parameter lets you override the default broadcast logic. When provided, the framework calls your `relay` function instead of iterating over the downstream observers.

📋 **Canonical template:**

```dart
final synapses = Synapses(
  relay: (pulse) {
    // Custom delivery logic
    for (final cell in myCustomObservers) {
      cell.receptor.call(pulse);
    }
  },
);
```

### 7.2 When to Use `relay`

- **Custom routing** — you have a non-standard topology.
- **Conditional delivery** — different observers receive different pulses.
- **Logging and metrics** — you want to instrument each broadcast.

### 7.3 When NOT to Use `relay`

For most use cases, the default broadcast is sufficient. The `downstreams` and `filter` parameters handle most customisation. Only reach for `relay` when the default iteration does not fit.

---

## 8. Cycle Safety

### 8.1 What Cycle Safety Is

The synapses fabric automatically prevents infinite loops. Every pulse carries its forensic history. When a pulse reaches a cell it has already visited, the framework silently terminates propagation for that branch.

### 8.2 Practical Implication

You do not need to guard against cycles manually. A graph like:

```
A → B → C → A
```

will not infinite-loop. The pulse is delivered to `A`, `B`, and `C` once, and then terminated.

### 8.3 Detecting Cycles

If you suspect a cycle is causing unintended termination (a pulse not reaching a downstream cell you expected), inspect the pulse's trace:

```dart
Cell.observe(
source: someCell,
effect: (pulse) {
print('Trace: ${pulse.trace}');
},
);
```

The trace shows the path the pulse has taken. If the same cell appears twice, the cycle was detected.

---

## 9. Forensic Tagging

Every signal passing through the synapse fabric is implicitly tagged with **egress metadata**. This allows the framework to reconstruct:

- Which cell emitted the pulse.
- Which synapses the pulse traversed.
- Which observers received the pulse.

### Accessing the Forensic Metadata

```dart
Cell.observe(
source: cell,
effect: (pulse) {
print('Source: ${pulse.source}');
print('Root: ${pulse.root}');
print('Trace: ${pulse.trace}');
},
);
```

The forensic metadata is preserved automatically — you do not need to configure anything.

---

## 10. Async Broadcasts

The synapses fabric provides an async view for non-blocking broadcasts:

📋 **Canonical template:**

```dart
await synapses.async.call(pulse);
```

### When to Use Async Broadcasts

- **UI updates** — you do not want to block the caller.
- **Background processing** — long-running observers.
- **Logging** — deferred delivery to a log sink.

### When NOT to Use Async

- **Order-critical paths** — async broadcast does not guarantee ordering relative to other pulses.
- **Atomic transactions** — use `Cell.transaction` or `Cell.txApply` for atomicity.

### Cycle Checking in Async Mode

Async broadcasts still perform cycle checking. The check runs on the event loop, so it does not block the caller.

---

## 11. Common Human Patterns

### 11.1 Terminal Logger

```dart
final logger = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    print('Log: ${pulse.payload}');
    return null;
  }),
);
```

### 11.2 PII-Redacting Broadcast

```dart
final cell = Cell(
  synapses: Synapses(
    downstreams: [uiWidget, analytics],
    filter: FilterRule<UserData>((pulse, {user}) {
      return Pulse(pulse.payload.copyWith(email: '***'));
    }),
  ),
);
```

### 11.3 Debounced Search

```dart
final searchSynapses = Synapses(
  downstreams: [searchApi],
  policy: PropagationPolicy(
    strategy: PropagationStrategy.debounced,
    debounceTime: Duration(milliseconds: 300),
  ),
);
```

### 11.4 Runtime Observer Attachment

```dart
final cell = Cell();

Future<void> attachObserver(Cell observer) async {
  final linked = await cell._nucleus.synapses.link(cell, downstreamCell: observer);
  if (!linked) {
    print('Link rejected by test rule');
  }
}

Future<void> detachObserver(Cell observer) async {
  cell._nucleus.synapses.unlink(cell, downstreamCell: observer);
}
```

### 11.5 Conditional Delivery

```dart
final conditionalSynapses = Synapses(
  downstreams: [],
  relay: (pulse) {
    if (pulse.priority >= 80) {
      highPriorityHandler.receptor.call(pulse);
    } else {
      lowPriorityHandler.receptor.call(pulse);
    }
  },
);
```

---

## 12. Anti-Patterns

❌ **Using `relay` for standard broadcast.** The default iteration is sufficient for most cases. Use `relay` only when you have a specific need.

❌ **Sharing an activated synapse across cells.** Synapses are per-cell registries. Do not attempt to share.

❌ **Assuming filter execution order.** In composed filters, execution follows the `+` composition order. Do not rely on undefined behaviour.

❌ **Forgetting to unlink observers.** Unremoved observers hold references and prevent garbage collection.

❌ **Assuming async broadcasts preserve order.** They do not. Use synchronous broadcasts when order matters.

❌ **Using `Synapses.disabled` for cells that need to emit.** Terminal cells cannot broadcast. Verify `isTerminal` is what you want.

❌ **Ignoring link failures.** `link` returns `false` if the rules reject the connection. Always check the return value.

---

# Part II — AI Coding Agent Decision Tree

## 13. How to Use This Section

This section is a procedural specification for AI prompt agents that generate synapse-related code.

**Rules for AI agents:**

1. **Follow the decision tree first.**
2. **Do not read Part I first.**
3. **Follow the numbered steps in order.**
4. **✅ marks a post-condition.**
5. **⚠️ marks a failure mode.**
6. **❌ marks a prohibition.**
7. **📋 marks a canonical template.**
8. **🔁 marks a loop invariant.**

When the requirement is ambiguous, ask a clarifying question **before** choosing a procedure.

---

## 14. Decision Tree: What Kind of Synapse Configuration Do You Need?

Start at Step 1.

### Step 1 — Does the cell need to broadcast?

Ask: "Does the cell need to emit pulses to downstream observers?"

- **Yes** → Go to Step 2.
- **No, terminal sink** → Go to **Procedure B** (§16).
- **Not sure** → Go to Step 2; the default is enabled.

### Step 2 — Is the default configuration sufficient?

Ask: "Does the cell need downstream observers pre-registered, filters, or a timing policy?"

- **No, use defaults** → Go to **Procedure A** (§15).
- **Yes** → Go to Step 3.

### Step 3 — What customisation is required?

Ask: "Which synapse feature does the code need?"

- **Initial downstream observers** → Include `downstreams` in the template.
- **Filter outgoing pulses** → Go to **Procedure D** (§18).
- **Compose multiple filters** → Go to **Procedure E** (§19).
- **Control timing (debounce/throttle/batch)** → Go to **Procedure F** (§20).
- **Runtime observer management** → Go to **Procedure G** (§21).
- **Custom broadcast logic** → Go to **Procedure H** (§22).

### Step 4 — Are multiple customisations needed?

Ask: "Does the code need more than one of the above?"

- **Yes** → Combine the procedures in a single `Synapses(...)` call.
- **No** → Apply the single chosen procedure.

### Step 5 — Verify

Run the **Verification Checklist** (§23).

---

## 15. Procedure A: Use `Synapses.enabled` (Default)

Purpose: Use the framework's default synapse configuration.

### Steps

1. **Do not pass a `synapses:` parameter.**
2. **Or pass `synapses: Synapses.enabled` explicitly.**

📋 Canonical template:

```dart
final cell = Cell(
  // no synapses parameter
);
```

Or, explicitly:

```dart
final cell = Cell(
  synapses: Synapses.enabled,
);
```

✅ Post-condition: The cell allocates a fresh, empty observer registry on activation. Observers can be linked at runtime.

⚠️ Failure mode: If you omit `synapses:` but the cell is meant to be terminal, the cell will consume memory for the observer registry it will never use. Use Procedure B instead.

---

## 16. Procedure B: Use `Synapses.disabled` (Terminal Node)

Purpose: Configure a cell as a terminal sink.

### Steps

1. **Pass `synapses: Synapses.disabled` to the cell factory.**

📋 Canonical template:

```dart
final observer = Cell(
  synapses: Synapses.disabled,
  receptor: Receptor((cell, pulse, {user}) {
    // Process the pulse but do not forward it
    return null;
  }),
);
```

✅ Post-condition: `observer.isTerminal` returns `true`. The cell does not maintain an observer registry.

⚠️ Failure mode: If you attempt to link an observer to a terminal cell, the link returns `false`.

❌ Prohibition: Do not use `Synapses.disabled` for cells that need to emit pulses to downstream cells.

---

## 17. Procedure C: Configure Downstream Observers

Purpose: Pre-register observers on a cell's synapses.

### Steps

1. **Identify the downstream cells.**
2. **Pass them to `Synapses(downstreams: [...])`.**

📋 Canonical template:

```dart
final cell = Cell(
  synapses: Synapses(
    downstreams: [logger, analytics, uiUpdater],
  ),
);
```

✅ Post-condition: Each downstream cell is linked to the source cell. Pulses emitted by the source reach all downstreams.

⚠️ Failure mode: If any downstream cell's link is rejected by the source's test rule, that specific link is silently not established. Check the source's rules if you observe missing deliveries.

❌ Prohibition: Do not list the same downstream cell twice. The registry deduplicates, but the intent should be clear.

---

## 18. Procedure D: Attach a `FilterRule`

Purpose: Transform or suppress outgoing pulses before broadcast.

### Steps

1. **Identify the transformation or filtering logic.**
2. **Construct a `FilterRule` with the appropriate payload type.**

📋 Canonical template:

```dart
final redactFilter = FilterRule<UserData>((pulse, {user}) {
  return Pulse(pulse.payload.copyWith(email: '***'));
});
```

3. **Attach the filter to the synapses.**

📋 Canonical template:

```dart
final cell = Cell(
  synapses: Synapses(filter: redactFilter),
);
```

✅ Post-condition: Every outgoing pulse passes through the filter before reaching observers.

⚠️ Failure mode: If the filter throws, the framework preserves the original pulse. Ensure the filter is defensive.

❌ Prohibition: Do not mutate the pulse inside the filter. Return a new pulse if modification is needed.

---

## 19. Procedure E: Compose Filters with `+`

Purpose: Chain multiple filters into a sequential pipeline.

### Steps

1. **Identify the filters to compose.** Their payload types must match.
2. **Compose with `+`.**

📋 Canonical template:

```dart
final pipeline = redactFilter + formatFilter + auditFilter;
```

3. **Attach the composed filter to the synapses.**

```dart
final cell = Cell(
  synapses: Synapses(filter: pipeline),
);
```

✅ Post-condition: The pipeline applies filters in order. If any returns `null`, the pulse is dropped.

⚠️ Failure mode: If a filter returns a pulse with a different type than the pipeline expects, a type error occurs at runtime. Ensure all filters in the pipeline use the same payload type.

❌ Prohibition: Do not assume filters execute in an undefined order. `+` is left-associative: `a + b + c` runs `a → b → c`.

---

## 20. Procedure F: Configure a `PropagationPolicy`

Purpose: Control the timing of pulse delivery.

### Steps

1. **Identify the desired strategy:**
    - **Debounce** — deliver after a silence window.
    - **Throttle** — deliver at a bounded rate.
    - **Batch** — deliver pulses together.
2. **Construct a `PropagationPolicy` with the chosen strategy.**
3. **Attach the policy to the synapses.**

📋 Canonical template — Debounce:

```dart
final cell = Cell(
  synapses: Synapses(
    downstreams: [searchHandler],
    policy: PropagationPolicy(
      strategy: PropagationStrategy.debounced,
      debounceTime: Duration(milliseconds: 300),
    ),
  ),
);
```

📋 Canonical template — Throttle:

```dart
final cell = Cell(
  synapses: Synapses(
    downstreams: [uiUpdater],
    policy: PropagationPolicy(
      strategy: PropagationStrategy.throttled,
      throttleTime: Duration(milliseconds: 100),
    ),
  ),
);
```

✅ Post-condition: The policy governs the timing of pulse delivery. Observers receive pulses according to the policy's rules.

⚠️ Failure mode: If the policy's parameters (e.g., `debounceTime`) are not set, the policy may fall back to immediate delivery. Verify the parameters.

❌ Prohibition: Do not combine multiple timing policies. If you need both debounce and throttle, apply one at the source and one at a downstream cell.

---

## 21. Procedure G: Link and Unlink at Runtime

Purpose: Dynamically attach or detach observers.

### Steps

1. **Identify the source cell and the downstream cell.**
2. **Call `link` to attach or `unlink` to detach.**
3. **Handle the return value.**

📋 Canonical template — Link:

```dart
final linked = await source._nucleus.synapses.link(
source,
downstreamCell: observer,
);
if (!linked) {
// Link was rejected by the test rule
return;
}
```

📋 Canonical template — Unlink:

```dart
final unlinked = source._nucleus.synapses.unlink(
  source,
  downstreamCell: observer,
);
if (!unlinked) {
// Link did not exist
return;
}
```

✅ Post-condition: After `link`, the observer receives pulses. After `unlink`, it no longer does.

⚠️ Failure mode: If `link` returns `false`, the connection was not established. Check the source's test rule.

❌ Prohibition: Do not assume `link` is idempotent — check the return value for diagnostic purposes.

---

## 22. Procedure H: Attach a Custom `relay`

Purpose: Override the default broadcast logic.

### Steps

1. **Identify why the default broadcast is insufficient.**
2. **Write a `relay` function that takes a `Pulse` and performs the delivery manually.**
3. **Attach the `relay` to the synapses.**

📋 Canonical template:

```dart
final cell = Cell(
  synapses: Synapses(
    relay: (pulse) {
      // Custom delivery logic
      for (final downstream in myObservers) {
        downstream.receptor.call(pulse);
      }
    },
  ),
);
```

✅ Post-condition: The default broadcast is bypassed. The `relay` function is responsible for delivering the pulse.

⚠️ Failure mode: If the `relay` does not deliver to any observer, pulses are silently dropped. Ensure the relay implements the full delivery logic.

❌ Prohibition: Do not use `relay` unless the default broadcast is genuinely insufficient. Use `downstreams` and `filter` for most customisation.

---

## 23. Verification Checklist for AI Agents

Before returning generated synapse code, verify all of the following:

### Configuration Correctness

✅ The cell's broadcast requirement (terminal vs. non-terminal) matches the chosen `Synapses` configuration.
✅ Downstream observers are of the correct type.
✅ Filters have the correct payload type.
✅ Policies have valid parameters.

### Terminal

✅ Terminal cells use `Synapses.disabled`.
✅ Non-terminal cells do not use `Synapses.disabled`.
✅ `isTerminal` is checked if the caller depends on terminality.

### Filtering

✅ Filters return the correct pulse type.
✅ Filters handle `null` pulses correctly (returning a non-null pulse for valid inputs).
✅ Filter composition uses `+` for sequential pipelines.

### Timing

✅ Propagation policies use valid strategies and parameters.
✅ Timing does not conflict with graph atomicity requirements (e.g., inside `txApply`).

### Runtime Management

✅ `link` calls check the return value.
✅ `unlink` calls check the return value.
✅ Runtime links do not create cycles that could cause unexpected termination.

### Relay

✅ Custom `relay` functions deliver to all intended observers.
✅ Relay functions do not duplicate default broadcast behaviour.

### Correctness

✅ The generated code compiles.
✅ Any ambiguity has been resolved with the user.
✅ The chosen procedure matches the decision tree's outcome.

If any check fails, correct the code before returning it. If a check cannot be verified, ask the user for clarification.

---

## 24. References

| Document | Purpose |
|---|---|
| [`README.md`](README.md) | Package overview. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Design rationale for the substrate. |
| [`HowTo-Start.md`](HowTo-Start.md) | Getting started with `cell`. |
| [`HowTo-Pulse.md`](HowTo-Pulse.md) | Working with pulses. |
| [`HowTo-Instruction.md`](HowTo-Instruction.md) | Working with instructions. |
| [`HowTo-Context.md`](HowTo-Context.md) | Working with contexts and provenance. |
| [`HowTo-Receptor.md`](HowTo-Receptor.md) | Working with receptors. |
| [`HowTo-Transaction.md`](HowTo-Transaction.md) | The `Cell.transaction` surface. |
| [`HowTo-TransactionOnApply.md`](HowTo-TransactionOnApply.md) | The `Cell.txApply` surface. |
| [`HowTo-Advanced.md`](HowTo-Advanced.md) | Index of governance machinery. |
| [`packages/cell_organ/guide/HowTo-Relations.md`](../cell_organ/guide/HowTo-Relations.md) | Working with relations. |

---

*If a guide and the source disagree, the source is current.*