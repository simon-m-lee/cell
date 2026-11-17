// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns the async state of [cell] as an [AsyncSnapshot], updating on
/// every pulse.
///
/// [useCellAsync] is the hooks layer's **Async State Reader** — the
/// `HookWidget` equivalent of `CellAsyncBuilder`. It gives the caller the
/// same [AsyncSnapshot] shape `StreamBuilder` / `FutureBuilder` provide,
/// driven by a cell, so switch-style rendering on
/// `hasData` / `hasError` transfers directly.
///
/// ### Why it is used
/// - **Async source display in a `HookWidget`**: the widget-layer
///   equivalent (`CellAsyncBuilder`) is a `StatefulWidget`, which a
///   `HookWidget` cannot slot into cleanly for its own render. This hook
///   gives the same snapshot without leaving the hook layer.
/// - **`AsyncSnapshot` ergonomics**: the caller can branch on
///   `snapshot.hasError` / `snapshot.hasData` / `connectionState` exactly
///   as they would with `StreamBuilder`.
/// - **Error visibility**: unlike `useCellValue` and `useCellNotifier`,
///   this hook **does** surface error pulses as `hasError == true`.
///
/// ### How it works
/// 1. `useState` holds the current [AsyncSnapshot]. The initial state is
///    [initialSnapshot] if provided; otherwise it is seeded via
///    [snapshotForCell] — the same retained-pulse path `CellAsyncBuilder`
///    uses (every state-like operator plus [ValueCell]) — falling back to
///    `AsyncSnapshot<V>.nothing()` only when the cell has never emitted.
/// 2. `useEffect` (keyed on `[cell]`) opens one `Cell.observe` link and
///    converts each pulse to a snapshot:
///    - `type == 'error'` → `withError(active, payload ?? StateError(…))`
///    - `null is V` and `payload == null` → `withData(active, null)`
///    - `payload is V` → `withData(active, payload)`
///    - otherwise → `withError(active, StateError('type mismatch'))`
/// 3. The cleanup returned by `useEffect` stops the egress. A cell swap
///    rebinds.
/// 4. The current `snapshot.value` is returned.
///
/// ### Snapshot transitions
/// | Before first pulse | After a data pulse | After an error pulse |
/// |---|---|---|
/// | `ConnectionState.none` (`AsyncSnapshot.nothing()`) | `active`, `hasData == true` | `active`, `hasError == true` |
///
/// **`ConnectionState.done` is never reached.** No core operator emits a
/// completion pulse. `Cell.fromFuture` emits once and stays silent;
/// `Cell.fromStream` emits until the stream ends and stays silent;
/// `Cell.asyncMap` emits per input and never completes. See
/// `CellAsyncBuilder`'s dartdoc for the full lifecycle.
///
/// ### Error-pulse sources (inherited from `CellAsyncBuilder`)
/// Only `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on the
/// failure path. `Cell.fromStream` and `Cell.asyncMap` do **not**. A
/// `useCellAsync` over an `asyncMap` source will therefore keep the last
/// successful snapshot when the mapper throws — errors do not surface
/// through this hook for those sources. Users who need error visibility
/// from those sources must bridge them through a custom cell that re-emits
/// the failure as an `'error'` pulse. The per-source behavior is asserted
/// in `test/error_pulse_sources_test.dart`.
///
/// ### Concurrent `asyncMap` caveat
/// Over `Cell.asyncMap` with `concurrency > 0` (or overlapping
/// `latestOnly` futures), this hook inherits the framework's
/// caveat: concurrent effect attribution is tracked separately and is not
/// yet verified end-to-end. The hook's own observation is correct; the
/// caveat is about the source's replay fidelity. See the `cell` core
/// package for status.
///
/// ### Design Note: cell-swap behavior differs from `CellAsyncBuilder`
/// When [cell] identity changes, the snapshot **persists** across the swap
/// until the new cell emits. That differs from `CellAsyncBuilder`, whose
/// `didUpdateWidget` resets `_snapshot` to
/// `initialSnapshot ?? nothing()` on cell swap. The difference is
/// deliberate: this hook's subscription effect only opens the egress — it
/// does not recompute the snapshot, the way `useCell`'s recompute effect
/// does (`useCell` re-runs its keyed effect synchronously during the build
/// that registers the new cell, so its selection never goes stale).
///
/// To reset the hook's state on cell swap, **key the enclosing
/// `HookWidget`** on the cell:
///
/// ```dart
/// HookBuilder(
///   key: ValueKey(cell),
///   builder: (ctx) => ResultsView(cell: cell),
/// );
/// ```
///
/// Keying is the `flutter_hooks` idiom for "reset the entire hook state on
/// identity change" — it disposes and rebuilds the hook state, which is
/// exactly the reset semantics `CellAsyncBuilder` gets for free from its
/// widget lifecycle.
///
/// ### Technical Details
/// - **One egress per element**: the hook owns one observation link per
///   cell; the `useEffect` cleanup stops it.
/// - **Type erasure at observation**: the link is typed
///   `Pulse<Object?>` so error and type-mismatch pulses can be decoded;
///   the type narrowing happens inside the effect.
/// - **Immediate updates**: pulses commit synchronously in the effect's
///   callback. A pulse arriving during a build phase would trigger
///   Flutter's "setState during build" error — the same contract as
///   `CellAsyncBuilder`'s stateful counterpart. Emit cells from outside
///   the build phase to avoid it.
/// - **State holder is a `useState`**: the hook re-renders when the
///   snapshot changes. Do not call the hook inside a conditional; use a
///   child `HookWidget` if a conditional read is needed.
///
/// ### Example
/// ```dart
/// class SearchResults extends HookWidget {
///   final Cell results;
///   const SearchResults({required this.results, super.key});
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
///
/// ### Parameters:
/// * [cell]: **The Observed Cell.** Any [Cell]. Changing its identity
///   rebinds the effect; the snapshot persists across the swap (see
///   *Cell-swap behavior*).
/// * [initialSnapshot]: **Optional Initial Snapshot.** When supplied,
///   used as the `useState` seed instead of the default seed path. The
///   default path calls [snapshotForCell] — so a [ValueCell] source seeds
///   with its current value, and every state-like operator (`fromFuture`,
///   `fromStream`, `asyncMap`, `derive`) seeds with its retained pulse,
///   exactly like `CellAsyncBuilder` — and falls back to
///   `AsyncSnapshot<V>.nothing()` only when the cell has never emitted.
///   Pass [initialSnapshot] for cache hydration or to override the seed
///   with a snapshot the caller holds.
///
/// ### Returns:
/// The current [AsyncSnapshot], re-rendered on each pulse.
///
/// ### See Also:
/// - `CellAsyncBuilder` — the widget equivalent, whose docs cover error
///   sources and the `ConnectionState.done` note.
/// - [useCell] / [useCellValue] — for synchronous value rendering.
/// - [useCellListener] — for side effects rather than display.
/// - [AsyncSnapshot] — the Flutter type this hook produces.
AsyncSnapshot<V> useCellAsync<V>(
  Cell cell, {
  AsyncSnapshot<V>? initialSnapshot,
}) {
  final snapshot = useState<AsyncSnapshot<V>>(
    initialSnapshot ?? snapshotForCell<V>(cell) ?? AsyncSnapshot<V>.nothing(),
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
