# cell_flow — Architecture

**Author:** Lee Man Hoi Simon (see `AUTHORS`)

This document explains the design of **cell_flow** (`package:cell_flow`):
why operators exist, how they sit on **cell**, and how a pulse becomes a
downstream `FlowHandle`. It is the Flow counterpart to cell’s own
architecture notes.

For operator catalogues see the instruction files under
`lib/src/instruction/`. For chaining syntax see
[`HowTo-Fluent_Operator.md`](HowTo-Fluent_Operator.md). For one-Receptor
pipelines see
[`HowTo-FlowInstruction-Receptor.md`](HowTo-FlowInstruction-Receptor.md).

---

## 1. The core idea

**cell** is a graph of nodes (`Cell`), signals (`Pulse`), integrity
(`TestCell`), and gates (`Receptor`). That is enough to hold state and
notify observers. Everyday stream work — debounce, switchMap, zip, retry —
would otherwise be ad-hoc `Timer`s and custom receptors.

cell_flow adds an **operator layer**. Each named policy is a
`FlowInstruction` that:

1. Reads pulses from a bound source `Cell`.
2. Drops, delays, maps, buffers, or fans them according to that policy.
3. Materializes as a `FlowHandle` (`{ cell, emit, emitAsync, ingest }`)
   whose `Receptor` *is* that instruction (or an `InstructionChain` of
   them).

The graph, locks, validation, and provenance stay in **cell**. Flow only
decides *which* pulses go downstream and *when*.

```
cell          identity, lock, TestCell, Context, Synapses
cell_flow     named pulse policies (Rx-shaped operators)
```

Flow does not invent a second graph. A Flow cell is a cell.

---

## 2. Progressive disclosure

Cognitive load should match the task. Calling `Flow.debounce` must not
require reading `Nucleus`.

| Tier | What you use | When |
|---|---|---|
| **1. `Flow.*` factories** | `Flow.map`, `Flow.debounce`, `Flow.merge` | Application code. |
| **2. Fluent extensions** | `cell.filter().map()` from `fluent_operator.dart` | Unary pipelines. Same factories. |
| **3. Instruction classes** | `Filter`, `Debounce`, `SwitchMap` + `.toHandle(source:)` | A custom `Receptor`, or an operator not on `Flow`. |
| **4. InstructionChain** | `Filter + MapValue + Tap` | One Receptor, one lock, many sync stages. |
| **5. Nucleus / Receptor** | `Receptor.instruction(op)` + `Nucleus` | Combinators that need a custom gate. |

Moving from 1 toward 5 is a **choice**. If a Tier 1 factory required
Nucleus knowledge to use correctly, that would be a design smell.

---

## 3. Core primitives

| Primitive | Role |
|---|---|
| **`Flow`** | Abstract facade (`extends CellBase`). Static factories return `FlowHandle`. |
| **`FlowInstruction`** | `Instruction<C,I,O>` with `+` and `toHandle`. Every operator class implements this. |
| **`FlowInstructionBase`** | Sync closure or `.future` closure (async emit sink). |
| **`_FlowInstructionChain`** | `InstructionChain` + `FlowInstructionMixin`. Result of `a + b`. |
| **`FlowHandle`** | `{ Cell cell, emit, emitAsync, ingest }` — same idea as `IngressHandle`. |
| **`Cell` / `Pulse` / `Receptor` / `Nucleus` / `TestCell` / `Synapses`** | Unchanged cell primitives. Re-exported from `flow.dart`. |

### How an operator becomes a cell

```
source Cell
    │
    ▼
FlowInstruction  (e.g. Debounce)
    │  toHandle(source:)
    ▼
Receptor.instruction(this)
    │
    ▼
Nucleus(bind: source, receptor: …, testRule, synapses)
    │
    ▼
Cell.fromNucleus  →  FlowHandle.cell
```

That wiring lives in `FlowInstructionMixin.toHandle` (`flow_core.dart`).

Sync operators (`Filter`, `MapValue`, `Tap`) return a pulse or `null`
from the instruction closure. `null` means “drop this pulse.”

Async / timed operators (`Delay`, `AsyncMap`, `Debounce`, `FromStream`)
are constructed with `FlowInstructionBase.future`. They return `null`
immediately and later call the `future:` sink with a result pulse. That
is why they are not a pure map of pulse-in → pulse-out: they suspend,
buffer, or subscribe, then emit.

---

## 4. Two syntaxes, one graph

### Static factories

```dart
Flow.debounce<String>(
  Flow.distinct<String>(search.cell).cell,
  duration: const Duration(milliseconds: 300),
);
Flow.merge<int>(gate.cell, sources: [a.cell, b.cell]);
```

Authoritative entry. Best when there is no single primary upstream
(`merge`, `zip`, `race`, `combineLatest`) or when a node should be named
in logs.

### Fluent extensions

`fluent_operator.dart` is a **part** of `library cell_flow`. One import:

```dart
import 'package:cell_flow/flow.dart';

search.cell
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: api.search);
```

`CellFlowOperators` starts from a `Cell`. `FlowOperators` continues from a
`FlowHandle` via `.cell`. Every method delegates to `Flow.*`. Fluent does
not add behaviour and does not bypass `TestCell`.

### Instruction `+` (one Receptor)

```dart
final gate = MapValue<String, String>((s) => s.trim()) +
    Filter<String>((s) => s.isNotEmpty) +
    Distinct<String>();
final handle = gate.toHandle(source: ingress.cell);
```

This is **not** the same as fluent chaining. `+` builds an
`InstructionChain` executed by **one** Receptor under **one** lock.
Fluent `filter().map()` builds **two** cells.

| | `+` / `Instruction.chain` | Fluent / nested `Flow.*` |
|---|---|---|
| Receptors | one | one per operator |
| Lock | shared | per node |
| Best for | sync policy (trim, filter, tap) | timers, HTTP, flatten |
| Test | `receptor.call(Pulse(...))` | probe the output cell |

---

## 5. Operator families

Instructions live as one file per family (Rx name in comments, original
code and license).

| Family | File | Policy |
|---|---|---|
| Create | `of.dart`, `from_future.dart`, `from_stream.dart` | arming pulse plays a sequence / Future / Stream |
| Transform | `map.dart`, `pluck.dart`, `scan.dart`, `reduce.dart`, `pairwise.dart` | 1 → 1 (or running state) |
| Filter | `filter.dart` | 1 → 0..1 predicate / type / allow-list |
| Take / skip / distinct | `take.dart`, `skip.dart`, `distinct.dart` | count and uniqueness gates |
| Flatten | `concat_map.dart`, `merge_map.dart`, `switch_map.dart`, `exhaust_map.dart`, `async_expand.dart` | inner sequences |
| Combine | `merge.dart`, `zip.dart`, `combine_latest.dart`, `race.dart` | several sources |
| Time | `delay.dart`, `debounce.dart`, `throttle.dart`, `sample.dart`, `interval.dart`, `timeout.dart` | *when* a pulse leaves |
| Collect | `buffer.dart`, `window.dart`, `group_by.dart`, `partition.dart` | lists / groups |
| Control | `start_with.dart`, `share.dart`, `retry.dart`, `tap.dart`, `routing.dart` | prefix, multicast, errors, `iif` |
| Async fold / map | `async_map.dart`, `async_fold.dart` | queued / latest / concurrent projection |

Cells **do not complete**. Operators that are terminal in Rx (`last`,
`reduce` as a single value, `concat(cellA, cellB)`) are adapted:

- running fold (`scan` / `reduce` / `asyncFold`) instead of a terminal reduce
- concat of **inners** (list / Future / Stream payloads), not Cell-then-Cell
- `take` / `skip` as sticky gates, not completion

---

## 6. Relationship to cell

| Concern | Lives in |
|---|---|
| Holding state, deputies, transactions | **cell** (`Cell.state`, `Cell.transaction`) |
| Pulse lineage, `TestCell`, `Context` | **cell** |
| Debounce / throttle / switchMap / merge / zip | **cell_flow** |
| Fan-in | cell: `Cell.synthesis`; flow: `merge`, `zip`, `combineLatest` (different pairing rules) |
| Route by type / predicate | cell: hub; flow: `routing.dart`, `partition.dart`, `Iif` |

`flow.dart` re-exports `package:cell/cell.dart`, so one import covers both
layers.

A Flow output cell can be observed, deputized, put in a transaction, or
passed into another `Flow.*` factory. Flow does not invent a second
identity model.

If **cell** already has a thin `debounce` / `asyncMap`, prefer **one**
layer in a given pipeline so timing and identity stay obvious. Flow’s
versions are the richer Rx-shaped set (leading/trailing, latest/exhaust,
indexed map, error pulses).

---

## 7. Error and time contracts

- Typed operators call `onError` and drop the pulse when the payload is
  the wrong type (`FormatException`).
- Async failures call `onError`. Some families also take
  `emitErrorPulse` and emit `Pulse.type == 'error'`.
- Time operators use real `Timer`s / `Future.delayed`. Tests must wait.
- First-pulse **arming**: `FromFuture`, `Of`, `Interval`, `Zip` extra
  sources, `CombineLatest` extras — `future:` is only available after the
  bound handle has pulsed once.
- Inner sequences (`ConcatAll`, `MergeAll`, `FromStream`) treat a `String`
  as a scalar, not an iterable of characters.

---

## 8. Library surface

Supported public entry:

```text
package:cell_flow/flow.dart
  part  src/flow.dart              Flow facade
  part  src/flow_core.dart         FlowInstruction, toHandle, +
  part  src/fluent_operator.dart   Cell / FlowHandle extensions
  import src/instruction/*.dart    operator classes
```

Application code should import **only** `package:cell_flow/flow.dart`.
Instruction files stay implementation detail except when you construct
`Filter + MapValue` by type.

---

## 9. Design rules

1. **One policy per class.** `Filter` does not also debounce.
2. **Factories wrap classes.** `Flow.debounce` is `Debounce(...).toHandle`.
3. **Fluent wraps factories.** No third implementation.
4. **`+` is for sync gates.** Timers and HTTP belong on the next Cell.
5. **Names may follow Rx.** Implementations and license are original
   Cell Flow (terminology is not a reason to attach an RxJS copyright
   header).
6. **Do not complete the Cell.** Adapt terminal Rx operators to running
   or inner-sequence shape.
7. **`toHandle` is the Receptor hook.** Do not open a second subscribe
   path that bypasses `TestCell`.

---

## 10. Status

Intended design for the instruction-based Flow layer described above.
Verify guarantees against current source. Experimental trees
(`instruction2/`, unused nucleus blueprints) are out of scope for this
document unless `Flow.*` imports them.

If cell’s architecture document is the foundation, this file is the
operator storey on top of it: same graph, named policies, three ways in
(`Flow.*`, fluent, `InstructionChain`).
