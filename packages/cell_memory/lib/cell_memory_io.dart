// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The `dart:io` backend for `cell_memory`.
///
/// Import this library in addition to `package:cell_memory/cell_memory.dart`
/// when you want the file store; the core library stays web-safe.
library;

export 'src/stores/file_store.dart' show FileMemoryStore;
