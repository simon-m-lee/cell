// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The process-wide name → nucleus registry that backs [NucleusBase.id]
/// for registered cells.
///
/// ### How it works
/// Deliberately **process-wide, not graph-scoped**. Two cells in the same
/// process cannot share an `id` even if they belong to different graphs —
/// that is the whole point of a stable identity. The registry refuses
/// duplicate registration, which is how the graph acceptance criterion
/// ("two cells with the same `id` fail registration") is enforced.
///
/// The registry is keyed by `Nucleus` (identity), not by `Cell`. This is
/// because the same `Cell` instance may be reached through multiple
/// wrappers (a deputy, an unmodifiable projection), and all of them should
/// resolve to the same `id` — which `CellBase.id` already guarantees by
/// delegating to `_nucleus.id`. Registering the nucleus rather than the
/// cell keeps the registry small (one entry per principal) and makes the
/// `Deputy` mixin's "share the principal's id" behaviour automatic.
///
/// ### Non-obvious: unregistration
///
/// The registry has no automatic unregistration. A `CellGraph` that is
/// dropped does **not** unregister its cells — this is deliberate,
/// because a snapshot taken before the graph was dropped may still refer
/// to the ids, and re-registering the same `id` for a different cell is a
/// semantic error that must be loud. Users who genuinely need to recycle
/// an id (e.g. tests) call `CellGraphRegistry.forceReset()`, which is
/// `@visibleForTesting` and documented as unsafe.
class _CellGraphRegistry {
  /// nucleus identity → assigned id.
  static final Map<Nucleus, String> _byNucleus = {};

  /// assigned id → nucleus identity (for reverse lookup, used by tests
  /// and by `_fallbackId` diagnostics).
  static final Map<String, Nucleus> _byId = {};

  static String? nameOf(Nucleus nucleus) => _byNucleus[nucleus];

  /// Registers [nucleus] under [id]. Returns `true` on success, `false` if
  /// either the nucleus or the id is already claimed.
  static bool register(Nucleus nucleus, String id) {
    final existingName = _byNucleus[nucleus];
    if (existingName != null) {
      // Re-registering the same nucleus with the same id is a no-op (a
      // graph may legitimately re-register on rebuild). With a different
      // id, it's a bug.
      return existingName == id;
    }
    final existingNucleus = _byId[id];
    if (existingNucleus != null) {
      // Id collision: two distinct nuclei want the same name.
      return false;
    }
    _byNucleus[nucleus] = id;
    _byId[id] = nucleus;
    return true;
  }

  /// Removes [nucleus] from the registry. Returns the previous id, or
  /// `null` if the nucleus was not registered.
  // ignore: unused_element — journal teardown hook (graph drop, tests).
  static String? unregister(Nucleus nucleus) {
    final id = _byNucleus.remove(nucleus);
    if (id != null) _byId.remove(id);
    return id;
  }

  /// Clears the registry. Only safe in tests, because any `CellSnapshot`
  /// or `Pulse` produced while the registry was populated refers to ids
  /// that will no longer resolve after the reset.
  @visibleForTesting
  static void forceReset() {
    resetForFork();
  }

  /// The same reset, for the library's own use: `CellGraph.fork` hands
  /// the isolate's id namespace to the fresh fork graph (the parent is
  /// finished in this isolate — see the fork docs).
  static void resetForFork() {
    _byNucleus.clear();
    _byId.clear();
    _ReplayCellRegistry.forceReset();
  }

  /// Diagnostic: a snapshot of the current registry contents. Not part of
  /// the public API; exists so tests and the CLI can inspect
  /// collisions.
  static Map<String, String> snapshot() {
    final out = <String, String>{};
    for (final entry in _byId.entries) {
      out[entry.key] = entry.value.toString();
    }
    return out;
  }
}
