# cell_tissue — Feature Catalog

**Package:** `cell_tissue`  
**Version:** 1.0.0 (Alpha / Mitosis preview)  
**SDK:** Dart `>=3.5.0 <4.0.0`  
**License:** MIT or Apache-2.0  
**Author:** Lee Man Hoi Simon (see [`AUTHORS`](AUTHORS))  
**Location:** `packages/cell_tissue`

Categorized inventory of reactive collections in the Cell Framework.
Tissues are **cells** that hold a Dart collection. If dartdoc and the
factories disagree, **the source is current**. Design intent:
[`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Table of Contents

1. [What cell_tissue Is](#1-what-cell_tissue-is)
2. [Status and Boundaries](#2-status-and-boundaries)
3. [Progressive Disclosure](#3-progressive-disclosure)
4. [Tissue Base](#4-tissue-base)
5. [TissueList](#5-tissuelist)
6. [TissueSet](#6-tissueset)
7. [TissueMap](#7-tissuemap)
8. [TissueQueue](#8-tissuequeue)
9. [TissueValue](#9-tissuevalue)
10. [Events](#10-events)
11. [Validation](#11-validation)
12. [Receptor, Nucleus, Container](#12-receptor-nucleus-container)
13. [Deputies and Unmodifiable Views](#13-deputies-and-unmodifiable-views)
14. [Observation and Async](#14-observation-and-async)
15. [Relationship to cell](#15-relationship-to-cell)
16. [Use-Case Decision Matrix](#16-use-case-decision-matrix)
17. [Known Gaps](#17-known-gaps)
18. [Quick Reference](#18-quick-reference)

---

## 1. What cell_tissue Is

**cell** is one node and one pulse. **cell_tissue** is a node whose
state is a **collection**, with a pulse per structural change.

You still call `add`, `remove`, `[]=` — those methods run TestTissue,
commit under a lock, and emit a `TissueEvent`.

Five collection types:

| Type | Dart shape | Typical use |
|------|------------|-------------|
| `TissueList<E>` | `List<E>` | Ordered, indexable sequences |
| `TissueSet<E>` | `Set<E>` | Unique membership |
| `TissueMap<K,V>` | keyed store (`Tissue<V>`) | Associative state |
| `TissueQueue<E>` | `Queue<E>` | FIFO/LIFO, optional capacity |
| `TissueValue<V>` | `ValueCell<V>` + `Tissue<V>` | Single scalar in the tissue model |

The library re-exports `package:cell/cell.dart`.

---

## 2. Status and Boundaries

**Alpha.** `publish_to: none`. No independent audit. This package has no
`example/` tree and an empty `test/` directory.

| Claim | Reality |
|-------|---------|
| Drop-in `List` / `Set` | Implements the interfaces; mutations are gated and may skip invalid items. |
| Snapshot unmodifiable | `.unmodifiable` is a **live** deputy, not `List.unmodifiable`. |
| Thread-safe / multi-isolate | Per-tissue `Lock` on one isolate. Not shared-memory across isolates. |
| `listen` on the tissue | Dartdoc examples; observe with `Cell.observe(source: tissue, …)`. |
| `TissueList([1, 2, 3])` | Not the primary factory. Use `TissueList.of([1, 2, 3])`. |

---

## 3. Progressive Disclosure

1. `TissueList.of` / `TissueSet` / `TissueMap` / `TissueQueue` / `TissueValue`
2. `TestTissue`, `.unmodifiable`, `.deputy()`
3. Custom `TissueReceptor`, `Synapses` / `PropagationPolicy`
4. `TissueNucleus`, `Tissue.create`, `Container.*`

Defaults: `TestTissue.allowAll`, `TissueReceptor.passThrough`,
`Context.system`, `Synapses.enabled`.

---

## 4. Tissue Base

`Tissue<E>` implements `Cell` and `Iterable<E>`.

**Factories**

| Factory | Role |
|---------|------|
| `Tissue(elements, {bind, receptor, testRule, synapses})` | Generic tissue |
| `Tissue.governed(elements, {context, ephemeralPolicy, …})` | Explicit context / TTL |
| `Tissue.empty({…})` | Empty placeholder; may return flyweight `TissueNever` |
| `Tissue.fromNucleus(nucleus, {elements})` | Hydrate a blueprint |
| `Tissue.unmodifiable(bind, {context, unmodifiableElement})` | Live read-only view |
| `Tissue.create<E,I,C>(…)` | Custom storage / types |

**Instance**

| Member | Role |
|--------|------|
| `deputy({context, testRule, ephemeralPolicy, synapses})` | Capability-narrowed proxy (`FutureOr`) |
| `unmodifiable` | Read-only live view |
| `validate` | Composed `TestTissue` |
| `context` | Operational `Context` |
| `isTerminal` / `isInvalidated` / `isGoverned` | Cell flags |
| `apply` / `modifiable` | Command whitelist (used by `add` etc.) |
| `async` | `TissueModifiableAsync` — Future-based mutations |

**Non-obvious**

- Construction with initial elements emits **no** events.
- Deputies share storage; `deputy == principal`.
- Deputy rules only **narrow**.
- `addAll`: invalid elements skipped individually.

---

## 5. TissueList

Ordered, indexable. Implements `List<E>`.

| Factory | Notes |
|---------|--------|
| `TissueList({bind, context, receptor, testRule, synapses, growable})` | Empty growable list by default |
| `TissueList.of(elements, {…, growable})` | Populate from an iterable |
| `TissueList.fromNucleus(nucleus, {elements})` | Blueprint |
| `TissueList.unmodifiable(bind, {context, unmodifiableElement})` | Live view |

`growable: false` uses `Container.growableFalse`. Nucleus:
`TissueListNucleus` / `.evolve`. Async wrapper: `ModifiableListAsync`.

---

## 6. TissueSet

Unique elements. Implements `Set<E>`.

| Factory | Notes |
|---------|--------|
| `TissueSet(elements, {…, identitySet})` | Value equality by default |
| `TissueSet.empty` / `.of` / `.from` | Empty or copy |
| `TissueSet.identity({entries})` | `identical` uniqueness (`Container.identitySet`) |
| `TissueSet.fromNucleus` / `.unmodifiable` | Blueprint / view |

Use identity sets for collections of `Cell` instances when `==` would
collapse deputies incorrectly.

---

## 7. TissueMap

Key–value. Implements `Tissue<V>` (values are the iterable elements).

| Factory | Notes |
|---------|--------|
| `TissueMap({properties, entries})` | Empty or from entries |
| `TissueMap.from(Map)` / `.fromEntries` | Copy a Dart map |
| `TissueMap.identity({entries})` | Identity map |
| `TissueMap.fromNucleus` / `.unmodifiable` | Blueprint / view |

Mutations (`[]=`, `remove`, …) emit tissue events on the **value** side.
Nucleus: `TissueMapNucleus`.

---

## 8. TissueQueue

Double-ended buffer. Implements `Queue<E>`.

| Factory | Notes |
|---------|--------|
| `TissueQueue({capacity, …})` | `capacity` omitted / `-1` = unbounded |
| `TissueQueue.of(elements, {capacity, …})` | Pre-populated |
| `TissueQueue.fromNucleus` / `.unmodifiable` | Blueprint / view |

Bounded queue is a circular buffer: when full, a new add **drops the
oldest element silently**.

---

## 9. TissueValue

Single scalar that is both `Tissue<V>` and `ValueCell<V>`.

| Factory | Notes |
|---------|--------|
| `TissueValue(value, {…, finalValue})` | Optional initial value |
| `TissueValue.empty({…})` | Starts unset |
| `TissueValue.fromNucleus` / `.unmodifiable` | Blueprint / view |

`finalValue: true` → `Container.finalValue` (set once). Emits
`ValueChangedEvent` on assignment.

Prefer `Cell.state` / `ValueCell` unless you need tissue validation,
deep unmodifiable, or nested-cell linking. See
[`docs/InDepth-CollectiveValue-vs-ValueCell.md`](docs/InDepth-CollectiveValue-vs-ValueCell.md).

---

## 10. Events

`TissueEvent<E>` implements `Pulse<E>`.

| Type | When |
|------|------|
| `ElementAddedEvent<E>` | Membership add |
| `ElementRemovedEvent<E>` | Membership remove (`clear` / `removeAll` may batch in payload) |
| `ValueChangedEvent<V, E>` | `TissueValue` assignment (`ValueChangedRecord`) |
| `EvolvedTissueEvent` | Causal child of another tissue event |
| `CollectiveTissueEvent` | `TissueEvent.batch(events)` |
| `UnmodifiableTissueEvent` | Frozen event view |
| `TissueEventShell` | Handshake / scrutinize wrapper |

`ElementValueChange` / `ValueChange` describe in-element value deltas.

Observe:

```dart
Cell.observe(
  source: list,
  effect: (pulse) {
    if (pulse is ElementAddedEvent<int>) {
      print('added ${pulse.payload}');
    }
  },
);
```

Removed-event payload does **not** include list index.

---

## 11. Validation

`TestTissue<E, C>` extends `TestCell<C>` and `TestElementRule<E, C>`.

| Built-in | Role |
|----------|------|
| `TestTissue.allowAll` | Default singleton |
| `TestTissue.readOnly` | Blocks `modifiable` actions; used by unmodifiable views |
| `TestTissue.unlimitedLength` | `-1` sentinel for unbounded size |

Custom: `TestTissue((element, {host, action, user}) => …)` and `+` /
`chain` like `TestCell`. Deputies **layer** rules.

Invalid `addAll` items are skipped, not thrown (unless your rule throws).

---

## 12. Receptor, Nucleus, Container

**TissueReceptor** — `passThrough` (singleton),
`TissueReceptor((tissue, pulse, {user}) => …)`,
`TissueReceptor.from({rule, preProcess, postProcess})`.
Pass-through mirrors a bound principal’s structural deltas, then
forwards the pulse.

**TissueNucleus** — `TissueNucleus({…})`, `.evolve({principal, …})`,
`.empty()` (`TissueNucleusNever`). Typed variants:
`TissueListNucleus`, `TissueSetNucleus`, `TissueMapNucleus`,
`TissueQueueNucleus`, `TissueValueNucleus`.

**Container** strategies:

`iterableNever`, `iterable`, `set`, `identitySet`, `list`,
`growableTrue`, `growableFalse`, `queue`, `map`, `identityMap`,
`value`, `finalValue`.

`TissueContainer` / `ValueContainer` wrap the live storage.

---

## 13. Deputies and Unmodifiable Views

| API | Effect |
|-----|--------|
| `tissue.deputy({context, testRule, …})` | Proxy; no-op if args are defaults |
| `tissue.unmodifiable` | `TestTissue.readOnly` + live storage |
| `Tissue.unmodifiable(bind)` / typed `.unmodifiable` factories | Same as a view |
| `unmodifiableElement: true` | Nested cells become unmodifiable deputies |

Unmodifiable mutations throw `UnsupportedError` (read-only gate). Writes
on the principal remain visible.

---

## 14. Observation and Async

Tissues are cells: `Cell.observe(source: tissue, effect: …)` or
`Flow.observe(bind: tissue, …)` if cell_flow is in use.

`tissue.async` returns a typed async wrapper (`ModifiableListAsync`,
`ModifiableSetAsync`, `ModifiableMapAsync`, `ModifiableQueueAsync`,
`ModifiableValueAsync`) so mutations can be awaited through the lock.

Propagation timing (`debounce` / `throttle` / `batch`) is still
`Synapses` + `PropagationPolicy` from **cell**, attached at construction.

---

## 15. Relationship to cell

| Need | Package |
|------|---------|
| One counter / flag | `Cell.state` |
| List of items with add/remove UI | `TissueList` |
| Unique IDs / tags | `TissueSet` |
| Dictionary | `TissueMap` |
| Bounded buffer / work queue | `TissueQueue` |
| Scalar that must share tissue rules | `TissueValue` |
| Rx operators on a tissue | **cell_flow** (`Flow.map(tissue, …)`) |
| Multi-cell money transfer | **cell** `Cell.transaction` |

---

## 16. Use-Case Decision Matrix

| Need | Feature |
|------|---------|
| Todo list / playlist | `TissueList.of` + `Cell.observe` |
| Validated membership | `TestTissue` on add |
| UI must not mutate | `.unmodifiable` |
| Plugin may only add, not clear | Custom `TestTissue` on actions + deputy |
| Share list without copy | Deputy / unmodifiable |
| Drop oldest when full | `TissueQueue(capacity: n)` |
| Cells as set members | `TissueSet.identity` |
| Nested cells must stay read-only | `unmodifiableElement: true` |
| Replace entire list as one value | `Cell.state<List<T>>` instead of tissue |

---

## 17. Known Gaps

1. Alpha; not published; no tests or examples in-tree.
2. Dartdoc `listen` / `TissueList([...])` snippets vs actual API.
3. `addAll` silent skip of invalid elements.
4. Queue overflow drops oldest with no dedicated event documented as
   distinct from a normal remove.
5. `tissue_callable.dart` is not exported from `tissue.dart`.
6. Marketing claims in the previous README are not measurements.

---

## 18. Quick Reference

```dart
import 'package:cell_tissue/tissue.dart';

final list = TissueList.of<int>([1, 2, 3]);
final tags = TissueSet<String>(['a', 'b']);
final map = TissueMap<String, int>(entries: [MapEntry('k', 1)]);
final q = TissueQueue<int>(capacity: 8);
final n = TissueValue<int>(0);

Cell.observe(
  source: list,
  effect: (p) {
    if (p is ElementAddedEvent<int>) print(p.payload);
  },
);

list.add(4);
final view = list.unmodifiable;
```

| Type | Populate | Interfaces |
|------|----------|------------|
| `TissueList` | `.of(iterable)` | `List` |
| `TissueSet` | `(iterable)` | `Set` |
| `TissueMap` | `{entries}` / `.from` | `Tissue<V>` |
| `TissueQueue` | `.of` + `capacity` | `Queue` |
| `TissueValue` | `(value)` | `ValueCell` + `Tissue` |
