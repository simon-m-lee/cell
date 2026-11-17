// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

/// A keyed persistence backend for one value type.
///
/// Implementations own the storage medium; [PersistedCell] owns the
/// reactive half. `read` / `write` / `delete` are the entire contract —
/// custom backends (files, databases, remote stores) need only these
/// three operations.
abstract class CellPersistenceAdapter<T> {
  /// Reads the value stored under [key], or `null`.
  Future<T?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, T value);

  /// Removes the value stored under [key].
  Future<void> delete(String key);
}

/// When a [PersistedCell] writes through to its adapter.
enum WriteMode {
  /// Write on every value change. Highest durability, most I/O.
  immediate,

  /// Write after a quiet period. Balanced; the default.
  debounced,

  /// Write only when the app pauses. Lowest I/O, most loss on crash.
  onAppPause;

  /// The default debounce duration for [WriteMode.debounced].
  static const Duration defaultDebounce = Duration(seconds: 1);
}
