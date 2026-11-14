# Changelog

## 0.6.0

Hardening release: the Phase 7 1.0 gate was evaluated and did **not**
pass (see `reports/GATE_1.0.md`), so the binding stays on `0.5.x` and
this release carries the hardening artifacts and tooling:

- Fuzz harness + six fuzz suites (`test/fuzz/`), including the
  replay-probe fuzz (debounce, throttle, `fromFuture`, `fromStream`)
- 10k-iteration soak test with an in-test control phase
  (`test/soak/soak_test.dart`) — framework-attributable RSS growth
  +2.7%, timers flat
- Microbenchmark package (`benchmark/`) comparing `CellBuilder` against
  `ValueListenableBuilder`, Riverpod, and Bloc; results in
  `guide/Benchmarks.md`
- Snippet extraction tool (`tool/extract_snippets.dart`) generating
  `test/migration/_extracted_test.dart` from the migration guides
- Link checker (`tool/check_links.dart`)
- Hardening CI workflow (`.github/workflows/hardening.yml`)
- Gate artifacts: `reports/FUZZ.md`, `reports/SOAK.md`,
  `reports/SECURITY_REVIEW.md`, `reports/DOCS_AUDIT.md`,
  `reports/USABILITY.md`, `reports/GATE_1.0.md`, `SECURITY.md`

**Gate evaluation summary (2026-11-13):** G1, G2, G4, G5, G7, G8, G9
pass. G6 passes on the deterministic smoke run; the full 30-minute fuzz
run is wired into CI (this sandbox hit an OS thread limit). G3 fails on
multi-builder bursts (10 builders 2.31×, 100 builders 2.93× of the
`ValueListenableBuilder` baseline; single-builder 1.25× passes) — the
overhead lives in the cell core's pulse machinery and is tracked for the
next hardening cycle. G10 is blocked: no external developer is available
to run the migration usability test. S1 remains a documented gap (no
external production adopters yet).

**Breaking:** none. Phase 1–5 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`,
and `fromStream` probes. Concurrent `asyncMap` effect attribution is
tracked separately (Gate G1.5). Only `Cell.fromFuture` emits error pulses
today; `fromStream` and `asyncMap` do not.

## 0.5.0

- `doc/CHOOSING.md` — the honest decision document ("should I use
  Mitosis at all?")
- `doc/INDEX.md` — the landing page for all guides and examples
- `guide/MigratingFrom-Riverpod.md` — the primary adoption path, with
  concept mapping, step-by-step migration, and an explicit "what doesn't
  migrate" section
- `guide/MigratingFrom-Bloc.md` — the secondary adoption path (same
  structure)
- `example/lib/todo_with_auth.dart` — realistic end-to-end example
  (auth + todos + count selector + saved snackbar + `testRule`
  validation) with `example/test/todo_with_auth_test.dart`
- Accessibility audit on all 6 examples
  (`example/integration_test/accessibility_test.dart`)
- Snippet compile-checks: `test/migration/_riverpod_snippets_test.dart`
  and `_bloc_snippets_test.dart` (every Mitosis snippet in the guides is
  a compiling test)

**Breaking:** none. Phase 1–5 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`,
and `fromStream` probes. Concurrent `asyncMap` effect attribution is
tracked separately (Gate G1.5). Only `Cell.fromFuture` emits error pulses
today; `fromStream` and `asyncMap` do not — the migration guides name
this explicitly for users coming from Riverpod's `AsyncValue` and Bloc's
error surfaces.

## 0.4.0

- Add `testing.dart` sub-library with `WidgetTester` extensions:
  `pumpWithCells`, `pumpCell`, `emitAndSettle`, `emitAndPump`,
  `expectCellValue`, `expectCellGolden`
- Add `recordPulses()` extension and `PulseRecorder<T>` class
- Add `CellTestHarness` for auto-managed test cell bundles
- Add `example/test/counter_test.dart` and `guide/HowTo-Testing.md`

**Requirement:** `cell_flutter` declares `flutter_test` as a regular
dependency (the standard `bloc_test` / `mocktail` pattern). Keep
`cell_flutter` in your dev_dependencies and `flutter_test` resolves
transitively without reaching production builds.

**Breaking:** none. Phase 1–4 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`). `recordPulses` records every pulse regardless of
type; only `Cell.fromFuture` currently emits error pulses (`fromStream`
and `asyncMap` do not). Concurrent `asyncMap` effect attribution is
tracked separately (Gate G1.5).

## 0.3.0

- `cell_flutter/hooks.dart` — optional `flutter_hooks` integration with
  `useCell`, `useCellValue`, `useCellNotifier`, `useCellListener`,
  `useCellAsync`
- `CellBuilder` debug warning for the "cell created in `build`" hot-reload
  anti-pattern
- `CellScope` debug warning for nested-scope symbol shadowing
- `CellSelector` debug assert for collection slices without a custom
  `equals`
- Example: `hooks_counter.dart`
- Guides: `HowTo-Hooks.md`, `HowTo-HotReload.md`, `HowTo-Debugging.md`

**Breaking:** none. Phase 1–3 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`). `useCellAsync` inherits `CellAsyncBuilder`'s per-source
error behavior (only `fromFuture` emits error pulses today) and Gate G1.5
(concurrent `asyncMap` effect attribution, tracked separately).

## 0.2.0

- `CellAsyncBuilder<V>` — renders `Cell.fromFuture` / `fromStream` / `asyncMap`
  outputs as `AsyncSnapshot`; documents the per-source error-pulse behavior
  (only `fromFuture` emits errors today)
- `CellSelector<V, S>` — rebuild on selected slice, with custom `equals`
- `CellValueBuilder<V>` — renders any `Cell` via an internal mirror; the
  bridge for `Cell.derive` / `synthesis` / `switchMap` / tissue sources
- `Cell.asStream()` — `Stream<V?>` bridge for `Bloc` / `StreamBuilder` interop
- `Cell.asValueCell()` — record-returning mirror with explicit `dispose`
- Examples: `async_search.dart`, `derived_cells.dart`
- Guides: `HowTo-CellAsyncBuilder.md`, `HowTo-CellSelector.md`,
  `HowTo-DerivedCells.md`, `HowTo-Streams.md`

**Breaking:** none. Phase 1–2 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`, and
`fromStream` probes. Concurrent `asyncMap` effect attribution is tracked
separately (Gate G1.5). Phase 3's `CellAsyncBuilder`, `CellValueBuilder`,
and `asStream` inherit that caveat when observing `asyncMap` sources with
`concurrency > 0`; the widget's observation is correct, the caveat is
about the source's replay fidelity. `fromStream` and `asyncMap` do not
emit error pulses today; `CellAsyncBuilder` shows the last successful
value on failure rather than an error snapshot.

## 0.1.0

- `CellListener<V>` — side-effect primitive with mid-frame deferral and
  documented error-pulse handling
- `CellScope` — app-level dependency injection via InheritedWidget
- Example: `auth_flow.dart` demonstrating both primitives
- Guides: `HowTo-CellListener.md`, `HowTo-CellScope.md`

**Breaking:** none. Phase 1 APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`, and
`fromStream` probes. Concurrent `asyncMap` effect attribution is tracked
separately (Gate G1.5) and is not claimed by this release. `CellListener`
over an `asyncMap` source with `concurrency > 0` inherits that caveat.

## 0.0.1

Initial release.

- `CellNotifier<V>`: adapts `ValueCell<V>` to `ValueNotifier<V?>`
- `CellBuilder<V>`: rebuilds on cell value changes
- `ValueCell.builder`: fluent shorthand for `CellBuilder`

The binding rests on `cell`'s verified replay round-trip (commit `05b4895d`)
for the pure state, debounce, throttle, fromFuture, and fromStream probes.
Concurrent `asyncMap` effect attribution is tracked separately (Gate G1.5)
and is not claimed by this release.
