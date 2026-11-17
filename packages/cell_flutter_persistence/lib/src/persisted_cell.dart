// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';

import 'cell_persistence_adapter.dart';

/// A durable, restorable state cell.
///
/// [PersistedCell] composes the two mechanisms Flutter offers:
///
/// - **Restoration** (process kill) — the inner `cell` is a
///   [RestorableCell]; register it with a `CellRestorationScope` and
///   the value survives the OS killing the app.
/// - **Persistence** (explicit quit) — [load] reads the durable value
///   from [adapter] on mount, and [writeMode] controls when changes
///   write back.
///
/// ### Usage
///
/// ```dart
/// final counter = persistedState<int>(
///   restorationId: 'counter',
///   initial: 0,
///   adapter: SharedPreferencesAdapter.integer(prefs),
/// );
///
/// // In initState:
/// CellRestorationScope.maybeOf(context)?.register(counter.cell);
/// counter.load(); // async; the cell updates when the read completes.
///
/// // Everywhere else:
/// counter.cell.value = 5; // restored + persisted (per writeMode)
/// ```
///
/// ### Write cadence
/// [WriteMode.immediate] writes every change; [WriteMode.debounced]
/// (default, 1s) writes after a quiet period and coalesces bursts;
/// [WriteMode.onAppPause] writes when [handleAppPaused] is called —
/// call it from a `WidgetsBindingObserver.didChangeAppLifecycleState`
/// override for `AppLifecycleState.paused`.
///
/// ### Failure behavior
/// [load] never throws — a failing adapter read returns `false` and
/// leaves the cell at its current value. [persistNow] surfaces adapter
/// errors to the caller.
class PersistedCell<T> {
  PersistedCell._({
    required this.cell,
    required this.adapter,
    required this.writeMode,
    this.debounce = WriteMode.defaultDebounce,
  });

  /// The restorable value cell holding the state.
  ///
  /// Register it with a `CellRestorationScope` for process-kill
  /// survival.
  final RestorableCell<T> cell;

  /// The durable backend.
  final CellPersistenceAdapter<T> adapter;

  /// When writes happen.
  final WriteMode writeMode;

  /// The quiet period for [WriteMode.debounced].
  final Duration debounce;

  EgressHandle<Pulse<Object?>>? _egress;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// The key used for adapter reads/writes (the restoration id).
  String get key => cell.restorationId;

  /// Reads the durable value from [adapter] into [cell].
  ///
  /// Returns `true` when a value was restored, `false` when no value
  /// exists or the adapter failed (never throws).
  Future<bool> load() async {
    try {
      final value = await adapter.read(key);
      if (_disposed || value == null) {
        return value != null;
      }
      cell.value = value;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes the current value to [adapter].
  ///
  /// Equality-guarded: an unchanged value skips the write. Adapter
  /// errors propagate to the caller.
  Future<void> persistNow() async {
    final value = cell.value;
    if (value == null) {
      return;
    }
    await adapter.write(key, value);
  }

  /// Starts observing the cell and writing per [writeMode].
  ///
  /// Idempotent. In [WriteMode.immediate] / [WriteMode.debounced] the
  /// observation writes through on changes; in [WriteMode.onAppPause]
  /// the observation only records that a change happened (writes occur
  /// on [handleAppPaused]).
  void start() {
    if (_egress != null) {
      return;
    }
    _egress = Cell.observe<Pulse<Object?>>(
      source: cell,
      effect: (_) => _onChanged(),
      initiallyStarted: true,
    );
  }

  void _onChanged() {
    if (_disposed) {
      return;
    }
    switch (writeMode) {
      case WriteMode.immediate:
        persistNow();
      case WriteMode.debounced:
        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounce, () {
          persistNow();
        });
      case WriteMode.onAppPause:
        break; // Written on handleAppPaused.
    }
  }

  /// Writes the current value when the app pauses.
  ///
  /// Called manually (or from a `WidgetsBindingObserver` for
  /// `AppLifecycleState.paused`); used by [WriteMode.onAppPause].
  Future<void> handleAppPaused() => persistNow();

  /// Stops observing and cancels pending debounced writes.
  ///
  /// Does not dispose [cell] — the cell belongs to the caller.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _debounceTimer?.cancel();
    _egress?.stop();
    _egress = null;
  }
}

/// Creates a [PersistedCell] backed by [adapter].
///
/// The inner `cell` is a [RestorableCell] (register it with a
/// `CellRestorationScope`). A `Cell.persistedState` extension spelling
/// is not reachable from another package — Dart extension statics
/// belong to the extension, not the extended type — so the factory
/// ships as this top-level function.
PersistedCell<T> persistedState<T>({
  required String restorationId,
  required CellPersistenceAdapter<T> adapter,
  required T initial,
  WriteMode writeMode = WriteMode.debounced,
  Duration debounce = WriteMode.defaultDebounce,
}) {
  return PersistedCell<T>._(
    cell: restorableState<T>(
      restorationId: restorationId,
      initial: initial,
    ),
    adapter: adapter,
    writeMode: writeMode,
    debounce: debounce,
  );
}
