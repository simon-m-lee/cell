// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pulse_delivery.dart';

/// Builds the snapshot a [CellAsyncBuilder] would show for [pulse].
AsyncSnapshot<V> snapshotForPulse<V>(Pulse<Object?> pulse) {
  final type = pulse.type;
  final payload = pulse.payload;
  if (type == 'error') {
    return AsyncSnapshot<V>.withError(
      ConnectionState.active,
      payload ?? StateError('Pulse of type "error" with null payload'),
      StackTrace.current,
    );
  }
  if (payload == null && null is V) {
    return AsyncSnapshot<V>.withData(ConnectionState.active, null as V);
  }
  if (payload is V) {
    return AsyncSnapshot<V>.withData(ConnectionState.active, payload);
  }
  return AsyncSnapshot<V>.withError(
    ConnectionState.active,
    StateError(
      'CellAsyncBuilder<$V>: pulse payload is ${payload.runtimeType}, not $V.',
    ),
    StackTrace.current,
  );
}

/// The snapshot of [cell]'s retained latest pulse, or `null` when the cell
/// has not emitted one yet. [Cell.fromFuture], [Cell.fromStream],
/// [Cell.asyncMap], and [Cell.derive] retain that pulse; [Cell.ingress]
/// does not.
AsyncSnapshot<V>? snapshotForCell<V>(Cell cell) {
  final latest = retainedPulseOf(cell);
  if (latest == null) return null;
  return snapshotForPulse<V>(latest);
}

/// Renders the asynchronous state of [cell] as an [AsyncSnapshot<V>].
///
/// Accepts **any [Cell]**, not just `ValueCell` — async sources produced by
/// [Cell.fromFuture], [Cell.fromStream], and [Cell.asyncMap] return plain
/// `Cell`, and derived async cells compose the same way.
///
/// ## Snapshot transitions
///
/// - Before the first pulse: `ConnectionState.none`, `hasData == false`,
///   `hasError == false`.
/// - After a data pulse: `ConnectionState.active`, `hasData == true`.
/// - After an error pulse: `ConnectionState.active`, `hasError == true`.
/// - **`ConnectionState.done` is never reached.** No core operator emits a
///   completion pulse. `Cell.fromFuture` emits once and stays silent;
///   `Cell.fromStream` emits until the stream ends and then stays silent.
///   If the widget needs completion detection, compose with a completion
///   cell (documented in `HowTo-CellAsyncBuilder.md`).
///
/// ## Error pulses
///
/// `Cell.fromFuture`, `Cell.fromStream`, and `Cell.asyncMap` emit
/// `Pulse<Object>(type: 'error')` when the future, stream, or mapper
/// fails. A type-mismatched payload is also surfaced as [AsyncSnapshot.hasError].
/// Stream errors are not journalled for replay; that gap is in `cell`.
///
/// ## Concurrent `asyncMap` caveat
///
/// When the source is `Cell.asyncMap` with `concurrency > 0` or overlapping
/// `latestOnly` futures, this widget inherits the framework's Gate G1.5
/// caveat: concurrent effect attribution is tracked separately and is not
/// yet verified end-to-end. The widget's own observation behavior is
/// correct; the caveat is about the source's replay fidelity.
///
/// ## Usage
///
/// ```dart
/// final search = Cell.ingress<String>();
/// final results = Cell.asyncMap<String, List<String>>(
///   search.cell,
///   (query) async => api.search(query),
///   latestOnly: true,
/// );
///
/// CellAsyncBuilder<List<String>>(
///   cell: results,
///   builder: (ctx, snapshot) => switch (snapshot) {
///     AsyncSnapshot(hasData: true) => ResultsList(snapshot.data!),
///     AsyncSnapshot(hasError: true) => ErrorView(snapshot.error!),
///     _ => const LoadingSpinner(),
///   },
/// );
/// ```
class CellAsyncBuilder<V> extends StatefulWidget {
  const CellAsyncBuilder({
    required this.cell,
    required this.builder,
    this.initialSnapshot,
    super.key,
  });

  /// The async-source cell.
  ///
  /// Accepts any [Cell]. For `ValueCell` sources, prefer `CellBuilder` —
  /// this widget is for the async operators that return plain `Cell`.
  final Cell cell;

  /// Renders the current snapshot. Called on every pulse.
  final Widget Function(BuildContext context, AsyncSnapshot<V> snapshot)
      builder;

  /// Optional initial snapshot. Defaults to `AsyncSnapshot<V>.nothing()`.
  ///
  /// Two use cases:
  /// 1. **Cache hydration** — pass `AsyncSnapshot.withData(ConnectionState.active, cached)`
  ///    to render the cached value before the first pulse arrives.
  /// 2. **Already emitted** — `fromFuture`, `fromStream`, `asyncMap`, and
  ///    `derive` retain their latest pulse. The widget seeds from that pulse
  ///    when [initialSnapshot] is null, so a cell that completed before this
  ///    widget subscribed is not stuck on `nothing()`. Pass [initialSnapshot]
  ///    only to override that retained value (cache hydration).
  final AsyncSnapshot<V>? initialSnapshot;

  @override
  State<CellAsyncBuilder<V>> createState() => _CellAsyncBuilderState<V>();
}

class _CellAsyncBuilderState<V> extends State<CellAsyncBuilder<V>> {
  late AsyncSnapshot<V> _snapshot;
  EgressHandle<Pulse<Object?>>? _egress;
  bool _disposed = false;
  bool _ready = false;
  bool _flushScheduled = false;
  final List<Pulse<Object?>> _pending = [];

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ??
        snapshotForCell<V>(widget.cell) ??
        AsyncSnapshot<V>.nothing();
    _bind();
    _ready = true;
  }

  void _bind() {
    _egress = Cell.observe<Pulse<Object?>>(
      source: widget.cell,
      effect: _onPulse,
      initiallyStarted: true,
    );
  }

  void _unbind() {
    _egress?.stop();
    _egress = null;
    _pending.clear();
  }

  void _apply(Pulse<Object?> pulse) {
    _snapshot = snapshotForPulse<V>(pulse);
  }

  void _onPulse(Pulse<Object?> pulse) {
    if (_disposed) return;
    if (!_ready) {
      _apply(pulse);
      return;
    }
    if (!mounted) return;
    if (!isCellBuildPhase) {
      setState(() => _apply(pulse));
      return;
    }
    _pending.add(pulse);
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_disposed || !mounted || _pending.isEmpty) {
        _pending.clear();
        return;
      }
      final last = _pending.last;
      _pending.clear();
      setState(() => _apply(last));
    });
  }

  @override
  void didUpdateWidget(CellAsyncBuilder<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cell, widget.cell)) {
      _unbind();
      _snapshot = widget.initialSnapshot ??
          snapshotForCell<V>(widget.cell) ??
          AsyncSnapshot<V>.nothing();
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
  Widget build(BuildContext context) => widget.builder(context, _snapshot);
}
