// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Testing utilities for `cell_flutter`.
///
/// Import from **test files only**:
///
/// ```dart
/// import 'package:cell_flutter/testing.dart';
/// import 'package:flutter_test/flutter_test.dart';
/// ```
///
/// ## Requirement: test-only usage
///
/// `cell_flutter/testing.dart` imports `package:flutter_test/flutter_test.dart`.
/// `cell_flutter` declares `flutter_test` as a regular dependency (the
/// standard `bloc_test` / `mocktail` / `mockito` pattern), so it resolves
/// automatically. Add `cell_flutter` itself to your **dev_dependencies**
/// and this barrel will not pull `flutter_test` into production builds:
///
/// ```yaml
/// dev_dependencies:
///   cell_flutter: ^0.4.0
/// ```
///
/// ## What's in 0.4.0
///
/// - Extensions on `WidgetTester`: `pumpWithCells`, `pumpCell`,
///   `emitAndSettle`, `emitAndPump`, `expectCellValue`, `expectCellGolden`
/// - `recordPulses()` extension + `PulseRecorder<T>` class
/// - `CellTestHarness` for auto-managed test cell bundles
///
/// ## Inherited caveats
///
/// The binding rests on `cell`'s verified replay round-trip (commit
/// `05b4895d`). Concurrent `asyncMap` effect attribution is tracked
/// separately (Gate G1.5). `recordPulses` records every pulse regardless
/// of type; only `Cell.fromFuture` currently emits error pulses
/// (`fromStream` and `asyncMap` do not).
library cell_flutter_testing;

export 'package:cell_flutter/cell_flutter.dart';
export 'src/testing/pump_with_cells.dart';
export 'src/testing/pump_cell.dart';
export 'src/testing/emit_and_settle.dart';
export 'src/testing/expect_cell_value.dart';
export 'src/testing/expect_cell_golden.dart';
export 'src/testing/record_pulses.dart';
export 'src/testing/cell_test_harness.dart';
