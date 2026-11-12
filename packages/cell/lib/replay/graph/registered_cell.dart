// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A thin wrapper that pairs a [Cell] with its graph-scoped name.
///
/// The wrapper is what `CellGraphBuilder.register` returns. It is not a
/// `Cell` itself — it is a *handle* that lets callers carry the
/// registered name alongside the cell, e.g. to pass into a
/// [CellGraphSnapshot] constructor without re-looking up the name from the
/// registry.
///
/// The distinction matters because [Cell.id] already resolves the name
/// from the registry; the wrapper exists so that *some* call sites (like
/// `CellGraph.register`) need not trust the registry. Outside the graph
/// construction path, `cell.id` is the canonical accessor and the wrapper
/// is not needed.
///
/// ### Non-obvious: the wrapper does not replace the cell
///
/// A `RegisteredCell` is **not** a deputy. It shares no state with the
/// wrapped cell (there is no state in the wrapper). It is purely a
/// (cell, name) pair. Passing a `RegisteredCell` where a `Cell` is
/// expected requires calling `.cell`. This is deliberate — the compiler
/// is the enforcement that a registered cell and a raw cell are not
/// interchangeable, which is what makes Phase 2's "unregistered bind
/// rejected" check possible without heuristics.
class RegisteredCell {
  /// The underlying cell.
  final Cell cell;

  /// The graph-assigned name. Stable across processes; the same name the
  /// cell's `id` getter returns.
  final String name;

  const RegisteredCell(this.cell, this.name);

  /// Convenience: `cell.id` should equal `name`. This is asserted at
  /// construction (in debug builds) and by the `CellGraph` when it walks
  /// its roots.
  void assertConsistent() {
    assert(
      cell.id == name,
      'RegisteredCell invariant violation: cell.id="${cell.id}" '
      'but registered name="$name". This means the underlying nucleus '
      'was registered under a different name, or was not registered at '
      'all — check CellGraphBuilder.',
    );
  }
}
