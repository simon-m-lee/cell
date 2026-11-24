// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The declarative exposure policy.
///
/// The binding table is the *registry*; the whitelist is the *policy*.
/// A function that is not bound simply does not exist on the wire; a
/// function that is bound but not whitelisted exists in the graph but
/// is refused at the skin. When no whitelist is configured, every
/// registered binding is exposed.
/// {@category Features}
library;

/// What `cellId → {functionName}` exposure policy does with a binding
/// the map does not name.
///
/// [SkinUnlisted.hide] (the default) hides it silently: `allows` is
/// true only for functions listed under their cell. [SkinUnlisted.expose]
/// exposes it when its cell is not mentioned in the map at all — the
/// opt-in for "deny the cells I name, allow the rest" — and the
/// membrane warns about each binding that becomes reachable this way. A
/// function omitted from a cell the map *does* mention stays hidden in
/// both modes.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the whitelist's rule for bindings the map does not
/// name.
/// **When to use:** a BRD says "deny the cells I name, allow the rest"
/// — pass `SkinUnlisted.expose` to `SkinWhitelist`.
/// **When NOT to use:** per-request authorization (use
/// `SkinAuthorizer`), or creating exposure for unbound functions.
/// **Live signature:** `enum SkinUnlisted { hide, expose }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Do NOT confuse with:** `SkinWhitelist.allows` (the per-binding
/// verdict) or `SkinAuthorizer` (per-request allow/deny).
/// **Guide:** `HowTo-Whitelist.md` (inverting the policy).
enum SkinUnlisted { hide, expose }

/// `cellId → {functionName}` exposure policy.
///
/// ### When to use
/// * Shrinking the wire surface below "every registered binding":
///   applies, egress, `/skin/observe/:cellId`, and `/skin/ledger` all
///   respect it.
/// * Inverting the policy with [SkinUnlisted.expose]: name the cells to
///   hide; everything else is reachable.
///
/// ### How it works
/// A function that is not bound does not exist on the wire; a bound
/// but not whitelisted function is refused at the skin. Entries with no
/// matching binding raise startup policy warnings.
///
/// ### Non-obvious
/// The whitelist is policy *over* the binding table — it never creates
/// exposure by itself. Listing a function under a cell only ever hides
/// the other functions of *that* cell; it never changes a different
/// cell.
///
/// ### See also
/// [SkinBindingTable], [SkinMembrane.isExposed].
/// {@category Whitelist}
final class SkinWhitelist {
  final Map<String, Set<String>> _byCell;

  /// How bindings the map does not name are treated. [SkinUnlisted.hide]
  /// keeps the historical rule: only listed functions cross the skin.
  final SkinUnlisted unlisted;

  /// Creates a whitelist from `cellId → functions` entries.
  SkinWhitelist(
    Map<String, Iterable<String>> byCell, {
    this.unlisted = SkinUnlisted.hide,
  }) : _byCell = byCell.map((k, v) => MapEntry(k, Set.unmodifiable(v)));

  /// A whitelist that exposes nothing.
  static final empty = SkinWhitelist({});

  /// Whether `(cellId, functionName)` may cross the skin.
  bool allows(String cellId, String functionName) {
    final functions = _byCell[cellId];
    if (functions == null) return unlisted == SkinUnlisted.expose;
    return functions.contains(functionName);
  }

  /// Whether the whitelist mentions [cellId] at all.
  bool mentionsCell(String cellId) => _byCell.containsKey(cellId);

  /// All whitelisted cell ids.
  List<String> get cellIds => List.unmodifiable(_byCell.keys);

  /// All whitelisted functions for [cellId].
  List<String> functionsFor(String cellId) =>
      List.unmodifiable(_byCell[cellId] ?? const {});

  @override
  String toString() => 'SkinWhitelist($_byCell, unlisted: $unlisted)';
}
