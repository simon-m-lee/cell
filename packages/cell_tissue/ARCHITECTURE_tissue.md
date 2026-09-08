# cell_tissue — Architecture

**Author:** Lee Man Hoi Simon (see [`AUTHORS`](AUTHORS))

This document explains the design intent behind **cell_tissue**: why
collections are cells, how mutations become pulses, and how deputies stay
zero-copy. For a feature catalog, see [`FEATURES.md`](FEATURES.md). Core
graph primitives live in [cell](../cell/).

---

## 1. The core idea

A Dart `List` / `Set` / `Map` / `Queue` is a bag of values. Updating it is
an opaque in-place write: observers, if any, see “the collection changed,”
not *which* element, *who* changed it, or *whether* the write was allowed.

cell_tissue treats a collection as a **Cell whose payload is a container**.
Every mutation goes through the same cycle as a scalar cell:

1. **Validate** (`TestTissue` — elements *and* actions).
2. **Transform** (`TissueReceptor`).
3. **Commit** under the tissue’s `Lock`.
4. **Broadcast** a `TissueEvent` (`ElementAddedEvent`,
   `ElementRemovedEvent`, `ValueChangedEvent`, …) through `Synapses`.

The collection still implements the familiar Dart interfaces (`List`,
`Set`, `Queue`, `Iterable`), so application code can `add` / `remove` /
`for-in` without learning a second API. Reactivity and governance are
*inside* those methods, not a parallel observer API you must remember to
call.

That is a design *intent*. Some dartdoc examples still show helpers
(`listen`, `TissueList([1, 2, 3])`) that do not match the current
factories — see [§6](#6-current-status-and-known-gaps).

---

## 2. Progressive disclosure

| Tier | What you use | When |
|------|----------------|------|
| **1. Concrete collections** | `TissueList.of`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue` | Day-to-day: a reactive list/set/map/queue/scalar. |
| **2. Validation and views** | `TestTissue`, `.unmodifiable`, `.deputy()` | Rules on membership or actions; read-only or scoped handles. |
| **3. Propagation and receptors** | `Synapses` / `PropagationPolicy`, custom `TissueReceptor` | Debounce collection churn; custom mutation processing. |
| **4. Nucleus / container** | `TissueNucleus`, `Tissue.create`, `Container.*` | Custom storage strategy, reusable blueprints, infrastructure. |

`TissueList.of([1, 2, 3])` should never require understanding
`TissueNucleus`. Reaching for `Tissue.create` with a custom `Container`
is a deliberate choice.

---

## 3. Core primitives

| Primitive | Role |
|-----------|------|
| **`Tissue<E>`** | Cell + `Iterable<E>`. Base of every collection. |
| **`TissueList` / `Set` / `Map` / `Queue` / `Value`** | Dart-shaped collections with the tissue cycle on every mutation. |
| **`TissueNucleus<E>`** | Immutable blueprint: receptor, `TestTissue`, context, synapses, `Container`. |
| **`Container`** | Strategy for physical storage (`list`, `set`, `identitySet`, `queue`, `map`, `value`, `finalValue`, …). |
| **`TissueReceptor`** | How incoming pulses (including from a bound principal) update the container. Default: `passThrough`. |
| **`TestTissue`** | Validation gate for **elements** and **actions**. Extends `TestCell`. Combine with `+`. |
| **`TissueEvent`** | `Pulse` subtype: add / remove / value-change (and evolved / collective / unmodifiable variants). |
| **`UnmodifiableTissue`** | Live read-only deputy (`TestTissue.readOnly`), not a snapshot. |

A tissue is a cell. You can `Cell.observe` it, `Cell.deputy` it (typed
`Tissue.deputy`), put it in a `Cell.transaction`, or pass it to
`cell_flow` operators. There is no second graph.

### Mutation cycle

```
list.add(x)
    │
    ▼
TestTissue  ──reject──► no write, no event
    │ accept
    ▼
TissueReceptor / apply (whitelisted method)
    │
    ▼
Container (physical List/Set/Map/Queue)  under Lock
    │
    ▼
TissueEvent  ──Synapses──► observers (and child-cell links)
```

**Initial population is silent.** `TissueSet([1, 2, 3])` does not emit
events. Only mutations *after* construction do.

**Batch validation is per-element.** `addAll` skips invalid members; it
does not fail the whole call.

---

## 4. Deputies on collections

Same contract as cell, applied to containers:

- **Zero-copy.** Deputy and principal share storage and lock.
  `deputy == principal` is true.
- **Additive rules.** A deputy’s `TestTissue` layers on the principal;
  you can only narrow.
- **Live unmodifiable.** `.unmodifiable` is not `List.unmodifiable`
  (a frozen copy). Source writes show up immediately; the view cannot
  write back.
- **Deep immutability.** With `unmodifiableElement: true` (typical in
  factories), nested `Cell` elements are themselves unmodifiable deputies
  so callers cannot mutate children as a side door.
- **Own synapses.** A deputy can have its own observer registry.

`Tissue.unmodifiable(source)` / `TissueList.unmodifiable(bind)` construct
the view without going through `deputy()` if you prefer a factory.

---

## 5. Relationship to cell

| Concern | cell | cell_tissue |
|---------|------|-------------|
| One value | `Cell.state` / `ValueCell` | `TissueValue` (ValueCell + tissue cycle, nested linking) |
| Many values | several cells + `synthesis` | one `TissueList` / `Set` / `Map` / `Queue` |
| Validation | `TestCell` | `TestTissue` (elements + actions) |
| Signal | `Pulse` | `TissueEvent` (is a `Pulse`) |
| Storage | `Box<V>` | `Container` strategy + `TissueContainer` |
| Restricted view | `Cell.deputy` / `.unmodifiable` | same, plus deep element projection |

Use **cell** when the unit of change is one atom. Use **tissue** when the
unit of change is membership or an indexed/keyed structure, and you want
granular add/remove events instead of replacing a whole list in a
`ValueCell<List<T>>`.

**TissueValue vs ValueCell** (also [`docs/InDepth-CollectiveValue-vs-ValueCell.md`](docs/InDepth-CollectiveValue-vs-ValueCell.md)):
`TissueValue` implements `ValueCell` but uses `TissueValueNucleus`,
`TestTissue`, and `TissueReceptor`. Prefer `Cell.state` / `ValueCell`
for a lightweight scalar; prefer `TissueValue` when the scalar must
participate in tissue rules, deep unmodifiable trees, or nested-cell
linking.

---

## 6. Current status and known gaps

- **Alpha.** `publish_to: none`. No independent audit. `test/` is empty
  in this package.
- **No `example/` directory.** Usage is in dartdoc; some snippets are
  stale (`tissue.listen(...)` — observe with `Cell.observe`;
  `TissueList([1, 2, 3])` — use `TissueList.of([...])`).
- **`TissueList` primary factory** does not take initial elements;
  `TissueList.of` does. `TissueSet` / `TissueQueue.of` / `TissueValue`
  do take initial data on the main factory.
- Existing README marketing (AI-native tier, 10k-item claims) is not
  a measured guarantee.
- Locks make mutations atomic on one isolate; they do not share a
  tissue across isolates.
- Invalid elements in `addAll` are skipped silently — easy to miss in
  UI unless you count before/after or log in a custom `TestTissue`.

If you rely on a guarantee here, verify it against current source.
