# HowTo-Tissue-Advanced.md

**Advanced Reactive Collections in `cell_tissue`**
*A guide for human developers and AI prompt agents*

---

## Abstract

This guide covers the advanced surfaces of `cell_tissue` — the parts that a developer or AI agent reaches for after the basics are understood. It explains custom container strategies, the propagation and lifecycle policies that govern tissue distribution, the transformation pipeline (`TissueReceptor`), the internal storage model, and the fine-grained governance mechanisms that make tissues composable and secure at scale.

Like its companion guide [`HowTo-Tissue.md`](HowTo-Tissue.md), this document is written in two registers simultaneously: prose for human developers and numbered, executable specifications for AI prompt agents. Every section uses the same conventions:

- 📋 **Canonical templates** — copy and adapt.
- ✅ **Post-conditions** — verify before proceeding.
- ⚠️ **Failure modes** — stop and report if observed.
- 🔁 **Loop invariants** — check on each iteration.
- ❌ **Prohibitions** — never do these.

The guide assumes you have already read [`HowTo-Tissue.md`](HowTo-Tissue.md) or are otherwise familiar with the basics: creating a `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` / `TissueValue`, attaching a `TestTissue` rule, and using `.deputy()` and `.unmodifiable`.

---

## Table of Contents

1. [The Tissue Architecture Recap](#1-the-tissue-architecture-recap)
2. [Custom Container Strategies](#2-custom-container-strategies)
3. [Understanding `TissueNucleus`](#3-understanding-tissuenucleus)
4. [Deputies and Nucleus Evolution](#4-deputies-and-nucleus-evolution)
5. [The `TissueReceptor` Transformation Pipeline](#5-the-tissuereceptor-transformation-pipeline)
6. [The `TissuePulse` and Event Classification](#6-the-tissuepulse-and-event-classification)
7. [Propagation Policies](#7-propagation-policies)
8. [Lifecycle Governance with `EphemeralPolicy`](#8-lifecycle-governance-with-ephemeralpolicy)
9. [Async Tissue Handling](#9-async-tissue-handling)
10. [Advanced `TestTissue` Composition](#10-advanced-testtissue-composition)
11. [Integrating with `Cell.txApply`](#11-integrating-with-celltxapply)
12. [Custom Tissue Types](#12-custom-tissue-types)
13. [Performance Considerations](#13-performance-considerations)
14. [Debugging and Introspection](#14-debugging-and-introspection)
15. [References](#15-references)

---

## 1. The Tissue Architecture Recap

A `Tissue` is composed of four swappable parts:

| Part | Role | Where to Configure |
|---|---|---|
| **`TissueContainer`** | Physical storage — the underlying `List`, `Set`, `Map`, `Queue`, or `ValueContainer` | via `Container` strategy in the nucleus |
| **`TissueNucleus`** | Immutable blueprint — rules, context, receptor, synapses | via `TissueNucleus.create(...)` or a factory |
| **`TissueReceptor`** | Transformation pipeline — how mutations are processed | via `receptor:` parameter |
| **`Synapses`** | Distribution — how mutations propagate to observers | via `synapses:` parameter |

**For AI agents:**

1. Every Tissue created by any factory (`TissueList()`, `TissueSet()`, etc.) carries a nucleus that references all four parts.
2. The parts are swappable at construction but not after activation — the nucleus is immutable once the tissue is live.
3. To produce a variant with different parts, use `.deputy(...)` (for governance) or `.evolve(...)` on the nucleus (for advanced structural changes).

✅ **Post-condition:** You can enumerate the four parts of any live Tissue by inspecting `tissue._nucleus.container`, `._nucleus.receptor`, and `._nucleus.synapses`.

⚠️ **Failure mode:** Attempting to reassign a nucleus field after activation throws a runtime error. The nucleus is designed to be frozen once bound to a live cell.

---

## 2. Custom Container Strategies

### 2.1 What a Container Strategy Is

A **container strategy** tells the framework how to allocate, add to, and remove from the physical storage of a tissue. The framework provides several predefined strategies via the `Container` interface.

### 2.2 Predefined Strategies

| Constant | Storage Type | Notes |
|---|---|---|
| `Container.list` | `List<E>` | Growable list |
| `Container.growableTrue` | `List<E>` | Explicitly growable |
| `Container.growableFalse` | `List<E>` | Fixed-length |
| `Container.set` | `Set<E>` | Value-based uniqueness |
| `Container.identitySet` | `Set<E>` | Referential uniqueness |
| `Container.map` | `Map<K, V>` | Standard map |
| `Container.identityMap` | `Map<K, V>` | Identity-keyed map |
| `Container.queue` | `Queue<E>` | FIFO / double-ended |
| `Container.value` | `ValueContainer<V>` | Single mutable value |
| `Container.finalValue` | `V` | Write-once value |
| `Container.iterable` | `Iterable<E>` | Read-only |
| `Container.iterableNever` | `Iterable<Never>` | Permanently empty |

### 2.3 Using a Predefined Strategy

📋 **Canonical template:**

```dart
import 'package:cell_tissue/cell_tissue.dart';

final fixedLength = TissueList.create<int, TissueList<int>>(
  container: Container.growableFalse,
  elements: [1, 2, 3],
);

// Attempting to grow throws or is rejected
// fixedLength.add(4); // rejected
```

**For AI agents:**

1. Pass `container: Container.xxx` to any Tissue factory that accepts it (`create`, `governed`, `fromNucleus`).
2. The container strategy is **structural** — it is fixed at construction and inherited by all deputies.
3. The strategy determines which mutation methods are accepted (e.g., `growableFalse` rejects `add`).

### 2.4 Building a Custom Strategy

📋 **Canonical template:**

```dart
final cappedList = Container.create<List<int>, List<int>>(
  create: (init) => List<int>.from(init ?? [], growable: true),
  add: (tissue, list, element) {
    if (list.length >= 10) {
      // Silently drop when full
      return false;
    }
    list.add(element);
    return true;
  },
  remove: (tissue, list, element) => list.remove(element),
);

final capped = TissueList.create<int, TissueList<int>>(
  container: cappedList,
);

for (var i = 0; i < 20; i++) {
  capped.add(i); // Only the first 10 succeed
}

print(capped.length); // 10
```

**For AI agents:**

1. `Container.create<E, I>(...)` requires three functions: `create`, `add`, `remove`.
2. The `create` function is called once per tissue; it should return a fresh store.
3. The `add` function returns `true` if the element was successfully added, `false` otherwise.
4. The `remove` function returns `true` if the element was removed, `false` otherwise.
5. The `tissue` parameter in `add`/`remove` gives the function access to the host — useful for capacity checks and per-tissue state.

✅ **Post-condition:** After creating a tissue with a custom strategy, all mutations pass through the strategy's `add`/`remove` functions.

⚠️ **Failure mode:** If the `add` function throws, the framework treats the mutation as rejected (returns `false`).

❌ **Prohibition:** Do not mutate the tissue's state inside the `add`/`remove` functions. The strategy only governs the store; all tissue-level side effects are handled by the receptor pipeline.

---

## 3. Understanding `TissueNucleus`

### 3.1 What the Nucleus Contains

A `TissueNucleus<E>` (or its concrete implementation `_TissueNucleus<E, I, C>`) holds:

- **`container` / `containerType`** — the storage strategy.
- **`receptor`** — the transformation pipeline.
- **`testRule`** — the integrity gate.
- **`context`** — the operational authority.
- **`synapses`** — the distribution network.
- **`ephemeralPolicy`** — the lifecycle policy.
- **`bind`** — an optional upstream cell to observe.
- **`principal`** — the ancestral nucleus (for deputies).
- **`user`** — arbitrary developer metadata.

### 3.2 Creating a Nucleus Explicitly

📋 **Canonical template:**

```dart
final nucleus = TissueNucleus.create<int, List<int>, TissueList<int>>(
  container: Container.growableTrue,
  testRule: TestTissue.allowAll,
  context: Context.system,
);

final list = TissueList.fromNucleus(nucleus, elements: [1, 2, 3]);
```

**For AI agents:**

1. `TissueNucleus.create<E, I, C>(...)` is the type-safe factory for creating a nucleus.
2. `E` is the element type; `I` is the storage type (`List<E>`, `Set<E>`, etc.); `C` is the concrete tissue interface.
3. If a `principal` is provided, the new nucleus inherits from it.
4. If `forceLock: true`, the nucleus shares its principal's lock; otherwise it allocates its own.

✅ **Post-condition:** The created nucleus is frozen and ready to be activated by a tissue.

### 3.3 Nucleus Resolution Order

When a nucleus's property is accessed, the framework resolves it in this order:

1. **Local record** — if the property was set on this nucleus.
2. **Principal chain** — if the property is inherited from an ancestor via `principal`.
3. **Default** — if the property is unset.

**For AI agents:**

1. Always assume the principal chain is consulted for properties not locally set.
2. To override a property locally without affecting the principal, provide it at construction time.
3. To remove a local override, create a new nucleus.

### 3.4 `TissueNucleus.empty()`

📋 **Canonical template:**

```dart
const empty = TissueNucleus.empty<int>();
```

**For AI agents:**

1. `TissueNucleus.empty()` returns a `const` sentinel (`TissueNucleusNever`) that rejects all mutations and holds no elements.
2. Use it as a non-null fallback in generic code.
3. The sentinel is a singleton — all uses share the same memory.

---

## 4. Deputies and Nucleus Evolution

### 4.1 How Deputies Work

A deputy is a restricted view created from a principal. It shares the principal's storage and lock, but applies its own governance.

📋 **Canonical template:**

```dart
final source = TissueList<int>([1, 2, 3]);

final deputy = await source.deputy(
  context: DeputyContext.system,
  testRule: TestTissue.readOnly,
);

// deputy shares storage with source
source.add(4);
print(deputy.length); // 4
```

**For AI agents:**

1. `.deputy()` internally calls `TissueNucleus.evolve(principal: source._nucleus, ...)`.
2. The evolved nucleus shares the principal's container and lock.
3. The deputy's test rule is composed additively with the principal's rule.

### 4.2 Evolve at the Nucleus Level

📋 **Canonical template:**

```dart
final source = TissueList<int>([1, 2, 3]);
final sourceNucleus = source._nucleus;

final evolvedNucleus = TissueNucleus.evolve<int, List<int>, TissueList<int>>(
  principal: sourceNucleus,
  testRule: TestTissue.readOnly,
  context: Context.system,
);

final deputy = TissueList.fromNucleus(evolvedNucleus);
```

**For AI agents:**

1. `TissueNucleus.evolve<E, I, C>(principal: ..., ...)` is the low-level API behind `.deputy()`.
2. Use it when you need finer control than `.deputy()` provides.
3. If `override` is provided, its record supersedes all other parameters.

### 4.3 Cloning the Nucleus

📋 **Canonical template:**

```dart
final source = TissueList<int>([1, 2, 3]);
final clonedNucleus = source._nucleus.clone;

final independentList = TissueList.fromNucleus(clonedNucleus);
// independentList has its own lock and synapses
```

**For AI agents:**

1. `.clone` produces a fresh nucleus with a new lock and synapses.
2. The clone is **not** a deputy — it does not share the source's storage.
3. Use `.clone` when you want an independent tissue with the same configuration.

⚠️ **Failure mode:** If the original nucleus is a deputy (has a principal), the clone preserves the principal chain. `deputy == original` still returns `true` in this case.

---

## 5. The `TissueReceptor` Transformation Pipeline

### 5.1 What a Receptor Does

A `TissueReceptor` is the transformation engine of a tissue. It intercepts every mutation pulse, optionally transforms it, and routes it through the tissue's integrity gate.

### 5.2 The Default: `passThrough`

📋 **Canonical template:**

```dart
final list = TissueList<int>(
  receptor: TissueReceptor.passThrough,
);
```

**For AI agents:**

1. `TissueReceptor.passThrough` is the default — a no-op singleton.
2. It forwards every pulse unchanged.

### 5.3 A Custom Receptor

📋 **Canonical template:**

```dart
final loggingReceptor = TissueReceptor<int, TissueList<int>>(
  (tissue, pulse, {user}) {
    print('Mutation: ${pulse.type}, payload: ${pulse.payload}');
    return pulse; // forward unchanged
  },
);

final list = TissueList<int>(
  receptor: loggingReceptor,
);
```

**For AI agents:**

1. `TissueReceptor<E, C>(function)` constructs a receptor from a transformation function.
2. The function receives the tissue, the pulse, and optional user metadata.
3. Return the pulse to continue propagation; return `null` to terminate.
4. The receptor is a stateless template until activated by `Cell.fromNucleus`.

### 5.4 A Pipeline Receptor

For multi-stage processing, use `.pipeline`:

📋 **Canonical template:**

```dart
final pipelineReceptor = TissueReceptor.pipeline(
  preProcess: Instruction((pulse, {cell, user}) {
    print('Pre: ${pulse.type}');
    return pulse;
  }),
  instruction: Instruction((pulse, {cell, user}) {
    // Core transformation
    return pulse;
  }),
  postProcess: Instruction((pulse, {cell, user}) {
    print('Post: ${pulse.type}');
    return pulse;
  }),
);
```

**For AI agents:**

1. `TissueReceptor.pipeline(...)` accepts `preProcess`, `instruction`, and `postProcess` stages.
2. Stages run in order: `preProcess` → `instruction` → `postProcess`.
3. If any stage returns `null`, the pipeline short-circuits.
4. Each stage is an `Instruction` from `cell`.

### 5.5 The `TissueReceptorBase` Sync Stack

The concrete `TissueReceptorBase` adds an implicit **synchronisation step**: when a pulse arrives from a bound principal, structural deltas (additions, removals, updates) are applied to the local tissue's container **before** the pipeline runs.

**For AI agents:**

1. This sync step is what makes deputies mirror their principals automatically.
2. It only runs for pulses originating from the bind source.
3. If the sync is partial (some deltas rejected), the resulting pulse reflects only the committed changes.

---

## 6. The `TissuePulse` and Event Classification

### 6.1 The `TissueEvent` Vocabulary

Every `TissuePulse` carries a `type` field classified as a `TissueEvent`:

| Constant | Meaning |
|---|---|
| `Tissue.elementAdded` | An element was added to the collection |
| `Tissue.elementRemoved` | An element was removed |
| `Tissue.elementUpdated` | A single value changed (e.g., `TissueValue`) |
| `Tissue.entryUpdated` | A map entry changed |

**For AI agents:**

1. Match on `pulse.type` in observers.
2. For batch operations, the type may be a composite (a `TissueEvent` combined via `+`).
3. Iterating over a composite `TissueEvent` yields the individual event types it represents.

### 6.2 Composite Events

📋 **Canonical template:**

```dart
final composite = Tissue.elementAdded + Tissue.elementRemoved;

for (final event in composite) {
  if (event == Tissue.elementAdded) {
    print('Handles additions');
  }
  if (event == Tissue.elementRemoved) {
    print('Handles removals');
  }
}
```

**For AI agents:**

1. `TissueEvent` is a bitmask. `+` performs a bitwise OR.
2. Iterating a composite yields the individual event types it contains.
3. `CompositeTissueEvent` is the concrete class for combined events.

### 6.3 Event Records

Some events carry a `record` payload:

- `Tissue.elementUpdated` → `ElementUpdatedRecord<V, E>({value, before, after})`
- `Tissue.entryUpdated` → `EntryUpdatedRecord<K, V>({key, before, after})`

**For AI agents:**

1. Destructure the record in the observer effect: `final (:value, :before, :after) = pulse.payload!;`
2. All records are immutable.
3. Nested `Cell` values in a record are projected as unmodifiable when the event was emitted by an unmodifiable view.

---

## 7. Propagation Policies

### 7.1 What a Propagation Policy Is

A `PropagationPolicy` governs how mutations propagate to observers — it is attached to the tissue's `Synapses`. Common policies include debouncing, throttling, and batching.

### 7.2 Configuring a Policy

📋 **Canonical template:**

```dart
final debounced = TissueList<int>(
  synapses: Synapses(
    policy: PropagationPolicy(
      strategy: PropagationStrategy.debounced,
      debounceTime: Duration(milliseconds: 300),
    ),
  ),
);
```

**For AI agents:**

1. Policies are passed to the `synapses:` parameter of a Tissue factory.
2. The available strategies depend on the version of `cell` you are using — check `PropagationStrategy` for the current list.
3. Policies are **structural** — they are inherited by deputies unless overridden.

### 7.3 Batching Multiple Mutations

For batch operations, the framework emits a single collective pulse:

```dart
final list = TissueList<int>();

Cell.observe(
  source: list,
  effect: (pulse) {
    if (pulse is CollectiveTissuePulse) {
      print('Batch of ${pulse.payload.length} events');
    }
  },
);

list.addAll([1, 2, 3]); // one collective pulse
```

**For AI agents:**

1. `addAll` and similar bulk operations emit a `CollectiveTissuePulse`, not one pulse per element.
2. Each sub-pulse retains its own identity, trace, and parent chain.
3. Iterate `pulse.payload` to access individual events.

---

## 8. Lifecycle Governance with `EphemeralPolicy`

### 8.1 What an Ephemeral Policy Does

An `EphemeralPolicy` automatically invalidates a tissue after a TTL or an event-count threshold.

📋 **Canonical template:**

```dart
final policy = EphemeralPolicy(
  duration: Duration(minutes: 5),
  onInvalidate: (nucleus) {
    print('Tissue expired');
    return true;
  },
);

final list = Tissue.governed<int>(
  elements: [1, 2, 3],
  ephemeralPolicy: policy,
);
```

**For AI agents:**

1. Pass `ephemeralPolicy:` to any factory that accepts it (`governed`, `create`, `fromNucleus`).
2. The policy monitors the tissue's activity. When the terminal condition is met, the tissue is neutralised.
3. After neutralisation, `tissue.isInvalidated` returns `true`.
4. The `onInvalidate` callback is invoked once at invalidation.

✅ **Post-condition:** After the TTL elapses, `tissue.isInvalidated` is `true` and all observers are notified.

⚠️ **Failure mode:** If `onInvalidate` returns `false`, the policy does not invalidate; instead, it resets the timer or leaves the tissue alive (behaviour depends on policy type).

### 8.2 Cascading Invalidation

When a principal is invalidated, all its deputies are invalidated too.

**For AI agents:**

1. If a tissue is a deputy of an invalidated principal, `isInvalidated` returns `true`.
2. This prevents stale projections from continuing to broadcast.
3. The cascade is automatic — you do not need to invalidate deputies manually.

---

## 9. Async Tissue Handling

### 9.1 The `.async` Facade

Every tissue provides an `.async` getter that returns an async facade.

📋 **Canonical template:**

```dart
final list = TissueList<int>();

await list.async.add(1);
await list.async.addAll([2, 3]);
await list.async.remove(1);
```

**For AI agents:**

1. `.async` returns a `ModifiableListAsync<E>` (or the corresponding facade).
2. Every method returns a `Future`.
3. Mutations are serialised through the tissue's lock.
4. The `Future` resolves after the mutation has been committed and propagated.

### 9.2 Awaiting Full Propagation

For strict sequencing, use `serializedCompletion`:

```dart
await list.async.add(1);
// The Future resolves after the entire downstream graph has stabilised
```

**For AI agents:**

1. The exact behaviour of `serializedCompletion` depends on the async facade — check the specific class's docs.
2. Default semantics usually resolve after the immediate mutation and its propagation wave.
3. For strict sequencing across the graph, use `Cell.txApply` with `wait: true`.

---

## 10. Advanced `TestTissue` Composition

### 10.1 The `TestElementRule`

For finer-grained validation, use `TestElementRule`:

📋 **Canonical template:**

```dart
final elementRule = TestElementRule<int, TissueList<int>>(
  (element, {host, action, user}) {
    if (action == TissueList.add) {
      return element! > 0; // reject non-positive additions
    }
    return true;
  },
);

final list = TissueList<int>(testRule: elementRule);
```

**For AI agents:**

1. `TestElementRule` is a `TestRule` that validates individual elements.
2. It receives the element, the host tissue, the action being attempted, and optional user metadata.
3. Use it for element-specific rules that differ per operation.

### 10.2 The `TestActionRule`

📋 **Canonical template:**

```dart
final actionRule = TestActionRule<TissueList<int>>(
  (action, {host, arguments, user}) {
    // Reject clear() operations on non-empty lists
    if (action == TissueList.clear && host!.isNotEmpty) {
      return false;
    }
    return true;
  },
);
```

**For AI agents:**

1. `TestActionRule` validates the action itself, not the element.
2. It receives the action (a `Function`), the host tissue, the arguments, and optional user metadata.
3. Use it to block operations based on the tissue's state.

### 10.3 The `TestLinkRule`

📋 **Canonical template:**

```dart
final linkRule = TestLinkRule<TissueList<int>>(
  (link, {host, user}) {
    // Only allow linking to cells in the same context
    return link.context.taxonomy == host!.context.taxonomy;
  },
);
```

**For AI agents:**

1. `TestLinkRule` validates attempts to link downstream observers.
2. It receives the link (a `Cell`), the host tissue, and optional user metadata.
3. Use it to enforce topological constraints.

### 10.4 Composing Rules

All test rules compose with `+`:

```dart
final combined = elementRule + actionRule + linkRule;
final list = TissueList<int>(testRule: combined);
```

**For AI agents:**

1. Use `+` to compose rules; the result is a new `TestTissue`.
2. The combined rule accepts a mutation only if **all** constituent rules accept it.
3. Composition is left-associative and additive.

---

## 11. Integrating with `Cell.txApply`

This section is a condensed reference for `Cell.txApply` with multiple tissue cells. See [`HowTo-Tissue.md`](HowTo-Tissue.md) Section 10 for the full treatment.

### 11.1 The Canonical Pattern

📋 **Canonical template:**

```dart
Future<void> atomicUpdate(
  TissueValue<int> a,
  TissueValue<int> b,
) async {
  final tx = Cell.txApply();

  try {
    final beforeA = a.value ?? 0;
    final beforeB = b.value ?? 0;

    tx.apply(
      a,
      () => a.value = beforeA + 1,
      compensate: () => a.value = beforeA,
    );

    tx.apply(
      b,
      () => b.value = beforeB + 1,
      compensate: () => b.value = beforeB,
    );

    await tx.commit();
  } catch (e) {
    await tx.rollback();
    rethrow;
  }
}
```

**For AI agents:**

1. Create a `Cell.txApply()` scope.
2. Read state inside the transaction.
3. Stage each mutation with `tx.apply(cell, mutation, compensate: reversal)`.
4. Wrap the commit in `try / catch`.
5. On error, call `await tx.rollback()` and rethrow.

### 11.2 Multi-Tissue Type Mixing

```dart
tx.apply(list, () => list.add(item), compensate: () => list.remove(item));
tx.apply(map, () => map[key] = value, compensate: () => map.remove(key));
tx.apply(valueCell, () => valueCell.value = newVal, compensate: () => valueCell.value = oldVal);
```

**For AI agents:**

1. Any tissue type can be staged inside a single `txApply` scope.
2. Order matters: compensations run in reverse order of staging.
3. Every `tx.apply` must supply a `compensate`.

### 11.3 Savepoints

```dart
final sp = tx.savepoint();
tx.apply(cellC, ..., compensate: ...);
await tx.rollback(savepoint: sp);
await tx.commit();
```

**For AI agents:**

1. `savepoint()` captures the current staging state.
2. `rollback(savepoint: sp)` runs compensations only for mutations staged after `sp`.
3. `commit()` applies all remaining staged mutations.

### 11.4 Success Criteria

✅ Read inside the transaction.
✅ Every `tx.apply` has a compensation.
✅ Commit is wrapped in `try / catch`.
✅ Rollback is called on any exception.
✅ Compensations are true inverses of their mutations.

⚠️ If any criterion is missing, the transaction pattern is incorrect.

---

## 12. Custom Tissue Types

### 12.1 Extending `TissueBase`

For a custom tissue type, extend `TissueBase` and mix in the appropriate collection mixin:

📋 **Canonical template:**

```dart
abstract class MyTissueBase<E, C extends MyTissue<E>>
    extends TissueBase<E, List<E>, C>
    with TissueListMixin<E, C>
    implements MyTissue<E> {
  @override
  MyTissueNucleusBase<E, C> get _nucleus =>
      super._nucleus as MyTissueNucleusBase<E, C>;
}
```

**For AI agents:**

1. `TissueBase` provides the core reactive lifecycle.
2. Mixins provide the collection API: `TissueListMixin`, `TissueSetMixin`, `TissueMapMixin`, `TissueQueueMixin`, `TissueValueMixin`.
3. The `_nucleus` getter must be overridden to return the concrete nucleus type.

### 12.2 Extending the Nucleus

```dart
abstract class MyTissueNucleusBase<E, C extends MyTissue<E>>
    extends TissueNucleusBase<E, List<E>, C>
    implements MyTissueNucleus<E> {
  @override
  Container get containerType {
    return get<Container>(() => record.local.inheritable.container,
        fallback: () => principal?.containerType,
        orElse: Container.list);
  }
}
```

**For AI agents:**

1. Extend `TissueNucleusBase` for the nucleus of a custom tissue.
2. Override `containerType` to select the storage strategy.
3. Provide a `clone` getter that returns a fresh nucleus.

### 12.3 Registering the Type

Custom tissue types must be registered with the framework's `Reference` registry if they participate in serialisation.

**For AI agents:**

1. Registration is performed in the code-generation step (`cell_ontogeny`).
2. If you are building custom types manually, refer to `Reference.register<T>()` in the `cell` package.

---

## 13. Performance Considerations

### 13.1 Memory Efficiency

- **Flyweight nuclei.** Multiple tissues can share the same nucleus without duplicating memory.
- **Zero-copy deputies.** Deputies share the principal's storage and lock; they do not copy data.
- **Lazy container allocation.** Containers are allocated lazily on first mutation or first read.

### 13.2 Lock Contention

- Every tissue has its own lock unless `forceLock: false`.
- Deputies inherit the principal's lock — mutations on either side are serialised.
- Long-running async rules hold the lock during suspension; keep them short.

**For AI agents:**

1. Prefer synchronous rules over async rules unless network or I/O is required.
2. Use `Cell.txApply` for coordination; it acquires locks only during commit, not across the whole transaction.

### 13.3 Observer Costs

- Each observer holds a reference to the tissue; the tissue holds a reference to each observer.
- Unstopped observers prevent garbage collection.
- `observer.stop()` releases the reference.

**For AI agents:**

1. Always call `observer.stop()` when done.
2. For long-lived observers, prefer a single well-scoped observer over many small ones.

### 13.4 Batching

- Bulk operations (`addAll`, `removeAll`) emit a single collective pulse.
- For high-frequency mutations, use `.deputy()` with a propagation policy (debounce, throttle, batch).

**For AI agents:**

1. Prefer `addAll` over many `add` calls.
2. For high-frequency writes, attach a debounce policy to the tissue's synapses.

---

## 14. Debugging and Introspection

### 14.1 Inspecting a Tissue

```dart
print(list.toString());            // the underlying collection's toString
print(list.length);
print(list._nucleus.testRule);     // the active integrity gate
print(list._nucleus.containerType); // the storage strategy
print(list._nucleus.context);      // the operational environment
```

**For AI agents:**

1. Use `_nucleus` for introspection — it gives you access to the tissue's blueprint.
2. Prefer public getters (`length`, iteration, `contains`) for normal use.

### 14.2 Tracing Mutations

```dart
Cell.observe(
  source: list,
  effect: (pulse) {
    print('Type: ${pulse.type}');
    print('Payload: ${pulse.payload}');
    print('Source: ${pulse.source}');
    print('Trace: ${pulse.trace}');
    print('Root: ${pulse.root}');
  },
);
```

**For AI agents:**

1. The `trace` field is a list of steps the pulse has accumulated.
2. The `root` field points to the original pulse in the lineage.
3. Use these to debug complex propagation chains.

### 14.3 Verifying Atomicity

To verify that a `txApply` was atomic, observe all participating cells before and after the commit:

```dart
final beforeA = a.value;
final beforeB = b.value;

await atomicUpdate(a, b);

// Either both changed or neither did
final afterA = a.value;
final afterB = b.value;
assert((afterA != beforeA) == (afterB != beforeB));
```

**For AI agents:**

1. Atomicity is a post-condition; verify it after every transaction.
2. If the assertion fails, the transaction did not preserve atomicity — investigate.

---

## 15. References

| Document | Purpose |
|---|---|
| [`README.md`](README.md) | Package overview |
| [`ARCHITECTURE-Tissue.md`](ARCHITECTURE-Tissue.md) | Design rationale |
| [`FEATURES-Tissue.md`](FEATURES-Tissue.md) | Feature catalog |
| [`HowTo-Tissue.md`](HowTo-Tissue.md) | Getting-started guide |
| [`HowTo-Transaction.md`](../cell/guide/HowTo-Transaction.md) | Full transaction reference in `cell` |
| [`HowTo-TransactionOnApply.md`](../cell/guide/HowTo-TransactionOnApply.md) | Full `txApply` reference in `cell` |
| [`HowTo-Receptor.md`](../cell/guide/HowTo-Receptor.md) | Receptor pipeline in `cell` |
| [`HowTo-Instruction.md`](../cell/guide/HowTo-Instruction.md) | Instruction stages in `cell` |
| [`HowTo-Synapses.md`](../cell/guide/HowTo-Synapses.md) | Synapses and propagation in `cell` |
| [`packages/cell/guide/HowTo-Start.md`](../cell/guide/HowTo-Start.md) | Starting with the `cell` layer |
| [`packages/cell_flow/guide/HowTo-Start.md`](../cell_flow/guide/HowTo-Start.md) | Starting with the `cell_flow` layer |
| [`packages/cell_organ/guide/HowTo-Start.md`](../cell_organ/guide/HowTo-Start.md) | Starting with the `cell_organ` layer |

---

*If a guide and the source disagree, the source is current.*