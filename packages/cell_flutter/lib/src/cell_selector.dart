// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import 'cell_notifier.dart';
import 'pulse_delivery.dart';

/// Rebuilds [builder] only when the selected slice of [cell] changes.
///
/// ## When to use
///
/// Use when [CellBuilder] would rebuild too often — e.g. a `Cell<User>`
/// that rebuilds on every field, but a widget only reads `user.name`.
///
/// ```dart
/// CellSelector<User, String>(
///   cell: user.cell,
///   select: (u) => u?.name ?? '',
///   builder: (_, name) => Text(name),
/// );
/// ```
///
/// ## Comparison to `CellBuilder`
///
/// | | `CellBuilder<V>` | `CellSelector<V, S>` |
/// |---|---|---|
/// | Rebuild trigger | Value `V` changes | Selected `S` changes |
/// | Type params | 1 (`V`) | 2 (`V`, `S`) |
/// | Source type | `ValueCell<V>` | `ValueCell<V>` |
/// | Underlying | `ValueListenableBuilder` | `CellNotifier` + `addListener` + `setState` |
///
/// Both require `ValueCell`. For a `Cell.derive` / `Cell.synthesis` /
/// `Cell.switchMap` source, wrap it with `CellValueBuilder` first — or
/// mirror it with `asValueCell` and pass the mirror to `CellSelector`.
///
/// ## Equality
///
/// `equals` defaults to `==`. For `List`, `Set`, or `Map` selections,
/// provide `listEquals`, `setEquals`, `mapEquals` from `flutter/foundation`.
/// Without a custom `equals`, `[1, 2] != [1, 2]` (new instance), and the
/// widget rebuilds on every emission even though the content is equal.
///
/// ```dart
/// CellSelector<User, List<String>>(
///   cell: user.cell,
///   select: (u) => u?.roles ?? const [],
///   equals: (a, b) => listEquals(a, b),
///   builder: (_, roles) => RolesList(roles),
/// );
/// ```
class CellSelector<V, S> extends StatefulWidget {
  const CellSelector({
    required this.cell,
    required this.select,
    required this.builder,
    this.equals,
    super.key,
  });

  /// The source cell. Requires `ValueCell` — the widget needs a synchronous
  /// current value for `select` to run against.
  final ValueCell<V> cell;

  /// Derives the displayed slice from the cell's current value.
  final S Function(V? value) select;

  /// Renders the selected slice. Called on initial build and when the
  /// slice changes.
  final Widget Function(BuildContext context, S selected) builder;

  /// Equality predicate for the selected slice. Defaults to `==`.
  ///
  /// Collections need `listEquals` / `setEquals` / `mapEquals`. Without a
  /// custom predicate, a fresh collection with the same content triggers
  /// a rebuild on every emission.
  final bool Function(S previous, S next)? equals;

  @override
  State<CellSelector<V, S>> createState() => _CellSelectorState<V, S>();
}

class _CellSelectorState<V, S> extends State<CellSelector<V, S>> {
  late CellNotifier<V> _notifier;
  late S _selected;
  late bool Function(S, S) _equals;

  @override
  void initState() {
    super.initState();
    _notifier = CellNotifier<V>(widget.cell);
    _equals = widget.equals ?? _defaultEquals;
    _selected = widget.select(_notifier.value);
    assert(
      widget.equals != null || !_isCollection(_selected),
      'CellSelector: select returned a collection '
      '(${_selected.runtimeType}) but equals is null. Collections use '
      'identity equality by default, so the widget will rebuild on every '
      'emission even when the content is equal. Provide equals: '
      'listEquals, setEquals, or mapEquals from package:flutter/foundation.dart.',
    );
    _notifier.addListener(_onChange);
  }

  static bool _defaultEquals<S>(S a, S b) => a == b;

  static bool _isCollection(Object? o) =>
      o is Map || (o is Iterable && o is! String);

  void _onChange() {
    if (!mounted) return;
    runAfterBuild(() {
      if (!mounted) return;
      final next = widget.select(_notifier.value);
      if (!_equals(_selected, next)) {
        setState(() => _selected = next);
      }
    });
  }

  @override
  void didUpdateWidget(CellSelector<V, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _equals = widget.equals ?? _defaultEquals;
    if (!identical(oldWidget.cell, widget.cell)) {
      _notifier.removeListener(_onChange);
      _notifier.dispose();
      _notifier = CellNotifier<V>(widget.cell);
      _notifier.addListener(_onChange);
      _selected = widget.select(_notifier.value);
    } else if (!identical(oldWidget.select, widget.select)) {
      // Selector logic changed with the same cell: recompute the slice
      // rather than render a stale value until the next pulse.
      final next = widget.select(_notifier.value);
      if (!_equals(_selected, next)) {
        _selected = next;
      }
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_onChange);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected);
}
