// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The entry point for constructing a [CellGraph].
///
/// ```dart
/// final graph = CellGraph.builder()
///   ..register('user.name', nameCell)
///   ..register('user.cart', cartCell)
///   ..register('user', synthesisCell)
///   ..build();
/// ```
///
/// The builder is **stateful but single-use**: after `build()` is called,
/// further `register` calls throw. This prevents the common bug where a
/// caller constructs a graph, then continues registering cells that will
/// never appear in the graph, silently de-synchronising the in-memory
/// graph from its snapshot.
///
/// ### Strictness modes
///
/// By default, the builder is **strict**: after the graph is built, every
/// cell that receives a pulse from any registered root must itself be
/// registered, either directly or via the bind chain. `CellGraph.unrestricted()`
/// disables this for tests, and is documented as unsafe for production.
class CellGraphBuilder {
  final String _graphId;
  final bool _strict;
  final List<RegisteredCell> _registered = [];
  final Map<String, RegisteredCell> _byName = {};
  final Set<String> _claimedNames = {};
  bool _built = false;

  /// Creates a builder. Pass `graphId: null` to auto-generate one from a
  /// UUID; pass a specific value to reproduce a graph across processes
  /// (a snapshot taken from one graph can be restored into another with
  /// the same `graphId`).
  CellGraphBuilder({String? graphId, bool strict = true})
      : _graphId = graphId ?? const Uuid().v4(),
        _strict = strict;

  /// Registers [cell] under [name].
  ///
  /// Throws [ArgumentError] if:
  /// * [name] is empty;
  /// * [name] has already been claimed by a previous `register` call;
  /// * [cell] is already registered under a different name.
  ///
  /// Throws [StateError] if the builder has already been built, or if the
  /// name is claimed by a nucleus the builder does not know about (a
  /// leaked id from another graph).
  ///
  /// Returns the `RegisteredCell` wrapper, so callers can chain.
  RegisteredCell register(String name, Cell cell) {
    if (_built) {
      throw StateError(
        'CellGraphBuilder.build() was already called; '
        'register("$name") came too late.',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (!_claimedNames.add(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'already registered by another cell',
      );
    }

    // The nucleus may already be registered elsewhere (e.g. by a previous
    // graph that adopted the cell). If so, adopt that name and refuse a
    // different one.
    final nucleus = cell._nucleus;
    final existing = _CellGraphRegistry.nameOf(nucleus);
    final effectiveName = existing ?? name;
    if (existing != null && existing != name) {
      throw ArgumentError(
        'CellGraphBuilder.register: cell is already registered '
        'under "$existing"; cannot re-register as "$name". '
        'If you need a distinct name, use a deputy (Phase 3+).',
      );
    }
    if (existing == null && !_CellGraphRegistry.register(nucleus, name)) {
      // Registration refused: the id is claimed by a nucleus we don't know
      // about (a leaked id from another graph). Loud failure is the right
      // response.
      throw StateError(
        'CellGraphBuilder.register: id "$name" is claimed by an unknown '
        'nucleus. This usually means another CellGraph (or a previous '
        'builder) registered the same name and was not unregistered. '
        'Use CellGraphRegistry.forceReset() in tests only.',
      );
    }
    final wrapped = RegisteredCell(cell, effectiveName);
    _registered.add(wrapped);
    _byName[effectiveName] = wrapped;
    // Phase 4: keep the Phase 1 source registry in sync so ledger entries
    // can resolve receipt cells back to live cells in this process.
    _ReplayCellRegistry.register(effectiveName, cell);
    return wrapped;
  }

  /// Registers a [StateHandle] (the record returned by [Cell.state])
  /// under [name], returning a handle whose `cell` is the registered
  /// wrapper.
  ///
  /// This is the ergonomic path: user code obtains a handle from
  /// `Cell.state(...)` and registers it without manually unwrapping.
  /// The returned handle's `cell` is the same instance (not a deputy), so
  /// `handle.cell.id == name` after registration.
  StateHandle<V> registerState<V>(String name, StateHandle<V> handle) {
    final wrapped = register(name, handle.cell);
    return (
      cell: wrapped.cell as ValueCell<V>,
      update: handle.update,
      updateAsync: handle.updateAsync,
      ingest: handle.ingest,
    );
  }

  /// Builds the [CellGraph]. After this returns, the builder is locked.
  CellGraph build() {
    if (_built) {
      throw StateError('CellGraphBuilder.build() was already called.');
    }
    _built = true;
    final graph = CellGraph._(
      graphId: _graphId,
      strict: _strict,
      registered: List.unmodifiable(_registered),
      byName: Map.unmodifiable(_byName),
    );
    // Validate reachability immediately, so a caller who built a
    // disconnected graph learns about it at construction time, not at
    // snapshot time.
    graph._validateReachability();
    return graph;
  }
}
