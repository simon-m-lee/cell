// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pulse_delivery.dart';

/// A widget that rebuilds its [builder] whenever any [Cell] emits a new value.
///
/// [CellValueBuilder] is the binding's **General-Purpose Cell Renderer**. It
/// accepts any [Cell] — not only a [ValueCell] — and keeps the latest visible
/// value on its own [State]. This makes it the correct choice for cells whose
/// concrete type is a plain `Cell`: derived projections ([Cell.derive],
/// [Cell.synthesis]), dynamic sources ([Cell.switchMap]), and `cell_tissue`
/// collections (`TissueList`, `TissueMap`, `TissueSet`, `TissueValue`) — none
/// of which extend [ValueCell].
///
/// ### Why it is used
/// - **Derived and projected state**: render a `Cell.derive` view-model, a
///   `Cell.synthesis` convergence, or a `Cell.switchMap` selection without
///   first wrapping it in an `asValueCell` mirror.
/// - **Tissue collections**: `cell_tissue` collections are `Cell` subtypes,
///   not `ValueCell`s, and cannot be handed to `CellBuilder`.
/// - **Async sources**: `Cell.fromFuture`, `Cell.fromStream`, and
///   `Cell.asyncMap` return plain `Cell`; combine with this widget for a
///   simple "latest value" view. For explicit `AsyncSnapshot`-style state,
///   prefer `CellAsyncBuilder`.
///
/// ### How it works
/// 1. **Seeding**: on `initState`, `_value` is seeded from [retainedPulseOf]
///    (the cell's retained pulse via `Cell.latestPulse`, or a [ValueCell]'s
///    current value), falling back to [initial]. See the *Seed semantics*
///    note below.
/// 2. **Observation**: the widget opens one `Cell.observe` link
///    (`EgressHandle<Pulse<Object?>>`) on [cell] and stores the latest
///    payload on the widget [State].
/// 3. **Build-phase deferral**: pulses that arrive during
///    `SchedulerPhase.persistentCallbacks` or `midFrameMicrotasks` are queued
///    and flushed in **one** `addPostFrameCallback`; only the most recent
///    pending pulse is committed. This prevents a parent `build` from
///    triggering `setState` on this element.
/// 4. **Immediate commit**: a pulse that arrives outside a build phase is
///    committed synchronously, so gesture-driven updates add no frame of
///    latency.
/// 5. **Cell swap**: if [cell] identity changes in `didUpdateWidget`, the
///    old egress is stopped, pending pulses are discarded, `_value` is
///    re-seeded, and a fresh egress is bound.
/// 6. **Disposal**: the egress is stopped on `dispose`; `EgressHandle.stop`
///    unlinks the observer, so no manual lifecycle is required.
///
/// ### Design Note: `CellValueBuilder` vs. `CellBuilder`
/// | | `CellBuilder<V>` | `CellValueBuilder<V>` |
/// |---|---|---|
/// | Accepts | `ValueCell<V>` | Any [Cell] |
/// | Underlying | `CellNotifier` (a `ValueNotifier`) | One `EgressHandle`, value kept on `State` |
/// | Rebuild source | `ValueListenableBuilder` | `setState` from the pulse handler |
/// | Read on build | Synchronous `cell.value` | Cached `_value` on `State` |
/// | Use | `Cell.state` results | `Cell.derive` / `synthesis` / `switchMap` / tissue results |
///
/// **Prefer `CellBuilder` when the source is a [ValueCell]** — it is the
/// cheaper binding and gets `ValueListenableBuilder`'s subtree isolation for
/// free. Reach for `CellValueBuilder` only when the source is a plain `Cell`.
///
/// ### Seed semantics (please read)
/// Seeding at subscription time uses [retainedPulseOf], which reads the
/// core package's retained pulse via `Cell.latestPulse` and therefore
/// serves every state-like operator — `fromFuture`, `fromStream`,
/// `asyncMap`, `derive` — as well as [ValueCell]. A source that **already
/// emitted before** this widget subscribed seeds that value into the first
/// frame instead of rendering [initial]. A cell that has never emitted
/// (including [Cell.ingress]) still falls back to [initial]. See
/// `test/seed_paths_test.dart` for the coverage. The behavior is defined by
/// [retainedPulseOf].
///
/// ### Error and type-mismatch pulses
/// - **Error pulses** (`pulse.type == 'error'`) are **silently skipped** by
///   default. Pass [emitErrors] `= true` to forward them to
///   [FlutterError.reportError] (the widget never tears down on a bad pulse).
/// - **One code path, every phase**: there is no separate seeding path for
///   live pulses — a pulse that arrives while this element is still
///   initializing takes the same build-phase deferral (and the same
///   [emitErrors] contract) as any other pulse.
/// - **Type-mismatch pulses** (payload not assignable to `V`) are **always**
///   reported via [FlutterError.reportError]; they are a caller bug, not a
///   transient source error.
/// - During seeding from the **retained slot** ([retainedPulseOf]), an error
///   pulse is ignored for the value — [initial] is used instead — and it is
///   reported via [FlutterError.reportError] when [emitErrors] is `true`,
///   the same contract as a live error pulse.
///
/// ### Concurrent `asyncMap` caveat
/// If the source is `Cell.asyncMap` with `concurrency > 0` (or overlapping
/// `latestOnly` futures), this widget inherits the framework's
/// caveat: concurrent effect attribution is tracked separately and is not yet
/// verified end-to-end. The widget's own observation is correct; the caveat
/// concerns the source's replay fidelity. See the `cell` core package for
/// status.
///
/// ### Technical Details
/// - **One egress per element**: the widget owns exactly one observation
///   link; there is no fan-in or internal multiplexing.
/// - **Coalesced flush**: build-phase pulses are batched into a single
///   post-frame `setState`, using only the most recent pulse.
/// - **Null `V` support**: a `V` that admits `null` accepts a `null`
///   payload as a valid data value; the widget distinguishes "no payload
///   yet" (seeded) from "payload is `null`" (committed).
/// - **No `ValueNotifier`**: unlike `CellBuilder`, this widget does not
///   expose a `Listenable`; consumers that need one should use `CellBuilder`
///   or `CellNotifier` directly.
///
/// See also:
/// - [CellBuilder] — the cheaper binding for [ValueCell] sources.
/// - `CellAsyncBuilder` — snapshot-style rendering for async cells.
/// - `CellAsValue` — to mirror a plain cell into a `ValueCell` for
///   `CellBuilder`.
/// - `pulse_delivery` — [isCellBuildPhase], [retainedPulseOf] and the
///   deferral helpers this widget relies on.
/// - `test/seed_paths_test.dart` — the seed-behavior coverage.
class CellValueBuilder<V> extends StatefulWidget {
  /// Creates a builder bound to [cell].
  ///
  /// [cell] may be any [Cell]; [builder] is called with the latest visible
  /// value (or [initial] before the first pulse).
  const CellValueBuilder({
    required this.cell,
    required this.builder,
    this.initial,
    this.emitErrors = false,
    super.key,
  });

  /// The source cell. Accepts any [Cell], not only [ValueCell].
  ///
  /// Typical sources: `Cell.derive`, `Cell.synthesis`, `Cell.switchMap`,
  /// `Cell.fromFuture`, `Cell.fromStream`, `Cell.asyncMap`, and
  /// `cell_tissue` collections. Prefer [CellBuilder] for `Cell.state`
  /// results.
  final Cell cell;

  /// Rebuilds when [cell]'s value changes.
  ///
  /// Called on first build with the seeded value (or [initial]), and again
  /// whenever a pulse commits a new payload. The second argument is
  /// nullable — `V?` — so callers can render a loading state before the
  /// first pulse.
  final Widget Function(BuildContext context, V? value) builder;

  /// Optional seed value used before [cell]'s first live pulse.
  ///
  /// [retainedPulseOf] serves [ValueCell] sources and every state-like
  /// operator (`fromFuture`, `fromStream`, `asyncMap`, `derive`) that has
  /// already emitted. [initial] is the fallback when the cell has never
  /// emitted a visible pulse, when the retained pulse is an error, or when
  /// its payload is not assignable to `V`.
  final V? initial;

  /// If `true`, error pulses are forwarded to [FlutterError.reportError].
  /// If `false` (default), error pulses are silently skipped.
  ///
  /// **This applies during seeding as well as during subsequent updates** —
  /// an error pulse in the retained slot is reported when `emitErrors` is
  /// `true`, and skipped otherwise.
  ///
  /// Type-mismatch pulses are **always** reported — they are a caller bug,
  /// not a transient source error — regardless of this flag.
  final bool emitErrors;

  @override
  State<CellValueBuilder<V>> createState() => _CellValueBuilderState<V>();
}

class _CellValueBuilderState<V> extends State<CellValueBuilder<V>> {
  V? _value;
  EgressHandle<Pulse<Object?>>? _egress;
  bool _disposed = false;
  bool _flushScheduled = false;
  final List<Pulse<Object?>> _pending = [];

  @override
  void initState() {
    super.initState();
    _seed();
    _bind();
  }

  /// Seeds `_value` from the retained pulse (or [CellValueBuilder.initial])
  /// and reports a retained error pulse through `FlutterError` when
  /// `emitErrors` is enabled — the seed path honors the same error contract
  /// as live pulses.
  void _seed() {
    final retained = retainedPulseOf(widget.cell);
    _value = seedFromRetained(widget.cell, widget.initial);
    if (retained != null && retained.type == 'error') {
      _reportError(
        retained,
        'during CellValueBuilder seed (before first frame)',
      );
    }
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
    if (!mounted || isCellBuildPhase) {
      // A pulse that arrives while this element is still initializing
      // (initState runs inside the first frame's build phase) takes the
      // same deferral path as any other build-phase pulse: one
      // post-frame flush, latest pending pulse wins.
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

  void _reportError(Pulse<Object?> pulse, [String? contextLabel]) {
    if (!widget.emitErrors) return;
    FlutterError.reportError(FlutterErrorDetails(
      exception: pulse.payload ?? StateError('Unknown error pulse'),
      library: 'cell_flutter',
      context: ErrorDescription(
        contextLabel ?? 'while observing Cell in CellValueBuilder',
      ),
    ));
  }

  void _apply(Pulse<Object?> pulse) {
    if (pulse.type == 'error') {
      _reportError(pulse);
      return;
    }
    final payload = pulse.payload;
    if (payload == null && null is V) {
      _value = null;
    } else if (payload is V) {
      _value = payload;
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

  void _commit(Pulse<Object?> pulse) => setState(() => _apply(pulse));

  @override
  void didUpdateWidget(CellValueBuilder<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cell, widget.cell)) {
      _egress?.stop();
      _egress = null;
      _pending.clear();
      _seed();
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
