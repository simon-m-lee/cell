// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Public read-only access to the cell id registry.
///
/// ### When to use
/// Tests and the CLI-only hook; it is deliberately not part of the normal
/// API surface — users should not need it outside tests.
///
/// ### How it works
/// The registry itself is `_CellGraphRegistry` (private to the library);
/// this class exposes the minimum public surface needed: [isRegistered]
/// checks whether an id is claimed, [snapshot] returns an immutable view,
/// and [forceReset] clears everything (test-only).
///
/// See also:
/// * `CellGraphBuilder` — the normal path that populates the registry.
/// {@category Replay}
abstract final class CellGraphRegistry {
  /// Whether [id] is currently claimed by any registered cell in this
  /// process.
  static bool isRegistered(String id) =>
      _CellGraphRegistry.snapshot().containsKey(id);

  /// A diagnostic snapshot of `{id: nucleus}` for every registered cell.
  /// Returns an immutable map.
  static Map<String, String> snapshot() =>
      Map.unmodifiable(_CellGraphRegistry.snapshot());

  /// Clears the registry. **Test-only.** Calling this in production will
  /// invalidate every `CellSnapshot` and `Pulse` whose `source` refers to
  /// a cleared id; subsequent codecs will fail to reconstruct those
  /// pulses.
  @visibleForTesting
  static void forceReset() => _CellGraphRegistry.forceReset();
}
