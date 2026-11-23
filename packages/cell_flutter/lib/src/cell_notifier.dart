// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';

/// Adapts a [ValueCell] to Flutter's [ValueNotifier] contract as a
/// **read-only** bridge.
///
/// [CellNotifier] is the binding's **Listenable Adapter**. It exposes a
/// [ValueCell]'s value through the standard `ValueNotifier<V?>` interface so
/// that Flutter primitives built around [Listenable] — `ValueListenableBuilder`,
/// `AnimatedBuilder`, `ListenableBuilder` — can consume a cell without knowing
/// about the reactive graph. Reads are synchronous (the cell's storage is
/// read on `.value`); writes flow **only** from the cell's own observers, not
/// from outside.
///
/// ### Why it is used
/// - **Flutter-native binding**: `CellBuilder` and `CellSelector` both build
///   on `CellNotifier`. Any Flutter widget that takes a [ValueListenable]
///   can take a `CellNotifier` directly.
/// - **Single observer per listener**: the adapter owns exactly one
///   `EgressHandle` on the cell; several Flutter consumers of the same
///   notifier share that one observation rather than each opening their own.
/// - **Synchronous read**: `notifier.value` returns the current value
///   immediately — useful for `select` projections, `initState` seeding,
///   and testing.
///
/// ### How it works
/// 1. **Subscribe**: the constructor seeds the notifier with the cell's
///    current value and opens one `Cell.observe` link on the cell.
/// 2. **Forward**: each pulse assigns `pulse.payload` to the underlying
///    [ValueNotifier.value]. Assigning on a `ValueNotifier` notifies its
///    listeners, which Flutter widgets like `ValueListenableBuilder`
///    receive as a rebuild request.
/// 3. **Filter**: error pulses (`pulse.type == 'error'`) are ignored — they
///    are not values, and the `ValueNotifier<V?>` contract has nowhere to
///    put them. Display widgets that need to render errors subscribe to the
///    cell directly (e.g. via `CellListener` or `CellAsyncBuilder`).
/// 4. **Dispose**: the egress is stopped and the underlying notifier is
///    disposed.
///
/// ### Design Note: `CellNotifier` is read-only by contract
/// [CellNotifier] extends [ValueNotifier] but **overrides the value setter
/// to throw** [UnsupportedError]. This is deliberate and load-bearing:
/// a writable `ValueNotifier` whose value diverges from its cell's value is
/// a silent bug — Flutter would rebuild on writes that the cell never
/// observed, and the two sources of truth would drift. Mutating the cell
/// instead (`cell.value = ...`) routes the change through the cell's
/// integrity gates and broadcasts it through the reactive graph, so every
/// dependent of the cell sees it — not just the widgets listening to this
/// one notifier.
///
/// ### Pulse semantics
/// - **Data pulses** assign to `super.value` synchronously. See the
///   *Synchronous delivery* note below for why this is intentional.
/// - **Error pulses** are silently dropped. This is a display adapter, not
///   an error surface.
/// - **Type-mismatch pulses** are not expected: the subscription is typed
///   `Cell.observe<Pulse<V>>` and `Pulse<V>.payload` is statically `V?`, so
///   the payload type is consistent with the notifier's value type.
///
/// ### Synchronous delivery (read this)
/// `super.value = pulse.payload` is assigned synchronously in `_onPulse`.
/// If a pulse arrives while a sibling `CellBuilder`'s subtree is mid-build,
/// this assignment marks the notifier's dependents dirty **during the
/// build** — which is exactly what we want: Flutter then raises its
/// *"setState() or markNeedsBuild() called during build"* framework error
/// instead of silently dropping the rebuild. The error is attributed to
/// the `CellBuilder` element, **not** to the widget that emitted the
/// pulse; the bug is the emission from inside `build`. Swallowing it would
/// hide the bug. Widgets that want the opposite — deferral to the end of
/// the frame — use `CellValueBuilder`, `CellAsyncBuilder`, or
/// `CellListener`, which manage a pending queue. The burden of correctness
/// falls on every cell that has a `CellBuilder` in the tree: never mutate
/// a cell from inside `build`.
///
/// ### Technical Details
/// - **One egress per notifier**: the adapter opens exactly one
///   `Cell.observe` link; disposing the notifier stops it.
/// - **Nullable `V?`**: the notifier exposes `V?` (not `V`), matching a
///   not-yet-emitted cell. `null is V`-aware downstream widgets handle the
///   nullable value.
/// - **Constructor-time validation**: subscribing to an invalidated cell
///   throws [ArgumentError] rather than producing a notifier that will never
///   fire.
///
/// ### Example
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
/// final notifier = CellNotifier(counter.cell);
///
/// print(notifier.value); // 0
/// counter.update(5);
/// print(notifier.value); // 5
///
/// notifier.value = 42;   // throws UnsupportedError
/// notifier.cell.value = 42; // correct: mutate the cell
///
/// notifier.dispose();
/// ```
///
/// ### See Also:
/// - [ValueNotifier] — the Flutter primitive this extends.
/// - `CellBuilder` — the widget that wraps `CellNotifier` in a
///   `ValueListenableBuilder`.
/// - `CellSelector` — the widget that adds slice-based rebuild granularity
///   on top of `CellNotifier`.
/// - `Cell.observe` — the underlying observation primitive.
class CellNotifier<V> extends ValueNotifier<V?> {
  /// Subscribes to [cell] and seeds the notifier with its current value.
  ///
  /// ### Parameters:
  /// * [cell]: **The Observed Cell.** The [ValueCell] whose value this
  ///   notifier mirrors. Held by reference for the lifetime of the
  ///   notifier; callers may read `notifier.cell` to reach the source.
  ///
  /// ### Throws:
  /// [ArgumentError] if [cell] is invalidated. Subscribing to a dead cell
  /// would produce a notifier that never fires — a latent bug, not a
  /// recoverable state.
  ///
  /// ### See Also:
  /// - [dispose] — releases the egress and the underlying [ValueNotifier].
  CellNotifier(this.cell) : super(_initialValue(cell)) {
    _egress = Cell.observe<Pulse<V>>(
      source: cell,
      effect: _onPulse,
      initiallyStarted: true,
    );
  }

  /// The cell being observed.
  ///
  /// Exposed for callers that need to reach the source (e.g. to mutate it,
  /// since [value] is read-only here). The cell is not owned by the
  /// notifier — dispose does not invalidate it.
  final ValueCell<V> cell;

  EgressHandle<Pulse<V>>? _egress;
  bool _disposed = false;

  static V? _initialValue<V>(ValueCell<V> cell) {
    if (cell.isInvalidated) {
      throw ArgumentError('CellNotifier: cannot observe an invalidated cell.');
    }
    return cell.value;
  }

  void _onPulse(Pulse<V> pulse) {
    // Defensive: EgressHandle.stop() is synchronous, so this should never
    // fire after disposal. Guard anyway against future changes to
    // Cell.observe's cancellation semantics.
    if (_disposed) return;
    // Error pulses are not values. Display widgets that understand them
    // subscribe to the cell directly.
    if (pulse.type == 'error') return;
    // Deliberately synchronous: a pulse that arrives while a sibling
    // CellBuilder is building must mark it dirty immediately, so Flutter
    // raises its "setState() or markNeedsBuild() called during build"
    // framework error instead of silently dropping the rebuild.
    super.value = pulse.payload;
  }

  /// Not supported — this notifier is read-only by contract.
  ///
  /// Writing through [CellNotifier] would create a second source of truth
  /// that diverges from the cell: the cell's integrity gates would be
  /// bypassed, and observers of the cell would not see the change. Mutate
  /// the cell instead:
  ///
  /// ```dart
  /// notifier.value = 42;       // throws UnsupportedError
  /// notifier.cell.value = 42;  // correct: routes through the cell
  /// ```
  ///
  /// ### Throws:
  /// Always throws [UnsupportedError]. The setter exists only to close the
  /// `ValueNotifier.value` contract inherited from the superclass.
  ///
  /// ### See Also:
  /// - [cell] — the correct mutation target.
  /// - [CellNotifier] class docs, *Design Note: `CellNotifier` is read-only
  ///   by contract*, for the rationale.
  @override
  set value(V? _) {
    throw UnsupportedError(
      'CellNotifier: cannot assign value directly. '
      'Mutate the cell: `cell.value = ...`.',
    );
  }

  /// Stops observing [cell] and disposes the underlying [ValueNotifier].
  ///
  /// Idempotent: repeated calls are no-ops. After disposal, the notifier
  /// no longer forwards cell pulses and no longer notifies its listeners.
  /// The observed [cell] is **not** invalidated — disposal releases this
  /// adapter's observation link only.
  ///
  /// ### See Also:
  /// - [CellNotifier] class docs for the lifecycle contract.
  /// - `EgressHandle.stop` — the primitive used to release the link.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _egress?.stop();
    _egress = null;
    super.dispose();
  }
}
