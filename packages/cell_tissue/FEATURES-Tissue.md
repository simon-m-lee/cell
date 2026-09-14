# cell_tissue — Feature Catalog

**Package:** `cell_tissue`  
**Version:** 1.0.0-rc.4  
**SDK:** Dart `>=3.5.0 <4.0.0`  
**License:** MIT or Apache-2.0  
**Author:** Lee Man Hoi Simon (see [`AUTHORS`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/AUTHORS))  
**Location:** `packages/cell_tissue`

Categorized inventory of reactive collections in the Cell Framework.
Tissues are **cells** that hold a Dart collection. If dartdoc and the
factories disagree, **the source is current**. Design intent:
[`ARCHITECTURE.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/ARCHITECTURE-Tissue.md).

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
15. [Relationship to cell and cell_flow](#15-relationship-to-cell-and-cell_flow)
16. [The Seam — Flow + Tissue](#16-the-seam--flow--tissue)
17. [Patterns in the Sibling Demos](#17-patterns-in-the-sibling-demos)
18. [Use-Case Decision Matrix](#18-use-case-decision-matrix)
19. [Known Gaps](#19-known-gaps)
20. [Quick Reference](#20-quick-reference)

---

## 1. What cell_tissue Is

**cell** is one node and one pulse. **cell_tissue** is a node whose
state is a **collection**, with a pulse per structural change.

You still call `add`, `remove`, `[]=` — those methods run TestTissue,
commit under a lock, and emit a `TissuePulse`.

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

**Alpha.** `publish_to: none`. No independent audit. The `example/`
tree now ships with four end-to-end demos (see §17) plus companion
docs per demo; the `test/` directory remains minimal.

| Claim | Reality |
|-------|---------|
| Drop-in `List` / `Set` | Implements the interfaces; mutations are gated and may skip invalid items. |
| Snapshot unmodifiable | `.unmodifiable` is a **live** deputy in the general case (some builds may snapshot; see the demo header). |
| Thread-safe / multi-isolate | Per-tissue `Lock` on one isolate. Not shared-memory across isolates. |
| `listen` on the tissue | Dartdoc examples; observe with `Cell.observe(source: tissue, …)`. In some builds, `Cell.observe` on a **Tissue** cell does not fire effect callbacks; trace prints come from the writers. |
| `TissueList([1, 2, 3])` | Not the primary factory. Use `TissueList.of([1, 2, 3])`. |
| `TissueMap(testRule: …)` | Not the primary factory. Pass a `TissueMapNucleus` via `properties:`. |
| `TissueQueue.removeFirst` drains | Not guaranteed in this build; demos use an audit-side enqueue + a plain Dart working list for the pump. |
| `TestCell` on a Tissue | Not allowed. Tissues take `TestTissue`, never `TestCell`. |

**TestCell vs TestTissue — do not swap:**

| Host | Rule type | Parameter |
|------|-----------|-----------|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` |

---

## 3. Progressive Disclosure

1. `TissueList.of` / `TissueSet` / `TissueMap` / `TissueQueue` / `TissueValue`
2. `TestTissue`, `.unmodifiable`, `.deputy()`
3. Custom `TissueReceptor`, `Synapses` / `PropagationPolicy`
4. `TissueNucleus`, `Tissue.create`, `Container.*`
5. Flow + Tissue seam: `Cell.observe` glue, Distinct-before-Filter, ACK-resets

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
- `modifiable` is the collection's public whitelist — the dispatcher
  or any external agent must consult it before invoking a tear-off.

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

**Append-only enforcement pattern** (used in the sibling demos):

```dart
final eventRule = TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
  (e, {host, arguments, user}) {
    if (arguments is Function) {
      final src = arguments.toString();
      if (src.contains('remove') ||
          src.contains('clear') ||
          src.contains('[]=')) {
        return false;
      }
    }
    return true;
  },
);
```

`TissueList` routes every mutation through `apply(function, …)`. The
`arguments` parameter of the rule receives that function, so a
string-match against `remove`/`clear`/`[]=` denies the action.

---

## 6. TissueSet

Unique elements. Implements `Set<E>`.

| Factory | Notes |
|---------|--------|
| `TissueSet(elements, {…, identitySet})` | Value equality by default; **initial iterable positional** |
| `TissueSet.empty` / `.of` / `.from` | Empty or copy |
| `TissueSet.identity({entries})` | `identical` uniqueness (`Container.identitySet`) |
| `TissueSet.fromNucleus` / `.unmodifiable` | Blueprint / view |

Use identity sets for collections of `Cell` instances when `==` would
collapse deputies incorrectly.

**Runtime-mutated policy pattern** (used in the sibling demos):

```dart
final mccBlock = TissueSet<String>(
  <String>[],
  testRule: TestTissue<String, TissueSet<String>>(
    (v, {host, arguments, user}) =>
        v is String && v.length == 4 && int.tryParse(v) != null,
  ),
);

// ops adds a category at runtime
mccBlock.add('7995');
```

The set is a **policy input** read by the pure decision function; it
is not a Pulse producer.

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

**Constructor note:** `testRule` lives on the `TissueMapNucleus`, passed
via the `properties:` argument:

```dart
final holdsMap = TissueMap<String, Hold>(
  properties: TissueMapNucleus<String, Hold>(testRule: _holdRule),
);
```

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

**Drain caveat.** In this build, `removeFirst` / `remove` on a
`TissueQueue` do **not** drain the container. The sibling demos use
the queue as the **audit-side enqueue** (`addLast` →
`ElementAdded<RtuJob>` / `ElementAdded<PushJob>` /
`ElementAdded<IssuerJob>`) and drive the pump on a plain Dart
working list. A downstream observer can still subscribe to the
queue's `ElementAdded` to reconstruct every outbound attempt.

---

## 9. TissueValue

Single scalar that is both `Tissue<V>` and `ValueCell<V>`.

| Factory | Notes |
|---------|--------|
| `TissueValue(value, {…, finalValue})` | Optional initial value; **initial scalar positional** |
| `TissueValue.empty({…})` | Starts unset |
| `TissueValue.fromNucleus` / `.unmodifiable` | Blueprint / view |

`finalValue: true` → `Container.finalValue` (set once). Emits
`ElementUpdated` on assignment.

Prefer `Cell.state` / `ValueCell` unless you need tissue validation,
deep unmodifiable, or nested-cell linking. See
`docs/InDepth-CollectiveValue-vs-ValueCell.md`.

**Non-negative guard pattern** (used in the sibling demos):

```dart
final reserveMw = TissueValue<int>(
  800,
  testRule: TestTissue<int, TissueValue<int>>(
    (v, {host, arguments, user}) => v is int && v >= 0,
  ),
);
```

Any write that would go negative is rejected. The rule is the primary
under-frequency / NSF / over-assignment guard.

---

## 10. Events

`TissuePulse<E>` implements `Pulse<E>`.

| Type | When |
|------|------|
| `ElementAdded<E>` | Membership add |
| `ElementRemoved<E>` | Membership remove (`clear` / `removeAll` may batch in payload) |
| `ElementUpdated<V, E>` | `TissueValue` assignment (`ElementUpdatedRecord<V, E>`) |
| `EvolvedTissuePulse` | Causal child of another tissue pulse |
| `CollectiveTissuePulse` | `TissuePulse.batch(pulses)` |
| `UnmodifiableTissuePulse` | Frozen pulse view |
| `TissueEventShell` | Handshake / scrutinize wrapper |

`ElementUpdatedRecord<V, E>` is a **record** with three fields:

```dart
final (cell, :before, :after) = event.payload!;
```

Observe:

```dart
Cell.observe(
  source: list,
  effect: (pulse) {
    if (pulse is ElementAdded<int>) {
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

**Rule taxonomy used in the sibling demos:**

| Kind | Example | Enforced at |
|------|---------|-------------|
| Element shape | `v is int && v >= 0` | `TissueValue` / `TissueSet` / `TissueMap` value |
| Action deny | block `remove` / `clear` / `[]=` | `TissueList` / any collection |
| Non-negative | `v != null && v >= 0` | `TissueValue` |
| Key/value shape | `driverId.isNotEmpty && riderId.isNotEmpty` | `TissueMap` value |
| Structure | `v.length == 4 && int.tryParse(v) != null` | `TissueSet<String>` |
| Read-only | `TestTissue.readOnly` | `.unmodifiable` / `.deputy(...)` |

---

## 12. Receptor, Nucleus, Container

**TissueReceptor** — `passThrough` (singleton),
`TissueReceptor((tissue, pulse, {user}) => …)`,
`TissueReceptor.pipeline({preProcess, instruction, postProcess, reaction, init, user})`.
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

**Dispatch-side gate pattern** (used in the NL-instruction demo): the
dispatch instruction consults `host.modifiable.contains(tearOff)`
before calling the tear-off. An unmodifiable view has an empty
`modifiable`, so the gate denies the verb **before** the tissue lock
is taken.

```dart
final host = _dispatchHost.value;
if (!host.modifiable.contains(tearOff)) {
  print('[dispatch] ${cmd.verb.name} denied (not in modifiable)');
  return;
}
```

---

## 14. Observation and Async

Tissues are cells: `Cell.observe(source: tissue, effect: …)` or
`Flow.observe(bind: tissue, …)` if cell_flow is in use.

**Tissue-cell observer caveat.** In this build, `Cell.observe` on a
Tissue cell does **not** deliver pulses to observer effects. The
sibling demos emit trace prints from the writers themselves (the
observers, `_drivePush` / `_driveRtu` / `_driveIssuer`, `placeHold`,
`applyShed`, `accept`, etc.).

`tissue.async` returns a typed async wrapper (`ModifiableListAsync`,
`ModifiableSetAsync`, `ModifiableMapAsync`, `ModifiableQueueAsync`,
`ModifiableValueAsync`) so mutations can be awaited through the lock.

Propagation timing (`debounce` / `throttle` / `batch`) is still
`Synapses` + `PropagationPolicy` from **cell**, attached at construction.

---

## 15. Relationship to cell and cell_flow

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
| Pure decision + governed book | **cell_flow** gate + **cell_tissue** observer |

---

## 16. The Seam — Flow + Tissue

The sibling demos all follow the same architectural pattern:

> **Flow owns the decision. Tissue owns the books. The observer is the
> only glue.**

- Flow answers: *“Is this tick a DECLINE / DISPATCH / SHED / verb?”*
- Tissue answers: *“What did the books just record, and did the money /
  driver / megawatt move?”*
- A `Cell.observe` on the gate cell is the only channel.

**Two locks, two owners:**

| Domain | Primitive | Covers |
|--------|-----------|--------|
| Decision | Receptor lock on the gate cell | `riskOf` / `matchOf` / `actionOf`, Distinct latch, `Filter` |
| Books | Tissue lock on each collection | `ledger.add`, `reserveMw.set`, `shedMap[...]`, `rtuQ.addLast`, etc. |

A decision pulse crosses the two domains **sequentially**, never
simultaneously. That sequencing is what lets the policy be unit-tested
with a bare domain object and no Tissue at all.

**Distinct-before-Filter ordering.** The Distinct latch runs **before**
the Filter, so the latch records every decision the pipeline made —
including `hold` / `approve` / `idle`. This is what makes
`hold → shed → hold → shed` fire twice.

**ACK resets.** ACK clears the Distinct latches via `resetDistinct()`
without calling `toHandle` again. A second handle would double every
downstream effect.

---

## 17. Patterns in the Sibling Demos

The `/example` tree ships four end-to-end demos. Each demonstrates the
same seam with a different domain:

| Demo | Domain | Flow decision | Tissue books |
|------|--------|---------------|--------------|
| `card-auth-pipeline(tissue)-Demo.dart` | Payments | `riskOf` → DECLINE / STEP-UP | `ledger`, `available`, `held`, `holdsMap`, `mccBlock`, `issuerQ` |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility | `matchOf` → DISPATCH / SURGE | `trips`, `idleDrivers`, `assignments`, `noGo`, `pushQ` |
| `grid-demand-response(tissue)-Demo.dart` | Energy | `actionOf` → SHED / WARN | `events`, `reserveMw`, `shedMap`, `protected`, `rtuQ` |
| `nl-instruction-tissue-set-Demo.dart` | Command surface | `AiTissueCommand` → `TissueCommand` | `tags` (`TissueSet<int>`) |

**Common patterns across all four:**

1. **Ingress `TestCell`** — shape validation at the edge.
2. **Snapshot bus** — one domain object per tick.
3. **Two gates per demo** — one Receptor per product.
4. **Distinct-before-Filter** — latch records every decision.
5. **ACK resets** — no graph rebuild.
6. **Observer writes Tissue** — the only glue.
7. **`modifiable` gate** — the collection's public contract.
8. **Read-only deputy** — the compliance / council / auditor view.
9. **Append-only log** — the audit trail is never deletable.
10. **Bounded outbound queue** — capacity limits backpressure.
11. **Non-negative value cell** — the balance / reserve / count guard.
12. **Runtime-mutable policy set** — ops change a blocklist without redeploy.
13. **v1 compensation ladder** — try/undo in the money-moving method.
14. **Two locks, two owners** — Receptor then Tissue, sequentially.

**Documented deviations in each demo:**

- Tissue constructors: `TissueSet` / `TissueValue` take the initial
  value as the **first positional** argument; `TissueMap` puts
  `testRule` on the nucleus via `properties:`.
- Each `TestCell` unwraps `Pulse.payload` before the shape check.
- Outbound pump: `addLast` is the audit enqueue; a plain Dart working
  list drives the retry.
- Trace prints come from the writers themselves, because
  `Cell.observe` on a Tissue cell is silent in this build.

---

## 18. Use-Case Decision Matrix

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
| Append-only audit log | `TissueList` + action-deny `TestTissue` |
| Non-negative balance | `TissueValue<int>` + `v >= 0` rule |
| Open-hold table | `TissueMap<String, Hold>` + shape rule |
| Runtime blocklist | `TissueSet<String>` + ops `add` |
| Bounded outbound buffer | `TissueQueue<T>(capacity: n)` |
| Read-only projection for a regulator | `.unmodifiable` / `.deputy(TestTissue.readOnly)` |
| Money invariant across two cells | `TissueValue` + `TissueMap` + v1 compensation ladder |
| Pure decision + governed book | Flow gate + `Cell.observe` + Tissue write |
| LLM verb whitelist enforcement | `host.modifiable.contains(tearOff)` before the tear-off |

---

## 19. Known Gaps

1. Alpha; not published; `test/` remains minimal.
2. Dartdoc `listen` / `TissueList([...])` snippets vs actual API.
3. `addAll` silent skip of invalid elements.
4. Queue overflow drops oldest with no dedicated event documented as
   distinct from a normal remove.
5. `tissue_callable.dart` is not exported from `tissue.dart`.
6. `TissueQueue.removeFirst` / `remove` do not drain the container in
   this build. The sibling demos use an audit-side enqueue + a plain
   Dart working list.
7. `Cell.observe` on a Tissue cell is silent in this build. Trace
   prints come from the writers.
8. `.unmodifiable` is a **snapshot** in some builds (see the NL
   instruction demo trailer: `auditorLength=0`). Verify the header of
   the demo before asserting liveliness.
9. Joint commit across multiple Tissues is not exposed in this build.
   The sibling demos use a v1 compensation ladder; `Cell.transaction`
   is the migration target.
10. Marketing claims in the previous README are not measurements.

---

## 20. Quick Reference

```dart
import 'package:cell_tissue/cell_tissue.dart';

// ── Collections ─────────────────────────────────────────────
final list = TissueList.of<int>([1, 2, 3]);
final tags = TissueSet<String>(['a', 'b']);
final map  = TissueMap<String, int>(entries: [MapEntry('k', 1)]);
final q    = TissueQueue<int>(capacity: 8);
final n    = TissueValue<int>(0);

// ── Observe ─────────────────────────────────────────────────
Cell.observe(
  source: list,
  effect: (p) {
    if (p is ElementAdded<int>) print(p.payload);
  },
);

// ── Validate ────────────────────────────────────────────────
final nonNegative = TestTissue<int, TissueValue<int>>(
  (v, {host, arguments, user}) => v is int && v >= 0,
);
final reserveMw = TissueValue<int>(800, testRule: nonNegative);

// ── Deputy / unmodifiable ───────────────────────────────────
final readOnly = list.unmodifiable;
final scoped   = list.deputy(testRule: TestTissue.readOnly);

// ── Flow + Tissue seam ──────────────────────────────────────
final gate = MapValue<Tick, Decision>((t) => policyOf(t, policySet))
    + _distinct()
    + Filter<Decision>((d) => d == Decision.fire);

final gateCell = gate.toHandle(source: tickIn.cell).cell;

Cell.observe(
  source: gateCell,
  effect: (pulse) {
    if (pulse.payload == Decision.fire) {
      ledger.add(LedgerEntry(...));
      outboundQ.addLast(Job(...));
      // ... move money / drivers / megawatts
    }
  },
);
```

| Type | Populate | Interfaces |
|------|----------|------------|
| `TissueList` | `.of(iterable)` | `List` |
| `TissueSet` | `(iterable)` | `Set` |
| `TissueMap` | `{properties, entries}` / `.from` | `Tissue<V>` |
| `TissueQueue` | `.of` + `capacity` | `Queue` |
| `TissueValue` | `(value)` | `ValueCell` + `Tissue` |

| TestTissue kind | Purpose |
|-----------------|---------|
| Element shape | validate each member |
| Action deny | block `remove` / `clear` / `[]=` |
| Non-negative | reject negative balance |
| Key/value shape | require non-empty id, positive amount |
| `readOnly` | block all mutations |

| Gate pattern | Purpose |
|--------------|---------|
| `MapValue` | pure policy (`riskOf` / `matchOf` / `actionOf`) |
| `Distinct` (custom) | record every decision, resettable by ACK |
| `Filter` | drop decisions that don't match the gate's product |
| `Cell.observe` | glue — the only place Tissue is written |