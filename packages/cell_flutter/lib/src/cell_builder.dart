// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cell_notifier.dart';

/// A widget that rebuilds its [builder] whenever [cell]'s value changes.
///
/// [CellBuilder] is the binding's **Primary State Renderer** — the default
/// way to put a [ValueCell] on screen. It binds a `ValueListenableBuilder`
/// to a [CellNotifier] over [cell], so only the subtree under [builder]
/// rebuilds when the cell emits a new value. Granularity is one widget per
/// [CellBuilder]; use multiple builders to isolate independent subtrees.
///
/// ### Why it is used
/// - **State display**: render the current value of a `Cell.state` result,
///   a projected `CellNotifier`, or any other [ValueCell].
/// - **Rebuild isolation**: because each [CellBuilder] owns its own notifier
///   and its own `ValueListenableBuilder`, a change in one cell rebuilds
///   only the widgets bound to that cell — other subtrees are untouched.
/// - **Least-privilege views**: hand a `cell.unmodifiable` proxy to a child
///   [CellBuilder] and the child can *read* the value but cannot mutate the
///   cell. This is the binding-layer embodiment of Mitosis's
///   least-privilege story.
///
/// ### How it works
/// 1. **Bind**: on `initState`, the widget constructs a [CellNotifier] over
///    [cell]. The notifier subscribes to the cell and exposes its value as a
///    [ValueListenable]`<V?>`.
/// 2. **Render**: `build` delegates to `ValueListenableBuilder<V?>`, which
///    calls [builder] with the notifier's current value on every change.
/// 3. **Rebind**: if [cell] identity changes in `didUpdateWidget`, the old
///    notifier is disposed and a new one is constructed. Identity is
///    compared with `identical` — swapping a cell requires rebinding; the
///    same cell (or an equal handle) does not.
/// 4. **Dispose**: the notifier is disposed, which stops the egress.
///
/// ### Design Note: `CellBuilder` vs. `CellValueBuilder` vs. `CellSelector`
/// | | `CellBuilder<V>` | `CellValueBuilder<V>` | `CellSelector<V, S>` |
/// |---|---|---|---|
/// | Source type | `ValueCell<V>` | Any `Cell` | `ValueCell<V>` |
/// | Underlying | [CellNotifier] → `ValueListenableBuilder` | One `EgressHandle`, value on `State` | [CellNotifier] + `addListener` |
/// | Rebuild trigger | Value `V` changes | Value `V` changes | Selected `S` changes |
/// | Cost | Cheapest binding for `ValueCell` | Slightly heavier (manual queue) | Runs `selector` per pulse; `setState` only on slice change |
///
/// Use [CellBuilder] **first** when the source is a [ValueCell] — it is the
/// cheapest binding and gets `ValueListenableBuilder`'s subtree isolation
/// for free. Reach for `CellValueBuilder` when the source is not a
/// [ValueCell] (`Cell.derive`, `Cell.synthesis`, `Cell.switchMap`, async
/// operators, `cell_tissue` collections). Reach for `CellSelector` when the
/// widget only reads one field of a larger object and should not rebuild on
/// every field change.
///
/// ### Rebuild anti-pattern (read this)
/// The widget tracks consecutive cell-identity swaps and, in debug builds,
/// prints a diagnostic after **3 in a row**. That pattern almost always
/// means the cell is created inside `build()` — an anti-pattern that breaks
/// hot reload, resets state on every rebuild, and causes the notifier to be
/// rebuilt on every frame. Move the `Cell.state` / `Cell.ingress` call to
/// `initState`, a `State` field, or a top-level `final`.
///
/// ### Build-phase pulses (read this)
/// [CellBuilder] is driven by a [CellNotifier], which notifies its
/// listeners **synchronously**. If a pulse arrives while this widget (or a
/// sibling `CellBuilder` on the same cell) is mid-build, Flutter raises
/// its *"setState() or markNeedsBuild() called during build"* framework
/// error **at this widget** — even though the bug is in whatever emitted
/// the pulse from inside `build`. That attribution is deliberate: the
/// error is surfaced, not swallowed. Ensure no widget mutates a cell from
/// inside `build`; widgets that prefer deferral to the end of the frame
/// instead of surfacing the bug are `CellValueBuilder`,
/// `CellAsyncBuilder`, and `CellListener`.
///
/// ### Pulse semantics
/// - **Data pulses** update the notifier's value and trigger a rebuild of
///   [builder]'s subtree.
/// - **Error pulses** (`pulse.type == 'error'`) are dropped by the notifier.
///   Use `CellAsyncBuilder` or `CellListener` if the widget needs to react
///   to errors.
/// - **Null values**: [builder] receives `V?` — a not-yet-emitted cell
///   renders as `null`; callers that need a default should handle it in
///   [builder] (`value ?? defaultValue`).
///
/// ### Technical Details
/// - **One notifier per element**: the widget owns exactly one
///   [CellNotifier]; multiple builds reuse it. The notifier owns the cell
///   observation.
/// - **No `setState`**: rebuilds flow through `ValueListenableBuilder`'s
///   own `Listenable` notification, not `setState` on `_CellBuilderState`.
///   The state class is intentionally minimal.
/// - **Identity-based rebind**: `didUpdateWidget` compares cells with
///   `identical`, not `==`. Two equal-but-distinct cell handles are still a
///   swap.
///
/// ### Concurrent `asyncMap` caveat
/// A [CellBuilder] can only be constructed over a [ValueCell]. `Cell.asyncMap`
/// returns a plain `Cell`, so the async-map caveat from
/// `Cell.asyncMap`'s own docs does not apply here — a `CellValueBuilder`
/// or `CellAsyncBuilder` should be used for that source instead.
///
/// ### Example
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
///
/// CellBuilder<int>(
///   cell: counter.cell.unmodifiable,   // read-only view
///   builder: (context, value) => Text('${value ?? 0}'),
/// );
/// ```
///
/// ### See Also:
/// - [CellNotifier] — the `ValueNotifier` adapter this widget wraps.
/// - `CellValueBuilder` — the equivalent for non-`ValueCell` sources.
/// - `CellSelector` — the slice-granular variant for `ValueCell` sources.
/// - `CellListener` — for side effects, not display.
/// - `ValueListenableBuilder` — the Flutter primitive used for the actual
///   rebuild.
/// - [ValueCellBuilder] — the fluent `.builder()` extension on [ValueCell].
class CellBuilder<V> extends StatefulWidget {
  /// Creates a builder bound to [cell].
  ///
  /// ### Parameters:
  /// * [cell]: **The State Source.** Must be a [ValueCell] — state display
  ///   needs a synchronous current value. For derived cells
  ///   (`Cell.derive`, `Cell.synthesis`), use `asValueCell()` to bridge, or
  ///   switch to `CellValueBuilder`.
  /// * [builder]: **The Render Callback.** Called on initial build and
  ///   whenever [cell] emits a new value.
  ///
  /// ### See Also:
  /// - [CellBuilder] class docs for the binding contract and anti-pattern
  ///   warnings.
  const CellBuilder({
    required this.cell,
    required this.builder,
    super.key,
  });

  /// The state source.
  ///
  /// Must be a [ValueCell]. Pass a `cell.unmodifiable` proxy to hand a
  /// read-only view to a child — the widget can *read* the value but cannot
  /// mutate the cell through this builder.
  final ValueCell<V> cell;

  /// Rebuilds when [cell]'s value changes.
  ///
  /// Called at least once (initial build) with `cell.value`. Called again
  /// every time the cell emits a value different from the previous one.
  /// The value is `V?` — nullable, so a not-yet-emitted cell renders as
  /// `null`. Provide a default in [builder] if the view needs one.
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

/// Fluent constructor for a [CellBuilder] over a [ValueCell].
///
/// [ValueCellBuilder] is the binding's **Widget-Layer Sugar**: a one-line
/// shortcut that turns any [ValueCell] into a self-rebuilding widget without
/// importing `CellBuilder` at the call site. It produces a standard
/// [CellBuilder] — same semantics, same rebuild granularity, same
/// debug-mode anti-pattern warning — with [key] forwarded.
///
/// ### Why it is used
/// - **Readability**: `counter.cell.builder((ctx, v) => Text('$v'))` reads
///   as a fluent sentence in composition-heavy trees, and avoids a
///   fully-qualified `CellBuilder<int>(...)` in every leaf.
/// - **Zero cost**: this is an extension; it adds no memory to [ValueCell]
///   instances and produces a normal [CellBuilder] at runtime.
///
/// ### Technical Details
/// - **Extension, not a wrapper**: the returned widget is a plain
///   [CellBuilder]; there is no subclass and no indirection.
/// - **Key forwarding**: [key] is passed through to the [CellBuilder]
///   constructor, so the usual Flutter key semantics apply.
///
/// ### See Also:
/// - [CellBuilder] — the widget this extension constructs.
/// - `CellValueBuilder` — the equivalent for non-`ValueCell` sources (which
///   does not have a `.builder()` extension).
extension ValueCellBuilder<V> on ValueCell<V> {
  /// Shorthand for `CellBuilder(cell: this, builder: builder)`.
  ///
  /// Returns a [CellBuilder] over this cell. The [builder] callback is
  /// invoked on initial build and whenever this cell emits a new value.
  ///
  /// ```dart
  /// counter.cell.builder((ctx, v) => Text('${v ?? 0}'));
  /// ```
  ///
  /// ### Parameters:
  /// * [builder]: **The Render Callback.** Same contract as
  ///   [CellBuilder.builder] — receives `V?`, called per emission.
  /// * [key]: **Flutter Key.** Forwarded to the constructed [CellBuilder].
  ///
  /// ### Returns:
  /// A [CellBuilder] bound to this cell.
  ///
  /// ### See Also:
  /// - [CellBuilder] — the underlying widget.
  Widget builder(
    Widget Function(BuildContext context, V? value) builder, {
    Key? key,
  }) =>
      CellBuilder<V>(cell: this, builder: builder, key: key);
}
