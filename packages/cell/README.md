# cell

## Install and import

```bash
dart pub add cell cell_flow cell_tissue
```

```dart
import 'package:cell/cell.dart';                 // Cell layer only
import 'package:cell_flow/cell_flow.dart';       // re-exports package:cell
import 'package:cell_tissue/cell_tissue.dart';
```

## AI agents start here

Read this before opening any other page.

`cell` is designed with AI coding agents in mind. Every top public symbol
carries a machine-readable `### AI Agent Guide` block, and the surfaces below
let an agent reliably pick the right factory and generate code that compiles
against the live API.

1. **Version pin:** `cell 1.1.0`, `cell_flow 1.0.0`, `cell_tissue 1.0.0`.
2. **Preflight:** `dart run tool/ai_preflight.dart` — prints the resolved versions and any stale pins.
3. **API chooser:** `lib/doc/api_chooser.dart` (generated from the `### AI Agent Guide` doc blocks).
4. **Layer guides:**
    - `guide/HowTo-Mitose-Cell.md` — Cell factory choices
    - `guide/HowTo-Mitose-Flow.md` — Flow operator choices
    - `guide/HowTo-Mitose-Tissue.md` — Tissue collection choices
5. **The seam sentence:** *The instruction decides, the chain assembles, the observer glues.*

## If you have a BRD sentence that says…

| BRD sentence | First factory | Do NOT |
|---|---|---|
| "capture X" / "record X entering" | `Cell.ingress` | create a custom Cell |
| "record every Y" (history) | `Cell.observe` + `TissueList` | put in instruction |
| "reserve N units" | `TissueValue` + invariant | use `Cell.state<int>` |
| "flag when Y happens" | `FlowInstructionBase` subclass in Flow | put in `Cell.observe` |
| "two facts move together" | `Cell.txApply` on Tissue | `Cell.transaction` |
| "wait for silence" | `Debounce` in `cell_flow` | roll your own `Timer` |

(The full matrix lives in `lib/doc/api_chooser.dart`; this is the 6-row elevator version.)

---

> **Reactive State for Dart** — transaction-ready, observable, validated,
> synchronized, auditable, and zero-copy deputy-able cells, pulses, and
> operators. Plain Dart state, plus a governance contract.

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell/LICENSE)
[![Version](https://img.shields.io/badge/cell-1.1.0-blue.svg)](#status)
[![Status](https://img.shields.io/badge/Status-Stable-green.svg)](#status)

This is the foundation package of the Cell Framework (Mitosis). Sibling packages add collections, relations, stream combinators, persistence, and codegen.

> **Mitose pipeline — the umbrella feature.** The root repository ships an AI-executable pipeline that turns a business requirement into a working Cell + Flow + Tissue solution with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. An AI prompt agent follows [`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md); this package supplies the **Cell layer** rules via [`guide/HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md). See the [root README](https://github.com/simon-m-lee/cell#readme).

---

## Overview

A **cell** holds a value or relays a signal. A **pulse** is the immutable
message that moves a change. Operators (`Cell.state`, `Cell.observe`, …) wire
cells together into a reactive graph — and that graph is governed:

- **Transaction ready, built into the foundation** — `Cell.txApply` (staged
  commands with Saga compensation and rollback) and `Cell.transaction`
  (buffered multi-cell atomic commits) are core factories of the `cell`
  package itself — an integral part of the reactive graph, not an add-on
  layer. Every mutation request is a first-class, auditable command
  (`apply` + `ApplyCommand` → sealed `ApplyOutcome`). Plain Dart state —
  and most reactive frameworks — have no equivalent: a multi-step update
  that throws halfway through leaves permanent, partial state; here it
  rolls back through recorded compensation.
- **Observable** — every change emits a typed `Pulse` that downstream cells
  react to; plain Dart requires hand-rolled listener or `Stream` plumbing.
- **Validated** — a `TestCell` gate runs on every write, so validation is
  enforced by the framework instead of being an `if` you remember to call.
- **Deputy-able** — hand out zero-copy read-only views (`.unmodifiable`) or
  restricted proxies (`.deputy()`); a deputy *is* the principal
  (`cell == cell.deputy()` is `true`) and its rules can only narrow what the
  principal already allows.
- **Auditable** — `ApplyReceipt` forensics, causal trace, and provenance
  metadata ride every pulse; `Cell.sanitized` redacts before egress.
- **Synchronized** — transactional writes serialize through the ledger, and
  governed cells carry synchronization locks for high-integrity paths.
- **Timing control** — `debounce`, `throttle`, and `distinct` are
  library behavior, not ad-hoc `Timer`s.
- **Composable** — 16 core operators cover state, events, projection,
  fan-in, async mapping (`asyncMap` with concurrency control), routing
  (`hub`), and switching (`switchMap`); `fromFuture` / `fromStream` bridge
  `dart:async`.
- **Extensible** — `Receptor` / `Instruction` transform pipelines,
  `Synapses` + `PropagationPolicy` control delivery, `Context` carries
  authority, and `Nucleus` / `Cell.governed` unlock high-integrity nodes.

Where plain Dart gives you a field, `cell` gives you a field **with a
governance contract**:

| Capability | Plain Dart (`setState` / `ValueNotifier` / `Stream`) | `cell` |
|---|---|---|
| Change notification | Manual listener or stream wiring | Built-in pulse graph — every change emits |
| **Transactions** | None — failures leave partial state | Built-in `Cell.transaction` / `Cell.txApply`: commands with compensation, atomic staging, and rollback |
| Validation | Manual `if` checks at call sites | `TestCell` gate on every write |
| Restricted views | None, or copying the data | Zero-copy `unmodifiable` / `deputy` proxies |
| Audit trail | None | `ApplyReceipt`, causal trace, provenance |
| Timing operators | Hand-rolled `Timer`s | `debounce` / `throttle` / `distinct` |
| Async combinators | Hand-rolled `Future`/`Stream` plumbing | `asyncMap` (concurrency/latest/exhaust), `switchMap`, `fromFuture`/`fromStream` |
| Multi-source aggregation | Manual bookkeeping | `Cell.synthesis` fan-in |

> **Transaction ready, in one breath:**
>
> ```dart
> final counter = Cell.state<int>(initial: 0);
>
> // One audited, compensable command:
> final outcome = await counter.cell.command(increment)
>     .args([5])
>     .undo(decrement, args: [5])
>     .run(); // ApplyAccepted with a receipt — or ApplyRejected, never a throw
>
> // Stage commands with recorded compensation inside a transaction ledger:
> final tx = Cell.txApply();
> await tx.execute(participants: [counter.cell], body: (scope) {
>   counter.cell.apply<dynamic>(
>     (
>       function: increment,
>       arguments: (positionalArguments: [5], namedArguments: null),
>       compensation: (
>         function: decrement,
>         arguments: (positionalArguments: [5], namedArguments: null),
>         cell: counter.cell,
>       ),
>     ),
>     tx: scope,
>   ); // buffered — invisible to readers until the transaction commits
> });
>
> // Or buffer several cells into one atomic commit:
> final tx2 = Cell.transaction();
> await tx2.begin([counter.cell, settings.cell]);
> tx2.update(counter.cell, 5);      // buffered
> tx2.update(settings.cell, theme); // buffered
> await tx2.commit();               // both land together — or neither does
> ```

Defaults are pass-through and allow-all — you can ship a counter without
learning `Nucleus`. Validation, deputies, provenance, and timing control are
available when you need them.

## Table of Contents

- [Overview](#overview)
- [What's new in 1.1](#whats-new-in-11)
- [When it fits](#when-it-fits)
- [Install](#install)
- [Quick example](#quick-example)
- [Core operators](#core-operators)
- [How much you need to know](#how-much-you-need-to-know)
- [Documentation](#documentation)
- [Ecosystem](#ecosystem)
- [Status](#status)
- [License](#license)

## What's new in 1.1

Two headline changes shipped with the stable release.

### Forensic `Cell.apply`

Every mutation request is now a first-class, auditable command — not a bag of positional parameters.

```dart
final outcome = await userCell.command(updateProfile)
    .args(['Simon'])
    .named({#active: true})
    .undo(updateProfile, args: ['Original Name'])
    .run();

switch (outcome) {
  case ApplyAccepted(result: final user):
    print('Update successful: ${user.name}');
  case ApplyRejected(reason: final error):
    print('Safety gate blocked the change: $error');
  case ApplyStaged():
    print('Staged in the transaction ledger');
}
```

`apply<R>(ApplyCommand, {tx})` is the only gateway: sealed `ApplyOutcome<R>` results, `ApplyReceipt` forensics, the `cell.command(...)` builder DSL, vetted/trusted `modifiable` whitelists, and Saga compensation through `Cell.txApply` — with validation running through the deputy's full `testRule` chain. The complete list is in [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CHANGELOG.md).

### Performance

Six optimization phases, tracked by a committed benchmark suite with a regression gate ([`benchmark/`](https://github.com/simon-m-lee/cell/tree/master/packages/cell/benchmark)):

| Shape | Before | 1.1.0 |
|---|---|---|
| Single-hop emit (`ingress` → observer) | ~170 µs | **~5–6 µs** (~30×) |
| `Cell.distinct`, duplicate-heavy | ~1.7 ms | **~8 µs** (~210×) |
| Chain depth 50 | ~8.3 s (exponential) | **~12.7 ms** (linear) |
| `Cell()` construction | ~3.7 µs | **~2.1 µs** |
| `Cell()` heap footprint | ~2.7 KB | **~1.1 KB** |

Run `dart run benchmark/runner.dart --out current.json` and compare against `benchmark/baseline.json`; the honest comparison story is feature-accounted in [benchmark/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/benchmark/README.md).

---

## When it fits

Cell is a good match if you want:

- Persistent reactive state with an explicit update path
- Events (clicks, sockets, sensors) entering the same graph as state
- Validation that is a gate, not a callback you remember to call
- Restricted views of the same data without copying it (`deputy`, `unmodifiable`)
- Multi-cell commits (`transaction`) or staged commands with undo (`txApply`)
- Debounce / throttle as library behavior rather than ad-hoc `Timer`s

It is more machinery than you need for a couple of flags, a basic form, or a single `Future`. For Rx-style combinators (`merge`, `zip`, `scan`, windows), use **cell_flow**.

---

## Install

The package is on pub.dev. From this monorepo:

```yaml
dependencies:
  cell: ^1.1.0   # stable
```

From git:

```yaml
dependencies:
  cell:
    git:
      url: https://github.com/simon-m-lee/cell.git
      path: packages/cell
```

Requires Dart `>=3.5.0 <4.0.0`.

```dart
import 'package:cell/cell.dart';
```

---

## Quick example

```dart
import 'package:cell/cell.dart';

void main() {
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse((host.value ?? 0) + delta);
    },
  );

  final observer = Cell.observe(
    source: counter.cell,
    effect: (Pulse pulse) => print('Counter: ${pulse.payload}'),
  );

  counter.update(5); // prints: Counter: 5
  observer.stop();
}
```

`evolve` returning `null` rejects the update. Omit `evolve` to treat `update` as a direct assignment.

Runnable demos live in [`example/`](https://github.com/simon-m-lee/cell/tree/master/packages/cell/example). Start with `example/state_demo.dart`.

---

## Core operators

You can build most application graphs from these factories. None of them require configuring `Receptor`, `TestCell`, `Context`, or `Synapses`.

| | Factory | Use when |
|---|---------|----------|
| 1 | `Cell.state` | Persistent mutable state |
| 2 | `Cell.ingress` | Manual `emit` / `ingest` of external events |
| 3 | `Cell.observe` | Side effects; `start` / `stop` |
| 4 | `Cell.derive` | Pure projection of one source |
| 5 | `Cell.debounce` | Emit after a silence window |
| 6 | `Cell.distinct` | Skip equal consecutive payloads |
| 7 | `Cell.throttle` | Cap emission frequency |
| 8 | `Cell.synthesis` | Aggregate several sources |
| 9 | `Cell.asyncMap` | Map each value to a `Future` (`concurrency`, `latestOnly`, `exhaust`) |
| 10 | `Cell.hub` | Route by `Pulse.type` |
| 11 | `Cell.switchMap` | Follow the latest inner cell |
| 12 | `Cell.fromFuture` / `Cell.fromStream` | Bridge `dart:async` |
| 13 | `Cell.sanitized` | Redact before egress |
| 14 | `Cell.open` | Manual topology (`emit` / `link`) |
| 15 | `Cell.transaction` | Multi-cell buffered writes |
| 16 | `Cell.txApply` | Staged `apply` + compensation |

Also implemented, outside that numbered set: **`Cell.valve`** (predicate gate) and **`Cell.apply` / `cell.command(...)`** (audited mutations with receipts and Saga compensation). Fan-in of several sources is `Cell.synthesis` (or combinators in cell_flow).

Learning order: get data in → hold state → react → shape streams → go async → combine → isolate writes. Operators 1–4 are enough for a first app.

---

## How much you need to know

Layers are optional, not a reading list.

1. **Operators** — intended default for application code.
2. **Pipelines and propagation** — custom `Receptor` / `Instruction`, and `Synapses` + `PropagationPolicy`, when a factory’s default is not enough.
3. **Validation and authority** — `TestCell` and `Context`. Off by default (`TestCell.allowAll`, `Context.system`).
4. **Internals** — `Nucleus`, `Cell.governed`, `Cell.fromNucleus`, lifecycle policies. For extending the framework or high-integrity nodes.

A deputy is a proxy, not a copy: `cell == cell.deputy()` is true. Rules on a deputy can only **narrow** what the principal already allows.

See [ARCHITECTURE.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/ARCHITECTURE.md) for the design rationale.

---

## Documentation

| Document | What it is |
|----------|------------|
| [HowTo-Start.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Start.md) | Walkthrough of the core concepts |
| [HowTo-16_Essential_Operators.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-16_Essential_Operators.md) | Operator reference and learning path |
| [FEATURES.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/FEATURES.md) | Source-checked feature catalog |
| [ARCHITECTURE.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/ARCHITECTURE.md) | Why the pieces are shaped this way |
| [TEST_VERIFICATION.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/TEST_VERIFICATION.md) | Unit-test inventory, measured coverage, and how to run the suite |
| [HowTo-TestCell.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-TestCell.md) | Validation rules |
| [HowTo-Synapses.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Synapses.md) | Linking, filters, propagation |
| [HowTo-Receptor.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Receptor.md) | Transformation pipelines |
| [HowTo-Instruction.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Instruction.md) | Instruction stages |
| [HowTo-Transaction.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Transaction.md) | Buffered multi-cell writes |
| [HowTo-TransactionOnApply.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-TransactionOnApply.md) | Staged `apply` + compensation |
| [HowTo-Advanced.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Advanced.md) | Index of optional governance machinery |
| [benchmark/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/benchmark/README.md) | Benchmark suite, pass criteria, and the feature-accounted comparison story |

Guides use `HowTo-*.md` (hyphens). Generate API docs with `dart doc .` and open `doc/api/index.html`.

If a guide and the source disagree, **the source is current**.

---

## Ecosystem

| Package | Delivery | Adds                                                                                          |
|---------|----------|-----------------------------------------------------------------------------------------------|
| **cell** (this) | Now      | Nodes, pulses, operators, governance, transactions                                            |
| **cell_flow** | Now      | 100+ instruction factories on `Flow`, plus fluent chaining (`mapTo`, `asyncExpand`, `zip`, …) |
| **cell_tissue** | Now      | Reactive collections (list / map / set / queue)                                               |

Flutter has no dedicated widgets here. Bind with `Cell.observe` (or an adapter) and drive `setState` or your existing state library.

---

## Status

**Stable on pub.dev** (`1.1.0`). Public APIs for cells, pulses, operators, transactions, and the integrity-gated `apply`/`txApply` command model are exercised by a passing unit-test suite.

Release verification:

- `cell` **1174/1174**, `cell_flow` **1091/1091**, `cell_tissue` **362/362** unit tests pass.
- `dart analyze lib` reports **no issues**; the test files carry a few pre-existing informational lints.
- `dart doc .` completes with **zero warnings**; `doc/api` is generated.
- The benchmark suite's 60 tracked results pass the 15% regression gate (`benchmark/compare.dart`).
- `Context`, `PulseContext`, and `Sensitivity` let you *attach* classification, actor, and purpose. They do not implement or certify GDPR, HIPAA, PCI-DSS, or any other regulation. `Context.describe('…')` stores text; it is not a legal basis or an audit log.

Feedback and issues are useful at this stage.

```bash
dart analyze lib
dart test
dart format .
dart doc .
```

---

## License

MIT or Apache-2.0. See [LICENSE](https://github.com/simon-m-lee/cell/blob/master/packages/cell/LICENSE).

## Authors

Lee Man Hoi Simon. See [AUTHORS](https://github.com/simon-m-lee/cell/blob/master/packages/cell/AUTHORS) for copyright holders.
