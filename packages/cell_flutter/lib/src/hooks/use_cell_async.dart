// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Renders the async state of [cell] as an `AsyncSnapshot<V>`.
///
/// The hook equivalent of `CellAsyncBuilder`. Rebinds the snapshot on every
/// pulse.
///
/// ## Snapshot transitions
///
/// - Before first pulse: `ConnectionState.none`, `hasData == false`.
/// - After data pulse: `ConnectionState.active`, `hasData == true`.
/// - After error pulse: `ConnectionState.active`, `hasError == true`.
/// - **`ConnectionState.done` is never reached.** No core operator emits a
///   completion pulse. See `CellAsyncBuilder`'s dartdoc.
///
/// ## Error-pulse sources (inherited from `CellAsyncBuilder`)
///
/// Only `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on the
/// failure path. `Cell.fromStream` and `Cell.asyncMap` do **not**. A
/// `useCellAsync` over an `asyncMap` source will keep the last successful
/// snapshot when the mapper throws. Users who need error visibility from
/// those sources must bridge them through a custom cell that re-emits the
/// failure.
///
/// ## Concurrent `asyncMap` caveat
///
/// Over `Cell.asyncMap` with `concurrency > 0`, this hook inherits the
/// framework's Gate G1.5 caveat: concurrent effect attribution is tracked
/// separately. The hook's observation is correct; the caveat is about the
/// source's replay fidelity.
///
/// ## Cell-swap behavior
///
/// The snapshot persists across cell swaps until the new cell emits. This
/// differs from `CellAsyncBuilder`, which resets the snapshot to
/// `initialSnapshot ?? nothing()` in `didUpdateWidget`. To reset the hook's
/// state on cell swap, key the `HookWidget` on the cell:
///
/// ```dart
/// HookBuilder(
///   key: ValueKey(cell),
///   builder: (ctx) => ResultsView(cell: cell),
/// );
/// ```
///
/// The alternative — resetting inside the hook — would require a
/// `setState` during build, which triggers a one-frame flash. Keying is the
/// `flutter_hooks` idiom for "reset the entire hook state on identity change."
///
/// ## Usage
///
/// ```dart
/// class SearchResults extends HookWidget {
///   final Cell results;
///
///   @override
///   Widget build(BuildContext context) {
///     final snapshot = useCellAsync<List<Product>>(results);
///     if (snapshot.hasError) return ErrorView(snapshot.error!);
///     if (!snapshot.hasData) return const Spinner();
///     return ResultsList(snapshot.data!);
///   }
/// }
/// ```
AsyncSnapshot<V> useCellAsync<V>(
  Cell cell, {
  AsyncSnapshot<V>? initialSnapshot,
}) {
  final snapshot = useState<AsyncSnapshot<V>>(
    initialSnapshot ?? AsyncSnapshot<V>.nothing(),
  );

  useEffect(() {
    final egress = Cell.observe<Pulse<Object?>>(
      source: cell,
      effect: (pulse) {
        if (pulse.type == 'error') {
          snapshot.value = AsyncSnapshot<V>.withError(
            ConnectionState.active,
            pulse.payload ?? StateError('Error pulse with null payload'),
            StackTrace.current,
          );
        } else if (pulse.payload == null && null is V) {
          snapshot.value = AsyncSnapshot<V>.withData(
            ConnectionState.active,
            null as V,
          );
        } else if (pulse.payload is V) {
          snapshot.value = AsyncSnapshot<V>.withData(
            ConnectionState.active,
            pulse.payload as V,
          );
        } else {
          snapshot.value = AsyncSnapshot<V>.withError(
            ConnectionState.active,
            StateError(
              'useCellAsync<$V>: pulse payload is '
              '${pulse.payload.runtimeType}, not $V.',
            ),
            StackTrace.current,
          );
        }
      },
      initiallyStarted: true,
    );
    return egress.stop;
  }, [cell]);

  return snapshot.value;
}
