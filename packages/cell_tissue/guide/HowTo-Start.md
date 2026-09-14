# How to Start with cell_tissue

**Quick-start guide for developers** · `cell_tissue` v1.0.0-rc.3

Get up and running with **cell_tissue** in 15 minutes. Learn the five reactive collection types, add validation, observe granular change events, create zero-copy deputy views, and govern a tissue with a lifecycle policy.

---

## Table of Contents

1. [What is cell_tissue?](#what-is-cell_tissue)
2. [Installation](#installation)
3. [Core Concepts in 5 Minutes](#core-concepts-in-5-minutes)
4. [The Five Tissues (Cheat Sheet)](#the-five-tissues-cheat-sheet)
5. [Your First Reactive Collections (5 Examples)](#your-first-reactive-collections-5-examples)
6. [Validation with TestTissue](#validation-with-testtissue)
7. [Events & Observation](#events--observation)
8. [Deputies & Unmodifiable Views](#deputies--unmodifiable-views)
9. [Governance with EphemeralPolicy](#governance-with-ephemeralpolicy)
10. [Common Patterns](#common-patterns)
11. [Next Steps](#next-steps)

---

## What is cell_tissue?

**cell_tissue** is the *Application Layer (Tissue)* of the Cell Framework: reactive, validated, thread-safe Dart collections — built **on the same graph** as `package:cell`.

| You want… | cell_tissue provides |
|---|---|
| A reactive, indexable list | `TissueList<E>` |
| A unique-element set | `TissueSet<E>` |
| A reactive key-value store | `TissueMap<K, V>` |
| A bounded FIFO buffer | `TissueQueue<E>` |
| A single reactive scalar | `TissueValue<V>` |

**Key insight:** the graph, locks, validation, provenance, and lifecycle governance stay in **cell**. Tissue only decides *what shape the collection has* and *which granular events it emits* (`ElementAdded`, `ElementRemoved`, `ElementUpdated`).

```dart
final list = TissueList<int>.of([1, 2, 3]);
print(list.length); // 3 – it is a List…
print(list.isGoverned); // false – …and a Cell
```

---

## Installation

Add `cell` and `cell_tissue` to your `pubspec.yaml`:

```yaml
dependencies:
  cell: ^1.0.0-rc.2
  cell_tissue: ^1.0.0-rc.3
```

Import once in your Dart file:

```dart
import 'package:cell_tissue/cell_tissue.dart'; // re-exports package:cell
```

---

## Core Concepts in 5 Minutes

### 1. Tissue = Cell + Collection

Every tissue is a `Cell` (it lives in the reactive graph, has a `Nucleus`, a lock, and a validation gate) **and** a normal Dart collection (it implements `List`, `Set`, `Map`, or `Queue`).

```dart
final set = TissueSet<int>([1, 2, 3]);
set.add(4);          // Dart collection API
Cell.observe(source: set, effect: (p) => print('Set changed')); // Cell API
```

### 2. Every Mutation Is Validated, Then Signalled

A mutation flows through the tissue's command gateway:

```
mutate → TestTissue (action + element gates) → container update → TissuePulse → synapses → observers
```

```dart
final positive = TestTissue<int, TissueList<int>>(
  (value, {host, arguments, user}) => value > 0,
);
final nums = TissueList<int>.of([1], testRule: positive);

nums.add(2);   // ✅ passes validation
nums.add(-1);  // ❌ silently skipped
print(nums.length); // 2
```

### 3. Granular Events Carry Provenance

Every mutation returns (or emits) a `TissuePulse` subtype that says *exactly* what happened:

```dart
final list = TissueList.of(['a']);
final event = list.apply(list.add, positionalArguments: ['b']);

if (event is ElementAdded<String>) {
  print(event.payload); // b
}
```

- `ElementAdded<E>` — an element entered a collection.
- `ElementRemoved<E>` — an element left a collection.
- `ElementUpdated<V, E>` — a `TissueValue` changed; `payload` carries `before` / `after` / `value`.

### 4. Progressive Disclosure

| Tier | Use When | Example |
|---|---|---|
| **1. Direct constructors** | App code, defaults | `TissueList.of([1, 2])` |
| **2. Nucleus factories** | Reusable blueprints, governance | `TissueListNucleus(...)` + `fromNucleus` |
| **3. Deputy / unmodifiable** | Scoped, read-only views | `await list.deputy()` |
| **4. Nucleus evolve** | Custom collection types | `TissueNucleus.evolve(...)` |

---

## The Five Tissues (Cheat Sheet)

### Create

| Tissue | Empty | With Data |
|---|---|---|
| `TissueList<E>` | `TissueList<int>()` | `TissueList.of([1, 2, 3])` |
| `TissueSet<E>` | `TissueSet<int>.empty()` | `TissueSet<int>([1, 2, 3])` |
| `TissueMap<K, V>` | `TissueMap<String, int>()` | `TissueMap.from({'a': 1})` |
| `TissueQueue<E>` | `TissueQueue<int>(capacity: 5)` | `TissueQueue.of([1, 2, 3])` |
| `TissueValue<V>` | `TissueValue<int>.empty()` | `TissueValue<int>(0)` |

### Mutate

| Tissue | Typical Mutations |
|---|---|
| `TissueList<E>` | `add`, `addAll`, `remove`, `clear`, `setValueAt` |
| `TissueSet<E>` | `add`, `addAll`, `remove`, `clear` |
| `TissueMap<K, V>` | `map[key] = value`, `remove(key)`, `clear` |
| `TissueQueue<E>` | `add`, `addFirst`, `removeFirst`, `removeLast` |
| `TissueValue<V>` | `value.set(42)`, `value.value = 42` |

### Read

| Tissue | Read |
|---|---|
| `TissueList<E>` | `list[0]`, `list.length`, `for (final e in list)` |
| `TissueSet<E>` | `set.contains(x)`, `set.length` |
| `TissueMap<K, V>` | `map[key]`, `map.keys`, `map.entries` |
| `TissueQueue<E>` | `queue.first`, `queue.last`, `queue.length` |
| `TissueValue<V>` | `value.value` |

---

## Your First Reactive Collections (5 Examples)

### Example 1: Validated Task List (List + Observe)

```dart
import 'package:cell_tissue/cell_tissue.dart';

final tasks = TissueList.of(
  ['buy milk', 'write guide'],
  testRule: TestTissue<String, TissueList<String>>(
    (value, {host, arguments, user}) => value.isNotEmpty,
  ),
);

final handle = Cell.observe<TissuePulse<String>>(
  source: tasks,
  effect: (pulse) => print('Changed: ${pulse.payload}'),
);

tasks.add('publish'); // → Changed: publish
tasks.add('');        // rejected by validation, nothing printed
handle.stop();
```

**Why it works:** the `TestTissue` gate runs *before* the container mutation; invalid elements are silently skipped.

---

### Example 2: Unique Tags (Set)

```dart
final tags = TissueSet<String>(['dart', 'reactive']);

tags.add('dart');      // already present → no-op
tags.add('collection');
print(tags.length);    // 3

tags.remove('dart');
print(tags.contains('dart')); // false
```

**Why it works:** `TissueSet` enforces uniqueness with standard `==` / `hashCode`. Use `TissueSet.identity()` for identity-based uniqueness.

---

### Example 3: Key-Value Counters (Map)

```dart
final counters = TissueMap<String, int>();

counters['a'] = 1;
counters['b'] = (counters['a'] ?? 0) + 1;

print(counters['b']); // 2
print(counters.keys); // (a, b)
```

**Why it works:** `TissueMap` behaves like a Dart `Map`, but every `[]=` is validated and observable.

---

### Example 4: Sliding Window (Bounded Queue)

```dart
final window = TissueQueue<int>(capacity: 2);

window.add(1);
window.add(2);
window.add(3); // queue is full → oldest (1) is dropped

print(window.toList()); // [2, 3]
```

**Why it works:** a bounded `TissueQueue` is a circular buffer — adding past capacity evicts the oldest element.

---

### Example 5: Reactive Scalar (Value)

```dart
final counter = TissueValue<int>(0);

final event = counter.apply(counter.set, positionalArguments: [42])
    as ElementUpdated<int, TissueValue<int>>;

print(event.payload?.before); // 0
print(event.payload?.after);  // 42
print(counter.value);         // 42
```

**Why it works:** `TissueValue.set` validates, then stores; `apply` returns the `ElementUpdated` event with the before/after record.

---

## Validation with TestTissue

`TestTissue<E, C>` validates two things:

- **Actions** — which mutation functions are permitted (`action`).
- **Elements** — which values may enter the collection (`element`).

```dart
final positive = TestTissue<int, TissueList<int>>(
  (value, {host, arguments, user}) => value > 0,
);
final even = TestTissue<int, TissueList<int>>(
  (value, {host, arguments, user}) => value.isEven,
);

// Compose gates: both must pass, in order
final gate = positive + even;

final list = TissueList<int>.of([2], testRule: gate);
list.add(4);   // ✅ positive + even
list.add(3);   // ❌ odd
list.add(-2);  // ❌ negative
print(list.toList()); // [2, 4]
```

For multi-rule pipelines use `TestTissue.chain`; for specialized element or action rules, extend `TestElementRule` / `TestActionRule`.

> 💡 **Deputy rules are layered.** A deputy's `testRule` is applied *on top of* its principal's rule — you can only narrow permissions, never expand them.

---

## Events & Observation

### Collections Emit Through the Graph

`Cell.observe` (re-exported by `cell_tissue`) receives each change as a `TissuePulse`:

```dart
final tasks = TissueList.of(['a']);
final seen = <String>[];

final handle = Cell.observe<TissuePulse<String>>(
  source: tasks,
  effect: (pulse) => seen.add(pulse.payload ?? ''),
);

tasks.add('b');
tasks.add('c');
print(seen); // [b, c]

handle.stop();
```

### Apply Returns the Concrete Event

When you need the exact event type (not just the payload), use `apply`:

```dart
final added = tasks.apply(tasks.add, positionalArguments: ['x'])
    as ElementAdded<String>;
final removed = tasks.apply(tasks.remove, positionalArguments: ['x'])
    as ElementRemoved<String>;
```

### Batch Events

```dart
final batch = TissuePulse.batch<String>([added, removed]);
print(batch.toList().length); // 2
```

> ⚠️ **Gotcha:** initial population does **not** emit pulses. `TissueList.of([1, 2, 3])` is silent — observers only see mutations that happen *after* creation.

---

## Deputies & Unmodifiable Views

### Deputy — Zero-Copy, Live, Restricted

```dart
final source = TissueList<int>.of([1, 2, 3]);

final deputy = await source.deputy(); // shares the same storage

source.add(4);
print(deputy.toList()); // [1, 2, 3, 4] – live view
print(deputy == source); // true – same logical entity
```

Deputies can have their own `context`, `testRule`, `synapses`, and `ephemeralPolicy` — same data, scoped authority.

### Unmodifiable — Read-Only View

```dart
final source = TissueList<int>.of([1, 2, 3]);

final readOnly = TissueList<int>.unmodifiable(source, unmodifiableElement: false);
// readOnly.add(4); // blocked – mutations throw

source.add(4);
print(readOnly.toList()); // [1, 2, 3, 4] – live read-only view
```

`unmodifiableElement: false` gives a **live, storage-sharing** view. With `unmodifiableElement: true` (the default on `.unmodifiable`), child `Cell`s are projected read-only for **deep immutability**.

---

## Governance with EphemeralPolicy

A tissue is **governed** when it hosts an `EphemeralPolicy` (TTL / event budget) in its nucleus — or when it inherits one from an upstream `bind`.

### Hosted Policy (Local)

```dart
final cachePolicy = EphemeralPolicy<Cell>(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, required policy, arguments, user}) =>
      (events: 0),
  onInvalidate: (nucleus) => true,
);

// Via a nucleus blueprint
final nucleus = TissueListNucleus<int>(ephemeralPolicy: cachePolicy);
final governed = TissueList<int>.fromNucleus(nucleus, elements: [1]);
print(governed.isGoverned); // true

// Or via the Tissue factory
final other = Tissue<int>.governed(
  [1, 2, 3],
  context: Context.system,
  ephemeralPolicy: cachePolicy,
);
print(other.isGoverned); // true
```

### Upstream (Bind) Policy

A tissue with no policy of its own still inherits governance from the head of its bind chain — "the head owns the body". A hosted policy always overrides an upstream one.

```dart
final head = TissueList<int>.fromNucleus(nucleus);      // governed
final body = TissueList<int>.of([], bind: head);        // no policy of its own
print(body.isGoverned); // true – inherited from upstream
```

> ⚠️ **Note:** `context` alone does **not** make a tissue governed. Governance is determined solely by the presence of an `EphemeralPolicy` — local or upstream.

---

## Common Patterns

### Pattern 1: Task List with Business Rules

```dart
final tasks = TissueList.of(
  ['buy milk'],
  testRule: TestTissue<String, TissueList<String>>(
    (value, {host, arguments, user}) => value.isNotEmpty && value.length <= 80,
  ),
);

tasks.add('write guide');
tasks.add(''); // silently skipped
```

---

### Pattern 2: Unique Tag Cloud

```dart
final tags = TissueSet<String>(['dart']);

tags.add('reactive');
tags.add('dart');     // duplicate, ignored
tags.addAll(['state', 'graph']);

print(tags.toList()); // dart, reactive, state, graph
```

---

### Pattern 3: Sliding Window Telemetry

```dart
final window = TissueQueue<int>(capacity: 10);

void record(int sample) => window.add(sample);
// The queue always keeps the 10 most recent samples.
```

---

### Pattern 4: Live Read-Only Projection

```dart
final source = TissueList<int>.of([1, 2, 3]);
final view = TissueList<int>.unmodifiable(source, unmodifiableElement: false);

// Give `view` to a UI widget – it can read, but not mutate.
source.add(4);
print(view.length); // 4
```

---

### Pattern 5: Governed Cache

```dart
final cachePolicy = EphemeralPolicy<Cell>(
  duration: Duration(minutes: 5),
  onEvent: (object, {required cell, required policy, arguments, user}) =>
      (events: 0), // reset TTL on activity
  onInvalidate: (nucleus) => true, // clear resources
);

final cache = TissueMap<String, String>.fromNucleus(
  TissueMapNucleus<String, String>(ephemeralPolicy: cachePolicy),
);

cache['home'] = api.fetchHome(); // cache expires 5 minutes after last activity
```

---

## Next Steps

### 📚 Deepen Your Knowledge

| Document | What You'll Learn |
|---|---|
| [`cell_tissue` API docs](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue) | Full collection API reference |
| [`HowTo-Start.md` (cell)](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Start.md) | The Cell graph, pulses, and operators underneath |
| [`HowTo-EphemeralPolicy.md` (cell)](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-EphemeralPolicy.md) | TTL and event-limit lifecycle policies |
| [`HowTo-TestCell.md` (cell)](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-TestCell.md) | Validation gates and business rules |
| [`HowTo-Nucleus.md` (cell)](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Nucleus.md) | Blueprints and structural integrity |

---

### 🛠️ Explore Examples

Runnable demos in `example/`:

| File | Scenario |
|---|---|
| `card-auth-pipeline(tissue)-Demo.dart` | Card authentication pipeline |
| `grid-demand-response(tissue)-Demo.dart` | Grid demand-response orchestration |
| `nl-instruction-tissue-set-Demo.dart` | Natural-language → `TissueSet` commands |
| `ride-hail-dispatch(tissue)-Demo.dart` | Ride-hail dispatch |

Run any example:

```bash
cd packages/cell_tissue
dart run example/card-auth-pipeline(tissue)-Demo.dart
```

---

### 🔍 Key Rules to Remember

1. **A tissue is a Cell and a collection.** It lives in the reactive graph and behaves like a normal Dart collection.
2. **Mutations are validated first.** Invalid elements are silently skipped — they do not throw or fail the batch.
3. **Initial population is silent.** Only post-creation mutations emit `TissuePulse`s.
4. **Deputies are zero-copy.** `await source.deputy()` shares storage and compares equal to its principal.
5. **`TissueValue` returns its event from `apply`.** Use `apply(set, ...)` to obtain the `ElementUpdated` before/after record.
6. **Use `.async` for Future-based mutations** when you need to `await` propagation.
7. **Governance = `EphemeralPolicy`.** `isGoverned` is `true` only when a policy is hosted or inherited from `bind`.

---

### 🆘 Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| `add` silently does nothing | Element rejected by `TestTissue` | Check the `element` / `action` gates |
| Observer never fires on creation | Initial population is silent | Observe, *then* mutate |
| Deputy mutation throws | Deputy's `testRule` is read-only or additive | Use a wider rule or mutate the source |
| Queue drops elements | `capacity` reached (circular buffer) | Raise `capacity` or use `-1` for unbounded |
| `Tissue.governed` reports `isGoverned == false` | No `ephemeralPolicy` supplied | Pass an `EphemeralPolicy` (context alone doesn't govern) |

---

### 📞 Get Help

- **Issues:** [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
- **Repo:** [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- **Package:** [packages/cell_tissue](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue)

---

**Happy building with cell_tissue!** 🧬

If you've made it this far, you know enough to build production-ready reactive collections: create a tissue, add a `TestTissue` gate, observe `TissuePulse` events, share state with zero-copy deputies, and govern lifetimes with `EphemeralPolicy`.
