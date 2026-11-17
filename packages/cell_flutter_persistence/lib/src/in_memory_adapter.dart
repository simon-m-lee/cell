// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'cell_persistence_adapter.dart';

/// An in-memory [CellPersistenceAdapter] for tests and previews.
///
/// Backed by a `Map<String, T>`; [contents] is exposed so tests can
/// inspect or seed the store directly. Behave identically to
/// [SharedPreferencesAdapter] at the contract level.
class InMemoryAdapter<T> implements CellPersistenceAdapter<T> {
  /// Creates the adapter with an empty store.
  InMemoryAdapter() : _store = {};

  /// Creates the adapter pre-seeded with [seed].
  InMemoryAdapter.seeded(Map<String, T> seed) : _store = {...seed};

  final Map<String, T> _store;

  /// The current contents (mutable view, for tests and tooling).
  Map<String, T> get contents => _store;

  @override
  Future<T?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, T value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
