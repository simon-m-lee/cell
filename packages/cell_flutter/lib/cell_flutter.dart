// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Flutter widget bindings for the Cell framework.
///
/// `cell_flutter` is the **widget layer** of the Mitosis reactive stack:
/// the core `cell` package provides the graph — cells, pulses, integrity
/// gates, forensics, transactions — and this library binds that graph to
/// Flutter's widget tree. It re-exports `package:cell/cell.dart` so a
/// single import suffices for most application code.
///
/// ### Why it is used
/// - **State display**: [CellBuilder], [CellSelector], and
///   [CellValueBuilder] render a cell's current value at three rebuild
///   granularities (per-value, per-slice, any-`Cell`); [CellAsyncBuilder]
///   renders async cells as `AsyncSnapshot`s.
/// - **Side effects**: [CellListener] runs one-shot imperatives
///   (navigation, snackbars, haptics, analytics) per pulse, without
///   rebuilding.
/// - **App-level DI**: [CellScope] registers well-known cells (`#auth`,
///   `#theme`) for subtree lookup by `Symbol`.
/// - **Forms and restoration**: [CellTextField], [CellFormField], and
///   [CellEditingController] bind text state to cells;
///   [RestorableCell]/[CellRestorationScope] survive process-kill
///   restoration.
/// - **Containment**: [CellErrorBoundary] isolates failing subtrees;
///   [CellListView] renders big derived-cell collections with builder
///   scrolling.
/// - **Interop bridges**: [CellAsStream] (cell → `Stream`), [CellAsValue]
///   (cell → `ValueCell` mirror), and [CellNotifier] (cell →
///   `ValueNotifier`).
/// - **DevTools**: [CellRegistry] and [CellInspectorOverlay] expose the
///   reactive graph for inspection — re-exported here for 1.x
///   compatibility; prefer `package:cell_flutter/devtools.dart`.
///
/// ### How it works
/// The binding is layered on three core primitives:
/// 1. **`Cell.observe`** — the graph-level pulse subscription. Every
///    widget and helper in this library opens exactly one of these on the
///    cell it is given.
/// 2. **`Pulse`** — the signal shape every widget decodes. Data pulses
///    carry a `V`; error pulses carry an `Object` and a `type == 'error'`
///    discriminator.
/// 3. **`ValueCell`** — the synchronous-state subtype that widgets needing
///    a current value ([CellBuilder], [CellSelector]) require.
///
/// Everything else is a layer over those primitives: a `StatefulWidget`
/// that owns an egress, an extension that returns a paired handle, or a
/// builder hook that routes pulses through a selector.
///
/// ### Status
/// **1.1.0 — stable.** The public API of this barrel and of
/// `hooks.dart` is frozen since 1.0.0 per the semver policy in
/// `CONTRIBUTING.md`; breaking changes require a 2.0.0. The authoritative
/// status, limitations, and benchmark notes live in
/// [README.md *Status*](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/README.md#status)
/// and the [CHANGELOG](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/CHANGELOG.md) —
/// this doc deliberately carries no release numbers or test counts.
///
/// ### What this library exports
/// **Core re-export** — `package:cell/cell.dart` in full: `Cell`,
/// `Cell.state`, `Cell.ingress`, [Pulse], [ValueCell], the `EgressHandle` /
/// `IngressHandle` / `StateHandle` families, `Context`, `EphemeralPolicy`,
/// `TestCell`, `Receptor`, `Synapses`, `Nucleus`, and the `Apply*`
/// command/receipt/outcome types. **The surface is wholesale**: anything a
/// `cell ^2.x` minor release adds to the core barrel becomes reachable
/// here without a `cell_flutter` version bump. Known name hazard: the
/// core's `Context` collides with `package:path`'s `Context` — import
/// selectively (`show` / `hide`) when both are in scope.
///
/// **Widgets** — [CellBuilder], [CellSelector], [CellValueBuilder],
/// [CellListener], [CellAsyncBuilder], [CellScope].
///
/// **Adapters and bridges** — [CellNotifier], [CellAsStream],
/// [CellAsValue] (with the [MirroredCell] record), and the
/// [ValueCellBuilder] fluent extension.
///
/// **Forms** — [CellEditingController], [CellTextField], [CellFormField].
///
/// **Restoration** — [RestorableCell], [CellRestoration], and
/// [CellRestorationScope].
///
/// **Containment and collections** — [CellErrorBoundary], [CellListView].
///
/// **DevTools (legacy re-export)** — [CellRegistry], [CellRegistryEntry],
/// [CellPulseRecord], and [CellInspectorOverlay]. New code should import
/// `package:cell_flutter/devtools.dart`; the barrel re-export is kept for
/// compatibility and is scheduled for removal in 2.0.
///
/// **Snapshot helpers** — [snapshotForPulse] and [snapshotForCell], the
/// decoders behind `CellAsyncBuilder` (advanced use; not the primary
/// widget surface).
///
/// **Separate entry points** (import explicitly when needed):
/// - `package:cell_flutter/hooks.dart` — the optional `flutter_hooks`
///   integration (`useCell`, `useCellValue`, `useCellNotifier`,
///   `useCellListener`, `useCellAsync`).
/// - `package:cell_flutter/testing.dart` — the widget-testing surface
///   (`pumpWithCells`, `pumpCell`, `emitAndSettle`, `recordPulses`,
///   `CellTestHarness`, `expectCellValue`, `expectCellGolden`).
/// - `package:cell_flutter/devtools.dart` — the DevTools registry and
///   overlay, kept off the application-facing surface going forward.
///
/// ### Which widget do I reach for?
/// | Need | Use |
/// |---|---|
/// | Display a `Cell.state` result | [CellBuilder] |
/// | Display one field of a larger object | [CellSelector] |
/// | Display a derived / async / tissue source | [CellValueBuilder] |
/// | Render loading / data / error | [CellAsyncBuilder] |
/// | React (navigate, toast, log) without rebuilding | [CellListener] |
/// | Reach a `Listenable` for Flutter primitives | [CellNotifier] |
/// | Bridge out to `Stream` | [CellAsStream.asStream] |
/// | Bridge out to a `ValueCell` mirror | [CellAsValue.asValueCell] |
/// | Register app-level cells for subtree lookup | [CellScope] |
/// | Bind a text field to a cell | [CellTextField] |
/// | Wrap a form field in cell validation | [CellFormField] |
/// | Survive process-kill restoration | [RestorableCell] |
/// | Isolate a failing subtree | [CellErrorBoundary] |
/// | Scroll a derived-cell collection | [CellListView] |
/// | Inspect the live graph | `package:cell_flutter/devtools.dart` |
///
/// ### Design notes
/// - **Explicit lifecycle for mirrors**: `asValueCell` returns a record
///   with a `dispose` callback because mirroring opens an egress that
///   must be released. There is no "auto-dispose" variant — the
///   widget-managed alternative is [CellValueBuilder].
/// - **Read-only by contract**: [CellNotifier] overrides `value`'s
///   setter to throw. Mutate the cell, not the notifier.
/// - **Build-phase safety by deferral**: widgets that must defer pulses
///   out of a build phase use a pending queue and a single post-frame
///   flush; widgets that must not defer (e.g. `CellSelector`'s
///   `setState`) route through `runAfterBuild`.
///
/// ### See also
/// - `package:cell/cell.dart` — the core graph primitives this library
///   wraps.
/// - [error_pulse_sources_test.dart](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/test/error_pulse_sources_test.dart) —
///   the authoritative statement of per-source error-pulse behavior
///   (`fromFuture` emits `type: 'error'` pulses; `fromStream` and
///   `asyncMap` do not).
/// - [seed_paths_test.dart](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/test/seed_paths_test.dart) —
///   the seed-behavior coverage for [CellValueBuilder],
///   [CellAsyncBuilder], `asValueCell`, and `asStream`.
/// - `package:cell_flutter/hooks.dart`, `package:cell_flutter/testing.dart`,
///   and `package:cell_flutter/devtools.dart` — the separate entry points.
/// - `cell_flutter_router`, `cell_flutter_persistence`, and
///   `cell_flutter_audit` — the ecosystem packages shipped alongside 1.0.
/// - `package:cell_flow` and `package:cell_tissue` — the instruction-layer
///   and collection/book libraries above the cell graph.
library;

// The core graph, re-exported wholesale (see the barrel doc for the
// collision caveat with package:path's `Context`).
export 'package:cell/cell.dart';

// Reactive builders.
export 'src/cell_async_builder.dart';
export 'src/cell_builder.dart';
export 'src/cell_listener.dart';
export 'src/cell_scope.dart';
export 'src/cell_selector.dart';
export 'src/cell_value_builder.dart';

// Adapters and bridges.
export 'src/cell_as_value.dart';
export 'src/cell_notifier.dart';
export 'src/cell_stream.dart';

// Forms, restoration, containment, and collections.
export 'src/cell_error_boundary.dart';
export 'src/cell_list_view.dart';
export 'src/cell_restoration.dart';
export 'src/cell_restoration_scope.dart';
export 'src/forms/cell_editing_controller.dart';
export 'src/forms/cell_form_field.dart';
export 'src/forms/cell_text_field.dart';

// DevTools registry and overlay. Retained for 1.x compatibility; new
// code should import package:cell_flutter/devtools.dart (removal here is
// scheduled for 2.0).
export 'src/devtools/cell_flutter_devtools.dart';
export 'src/devtools/cell_inspector_overlay.dart';
