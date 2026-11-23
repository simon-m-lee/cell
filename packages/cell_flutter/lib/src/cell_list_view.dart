// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import 'cell_value_builder.dart';

/// A virtualized list whose item collection is bound to a [Cell].
///
/// [CellListView] is the binding's **Cell-Bound List** — the `ListView`
/// equivalent of `CellBuilder` for collections. It observes a cell that
/// produces `List<T>` (a `Cell.state<List<T>>` result, a `TissueList`, a
/// derived projection, an `asyncMap` result) and renders it as a lazy
/// `ListView.builder`, so only visible items are laid out regardless of
/// the list length.
///
/// Two constructors cover the two production patterns:
///
/// - **[CellListView.builder]** — the naive variant. Every list change
///   rebuilds the visible items through the normal `ListView.builder`
///   reconciliation. Compose a per-item `CellBuilder` inside [itemBuilder]
///   when each item has its own cell:
///
///   ```dart
///   CellListView<User>.builder(
///     cell: users.cell,
///     itemBuilder: (ctx, user, i) => CellBuilder<User>(
///       cell: getUserCell(user.id),
///       builder: (_, u) => ListTile(title: Text(u?.name ?? '')),
///     ),
///   );
///   ```
///
/// - **[CellListView.keyed]** — the diffed variant. [itemKey] extracts a
///   stable key per item; the list keeps a widget cache and only calls
///   [itemBuilder] for items whose key is new **or whose value changed**
///   (the item is compared with `==` against the value the row was last
///   built with). Items are wrapped in `KeyedSubtree(ValueKey(itemKey))`
///   and the list supplies `findChildIndexCallback`, so unchanged items
///   preserve their element state (focus, scroll offsets, animations)
///   across mutations and reorders. Duplicate keys throw [StateError] —
///   keys must be unique within the list.
///
///   **Index freshness note:** a cached item widget keeps the index it was
///   built with. A reorder does not re-run [itemBuilder], so widgets that
///   render their own index show the index from their first build. Use
///   [CellListView.builder] when index-fresh rendering matters more than
///   rebuild avoidance.
///
/// ### Scroll position
/// The `ListView` element is preserved across list changes, so the scroll
/// position survives mutations in both variants (subject to Flutter's
/// usual `ScrollController` rules).
///
/// ### Reverse lists (live feeds)
/// [reverse] mirrors `ListView.builder`'s flag: with `true`, the list is
/// pinned to the bottom and index 0 renders at the visual bottom. This is
/// the live-feed orientation — a chat transcript, an audit log, or a
/// telemetry stream where the newest item should always be visible.
/// Callers typically keep their list ordered newest-first and let the
/// reversed view surface the head of the list at the bottom edge.
///
/// ### Known limitation (keyed variant)
/// The keyed variant builds a widget configuration per item up front
/// (O(n) memory) and diffs in O(n) time per list change. This is the
/// documented trade-off for not rebuilding unchanged items; for lists in
/// the tens of thousands with per-item cells, prefer
/// [CellListView.builder] with per-item `CellBuilder` composition.
///
/// ### Example
/// ```dart
/// final todos = Cell.state<List<String>>(initial: ['a', 'b']);
/// CellListView<String>.builder(
///   cell: todos.cell,
///   itemBuilder: (ctx, todo, i) => ListTile(title: Text(todo)),
/// );
/// ```
///
/// ### See Also:
/// - [CellValueBuilder] — the observation primitive this builds on.
/// - `ListView.builder` — the Flutter primitive used for layout.
class CellListView<T> extends StatelessWidget {
  /// Creates the naive builder variant (see class docs).
  const CellListView.builder({
    required this.cell,
    required this.itemBuilder,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.controller,
    this.reverse = false,
    this.itemCount,
    super.key,
  }) : _itemKey = null;

  /// Creates the keyed diff variant (see class docs).
  const CellListView.keyed({
    required this.cell,
    required this.itemBuilder,
    required Object Function(T item) itemKey,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.controller,
    this.reverse = false,
    super.key,
  }) : _itemKey = itemKey,
       itemCount = null;

  /// The cell producing `List<T>`.
  final Cell cell;

  /// Builds one item; called with the item and its index.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// The key extractor for the keyed variant; null for the builder
  /// variant.
  final Object Function(T item)? _itemKey;

  /// Forwarded to the underlying [ListView.builder].
  final Axis scrollDirection;

  /// Forwarded to the underlying [ListView.builder].
  final EdgeInsets? padding;

  /// Forwarded to the underlying [ListView.builder].
  final ScrollController? controller;

  /// Forwarded to the underlying [ListView.builder]. With `true`, the
  /// list pins to the bottom — index 0 renders at the visual bottom.
  /// Use for live feeds (chat transcripts, audit logs) whose newest
  /// item should stay visible.
  final bool reverse;

  /// Overrides the item count; defaults to the list length. A caller
  /// count larger than the current list is clamped to the list length —
  /// the builder never indexes past the list.
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    final itemKey = _itemKey;
    return CellValueBuilder<List<T>>(
      cell: cell,
      builder: (ctx, items) {
        final list = items ?? <T>[];
        if (itemKey != null) {
          return _KeyedItemsView<T>(
            items: list,
            itemKey: itemKey,
            itemBuilder: itemBuilder,
            scrollDirection: scrollDirection,
            padding: padding,
            controller: controller,
            reverse: reverse,
          );
        }
        return ListView.builder(
          scrollDirection: scrollDirection,
          padding: padding,
          controller: controller,
          reverse: reverse,
          // Clamp: a caller-supplied itemCount larger than the current
          // list must not index off the end inside build.
          itemCount: itemCount == null
              ? list.length
              : itemCount! > list.length
              ? list.length
              : itemCount!,
          itemBuilder: (ctx, i) => itemBuilder(ctx, list[i], i),
        );
      },
    );
  }
}

/// The keyed-diff half of [CellListView]: keeps a widget cache and only
/// re-invokes the item builder for new keys or changed indexes.
class _KeyedItemsView<T> extends StatefulWidget {
  const _KeyedItemsView({
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    required this.scrollDirection,
    required this.padding,
    required this.controller,
    required this.reverse,
  });

  final List<T> items;
  final Object Function(T item) itemKey;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Axis scrollDirection;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool reverse;

  @override
  State<_KeyedItemsView<T>> createState() => _KeyedItemsViewState<T>();
}

class _KeyedItemsViewState<T> extends State<_KeyedItemsView<T>> {
  // Widget cache plus the item value each widget was built with: a stable
  // key whose data changed must rebuild the row (same KeyedSubtree key, so
  // element state is preserved) instead of freezing the first value.
  final Map<Object, ({T item, Widget widget})> _cache = {};

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    final seen = <Object>{};
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final key = widget.itemKey(item);
      if (!seen.add(key)) {
        throw StateError(
          'CellListView.keyed: duplicate itemKey "$key" at index $i. '
          'Item keys must be unique within the list.',
        );
      }
      final cached = _cache[key];
      if (cached != null && cached.item == item) {
        widgets.add(cached.widget);
        continue;
      }
      final built = widget.itemBuilder(context, item, i);
      // The automatic key is what preserves element state across reorders
      // and mutations — the widget cache only avoids the rebuild.
      final keyed = KeyedSubtree(key: ValueKey<Object>(key), child: built);
      _cache[key] = (item: item, widget: keyed);
      widgets.add(keyed);
    }
    // Prune removed keys (internal cache maintenance; no rebuild needed).
    _cache.removeWhere((key, _) => !seen.contains(key));
    return ListView.builder(
      scrollDirection: widget.scrollDirection,
      padding: widget.padding,
      controller: widget.controller,
      reverse: widget.reverse,
      itemCount: widgets.length,
      // Keyed reorders must move elements (and their state) instead of
      // replacing them; the O(n) scan is the documented diff cost.
      findChildIndexCallback: (key) {
        for (var i = 0; i < widgets.length; i++) {
          if (widgets[i].key == key) return i;
        }
        return null;
      },
      itemBuilder: (ctx, i) => widgets[i],
    );
  }
}
