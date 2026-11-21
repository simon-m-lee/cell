# The fair comparison: Cell vs Riverpod, BLoC, Provider, GetX, and Signals

> This page compares Cell to the most widely-used Flutter state management
> packages. It is written by the Cell maintainers, so treat it with the
> skepticism any first-party comparison deserves. Every row is checked
> against each package's current documentation. Where Cell loses, the row
> says so. The decision tree at the end tells you when *not* to use Cell.

**Legend:** 🟢 Cell wins on this row · ⚪ neutral / tie · 🔴 Cell loses on
this row. Cell loses on five of the ten rows — on purpose. The five rows it
wins are its reason to exist.

**Last verified:** 2026-11-17, against each package's pub.dev page and
documentation (sources cited below the matrix).

## The comparison matrix

| Dimension | Cell | Riverpod | BLoC | Provider | GetX | Signals | Winner |
|---|---|---|---|---|---|---|---|
| **Learning curve** | High — new concepts (cells, pulses, gates) [1] | Moderate [2] | Moderate [3] | Low [4] | Low [5] | Moderate [6] | 🔴 |
| **Codegen support** | None — everything hand-written [1] | Mature (`riverpod_generator` 4.x) [2] | Optional (`freezed` ecosystem) [3] | None [4] | None [5] | None [6] | 🔴 |
| **DevTools integration** | New — `cell_flutter_devtools` 0.1 (ledger timeline) [7] | Mature (provider graph, state inspection, overrides) [2] | Mature (`BlocObserver`, browser extension) [3] | None official [4] | Minimal (community tooling) [5] | Minimal [6] | 🔴 |
| **Community size** | Small [8] | Large [8] | Large [8] | Large [8] | Large [8] | Small [8] | 🔴 |
| **Compile-time safety** | Partial — runtime-checked state [1] | Strong — codegen + lint rules [2] | Moderate — convention + `freezed` [3] | Weak [4] | Weak [5] | Strong — compile-time derivation [6] | 🔴 |
| **Async state** | `CellAsyncBuilder` / `asyncMap` [9] | `AsyncValue` [2] | Manual (events into states) [3] | `FutureBuilder` by hand [4] | `Obx` + reactive getters [5] | Derived signals [6] | ⚪ |
| **Audit trail (built-in)** | **Yes** — `ApplyLedger` receipts for every `Cell.apply` [10] | No | No (convention only) | No | No | No | 🟢 |
| **Multi-cell atomic commits with rollback** | **Yes** — `Cell.txApply` with compensations [11] | No | No | No | No | No | 🟢 |
| **Restricted views (zero-copy)** | **Yes** — `unmodifiable` / `deputy` [12] | `select` only [2] | No | `Selector` (slice rebuilds, not capability restriction) [4] | No | No | 🟢 |
| **Governance gates** | **Yes** — `TestCell` gates enforce before every mutation [13] | Convention | Convention | No | No | No | 🟢 |

Community size uses pub.dev like counts as a *proxy* on 2026-11-17 —
imperfect, but honest and checkable. Read that row as "order of
magnitude", not a census.

## What each package is for

- **Riverpod:** "For most Flutter apps. Compile-time safety, mature
  codegen, excellent async, and a large ecosystem. The default choice for
  a new Flutter project in 2026."
- **BLoC:** "For teams that need auditable event flows and strict
  architectural discipline. Events and states are first-class; the
  boilerplate is the price."
- **Provider:** "For small apps and legacy codebases. The simplest option;
  the community has largely moved to Riverpod."
- **GetX:** "For rapid prototyping. Low boilerplate; weaker type safety.
  The package is still maintained (last release 2025-11) but has a
  history of community maintenance concerns — check the issue tracker
  before adopting."
- **Signals:** "For apps where raw performance is the primary constraint.
  Compile-time-optimized; smaller community."
- **Cell:** "For apps where state must be **auditable, reversible, and
  governed** — regulated industries, multi-step operations with rollback,
  and AI-agent-mutated state. Use Cell when Riverpod or BLoC cannot give
  you the guarantees you need."

## The decision tree

```
Do you need an audit trail of every state change?
├── Yes → Cell
└── No
    Do you need atomic multi-cell commits with rollback?
    ├── Yes → Cell
    └── No
        Do you need restricted views (read-only, deputy) of the same state?
        ├── Yes → Cell
        └── No
            Are you on a team that needs strict event/state architecture?
            ├── Yes → BLoC
            └── No
                Do you need compile-time safety and codegen?
                ├── Yes → Riverpod
                └── No
                    Provider (or setState for the simplest cases)
```

Answer "No" to the first three questions and the tree is telling you not
to use Cell — that is the tree working as intended. (GetX and Signals are
deliberately absent from the tree: they fit "rapid prototyping" and
"raw performance" niches, which are rarely the deciding axis once the
questions above have been answered.)

## What Cell does not do

- **No code generation.** Every cell is written by hand.
- **No mature DevTools extension.** The 0.1 extension shows the ledger;
  it does not have the full inspection tools Riverpod provides.
- **No compile-time safety.** Cell's state is runtime-checked, not
  compile-checked.
- **No migration path from Riverpod's `AsyncNotifier`.** The async
  primitives are different.
- **A small ecosystem.** `cell_flutter_persistence`, `cell_flutter_router`,
  `cell_flutter_lints`, and `cell_flutter_audit` exist, but there is no
  `riverpod_lint`-depth tooling and no large third-party community yet.
  *(The original plan draft claimed there was no
  `cell_flutter_persistence`; that shipped since — this gap is kept
  accurate, not dramatic.)*

## When to migrate

> If you have decided that Cell's differentiators are worth the migration
> cost, see [Migrating-From-Riverpod-BLoC.md](../guide/Migrating-From-Riverpod-BLoC.md)
> for a step-by-step guide — complete before/after code, annotated diffs,
> and three runnable reference apps.

This page tells you **whether**; that guide tells you **how**. The other
adoption artifacts answer the remaining questions: the
[live Audit Trail demo](https://simon-m-lee.github.io/cell/audit-trail/)
is the "see it" proof, and
[`cell_flutter_audit`](https://pub.dev/packages/cell_flutter_audit) is
"here is the widget" for the audit trail.

## Sources

1. `cell_flutter` API docs and guides (cells, pulses, `TestCell` gates) —
   [pub.dev](https://pub.dev/packages/cell_flutter)
2. Riverpod docs — [riverpod.dev](https://riverpod.dev) (codegen, DevTools,
   `AsyncValue`, `select`); generator on
   [pub.dev](https://pub.dev/packages/riverpod_generator)
3. BLoC docs — [bloclibrary.dev](https://bloclibrary.dev) (`BlocObserver`,
   browser DevTools extension); `freezed` ecosystem on pub.dev
4. Provider docs and `Selector` — [pub.dev](https://pub.dev/packages/provider)
5. GetX repository and README — [pub.dev](https://pub.dev/packages/get)
6. Signals README (compile-time derivation claim) —
   [pub.dev](https://pub.dev/packages/signals)
7. `cell_flutter_devtools` extension — in-repo
   [README](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter_devtools)
8. Community-size proxy: pub.dev like counts for
   [cell_flutter](https://pub.dev/packages/cell_flutter),
   [flutter_riverpod](https://pub.dev/packages/flutter_riverpod),
   [flutter_bloc](https://pub.dev/packages/flutter_bloc),
   [provider](https://pub.dev/packages/provider),
   [get](https://pub.dev/packages/get), and
   [signals](https://pub.dev/packages/signals) — checked 2026-11-17
9. `CellAsyncBuilder` — cell_flutter API docs
10. `ApplyLedger` — `cell` API docs (`ApplyReceipt` minting for every
    `Cell.apply`)
11. `Cell.txApply` — [`cell` ARCHITECTURE.md §5](https://github.com/simon-m-lee/cell/blob/master/packages/cell/ARCHITECTURE.md)
12. `unmodifiable` / `deputy` — `cell` API docs (proxy views without copy)
13. `TestCell` — `cell` API docs (validation gate in front of mutations)

## How this page is maintained

This is a living document, not a one-time artifact: the five other
packages' documentation is checked quarterly, and any cell in the matrix
is updated when the source documentation changes. Every claim carries a
source above so you can verify it yourself — please open an issue when a
row goes stale.
