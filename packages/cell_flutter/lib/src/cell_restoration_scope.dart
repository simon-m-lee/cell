// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:flutter/widgets.dart';

import 'cell_restoration.dart';

/// Provides a [RestorationBucket] to descendant [RestorableCell]s and
/// registers them automatically with Flutter's restoration protocol.
///
/// [CellRestorationScope] is the binding's **Restoration Registry** — the
/// widget-layer counterpart of [CellScope]. Placing it above a subtree:
///
/// 1. Claims a child `RestorationBucket` from the nearest enclosing
///    `RestorationScope` (or [RootRestorationScope]) under
///    [restorationScopeId].
/// 2. Exposes [CellRestorationScopeState.register] /
///    [CellRestorationScopeState.unregister] through the widget tree,
///    which descendant `State`s call for each [RestorableCell] they own.
/// 3. Re-registers every known cell on each `restoreState` callback, so a
///    bucket arriving after mount (process restart) rewrites the restored
///    values into the cells before the next build.
///
/// ### Registration timing (read this)
/// Register cells from `initState` or `didChangeDependencies` — never from
/// `build`. Registration writes the restored value into the cell, which
/// emits through the reactive graph; doing that during a build phase can
/// trigger a `setState`-during-build error in observing widgets. The scope
/// itself performs its registration work before descendant `initState`s
/// run, so `initState` registration is always safe.
///
/// ### Injected buckets
/// Passing [bucket] wraps the scope in an [UnmanagedRestorationScope],
/// which is how tests (and hot-restart tooling) inject a specific bucket —
/// e.g. a `RestorationBucket.root` built from persisted data. Without it,
/// the bucket is claimed from the enclosing `RestorationScope` as usual.
///
/// ### Nested scopes
/// Nested [CellRestorationScope]s claim independent child buckets and
/// restore independently — the same nearest-scope rule as [CellScope].
///
/// ### Example
/// ```dart
/// RootRestorationScope(
///   restorationId: 'root',
///   child: CellRestorationScope(
///     restorationScopeId: 'app',
///     child: MyApp(),
///   ),
/// );
/// ```
///
/// ### See Also:
/// - [RestorableCell] — the cell type registered here.
/// - [restorableState] / [CellRestoration.restorableState] — the factory.
/// - [RestorationMixin] / [UnmanagedRestorationScope] — the Flutter
///   primitives this composes.
class CellRestorationScope extends StatelessWidget {
  /// Creates a restoration scope for the subtree below [child].
  const CellRestorationScope({
    required this.restorationScopeId,
    required this.child,
    this.bucket,
    super.key,
  });

  /// The id under which this scope claims its [RestorationBucket].
  final String restorationScopeId;

  /// The subtree whose [RestorableCell]s may register here.
  final Widget child;

  /// An optional pre-built bucket to inject (tests, hot-restart tooling).
  final RestorationBucket? bucket;

  /// Returns the nearest enclosing [CellRestorationScopeState], or `null`.
  ///
  /// Registration is one-shot and state-based (`findAncestorStateOfType`):
  /// the lookup does not register an inherited-widget dependency, and a
  /// **missing scope silently skips restoration**. When no scope encloses
  /// [context], `maybeOf(context)?.register(cell)` is a no-op — use
  /// [of] (or an assert) when restoration is required.
  static CellRestorationScopeState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<CellRestorationScopeState>();

  /// Returns the nearest enclosing [CellRestorationScopeState].
  ///
  /// ### Throws:
  /// [StateError] when no [CellRestorationScope] encloses [context].
  static CellRestorationScopeState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw StateError(
        'CellRestorationScope.of: no CellRestorationScope above this '
        'widget.',
      );
    }
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final inner = _CellRestorationScope(
      restorationScopeId: restorationScopeId,
      child: child,
    );
    if (bucket == null) return inner;
    // The injected bucket must be above the mixin-bearing state so the
    // RestorationMixin can claim from it in didChangeDependencies.
    return UnmanagedRestorationScope(bucket: bucket!, child: inner);
  }
}

/// The stateful, mixin-bearing half of [CellRestorationScope].
///
/// Public so tests can reach the claimed [bucket] through
/// `tester.state<CellRestorationScopeState>(...)`.
class CellRestorationScopeState extends State<_CellRestorationScope>
    with RestorationMixin {
  /// Cells currently registered, keyed by their restoration id.
  ///
  /// Delegates are typed `<Object?>` so the idempotence check below is
  /// independent of the caller's `V` (a `RestorableCell<int>` registered
  /// through a `RestorableCell<Object?>` reference is the same cell).
  final Map<String, RestorableCellDelegate<Object?>> _registered = {};

  @override
  String get restorationId => widget.restorationScopeId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // Properties registered outside restoreState must be re-registered
    // here on every restore. Re-registration replays initWithValue, which
    // rewrites the restored value into each cell.
    // coverage:ignore-start
    // Executed when the engine delivers new restoration data mid-session
    // (RestorationManager.handleRestorationUpdateFromEngine); widget tests
    // cannot drive that protected path directly.
    for (final entry in _registered.entries.toList()) {
      registerForRestoration(entry.value, entry.key);
    }
    // coverage:ignore-end
  }

  /// Registers [cell] for restoration under its [RestorableCell.restorationId].
  ///
  /// Idempotent for the same cell instance. Registering a **different**
  /// cell under an id that is already registered throws [StateError] — ids
  /// must be unique within this scope.
  ///
  /// Call from `initState` / `didChangeDependencies` (never from `build`):
  /// registration writes the restored value into the cell.
  void register<V>(RestorableCell<V> cell) {
    final existing = _registered[cell.restorationId];
    if (existing != null) {
      if (identical(existing.cell, cell)) {
        return; // Idempotent re-registration.
      }
      throw StateError(
        'CellRestorationScope: restorationId "${cell.restorationId}" is '
        'already registered. Each RestorableCell needs a unique id.',
      );
    }
    final delegate = RestorableCellDelegate<V>(cell);
    try {
      registerForRestoration(delegate, cell.restorationId);
    } catch (_) {
      // A codec failure (e.g. UnsupportedError from fromPrimitives) must
      // not leave the delegate half-registered.
      delegate.dispose();
      rethrow;
    }
    _registered[cell.restorationId] = delegate;
  }

  /// Unregisters [cell], removing its value from the restoration data.
  ///
  /// Idempotent: unregistering a cell that is not registered is a no-op.
  void unregister<V>(RestorableCell<V> cell) {
    final delegate = _registered.remove(cell.restorationId);
    if (delegate == null) return;
    unregisterFromRestoration(delegate);
    delegate.dispose();
  }

  /// The cells currently registered, by restoration id.
  ///
  /// Exposed for debugging and tests; do not mutate.
  Map<String, RestorableProperty<Object?>> get registeredCells =>
      Map.unmodifiable(_registered);

  @override
  void dispose() {
    for (final entry in _registered.entries.toList()) {
      // Every map entry was registered when added; the mixin unlinks the
      // property from this state inside unregisterFromRestoration, after
      // which the delegate's dispose releases its internal observation.
      unregisterFromRestoration(entry.value);
      entry.value.dispose();
    }
    _registered.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = _CellRestorationScopeInherited(
      register: register,
      unregister: unregister,
      child: widget.child,
    );
    // Inject the claimed bucket for descendant scopes, mirroring
    // RestorationScope's own pattern — nested CellRestorationScopes claim
    // their children from this bucket.
    final claimed = bucket;
    return claimed == null
        ? inner
        : UnmanagedRestorationScope(bucket: claimed, child: inner);
  }
}

class _CellRestorationScope extends StatefulWidget {
  const _CellRestorationScope({
    required this.restorationScopeId,
    required this.child,
  });

  final String restorationScopeId;
  final Widget child;

  @override
  State<_CellRestorationScope> createState() => CellRestorationScopeState();
}

class _CellRestorationScopeInherited extends InheritedWidget {
  const _CellRestorationScopeInherited({
    required this.register,
    required this.unregister,
    required super.child,
  });

  final void Function<V>(RestorableCell<V> cell) register;
  final void Function<V>(RestorableCell<V> cell) unregister;

  // coverage:ignore-start
  // The callbacks are bound to the same State for its lifetime; the VM
  // does not attribute this arrow one-liner in coverage reports.
  @override
  bool updateShouldNotify(_CellRestorationScopeInherited oldWidget) => false; // coverage:ignore-end
}
