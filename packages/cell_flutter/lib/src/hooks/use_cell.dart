// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../pulse_delivery.dart';

/// Reads the slice of [cell] produced by [select], rebuilding only when
/// that slice changes.
///
/// [useCell] is the hooks layer's **Selector Hook** — the `HookWidget`
/// equivalent of `CellSelector`. Its rebuild granularity is the selected
/// slice, not the full value, so a widget that only reads one field of a
/// large state object does not rebuild on unrelated field changes.
///
/// ### Why it is used
/// - **Granular rebuilds in a `HookWidget`**: `useCellValue` rebuilds on
///   every value change; [useCell] rebuilds only when `select(value)`
///   differs under [equals]. That is `CellSelector`'s whole purpose,
///   expressed in the hook layer.
/// - **Composition with `flutter_hooks`**: unlike `CellSelector`, [useCell]
///   lives inside the `HookWidget` body, so it can be combined with
///   `useMemoized`, `useAnimation`, `useTextEditingController`, and other
///   hook primitives without wrapping the widget in an additional
///   `StatefulWidget`.
///
/// ### How it works
/// 1. `useMemoized` constructs one [CellNotifier] per [cell] identity and
///    keeps it stable across builds.
/// 2. `useState` seeds the selected slice from `select(notifier.value)`
///    (the notifier's current value at first build).
/// 3. A first `useEffect` registers a `refresh` listener on the notifier.
///    `refresh` recomputes `select(notifier.value)` and updates the
///    selection only when [equals] reports a difference. The listener reads
///    `select` and `equals` through refs, so a new closure per build does
///    not re-subscribe.
/// 4. A second `useEffect` recomputes the selection when [select], [equals],
///    or the notifier identity changes — mirroring `CellSelector`'s
///    `didUpdateWidget` behavior. Without it, a changed selector with no
///    new pulse would render a stale slice. Because `flutter_hooks` runs a
///    keyed effect's body synchronously during the build that first
///    registers the new keys, the recompute happens **before [useCell]
///    returns** — the very first build with a new [cell] already returns
///    the new cell's slice (see *Design Note: no flash on cell swap*).
/// 5. A third `useEffect` returns `notifier.dispose` as its cleanup, so
///    the notifier is released on unmount or cell-identity change.
/// 6. The current selection is returned.
///
/// ### Rules
/// Called unconditionally at the top of a `HookWidget.build`, with the
/// same argument identity across builds (or `flutter_hooks` will warn
/// about out-of-order hooks). Same rules as every hook in this library.
///
/// ### `ValueCell` requirement (read this)
/// [cell] must be a [ValueCell] — the hook needs a synchronous current
/// value for [select] to run against. For derived cells (`Cell.derive`,
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
/// ### Design Note: why not `useValueListenable`
/// `useValueListenable(notifier)` rebuilds the entire widget on every value
/// change — which defeats the selector's purpose. This hook uses
/// `useState` + `useEffect` to rebuild only when `select(value)` changes,
/// matching `CellSelector`'s behavior. A `CellNotifier` is still used
/// internally (to bridge `ValueCell` to a `Listenable`), but its
/// notification is filtered through the selector and the equality check
/// before reaching `setState`.
///
/// ### Equality (read this)
/// [equals] defaults to `==`. For `List`, `Set`, and `Map` selections,
/// pass `listEquals` / `setEquals` / `mapEquals` from
/// `package:flutter/foundation.dart`. Without a custom predicate, a fresh
/// collection with identical content produces `[1, 2] != [1, 2]`
/// (different instances), and the widget rebuilds on every emission. This
/// is the same contract `CellSelector` enforces, and like `CellSelector`
/// the hook **asserts in debug builds** when the initial (or recomputed)
/// selection is a collection and [equals] is `null`.
///
/// ### Design Note: no flash on cell swap
/// `useState` seeds the selection once per element; its initializer does
/// **not** re-run when [cell] identity changes. The recompute effect is
/// keyed on `[select, eq, notifier]`, and `flutter_hooks` re-runs a keyed
/// effect's body synchronously **during the build** that first registers
/// the changed keys — so on a cell swap the selection is corrected before
/// [useCell] returns. The first build with the new cell already returns
/// the new cell's slice; no stale frame is produced, unlike the historical
/// "one-frame flash" the hook docs once warned about. (Verified by
/// `use_cell_test.dart`, "returns the new cell's slice on the first build
/// after a swap".)
///
/// `CellSelector` (the widget equivalent) achieves the same in
/// `didUpdateWidget`. Keying the enclosing `HookWidget` on the cell
/// (`key: ValueKey(cell)`) remains the `flutter_hooks` idiom when the
/// **entire** hook state — not just this selection — must reset on a swap.
///
/// ### Technical Details
/// - **Three `useEffect`s, keyed as follows**:
///   - `[notifier]` — subscribe once per notifier.
///   - `[select, eq, notifier]` — recompute on selector identity change.
///   - `[notifier]` — dispose the notifier on replacement or unmount.
/// - **`select`/`eq` via refs**: read through `useRef`, so a new closure
///   per build does not force a re-subscribe. This is the hook equivalent
///   of `CellListener`'s "don't rebind on `onPulse` identity change"
///   behavior.
/// - **Recompute on `select` identity change**: the middle effect runs on
///   every build where `select` or `eq` identity differs from the
///   previous build, which is what a caller expects when they swap the
///   selector without swapping the cell.
/// - **Selection seeding is one-shot**: `useState`'s initializer runs
///   once per `HookWidget` element. After that, the recompute effect is
///   the only writer — and because it re-runs synchronously during the
///   build that registers changed keys, a cell swap still returns the new
///   cell's slice on that very build (see *Design Note: no flash on cell
///   swap*).
///
/// ### Example
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
/// ### Parameters:
/// * [cell]: **The Source Cell.** A [ValueCell] whose value is projected
///   by [select]. Changing its identity rebinds the notifier and the
///   effects.
/// * [select]: **The Slice Projection.** A pure function `V? → S`. Runs on
///   first build and on every notifier tick. Keep it cheap — it runs on
///   every pulse even when the slice does not change.
/// * [equals]: **Slice Equality.** Defaults to `==`. Collections need an
///   explicit `listEquals` / `setEquals` / `mapEquals`.
///
/// ### Returns:
/// The current selected slice `S`, re-rendered only when it changes under
/// [equals].
///
/// ### See Also:
/// - [useCellValue] — the full-value shortcut (`select: (v) => v`).
/// - `CellSelector` — the widget equivalent, with the debug-mode
///   collection-equality assertion.
/// - [useCellNotifier] — the raw notifier hook, for composing with
///   `flutter_hooks` primitives directly.
S useCell<V, S>({
  required ValueCell<V> cell,
  required S Function(V? value) select,
  bool Function(S previous, S next)? equals,
}) {
  final notifier = useMemoized(() => CellNotifier<V>(cell), [cell]);
  final eq = equals ?? _defaultEquals;

  // Latest select/eq, so the subscription closure sees current values
  // without re-subscribing on every build. `customEqualsRef` tracks the
  // caller's raw `equals` (nullable) for the debug collection assertion;
  // the resolved `eq` is always non-null.
  final selectRef = useRef(select);
  final eqRef = useRef(eq);
  final customEqualsRef = useRef(equals);
  selectRef.value = select;
  eqRef.value = eq;
  customEqualsRef.value = equals;

  // Selected value; initial state from the notifier's current value.
  final selected = useState<S>(select(notifier.value));
  assert(
    equals != null || !isCollectionLike(selected.value),
    'useCell: select returned a collection '
    '(${selected.value.runtimeType}) but equals is null. Collections use '
    'identity equality by default, so the hook will rebuild on every '
    'emission even when the content is equal. Provide equals: '
    'listEquals, setEquals, or mapEquals from package:flutter/foundation.dart.',
  );

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
  // new pulse would render a stale slice. On a cell swap this also
  // corrects the one-frame stale selection described in the class-level
  // docs.
  useEffect(() {
    final next = select(notifier.value);
    assert(
      customEqualsRef.value != null || !isCollectionLike(next),
      'useCell: select returned a collection '
      '(${next.runtimeType}) but equals is null. Collections use '
      'identity equality by default, so the hook will rebuild on every '
      'emission even when the content is equal. Provide equals: '
      'listEquals, setEquals, or mapEquals from package:flutter/foundation.dart.',
    );
    if (!eq(selected.value, next)) {
      selected.value = next;
    }
    return null;
  }, [select, eq, notifier]);

  // Dispose the notifier when the cell changes or widget unmounts.
  useEffect(() => notifier.dispose, [notifier]);

  return selected.value;
}

/// A convenience wrapper for "rebuild on every value change".
///
/// [useCellValue] is [useCell] with `select: (v) => v` — the full-value
/// shortcut. It is the hooks layer's **Plain Value Reader**, the
/// `HookWidget` equivalent of `CellBuilder`.
///
/// ### Why it is used
/// Most `HookWidget`s that read a cell want the whole value, not a
/// projected slice. Rather than forcing the caller to pass
/// `select: (v) => v` and infer `S` from the cell's `V`, this helper
/// **shortens the call site** and infers the type directly.
///
/// ### When **not** to use it
/// Use only when every change matters. If the widget only reads one field
/// of a larger object — the common case once a `Cell<User>` grows beyond
/// `name` — reach for [useCell] with an explicit selector. Rebuilding the
/// widget on every unrelated field change is the exact cost
/// `CellSelector`'s slice reduction exists to avoid.
///
/// ### How it works
/// It delegates to `useCell<V, V?>` with `select: (v) => v`. The
/// selection is typed `V?` (matching `CellNotifier`'s value type) and
/// rebuilds on every distinct value.
///
/// ### Technical Details
/// - **Return type is `V?`**: the same nullable-value contract as
///   `CellBuilder.builder` — a not-yet-emitted cell returns `null`.
/// - **Delegates to [useCell]**: no separate implementation; the equality
///   and recompute semantics of [useCell] apply unchanged. Default
///   `equals` is `==`.
///
/// ### Example
/// ```dart
/// class CounterView extends HookWidget {
///   final ValueCell<int> counter;
///   const CounterView({required this.counter, super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final value = useCellValue(counter);
///     return Text('${value ?? 0}');
///   }
/// }
/// ```
///
/// ### Parameters:
/// * [cell]: **The Source Cell.** A [ValueCell] whose full value is read.
///
/// ### Returns:
/// The current value `V?`, re-rendered on every change.
///
/// ### See Also:
/// - [useCell] — the selector hook this delegates to.
/// - `CellBuilder` — the widget equivalent.
/// - [useCellNotifier] — for a [Listenable] rather than a value.
V? useCellValue<V>(ValueCell<V> cell) =>
    useCell<V, V?>(cell: cell, select: (v) => v);

/// The default slice-equality predicate: Dart's `==`.
///
/// Used by [useCell] when no [useCell.equals] is supplied. For collections,
/// callers must pass `listEquals` / `setEquals` / `mapEquals` from
/// `package:flutter/foundation.dart` — the default `==` on two distinct
/// collection instances returns `false` regardless of content.
///
/// ### See Also:
/// - [useCell] — where this default is applied.
bool _defaultEquals<S>(S a, S b) => a == b;
