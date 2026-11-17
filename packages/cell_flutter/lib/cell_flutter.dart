// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Flutter widget bindings for Mitosis [Cell]s.
///
/// `cell_flutter` is the **Widget Layer** of the Mitosis reactive stack.
/// The core `cell` package provides the graph — cells, pulses, integrity
/// gates, forensics, transactions — and this library binds that graph to
/// Flutter's widget tree. It supplies the widget, notifier, scope, stream,
/// and mirror primitives you need to render cells and react to their
/// pulses, and it re-exports `package:cell/cell.dart` so a single import
/// is sufficient in most application code.
///
/// ### Why it is used
/// - **State display**: `CellBuilder`, `CellSelector`, and
///   `CellValueBuilder` render a cell's current value, with a choice of
///   rebuild granularity (per-value, per-slice, or any-`Cell`).
/// - **Side effects**: `CellListener` runs one-shot imperatives (navigation,
///   snackbars, haptics, analytics) per pulse, without rebuilding.
/// - **Async state**: `CellAsyncBuilder` renders async cells
///   (`fromFuture`, `fromStream`, `asyncMap`) as `AsyncSnapshot`s.
/// - **App-level DI**: `CellScope` registers a small set of well-known
///   cells (`#auth`, `#theme`) for subtree lookup by `Symbol`.
/// - **Interop bridges**: `CellAsStream` (cell → `Stream`) and
///   `CellAsValue` (cell → `ValueCell` mirror) reach out of the graph to
///   the wider Dart and Flutter ecosystems.
/// - **Listenable adapters**: `CellNotifier` exposes a `ValueCell` as a
///   Flutter `ValueNotifier` for composition with `ValueListenableBuilder`
///   and other `Listenable`-based widgets.
///
/// ### How it works
/// The binding is layered on three primitives, all from the core `cell`
/// package:
/// 1. **`Cell.observe`** — the graph-level pulse subscription. Every
///    widget and helper in this library opens exactly one of these on the
///    cell it is given.
/// 2. **`Pulse`** — the signal shape every widget decodes. Data pulses
///    carry a `V`; error pulses carry an `Object` and a `type == 'error'`
///    discriminator.
/// 3. **`ValueCell`** — the synchronous-state subtype that widgets needing
///    a current value (`CellBuilder`, `CellSelector`) require.
///
/// Everything else in this library is a layer over those primitives: a
/// `StatefulWidget` that owns an egress, an extension that returns a
/// paired handle, or a builder hook that routes pulses through a selector.
///
/// ### Status
/// **0.7.0 — core hardening, not 1.0.** 0.7.0 is the core-hardening
/// release on top of 0.6.1: `CellValueBuilder` reports retained error
/// pulses during seeding under `emitErrors: true`, `useCellAsync`'s
/// plain-cell seeding is verified across all four async sources, the
/// `useCell` cell-swap doc was corrected against the verified no-flash
/// behavior, and every `lib/src/` doc claim was audited against a test
/// (see the `CHANGELOG.md`
/// 0.7.0 entry). The 1.0.0 gate was evaluated honestly and **failed**:
/// the microbenchmark gate fails for multi-builder trees (see
/// `guide/Benchmarks.md`), the full 30-minute fuzz gate (G6) is carried
/// by CI, and the external-developer usability gate (G10) is still
/// blocked. Verified in this binding: the replay probes for pure state,
/// debounce, throttle, `fromFuture`, and `fromStream` (commit `05b4895d`;
/// full suite 1371 tests, determinism gate 240/240). Concurrent
/// `asyncMap` effect attribution under `concurrency > 0` is tracked
/// separately and is **not** claimed by this binding. Use
/// this package in production with its documented limitations in mind;
/// see `README.md` *Status* and `ARCHITECTURE-flutter.md` §11.
///
/// ### What this library exports
/// **Core re-export**:
/// - `package:cell/cell.dart` — the entire core surface, including
///   `Cell`, `Cell.state`, `Cell.ingress`, `Pulse`, `ValueCell`,
///   `EgressHandle`, `IngressHandle`, `StateHandle`, `Context`,
///   `EphemeralPolicy`, `TestCell`, `Receptor`, `Synapses`, `Nucleus`,
///   and the `Apply*` command/receipt/outcome types.
///
/// **Widgets**:
/// - `CellBuilder<V>` — the primary renderer for a [ValueCell].
/// - `CellSelector<V, S>` — slice-granular rendering for a [ValueCell].
/// - `CellValueBuilder<V>` — renderer for any `Cell` (not just
///   `ValueCell`), including derived and async sources.
/// - `CellListener<V>` — side-effect terminal; no rebuild.
/// - `CellScope` — `InheritedWidget` cell registry, keyed by `Symbol`.
/// - `CellAsyncBuilder<V>` — `AsyncSnapshot`-style rendering for async
///   cells.
///
/// **Adapters and bridges**:
/// - `CellNotifier<V>` — `ValueNotifier` adapter over a [ValueCell].
/// - `CellAsStream` — extension: any `Cell` → `Stream<V?>`.
/// - `CellAsValue` — extension: any `Cell` → `MirroredCell<V>`
///   (a fresh `ValueCell` plus a required `dispose` callback).
/// - `MirroredCell<V>` — the record type returned by `asValueCell`.
///
/// **Fluent extensions**:
/// - `ValueCellBuilder` — extension: `cell.builder((ctx, v) => …)` as
///   sugar for `CellBuilder`.
///
/// **Snapshot helpers** (from `cell_async_builder.dart`, for advanced use
/// — not the primary widget surface):
/// - `snapshotForPulse<V>(pulse)` — pure decoder used by
///   `CellAsyncBuilder`.
/// - `snapshotForCell<V>(cell)` — retained-pulse seed used at subscription
///   time.
///
/// **Not exported here**: the test helpers (`pumpWithCells`, `pumpCell`,
/// `emitAndSettle`, `recordPulses`, `CellTestHarness`,
/// `expectCellValue`, `expectCellGolden`) and the optional
/// `flutter_hooks` integration (`package:cell_flutter/hooks.dart`) live
/// in separate libraries. Import them explicitly when needed — this
/// library deliberately keeps the application-facing surface free of
/// test-only code.
///
/// ### Which widget do I reach for?
/// | Need | Use |
/// |---|---|
/// | Display a `Cell.state` result | `CellBuilder` |
/// | Display one field of a larger object | `CellSelector` |
/// | Display a derived / async / tissue source | `CellValueBuilder` |
/// | Render loading / data / error | `CellAsyncBuilder` |
/// | React (navigate, toast, log) without rebuilding | `CellListener` |
/// | Reach a `Listenable` for Flutter primitives | `CellNotifier` |
/// | Bridge out to `Stream` | `CellAsStream.asStream` |
/// | Bridge out to a `ValueCell` mirror | `CellAsValue.asValueCell` |
/// | Register app-level cells for subtree lookup | `CellScope` |
///
/// ### Design notes
/// - **Explicit lifecycle for mirrors**: `asValueCell` returns a record
///   with a `dispose` callback because mirroring opens an egress that
///   must be released. There is no "auto-dispose" variant — the
///   widget-managed alternative is `CellValueBuilder`.
/// - **Read-only by contract**: `CellNotifier` overrides `value`'s
///   setter to throw. Mutate the cell, not the notifier.
/// - **Build-phase safety by deferral**: widgets that need to defer
///   pulses out of a build phase use a pending queue and a single
///   post-frame flush; widgets that must not defer (e.g. `CellSelector`'s
///   `setState`) route through `runAfterBuild`.
///
/// ### See Also:
/// - `package:cell/cell.dart` — the core graph primitives this library
///   wraps.
/// - `test/error_pulse_sources_test.dart` — the authoritative statement of
///   per-source error-pulse behavior (`fromFuture` emits `type: 'error'`
///   pulses; `fromStream` and `asyncMap` do not).
/// - `test/seed_paths_test.dart` — the seed-behavior coverage for
///   `CellValueBuilder`, `CellAsyncBuilder`, `asValueCell`, `asStream`.
/// - `package:cell_flutter/hooks.dart` — the optional `flutter_hooks`
///   integration (`useCell`, `useCellValue`, `useCellNotifier`,
///   `useCellListener`, `useCellAsync`).
/// - `package:cell_flow` — the instruction-layer library (Flows) that
///   sits above the cell graph.
/// - `package:cell_tissue` — the collection/book library that
///   `CellValueBuilder` can render.
library cell_flutter;

export 'package:cell/cell.dart';
export 'src/cell_notifier.dart';
export 'src/cell_builder.dart';
export 'src/cell_listener.dart';
export 'src/cell_scope.dart';
export 'src/cell_async_builder.dart';
export 'src/cell_selector.dart';
export 'src/cell_value_builder.dart';
export 'src/cell_stream.dart';
export 'src/cell_as_value.dart';
export 'src/cell_restoration.dart';
export 'src/cell_restoration_scope.dart';
export 'src/forms/cell_editing_controller.dart';
export 'src/forms/cell_text_field.dart';
export 'src/forms/cell_form_field.dart';
export 'src/cell_error_boundary.dart';
export 'src/cell_list_view.dart';
export 'src/devtools/cell_flutter_devtools.dart';
export 'src/devtools/cell_inspector_overlay.dart';
