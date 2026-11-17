// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Optional `flutter_hooks` integration for `cell_flutter`.
///
/// **Status:** Experimental, paired with `cell_flutter` 0.6.0 (hardening —
/// see the `cell_flutter` library docs and `README.md` *Status* for what
/// is and is not claimed).
///
/// This library is the **Hooks Layer** of the binding: a set of `use*`
/// functions that express the same reactive contracts as the widget
/// counterparts (`CellBuilder`, `CellSelector`, `CellAsyncBuilder`,
/// `CellListener`) but compose with `flutter_hooks` primitives. It is
/// **opt-in** — application code that does not use `HookWidget` should
/// import `package:cell_flutter/cell_flutter.dart` instead.
///
/// Import this library from any widget that extends `HookWidget` (or uses
/// `HookBuilder`):
///
/// ```dart
/// import 'package:cell_flutter/hooks.dart';
/// ```
///
/// ### Rules inherited from `flutter_hooks`
/// Every hook in this library must be called:
/// 1. **Unconditionally** — not inside an `if`, loop, or short-circuit.
/// 2. **At the top** of `HookWidget.build` (before any early return that
///    precedes another hook).
/// 3. **In the same order** on every build.
///
/// Violations trigger `flutter_hooks`' own assertion. The contract is not
/// relaxed here — the hooks are thin wrappers around `flutter_hooks`
/// primitives and inherit its lifecycle model verbatim.
///
/// ### Requirements
/// `flutter_hooks` must be in your `pubspec.yaml`. It is a regular
/// dependency of `cell_flutter`, so it resolves automatically; pinning its
/// version explicitly is recommended for stability, since this library is
/// coupled to `flutter_hooks`' hook API.
///
/// ### Inherited caveats (please read)
/// `useCellAsync` inherits the per-source **error-pulse behavior** and the
/// concurrent-`asyncMap` caveat documented in `CellAsyncBuilder`.
/// In short: only `Cell.fromFuture` emits error pulses today; `fromStream`
/// and `asyncMap` do not. A `useCellAsync` over an `asyncMap` source with
/// `concurrency > 0` inherits the concurrent-effect-attribution
/// caveat. The hooks' own observation is correct; the caveats concern the
/// source's replay fidelity and the per-source error surface.
///
/// ### What this library exports
/// - [useCell] — the selector hook (equivalent of `CellSelector`).
/// - [useCellValue] — the full-value shortcut for [useCell].
/// - [useCellNotifier] — the [CellNotifier] hook for composing with
///   `flutter_hooks` primitives or `ValueListenableBuilder`.
/// - `useCellListener` — the side-effect hook (equivalent of
///   `CellListener`).
/// - `useCellAsync` — the async-snapshot hook (equivalent of
///   `CellAsyncBuilder`).
///
/// It also re-exports `cell_flutter` and `flutter_hooks`, so a single
/// import suffices in a `HookWidget`.
///
/// ### See Also:
/// - `cell_flutter` — the widget-layer binding this library builds on.
/// - `flutter_hooks` — the hook primitives and rules this library obeys.
/// - `CellBuilder`, `CellSelector`, `CellAsyncBuilder`, `CellListener` —
///   the widget equivalents each hook mirrors.
library cell_flutter_hooks;

export 'package:cell_flutter/cell_flutter.dart';
export 'package:flutter_hooks/flutter_hooks.dart';

export 'src/hooks/use_cell.dart';
export 'src/hooks/use_cell_notifier.dart';
export 'src/hooks/use_cell_listener.dart';
export 'src/hooks/use_cell_async.dart';
