# `cell_flutter` compared to Provider, Riverpod, and Bloc

This page answers "why would I choose `cell_flutter` over the state
management package I already know?" It is deliberately honest: where
`cell_flutter` lacks a feature, the table says so. Read the Status
section of the README alongside this page — this document describes
*shape*, the README describes *maturity*.

## 1. The philosophy

The four packages differ in what they treat as the unit of state.

- **Provider** is dependency injection with rebuilds. Its unit is the
  *provider* — an object lookup keyed by type, with `ChangeNotifier`
  as the workhorse. State itself is plain Dart classes you write.
- **Riverpod** is compile-safe DI with a reactive graph. Its unit is
  still the *provider*, but providers are first-class reactive nodes:
  they can watch each other, be overridden in tests, and be
  auto-disposed. State is still your classes (or `AsyncValue`).
- **Bloc** is an event-driven architecture. Its unit is the
  *Cubit/Bloc*: state transitions happen only through events, which
  makes every change traceable and forces the business logic out of
  the widget layer.
- **`cell_flutter`** is a reactive graph of *cells*. Its unit is the
  cell itself: a node that holds or derives a value and emits
  governed **pulses** when it changes. `Cell.state` / `Cell.derive` /
  `Cell.asyncMap` are the graph operators; the widgets (`CellBuilder`,
  `CellSelector`, `CellListener`, ...) are thin observers. The widget
  layer is deliberately dumb — it renders pulses and does nothing
  else.

The practical consequence: in Provider/Riverpod/Bloc, the widget layer
owns rebuild orchestration (`Consumer`, `ref.watch`, `BlocBuilder`);
in `cell_flutter`, the *graph* owns propagation and the widgets merely
subscribe. This is why `cell_flutter` can offer transactions, pulse
forensics, and least-privilege views that the others structure out.

## 2. Feature comparison

Honesty rule for this table: a `✓` means the capability ships in the
published surface today (or is the package's standard pattern). `—`
means it does not — no "coming soon".

| Capability | Provider | Riverpod | Bloc | cell_flutter |
|---|---|---|---|---|
| Local mutable state | ✓ `ChangeNotifier` | ✓ providers | ✓ `Cubit` | ✓ `Cell.state` |
| Derived state | ✓ `Selector`/manual | ✓ `Provider` | ✓ computed in state | ✓ `Cell.derive` |
| Async state | manual `FutureBuilder` | ✓ `AsyncValue` | manual/`Bloc` events | ✓ `CellAsyncBuilder`/`asyncMap` |
| Error visibility in UI | manual | ✓ `AsyncError` | ✓ state holds error | ✓ `Cell.fromFuture` errors + `CellErrorBoundary` |
| Dependency injection | ✓ (its core) | ✓ (its core) | — (manual) | — (manual; `CellScope` for scoping) |
| Side effects | `ref.listen`-ish manual | ✓ `ref.listen` | ✓ `BlocListener` | ✓ `CellListener` |
| Testing | manual mocking | ✓ overrides | ✓ `bloc_test` | ✓ first-class harness (`recordPulses`, `pumpWithCells`, determinism gate) |
| Transactions (atomic multi-write) | — | — | — | ✓ (unique: graph-governed pulses) |
| Pulse forensics (replay/audit) | — | — | — | ✓ (unique: `cell` replay engine) |
| Least-privilege views | — | — | — | ✓ (unique: `ValueCell`/`Cell` split) |
| DevTools | — | ✓ mature | ✓ | ✓ in-app `CellInspectorOverlay` (new; not as deep as Riverpod's) |
| Persistence | manual | `riverpod_persistence` | `hydrated_bloc` | ✓ `restorableState` (Flutter restoration) |
| Codegen | — | ✓ `riverpod_generator` | ✓ `freezed` ecosystem | — |
| Form helpers | — | — | — | ✓ `CellTextField`/`CellFormField` |
| List virtualization | manual | manual | manual | ✓ `CellListView` |
| Error boundary | — | — | — | ✓ `CellErrorBoundary` |
| Routing integration | manual | manual | manual | — (backlog) |
| Migration guides | ✓ | ✓ | ✓ | ✓ (this phase) |
| Lint rules | — | ✓ `riverpod_lint` | ✓ `bloc_lint` | ✓ `cell_flutter_lints` (new) |

## 3. Where `cell_flutter` wins

- **Testing.** `recordPulses`, `pumpWithCells`, `emitAndSettle`, and the
  pulse-level determinism gate test *sequences* of state changes, not
  just final values. Bloc's event log is close in spirit; no other
  package asserts pulse order, payloads, and error types with the same
  directness.
- **Transactions.** A governed write can atomically commit several cell
  updates with one logical pulse — no other package in this table has a
  native multi-state transaction primitive.
- **Forensics.** Pulses are first-class, typed, source-tagged objects
  with a replay engine in the core package. When a bug needs "what
  happened in which order", `cell_flutter` answers from data, not from
  re-adding logs.
- **Least-privilege views.** The `ValueCell` (read-write) / `Cell`
  (read-only) split is enforced by the type system: a child widget
  receiving a `Cell` *cannot* write state, no convention required.

## 4. Where `cell_flutter` loses

- **DevTools maturity.** The in-app `CellInspectorOverlay` is real and
  useful, but Riverpod's DevTools (provider graph, state inspection,
  override UI) is years ahead. The browser DevTools extension is still
  on the roadmap.
- **Ecosystem.** There is no `riverpod_persistence` equivalent, no
  `hydrated_bloc` equivalent, no codegen, no router bridge yet.
- **Learning curve.** Provider and Bloc teach their model in an hour;
  `cell_flutter` requires reading the architecture doc to use well
  (cells, pulses, scopes). The current guides are the fix, but
  the curve is real.
- **Community.** Smaller ecosystem, fewer StackOverflow answers,
  fewer example apps in the wild.

## 5. Should I use this?

- **Use `cell_flutter` if** you value testable state sequences,
  transactions, and auditability more than ecosystem size; if your
  team will read one architecture doc; and if you want Flutter-native
  restoration and forms out of the box.
- **Use Riverpod if** you want the most mature all-in-one reactive
  ecosystem today: codegen, DevTools, DI, and async ergonomics.
- **Use Bloc if** you want a hard event/state boundary enforced by
  convention and tooling, with a large team of developers who know the
  pattern.
- **Use Provider if** you need simple, boring, well-understood DI with
  rebuilds and nothing more.

## 6. Migration paths

- [Migrating from Provider](guide/Migrating-From-Provider.md) — one
  `ChangeNotifier` → one `Cell.state`; `Consumer` → `CellBuilder`.
- [Migrating from Riverpod](guide/Migrating-From-Riverpod.md) —
  providers → cells; `AsyncValue` → `AsyncSnapshot` via
  `CellAsyncBuilder`; families → `Map`/`Cell.switchMap`.
- [Migrating from Bloc](guide/Migrating-From-Bloc.md) — `Cubit` →
  `Cell.state`; events → `Cell.ingress`; `BlocBuilder` →
  `CellBuilder`.
- [Migrating from setState](guide/Migrating-From-SetState.md) — the
  smallest possible first step.
