# cell_flutter package - Test Verification Report

**Generated:** 2026-11-19
**Package:** cell_flutter (v1.0.2)
**Test Files Analyzed:** 46
**Total Tests:** 365 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Source Under Test (`lib/`)](#source-under-test-lib)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [cell_as_value_test.dart](#file-1-cell_as_value_test.dart-7-tests)
  - [cell_async_builder_test.dart](#file-2-cell_async_builder_test.dart-14-tests)
  - [cell_builder_hot_reload_test.dart](#file-3-cell_builder_hot_reload_test.dart-3-tests)
  - [cell_builder_test.dart](#file-4-cell_builder_test.dart-9-tests)
  - [cell_listener_test.dart](#file-5-cell_listener_test.dart-18-tests)
  - [cell_notifier_test.dart](#file-6-cell_notifier_test.dart-10-tests)
  - [cell_scope_shadow_test.dart](#file-7-cell_scope_shadow_test.dart-3-tests)
  - [cell_scope_test.dart](#file-8-cell_scope_test.dart-18-tests)
  - [cell_selector_collection_test.dart](#file-9-cell_selector_collection_test.dart-2-tests)
  - [cell_selector_test.dart](#file-10-cell_selector_test.dart-11-tests)
  - [cell_stream_test.dart](#file-11-cell_stream_test.dart-9-tests)
  - [cell_value_builder_test.dart](#file-12-cell_value_builder_test.dart-13-tests)
  - [overlay_test.dart](#file-13-overlay_test.dart-16-tests)
  - [cell_error_boundary_test.dart](#file-14-cell_error_boundary_test.dart-9-tests)
  - [error_pulse_sources_test.dart](#file-15-error_pulse_sources_test.dart-12-tests)
  - [cell_editing_controller_test.dart](#file-16-cell_editing_controller_test.dart-8-tests)
  - [cell_form_field_test.dart](#file-17-cell_form_field_test.dart-6-tests)
  - [cell_text_field_test.dart](#file-18-cell_text_field_test.dart-7-tests)
  - [login_form_integration_test.dart](#file-19-login_form_integration_test.dart-4-tests)
  - [async_fuzz_test.dart](#file-20-async_fuzz_test.dart-2-tests)
  - [builders_fuzz_test.dart](#file-21-builders_fuzz_test.dart-1-tests)
  - [listeners_fuzz_test.dart](#file-22-listeners_fuzz_test.dart-1-tests)
  - [replay_probes_fuzz_test.dart](#file-23-replay_probes_fuzz_test.dart-3-tests)
  - [scope_fuzz_test.dart](#file-24-scope_fuzz_test.dart-1-tests)
  - [selectors_fuzz_test.dart](#file-25-selectors_fuzz_test.dart-1-tests)
  - [counter_app_golden_test.dart](#file-26-counter_app_golden_test.dart-1-tests)
  - [feature_goldens_test.dart](#file-27-feature_goldens_test.dart-5-tests)
  - [use_cell_async_test.dart](#file-28-use_cell_async_test.dart-13-tests)
  - [use_cell_listener_test.dart](#file-29-use_cell_listener_test.dart-7-tests)
  - [use_cell_test.dart](#file-30-use_cell_test.dart-20-tests)
  - [cell_list_view_test.dart](#file-31-cell_list_view_test.dart-12-tests)
  - [_bloc_snippets_test.dart](#file-32-_bloc_snippets_test.dart-5-tests)
  - [_extracted_test.dart](#file-33-_extracted_test.dart-15-tests)
  - [_riverpod_snippets_test.dart](#file-34-_riverpod_snippets_test.dart-11-tests)
  - [migration_test.dart](#file-35-migration_test.dart-9-tests)
  - [pulse_delivery_test.dart](#file-36-pulse_delivery_test.dart-5-tests)
  - [restorable_cell_test.dart](#file-37-restorable_cell_test.dart-19-tests)
  - [seed_paths_test.dart](#file-38-seed_paths_test.dart-12-tests)
  - [soak_test.dart](#file-39-soak_test.dart-1-tests)
  - [cell_test_harness_test.dart](#file-40-cell_test_harness_test.dart-16-tests)
  - [emit_and_settle_test.dart](#file-41-emit_and_settle_test.dart-6-tests)
  - [expect_cell_golden_test.dart](#file-42-expect_cell_golden_test.dart-3-tests)
  - [expect_cell_value_test.dart](#file-43-expect_cell_value_test.dart-2-tests)
  - [pump_cell_test.dart](#file-44-pump_cell_test.dart-4-tests)
  - [pump_with_cells_test.dart](#file-45-pump_with_cells_test.dart-5-tests)
  - [record_pulses_test.dart](#file-46-record_pulses_test.dart-6-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `flutter test`](#last-flutter-test)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_flutter test suite contains **365 unit tests** across **46 files** in `test/`. Counts are `test(` / `testWidgets(` declarations.

The library under test is **33 source files** in `lib/`: **3** in top-level barrels (`cell_flutter.dart`, `hooks.dart`, `testing.dart`); **14** in `lib/src/` — widget layer; **2** in `lib/src/devtools/` — in-app Cell Inspector; **3** in `lib/src/forms/` — form bindings; **4** in `lib/src/hooks/` — `flutter_hooks` integration; **7** in `lib/src/testing/` — widget-test surface.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(` / `testWidgets(`.

### Snapshot

Last `flutter test` is **green**: **364 passed**, 0 failed (exit 0).

`lib/` line coverage is **100.0%** (928 / 928).

No `lib/` file is below 70% in this lcov.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 46 |
| **Total Tests** | 365 |
| **Skipped** | 0 |
| **Last full run** | 364 passed, 0 failed, 1 skipped (exit 0) |
| **Test Groups** | 67 (`group(` declarations) |
| **Async-ish tests** | ~25 (heuristic) |
| **Line coverage (`lib/`)** | **100.0%** (928 / 928) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | cell_as_value_test.dart | 93 | 7 | 2.6 KB | cell as value; groups: Cell.asValueCell |
| 2 | cell_async_builder_test.dart | 390 | 14 | 11.8 KB | cell async builder; groups: CellAsyncBuilder |
| 3 | cell_builder_hot_reload_test.dart | 82 | 3 | 2.6 KB | cell builder hot reload; groups: CellBuilder hot-reload warning |
| 4 | cell_builder_test.dart | 206 | 9 | 6.2 KB | cell builder; groups: CellBuilder, ValueCell.builder extension |
| 5 | cell_listener_test.dart | 530 | 18 | 15.5 KB | cell listener; groups: CellListener |
| 6 | cell_notifier_test.dart | 143 | 10 | 4.2 KB | cell notifier; groups: CellNotifier |
| 7 | cell_scope_shadow_test.dart | 99 | 3 | 3.3 KB | cell scope shadow; groups: CellScope nested shadow warning |
| 8 | cell_scope_test.dart | 392 | 18 | 11.1 KB | cell scope; groups: CellScope.of, CellScope.maybeOf, CellScope.valueOf, CellScope.updateShouldNotify, CellScope nested |
| 9 | cell_selector_collection_test.dart | 40 | 2 | 1.5 KB | cell selector collection; groups: CellSelector collection warning |
| 10 | cell_selector_test.dart | 312 | 11 | 8.9 KB | cell selector; groups: CellSelector |
| 11 | cell_stream_test.dart | 132 | 9 | 3.6 KB | cell stream; groups: Cell.asStream |
| 12 | cell_value_builder_test.dart | 344 | 13 | 9.4 KB | cell value builder; groups: CellValueBuilder |
| 13 | overlay_test.dart | 231 | 16 | 8.1 KB | overlay; groups: CellFlutterDevTools registry, CellInspectorOverlay |
| 14 | cell_error_boundary_test.dart | 280 | 9 | 9.1 KB | cell error boundary; groups: CellErrorBoundary |
| 15 | error_pulse_sources_test.dart | 229 | 12 | 7.3 KB | error pulse sources; groups: fromFuture, fromStream, asyncMap, recordPulses, CellAsyncBuilder error seeding (C1 x C2) |
| 16 | cell_editing_controller_test.dart | 109 | 8 | 3.8 KB | cell editing controller; groups: CellEditingController |
| 17 | cell_form_field_test.dart | 137 | 6 | 4.3 KB | cell form field; groups: CellFormField |
| 18 | cell_text_field_test.dart | 131 | 7 | 4.1 KB | cell text field; groups: CellTextField |
| 19 | login_form_integration_test.dart | 190 | 4 | 6.2 KB | login form integration; groups: LoginForm |
| 20 | async_fuzz_test.dart | 99 | 2 | 3.2 KB | async fuzz |
| 21 | builders_fuzz_test.dart | 50 | 1 | 1.6 KB | builders fuzz |
| 22 | listeners_fuzz_test.dart | 55 | 1 | 1.7 KB | listeners fuzz |
| 23 | replay_probes_fuzz_test.dart | 133 | 3 | 4.8 KB | replay probes fuzz |
| 24 | scope_fuzz_test.dart | 59 | 1 | 2.0 KB | scope fuzz |
| 25 | selectors_fuzz_test.dart | 65 | 1 | 2.2 KB | selectors fuzz |
| 26 | counter_app_golden_test.dart | 53 | 1 | 1.6 KB | counter app golden |
| 27 | feature_goldens_test.dart | 125 | 5 | 3.7 KB | feature goldens; groups: feature goldens |
| 28 | use_cell_async_test.dart | 253 | 13 | 8.3 KB | use cell async; groups: useCellAsync |
| 29 | use_cell_listener_test.dart | 180 | 7 | 5.8 KB | use cell listener; groups: useCellListener |
| 30 | use_cell_test.dart | 426 | 20 | 13.6 KB | use cell; groups: useCell, useCellValue, useCellNotifier |
| 31 | cell_list_view_test.dart | 282 | 12 | 8.5 KB | cell list view; groups: CellListView.builder, CellListView.keyed |
| 32 | _bloc_snippets_test.dart | 127 | 5 | 4.2 KB | bloc snippets; groups: MigratingFrom-Bloc.md — Section 3 (Cubit → Cell.state), MigratingFrom-Bloc.md — Section 4 (Bloc → Cell.state + ingress), MigratingFrom-Bloc.md — Section 6 (DI), MigratingFrom-Bloc.md — Section 7 (testing), MigratingFrom-Bloc.md — Section 8 (hydration) |
| 33 | _extracted_test.dart | 203 | 15 | 6.2 KB | extracted |
| 34 | _riverpod_snippets_test.dart | 229 | 11 | 7.5 KB | riverpod snippets; groups: MigratingFrom-Riverpod.md — Section 3 (state primitives), MigratingFrom-Riverpod.md — Section 4 (derived state), MigratingFrom-Riverpod.md — Section 5 (async), MigratingFrom-Riverpod.md — Section 6 (widgets), MigratingFrom-Riverpod.md — Section 7 (DI), MigratingFrom-Riverpod.md — Section 8 (testing) |
| 35 | migration_test.dart | 202 | 9 | 6.8 KB | migration; groups: Provider fixtures, Riverpod fixtures, Bloc fixtures |
| 36 | pulse_delivery_test.dart | 43 | 5 | 1.5 KB | pulse delivery; groups: seedFromRetained, isCollectionLike |
| 37 | restorable_cell_test.dart | 582 | 19 | 17.4 KB | restorable cell; groups: RestorableCell, restoration integration |
| 38 | seed_paths_test.dart | 290 | 12 | 8.9 KB | seed paths; groups: CellValueBuilder seeds from retained pulses, CellAsyncBuilder seeds from retained pulses, asValueCell seeds from retained pulses, asStream seeds from retained pulses |
| 39 | soak_test.dart | 231 | 1 | 7.3 KB | soak |
| 40 | cell_test_harness_test.dart | 153 | 16 | 4.6 KB | cell harness; groups: CellTestHarness |
| 41 | emit_and_settle_test.dart | 95 | 6 | 3.2 KB | emit and settle; groups: emitAndSettle, emitAndPump |
| 42 | expect_cell_golden_test.dart | 73 | 3 | 2.4 KB | expect cell golden; groups: expectCellGolden |
| 43 | expect_cell_value_test.dart | 26 | 2 | 0.9 KB | expect cell value; groups: expectCellValue |
| 44 | pump_cell_test.dart | 52 | 4 | 1.7 KB | pump cell; groups: pumpCell |
| 45 | pump_with_cells_test.dart | 82 | 5 | 2.7 KB | pump with cells; groups: pumpWithCells |
| 46 | record_pulses_test.dart | 82 | 6 | 2.6 KB | record pulses; groups: recordPulses |
| **Total** | | **8,320** | **365** | **258.7 KB** | |

---

## Source Under Test (`lib/`)

The whole binding surface is inventoried: the top-level barrels, the widget layer, and the devtools / forms / hooks / testing sub-libraries.

| Area | Files | Lines | Size |
|------|------:|------:|-----:|
| top-level barrels (`cell_flutter.dart`, `hooks.dart`, `testing.dart`) | 3 | 370 | 17.5 KB |
| `lib/src/` — widget layer | 14 | 3,637 | 149.1 KB |
| `lib/src/devtools/` — in-app Cell Inspector | 2 | 528 | 16.1 KB |
| `lib/src/forms/` — form bindings | 3 | 378 | 12.2 KB |
| `lib/src/hooks/` — `flutter_hooks` integration | 4 | 774 | 34.0 KB |
| `lib/src/testing/` — widget-test surface | 7 | 1,408 | 62.1 KB |

| File | Lines | Size |
|------|------:|-----:|
| `lib/cell_flutter.dart` | 174 | 8.7 KB |
| `lib/hooks.dart` | 79 | 3.5 KB |
| `lib/src/cell_as_value.dart` | 264 | 12.0 KB |
| `lib/src/cell_async_builder.dart` | 393 | 16.7 KB |
| `lib/src/cell_builder.dart` | 271 | 11.6 KB |
| `lib/src/cell_error_boundary.dart` | 199 | 7.3 KB |
| `lib/src/cell_list_view.dart` | 221 | 7.8 KB |
| `lib/src/cell_listener.dart` | 299 | 11.3 KB |
| `lib/src/cell_notifier.dart` | 216 | 9.4 KB |
| `lib/src/cell_restoration.dart` | 271 | 9.6 KB |
| `lib/src/cell_restoration_scope.dart` | 248 | 9.3 KB |
| `lib/src/cell_scope.dart` | 321 | 13.7 KB |
| `lib/src/cell_selector.dart` | 205 | 9.0 KB |
| `lib/src/cell_stream.dart` | 210 | 8.9 KB |
| `lib/src/cell_value_builder.dart` | 297 | 12.0 KB |
| `lib/src/devtools/cell_flutter_devtools.dart` | 288 | 8.7 KB |
| `lib/src/devtools/cell_inspector_overlay.dart` | 240 | 7.4 KB |
| `lib/src/forms/cell_editing_controller.dart` | 113 | 3.9 KB |
| `lib/src/forms/cell_form_field.dart` | 136 | 4.1 KB |
| `lib/src/forms/cell_text_field.dart` | 129 | 4.2 KB |
| `lib/src/hooks/use_cell.dart` | 301 | 13.4 KB |
| `lib/src/hooks/use_cell_async.dart` | 200 | 8.8 KB |
| `lib/src/hooks/use_cell_listener.dart` | 176 | 7.5 KB |
| `lib/src/hooks/use_cell_notifier.dart` | 97 | 4.3 KB |
| `lib/src/pulse_delivery.dart` | 222 | 10.6 KB |
| `lib/src/testing/cell_test_harness.dart` | 350 | 13.9 KB |
| `lib/src/testing/emit_and_settle.dart` | 166 | 8.0 KB |
| `lib/src/testing/expect_cell_golden.dart` | 218 | 10.0 KB |
| `lib/src/testing/expect_cell_value.dart` | 132 | 5.8 KB |
| `lib/src/testing/pump_cell.dart` | 143 | 6.3 KB |
| `lib/src/testing/pump_with_cells.dart` | 144 | 6.4 KB |
| `lib/src/testing/record_pulses.dart` | 255 | 11.7 KB |
| `lib/testing.dart` | 117 | 5.3 KB |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: cell_as_value_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |
| Cell.asValueCell | |

**Tests**

- mirror emits the same values as the source
- initial seeds the first value
- type-mismatched payloads are reported through the zone
- dispose stops mirroring
- nullable V emits null
- error pulses are skipped
- dispose is idempotent

### File 2: cell_async_builder_test.dart (14 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 14 |
| CellAsyncBuilder | |

**Tests**

- nothing before first pulse
- active + data after first data pulse
- active + error after error pulse
- initialSnapshot seeds first frame
- type mismatch becomes an error snapshot
- nullable V accepts a null payload as data
- error pulse with null payload uses a placeholder error
- cell swap resets to nothing and rebinds
- renders fromFuture success as data
- renders fromFuture failure as error
- asyncMap mapper failure keeps the last successful value
- dispose stops egress
- defers a pulse emitted during build
- drops a pending deferred pulse when disposed before the flush

### File 3: cell_builder_hot_reload_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |
| CellBuilder hot-reload warning | |

**Tests**

- warns after 3 consecutive cell swaps
- does not warn on same cell rebuild
- counter resets on non-swap

### File 4: cell_builder_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| CellBuilder | |
| ValueCell.builder extension | |

**Tests**

- renders initial value
- rebuilds on cell update
- renders null initial value
- rebinds when cell swaps
- multiple builders over the same cell all rebuild
- read-only view propagates reads and rejects mutation
- emit during build raises a framework error
- builder errors propagate to Flutter error widget
- works as shorthand

### File 5: cell_listener_test.dart (18 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 18 |
| CellListener | |

**Tests**

- sync dispatch from event handler
- defers pulse emitted during build
- multiple mid-frame pulses delivered in order
- defers pulse during midFrameMicrotasks
- listener survives onPulse throw
- rebinds on cell swap
- cell swap clears pending queue
- onPulse identity change does not rebind
- dispose stops further callbacks
- clears pending on dispose
- 100 rebuilds with the same cell do not churn egress
- context has access to Navigator
- async onPulse with mounted check
- reads from non-ValueCell sources
- handles error pulses without casting crash
- rejects invalidated cell
- multiple listeners over the same cell all fire
- child is not rebuilt on pulse

### File 6: cell_notifier_test.dart (10 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 10 |
| CellNotifier | |

**Tests**

- reflects initial cell value
- null initial value
- fires listener on cell update
- reflects a null emission after a non-null value
- deduplicates equal updates
- dispose stops listening
- dispose is idempotent
- set value throws UnsupportedError
- rejects invalidated cell
- works with a read-only unmodifiable view

### File 7: cell_scope_shadow_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |
| CellScope nested shadow warning | |

**Tests**

- warns when symbol shadowed
- does not warn when symbol unique
- warns once per symbol

### File 8: cell_scope_test.dart (18 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 18 |
| CellScope.of | |
| CellScope.maybeOf | |
| CellScope.valueOf | |
| CellScope.updateShouldNotify | |
| CellScope nested | |

**Tests**

- returns registered cell
- throws StateError on type mismatch
- debug assert on unknown id
- debug assert when no scope exists
- returns non-ValueCell registrations as-is
- returns null for unknown id
- returns null when no scope exists
- throws on type mismatch
- returns ValueCell for ValueCell registration
- throws for non-ValueCell registration
- throws for wrong ValueCell type parameter
- rebuilds when cell swapped
- does not rebuild when map is re-created with same cells
- rebuilds when cell added
- rebuilds when cell removed
- does not rebuild when a cell is swapped for an equal deputy
- inner scope shadows outer
- outer cell still reachable from outer-scope context

### File 9: cell_selector_collection_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |
| CellSelector collection warning | |

**Tests**

- warns on collection without equals
- does not warn with equals

### File 10: cell_selector_test.dart (11 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 11 |
| CellSelector | |

**Tests**

- rebuilds when the selected slice changes
- does not rebuild when the slice is unchanged
- selector change with same cell recomputes immediately
- custom equals with listEquals
- rebinds on cell swap
- nullable V handled in select
- multiple emissions in one frame cause a single rebuild
- select is called once per emission
- no rebuild after dispose
- select throwing is contained by the framework
- defers slice recompute for a pulse emitted during build

### File 11: cell_stream_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| Cell.asStream | |

**Tests**

- sync emission matches observe sequence
- seeds a ValueCell current value on listen
- async emission with sync: false
- error pulse with emitErrors: true becomes addError
- error pulse with emitErrors: false is skipped
- cancel stops the egress
- second listen throws (single-subscription)
- null payload is emitted as null
- type mismatch becomes addError

### File 12: cell_value_builder_test.dart (13 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 13 |
| CellValueBuilder | |

**Tests**

- mirrors Cell.derive output
- mirrors Cell.synthesis output
- initial seeds the first frame
- nullable V mirrors a null payload
- error pulse silently skipped by default
- error pulse reported when emitErrors is true
- reports a retained error pulse during seed when emitErrors is true 
- skips a retained error pulse during seed when emitErrors is false 
- type mismatch reported even when emitErrors is false
- cell swap resets the mirror
- dispose stops egress
- defers a pulse emitted during build
- drops a pending deferred pulse when disposed before the flush

### File 13: overlay_test.dart (16 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 16 |
| CellFlutterDevTools registry | |
| CellInspectorOverlay | |

**Tests**

- enable() is idempotent
- register before enable throws StateError
- registry before enable throws StateError
- registers and exposes an entry with value and type
- duplicate symbol throws StateError
- records pulses newest-first with a cap of 10
- unregister releases the observation link
- clear releases every link but never disposes cells
- registry notifies on register, pulse, and clear
- entry values survive broken toString and truncate long values
- renders the child unchanged when disabled
- shows the floating button when enabled
- lists registered cells and expands pulse history
- wraps a whole MaterialApp (no Directionality above)
- clear empties the panel and close hides it
- panel shows non-value cells as null

### File 14: cell_error_boundary_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| CellErrorBoundary | |

**Tests**

- renders onError for an invalidated-cell error
- a cell invalidated mid-frame is contained
- does not intercept the cell_flutter report channel
- reset recovers and re-renders the child
- onReset fires on reset
- nested boundaries are independent
- FlutterError.onError is restored on dispose
- a second error while the fallback is showing is forwarded
- captures an error reported outside a build phase

### File 15: error_pulse_sources_test.dart (12 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 12 |
| fromFuture | |
| fromStream | |
| asyncMap | |
| recordPulses | |
| CellAsyncBuilder error seeding (C1 x C2) | |

**Tests**

- emits an error pulse on future failure
- emits a data pulse on future success
- does not emit an error pulse on stream error 
- does not emit an error pulse on stream error 
- retains the last data pulse emitted before a stream error
- does not emit an error pulse when the mapper throws
- does not emit an error pulse when the mapper returns 
- retains the last mapped result emitted before a later failure
- captures the error pulse from a failed fromFuture
- observes no error pulse from a failing asyncMap
- observes no error pulse from a failing fromStream
- a completed failed fromFuture seeds an error snapshot

### File 16: cell_editing_controller_test.dart (8 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 8 |
| CellEditingController | |

**Tests**

- initializes from the cell current value
- typing in the controller updates the cell
- cell update updates the controller text
- same-value cell write does not touch the controller
- disposal stops the cell sync direction
- selection preserved across a same-length replacement
- selection moves to the end across a length-changing replacement
- repeated alternating writes converge (no loop)

### File 17: cell_form_field_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |
| CellFormField | |

**Tests**

- renders the cell current value
- didChange updates the cell
- cell update updates the field state
- Form.validate() calls the validator
- custom T (DateTime) round-trips
- cell swap rebinds

### File 18: cell_text_field_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |
| CellTextField | |

**Tests**

- renders the cell current value
- typing updates the cell
- cell update re-renders the field
- validator runs on Form.validate()
- focus is preserved across cell updates
- cell swap rebinds the controller
- disposal stops listeners

### File 19: login_form_integration_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| LoginForm | |

**Tests**

- typing in each field updates its cell
- validate() rejects empty email and mismatched confirm
- valid submission runs onSubmit
- hot restart preserves the field values

### File 20: async_fuzz_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- CellAsyncBuilder asyncMap storm
- CellAsyncBuilder fromFuture cell swaps

### File 21: builders_fuzz_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- CellBuilder fuzz

### File 22: listeners_fuzz_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- CellListener fuzz

### File 23: replay_probes_fuzz_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- debounce fuzz: at most one emission per settled burst
- throttle fuzz: emission rate respects the window
- fromFuture / fromStream fuzz: well-formed snapshots

### File 24: scope_fuzz_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- CellScope fuzz

### File 25: selectors_fuzz_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- CellSelector fuzz

### File 26: counter_app_golden_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- counter app golden

### File 27: feature_goldens_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| feature goldens | |

**Tests**

- CellTextField empty
- CellTextField filled
- CellErrorBoundary fallback
- CellListView filled
- CellListView empty

### File 28: use_cell_async_test.dart (13 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 13 |
| useCellAsync | |

**Tests**

- nothing before first pulse
- seeds from a ValueCell current value
- seeds from a completed fromFuture
- seeds from a fromStream after one value
- seeds from an asyncMap after one value
- seeds from a derive after one emission
- active+data after pulse
- active+error after error pulse
- nullable V accepts a null payload as data
- type mismatch becomes an error snapshot
- initialSnapshot seeds
- cell swap rebinds
- snapshot persists across cell swap (documented divergence)

### File 29: use_cell_listener_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |
| useCellListener | |

**Tests**

- sync dispatch from event handler
- defers mid-frame pulse
- onPulse throw is contained
- fresh onPulse closure does not churn
- cell swap rebinds
- cell swap clears pending queue
- does not rebuild widget

### File 30: use_cell_test.dart (20 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 20 |
| useCell | |
| useCellValue | |
| useCellNotifier | |

**Tests**

- renders initial selected value
- debug asserts when select returns a collection without equals
- does not assert for a collection selection with equals
- debug asserts when a changed select returns a collection without equals
- rebuilds when selected slice changes
- does not rebuild when unselected slice changes
- selector change recomputes selected
- custom equals for lists
- null handling
- cell swap rebinds
- returns the new cell\
- keying the HookWidget resets the whole hook state
- non-collection select without equals works without 
- dispose stops subscription
- fresh select closure does not churn subscription
- multiple useCell calls in one widget
- rebuilds on every value change
- returns a notifier bound to cell
- dispose notifier on unmount
- rebinds when cell changes

### File 31: cell_list_view_test.dart (12 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 12 |
| CellListView.builder | |
| CellListView.keyed | |

**Tests**

- renders the list items
- updates when the cell list changes
- a cell that has never emitted renders an empty list
- composes with per-item CellBuilder
- renders the list items
- append rebuilds only the new item
- remove drops only the removed item
- replace rebuilds only the replaced item
- reorder preserves item state through keys
- duplicate itemKey throws StateError
- scroll position survives a list mutation
- 10,000 items render and scroll to the end

### File 32: _bloc_snippets_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| MigratingFrom-Bloc.md — Section 3 (Cubit → Cell.state) | |
| MigratingFrom-Bloc.md — Section 4 (Bloc → Cell.state + ingress) | |
| MigratingFrom-Bloc.md — Section 6 (DI) | |
| MigratingFrom-Bloc.md — Section 7 (testing) | |
| MigratingFrom-Bloc.md — Section 8 (hydration) | |

**Tests**

- Cubit → Cell.state + CellBuilder
- event validation moves into refine and testRule
- BlocProvider → CellScope
- blocTest → recordPulses
- minimal load-on-init persistence pattern

### File 33: _extracted_test.dart (15 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 15 |

**Tests**

- MigratingFrom-Bloc.md line 50
- MigratingFrom-Bloc.md line 57
- MigratingFrom-Bloc.md line 88
- MigratingFrom-Bloc.md line 159
- increment updates the cell
- MigratingFrom-Bloc.md line 207
- MigratingFrom-Riverpod.md line 62
- MigratingFrom-Riverpod.md line 91
- MigratingFrom-Riverpod.md line 105
- MigratingFrom-Riverpod.md line 123
- MigratingFrom-Riverpod.md line 147
- MigratingFrom-Riverpod.md line 161
- MigratingFrom-Riverpod.md line 202
- MigratingFrom-Riverpod.md line 233
- counter renders

### File 34: _riverpod_snippets_test.dart (11 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 11 |
| MigratingFrom-Riverpod.md — Section 3 (state primitives) | |
| MigratingFrom-Riverpod.md — Section 4 (derived state) | |
| MigratingFrom-Riverpod.md — Section 5 (async) | |
| MigratingFrom-Riverpod.md — Section 6 (widgets) | |
| MigratingFrom-Riverpod.md — Section 7 (DI) | |
| MigratingFrom-Riverpod.md — Section 8 (testing) | |

**Tests**

- StateProvider → Cell.state
- Notifier → Cell.state with testRule
- Provider → Cell.derive
- derived Cell requires CellValueBuilder for display
- Provider → Cell.synthesis
- FutureProvider → Cell.fromFuture emits error pulse
- StreamProvider → Cell.fromStream does NOT emit error pulse
- AsyncValue → AsyncSnapshot via CellAsyncBuilder
- ref.listen → CellListener branches on error type
- ProviderScope → CellScope
- overrideWithValue → pumpWithCells

### File 35: migration_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| Provider fixtures | |
| Riverpod fixtures | |
| Bloc fixtures | |

**Tests**

- counter renders identically before and after
- login renders identically before and after
- todo renders identically before and after
- counter renders identically before and after
- login renders identically before and after
- todo renders identically before and after
- counter renders identically before and after
- login renders identically before and after
- todo renders identically before and after

### File 36: pulse_delivery_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| seedFromRetained | |
| isCollectionLike | |

**Tests**

- falls back to initial for a plain cell
- serves a ValueCell current value
- falls back to initial for a mismatched retained payload
- accepts a null retained payload for a nullable V
- reports Map and Iterable, not String or scalars

### File 37: restorable_cell_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| RestorableCell | |
| restoration integration | |

**Tests**

- fresh install falls back to initial
- persisted bucket restores the value (restored wins)
- primitive types round-trip into the bucket
- non-primitive value without codecs throws UnsupportedError
- custom codecs round-trip a custom object
- restored value equal to initial does not emit a pulse
- duplicate restorationId throws StateError
- registering the same cell twice is idempotent
- unregister removes the value, re-register works
- scope disposal unregisters cleanly
- nested scopes restore independently
- multiple cells in one scope restore
- cleared data falls back to initial
- wrong-typed restored primitive throws UnsupportedError
- of() throws when no CellRestorationScope encloses the 
- a changed restoration id re-restores registered cells
- value writes after restoration propagate through the graph
- claims a bucket from the surrounding RestorationScope
- CounterApp survives a process-kill simulation

### File 38: seed_paths_test.dart (12 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 12 |
| CellValueBuilder seeds from retained pulses | |
| CellAsyncBuilder seeds from retained pulses | |
| asValueCell seeds from retained pulses | |
| asStream seeds from retained pulses | |

**Tests**

- 1. fromFuture subscribed after completion renders 42
- 2. fromFuture subscribed before completion shows initial 
- 3. derive subscribed after emission renders the derived 
- 4. asyncMap subscribed after emission renders the mapped 
- 5. fromFuture subscribed after completion has data 42
- 6. fromFuture subscribed before completion shows nothing 
- 7. fromStream subscribed after one value has data
- 8. asyncMap subscribed after one value has data
- 9. derive subscribed after emission mirrors the derived value
- 10. fromFuture subscribed after completion mirrors 42
- 11. derive subscribed after emission emits the derived value 
- 12. fromFuture subscribed after completion emits 42 first

### File 39: soak_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- 10k-iteration soak with control phase

### File 40: cell_test_harness_test.dart (16 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 16 |
| CellTestHarness | |

**Tests**

- cell() returns typed cell
- cell() throws on wrong type
- cell() for missing id throws
- valueCell() returns typed ValueCell
- valueCell() for missing id throws
- valueCell() throws for non-ValueCell registration
- pump() registers all cells in CellScope
- emitAndSettle() updates cell
- dispose() stops recorders
- dispose() is idempotent
- add() after dispose throws
- pump() after dispose throws
- emitAndSettle() after dispose throws
- recordPulses() for missing id throws
- recordPulses() after dispose throws
- cells getter returns the registered cells

### File 41: emit_and_settle_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |
| emitAndSettle | |
| emitAndPump | |

**Tests**

- updates cell and settles
- settles nested rebuilds
- null value
- pumps a single frame
- pumps a duration
- does not wait for settle

### File 42: expect_cell_golden_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |
| expectCellGolden | |

**Tests**

- golden with text
- golden with registration in CellScope
- two-golden workflow: mutate the cell directly between captures

### File 43: expect_cell_value_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |
| expectCellValue | |

**Tests**

- matches with matcher
- failure throws TestFailure with reason

### File 44: pump_cell_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| pumpCell | |

**Tests**

- pumps a CellBuilder
- rebuilds on cell update
- wraps in MaterialApp + Scaffold
- nullable V

### File 45: pump_with_cells_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| pumpWithCells | |

**Tests**

- registers cells in CellScope
- default wrapper provides MaterialApp + Scaffold
- custom wrapper overrides default
- multiple cells registered
- unregistered id throws

### File 46: record_pulses_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |
| recordPulses | |

**Tests**

- records sync pulses
- records derived cell pulses
- records error pulses from fromFuture
- stop releases egress
- stop is idempotent
- clear resets without stopping

---

## Runtime Verification Status

Working directory: `packages/cell_flutter` (package-relative; host paths omitted).

`flutter test` discovers `*_test.dart` automatically; the explicit list is kept for the report and for CI (it excludes shared helpers such as `test/fuzz/fuzz_harness.dart` that have no `main()`).

```bash
flutter pub get
flutter test \
  test/cell_as_value_test.dart \
  test/cell_async_builder_test.dart \
  test/cell_builder_hot_reload_test.dart \
  test/cell_builder_test.dart \
  test/cell_listener_test.dart \
  test/cell_notifier_test.dart \
  test/cell_scope_shadow_test.dart \
  test/cell_scope_test.dart \
  test/cell_selector_collection_test.dart \
  test/cell_selector_test.dart \
  test/cell_stream_test.dart \
  test/cell_value_builder_test.dart \
  test/devtools/overlay_test.dart \
  test/error_boundary/cell_error_boundary_test.dart \
  test/error_pulse_sources_test.dart \
  test/forms/cell_editing_controller_test.dart \
  test/forms/cell_form_field_test.dart \
  test/forms/cell_text_field_test.dart \
  test/forms/login_form_integration_test.dart \
  test/fuzz/async_fuzz_test.dart \
  test/fuzz/builders_fuzz_test.dart \
  test/fuzz/listeners_fuzz_test.dart \
  test/fuzz/replay_probes_fuzz_test.dart \
  test/fuzz/scope_fuzz_test.dart \
  test/fuzz/selectors_fuzz_test.dart \
  test/golden/counter_app_golden_test.dart \
  test/golden/feature_goldens_test.dart \
  test/hooks/use_cell_async_test.dart \
  test/hooks/use_cell_listener_test.dart \
  test/hooks/use_cell_test.dart \
  test/list_view/cell_list_view_test.dart \
  test/migration/_bloc_snippets_test.dart \
  test/migration/_extracted_test.dart \
  test/migration/_riverpod_snippets_test.dart \
  test/migration/migration_test.dart \
  test/pulse_delivery_test.dart \
  test/restoration/restorable_cell_test.dart \
  test/seed_paths_test.dart \
  test/soak/soak_test.dart \
  test/testing/cell_test_harness_test.dart \
  test/testing/emit_and_settle_test.dart \
  test/testing/expect_cell_golden_test.dart \
  test/testing/expect_cell_value_test.dart \
  test/testing/pump_cell_test.dart \
  test/testing/pump_with_cells_test.dart \
  test/testing/record_pulses_test.dart
```

### Last `flutter test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 364 | 0 | 1 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
:18 +357 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:18 +358 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:18 +359 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:18 +360 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:18 +361 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:18 +362 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:19 +362 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:20 +362 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:21 +362 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:22 +362 ~1: ./test/list_view/cell_list_view_test.dart: CellListView.keyed 10,000 items render and scroll to the end                              
00:22 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:23 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:24 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:25 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:26 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:27 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:28 +363 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:28 +364 ~1: ./test/soak/soak_test.dart: 10k-iteration soak with control phase                                                                    
00:28 +364 ~1: 1 skipped test.                                                                                                                                                                         

00:28 +364 ~1: All other tests passed!
```

</details>

### Line Coverage (`lib/`)

**Overall: 928 / 928 lines = 100.0%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/cell_as_value.dart` | 14 | 14 | 100.0 |
| `lib/src/cell_async_builder.dart` | 66 | 66 | 100.0 |
| `lib/src/cell_builder.dart` | 30 | 30 | 100.0 |
| `lib/src/cell_error_boundary.dart` | 41 | 41 | 100.0 |
| `lib/src/cell_list_view.dart` | 45 | 45 | 100.0 |
| `lib/src/cell_listener.dart` | 47 | 47 | 100.0 |
| `lib/src/cell_notifier.dart` | 20 | 20 | 100.0 |
| `lib/src/cell_restoration.dart` | 45 | 45 | 100.0 |
| `lib/src/cell_restoration_scope.dart` | 47 | 47 | 100.0 |
| `lib/src/cell_scope.dart` | 34 | 34 | 100.0 |
| `lib/src/cell_selector.dart` | 38 | 38 | 100.0 |
| `lib/src/cell_stream.dart` | 25 | 25 | 100.0 |
| `lib/src/cell_value_builder.dart` | 64 | 64 | 100.0 |
| `lib/src/devtools/cell_flutter_devtools.dart` | 65 | 65 | 100.0 |
| `lib/src/devtools/cell_inspector_overlay.dart` | 73 | 73 | 100.0 |
| `lib/src/forms/cell_editing_controller.dart` | 29 | 29 | 100.0 |
| `lib/src/forms/cell_form_field.dart` | 37 | 37 | 100.0 |
| `lib/src/forms/cell_text_field.dart` | 25 | 25 | 100.0 |
| `lib/src/hooks/use_cell.dart` | 31 | 31 | 100.0 |
| `lib/src/hooks/use_cell_async.dart` | 21 | 21 | 100.0 |
| `lib/src/hooks/use_cell_listener.dart` | 29 | 29 | 100.0 |
| `lib/src/hooks/use_cell_notifier.dart` | 3 | 3 | 100.0 |
| `lib/src/pulse_delivery.dart` | 17 | 17 | 100.0 |
| `lib/src/testing/cell_test_harness.dart` | 40 | 40 | 100.0 |
| `lib/src/testing/emit_and_settle.dart` | 6 | 6 | 100.0 |
| `lib/src/testing/expect_cell_golden.dart` | 12 | 12 | 100.0 |
| `lib/src/testing/expect_cell_value.dart` | 4 | 4 | 100.0 |
| `lib/src/testing/pump_cell.dart` | 4 | 4 | 100.0 |
| `lib/src/testing/pump_with_cells.dart` | 4 | 4 | 100.0 |
| `lib/src/testing/record_pulses.dart` | 12 | 12 | 100.0 |

---

## Recommendations

1. Keep this report generated — do not hand-count `test(` / `testWidgets(`./ `testWidgets(`.
2. CI should run `flutter test` from the package root (or the explicit file list above) so widget tests, goldens, fuzz, and soak all run.
3. Golden suites (`test/golden/`) are regeneration-checked — run the golden regeneration task and commit the images when a widget's rendering changes.
4. The fuzz and soak suites are CI-only or long-running; keep the deterministic smoke variants in the default `flutter test` run.
5. Coverage targets should be tracked per sub-library (`lib/src/`, `lib/src/hooks/`, `lib/src/testing/`, …), not just the whole `lib/` average.
6. Migration-guide fixtures (`test/migration/`) verify every before/after snippet pair compiles and renders — keep them in sync when the guides change.

---

## Appendix: File Locations

```
test/
├── cell_as_value_test.dart  (7 tests, 2.6 KB, 93 lines)
├── cell_async_builder_test.dart  (14 tests, 11.8 KB, 390 lines)
├── cell_builder_hot_reload_test.dart  (3 tests, 2.6 KB, 82 lines)
├── cell_builder_test.dart  (9 tests, 6.2 KB, 206 lines)
├── cell_listener_test.dart  (18 tests, 15.5 KB, 530 lines)
├── cell_notifier_test.dart  (10 tests, 4.2 KB, 143 lines)
├── cell_scope_shadow_test.dart  (3 tests, 3.3 KB, 99 lines)
├── cell_scope_test.dart  (18 tests, 11.1 KB, 392 lines)
├── cell_selector_collection_test.dart  (2 tests, 1.5 KB, 40 lines)
├── cell_selector_test.dart  (11 tests, 8.9 KB, 312 lines)
├── cell_stream_test.dart  (9 tests, 3.6 KB, 132 lines)
├── cell_value_builder_test.dart  (13 tests, 9.4 KB, 344 lines)
├── devtools/overlay_test.dart  (16 tests, 8.1 KB, 231 lines)
├── error_boundary/cell_error_boundary_test.dart  (9 tests, 9.1 KB, 280 lines)
├── error_pulse_sources_test.dart  (12 tests, 7.3 KB, 229 lines)
├── forms/cell_editing_controller_test.dart  (8 tests, 3.8 KB, 109 lines)
├── forms/cell_form_field_test.dart  (6 tests, 4.3 KB, 137 lines)
├── forms/cell_text_field_test.dart  (7 tests, 4.1 KB, 131 lines)
├── forms/login_form_integration_test.dart  (4 tests, 6.2 KB, 190 lines)
├── fuzz/async_fuzz_test.dart  (2 tests, 3.2 KB, 99 lines)
├── fuzz/builders_fuzz_test.dart  (1 tests, 1.6 KB, 50 lines)
├── fuzz/listeners_fuzz_test.dart  (1 tests, 1.7 KB, 55 lines)
├── fuzz/replay_probes_fuzz_test.dart  (3 tests, 4.8 KB, 133 lines)
├── fuzz/scope_fuzz_test.dart  (1 tests, 2.0 KB, 59 lines)
├── fuzz/selectors_fuzz_test.dart  (1 tests, 2.2 KB, 65 lines)
├── golden/counter_app_golden_test.dart  (1 tests, 1.6 KB, 53 lines)
├── golden/feature_goldens_test.dart  (5 tests, 3.7 KB, 125 lines)
├── hooks/use_cell_async_test.dart  (13 tests, 8.3 KB, 253 lines)
├── hooks/use_cell_listener_test.dart  (7 tests, 5.8 KB, 180 lines)
├── hooks/use_cell_test.dart  (20 tests, 13.6 KB, 426 lines)
├── list_view/cell_list_view_test.dart  (12 tests, 8.5 KB, 282 lines)
├── migration/_bloc_snippets_test.dart  (5 tests, 4.2 KB, 127 lines)
├── migration/_extracted_test.dart  (15 tests, 6.2 KB, 203 lines)
├── migration/_riverpod_snippets_test.dart  (11 tests, 7.5 KB, 229 lines)
├── migration/migration_test.dart  (9 tests, 6.8 KB, 202 lines)
├── pulse_delivery_test.dart  (5 tests, 1.5 KB, 43 lines)
├── restoration/restorable_cell_test.dart  (19 tests, 17.4 KB, 582 lines)
├── seed_paths_test.dart  (12 tests, 8.9 KB, 290 lines)
├── soak/soak_test.dart  (1 tests, 7.3 KB, 231 lines)
├── testing/cell_test_harness_test.dart  (16 tests, 4.6 KB, 153 lines)
├── testing/emit_and_settle_test.dart  (6 tests, 3.2 KB, 95 lines)
├── testing/expect_cell_golden_test.dart  (3 tests, 2.4 KB, 73 lines)
├── testing/expect_cell_value_test.dart  (2 tests, 0.9 KB, 26 lines)
├── testing/pump_cell_test.dart  (4 tests, 1.7 KB, 52 lines)
├── testing/pump_with_cells_test.dart  (5 tests, 2.7 KB, 82 lines)
├── testing/record_pulses_test.dart  (6 tests, 2.6 KB, 82 lines)
```

**Total lines of test code:** 8,320

*Generated 2026-11-19 by generate_test_verification.py*
