// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An [InheritedWidget] that provides a small set of app-level cells to the
/// subtree below it, addressed by [Symbol].
///
/// [CellScope] is the binding's **App-Level Cell Registry**. It exists for
/// the handful of cells that are genuinely global — `auth`, `theme`,
/// `featureFlags`, `currentUser` — and should not become a general-purpose
/// service locator. Mitosis's philosophy is that cells flow through the tree
/// explicitly; passing a cell as a constructor argument is the default, and
/// [CellScope] is the escape hatch for the few identifiers that every layer
/// of the app needs to reach by name.
///
/// ### Why it is used
/// - **Well-known globals**: register the small set of cells whose identity
///   is stable for the lifetime of the app, so distant widgets can find them
///   without threading them through every intermediate widget.
/// - **Symbol-keyed lookup**: keys are `Symbol`s (`#auth`, `#theme`), not
///   type parameters. A single app commonly has several `Cell` values of the
///   same `V` (multiple `Cell<User>`, several `Cell<int>`), and type-keyed
///   lookup cannot tell them apart.
/// - **Subtree scoping**: nested [CellScope]s allow a feature to expose its
///   own cells without polluting the app-wide registry, while still obeying
///   the nearest-scope rule described under *Nested scopes*.
///
/// ### How it works
/// 1. **Registration**: a [CellScope] takes a `Map<Symbol, Cell>` and places
///    it in the widget tree above its [child].
/// 2. **Lookup**: [of], [maybeOf], and [valueOf] perform a
///    `dependOnInheritedWidgetOfExactType<CellScope>()` call, which both
///    retrieves the nearest enclosing scope **and** registers the caller as
///    a dependent — so the caller is rebuilt only when [updateShouldNotify]
///    returns `true`.
/// 3. **Type widening and narrowing**: [of] / [maybeOf] accept a value-type
///    parameter `V` and narrow the returned cell to `ValueCell<V>` when the
///    registration is a `ValueCell`. Plain `Cell` registrations are returned
///    unchanged — the value type only exists on the pulse they emit.
///
/// ### Design Note: `Symbol` keys, not type keys
/// Type-keyed lookup (`Provider<T>`, `InheritedWidget` subclasses per type)
/// fails in a Mitosis app for the same reason it would fail in a rich domain
/// model: type is not identity. `#auth` and `#profile` may both be
/// `Cell<User>`; `#theme` and `#draftTheme` may both be `Cell<ThemeData>`.
/// `Symbol` keys make the intent explicit at both the registration and the
/// lookup site and enable the debug shadow warning below.
///
/// ### Lookup semantics
/// | Method | Unknown id | Type mismatch | Requires `ValueCell` |
/// |---|---|---|---|
/// | [of] | throws | throws | no |
/// | [maybeOf] | returns `null` | throws | no |
/// | [valueOf] | throws | throws | yes |
///
/// A type mismatch on a `ValueCell` registration always throws — it is a
/// caller bug, not an absence. Unknown ids return `null` through [maybeOf]
/// only; [of] and [valueOf] treat them as bugs.
///
/// ### Nested scopes
/// If a [CellScope] is nested inside another,
/// `dependOnInheritedWidgetOfExactType<CellScope>()` returns the **nearest**
/// one. Inner registrations therefore shadow outer ones for the same
/// [Symbol]. This matches [InheritedWidget]'s contract. In debug builds
/// [_lookup] inspects ancestors and emits a `debugPrint` warning — once per
/// symbol per session — when a lookup finds a registration that would be
/// shadowed by a nearer scope. The warning is usually a sign that a feature
/// scope has accidentally duplicated an app-wide id.
///
/// ### Rebuild behavior
/// [updateShouldNotify] returns `true` only when the **effective map**
/// changes: a cell at a key is replaced with a cell that is not `==` to
/// the previous one, or the key set changes length. `Cell` overrides `==`
/// as nucleus-based logical identity, so swapping a cell for an equal
/// handle (such as a deputy of the same cell) does **not** notify
/// dependents. A parent re-build that constructs an equal-but-distinct map
/// — a common accident when the map literal is inlined in `build` — also
/// does **not** trigger descendant rebuilds.
///
/// ### Example
/// ```dart
/// // App root:
/// final auth  = Cell.state<AuthState?>(initial: null);
/// final theme = Cell.state<ThemeData>(initial: ThemeData.light());
///
/// CellScope(
///   cells: {
///     #auth:  auth.cell,
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
/// ### Parameters:
/// * [cells]: **The Registry.** A `Map<Symbol, Cell>` of app-level cells.
///   Keys are the well-known `Symbol`s; values are the `Cell`s they resolve
///   to. Held by reference — the map is not copied.
/// * [child]: **The Scoped Subtree.** The widget whose descendants may
///   perform lookups against this registry.
///
/// ### See Also:
/// - [InheritedWidget] — the Flutter primitive this builds on.
/// - `CellBuilder` / `CellValueBuilder` — the widgets that typically consume
///   `valueOf` / `of` results.
/// - `CellScope.valueOf` — the common lookup for `ValueCell`-backed
///   registrations.
class CellScope extends InheritedWidget {
  /// Registers [cells] under [Symbol] keys for the subtree below [child].
  ///
  /// Keys are `Symbol`s (`#auth`, `#theme`), not type parameters — see the
  /// class-level *Design Note* for why.
  const CellScope({
    required this.cells,
    required super.child,
    super.key,
  });

  /// The registered cells: keys are `Symbol`s, values are `Cell`s.
  ///
  /// The map is stored by reference; callers should not mutate it after
  /// construction. Mutating it in place bypasses [updateShouldNotify] and
  /// leaves already-dependent widgets out of date.
  final Map<Symbol, Cell> cells;

  /// Returns the cell registered at [id] in the nearest enclosing [CellScope].
  ///
  /// ### Parameters:
  /// * [context]: **The Lookup Context.** Must be beneath a [CellScope].
  /// * [id]: **The Registration Key.** The `Symbol` used at registration.
  ///
  /// ### Returns:
  /// The registered [Cell]. If the registration is a `ValueCell<V>`, the
  /// result is narrowed to that type; plain `Cell` registrations are returned
  /// as-is.
  ///
  /// ### Throws:
  /// - [AssertionError] in debug (or [StateError] in release) when there is
  ///   no [CellScope] above [context], or when no cell is registered under
  ///   [id]. Both are programmer bugs.
  /// - [StateError] on a **type mismatch**: a `ValueCell` registered under
  ///   [id] whose value type does not satisfy `V`.
  ///
  /// ### See Also:
  /// - [maybeOf] — nullable variant for optional registrations.
  /// - [valueOf] — narrows the result to `ValueCell<V>`.
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

  /// Like [of], but returns `null` when [id] is not registered (or no
  /// [CellScope] encloses [context]).
  ///
  /// **`maybeOf` does not swallow type mismatches.** A missing scope or
  /// unknown id is treated as an absence, not a bug; a **type mismatch**
  /// on a `ValueCell` registration still throws [StateError] — that is a
  /// caller bug, not an absence. Use this only when absence is a valid
  /// test outcome.
  ///
  /// Unlike [of], `maybeOf` does not emit the nested-shadow debug warning
  /// — it is the quiet probe for optional lookups.
  ///
  /// ### Parameters:
  /// * [context]: **The Lookup Context.**
  /// * [id]: **The Registration Key.**
  ///
  /// ### Returns:
  /// The registered [Cell], or `null` if there is no [CellScope] above
  /// [context] or no cell is registered under [id].
  ///
  /// ### Throws:
  /// [StateError] on a type mismatch.
  ///
  /// ### See Also:
  /// - [of] — non-nullable variant that treats absence as a bug.
  /// - [valueOf] — narrows the result to `ValueCell<V>`.
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

  /// Returns the cell registered at [id], narrowed to [ValueCell<V>].
  ///
  /// This is the common lookup for `CellBuilder`: `Cell.state` returns a
  /// [ValueCell] internally, and most app-level registrations are
  /// [ValueCell]s. Registrations that are not `ValueCell<V>` throw —
  /// use [of] for plain `Cell` sources (`Cell.derive`, `Cell.asyncMap`,
  /// `Cell.ingress`, `cell_tissue` collections).
  ///
  /// ### Parameters:
  /// * [context]: **The Lookup Context.**
  /// * [id]: **The Registration Key.**
  ///
  /// ### Returns:
  /// The registered cell, statically typed as [ValueCell<V>].
  ///
  /// ### Throws:
  /// - All the conditions under which [of] throws.
  /// - [StateError] when the registration is a `ValueCell` whose value type
  ///   does not satisfy `V`, **or** when the registration is not a
  ///   `ValueCell` at all.
  ///
  /// ### See Also:
  /// - [of] — the un-narrowed lookup for any [Cell].
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
  ///
  /// One warning per symbol per debug session; tests may clear this set to
  /// observe the warning again. Only consulted in debug builds.
  @visibleForTesting
  static final Set<Symbol> shadowWarned = <Symbol>{};

  static Cell _lookup(BuildContext context, Symbol id) {
    final scope = context.dependOnInheritedWidgetOfExactType<CellScope>();
    // Debug-mode contracts: a missing scope or an unknown id is a bug and
    // fails as an AssertionError during development. The StateError
    // fallbacks keep the behavior defined in release builds.
    assert(scope != null, 'CellScope.of: no CellScope above this widget.');
    // coverage:ignore-start
    // Release-only fallback: in debug builds the assert above throws
    // first, so the fallback is unreachable in debug coverage runs.
    if (scope == null) {
      throw StateError('No CellScope above this widget.');
    }
    // coverage:ignore-end
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
    // coverage:ignore-start
    // Release-only fallback: in debug builds the assert above throws
    // first, so the fallback is unreachable in debug coverage runs.
    if (cell == null) {
      throw StateError('No cell registered under $id.');
    }
    // coverage:ignore-end
    return cell;
  }

  /// Returns `true` only when the **effective map** of cells has changed.
  ///
  /// The check is intentionally equality-based:
  /// 1. Same map instance → no change.
  /// 2. Different length → change (a key was added or removed).
  /// 3. Otherwise, compare the cell at each key with `==`; a replacement
  ///    with a cell that is not equal is a change.
  ///
  /// `Cell` defines `==` as nucleus-based logical identity, so an equal
  /// handle — a deputy of the same cell, or the same cell re-wrapped — is
  /// **not** a change. A parent rebuild that constructs an equal-but-distinct
  /// map — the common accident of writing the map literal inline in `build` —
  /// does **not** notify descendants, because the cells behind each `Symbol`
  /// are unchanged.
  ///
  /// ### Parameters:
  /// * [oldWidget]: **The Previous Scope.** The [CellScope] from the prior
  ///   build at the same position in the tree.
  ///
  /// ### Returns:
  /// `true` if descendants that depend on this scope should rebuild.
  @override
  bool updateShouldNotify(CellScope oldWidget) {
    if (identical(cells, oldWidget.cells)) return false;
    if (cells.length != oldWidget.cells.length) return true;
    for (final id in cells.keys) {
      if (cells[id] != oldWidget.cells[id]) return true;
    }
    return false;
  }
}
