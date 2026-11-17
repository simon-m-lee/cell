// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Testing utilities for `cell_flutter`.
///
/// `testing.dart` is the binding's **Test Surface** — the barrel library
/// that exports every test helper the binding provides, plus the
/// application-facing surface (`cell_flutter.dart`) they build on. It is
/// the single import a test needs to pump, emit, record, and assert against
/// cells inside a `testWidgets` body.
///
/// ### Why it is used
/// Widget-testing a cell-backed widget has three recurring shapes, and
/// this library covers each without hand-rolled scaffolding:
/// - **Pumping**: a widget needs a `CellScope` (for lookups) or at least a
///   `MaterialApp` + `Scaffold` frame (for text and theme). `pumpWithCells`
///   and `pumpCell` assemble the correct tree with one call.
/// - **Emitting**: writing `cell.value = ...` does not trigger a render on
///   its own; `emitAndSettle` and `emitAndPump` combine the write with the
///   pumping needed to see the result.
/// - **Observing**: `recordPulses` captures the full pulse sequence, and
///   `expectCellValue` / `expectCellGolden` assert on the current value or
///   the rendered pixels.
///
/// `CellTestHarness` bundles all three for suites with several shared
/// cells, and takes care of recorder cleanup in `tearDown`.
///
/// ### Import from test files only
/// ```dart
/// import 'package:cell_flutter/testing.dart';
/// import 'package:flutter_test/flutter_test.dart';
/// ```
///
/// ### Requirement: test-only usage (read this)
/// `cell_flutter/testing.dart` imports `package:flutter_test/flutter_test.dart`.
/// `cell_flutter` declares `flutter_test` as a **regular dependency** — the
/// same pattern `bloc_test`, `mocktail`, and `mockito` use — so the import
/// resolves automatically. To keep `flutter_test` out of production
/// builds, add `cell_flutter` itself to your **dev_dependencies**:
///
/// ```yaml
/// dev_dependencies:
///   cell_flutter: ^0.4.0
/// ```
///
/// Application code that imports `package:cell_flutter/cell_flutter.dart`
/// (not `testing.dart`) is unaffected; the `flutter_test` import never
/// enters the production graph.
///
/// ### What this library exports
/// **Re-export**:
/// - `package:cell_flutter/cell_flutter.dart` — the entire
///   application-facing surface (`CellBuilder`, `CellSelector`,
///   `CellValueBuilder`, `CellAsyncBuilder`, `CellListener`, `CellScope`,
///   `CellNotifier`, `CellAsStream`, `CellAsValue`, plus the core `cell`
///   re-export). Test helpers are typically written against the same
///   surface the production code uses, so this library re-exports it.
///
/// **Widget pumping**:
/// - `CellPumpWithCells.pumpWithCells` — pumps a widget inside a
///   `CellScope`, with an optional custom wrapper.
/// - `CellPumpCell.pumpCell` — pumps a bare `CellBuilder` in a default
///   `MaterialApp` + `Scaffold` frame.
///
/// **Emission**:
/// - `CellEmitAndSettle.emitAndSettle` — writes the value and pumps until
///   the tree settles.
/// - `CellEmitAndSettle.emitAndPump` — writes the value and pumps a single
///   frame (or an explicit `Duration`), without waiting for settle.
///
/// **Observation**:
/// - `CellRecordPulses.recordPulses` — records the ordered pulse sequence
///   emitted by any `Cell`.
/// - `PulseRecorder<T>` — the recorder type; exposes `pulses` and
///   `payloads`.
/// - `CellExpectValue.expectCellValue` — asserts a `ValueCell`'s current
///   value against a matcher.
/// - `CellExpectGolden.expectCellGolden` — captures a golden image of a
///   `CellBuilder` at the cell's current value.
///
/// **Fixture**:
/// - `CellTestHarness` — a per-test registry that owns recorders and
///   bundles pumping + emission + cleanup.
///
/// ### Inherited caveats
/// The binding rests on `cell`'s verified replay round-trip (commit
/// `05b4895d`). Concurrent `asyncMap` effect attribution is tracked
/// separately and is not claimed by this binding. `recordPulses`
/// records **every** pulse regardless of type; only `Cell.fromFuture`
/// currently emits error pulses in the core package — `fromStream` and
/// `asyncMap` do not. See `record_pulses.dart` for the full explanation.
///
/// ### See Also:
/// - `package:cell_flutter/cell_flutter.dart` — the application-facing
///   surface this library re-exports.
/// - `package:cell_flutter/hooks.dart` — the optional `flutter_hooks`
///   integration, with its own hook equivalents for tests that use
///   `HookWidget`.
/// - `record_pulses.dart` — the authoritative statement of per-source
///   error-pulse behavior (overrides contradictory claims in other
///   binding docs).
/// - `test/error_pulse_sources_test.dart` — the test file that locks in
///   the per-source error-pulse behavior these docs describe.
/// - `CellTestHarness` — the higher-level fixture for multi-cell suites.
library cell_flutter_testing;

export 'package:cell_flutter/cell_flutter.dart';
export 'src/testing/pump_with_cells.dart';
export 'src/testing/pump_cell.dart';
export 'src/testing/emit_and_settle.dart';
export 'src/testing/expect_cell_value.dart';
export 'src/testing/expect_cell_golden.dart';
export 'src/testing/record_pulses.dart';
export 'src/testing/cell_test_harness.dart';
