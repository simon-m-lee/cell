// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection';

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A widget that invokes [onPulse] for every pulse emitted by [cell],
/// **without** rebuilding its subtree.
///
/// [CellListener] is the binding's **Side-Effect Terminal**. Where
/// `CellBuilder` is for *displaying* the current value, this widget is for
/// *reacting* to the arrival of a pulse: navigation, snackbars, haptics,
/// analytics, logging, dialog prompts, and other one-shot imperatives. Its
/// [child] is passed through unchanged and never rebuilt by the listener —
/// that is the entire point of the widget versus `CellBuilder`.
///
/// ### Why it is used
/// - **Imperative side effects**: `Navigator.push`, `showSnackBar`,
///   `HapticFeedback.lightImpact`, `analytics.logEvent` — anything that
///   should happen once per pulse, not on every render.
/// - **Zero rebuild cost**: because the [child] is stable, a listener in the
///   widget tree does not cause Flutter to rebuild anything when its cell
///   pulses. The side effect runs; the tree does not repaint.
/// - **Widget-tree-scoped reaction**: unlike `Cell.observe` (which lives at
///   the graph level and has no [BuildContext]), a `CellListener` fires with
///   the widget's own [BuildContext] so handlers can reach
///   `Theme.of`, `Navigator.of`, `ScaffoldMessenger.of`, `MediaQuery.of`.
///
/// ### How it works
/// 1. **Bind**: on `initState`, the widget opens one `Cell.observe` link on
///    [cell] and forwards each pulse into `_dispatch`.
/// 2. **Dispatch**: if the pulse arrives outside a build phase (event
///    handler, timer, microtask, animation), [onPulse] is invoked
///    **synchronously** — no frame of latency is added. If it arrives
///    during `persistentCallbacks` or `midFrameMicrotasks`, it is queued and
///    delivered in order from a single post-frame callback. This makes it
///    safe for [onPulse] to call `Navigator.push`, `showSnackBar`, or
///    `setState` without tripping Flutter's *"setState() or markNeedsBuild()
///    called during build"* error.
/// 3. **Rebind**: if [cell] identity changes in `didUpdateWidget`, the old
///    egress is stopped and a new one is bound. A change to [onPulse]
///    identity does **not** rebind — `widget.onPulse` is read at invoke time,
///    so a fresh closure per build costs nothing.
/// 4. **Dispose**: the egress is stopped and the pending queue drained.
///
/// ### Design Note: `CellListener` vs. `CellBuilder`
/// | | `CellBuilder<V>` | `CellListener<V>` |
/// |---|---|---|
/// | Rebuilds subtree | Yes | No |
/// | Purpose | Display current value | Run one-shot side effect |
/// | Source type | `ValueCell<V>` | Any `Cell` |
/// | [BuildContext] | inherited from [ValueListenableBuilder] | this widget's own context |
/// | [child] | builder returns it per build | passed through unchanged |
///
/// **Compose, do not substitute**: a subtree that needs to both display and
/// react should contain both widgets — a `CellBuilder` for the display and a
/// `CellListener` for the effect — rather than forcing either widget to do
/// both jobs.
///
/// ### Pulse semantics
/// - **Data pulses** are delivered to [onPulse] in emission order.
/// - **Error pulses** (`pulse.type == 'error'`) arrive as `Pulse<V>` at the
///   type level, but their `payload` is the underlying error object, **not**
///   a `V`. Only `Cell.fromFuture` emits these on its failure path;
///   `Cell.fromStream` and `Cell.asyncMap` do **not** emit error pulses in
///   the core package today, so their failures never reach this listener.
///   Do not cast `pulse.payload` blindly — check `pulse.type` first:
///
/// ```dart
/// onPulse: (context, pulse) {
///   if (pulse.type == 'error') {
///     showErrorDialog(context, pulse.payload);
///     return;
///   }
///   final value = pulse.payload as V?; // safe on the data path
///   handleValue(value);
/// },
/// ```
///
/// ### Async [onPulse]
/// [onPulse] is typed `void Function(...)`. An `async` closure is accepted
/// and the returned `Future` is ignored. Because Flutter's [BuildContext]
/// becomes invalid after the widget unmounts, **check `context.mounted`
/// after any `await`**:
///
/// ```dart
/// onPulse: (context, pulse) async {
///   await showDialog(context: context, ...);
///   if (!context.mounted) return;
///   Navigator.of(context).push(...);
/// },
/// ```
///
/// ### Error containment
/// If [onPulse] throws, the error is reported via [FlutterError.reportError]
/// and the listener continues to receive subsequent pulses. A single bad
/// handler does not tear down the listener or drop the queue.
///
/// ### When **not** to use
/// - **Display**: the pulse is state to be rendered. Use `CellBuilder` (or
///   `CellValueBuilder` for non-`ValueCell` sources).
/// - **Broadcast/batch**: the pulse is a batch signal that many independent
///   consumers should see, not a widget-scoped reaction. Use `Cell.observe`
///   directly with a custom effect.
///
/// ### Technical Details
/// - **One egress per element**: the widget owns exactly one observation
///   link; multiple pulses share it.
/// - **Ordered deferral**: pending pulses are held in a [Queue] and drained
///   FIFO on the post-frame callback — order is preserved across the defer.
/// - **Lifecycle guards**: `_dispatch` checks `_disposed` and `mounted`
///   before queueing; `_flush` re-checks both before draining. `dispose`
///   drops any unconsumed pulses.
///
/// ### Concurrent `asyncMap` caveat
/// Listeners over `Cell.asyncMap` sources with `concurrency > 0` (or
/// overlapping `latestOnly` futures) inherit the framework's
/// caveat: concurrent effect attribution is tracked separately and is not
/// yet verified end-to-end. The listener's own delivery is correct; the
/// caveat concerns the source's replay fidelity. See the `cell` core package
/// for status.
///
/// ### Example
/// ```dart
/// final login = Cell.state<String?>(initial: null);
///
/// CellListener<String?>(
///   cell: login.cell,
///   onPulse: (context, pulse) {
///     if (pulse.payload != null) {
///       ScaffoldMessenger.of(context)
///           .showSnackBar(SnackBar(content: Text('Hi ${pulse.payload}')));
///     }
///   },
///   child: const LoginForm(),
/// );
/// ```
///
/// ### See Also:
/// - `CellBuilder` — for displaying the current value.
/// - `CellValueBuilder` — for displaying values from non-`ValueCell` sources.
/// - `CellAsyncBuilder` — for `AsyncSnapshot`-style rendering of async cells.
/// - `Cell.observe` — the underlying primitive, for graph-level side effects
///   outside the widget tree.
/// - `test/error_pulse_sources_test.dart` — the authoritative statement of
///   which sources emit error pulses.
class CellListener<V> extends StatefulWidget {
  /// Creates a listener over [cell] that invokes [onPulse] for every pulse.
  ///
  /// [child] is passed through unchanged and is **not** rebuilt when [cell]
  /// emits. If the child needs to react visually, compose a `CellBuilder`
  /// inside it rather than expecting [CellListener] to rebuild.
  ///
  /// ### Parameters:
  /// * [cell]: **The Observed Cell.** Any [Cell]. Held by reference.
  /// * [onPulse]: **The Side-Effect Handler.** Invoked once per pulse, on
  ///   this widget's [BuildContext].
  /// * [child]: **The Stable Subtree.** Displayed unchanged across pulses.
  ///
  /// ### Throws:
  /// [ArgumentError] at first build if [cell] is invalidated. See
  /// `_CellListenerState._bind`.
  const CellListener({
    required this.cell,
    required this.onPulse,
    required this.child,
    super.key,
  });

  /// The cell to observe.
  ///
  /// Takes any [Cell], not a `ValueCell` — pulsing from a `Cell.derive`,
  /// `Cell.ingress`, `Cell.asyncMap`, or a `cell_tissue` collection is the
  /// common case. `Cell` carries no value type parameter; the value type
  /// lives on the [Pulse] delivered to [onPulse].
  final Cell cell;

  /// Invoked for every pulse, on the widget's [BuildContext].
  ///
  /// The [BuildContext] is [CellListener]'s own context — it sits **above**
  /// the [child] in the tree. Use it for `Navigator.of`, `Theme.of`,
  /// `ScaffoldMessenger.of`, `MediaQuery.of`.
  ///
  /// An `async` closure is allowed; the returned [Future] is ignored. Guard
  /// `context.mounted` after any `await` (see the class-level *Async
  /// onPulse* note).
  final void Function(BuildContext context, Pulse<V> pulse) onPulse;

  /// The widget to display. Stable across pulses.
  ///
  /// Rebuilds of this subtree are the caller's responsibility — typically a
  /// `CellBuilder` (or `CellValueBuilder`) nested inside [child].
  final Widget child;

  @override
  State<CellListener<V>> createState() => _CellListenerState<V>();
}

class _CellListenerState<V> extends State<CellListener<V>> {
  EgressHandle<Pulse<V>>? _egress;
  final Queue<Pulse<V>> _pending = Queue<Pulse<V>>();
  bool _flushScheduled = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (widget.cell.isInvalidated) {
      throw ArgumentError(
        'CellListener: cannot listen to an invalidated cell.',
      );
    }
    _egress = Cell.observe<Pulse<V>>(
      source: widget.cell,
      effect: _dispatch,
      initiallyStarted: true,
    );
  }

  void _unbind() {
    _egress?.stop();
    _egress = null;
    _pending.clear();
  }

  void _dispatch(Pulse<V> pulse) {
    if (_disposed || !mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final defer =
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    if (defer) {
      _pending.add(pulse);
      if (!_flushScheduled) {
        _flushScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _flushScheduled = false;
          _flush();
        });
      }
    } else {
      _invoke(pulse);
    }
  }

  void _flush() {
    while (_pending.isNotEmpty && !_disposed && mounted) {
      _invoke(_pending.removeFirst());
    }
    // Defensive: if the widget was disposed or unmounted mid-flush,
    // discard whatever remains (a no-op on an already-drained queue).
    _pending.clear();
  }

  void _invoke(Pulse<V> pulse) {
    try {
      widget.onPulse(context, pulse);
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'cell_flutter',
          context: ErrorDescription('while invoking CellListener.onPulse'),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(CellListener<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebinding is ONLY for cell swaps. Do not rebind on `onPulse` identity
    // change: `widget.onPulse` is always the current handler at invoke time,
    // so a new closure on every build costs nothing. Rebinding here would
    // dispose/re-create an EgressHandle 60+ times per second.
    if (!identical(oldWidget.cell, widget.cell)) {
      _unbind();
      _bind();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
