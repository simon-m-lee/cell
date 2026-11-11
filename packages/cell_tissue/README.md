# cell_tissue

## Install and import

```bash
dart pub add cell cell_flow cell_tissue
```

```dart
import 'package:cell_flow/cell_flow.dart';  // re-exports package:cell
import 'package:cell_tissue/cell_tissue.dart';
```

## AI agents start here

Read this before opening any other page.

`cell_tissue` is designed with AI coding agents in mind. Every top public
symbol carries a machine-readable `### AI Agent Guide` block, and the surfaces
below let an agent reliably pick the right book and generate code that
compiles against the live API.

1. **Version pin:** `cell 1.1.0`, `cell_flow 1.0.0`, `cell_tissue 1.0.0`.
2. **Preflight:** `dart run tool/ai_preflight.dart` — prints the resolved versions and any stale pins.
3. **API chooser:** `lib/doc/api_chooser.dart` (generated from the `### AI Agent Guide` doc blocks).
4. **Layer guides:**
    - `guide/HowTo-Mitose-Tissue.md` — Tissue collection choices
    - `guide/HowTo-Mitose-Cell.md` — Cell factory choices
    - `guide/HowTo-Mitose-Flow.md` — Flow operator choices
5. **The seam sentence:** *The instruction decides, the chain assembles, the observer glues.*

## If you have a BRD sentence that says…

| BRD sentence | First book | Do NOT |
|---|---|---|
| "record of every alert and action" | `TissueList` + append-only | plain Dart `List` |
| "protected / diplomatic / resus" | `TissueSet` fed to `riskOf` | duplicate Dart `Set` |
| "open incidents by belt / stream" | `TissueMap` | new Map per bag |
| "alert the supervisor / RTU" | `TissueQueue` + pump list | drain the audit queue |
| "45,000 bags / 42 trolleys / 800 MW" | `TissueValue` + invariant | `Cell.state<int>` |
| "council reads, cannot delete" | `.unmodifiable` + COMPLY | a second "compliance" list |

(The full matrix lives in `lib/doc/api_chooser.dart`; this is the 6-row elevator version.)

---

> **Reactive Collections for the Cell Framework** — transaction-ready,
> observable, validated, thread-safe, auditable, and zero-copy deputy-able
> lists, sets, maps, queues, and single values. Everything a native Dart
> collection gives you, plus a governance contract.

[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.5-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-green.svg)](#license)

> **Mitose pipeline — the umbrella feature.** The root repository ships an AI-executable pipeline that turns a business requirement into a working Cell + Flow + Tissue solution with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. An AI prompt agent follows [`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md); this package supplies the **Tissue layer** rules via [`guide/HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md). See the [root README](https://github.com/simon-m-lee/cell#readme).

---

## Overview

`cell_tissue` brings the full power of reactive governance to Dart
collections. It provides lists, sets, maps, queues, and single-value
containers that are:

- **Transaction ready** — every mutation can run as an auditable,
  compensable command (`apply` + `ApplyCommand` → `ApplyOutcome`), or be
  staged into an atomic transaction (`Cell.txApply()` /
  `Cell.transaction()`) that buffers writes until commit and rolls back
  through recorded compensation on failure. Native collections have no
  equivalent: a multi-step mutation that throws halfway through leaves them
  permanently, partially updated.
- **Observable** — every mutation emits a typed reactive event that
  downstream observers react to; native collections require hand-rolled
  listener plumbing.
- **Validated** — business rules are enforced per element and per mutation
  vector via `TestTissue` before any write lands.
- **Thread-safe** — operations are serialized through a synchronization
  lock, safe for concurrent async flows on one isolate.
- **Deputy-able** — share a collection as a zero-copy read-only view
  (`.unmodifiable`) or a restricted proxy (`.deputy(...)`); native
  `List.unmodifiable` copies the data instead of sharing it.
- **Auditable** — every change carries a full causal trace with provenance
  metadata for forensic replay.
- **Batch-able** — `TissuePulse.batch` packages many changes into one
  collective notification with a single completion callback.
- **Backpressure-ready** — bounded queues drop the oldest element; lists
  support a fixed-length mode.
- **Async** — every tissue exposes a serialized `.async` facade for
  `await`-able mutations.
- **Equality-aware** — sets and maps switch between value and identity
  comparison.
- **Flow-seam** — the governed "book" half of the Flow-decides /
  Tissue-records pattern from `cell_flow`.

Where native collections give you a container, `cell_tissue` gives you a
container **with a governance contract**:

| Capability | Native `List`/`Map`/`Set`/`Queue` | `cell_tissue` |
|---|---|---|
| Change notification | Manual listener plumbing | Built-in — every mutation emits an event |
| **Transactions** | None — failures leave partial updates | Commands with compensation, atomic staging, and rollback |
| Validation | None | Per-element `TestTissue` rules |
| Read-only sharing | `List.unmodifiable` copies the data | Zero-copy, live `.unmodifiable` views |
| Restricted proxies | None | `.deputy(...)` with per-rule attenuation |
| Audit trail | None | Causal trace + provenance on every pulse |
| Backpressure | None | Bounded queue, fixed-length list |
| Batch notifications | None | `TissuePulse.batch` collective pulses |
| Async safety | None | Serialized `.async` facade |

> **Transaction ready, in one breath:**
>
> ```dart
> final ledger = TissueList<int>();
>
> // A single audited, compensable command:
> final outcome = await ledger.apply<dynamic>((
>   function: ledger.add,
>   arguments: (positionalArguments: [42], namedArguments: null),
>   compensation: (
>     function: ledger.remove,
>     arguments: (positionalArguments: [42], namedArguments: null),
>     cell: ledger,
>   ),
> )); // ApplyAccepted with a vetted receipt — never a half-applied write
>
> // Or stage many changes and commit them atomically:
> final tx = Cell.txApply();
> await tx.execute(participants: [ledger], body: (scope) {
>   ledger.apply<dynamic>(
>     (
>       function: ledger.add,
>       arguments: (positionalArguments: [7], namedArguments: null),
>       compensation: null,
>     ),
>     tx: scope,
>   ); // buffered — invisible to readers until the transaction commits
> });
> ```

Every `Tissue` is a `Cell` under the hood: it participates in the same
reactive graph, uses the same `Receptor`/`TestCell`/`Synapses`/`Context`
plumbing, and interoperates seamlessly with the rest of the Cell ecosystem.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [The Five Collection Types](#the-five-collection-types)
- [Observability](#observability)
- [Validation](#validation)
- [Read-Only Views](#read-only-views)
- [Deputies (Restricted Proxies)](#deputies-restricted-proxies)
- [Capacity & Backpressure](#capacity--backpressure)
- [Identity vs. Value Equality](#identity-vs-value-equality)
- [Async Operations](#async-operations)
- [The Flow + Tissue Seam](#the-flow--tissue-seam)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Best Practices](#best-practices)
- [Example Demos](#example-demos)
- [Status & Known Gaps](#status--known-gaps)
- [Related Packages](#related-packages)
- [License](#license)

---

## Installation

Add `cell_tissue` to your `pubspec.yaml`:

```yaml
dependencies:
  cell_tissue: ^1.0.0
```

Then run:

```bash
dart pub get
```

---

## Quick Start

```dart
import 'package:cell_tissue/cell_tissue.dart';

void main() {
  // 1. Create a reactive list
  final tasks = TissueList.of(['Buy milk', 'Walk dog']);

  // 2. Observe changes — every mutation emits a TissuePulse
  final observer = Cell.observe(
    source: tasks,
    effect: (Pulse pulse) {
      print('Changed: ${pulse.payload}');
    },
  );

  // 3. Mutate — every change flows through the reactive graph
  tasks.add('Write report'); // prints: Changed: Write report
  tasks.remove('Buy milk');  // prints: Changed: Buy milk

  // 4. Share a read-only view with a UI widget
  final readOnly = tasks.unmodifiable;

  // 5. Detach when done
  observer.stop();
}
```

> ⚠️ **Tissue-cell observer caveat (current build).** `Cell.observe` on a
> Tissue cell may not deliver pulses to observer effects in some builds. If
> your trace prints come back empty, emit them from the writer (the observer,
> the money method, the pump) instead. The example demos do exactly this and
> document the deviation in their headers.

> **`TissueList.of` not `TissueList`.** The primary `TissueList` factory is
> empty; use `TissueList.of(iterable)` to populate. `TissueSet` /
> `TissueQueue.of` / `TissueValue` accept initial data on their main
> factories.

---

## The Five Collection Types

| Type | Backing storage | Use when |
|------|-----------------|----------|
| `TissueList<E>`   | `List<E>`            | You need an ordered, indexable sequence. |
| `TissueSet<E>`    | `Set<E>`             | You need unique elements (value or identity equality). |
| `TissueMap<K, V>` | `Map<K, V>`          | You need associative key–value storage. |
| `TissueQueue<E>`  | `Queue<E>`           | You need FIFO/LIFO with optional capacity. |
| `TissueValue<V>`  | `ValueContainer<V>`  | You need a single reactive scalar. |

Every type implements the standard Dart collection interface, so you already
know how to use it:

```dart
final list = TissueList.of([1, 2, 3]);
list.add(4);
list.removeAt(0);
list[1] = 20;

final set = TissueSet<String>({'a', 'b'});
set.add('c');
set.remove('a');

final map = TissueMap<String, int>();
map['one'] = 1;
map.putIfAbsent('two', () => 2);

final queue = TissueQueue<int>(capacity: 10);
queue.addFirst(0);
queue.addLast(1);
queue.removeFirst();

final value = TissueValue<int>(42);
value.value = 100;
value.set(200);
```

---

## Observability

Every mutation emits a `TissuePulse<E>` — a `Pulse` whose payload carries the
changed data and whose provenance keeps the causal trace:

| Mutation | Emitted by |
|-------|------------|
| `add` / `addAll` / `addFirst` / `addLast` / `put` / index assignment | List, Set, Map, Queue |
| `remove` / `removeAt` / `clear` | List, Set, Map, Queue |
| assignment / `set` | Value |

```dart
final counter = TissueValue<int>(0);

Cell.observe(
  source: counter,
  effect: (Pulse pulse) {
    print('Value changed: ${pulse.payload}');
  },
);

counter.value = 42; // prints: Value changed: 42
```

Event classification flags live on `Tissue` (`Tissue.elementAdded`,
`Tissue.elementRemoved`, `Tissue.elementUpdated`). Batch events can be
bundled with `TissuePulse.batch` or the `+` operator:

```dart
final batch = event1 + event2 + event3;
```

> **Tissue-cell observer caveat (current build).** `Cell.observe` on a
> Tissue cell may not deliver pulses to observer effects in some builds.
> If your trace prints come back empty, emit them from the writer (the
> observer, the money method, the pump) instead. The example demos do
> exactly this and document the deviation in their headers.

---

## Validation

Enforce business rules with `TestTissue`. A rule receives the element, the
host tissue, the action, and optional user metadata. Returning `false`
rejects the mutation.

```dart
final positiveIntegers = TissueList<int>(
  testRule: TestTissue<int, TissueList<int>>(
    (value, {host, arguments, user}) => (value as int) > 0,
  ),
);

positiveIntegers.add(5);   // ✅ accepted
positiveIntegers.add(-3);  // ❌ rejected, no event emitted
```

Compose rules with `+`:

```dart
final policy = positiveIntegers +
    TestTissue<int, TissueList<int>>(
      (value, {host, ...}) => (value as int) < 1000,
    );
```

Two sentinels are built in:

- `TestTissue.allowAll` — no restrictions (default).
- `TestTissue.readOnly` — blocks all mutations.

**Append-only pattern.** A `TestTissue` rule receives the mutation function
in its `arguments` parameter. String-match against `remove` / `clear` /
`[]=` to enforce an append-only log:

```dart
final appendOnly = TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
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

### `TestCell` vs `TestTissue` — do not swap

| Host | Rule type | Parameter |
|------|-----------|-----------|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` |

They are not subtypes. A `TestCell` on a Tissue constructor is a type
error; a `TestTissue` on an ingress Cell is a type error.

---

## Read-Only Views

Get a live, read-only projection via `.unmodifiable`:

```dart
final source = TissueList.of(['A', 'B']);
final uiView = source.unmodifiable;

// Pass uiView to a widget — it can only read.
source.add('C');
print(uiView.length); // 3 — the view is live!
// uiView.add('D');   // throws UnsupportedError
```

Key properties of unmodifiable views:

- **Zero-copy** — share the same physical storage as the source.
- **Live** — reflect changes to the source immediately (pinned by the
  fitness suite; see below).
- **Recursive** — if `unmodifiableElement` is `true` (default), any `Cell`
  elements are projected as their own unmodifiable deputies, preventing
  side-door mutations.
- **Own observer registry** — observers attached to the view receive pulses
  independently of the source.

> ✅ **Liveliness is verified.** The fitness suite
> (`test/tissue/fitness/unmodifiable_is_live_test.dart`) pins that `.unmodifiable`
> views are live in the current build — across list, set, map, queue, and
> value.

---

## Deputies (Restricted Proxies)

For finer control than read-only — scoped authority, temporary access, custom
validation — use `.deputy()`:

```dart
final source = TissueList.of([1, 2, 3]);

// A read-only deputy
final readOnly = await source.deputy(testRule: TestTissue.readOnly);

// A deputy with a narrower authority tier
final scoped = await source.deputy(
  context: DeputyContext.delegate(
    baseContext: Context.system,
    task: 'REPORT_GENERATION',
  ),
);

// A time-limited deputy
final temporary = await source.deputy(
  ephemeralPolicy: EphemeralPolicy(
    duration: Duration(minutes: 5),
    onEvent: (o, {required cell, arguments, required policy, user}) =>
        (events: 0),
    onInvalidate: (nucleus) => true,
  ),
);
```

Deputies:

- Share the same storage and lock as the principal.
- Layer additional `testRule`s on top — you can only **narrow**, never widen.
- Are logically equal to their principal (`deputy == principal` is `true`).
- Have their own observer registries, so observers on the deputy are isolated.

### The `modifiable` gate

Every collection exposes a `modifiable` iterable of the functions that
`apply(function, …)` will accept. An unmodifiable view has an empty
`modifiable` — a dispatcher can check the manifest before invoking a
tear-off:

```dart
final host = _dispatchHost.value;
if (!host.modifiable.contains(tearOff)) {
  print('[dispatch] ${verb.name} denied (not in modifiable)');
  return;
}
```

This is how a natural-language command surface or a verb registry denies
a verb **before** the tissue lock is taken.

---

## Capacity & Backpressure

`TissueQueue` supports a bounded capacity. When full, adding a new element
silently drops the oldest one — a classic circular buffer:

```dart
final buffer = TissueQueue<int>(capacity: 3);
buffer.addAll([1, 2, 3]);
buffer.add(4);
print(buffer.toList()); // [2, 3, 4]
```

`TissueList` supports a fixed-length mode via `growable: false`:

```dart
final coords = TissueList.of([0, 0, 0], growable: false);
// coords.add(1); // throws — cannot grow
coords[0] = 1;    // ✅ index assignment still allowed
```

> **`TissueQueue` drain caveat.** In some builds, `removeFirst` / `remove`
> on a `TissueQueue` do not drain the container. The example demos use the
> queue as the **audit-side enqueue** (`addLast` → a pulse classified with
> `Tissue.elementAdded`) and
> drive the pump on a plain Dart working list. A downstream observer can
> still subscribe to the queue's `TissuePulse` stream to reconstruct
> every outbound attempt.

---

## Identity vs. Value Equality

By default, sets and maps compare elements/keys by value (`==` and `hashCode`).
For mutable objects or cells, use the identity variants:

```dart
final idSet = TissueSet<MyMutableKey>.identity();
idSet.add(keyA);
idSet.add(keyB); // different instance, same value → both kept

final idMap = TissueMap<MyMutableKey, int>.identity();
```

Use identity variants when:

- Keys or elements are mutable and could change between operations.
- You need to track distinct physical instances, not distinct values.
- Elements are `Cell`s whose internal state may mutate.

---

## Async Operations

Every tissue exposes an `.async` getter for non-blocking, `await`-able
mutations:

```dart
final list = TissueList.of([1, 2, 3]);
await list.async.add(4);
await list.async.remove(1);

final queue = TissueQueue<int>();
await queue.async.add(42);
```

`async` operations are serialized through the tissue's lock, so they're safe
from any async context (network callbacks, isolate messages, UI event
handlers) on the same isolate.

---

## The Flow + Tissue Seam

`cell_tissue` is the *book* half of a two-subsystem pattern that the
`/example` demos teach:

> **Flow decides. Tissue records. The observer is the only glue.**

- **Flow** (`cell_flow`) transforms a domain tick into a decision
  (`DECLINE` / `DISPATCH` / `SHED` / `add 3`).
- **Tissue** (`cell_tissue`) records the decision in a governed book
  (append-only log, non-negative balance, open-hold map, outbound queue).
- A `Cell.observe` on the **gate cell** is the only channel between the
  two subsystems.

```dart
// Flow owns the decision
final gate = MapValue<Tick, Decision>((t) => policyOf(t, policySet))
    + _distinct()
    + Filter<Decision>((d) => d == Decision.fire);

final gateCell = gate.toHandle(source: tickIn.cell).cell;

// Tissue records the decision
Cell.observe(
  source: gateCell,
  effect: (Pulse pulse) {
    if (pulse.payload == Decision.fire) {
      ledger.add(LedgerEntry(...));
      outboundQ.addLast(Job(...));
      // ... move money / drivers / megawatts
    }
  },
);
```

**Two locks, two owners.** The Receptor lock on the gate covers the pure
policy, the Distinct latch, and the Filter. The Tissue lock on each
collection covers the actual mutation. A decision pulse crosses the two
domains **sequentially**, never simultaneously. That sequencing is what
lets the policy be unit-tested with a bare domain object and no Tissue
at all.

**Distinct-before-Filter.** The Distinct latch runs before the Filter so
the latch records every decision the pipeline made — including `hold` /
`approve` / `idle`. This is what makes `hold → fire → hold → fire` fire
twice.

**ACK resets, not rebuilds.** ACK clears the Distinct latches via
`resetDistinct()` without calling `toHandle` again. A second `toHandle`
would double every downstream effect.

For the full pattern, see the four sibling demos in [`/example`](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example)
and the per-demo `*-ARCHITECTURE.md` companions.

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                        Tissue<E>                           │
│  ── Public API (Iterable, List, Set, Map, Queue, Value)    │
└───────────────────────┬────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────┐
│                    TissueBase<E, I, C>                     │
│  ── Reactive engine: constructor, deputy, equality         │
└───────────────────────┬────────────────────────────────────┘
                        │
        ┌───────────────┼─────────────────┐
        ▼               ▼                 ▼
┌─────────────────┐ ┌───────────────┐ ┌─────────────────────┐
│ TissueNucleus   │ │TissueContainer│ │ TissueReceptor      │
│  (DNA/blueprint)│ │(physical      │ │ (mutation pipeline) │
│  receptor,      │ │ storage +     │ │                     │
│  testRule,      │ │ linking)      │ │                     │
│  context,       │ │               │ │                     │
│  synapses       │ │               │ │                     │
└─────────────────┘ └───────────────┘ └─────────────────────┘
                        │
                        ▼
             ┌───────────────────────┐
             │ TissuePulse<E>        │
             │  (event emitted on    │
             │   every mutation)     │
             └───────────────────────┘
```

**Lifecycle of a mutation:**

1. `list.add(42)` calls `apply(add, positionalArguments: [42])`.
2. `apply` consults `modifiable` — if the function isn't whitelisted,
   the call is rejected.
3. The `TestTissue` gate validates the action and the element.
4. The receptor runs its pipeline (`preProcess → rule → postProcess`).
5. The container mutates atomically under the tissue's `Lock`.
6. Any `Cell` elements are automatically linked/unlinked via `Synapses`.
7. A `TissuePulse` classified with `Tissue.elementAdded` (or
   `Tissue.elementRemoved`) is emitted.
8. The pulse propagates through the tissue's `Synapses` to downstream
   observers.

For the full design intent, see [`ARCHITECTURE-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/ARCHITECTURE-Tissue.md).

---

## API Reference

### Factories

| Factory | Purpose |
|---------|---------|
| `Tissue(elements)` | Create a generic tissue. |
| `Tissue.empty(...)` | Create an empty tissue (or `TissueNever`). |
| `Tissue.governed(elements, ...)` | Explicit governance & lifecycle policy. |
| `Tissue.fromNucleus(nucleus, ...)` | Hydrate from a pre-built blueprint. |
| `Tissue.unmodifiable(source, ...)` | Live read-only projection. |
| `TissueList(...)` / `.of(...)` / `.fromNucleus(...)` / `.unmodifiable(...)` | List-specific. |
| `TissueSet(...)` / `.of(...)` / `.empty(...)` / `.identity(...)` | Set-specific. |
| `TissueMap(...)` / `.from(...)` / `.fromEntries(...)` / `.identity(...)` | Map-specific. |
| `TissueQueue(...)` / `.of(...)` | Queue-specific. |
| `TissueValue(...)` / `.empty(...)` | Value-specific. |

### Core Members

| Member | Description |
|--------|-------------|
| `deputy(...)` | Create a restricted proxy (read-only, scoped, ephemeral). |
| `unmodifiable` | Get a live read-only view. |
| `async` | Get an async wrapper for non-blocking mutations. |
| `validate` | The active `TestTissue` rule. |
| `context` | The authority tier and domain. |
| `modifiable` | The whitelist of functions allowed via `apply`. |
| `apply(fn, ...)` | The command-pattern gateway. |
| `isTerminal` | `true` if the tissue doesn't broadcast. |
| `isInvalidated` | `true` if reclaimed by `EphemeralPolicy`. |
| `isGoverned` | `true` if a non-default context is attached. |

### Related Types

- `TestTissue<E, C>` — validation gate.
- `TissueReceptor<E, C>` — mutation pipeline.
- `TissuePulse<E>` — base event type.
- `TissueEvent` / `CompositeTissueEvent` — event classification flags.
- `TissueNucleus<E>` — immutable blueprint.
- `TissueContainer<E, I>` — physical storage mediator.
- `Container` — strategy object (List, Set, Map, Queue, Value, …).

---

## Best Practices

### ✅ Do

- **Use `.unmodifiable` for sharing with UI.** It's zero-copy, live, and
  safe.
- **Use `.deputy(...)` for scoped authority.** Read-only, temporary, or
  restricted views.
- **Attach a `testRule` to enforce invariants.** Positive integers, valid
  emails, max length, etc.
- **Use `TissueSet.identity` for mutable keys.** Prevent subtle bugs when
  keys change.
- **Use `TissueQueue(capacity: n)` for bounded buffers.** Backpressure for
  free.
- **Await `.async` operations from async contexts.** Avoid blocking the UI.
- **Use an append-only `TestTissue` for audit logs.** The log is the
  forensic record; a removable row would break the trace.
- **Consult `modifiable` before dispatching a verb.** The manifest is the
  collection's public contract.

### ❌ Don't

- **Don't expect an event for initial population.** Only post-construction
  mutations emit pulses.
- **Don't hold direct references to elements that should be immutable.**
  Use `unmodifiableElement: true`.
- **Don't share a mutable deputy with untrusted code.** Use
  `TestTissue.readOnly`.
- **Don't rely on element order in a `Set`.** It's unspecified.
- **Don't pass a `TestCell` to a Tissue constructor.** They are not
  subtypes.
- **Don't fold Tissue into Flow.** `ledger.add(...)` inside a `MapValue`
  hides the lock and makes the policy untestable.
- **Don't fold Flow into Tissue.** `interpreter.complete(...)` inside a
  `TestTissue` rule makes the rule I/O-bound and non-deterministic.
- **Don't call `toHandle` from an ACK observer.** It doubles every
  downstream effect.
- **Don't write `available` / `held` / `reserveMw` outside the money
  method.** The invariant breaks.

---

## Example Demos

Four end-to-end demos live under [`/example`](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue/example). A minimal, runnable quick start is available at [`example/cell_tissue_example.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/cell_tissue_example.dart). Each demo is a
complete, runnable illustration of the Flow + Tissue seam with a different
domain:

| Demo | Domain | What it teaches |
|------|--------|-----------------|
| [`card-auth-pipeline(tissue)-Demo.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/card-auth-pipeline(tissue)-Demo.dart) | Payments | Authorize, hold, capture, void — with the money invariant `available + held + captured == 250000`. |
| [`ride-hail-dispatch(tissue)-Demo.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/ride-hail-dispatch(tissue)-Demo.dart) | Mobility | Match a rider to a driver, hold a surge banner, keep an auditable trip log. |
| [`grid-demand-response(tissue)-Demo.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/grid-demand-response(tissue)-Demo.dart) | Energy | Shed interruptible load, protect hospital feeders, restore after the shift-lead ACK. |
| [`nl-instruction-tissue-set-Demo.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/example/nl-instruction-tissue-set-Demo.dart) | Command surface | Translate a natural-language sentence into a verb, then dispatch it against a governed `TissueSet<int>`. |

Each demo ships with three companions:

| Document | Purpose |
|----------|---------|
| `*-WalkThrough.md` | The requirement document and scenario contract. |
| `*-FEATURES.md` | The operator catalogue and feature index. |
| `*-ARCHITECTURE.md` | The layering, ownership, locking, and failure-semantics note. |

See [`DEMO_GUIDE-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/DEMO_GUIDE-Tissue.md) for a progressive walk-through of
the demos, or read the demos themselves in this order:

1. Skim the class doc.
2. Read the pure policy (`riskOf` / `matchOf` / `actionOf`).
3. Read the gate installation (`installGates`).
4. Trace one decision from ingress to the Tissue write.

---

## Status & Known Gaps

**Stable on pub.dev** (`1.0.0`, shipped with `cell` `1.1.0`, `cell_flow` `1.0.0`, and `mitosis` `2.2.0`). See
[CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/CHANGELOG.md).

- `example/` ships four demos; `test/` passes **362/362** tests.
- Some dartdoc snippets are stale — use `TissueList.of([...])` rather than
  `TissueList([...])`, and observe with `Cell.observe` rather than
  `tissue.listen`.
- `TissueMap` puts `testRule` on the `TissueMapNucleus` via `properties:`.
- `addAll` skips invalid elements silently — count before/after or log in
  a custom `TestTissue` if you need visibility.
- `TissueQueue` overflow drops the oldest element with no dedicated event
  distinct from a normal remove.
- `TissueQueue.removeFirst` / `remove` may not drain the container in some
  builds.
- `Cell.observe` on a Tissue cell may be silent in some builds; emit trace
  prints from the writer.
- Joint commits across multiple tissues are staged through
  `ApplyTransactionScope.enqueueCommand` (`Cell.txApply`); the example demos
  predate the bridge and use a v1 compensation ladder.

If you rely on a guarantee here, verify it against the current source and
the header of the demo that exercises it. See
[`ARCHITECTURE-Tissue.md § Current status`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/ARCHITECTURE-Tissue.md#9-current-status-and-known-gaps)
for the full list.

---

## Testing

The package includes a test suite covering the public API surface, edge
cases, and the mutation/observation lifecycle.

```bash
dart test
```

For coverage:

```bash
dart test --coverage=coverage
dart pub global activate coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Related Packages

- **`cell`** — the core reactive framework (`Cell`, `Pulse`, `Receptor`,
  `Synapses`, `TestCell`). `cell_tissue` re-exports `cell` for convenience.
- **`cell_flow`** — instruction-layer `Flow` factories for complex stream
  orchestration. Pairs with `cell_tissue` for the Flow + Tissue seam.

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository and create a topic branch.
2. Run `dart analyze` and `dart test` locally.
3. Add tests for new behavior.
4. Submit a pull request with a clear description.

See `CONTRIBUTING.md` for details.

---

## License

Released under the terms of either:

- **MIT License**
- **Apache License 2.0**

See [LICENSE](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/LICENSE) for the full text.

---

## Author

**Lee Man Hoi Simon** — see [AUTHORS](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/AUTHORS) for details.

---

*`cell_tissue` is part of the Cell Framework — a reactive, governable,
connective substrate for building resilient Dart applications.*