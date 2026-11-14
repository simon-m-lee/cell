// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Reads the slice of [cell] returned by [select], rebuilding only when
/// that slice changes.
///
/// The hook equivalent of `CellSelector`. Rebuild granularity is the
/// selected slice, not the full value.
///
/// ## Rules
///
/// Called unconditionally at the top of a `HookWidget.build`. Same arguments
/// every build (or `flutter_hooks` will warn about out-of-order hooks).
///
/// ## `ValueCell` requirement
///
/// `cell` must be a `ValueCell<V>` — the hook needs a synchronous current
/// value for `select` to run against. For derived cells (`Cell.derive`,
/// `Cell.synthesis`, `Cell.switchMap`, tissue collections), bridge first:
///
/// ```dart
/// // Wrong: derived Cell is not a ValueCell
/// useCell<int, int>(cell: derived, select: (v) => v ?? 0);
///
/// // Right: wrap in CellValueBuilder, or mirror via asValueCell
/// CellValueBuilder<int>(cell: derived, builder: ...);
/// ```
///
/// ## Usage
///
/// ```dart
/// class UserNameView extends HookWidget {
///   final ValueCell<User> user;
///   const UserNameView({required this.user, super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final name = useCell<User, String>(
///       cell: user,
///       select: (u) => u?.name ?? '',
///     );
///     return Text(name);
///   }
/// }
/// ```
///
/// ## Why not useValueListenable?
///
/// `useValueListenable(notifier)` rebuilds the entire widget on every value
/// change. That defeats the selector's purpose. This hook uses
/// `useState` + `useEffect` to rebuild only when `select(value)` changes,
/// matching `CellSelector`'s behavior.
///
/// ## Equality
///
/// `equals` defaults to `==`. For collections, provide `listEquals` /
/// `setEquals` / `mapEquals` from `flutter/foundation`.
S useCell<V, S>({
  required ValueCell<V> cell,
  required S Function(V? value) select,
  bool Function(S previous, S next)? equals,
}) {
  final notifier = useMemoized(() => CellNotifier<V>(cell), [cell]);
  final eq = equals ?? _defaultEquals;

  // Latest select/eq, so the subscription closure sees current values
  // without re-subscribing on every build.
  final selectRef = useRef(select);
  final eqRef = useRef(eq);
  selectRef.value = select;
  eqRef.value = eq;

  // Selected value; initial state from the notifier's current value.
  final selected = useState<S>(select(notifier.value));

  // Subscribe once per notifier. Refresh reads current select/eq from refs.
  useEffect(() {
    void refresh() {
      final next = selectRef.value(notifier.value);
      if (!eqRef.value(selected.value, next)) {
        selected.value = next;
      }
    }

    notifier.addListener(refresh);
    return () => notifier.removeListener(refresh);
  }, [notifier]);

  // Recompute when select or equals changes (mirrors CellSelector's
  // didUpdateWidget behavior). Without this, a changed selector with no
  // new pulse would render a stale slice.
  useEffect(() {
    final next = select(notifier.value);
    if (!eq(selected.value, next)) {
      selected.value = next;
    }
    return null;
  }, [select, eq, notifier]);

  // Dispose the notifier when the cell changes or widget unmounts.
  useEffect(() => notifier.dispose, [notifier]);

  return selected.value;
}

/// Convenience for "rebuild on every value change": `useCell` with
/// `select: (v) => v`.
///
/// Use only when every change matters. For finer granularity, use
/// `useCell` with an explicit selector.
V? useCellValue<V>(ValueCell<V> cell) =>
    useCell<V, V?>(cell: cell, select: (v) => v);

bool _defaultEquals<S>(S a, S b) => a == b;
