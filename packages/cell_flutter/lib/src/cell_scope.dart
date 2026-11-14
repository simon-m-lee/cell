// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Provides cells to the subtree below it, addressed by [Symbol].
///
/// `CellScope` is app-level dependency injection for the small set of cells
/// that are genuinely global: `auth`, `theme`, `featureFlags`, `currentUser`.
/// For anything else, pass the cell as a constructor argument — Mitosis
/// philosophy is that cells flow through the tree explicitly, and
/// `CellScope` should not become a general-purpose locator.
///
/// ## Usage
///
/// ```dart
/// // App root:
/// final auth = Cell.state<AuthState?>(initial: null);
/// final theme = Cell.state<ThemeData>(initial: ThemeData.light());
///
/// CellScope(
///   cells: {
///     #auth: auth.cell,
///     #theme: theme.cell,
///   },
///   child: const MyApp(),
/// );
///
/// // Deep in the tree:
/// final authCell = CellScope.valueOf<AuthState?>(context, #auth);
/// CellBuilder<AuthState?>(
///   cell: authCell.unmodifiable,
///   builder: (_, state) => ...,
/// );
/// ```
///
/// ## Lookup semantics
///
/// - [of] throws if the id is unknown or the type is wrong.
/// - [maybeOf] returns `null` if the id is unknown; throws on type mismatch.
/// - [valueOf] is like [of] but additionally requires the registered cell
///   to be a [ValueCell<V>] — the common case for `CellBuilder`.
///
/// Because `Cell` itself carries no value type parameter, the type check is
/// runtime-verifiable for [ValueCell] registrations (the common case from
/// `Cell.state`). A non-`ValueCell` registration (`Cell.ingress`,
/// `Cell.derive`, `Cell.asyncMap`) is returned as-is by [of] and [maybeOf];
/// the value type is enforced where it exists — on the [Pulse] — and by
/// [valueOf]'s stricter check.
///
/// ## Nested scopes
///
/// If a `CellScope` is nested inside another, `dependOnInheritedWidgetOfExactType`
/// returns the *nearest* one. Inner registrations shadow outer ones for the
/// same `Symbol`. This matches `InheritedWidget`'s contract.
///
/// ## Rebuild behavior
///
/// [updateShouldNotify] returns `true` only when the effective map changes
/// — that is, when a cell at a key is replaced with a different instance.
/// A parent re-build that constructs an equal-but-distinct map does not
/// trigger descendant rebuilds.
class CellScope extends InheritedWidget {
  /// Registers [cells] under [Symbol] keys for the [child] subtree.
  ///
  /// Keys are `Symbol`s (`#auth`, `#theme`), not type parameters. Mitosis
  /// often has multiple `Cell` values of the same `V` in one app; type-keyed
  /// lookup cannot distinguish them.
  const CellScope({
    required this.cells,
    required super.child,
    super.key,
  });

  /// The registered cells. Keys are `Symbol`s, values are `Cell`.
  final Map<Symbol, Cell> cells;

  /// Returns the cell registered at [id] in the nearest enclosing [CellScope].
  ///
  /// Throws if:
  /// - No [CellScope] exists above [context].
  /// - No cell is registered under [id].
  /// - The registered cell is a [ValueCell] whose value type does not
  ///   satisfy `V`.
  ///
  /// In debug builds the first two cases fail as `AssertionError`s (they
  /// are programmer bugs); the `StateError` is the release-mode fallback.
  static Cell of<V>(BuildContext context, Symbol id) {
    final cell = _lookup(context, id);
    if (cell is ValueCell && cell is! ValueCell<V>) {
      throw StateError(
        'CellScope.of<$V>($id): registered cell is ${cell.runtimeType}, '
        'which is not a ValueCell<$V>.',
      );
    }
    return cell;
  }

  /// Like [of], but returns `null` if [id] is not registered.
  ///
  /// Still throws [StateError] on a **type mismatch** — that is a bug, not
  /// an absence.
  static Cell? maybeOf<V>(BuildContext context, Symbol id) {
    final scope = context.dependOnInheritedWidgetOfExactType<CellScope>();
    if (scope == null) return null;
    final cell = scope.cells[id];
    if (cell == null) return null;
    if (cell is ValueCell && cell is! ValueCell<V>) {
      throw StateError(
        'CellScope.maybeOf<$V>($id): registered cell is '
        '${cell.runtimeType}, which is not a ValueCell<$V>.',
      );
    }
    return cell;
  }

  /// Returns the cell registered at [id], requiring it to be a [ValueCell<V>].
  ///
  /// This is the common lookup for `CellBuilder`: `Cell.state` returns a
  /// `ValueCell` internally, and most app-level cells are `ValueCell`s.
  static ValueCell<V> valueOf<V>(BuildContext context, Symbol id) {
    final cell = of<V>(context, id);
    if (cell is! ValueCell<V>) {
      throw StateError(
        'CellScope.valueOf<$V>($id): registered cell is '
        '${cell.runtimeType}, which is not a ValueCell<$V>. '
        'Use CellScope.of for non-ValueCell sources.',
      );
    }
    return cell;
  }

  /// Symbols for which the nested-shadow warning has already been emitted.
  /// One warning per symbol per debug session; cleared by tests.
  @visibleForTesting
  static final Set<Symbol> shadowWarned = <Symbol>{};

  static Cell _lookup(BuildContext context, Symbol id) {
    final scope = context.dependOnInheritedWidgetOfExactType<CellScope>();
    // Debug-mode contracts: a missing scope or an unknown id is a bug and
    // fails as an AssertionError during development. The StateError
    // fallbacks keep the behavior defined in release builds.
    assert(scope != null, 'CellScope.of: no CellScope above this widget.');
    if (scope == null) {
      throw StateError('No CellScope above this widget.');
    }
    if (kDebugMode) {
      context.visitAncestorElements((el) {
        if (el.widget is CellScope && !identical(el.widget, scope)) {
          final outer = el.widget as CellScope;
          if (outer.cells.containsKey(id) && !shadowWarned.contains(id)) {
            shadowWarned.add(id);
            debugPrint(
              'CellScope: $id is registered in a nested scope and shadows '
              'the outer registration. This is usually a bug. If intentional, '
              'this message appears only once per symbol per debug session.',
            );
          }
        }
        return true;
      });
    }
    final cell = scope.cells[id];
    assert(cell != null, 'CellScope.of: no cell registered under $id.');
    if (cell == null) {
      throw StateError('No cell registered under $id.');
    }
    return cell;
  }

  @override
  bool updateShouldNotify(CellScope oldWidget) {
    if (identical(cells, oldWidget.cells)) return false;
    if (cells.length != oldWidget.cells.length) return true;
    for (final id in cells.keys) {
      if (!identical(cells[id], oldWidget.cells[id])) return true;
    }
    return false;
  }
}
