// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';

/// Adapts a [ValueCell<V>] to Flutter's [ValueNotifier<V?>] contract.
///
/// Reads are synchronous (the cell's storage is read on `.value`); writes
/// come from the cell's own observers. The adapter subscribes to the cell
/// in the constructor and unsubscribes on [dispose].
///
/// ## Usage
///
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
/// final notifier = CellNotifier(counter.cell);
///
/// print(notifier.value); // 0
/// counter.update(5);
/// print(notifier.value); // 5
/// notifier.dispose();
/// ```
///
/// ## Mutability
///
/// [CellNotifier] is **read-only by contract**. The `.value` setter throws
/// [UnsupportedError]; mutate the underlying cell instead:
///
/// ```dart
/// notifier.value = 42; // throws
/// notifier.cell.value = 42; // correct
/// ```
///
/// This is deliberate: a writable `ValueNotifier` whose value diverges from
/// the cell's value is a silent bug. The override enforces the invariant.
class CellNotifier<V> extends ValueNotifier<V?> {
  /// Subscribes to [cell] and seeds the notifier with its current value.
  ///
  /// Throws [ArgumentError] if [cell] is invalidated — subscribing to a
  /// dead cell produces a notifier that will never fire.
  CellNotifier(this.cell) : super(_initialValue(cell)) {
    _egress = Cell.observe<Pulse<V>>(
      source: cell,
      effect: _onPulse,
      initiallyStarted: true,
    );
  }

  /// The cell being observed.
  final ValueCell<V> cell;

  EgressHandle<Pulse<V>>? _egress;
  bool _disposed = false;

  static V? _initialValue<V>(ValueCell<V> cell) {
    if (cell.isInvalidated) {
      throw ArgumentError(
        'CellNotifier: cannot observe an invalidated cell.',
      );
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

  /// Not supported. Mutate [cell] directly.
  @override
  set value(V? _) {
    throw UnsupportedError(
      'CellNotifier: cannot assign value directly. '
      'Mutate the cell: `cell.value = ...`.',
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _egress?.stop();
    _egress = null;
    super.dispose();
  }
}
