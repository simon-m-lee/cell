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

/// `cellId → {functionName}` exposure policy.
///
/// ### When to use
/// * Shrinking the wire surface below "every registered binding":
///   applies, egress, `/skin/observe/:cellId`, and `/skin/ledger` all
///   respect it.
///
/// ### How it works
/// A function that is not bound does not exist on the wire; a bound
/// but not whitelisted function is refused at the skin. Entries with no
/// matching binding raise startup policy warnings.
///
/// ### Non-obvious
/// The whitelist is policy *over* the binding table — it never creates
/// exposure by itself.
///
/// ### See also
/// [SkinBindingTable], [SkinMembrane.isExposed].
/// {@category Whitelist}
final class SkinWhitelist {
  final Map<String, Set<String>> _byCell;

  /// Creates a whitelist from `cellId → functions` entries.
  SkinWhitelist(Map<String, Iterable<String>> byCell)
      : _byCell = byCell.map((k, v) => MapEntry(k, Set.unmodifiable(v)));

  /// A whitelist that exposes nothing.
  static final empty = SkinWhitelist({});

  /// Whether `(cellId, functionName)` may cross the skin.
  bool allows(String cellId, String functionName) =>
      _byCell[cellId]?.contains(functionName) ?? false;

  /// Whether the whitelist mentions [cellId] at all.
  bool mentionsCell(String cellId) => _byCell.containsKey(cellId);

  /// All whitelisted cell ids.
  List<String> get cellIds => List.unmodifiable(_byCell.keys);

  /// All whitelisted functions for [cellId].
  List<String> functionsFor(String cellId) =>
      List.unmodifiable(_byCell[cellId] ?? const {});

  @override
  String toString() => 'SkinWhitelist($_byCell)';
}
