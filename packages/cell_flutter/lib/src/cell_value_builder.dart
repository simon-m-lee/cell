// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pulse_delivery.dart';

/// Rebuilds [builder] whenever [cell] emits a new value.
///
/// Unlike [CellBuilder], this accepts any [Cell] — not just `ValueCell`.
/// Use it for derived cells (`Cell.derive`, `Cell.synthesis`,
/// `Cell.switchMap`) which return `Cell`, not `ValueCell`. Also works for
/// `cell_tissue` collections (`TissueList`, `TissueMap`, `TissueSet`,
/// `TissueValue`) — they are `Cell` subtypes that do not extend `ValueCell`.
///
/// ## How it differs from `CellBuilder`
///
/// | | `CellBuilder<V>` | `CellValueBuilder<V>` |
/// |---|---|---|
/// | Accepts | `ValueCell<V>` | Any `Cell` |
/// | Underlying | `CellNotifier` directly | One `EgressHandle`, value kept on `State` |
/// | Cost | One `EgressHandle` | One `EgressHandle` |
/// | Use | `Cell.state` results | `Cell.derive` / `synthesis` / `switchMap` / tissue results |
///
/// **Prefer `CellBuilder` when the cell is a `ValueCell`** — it is cheaper.
/// Reach for `CellValueBuilder` only when the source is not a `ValueCell`.
///
/// ## Implementation
///
/// The latest payload is stored on the widget [State]. Pulses that arrive
/// during build are applied after the frame, so a parent `build` cannot
/// `setState` this element. A cell that already emitted (for example a
/// completed `Cell.fromFuture`) is seeded from [Cell.latestPulse] before
/// the first frame.
///
/// On dispose the observation link is released (`Cell.observe`'s `stop`
/// unlinks the observer). No manual lifecycle.
///
/// ## Error and type-mismatch pulses
///
/// Error pulses (`pulse.type == 'error'`) and payloads that are not `V`
/// are reported via `FlutterError.reportError` when [emitErrors] is `true`
/// (default: `false`). The widget itself never tears down on a bad pulse.
///
/// ## Concurrent `asyncMap` caveat
///
/// If the source is `Cell.asyncMap` with `concurrency > 0`, the mirror
/// inherits the framework's Gate G1.5 caveat (tracked separately). The
/// widget's observation is correct; the caveat is about the source's
/// replay fidelity.
class CellValueBuilder<V> extends StatefulWidget {
  const CellValueBuilder({
    required this.cell,
    required this.builder,
    this.initial,
    this.emitErrors = false,
    super.key,
  });

  /// The source cell. Accepts any [Cell], not just `ValueCell`.
  final Cell cell;

  /// Rebuilds when [cell]'s value changes.
  final Widget Function(BuildContext context, V? value) builder;

  /// Optional initial value before [cell]'s first pulse.
  ///
  /// Useful when the source emitted before the widget subscribed — same
  /// caveat as `CellAsyncBuilder.initialSnapshot`.
  final V? initial;

  /// If `true`, error pulses are reported via [FlutterError.reportError].
  /// If `false` (default), they are silently skipped.
  ///
  /// Type-mismatch pulses are **always** reported — they are a caller bug,
  /// not a transient source error.
  final bool emitErrors;

  @override
  State<CellValueBuilder<V>> createState() => _CellValueBuilderState<V>();
}

class _CellValueBuilderState<V> extends State<CellValueBuilder<V>> {
  V? _value;
  EgressHandle<Pulse<Object?>>? _egress;
  bool _disposed = false;
  bool _ready = false;
  bool _flushScheduled = false;
  final List<Pulse<Object?>> _pending = [];

  @override
  void initState() {
    super.initState();
    _value = _seed(widget.cell, widget.initial);
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

  void _onPulse(Pulse<Object?> pulse) {
    if (_disposed) return;
    if (!_ready) {
      _store(pulse);
      return;
    }
    if (!mounted || isCellBuildPhase) {
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
        _commit(last);
      });
      return;
    }
    _commit(pulse);
  }

  void _store(Pulse<Object?> pulse) {
    if (pulse.type == 'error') return;
    final payload = pulse.payload;
    if (payload == null && null is V) {
      _value = null;
    } else if (payload is V) {
      _value = payload;
    }
  }

  void _commit(Pulse<Object?> pulse) {
    if (pulse.type == 'error') {
      if (widget.emitErrors) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: pulse.payload ?? StateError('Unknown error pulse'),
          library: 'cell_flutter',
          context:
              ErrorDescription('while observing Cell in CellValueBuilder'),
        ));
      }
      return;
    }
    final payload = pulse.payload;
    if (payload == null && null is V) {
      setState(() => _value = null);
    } else if (payload is V) {
      setState(() => _value = payload);
    } else {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError(
          'CellValueBuilder<$V>: pulse payload is '
          '${payload.runtimeType}, not $V.',
        ),
        library: 'cell_flutter',
        context: ErrorDescription('while observing Cell in CellValueBuilder'),
      ));
    }
  }

  @override
  void didUpdateWidget(CellValueBuilder<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cell, widget.cell)) {
      _egress?.stop();
      _egress = null;
      _pending.clear();
      _value = _seed(widget.cell, widget.initial);
      _bind();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _egress?.stop();
    _egress = null;
    _pending.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

/// Prefers a retained latest payload over [initial]. An explicit [initial]
/// is the fallback for cells that have not emitted yet.
V? _seed<V>(Cell cell, V? initial) {
  final latest = retainedPulseOf(cell);
  if (latest == null || latest.type == 'error') return initial;
  final payload = latest.payload;
  if (payload is V) return payload;
  if (payload == null && null is V) return null;
  return initial;
}
