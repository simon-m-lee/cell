# cell_tissue — Architecture

**Author:** Lee Man Hoi Simon (see [`AUTHORS`](AUTHORS))

This document explains the design intent behind **cell_tissue**: why
collections are cells, how mutations become pulses, how deputies stay
zero-copy, and how Flow-driven decisions wire into governed books. For a
feature catalog, see [`FEATURES-Tissue.md`](FEATURES.md). Core graph
primitives live in [cell](../cell/); transformations live in
[cell_flow](../cell_flow/).

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
4. **Broadcast** a `TissuePulse` (`ElementAdded`,
   `ElementRemoved`, `ElementUpdated`, …) through `Synapses`.

The collection still implements the familiar Dart interfaces (`List`,
`Set`, `Queue`, `Iterable`), so application code can `add` / `remove` /
`for-in` without learning a second API. Reactivity and governance are
*inside* those methods, not a parallel observer API you must remember to
call.

That is the design *intent*. Some dartdoc examples still show helpers
(`listen`, `TissueList([1, 2, 3])`) that do not match the current
factories — see [§9](#9-current-status-and-known-gaps).

---

## 2. Progressive disclosure

| Tier | What you use | When |
|------|----------------|------|
| **1. Concrete collections** | `TissueList.of`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue` | Day-to-day: a reactive list/set/map/queue/scalar. |
| **2. Validation and views** | `TestTissue`, `.unmodifiable`, `.deputy()` | Rules on membership or actions; read-only or scoped handles. |
| **3. Propagation and receptors** | `Synapses` / `PropagationPolicy`, custom `TissueReceptor` | Debounce collection churn; custom mutation processing. |
| **4. Nucleus / container** | `TissueNucleus`, `Tissue.create`, `Container.*` | Custom storage strategy, reusable blueprints, infrastructure. |
| **5. The Flow + Tissue seam** | `Cell.observe` on a gate cell; `modifiable` gate | Decision subsystem wired into a governed book. |

`TissueList.of([1, 2, 3])` should never require understanding
`TissueNucleus`. Reaching for `Tissue.create` with a custom `Container`
is a deliberate choice. Wiring a Flow gate into a Tissue book is the
subject of §8.

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
| **`TissuePulse`** | `Pulse` subtype: add / remove / value-change (and evolved / collective / unmodifiable variants). |
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
TissuePulse  ──Synapses──► observers (and child-cell links)
```

**Initial population is silent.** `TissueSet([1, 2, 3])` does not emit
events. Only mutations *after* construction do.

**Batch validation is per-element.** `addAll` skips invalid members; it
does not fail the whole call.

**The `modifiable` manifest is the public contract.** `TissueList`,
`TissueSet`, `TissueMap`, `TissueQueue`, and `TissueValue` each expose a
`modifiable` iterable of functions. Every mutation routed through
`apply(function, …)` first checks `modifiable.contains(function)`. An
unmodifiable view has an empty `modifiable`, so an external dispatcher
that consults the manifest can deny a verb **before** the tissue lock is
taken.

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

**Dispatch-side gate.** A deputy’s empty `modifiable` is the mechanism a
dispatcher uses to deny a verb without attempting the mutation. The
sibling demos exercise this directly: the dispatch instruction consults
`host.modifiable.contains(tearOff)` before calling the tear-off, so an
unmodifiable host is denied at the gate.

**Snapshot caveat.** In some builds, `.unmodifiable` may be a snapshot
rather than a live view. Verify the header of the demo or the docstring
of `.unmodifiable` before relying on liveliness; the two behaviours are
indistinguishable from an observer that subscribes after install.

---

## 5. Relationship to cell

| Concern | cell | cell_tissue |
|---------|------|-------------|
| One value | `Cell.state` / `ValueCell` | `TissueValue` (ValueCell + tissue cycle, nested linking) |
| Many values | several cells + `synthesis` | one `TissueList` / `Set` / `Map` / `Queue` |
| Validation | `TestCell` | `TestTissue` (elements + actions) |
| Signal | `Pulse` | `TissuePulse` (is a `Pulse`) |
| Storage | `Box<V>` | `Container` strategy + `TissueContainer` |
| Restricted view | `Cell.deputy` / `.unmodifiable` | same, plus deep element projection |
| Command whitelist | `Cell.modifiable` | `Tissue.modifiable` (per collection type) |

Use **cell** when the unit of change is one atom. Use **tissue** when the
unit of change is membership or an indexed/keyed structure, and you want
granular add/remove events instead of replacing a whole list in a
`ValueCell<List<T>>`.

**TestCell vs TestTissue — do not swap:**

| Host | Rule type | Parameter |
|------|-----------|-----------|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` |

They are not subtypes. A rule that validates the shape of an incoming
pulse belongs on a `Cell`. A rule that validates a mutation, a member,
or a value write belongs on a `Tissue`. Passing a `TestCell` where a
`TestTissue` is expected is a type error; wrapping one in the other is a
layering error.

**TissueValue vs ValueCell** (also [`docs/InDepth-CollectiveValue-vs-ValueCell.md`](docs/InDepth-CollectiveValue-vs-ValueCell.md)):
`TissueValue` implements `ValueCell` but uses `TissueValueNucleus`,
`TestTissue`, and `TissueReceptor`. Prefer `Cell.state` / `ValueCell`
for a lightweight scalar; prefer `TissueValue` when the scalar must
participate in tissue rules, deep unmodifiable trees, or nested-cell
linking.

---

## 6. Relationship to cell_flow

`cell_flow` adds operators that transform, filter, and route `Pulse`s.
`cell_tissue` is a `Cell` subtype, so a tissue can be a source or a sink
for a Flow pipeline. The two packages address different concerns:

| Concern | cell_flow | cell_tissue |
|---------|-----------|-------------|
| Purpose | Decision, transformation, timing | Durable state, validation, audit |
| Signal | `Pulse` (input and output) | `TissuePulse` (a `Pulse` subtype) |
| State | None | The collection is the state |
| Validation | `TestCell` on ingress / handles | `TestTissue` on mutations |
| Sink for `Cell.observe` | Yes | Yes (a tissue is a Cell) |
| Storage | None | `Container` strategy |

A Flow gate emits a `Pulse`. An observer attached to the gate writes the
Tissue. The Tissue does not run inside the Flow gate. This is the
architectural boundary the demos teach.

---

## 7. The seam — Flow owns the decision, Tissue owns the books

The four sibling demos in `/example` all follow the same shape:

> **Flow decides. Tissue records. The observer is the only glue.**

- Flow answers: *“Is this tick a DECLINE / DISPATCH / SHED / verb?”*
- Tissue answers: *“What did the books just record, and did money /
  drivers / megawatts / members move?”*
- A `Cell.observe` on the gate cell is the only channel.

### 7.1 Two locks, two owners

Every reactive node carries its own synchronisation lock. The demos keep
two **disjoint** lock domains:

| Domain | Primitive | Covers | Does not cover |
|--------|-----------|--------|----------------|
| Decision | Receptor lock on the gate cell | pure policy, Distinct latch, `Filter` | any Tissue write |
| Books | Tissue lock on each collection | `add` / `remove` / `set` / `[]=` | any decision logic |

A decision pulse crosses the two domains **sequentially**: the Receptor
lock releases, then the observer takes the Tissue lock. That sequencing
is what lets the policy be unit-tested with a bare domain object and no
Tissue at all.

### 7.2 The three coupling points

In a two-product demo there are exactly three places where the two
subsystems touch:

1. **Gate observer (Flow → Tissue, write-only).** The observer appends
   to the audit log, enqueues an outbound job, moves a balance.
2. **ACK observer (Flow → Tissue, write-only + latch reset).** The ACK
   observer calls `resetDistinct()` (a plain field assignment, no lock)
   and then optionally writes Tissue.
3. **Policy read (Tissue → Flow, read-only).** The pure policy reads a
   policy set (`mccBlock`, `noGo`, `protected`) but never writes it.

The third coupling is one-way and non-mutating. It is explicitly part of
the policy input, not a control channel.

### 7.3 Distinct before Filter

The Distinct latch runs **before** the Filter, so the latch records
every decision the pipeline made — including `hold` / `approve` /
`idle`. This is what makes `hold → shed → hold → shed` fire twice. If
Filter ran first, the second `shed` would be suppressed because the
latch still held `shed` from the first tick.

The corollary: **every tick writes every gate's latch**, even ticks
whose decision is not that gate's product. A SURGE tick sets the
DISPATCH latch to `surge`; a STEP-UP tick sets the DECLINE latch to
`stepUp`. This is the load-bearing consequence of the `Distinct →
Filter` ordering.

### 7.4 ACK resets, not rebuilds

ACK clears the Distinct latches via `resetDistinct()` without calling
`toHandle` again. A second `toHandle` would attach a second gate to the
same source and double every downstream effect.

### 7.5 Money movement is a separate moment

The ACK observer does **not** call `placeHold` / `applyShed` /
`accept`. The ACK clears the latches and appends an audit row. The
**caller** then calls the money-moving method directly. This separation
is what makes money movement a public imperative API that any
orchestration layer can call, and what lets the ACK observer stay a
pure latch-reset + audit append.

### 7.6 v1 write protocol and compensation

The three money methods (`placeHold` / `capture` / `voidHold` in card-auth,
`applyShed` / `restore` in grid, `accept` / `complete` in ride-hail)
write two or more Tissues in sequence. In this build there is no joint
commit across tissues, so each method uses a **compensation ladder**: if
a later write rejects, earlier writes are undone before the method
returns `false`. The ladder is the current substitute for
`Cell.transaction`; the migration target is documented per demo.

The invariant each demo maintains:

| Demo | Invariant |
|------|-----------|
| card-auth | `available + held + capturedCents == 250000` |
| ride-hail | `idleDrivers + assignments.length == 12` |
| grid | `reserveMw + sum(droppedMw) == 800` |
| nl-instruction | *(no numeric invariant — the set is the book)* |

Each demo deliberately breaks its invariant once to prove the guard
fires, then restores a self-consistent state.

---

## 8. Patterns shared across the sibling demos

| Pattern | Mechanism |
|---------|-----------|
| Ingress shape validation | `TestCell` on each ingress Cell |
| Snapshot bus | one domain object per tick, published on `tickIn` |
| Two gates per demo | `MapValue → Distinct → Filter` per product |
| Distinct-before-Filter | latch records every decision |
| ACK resets | `resetDistinct()`, no `toHandle` |
| Gate observer writes Tissue | `Cell.observe` is the only glue |
| `modifiable` gate | deny the verb before the tissue lock |
| Read-only deputy | `.unmodifiable` for the compliance screen |
| Append-only log | action-deny `TestTissue` on `TissueList` |
| Bounded outbound queue | `TissueQueue(capacity: n)` + working list |
| Non-negative value cell | `TissueValue<int>` + `v >= 0` rule |
| Runtime-mutable policy set | `TissueSet<String>` + ops `add` |
| v1 compensation ladder | try / undo in the money-moving method |
| Two locks, two owners | Receptor then Tissue, sequentially |

### 8.1 `TissueQueue` drain caveat

In this build, `TissueQueue.removeFirst` / `remove` do **not** drain the
container. The demos therefore use the queue as the **audit-side
enqueue** (`addLast` → `ElementAdded<RtuJob>`) and drive the retry pump
on a plain Dart working list (`_rtuWork`, `_pushWork`, `_issuerWork`).
A downstream observer can still subscribe to the queue's `ElementAdded`
pulses to reconstruct every outbound attempt.

### 8.2 Tissue-cell observer caveat

In this build, `Cell.observe` on a **Tissue** cell does not deliver
pulses to observer effects. The demos emit trace prints from the
**writers** themselves — the gate observers, the pump methods, the
money methods, and the scenario code in `main()`.

The pattern is portable: subscribe with `Cell.observe` when the Tissue
is a source for Flow; emit prints from the writer when the Tissue write
is the observable event.

---

## 9. Current status and known gaps

- **Alpha.** `publish_to: none`. No independent audit. `test/` is
  minimal in this package.
- **`example/` now ships four end-to-end demos**, each with an
  `*-Demo.dart`, a `*-WalkThrough.md`, a `*-FEATURES.md`, and a
  `*-ARCHITECTURE.md`:
  - `card-auth-pipeline(tissue)-*` — payments books
  - `ride-hail-dispatch(tissue)-*` — mobility books
  - `grid-demand-response(tissue)-*` — energy books
  - `nl-instruction-tissue-set-*` — command-surface book
- **Dartdoc snippets are stale** in places
  (`tissue.listen(...)` — observe with `Cell.observe`;
  `TissueList([1, 2, 3])` — use `TissueList.of([...])`).
- **`TissueList` primary factory** does not take initial elements;
  `TissueList.of` does. `TissueSet` / `TissueQueue.of` / `TissueValue`
  do take initial data on the main factory.
- **`TissueMap` constructor** puts `testRule` on the
  `TissueMapNucleus`, passed via `properties:`.
- **`addAll` skips invalid elements silently** — easy to miss in UI
  unless you count before/after or log in a custom `TestTissue`.
- **Queue overflow** drops the oldest element with no dedicated event
  documented as distinct from a normal remove.
- **`TissueQueue` does not drain** via `removeFirst` / `remove` in this
  build.
- **`Cell.observe` on a Tissue cell is silent** in this build.
- **`.unmodifiable` may be a snapshot** in some builds. Verify the
  docstring or the demo header before relying on liveliness.
- **No joint commit** across multiple Tissues in this build. The demos
  use the v1 compensation ladder; `Cell.transaction` is the migration
  target.
- **Isolates.** Locks make mutations atomic on one isolate; they do not
  share a tissue across isolates.
- **Marketing claims** in the previous README (AI-native tier,
  10k-item claims) are not measured guarantees.

If you rely on a guarantee here, verify it against the current source
and the header of the demo that exercises it.

---

## 10. See also

| Document                                                                                                  | Purpose |
|-----------------------------------------------------------------------------------------------------------|---------|
| [`FEATURES-Tissue.md`](FEATURES-Tissue.md)                                                                | Categorized feature catalog |
| [`DEMO_GUIDE-Tissue.md`](DEMO_GUIDE.md)                                                                   | Progressive walk-through of the demos |
| [`card-auth-pipeline(tissue)-ARCHITECTURE.md`](../example/card-auth-pipeline(tissue)-ARCHITECTURE.md)     | Payments sibling — same seam, different domain |
| [`ride-hail-dispatch(tissue)-ARCHITECTURE.md`](../example/ride-hail-dispatch(tissue)-ARCHITECTURE.md)     | Mobility sibling |
| [`grid-demand-response(tissue)-ARCHITECTURE.md`](../example/grid-demand-response(tissue)-ARCHITECTURE.md) | Energy sibling |
| [`cell`](../cell/)                                                                                        | Core graph primitives |
| [`cell_flow`](../cell_flow/)                                                                              | Reactive operators |