# The Cell Framework: Progressive Disclosure Design

## Core Principle

**Progressive Disclosure** ensures a developer's cognitive load remains proportional to the complexity of the task at hand. It prevents "Governance Fatigue" by hiding high-integrity architectural machinery behind a simplified, intuitive entry tier.

The framework is architected as a series of **"concentric circles" of complexity**:

---

## The Concentric Circles of Complexity

```
                        ┌─────────────────────────────────────────────────────────────┐
                        │                    TIER 4: EXPERT                          │
                        │  • Cell.governed()                                         │
                        │  • Nucleus.evolve()                                        │
                        │  • Custom TestCell pipelines                              │
                        │  • Transaction isolation levels                           │
                        │  • Custom propagation strategies                          │
                        │                                                             │
                        │              ┌──────────────────────────────────────┐       │
                        │              │           TIER 3: ADVANCED           │       │
                        │              │  • Cell.transaction()                │       │
                        │              │  • Cell.txApply()                    │       │
                        │              │  • Cell.hub()                        │       │
                        │              │  • Cell.switchMap()                  │       │
                        │              │  • Custom Context                    │       │
                        │              │                                      │       │
                        │              │        ┌──────────────────────┐      │       │
                        │              │        │    TIER 2: COMMON    │      │       │
                        │              │        │  • Cell.debounce()   │      │       │
                        │              │        │  • Cell.throttle()   │      │       │
                        │              │        │  • Cell.merge()      │      │       │
                        │              │        │  • Cell.distinct()   │      │       │
                        │              │        │  • Cell.synthesis()  │      │       │
                        │              │        │                      │      │       │
                        │              │        │  ┌──────────────┐    │      │       │
                        │              │        │  │ TIER 1: CORE │    │      │       │
                        │              │        │  │ Cell.state()  │    │      │       │
                        │              │        │  │ Cell.ingress()│    │      │       │
                        │              │        │  │ Cell.observe()│    │      │       │
                        │              │        │  │ Cell.derive() │    │      │       │
                        │              │        │  └──────────────┘    │      │       │
                        │              │        └──────────────────────┘      │       │
                        │              └──────────────────────────────────────┘       │
                        └─────────────────────────────────────────────────────────────┘
```

---

## Tier 1: Core (The 80% Solution)

**What you need to know:** 4 operators

| Operator | Purpose |
|----------|---------|
| `Cell.state` | Hold and update state |
| `Cell.ingress` | Get events into the system |
| `Cell.observe` | React with side effects |
| `Cell.derive` | Compute derived values |

**What you don't need to know:**
- Receptors
- TestCells
- Contexts
- Synapses
- Nuclei
- Pulses (they're created for you)

```dart
// Everything you need to build a working app
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) => Pulse(host.value + 1),
);

Cell.observe(
  source: counter.cell,
  effect: (pulse) => setState(() => count = pulse.payload),
);

counter.update(1);  // It just works
```

---

## Tier 2: Common Patterns (The Next 15%)

**What you need to know:** +5 operators

| Operator | Purpose |
|----------|---------|
| `Cell.debounce` | Handle user input gracefully |
| `Cell.throttle` | Rate-limit high-frequency events |
| `Cell.merge` | Combine multiple sources |
| `Cell.distinct` | Skip duplicate updates |
| `Cell.synthesis` | Aggregate multiple sources |

**What you don't need to know:**
- Still don't need Receptors or TestCells
- Still don't need Context or Synapses
- Still don't need to understand Pulse internals

```dart
// Common patterns, still simple
final search = Cell.ingress<String>();
final debounced = Cell.debounce(search.cell, Duration(milliseconds: 300));
// Just works — no new concepts needed
```

---

## Tier 3: Advanced (The Final 5%)

**What you need to know:** +6 operators

| Operator | Purpose |
|----------|---------|
| `Cell.asyncMap` | Background tasks with concurrency |
| `Cell.hub` | Pattern-based routing |
| `Cell.switchMap` | Dynamic source switching |
| `Cell.fromFuture/Stream` | Async bridging |
| `Cell.sanitized` | Data redaction |
| `Cell.open` | Manual control |

**What you're now ready to learn:**
- Context (security tiers, domains)
- Receptors (transformation pipelines)
- TestCells (validation gates)
- Synapses (distribution control)

```dart
// Advanced patterns, still using familiar concepts
final profiles = Cell.asyncMap<int, User>(
  userId.cell,
  (id) => api.fetchUser(id),
  latestOnly: true,
);
// You only need to know about asyncMap — not its implementation
```

---

## Tier 4: Expert (Framework Extension)

**What you need to know:** +2 operators + internals

| Operator | Purpose |
|----------|---------|
| `Cell.transaction` | Multi-cell atomic updates |
| `Cell.txApply` | Batch apply with compensation |

**What you now understand:**
- Everything from Tiers 1-3
- How Receptors, TestCells, Contexts, and Synapses work
- How to compose them for custom behavior
- How to extend the framework

```dart
// Expert patterns with full understanding
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
  timeout: Duration(seconds: 5),
));
// You now understand everything beneath it
```

---

## Developer Experience Summary

| Tier | Operators | Concepts | Cognitive Load | Who For |
|------|-----------|----------|----------------|---------|
| 1: Core | 4 | 4 | Low | Everyone |
| 2: Common | 5 | 4 | Low-Medium | Most developers |
| 3: Advanced | 6 | 4-6 | Medium | Experienced developers |
| 4: Expert | 2 | 8+ | High | Framework extenders |

---

## The Minimal Path

**To build a working app, you only need Tier 1:**

```dart
import 'package:cell/cell.dart';

void main() {
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) => Pulse(host.value + 1),
  );

  Cell.observe(
    source: counter.cell,
    effect: (pulse) => print('Count: ${pulse.payload}'),
  );

  counter.update(1);  // Prints: Count: 1
}
```

**That's it. Everything else is optional.**

---

## Progressive Disclosure in Practice

### Day 1: "I just need a counter"
→ Use `Cell.state` + `Cell.observe`

### Week 1: "I need to handle user input"
→ Add `Cell.ingress` + `Cell.debounce`

### Month 1: "I need to fetch data from APIs"
→ Add `Cell.asyncMap`

### Year 1: "I need to understand what's happening in production"
→ Explore `Pulse.trace` and `Context`

### Year 2: "I need to extend the framework"
→ Explore `Receptor`, `TestCell`, `Nucleus`

---

## The Promise

**You will never be forced to learn more than you need.**

The framework meets you where you are:
- Use only Tier 1 → Build working apps
- Learn Tier 2 → Handle common patterns
- Master Tier 3 → Build complex systems
- Expert Tier 4 → Extend the framework

**Start simple. Grow as you need. The framework grows with you.**
