// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import 'cell_notifier.dart';
import 'pulse_delivery.dart';

/// A widget that rebuilds its [builder] only when a **selected slice** of
/// [cell]'s value changes.
///
/// [CellSelector] is the binding's **Granularity Reducer**. Where [CellBuilder]
/// rebuilds on every value change of a [ValueCell], `CellSelector` projects
/// that value through a pure [select] function and rebuilds only when the
/// projection differs under [equals]. The common case: a `Cell<User>` that
/// changes on every field, but a widget that only reads `user.name`.
///
/// ### Why it is used
/// - **Sub-value rendering**: display one field of a larger state object
///   without rebuilding when unrelated fields change.
/// - **Derived display values**: format, sum, join, or otherwise derive the
///   visible value inside [select] without creating an intermediate cell.
/// - **Isolating hot cells**: a single high-frequency `ValueCell` can drive
///   many independent `CellSelector` widgets; each rebuilds only when its
///   own slice changes.
///
/// ### How it works
/// 1. **Binding**: the widget constructs a [CellNotifier] over [cell]. A
///    [CellNotifier] subscribes to the cell and exposes its value
///    synchronously via `ValueNotifier.value`.
/// 2. **Initial projection**: on `initState`, [select] is run against the
///    notifier's current value and the result is stored as `_selected`.
/// 3. **Listening**: the widget registers `_onChange` on the notifier. On
///    every notify, `_onChange` re-runs [select] against the current value,
///    compares to `_selected` with [equals], and calls `setState` only when
///    the slice actually changed.
/// 4. **Build-phase safety**: `_onChange` routes through [runAfterBuild] so
///    a pulse arriving mid-frame is applied after the frame — no
///    `setState() … called during build` from a sibling `CellBuilder`.
/// 5. **Cell swap**: if [cell] identity changes in `didUpdateWidget`, the
///    old notifier is disposed and a new one is bound; the slice is
///    recomputed. If only [select] changes, the slice is recomputed without
///    rebinding the notifier.
/// 6. **Disposal**: the listener is removed and the notifier disposed.
///
/// ### Build-phase pulses (read this)
/// `CellSelector` defers its own `setState` through [runAfterBuild], but
/// its [CellNotifier] still notifies **synchronously**. A pulse that
/// arrives mid-build therefore marks any sibling `CellBuilder` on the same
/// cell dirty during the build, and Flutter raises its *"setState() or
/// markNeedsBuild() called during build"* error **at that sibling** — the
/// bug is in whatever emitted the pulse from inside `build`. Ensure no
/// widget mutates a cell from inside `build`.
///
/// ### Design Note: `CellSelector` vs. `CellBuilder`
/// | | `CellBuilder<V>` | `CellSelector<V, S>` |
/// |---|---|---|
/// | Rebuild trigger | Value `V` changes | Selected `S` changes |
/// | Type parameters | 1 (`V`) | 2 (`V`, `S`) |
/// | Source type | `ValueCell<V>` | `ValueCell<V>` |
/// | Underlying | `ValueListenableBuilder` | [CellNotifier] + `addListener` + `setState` |
/// | Cost | Cheap when `V` is small | Always runs [select] per pulse; only pays `setState` when the slice moves |
///
/// Both require a [ValueCell]. For a `Cell.derive` / `Cell.synthesis` /
/// `Cell.switchMap` source, use `CellValueBuilder` directly, or mirror the
/// cell with `asValueCell` and pass the mirror to `CellSelector`.
///
/// ### Equality (read this)
/// [equals] defaults to `==`. For `List`, `Set`, and `Map` selections, pass
/// `listEquals` / `setEquals` / `mapEquals` from `package:flutter/foundation.dart`.
/// Without a custom predicate, a fresh collection with identical content
/// produces `[1, 2] != [1, 2]` (different instances), and the widget
/// rebuilds on every emission. In debug builds, `initState` asserts when
/// [select] returns a collection and [equals] is `null` — catch the bug
/// early rather than at 60 Hz.
///
/// ### Technical Details
/// - **Stateless [select] assumed**: [select] is expected to be pure and
///   cheap. It runs on every notifier tick; if [select] itself is expensive,
///   memoize downstream or move the derivation into a `Cell.derive` upstream.
/// - **Synchronous read**: [CellNotifier] exposes the current value
///   synchronously, so `select(_notifier.value)` never blocks or awaits.
/// - **Rebuild isolation**: `setState` is scoped to this element; only the
///   subtree under [builder] rebuilds.
/// - **Selection stability**: `_selected` is preserved across rebuilds of
///   this widget; it is only replaced when the [equals] comparison reports a
///   difference.
///
/// See also:
/// - [CellBuilder] — the general `ValueCell` binding (no slice reduction).
/// - `CellValueBuilder` — for plain `Cell` sources that are not `ValueCell`.
/// - [CellNotifier] — the `ValueNotifier` adapter this widget builds on.
/// - `runAfterBuild` — the build-phase deferral used by `_onChange`.
class CellSelector<V, S> extends StatefulWidget {
  /// Creates a selector over [cell] that renders `select(value)` and
  /// rebuilds when it changes under [equals].
  const CellSelector({
    required this.cell,
    required this.select,
    required this.builder,
    this.equals,
    super.key,
  });

  /// The source cell.
  ///
  /// Must be a [ValueCell] — the widget reads the current value
  /// synchronously for [select] to run against. For plain `Cell` sources,
  /// use `CellValueBuilder` or mirror with `asValueCell` first.
  final ValueCell<V> cell;

  /// Derives the displayed slice from [cell]'s current value.
  ///
  /// Runs on first build and on every notifier tick. Keep it pure and
  /// cheap. The argument is nullable (`V?`) so a not-yet-emitted cell
  /// still produces a displayable value.
  final S Function(V? value) select;

  /// Renders the selected slice.
  ///
  /// Called on initial build and whenever [equals] reports that the slice
  /// changed. Not called when a pulse arrives whose projected slice is
  /// equal to the previous one — that is the entire point of the widget.
  final Widget Function(BuildContext context, S selected) builder;

  /// Equality predicate for the selected slice. Defaults to `==`.
  ///
  /// Collections (`List`, `Set`, `Map`) need an explicit
  /// `listEquals` / `setEquals` / `mapEquals`. In debug builds, `initState`
  /// asserts if [select] returns a collection and this is `null`.
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
      widget.equals != null || !isCollectionLike(_selected),
      'CellSelector: select returned a collection '
      '(${_selected.runtimeType}) but equals is null. Collections use '
      'identity equality by default, so the widget will rebuild on every '
      'emission even when the content is equal. Provide equals: '
      'listEquals, setEquals, or mapEquals from package:flutter/foundation.dart.',
    );
    _notifier.addListener(_onChange);
  }

  static bool _defaultEquals<S>(S a, S b) => a == b;

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
