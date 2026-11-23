// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../pulse_delivery.dart';

/// Invokes [onPulse] for every pulse emitted by [cell], **without**
/// rebuilding the widget.
///
/// [useCellListener] is the hooks layer's **Side-Effect Terminal** — the
/// `HookWidget` equivalent of `CellListener`. It is the hook to use when
/// a cell pulse should trigger navigation, a snackbar, haptics, analytics,
/// or any one-shot imperative, and the widget should **not** rebuild on
/// the pulse.
///
/// ### Why it is used
/// - **Rebuild-free reactions**: a `HookWidget` that only reacts to pulses
///   (no display) would otherwise have to call `useCellValue` for no
///   visible reason. This hook fires the effect and touches no widget
///   state.
/// - **Build-phase safety**: pulses arriving during `persistentCallbacks`
///   or `midFrameMicrotasks` are deferred to a single post-frame callback,
///   so `Navigator.push`, `ScaffoldMessenger.showSnackBar`, and `setState`
///   are safe to call from [onPulse].
/// - **Ordered delivery**: multiple pulses queued in the same frame are
///   delivered in emission order, in one post-frame callback.
///
/// ### How it works
/// 1. `useContext` captures the enclosing [BuildContext] — the hook's
///    closure delivers [onPulse] with this context so handlers can reach
///    `Navigator.of`, `Theme.of`, `ScaffoldMessenger.of`.
///
///    **Reparenting note**: the captured context is bound to the position
///    where the hook was first built. If the enclosing `HookWidget` is
///    *moved* in the tree (reparented under a different `Navigator` /
///    `Theme`), the effect is keyed on `[cell]` and does **not** re-run,
///    so the handler keeps resolving from the old position. Key the widget
///    (or rebuild it under the new parent) when the context's ancestry
///    must follow the move.
/// 2. `useRef` holds the latest [onPulse], so a new closure per build does
///    **not** re-subscribe; the effect reads `onPulseRef.value` at invoke
///    time and always calls the current handler.
/// 3. `useMemoized` creates a per-cell pending [Queue] used for deferral.
/// 4. `useEffect` (keyed on `[cell]`) opens one `Cell.observe` link and
///    installs a cleanup that stops it, clears the queue, and resets the
///    scheduled flag. A cell swap rebinds through this effect.
///
/// ### Design Note: why the pending queue is cleared on cell swap
/// Pulses queued against the previous cell are **not** relevant to the new
/// one — firing them after a swap would deliver pulses from the wrong
/// source to the new cell's handler. The `useEffect` cleanup clears the
/// queue before the new egress is bound, so a swap behaves as if the
/// listener had been freshly attached to the new source.
///
/// ### Pulse semantics
/// - **Data pulses** are delivered to [onPulse] on the enclosing
///   [BuildContext].
/// - **Error pulses** (`pulse.type == 'error'`) arrive as `Pulse<V>` at
///   the type level, but their `payload` is the underlying error object,
///   not a `V`. **Do not cast the payload blindly** on that path:
///
/// ```dart
/// onPulse: (context, pulse) {
///   if (pulse.type == 'error') {
///     showErrorDialog(context, pulse.payload);
///     return;
///   }
///   handleValue(pulse.payload);
/// },
/// ```
///
/// ### Error containment
/// If [onPulse] throws, the error is reported via
/// [FlutterError.reportError] and the listener continues to receive
/// subsequent pulses. One bad handler does not tear down the hook or drop
/// the queue.
///
/// ### Technical Details
/// - **Deliver-once, in order**: each queued pulse is delivered exactly
///   once; the post-frame callback drains the queue with
///   `removeFirst()` before invoking, which is required because a handler
///   that unmounts the hook (e.g. `Navigator.pop`) clears the queue
///   synchronously.
/// - **`onPulseRef` indirection**: [onPulse] is captured in a ref, not a
///   memoized value, so identity changes in the closure do not force a
///   rebind. This mirrors `CellListener`'s `didUpdateWidget` behavior.
/// - **Lifecycle guards**: the effect's `disposed` flag and
///   `context.mounted` are checked before queueing and before delivery, so
///   a pulse that lands after unmount is dropped, not fired.
/// - **Sync outside build phases**: pulses outside a build phase fire
///   synchronously — no frame of latency is added for the common case.
///
/// ### Parameters:
/// * [cell]: **The Observed Cell.** Any [Cell] — including derived cells,
///   async cells, and tissue collections. Changing the cell identity
///   rebinds the effect and clears any pending queue.
/// * [onPulse]: **The Side-Effect Handler.** Called once per pulse with
///   the enclosing [BuildContext] and the [Pulse]. An `async` closure is
///   allowed; the returned [Future] is ignored. Guard `context.mounted`
///   after any `await` — the context is invalidated on unmount.
///
/// ### See Also:
/// - `CellListener` — the widget equivalent, whose docs cover the same
///   deferral and error-containment contracts.
/// - [useCell] / [useCellValue] — the display hooks.
/// - `Cell.observe` — the underlying primitive, for graph-level side
///   effects outside the widget tree.
/// - `test/error_pulse_sources_test.dart` — the authoritative statement of
///   which sources emit error pulses.
void useCellListener<V>({
  required Cell cell,
  required void Function(BuildContext context, Pulse<V> pulse) onPulse,
}) {
  final context = useContext();
  final onPulseRef = useRef(onPulse);
  onPulseRef.value = onPulse;
  final pending = useMemoized(Queue<Pulse<V>>.new, [cell]);
  final flushScheduled = useRef(false);

  useEffect(() {
    var disposed = false;
    final egress = Cell.observe<Pulse<V>>(
      source: cell,
      effect: (pulse) {
        if (disposed || !context.mounted) return;
        void invoke(Pulse<V> next) {
          try {
            onPulseRef.value(context, next);
          } catch (e, st) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: e,
                stack: st,
                library: 'cell_flutter',
                context: ErrorDescription(
                  'while invoking useCellListener.onPulse',
                ),
              ),
            );
          }
        }

        if (!isCellBuildPhase) {
          invoke(pulse);
          return;
        }
        pending.add(pulse);
        if (flushScheduled.value) return;
        flushScheduled.value = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          flushScheduled.value = false;
          while (pending.isNotEmpty && !disposed && context.mounted) {
            // Remove before invoke. An onPulse that unmounts the hook
            // clears [pending]; removing afterwards throws.
            invoke(pending.removeFirst());
          }
          pending.clear();
        });
      },
      initiallyStarted: true,
    );
    return () {
      disposed = true;
      egress.stop();
      pending.clear();
      flushScheduled.value = false;
    };
  }, [cell]);
}
