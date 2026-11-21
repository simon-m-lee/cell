// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The DevTools surface: the live cell registry and the inspector overlay.
///
/// Import this library explicitly for graph inspection —
///
/// ```dart
/// import 'package:cell_flutter/devtools.dart';
/// ```
///
/// The main `cell_flutter.dart` barrel still re-exports these symbols for
/// 1.x compatibility; that re-export is scheduled for removal in 2.0.
library;

export 'src/devtools/cell_flutter_devtools.dart';
export 'src/devtools/cell_inspector_overlay.dart';
