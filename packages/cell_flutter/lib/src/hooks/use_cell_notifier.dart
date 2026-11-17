// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns a [CellNotifier] bound to [cell], disposed on unmount.
///
/// [useCellNotifier] is the hooks layer's **Listenable Bridge**. It is the
/// `flutter_hooks` counterpart of `CellNotifier` itself — the value-notifier
/// adapter, not the widgets built on top of it. Use it when you want the
/// cell's value as a [ValueListenable] you can hand to another
/// `flutter_hooks` primitive or a Flutter widget, rather than as a rendered
/// subtree.
///
/// ### Why it is used
/// - **Compose with `flutter_hooks` primitives**: `useValueListenable`,
///   `useListenable`, `useValueChanged` all take a [Listenable] or
///   [ValueListenable]. Wrapping a cell in `useCellNotifier` lets you feed
///   the cell's value into them directly.
/// - **Hand the notifier to Flutter widgets**: `ValueListenableBuilder`,
///   `AnimatedBuilder`, `ListenableBuilder` take a `Listenable`. This hook
///   is the correct way to obtain one from a cell inside a `HookWidget`.
/// - **Explicit lifecycle**: the notifier is created once per cell (via
///   `useMemoized`) and disposed on unmount (via `useEffect`), so its
///   egress is released with the widget, not leaked.
///
/// ### When **not** to use it
/// - For **rebuild-on-value-change**, use [useCellValue] — it does the same
///   work with less ceremony and no notifier to carry around.
/// - For **rebuild-on-slice-change**, use [useCell] — it adds
///   [CellSelector]-style granularity.
/// - For **async snapshots**, use `useCellAsync`.
///
/// ### How it works
/// 1. `useMemoized` constructs one [CellNotifier] for the given [cell] and
///    keeps it stable across builds. A change of [cell] identity produces a
///    new notifier on the next build.
/// 2. `useEffect` registers `notifier.dispose` as the cleanup callback,
///    which runs when the hook unmounts or when the notifier is replaced by
///    a `useMemoized` identity change.
///
/// ### Technical Details
/// - **Memoization key is `[cell]`**: the notifier is re-created only when
///   the cell *identity* changes. Passing a freshly created cell on every
///   build would defeat the memoization and rebuild the notifier each
///   frame; the same caution applies here as to `CellBuilder`'s
///   cell-in-build anti-pattern.
/// - **The notifier is read-only**: `CellNotifier` overrides `value`'s
///   setter to throw [UnsupportedError]. Mutate the cell directly
///   (`cell.value = ...`) when a write is needed.
/// - **Error pulses are not surfaced**: the notifier drops
///   `pulse.type == 'error'` on the floor. Use `useCellAsync` if the
///   widget needs to render errors.
///
/// ### Example
/// ```dart
/// class FancyView extends HookWidget {
///   final ValueCell<int> counter;
///   const FancyView({required this.counter, super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final notifier = useCellNotifier(counter);
///     useValueListenable(notifier);
///     return ValueListenableBuilder<int?>(
///       valueListenable: notifier,
///       builder: (_, v, __) => Text('$v'),
///     );
///   }
/// }
/// ```
///
/// ### Parameters:
/// * [cell]: **The Source Cell.** A [ValueCell] whose value the notifier
///   mirrors. Held by reference for the notifier's lifetime; the notifier
///   does not invalidate it on dispose.
///
/// ### Returns:
/// A [CellNotifier] that is stable across builds of the enclosing
/// `HookWidget` and disposed automatically on unmount.
///
/// ### See Also:
/// - [useCell] — the selector hook.
/// - [useCellValue] — the full-value shortcut.
/// - `CellNotifier` — the underlying adapter; its docs cover the read-only
///   contract in detail.
/// - [useValueListenable] / [useListenable] — the `flutter_hooks`
///   primitives this hook is typically composed with.
CellNotifier<V> useCellNotifier<V>(ValueCell<V> cell) {
  final notifier = useMemoized(() => CellNotifier<V>(cell), [cell]);
  useEffect(() => notifier.dispose, [notifier]);
  return notifier;
}
