// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

import 'pulse_delivery.dart';

/// The result of [CellAsValue.asValueCell].
///
/// Holds the mirror cell and a dispose callback that stops the internal
/// egress. The `dispose` callback **must** be called when the mirror is
/// no longer needed, or the egress will leak.
typedef MirroredCell<V> = ({
  ValueCell<V> cell,
  void Function() dispose,
});

/// Mirrors a [Cell] into a fresh [ValueCell<V>].
extension CellAsValue on Cell {
  /// Mirrors this cell into a fresh [ValueCell<V>].
  ///
  /// Returns a [MirroredCell] record with both the mirror and a `dispose`
  /// callback. **Prefer [CellValueBuilder] inside widgets** — it manages the
  /// mirror's lifecycle automatically. Use `asValueCell` when the mirror
  /// must outlive a widget (e.g., shared across a service layer).
  ///
  /// ## Usage
  ///
  /// ```dart
  /// class MyService {
  ///   late final MirroredCell<int> _mirror;
  ///
  ///   MyService(Cell source) {
  ///     _mirror = source.asValueCell<int>(initial: 0);
  ///   }
  ///
  ///   void dispose() => _mirror.dispose();
  ///
  ///   ValueCell<int> get mirror => _mirror.cell;
  /// }
  /// ```
  ///
  /// ## Why not a plain `ValueCell<V>` return?
  ///
  /// A plain return hides the `EgressHandle`. Users would have no way to
  /// stop the mirroring, which leaks when the mirror outlives the source
  /// or when the mirror is created in `build`. The record makes the
  /// lifecycle explicit. `CellValueBuilder` is the widget-layer alternative
  /// that Flutter's state lifecycle manages for you.
  ///
  /// ## Error pulses
  ///
  /// Error pulses are silently skipped. Use `CellValueBuilder(emitErrors: true)`
  /// or `asStream(emitErrors: true)` if you need to see them.
  ///
  /// ## Concurrent `asyncMap` caveat
  ///
  /// If the source is `Cell.asyncMap` with `concurrency > 0`, the mirror
  /// inherits the framework's Gate G1.5 caveat. The mirror's observation
  /// is correct; the caveat is about the source's replay fidelity.
  MirroredCell<V> asValueCell<V>({V? initial}) {
    final mirror = ValueCell<V>(initial: _seeded<V>(this, initial));
    final egress = Cell.observe<Pulse<Object?>>(
      source: this,
      effect: (pulse) {
        if (pulse.type == 'error') return;
        final payload = pulse.payload;
        if (payload == null && null is V) {
          mirror.value = null;
        } else if (payload is V) {
          mirror.value = payload;
        } else {
          Zone.current.handleUncaughtError(
            StateError(
              'asValueCell<$V>: pulse payload is ${payload.runtimeType}, '
              'not $V.',
            ),
            StackTrace.current,
          );
        }
      },
      initiallyStarted: true,
    );
    return (cell: mirror, dispose: egress.stop);
  }
}

V? _seeded<V>(Cell source, V? initial) {
  final latest = retainedPulseOf(source);
  if (latest == null || latest.type == 'error') return initial;
  final payload = latest.payload;
  if (payload is V) return payload;
  if (payload == null && null is V) return null;
  return initial;
}
