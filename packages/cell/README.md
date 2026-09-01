# cell

Reactive state for Dart. A **cell** holds a value or relays a signal. A **pulse** is the immutable message that moves a change. Operators (`Cell.state`, `Cell.observe`, …) wire cells together.

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Mitosis-1.0.0--rc.1-blue.svg)](#status)
[![Status](https://img.shields.io/badge/Status-RC-yellow.svg)](#status)

Validation, deputies, provenance, and timing control are available when you need them. Defaults are pass-through and allow-all — you can ship a counter without learning `Nucleus`.

This is the foundation package of the Cell Framework (Mitosis). Sibling packages add collections, relations, stream combinators, persistence, and codegen.

---

## When it fits

Cell is a good match if you want:

- Persistent reactive state with an explicit update path
- Events (clicks, sockets, sensors) entering the same graph as state
- Validation that is a gate, not a callback you remember to call
- Restricted views of the same data without copying it (`deputy`, `unmodifiable`)
- Multi-cell commits (`transaction`) or staged commands with undo (`txApply`)
- Debounce / throttle / batch as library behavior rather than ad-hoc `Timer`s

It is more machinery than you need for a couple of flags, a basic form, or a single `Future`. For Rx-style combinators (`merge`, `zip`, `scan`, windows), use **cell_flow**.

---

## Install

The package is not on pub.dev. From this monorepo:

```yaml
dependencies:
  cell:
    path: packages/cell
```

From git:

```yaml
dependencies:
  cell:
    git:
      url: https://github.com/simon-m-lee/Cell-Framework-Mitosis.git
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
      return Pulse(host.value + delta);
    },
  );

  final observer = Cell.observe(
    source: counter.cell,
    effect: (pulse) => print('Counter: ${pulse.payload}'),
  );

  counter.update(5); // prints: Counter: 5
  observer.stop();
}
```

`evolve` returning `null` rejects the update. Omit `evolve` to treat `update` as a direct assignment.

Runnable demos live in [`example/`](example/). Start with `example/state_demo.dart`.

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

Also implemented, outside that numbered set: **`Cell.valve`** (predicate gate). Fan-in of several sources is `Cell.synthesis` (or combinators in cell_flow).

Learning order: get data in → hold state → react → shape streams → go async → combine → isolate writes. Operators 1–4 are enough for a first app.

---

## How much you need to know

Layers are optional, not a reading list.

1. **Operators** — intended default for application code.
2. **Pipelines and propagation** — custom `Receptor` / `Instruction`, and `Synapses` + `PropagationPolicy`, when a factory’s default is not enough.
3. **Validation and authority** — `TestCell` and `Context`. Off by default (`TestCell.allowAll`, `Context.system`).
4. **Internals** — `Nucleus`, `Cell.governed`, `Cell.fromNucleus`, lifecycle policies. For extending the framework or high-integrity nodes.

A deputy is a proxy, not a copy: `cell == cell.deputy()` is true. Rules on a deputy can only **narrow** what the principal already allows.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design rationale.

---

## Documentation

| Document | What it is |
|----------|------------|
| [HowTo-Start.md](guide/HowTo-Start.md) | Walkthrough of the core concepts |
| [HowTo-16_Essential_Operators.md](guide/HowTo-16_Essential_Operators.md) | Operator reference and learning path |
| [FEATURES.md](FEATURES.md) | Source-checked feature catalog |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Why the pieces are shaped this way |
| [TEST_VERIFICATION.md](TEST_VERIFICATION.md) | Unit-test inventory, measured coverage, and how to run the suite |
| [HowTo-TestCell.md](guide/HowTo-TestCell.md) | Validation rules |
| [HowTo-Synapses.md](guide/HowTo-Synapses.md) | Linking, filters, propagation |
| [HowTo-Receptor.md](guide/HowTo-Receptor.md) | Transformation pipelines |
| [HowTo-Instruction.md](guide/HowTo-Instruction.md) | Instruction stages |
| [HowTo-Transaction.md](guide/HowTo-Transaction.md) | Buffered multi-cell writes |
| [HowTo-TransactionOnApply.md](guide/HowTo-TransactionOnApply.md) | Staged `apply` + compensation |
| [HowTo-Advanced.md](guide/HowTo-Advanced.md) | Index of optional governance machinery |

Guides use `HowTo-*.md` (hyphens). Generate API docs with `dart doc .` and open `doc/api/index.html`.

If a guide and the source disagree, **the source is current**.

---

## Ecosystem

| Package | Delivery | Adds |
|---------|----------|------|
| **cell** (this) | Now      | Nodes, pulses, operators, governance, transactions |
| **cell_tissue** | Sept 26  | Reactive collections (list / map / set / queue) |
| **cell_organ** | Sept 26    | Relatable models (one / many, cascade, blend) |
| **cell_flow** | Sept 26  | 79 instruction factories on `Flow`, plus fluent chaining (`mapTo`, `asyncExpand`, `zip`, …) |
| **cell_memory** | TBD      | Persistence and storage adapters |
| **cell_ontogeny** | Sept 26  | Code generation |

Flutter has no dedicated widgets here. Bind with `Cell.observe` (or an adapter) and drive `setState` or your existing state library.

---

## Status

**RC** (Mitosis `1.0.0-rc.1`, Release Candidate). Public APIs for cells, pulses, operators, and transactions are exercised by a passing unit-test suite. Breaking changes remain possible before a versioned 1.0 stable.

A fuller developer list is in [KNOWN_ISSUES.md](KNOWN_ISSUES.md). Known limits, so this page does not over-promise:

- Not published to pub.dev. No independent security or correctness audit.
- `Context`, `PulseContext`, and `Sensitivity` let you *attach* classification, actor, and purpose. They do not implement or certify GDPR, HIPAA, PCI-DSS, or any other regulation. `Context.describe('…')` stores text; it is not a legal basis or an audit log.

Feedback and issues are useful at this stage.

```bash
dart analyze lib
# Files are test_*.dart — bare `dart test` finds nothing. See TEST_VERIFICATION.md.
dart test @(Get-ChildItem test/test_*.dart | ForEach-Object { "test/$($_.Name)" })
dart format .
dart doc .
```

---

## License

MIT or Apache-2.0. See [LICENSE](LICENSE).

## Authors

Lee Man Hoi Simon. See [AUTHORS](AUTHORS) for copyright holders.
