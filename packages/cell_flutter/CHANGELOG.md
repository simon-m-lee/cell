# Changelog

## 1.1.0

Documentation and packaging accuracy pass (additive API — no breaking
changes). Addresses the claims in
`research/Flutter-Binding/_Pending/code-review(Claude).md`.

- **Barrel doc rewritten** — the stale 0.7.0 "gate failed" status block
  (pre-1.0 content) is gone; the library doc now reflects the 1.x frozen
  API, carries no volatile release numbers or test counts, and links
  status/limitations to the README and this changelog. The export
  inventory and the "Which widget do I reach for?" table now cover every
  export, including forms, restoration, `CellErrorBoundary`,
  `CellListView`, and the DevTools surface.
- **`devtools.dart` entry point added** — `CellRegistry`,
  `CellRegistryEntry`, `CellPulseRecord`, and `CellInspectorOverlay` now
  have a dedicated `package:cell_flutter/devtools.dart`, mirroring
  `hooks.dart` and `testing.dart`. The barrel re-export is retained for
  1.x compatibility and is scheduled for removal in 2.0. The
  production-app example and the DevTools tests import the new entry
  point.
- **`library cell_flutter;` → unnamed `library;`**, exports sorted and
  grouped with comments, and the stray colon on the "See Also" heading
  fixed; doc links now use full GitHub URLs instead of repository-relative
  paths.
- **Pubspec comments corrected** — the `flutter_test` justification no
  longer cites bloc_test / mocktail / mockito (those depend on `test` /
  `test_api`, not `flutter_test`); the real reason (the `testing.dart`
  entry point must resolve for consumers) is stated, with the
  `cell_flutter_test` extraction scheduled for 2.0. The `flutter_hooks`
  comment now says plainly that it is mandatory at resolution time and
  optional at import time, and the dependency-override comment explains
  why pub dependents are unaffected.

## 1.0.2

- **README cleanup**: removed the pre-public "What's new in 0.1" section —
  the first public release is the 1.0.x line, so the README no longer
  presents the unpublished 0.1 history as news (the full history remains
  in this changelog). No code or API changes.

## 1.0.1

pub.dev scoring pass — no public API changes.

- **Pubspec description** lengthened to the 50–180 character convention
  window required by pub.dev scoring.
- **Example entry point** — added `example/lib/main.dart` (the canonical
  counter app) so pub.dev's "package has an example" check passes; the
  other demo files remain standalone runnable programs.
- **`flutter_hooks` constraint** widened to `'>=0.20.5 <0.22.0'` so the
  latest `0.21.x` release is supported (pub.dev "up-to-date
  dependencies" scoring); the full suite passes against `0.21.x`.
- **Material import annotations** — `lib/src/` files that import
  `package:flutter/material.dart` now carry an ignore annotation for the
  upcoming Flutter ≥3.47 `material_ui` transition, so pub.dev's
  analysis of the package stays clean while remaining compatible with
  the stable Flutter SDK.

## 1.0.0

Stable release (production readiness). The public API of
`cell_flutter.dart` and `hooks.dart` is frozen per the semver policy in
`CONTRIBUTING.md`; breaking changes now require a major version bump.

### Added

- **Ecosystem packages** — `cell_flutter_router` 0.1.0 (go_router
  bridge: `CellRouterState`, `CellRouterStateMirror`,
  `CellRouterScope`, `useCellRouter`, restorable `routerState()`)
  and `cell_flutter_persistence` 0.1.0 (`CellPersistenceAdapter`,
  `SharedPreferencesAdapter`, `InMemoryAdapter`, `PersistedCell`
  with immediate / debounced / onAppPause write modes).
- **Guides** — `guide/HowTo-Router.md` and
  `guide/HowTo-Persistence.md`; `ARCHITECTURE-flutter.md` gained
  sections 16–20 (router, persistence, benchmarks, API stability,
  roadmap).
- **Benchmark gate** — `benchmark/` scenarios against
  ValueListenableBuilder / Riverpod / Bloc with
  `benchmark/baseline.json` and the 15% regression gate in
  `tool/benchmark.dart`.
- **CI** — `.github/workflows/cell_flutter.yml` (format, analyze,
  doc, coverage ≥95%, ecosystem + dogfooding app tests, golden
  regeneration check), `cell_flutter_benchmark.yml` (15% gate),
  `cell_flutter_publish.yml` (publish dry-runs).
- **Stability docs** — `CONTRIBUTING.md` (development loop, quality
  gates, API stability policy) and the post-1.0 support commitment
  in the README.

### Changed

- `CellFlutterDevTools.unregister` / `clear` are now no-ops while the
  devtools are disabled — dispose-time cleanup is always safe
  (previously threw when the registry was reset before tree
  finalization).
- **Dependency floor**: `cell: ^2.0.0` (the Causal Replay release —
  required `journal:` parameters on the async operators and
  `Cell.latestPulse`); the `example/` search screen was updated to the
  journal-required `Cell.asyncMap` signature.

## 0.10.0

Minor release (developer experience). The widget layer is
frozen; this release ships the adoption tooling: migration guides, a
comparison document, an in-app cell inspector, and lint rules. Two
dogfooding-app bug fixes ride along.

### Added

- **Migration guides** — `guide/Migrating-From-Provider.md`,
  `guide/Migrating-From-Riverpod.md`, `guide/Migrating-From-Bloc.md`,
  and `guide/Migrating-From-SetState.md`. Each guide's worked examples
  are backed by before/after fixture pairs under `test/migration/`
  (real Provider / Riverpod 3 / Bloc code) whose rendering parity is
  asserted by `test/migration/migration_test.dart` — the guide's
  accuracy contract.
- **Comparison document** — `doc/comparison.md`: an honest
  Provider / Riverpod / Bloc / cell_flutter comparison with a
  should-I-use-this decision guide.
- **In-app Cell Inspector** — `CellFlutterDevTools.enable()` +
  `CellFlutterDevTools.register(symbol, cell)` + `CellInspectorOverlay`
  (floating panel with live values, pulse counts, and per-cell pulse
  journals). Explicit registration by design; the registry never
  disposes cells; release-mode `enable()` is a no-op.
- **`cell_flutter_lints` 0.1.0** — a sibling package (not a dependency)
  with four custom_lint rules: `cell_avoid_creation_in_build`,
  `cell_unkeyed_hook_builder`, `cell_forgotten_dispose`,
  `cell_collection_selector_without_equals`. `// expect_lint:` fixtures
  verify each rule's fire/no-fire/ignore/generics/nested/async/
  null-safe behavior.
- **Dogfooding app** — `example/production_app/`: login (forms +
  validation), a 120-item `CellListView`, a detail screen with
  `CellErrorBoundary` break/recovery, restored settings, and the
  inspector wired in; integration tests walk the whole journey.

### Changed

- `CellErrorBoundaryState.reset()` now defers the child restoration to
  a post-frame callback (and guarantees a frame). Retry buttons are
  focused when tapped; unmounting the focused fallback synchronously
  leaked a `_FocusInheritedScope` dependency, which the framework
  asserts when the enclosing route later unmounts.
- `CellTextField` forwards `obscureText` (password fields).
- `CellInspectorOverlay` provides a fallback `Directionality` when
  mounted above a whole `MaterialApp`.

### Tests

- `test/devtools/overlay_test.dart` — 14 registry + overlay tests.
- `test/migration/migration_test.dart` — 9 fixture-pair parity tests.
- `example/production_app/test/app_test.dart` — 3 journey tests.
- `cell_flutter_lints`: the expect_lint fixture matrix (4 rules ×
  fire/no-fire/unrelated/ignore/generics/nested/async/null-safe) driven
  by one harness test.

## 0.9.0

Minor release (forms, error boundary, list virtualization).
Adds the three remaining widget-layer categories a production app needs.
No breaking API changes; everything is additive.

### Added

- **`CellEditingController` / `cellEditingController(cell)`** — a
  `TextEditingController` bound two-way to a `ValueCell<String>`.
  Equality guards break the feedback loop in both directions; cell-driven
  updates preserve the cursor's offset from the end (full replacements
  land at the end). Disposal releases the internal observation.
- **`CellTextField`** — a `TextFormField` bound to a `ValueCell<String>`:
  typing updates the cell, cell updates re-render the field, focus is
  preserved, and `validator` / `autovalidateMode` / `Form.validate()`
  work through the standard `TextFormField` mechanism.
- **`CellFormField<T>`** — a generic `FormField` bound to a
  `ValueCell<T>` for non-text inputs (dropdowns, sliders, checkboxes,
  date pickers). `FormFieldState.didChange` commits to the cell; cell
  writes call `didChange` back (deferred on cell swap so the enclosing
  `Form` is never marked dirty mid-build).
- **`CellErrorBoundary`** — renders an `onError` fallback instead of
  Flutter's error screen for framework-thrown build errors (invalidated
  cells, build-phase `setState` errors). The `cell_flutter` report
  channel (type mismatches, `emitErrors` reports) passes through
  untouched; `CellErrorBoundaryState.reset()` recovers; nested boundaries
  are independent; `FlutterError.onError` is restored on dispose.
- **`CellListView<T>.builder`** — a virtualized `ListView.builder` bound
  to any cell producing `List<T>`; composes with per-item `CellBuilder`.
- **`CellListView<T>.keyed`** — the keyed-diff variant: `itemKey` drives
  a widget cache (only new keys re-invoke the builder), automatic
  `KeyedSubtree` keys plus `findChildIndexCallback` preserve item state
  across reorders, duplicate keys throw `StateError`, and the scroll
  position survives mutations. Documented trade-offs: O(n) widget
  configurations and a stale-index note for reorders.
- **`guide/HowTo-Forms.md`** — the forms walkthrough.

### Tests

- `test/forms/cell_editing_controller_test.dart` — 8 tests (two-way sync
  guards, cursor preservation, disposal, convergence).
- `test/forms/cell_text_field_test.dart` — 7 tests.
- `test/forms/cell_form_field_test.dart` — 6 tests (incl. `DateTime`).
- `test/forms/login_form_integration_test.dart` — 4 tests: typing,
  `Form.validate()`, `onSubmit`, hot-restart preservation of the 4-field
  `LoginForm`.
- `test/error_boundary/cell_error_boundary_test.dart` — 7 tests:
  invalidated-cell containment, mid-frame invalidation, report-channel
  passthrough, recovery, `onReset`, nesting, handler restoration.
- `test/list_view/cell_list_view_test.dart` — 11 tests: builder variant,
  per-item `CellBuilder` composition, keyed append/remove/replace
  rebuild counts, keyed reorder state preservation, duplicate keys,
  scroll-position survival, 10,000-item render + scroll.

## 0.8.0

Minor release (state restoration). Adds the restoration
foundation every production Flutter app needs. No breaking API changes;
everything is additive.

### Added

- **`RestorableCell<V>`** — a `ValueCell` whose value participates in
  Flutter's state restoration. Behaves exactly like any `ValueCell`;
  additionally serializes its value into a `RestorationBucket` when
  registered with a `CellRestorationScope`. Default codecs cover `bool`,
  `int`, `double`, `String`, and `null`; custom
  `toPrimitives` / `fromPrimitives` persist any `V`. Non-primitive values
  without codecs fail loudly with `UnsupportedError`.
- **`restorableState<V>(...)`** (and `CellRestoration.restorableState<V>`)
  — the factory spelling for `RestorableCell`. (The core `cell` package is
  Flutter-free, so the factory lives in `cell_flutter` rather than on
  `Cell`.)
- **`CellRestorationScope`** — claims a `RestorationBucket` (from the
  enclosing `RestorationScope`, or an injected `bucket` parameter),
  registers/unregisters `RestorableCell`s, re-registers them on every
  restore, and injects its bucket for nested scopes. Duplicate ids throw
  `StateError`; registration is idempotent per cell instance.
- **`guide/HowTo-Restoration.md`** — the minimal counter example, the
  serialization contract, registration timing rules, and the test-bucket
  format.

### Tests

- `test/restoration/restorable_cell_test.dart` — 16 tests: fresh install,
  persisted restore, primitive round-trip, loud non-primitive failure,
  custom codecs, no-pulse-on-equal-restore, duplicate-id error, idempotent
  registration, unregister/re-register, scope disposal, nested scopes,
  multiple cells, cleared data, graph propagation, bucket claiming, and
  the `CounterApp` process-kill simulation.

## 0.7.0

Minor release (core hardening). No breaking API changes; the
only user-visible behavior changes are strict improvements:
`CellValueBuilder` gains seed-path error visibility under
`emitErrors: true`, and one stale doc claim (`useCell`'s "one-frame
flash") was corrected against the verified behavior.

### Fixed

- **`useCellAsync` seeds from the retained pulse of a plain async cell**
  Verified against `fromFuture`, `fromStream`, `asyncMap`, and
  `derive` sources: a source that emitted before the hook mounted renders
  data on the first frame, mirroring `CellAsyncBuilder`. (The seeding call
  existed since 0.6.0; this release adds the four-source test coverage.)
- **`CellValueBuilder` reports a retained error pulse during seeding when
  `emitErrors: true`** Previously an error pulse sitting in the
  retained slot was silently dropped regardless of `emitErrors`; now the
  seed path honors the same error contract as live pulses
  (`FlutterError.reportError` with a seed-path context). Default
  `emitErrors: false` behavior is unchanged.
- **`useCell` collection-equality assert locked in with tests**:
  a collection `select` without `equals` fails the debug assert; a
  non-collection slice without `equals` works (new explicit test).
- **`CellTestHarness.emitAndSettle` post-dispose guard documented in the
  dispose contract**: the guard existed; the class doc now lists
  `emitAndSettle` among the methods that throw after `dispose`.

### Documentation

- **`useCell` cell-swap behavior corrected**. The docs previously
  warned of a "one-frame flash" on cell swap. A probe showed the claim was
  wrong: `flutter_hooks` re-runs a keyed effect's body synchronously
  during the build that registers the changed keys, so `useCell` returns
  the new cell's slice on the very first build after a swap. The
  `### Design Note` now documents the verified no-flash behavior, and the
  keying idiom is described as the general hook-state reset, not a flash
  workaround. The decision and its rationale are recorded in the library docs.
- **`CellScope.updateShouldNotify` `==` decision recorded**. The
  `==`-based comparison (deputy swap does not notify dependents) was
  already in place from 0.6.0; this release records the probe and the
  decision in the library docs;
- **`CellScope.maybeOf` first-line doc** now leads with "does not swallow
  type mismatches" and says to use it only when absence is a valid
  outcome.
- **`expectCellGolden` two-golden workflow** is now locked in by a test
  and two committed goldens: every call pumps a fresh tree, so the
  value is driven by a direct cell mutation between captures.
- **Full documentation consistency pass**. Every `///` behavior
  claim in `lib/src/` was audited: verified claims map to tests,
  contradicted claims were corrected (the `useCell` flash), and the audit
  is recorded in a repository-only audit file

### Internal

- `ARCHITECTURE-flutter.md` §7: the hooks-layer bullet updated to the
  verified no-flash `useCell` behavior.
- New tests: 10 (4 hook seed tests, 2 seed-error tests, 2 hook-swap
  tests, 1 collection-assert test, 1 two-golden workflow test).

## 0.6.1

Bugfix release. No breaking changes. Every user on 0.6.0 should upgrade.

### Fixed

- **C1 — Late-subscriber seed path for plain async cells.**
  `CellValueBuilder`, `CellAsyncBuilder`, `asValueCell`, and `asStream`
  now correctly seed from a plain cell's retained pulse when the source
  emitted before the consumer subscribed. This fixes a silent failure
  where a completed `Cell.fromFuture`, a `Cell.derive` that had already
  produced a value, a `Cell.fromStream` after its first emission, or an
  `asyncMap` that had already mapped one input would render as `initial`
  / `nothing()` / no event forever.

  The underlying cause was `retainedPulseOf` returning `null` for every
  non-`ValueCell` source. It now delegates to the core package's public
  retained-pulse accessor `Cell.latestPulse`, which covers `fromFuture`,
  `fromStream`, `asyncMap`, and `derive`; a `ValueCell.value` fallback
  still serves custom `ValueCell` subclasses. A cell that has never
  emitted still falls back to `initial` / `nothing()`.

  See `test/seed_paths_test.dart` for the 12-test coverage.

- **C2 — Consistent, test-locked documentation of per-source error-pulse
  behavior.** The truth was verified against the core `cell` source:
  only `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on its
  failure path; `Cell.fromStream` errors never emit a pulse (the error
  only decides whether to cancel), and `Cell.asyncMap` mapper failures
  never emit on the output cell (they fail the source pulse). The eight
  docs that discuss error pulses now all state this and reference the new
  authoritative test file.

  See `test/error_pulse_sources_test.dart` for the authoritative
  statement and `record_pulses.dart` for the user-facing contract.

### Documentation

- `ARCHITECTURE-flutter.md` §7: the "seed semantics for plain cells"
  constraint is replaced with the fixed behavior; the error-pulse bullet
  now points at the authoritative test.
- `README.md` §Status and the `cell_flutter.dart` library doc: updated to
  0.6.1, with the C1 fix listed under guarantees.
- `pulse_delivery.dart`, `cell_value_builder.dart`,
  `cell_async_builder.dart`, `cell_as_value.dart`, `cell_stream.dart`,
  `cell_listener.dart`, `use_cell_listener.dart`, `use_cell_async.dart`,
  `record_pulses.dart`, `testing.dart`: seed-semantics and error-pulse
  sections rewritten to match the fixed behavior, with `### See also`
  links to the two new test files.

## 0.6.0

Hardening release: the 1.0 gate was evaluated and did **not**
pass, so the binding stays on `0.5.x` and
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
- Gate-evaluation records: fuzz, soak,
  security review, documentation audit,
  usability, and the 1.0 gate

**Evaluation summary (2026-11-13):** the documentation, coverage, migration-guide, accessibility, soak, security-review, and link-check gates
pass. The fuzz gate passes on the deterministic smoke run; the full 30-minute fuzz
run is wired into CI (this sandbox hit an OS thread limit). The benchmark gate fails on
multi-builder bursts (10 builders 2.31×, 100 builders 2.93× of the
`ValueListenableBuilder` baseline; single-builder 1.25× passes) — the
overhead lives in the cell core's pulse machinery and is tracked for the
next hardening cycle. The usability gate is blocked: no external developer is available
to run the migration usability test. External production adoption remains a documented gap (no
external production adopters yet).

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`,
and `fromStream` probes. Concurrent `asyncMap` effect attribution is
tracked separately. Only `Cell.fromFuture` emits error pulses
today; `fromStream` and `asyncMap` do not.

**Code-review resolution (0.1.0-era review):**
The full record is kept in the repository.

- Error-pulse docs unified across all files: only `Cell.fromFuture` emits
  `type: 'error'` pulses; `CellAsyncBuilder` / `CellListener` /
  `asStream` docs now state the consequence for `fromStream` / `asyncMap`.
- Plain-cell retained-pulse seeding documented as a constraint (no
  `Cell.latestPulse` references — the published `cell` floor has no such
  API); a shared `seedFromRetained` helper replaces the duplicated
  per-file seed logic.
- `CellValueBuilder`'s (and `CellAsyncBuilder`'s) separate initState
  seeding path was removed — live pulses now take a single code path
  (build-phase deferral included), so the `emitErrors` contract applies
  uniformly to every pulse.
- `useCellAsync` seeds from `snapshotForCell`, matching `CellAsyncBuilder`
  for `ValueCell` sources.
- `useCell` gained the debug collection-equality assertion that
  `CellSelector` has, and documents its one-frame stale slice on cell swap.
- `CellScope.updateShouldNotify` compares cells with `==` (nucleus-based
  logical identity), so an equal deputy swap no longer notifies dependents.
- `CellTestHarness.emitAndSettle` gained the `_disposed` guard;
  `expectCellGolden`'s `name` is optional when `goldenPath` is given, and
  its docs state that every call pumps a fresh tree;
  `PulseRecorder.pulses` docs state the snapshot-copy semantics.
- Per-widget build-phase docs added for `CellBuilder` / `CellSelector` /
  `CellNotifier` (synchronous notification, error attribution, no
  emit-from-build rule); `useCellListener` documents its captured-context
  reparenting behavior.

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

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`,
and `fromStream` probes. Concurrent `asyncMap` effect attribution is
tracked separately. Only `Cell.fromFuture` emits error pulses
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

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`). `recordPulses` records every pulse regardless of
type; only `Cell.fromFuture` currently emits error pulses (`fromStream`
and `asyncMap` do not). Concurrent `asyncMap` effect attribution is
tracked separately.

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

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`). `useCellAsync` inherits `CellAsyncBuilder`'s per-source
error behavior (only `fromFuture` emits error pulses today) and the concurrency caveat

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

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`, and
`fromStream` probes. Concurrent `asyncMap` effect attribution is tracked
separately. The `CellAsyncBuilder`, `CellValueBuilder`,
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

**Breaking:** none. Public APIs unchanged.

The binding continues to rest on `cell`'s verified replay round-trip
(commit `05b4895d`) for the pure state, debounce, throttle, `fromFuture`, and
`fromStream` probes. Concurrent `asyncMap` effect attribution is tracked
separately and is not claimed by this release. `CellListener`
over an `asyncMap` source with `concurrency > 0` inherits that caveat.

## 0.0.1

Initial release.

- `CellNotifier<V>`: adapts `ValueCell<V>` to `ValueNotifier<V?>`
- `CellBuilder<V>`: rebuilds on cell value changes
- `ValueCell.builder`: fluent shorthand for `CellBuilder`

The binding rests on `cell`'s verified replay round-trip (commit `05b4895d`)
for the pure state, debounce, throttle, fromFuture, and fromStream probes.
Concurrent `asyncMap` effect attribution is tracked separately
and is not claimed by this release.
