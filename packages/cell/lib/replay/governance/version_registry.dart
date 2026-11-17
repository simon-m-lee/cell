// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Maps `(cellId, version)` to the receptor and test rule that
/// implemented that version.
///
/// ### When to use
/// The replay engine's [ReplayEngine] consults the [VersionRegistry]
/// first: if the registry has an entry for `(cellId, version)`, that is
/// used; otherwise, the live receptor is used **only if its version
/// matches** the ledger's; otherwise, replay fails loudly.
///
/// ### Non-obvious: the registry is graph-scoped, not process-wide
///
/// Two graphs in the same process may have the same cell name with
/// different version histories (a test graph and a production graph).
/// A process-wide registry would allow the test graph's version to
/// shadow the production graph's, which is exactly the kind of ambient
/// coupling the governance layer exists to prevent. The registry is
/// created lazily by [CellGraphVersions.versions] and lives for the
/// graph's lifetime.
///
/// See also:
/// * [CellGraphVersions] — the per-graph extension that owns a registry.
/// * [ReplayEngine] — consults the registry at each version boundary.
/// {@category Replay}
class VersionRegistry {
  final Map<String, Map<String, _VersionedImpl>> _byCellVersion = {};

  /// Registers [receptor] and [testRule] as the implementation for
  /// [cellId] at [version]. Both must have the same version string.
  ///
  /// ### How it works
  /// Registering the same `(cellId, version)` twice is a no-op if the
  /// implementations are identical (by identity); otherwise it throws
  /// [StateError] — a version must map to exactly one implementation.
  ///
  /// ### Parameters:
  /// - [cellId]: The cell whose historical implementation is registered.
  /// - [version]: The version string both implementations report.
  /// - [receptor]: The historical receptor.
  /// - [testRule]: The historical test rule.
  void register({
    required String cellId,
    required String version,
    required Receptor receptor,
    required TestCell testRule,
  }) {
    if (receptor.version != version || testRule.version != version) {
      throw StateError(
        'VersionRegistry.register: receptor.version=${receptor.version} '
        'and testRule.version=${testRule.version} must both equal '
        'version="$version".',
      );
    }
    final byVersion = _byCellVersion.putIfAbsent(cellId, () => {});
    final existing = byVersion[version];
    if (existing != null) {
      if (identical(existing.receptor, receptor) &&
          identical(existing.testRule, testRule)) {
        return; // identical re-registration is a no-op
      }
      throw StateError(
        'VersionRegistry: ("$cellId", "$version") is already registered '
        'with different implementations. A version must map to exactly '
        'one (receptor, testRule) pair.',
      );
    }
    byVersion[version] =
        _VersionedImpl(receptor: receptor, testRule: testRule);
  }

  /// Resolves [cellId] at [version]. Returns the registered pair, or
  /// `null` if the version is not registered — the caller must then
  /// either fall back to the live implementation (if its version
  /// matches) or fail loudly.
  ///
  /// ### Parameters:
  /// - [cellId]: The cell whose historical implementation is resolved.
  /// - [version]: The version to resolve.
  ///
  /// ### Returns:
  /// The registered `(receptor, testRule)` pair, or `null`.
  ({Receptor receptor, TestCell testRule})? resolve({
    required String cellId,
    required String version,
  }) {
    final impl = _byCellVersion[cellId]?[version];
    if (impl == null) return null;
    return (receptor: impl.receptor, testRule: impl.testRule);
  }

  /// Returns `true` if `(cellId, version)` is registered.
  ///
  /// ### Parameters:
  /// - [cellId]: The cell to check.
  /// - [version]: The version to check.
  bool has({required String cellId, required String version}) {
    return _byCellVersion[cellId]?.containsKey(version) ?? false;
  }
}

class _VersionedImpl {
  final Receptor receptor;
  final TestCell testRule;
  _VersionedImpl({required this.receptor, required this.testRule});
}

/// The graph-scoped version registry (see [VersionRegistry]).
///
/// ### How it works
/// The [Expando] keeps the registry per-[CellGraph] instance and clears
/// it when the graph is GC'd, so the registry never outlives its graph.
extension CellGraphVersions on CellGraph {
  static final Expando<VersionRegistry> _registries = Expando();

  /// The graph's version registry. Created lazily on first access; the
  /// [Expando] keeps it per-`CellGraph` instance and clears it when the
  /// graph is GC'd.
  VersionRegistry get versions {
    return _registries[this] ??= VersionRegistry();
  }

  /// Convenience: registers [cellId]'s current receptor and test rule
  /// under their current version.
  ///
  /// ### Parameters:
  /// - [cellId]: The registered cell whose live implementation is
  ///   pinned.
  void registerVersion(String cellId) {
    final registered = this[cellId];
    if (registered == null) {
      throw ArgumentError.value(cellId, 'cellId', 'not registered');
    }
    final nucleus = registered.cell._nucleus;
    versions.register(
      cellId: cellId,
      version: nucleus.receptor.version,
      receptor: nucleus.receptor,
      testRule: nucleus.testRule,
    );
  }
}
