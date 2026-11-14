// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns a [CellNotifier<V>] bound to [cell], disposing it on unmount.
///
/// Use when you want to compose with other `flutter_hooks` primitives
/// (`useValueListenable`, `useListenable`, `useValueChanged`) or pass the
/// notifier to a `ValueListenableBuilder`.
///
/// For a rebuild-on-value-change hook, use [useCellValue]. For a
/// rebuild-on-slice-change hook, use [useCell].
///
/// ```dart
/// class FancyView extends HookWidget {
///   final ValueCell<int> counter;
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
CellNotifier<V> useCellNotifier<V>(ValueCell<V> cell) {
  final notifier = useMemoized(() => CellNotifier<V>(cell), [cell]);
  useEffect(() => notifier.dispose, [notifier]);
  return notifier;
}
