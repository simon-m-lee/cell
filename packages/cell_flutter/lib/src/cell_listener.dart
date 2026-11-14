// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection';

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Invokes [onPulse] for every pulse emitted by [cell]. Does not rebuild.
///
/// Use this for one-shot side effects: navigation, snackbars, haptics,
/// analytics, logging. For state display (rendering the current value),
/// use [CellBuilder] instead.
///
/// ## Mid-frame deferral
///
/// Pulses fired during Flutter's build or mid-frame phases are deferred to
/// the frame's end. This means [onPulse] can safely call `Navigator.push`,
/// `ScaffoldMessenger.showSnackBar`, `setState`, or any method that would
/// otherwise throw "setState() or markNeedsBuild() called during build".
///
/// Multiple pulses that arrive in the same frame are delivered in order,
/// in a single post-frame callback.
///
/// Pulses fired outside the build phases (from event handlers, timers,
/// microtasks, or animations) are delivered **synchronously** — no frame
/// of latency is added.
///
/// ## Error pulses
///
/// `Cell.asyncMap`, `Cell.fromFuture`, and `Cell.fromStream` emit error
/// pulses as `Pulse<Object>(type: 'error')`. Their `payload` is the
/// underlying error, **not** a `V`. Because Dart's generics are covariant,
/// a `CellListener<V>` over an error-emitting source receives the pulse as
/// `Pulse<V>`, but `pulse.payload` resolves to `Object?` at runtime. Do not
/// cast blindly:
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
/// Listeners over `Cell.asyncMap` sources with `concurrency > 0` inherit the
/// framework's Gate G1.5 caveat: concurrent effect attribution is tracked
/// separately and is not yet verified end-to-end. See the `cell` core package
/// for status.
///
/// ## When not to use
///
/// - The pulse is state that should be displayed. Use [CellBuilder].
/// - The pulse is a batch/broadcast. Use `Cell.observe` directly with a
///   custom effect; [CellListener] is for widget-tree-scoped reactions.
///
/// ## Async `onPulse`
///
/// `onPulse` is typed `void Function(...)`. An `async` closure is allowed
/// and the returned `Future` is ignored. Because Flutter's `BuildContext`
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
/// ## Error containment
///
/// If [onPulse] throws, the error is reported via [FlutterError.reportError]
/// and the listener continues to receive subsequent pulses. One bad handler
/// does not kill the listener.
class CellListener<V> extends StatefulWidget {
  /// Creates a listener over [cell] that invokes [onPulse] for every pulse.
  ///
  /// The [child] is passed through unchanged. It is **not** rebuilt when
  /// [cell] emits — that is the entire point of [CellListener] versus
  /// [CellBuilder]. If the child needs to react visually, compose with a
  /// [CellBuilder] inside it.
  const CellListener({
    required this.cell,
    required this.onPulse,
    required this.child,
    super.key,
  });

  /// The cell to observe.
  ///
  /// Takes any [Cell], not [ValueCell] — pulsing from a `Cell.derive`,
  /// `Cell.ingress`, or `Cell.asyncMap` is the common case. (`Cell` carries
  /// no value type parameter; the value type lives on the [Pulse] delivered
  /// to [onPulse].)
  final Cell cell;

  /// Invoked for every pulse, on the widget's [BuildContext].
  ///
  /// The `BuildContext` is the [CellListener]'s own context — it sits
  /// *above* the [child] in the tree. Use it for `Navigator.of`,
  /// `Theme.of`, `ScaffoldMessenger.of`, `MediaQuery.of`.
  final void Function(BuildContext context, Pulse<V> pulse) onPulse;

  /// The widget to display. Stable across pulses.
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
    final defer = phase == SchedulerPhase.midFrameMicrotasks ||
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
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'cell_flutter',
        context: ErrorDescription('while invoking CellListener.onPulse'),
      ));
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
