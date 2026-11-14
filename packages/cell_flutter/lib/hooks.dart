// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Optional `flutter_hooks` integration for `cell_flutter`.
///
/// Import this library from any widget that extends `HookWidget` (or
/// `HookBuilder`):
///
/// ```dart
/// import 'package:cell_flutter/hooks.dart';
/// ```
///
/// The hooks follow `flutter_hooks`' rules: unconditional, top-level,
/// same order every build. Violations trigger `flutter_hooks`' own
/// assertion.
///
/// ## Requirements
///
/// `flutter_hooks` must be in your `pubspec.yaml`. It is a regular
/// dependency of `cell_flutter`, so it will resolve automatically, but
/// you may want to pin its version explicitly for stability.
///
/// ## Inherited caveats
///
/// `useCellAsync` inherits the per-source error behavior and the
/// concurrent `asyncMap` caveat documented in `CellAsyncBuilder`. In
/// short: only `Cell.fromFuture` emits error pulses today; `fromStream`
/// and `asyncMap` do not. `useCellAsync` over an `asyncMap` source with
/// `concurrency > 0` inherits Gate G1.5.
library cell_flutter_hooks;

export 'package:cell_flutter/cell_flutter.dart';
export 'package:flutter_hooks/flutter_hooks.dart';

export 'src/hooks/use_cell.dart';
export 'src/hooks/use_cell_notifier.dart';
export 'src/hooks/use_cell_listener.dart';
export 'src/hooks/use_cell_async.dart';
