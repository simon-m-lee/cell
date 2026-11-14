// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cell_notifier.dart';

/// Rebuilds [builder] whenever [cell]'s value changes.
///
/// This is the binding's primary widget. Rebuild granularity is one widget
/// per [CellBuilder]; use multiple builders to isolate subtrees.
///
/// ## Usage
///
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
///
/// CellBuilder<int>(
///   cell: counter.cell.unmodifiable,   // read-only view
///   builder: (context, value) => Text('${value ?? 0}'),
/// )
/// ```
///
/// Pass `cell.unmodifiable` to hand a read-only view to children — Mitosis's
/// least-privilege story, surfaced at the widget layer.
class CellBuilder<V> extends StatefulWidget {
  /// Creates a builder bound to [cell].
  ///
  /// [cell] must be a [ValueCell] because state display needs a synchronous
  /// current value. For derived cells (`Cell.derive`, `Cell.synthesis`),
  /// use `asValueCell()` (Phase 3) to bridge.
  const CellBuilder({
    required this.cell,
    required this.builder,
    super.key,
  });

  /// The state source. Pass `cell.unmodifiable` for a read-only view.
  final ValueCell<V> cell;

  /// Rebuilds when [cell]'s value changes.
  ///
  /// Called at least once (initial build) with `cell.value`. Called again
  /// every time the cell emits a value different from the previous one.
  final Widget Function(BuildContext context, V? value) builder;

  @override
  State<CellBuilder<V>> createState() => _CellBuilderState<V>();
}

class _CellBuilderState<V> extends State<CellBuilder<V>> {
  CellNotifier<V>? _notifier;
  int _consecutiveCellSwaps = 0;

  void _bind() {
    _notifier = CellNotifier<V>(widget.cell);
  }

  void _unbind() {
    _notifier?.dispose();
    _notifier = null;
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(CellBuilder<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Identity check: swapping the cell requires rebinding; the same cell
    // (or an equal handle) does not.
    if (!identical(oldWidget.cell, widget.cell)) {
      _unbind();
      _bind();
      _consecutiveCellSwaps++;
      if (kDebugMode && _consecutiveCellSwaps >= 3) {
        debugPrint(
          'CellBuilder: the cell identity changed $_consecutiveCellSwaps '
          'times in a row. This usually means the cell is created in '
          'build() — an anti-pattern that breaks hot reload. '
          'Move the Cell.state / Cell.ingress call to initState, a '
          'State field, or a top-level final.',
        );
      }
    } else {
      _consecutiveCellSwaps = 0;
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V?>(
      valueListenable: _notifier!,
      builder: (ctx, value, _) => widget.builder(ctx, value),
    );
  }
}

/// Fluent constructor for a [CellBuilder] over this cell.
extension ValueCellBuilder<V> on ValueCell<V> {
  /// Shorthand for `CellBuilder(cell: this, builder: builder)`.
  ///
  /// ```dart
  /// counter.cell.builder((ctx, v) => Text('${v ?? 0}'))
  /// ```
  Widget builder(
    Widget Function(BuildContext context, V? value) builder, {
    Key? key,
  }) =>
      CellBuilder<V>(cell: this, builder: builder, key: key);
}
