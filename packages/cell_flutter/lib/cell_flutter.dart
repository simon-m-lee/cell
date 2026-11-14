// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Flutter widget bindings for Mitosis cells.
///
/// **Status:** Experimental (0.1.0). The binding is production-grade for
/// live state display and pulse-driven side effects. The underlying `cell`
/// framework's replay round-trip is verified for the pure state, debounce,
/// throttle, `fromFuture`, and `fromStream` probes (commit `05b4895d`;
/// full suite 1371 tests, determinism gate 240/240). Concurrent `asyncMap`
/// effect attribution under `concurrency > 0` is tracked separately
/// (Gate G1.5) and is **not** claimed by this binding. See `package:cell`
/// for the current status.
///
/// One import gives [Cell], [Cell.state], [Pulse], [CellNotifier],
/// [CellBuilder], [CellListener], [CellScope], [CellAsyncBuilder],
/// [CellSelector], [CellValueBuilder], [CellAsStream], and [CellAsValue].
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
