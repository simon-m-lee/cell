// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pulse_delivery.dart';

/// Projects a single [Pulse] into an [AsyncSnapshot] for a `CellAsyncBuilder`.
///
/// [snapshotForPulse] is the binding's **Pulse-to-Snapshot Decoder** — the
/// one place where cell-level pulse types are translated into Flutter's
/// `AsyncSnapshot` contract. Every rendering decision in `CellAsyncBuilder`
/// flows through this function, which keeps the widget state class small and
/// makes the mapping testable in isolation.
///
/// ### Why it is used
/// - **Single source of truth**: error pulses, `null` data, and
///   type-mismatched payloads are all decoded here, not scattered through
///   the widget's state machine.
/// - **Testability**: it is a pure function; unit tests can assert every
///   pulse shape without pumping a widget.
///
/// ### How it works
/// | `pulse.type` | Payload | Snapshot produced |
/// |---|---|---|
/// | `'error'` | any non-null | `withError(active, payload, now)` |
/// | `'error'` | `null` | `withError(active, StateError('…'), now)` |
/// | data | `null`, `null is V` | `withData(active, null)` |
/// | data | `is V` | `withData(active, payload)` |
/// | data | not `V` | `withError(active, StateError('…'), now)` |
///
/// The result is always `ConnectionState.active`: no core operator ever
/// emits a completion pulse, so `ConnectionState.done` is never produced
/// here (see `CellAsyncBuilder` class docs).
///
/// ### Technical Details
/// - **`StackTrace.current` used for error snapshots**: `AsyncSnapshot`
///   requires a stack trace on error; a fresh one is synthesized at decode
///   time because the pulse does not carry one.
/// - **Null-aware `V`**: distinguishes "`V` admits `null`" (`null is V`) from
///   "`V` does not admit `null`" so `CellAsyncBuilder<int?>` and
///   `CellAsyncBuilder<int>` behave correctly.
/// - **No state, no allocation beyond the returned snapshot**.
///
/// See also:
/// - [snapshotForCell] — the retained-value seed used by `CellAsyncBuilder`.
/// - `CellAsyncBuilder` — the widget that calls this function per pulse.
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

/// Returns the [AsyncSnapshot] the widget should show for [cell]'s currently
/// retained pulse, or `null` when nothing usable is retained.
///
/// [snapshotForCell] is the **Late-Subscriber Seed** used by
/// `CellAsyncBuilder`. When a widget subscribes to a cell that already
/// emitted — a completed `Cell.fromFuture`, a `Cell.derive` that produced
/// a value — the widget should render that value on its first frame instead
/// of flickering through `nothing()` first. This function provides the seed.
///
/// ### How it works
/// 1. It calls [retainedPulseOf] on [cell].
/// 2. If the result is `null`, it returns `null` — the widget falls back to
///    `AsyncSnapshot<V>.nothing()`.
/// 3. Otherwise it delegates to [snapshotForPulse] and returns the snapshot.
///
/// ### Seed semantics (please read)
/// `retainedPulseOf` reads the core package's retained pulse via
/// `Cell.latestPulse`, so the common use cases this widget was built for —
/// `Cell.fromFuture`, `Cell.fromStream`, `Cell.asyncMap`, `Cell.derive` —
/// **do** seed through this function once they have emitted: a completed
/// `fromFuture` renders its data on the first frame instead of `nothing()`.
/// A cell that has never emitted returns `null` and the widget falls back
/// to `AsyncSnapshot<V>.nothing()`. If the caller wants to override the
/// seed, pass `CellAsyncBuilder.initialSnapshot` as an `AsyncSnapshot`.
/// The behavior is defined by `retainedPulseOf`; see
/// `test/seed_paths_test.dart` for the coverage.
///
/// ### Technical Details
/// - **No subscription**: this function does not open an egress. It reads
///   only what the binding can already see synchronously.
/// - **Pulse-shape fidelity**: any error in the retained slot is surfaced
///   as an error snapshot (via [snapshotForPulse]) rather than as data.
///
/// See also:
/// - [snapshotForPulse] — the decoder this function delegates to.
/// - [retainedPulseOf] — the retained-value probe.
/// - `test/seed_paths_test.dart` — the seed-behavior coverage.
/// - `CellAsyncBuilder.initialSnapshot` — the explicit override.
AsyncSnapshot<V>? snapshotForCell<V>(Cell cell) {
  final latest = retainedPulseOf(cell);
  if (latest == null) return null;
  return snapshotForPulse<V>(latest);
}

/// A widget that renders the asynchronous state of any [Cell] as an
/// [AsyncSnapshot<V>].
///
/// [CellAsyncBuilder] is the binding's **Async State Renderer** — the
/// widget counterpart of `StreamBuilder` / `FutureBuilder`, but driven by
/// a cell. It accepts **any [Cell]**, not just `ValueCell`, and gives the
/// builder a full [AsyncSnapshot] so the widget can distinguish "no data
/// yet" from "data" from "error" cleanly.
///
/// ### Why it is used
/// - **Async source display**: `Cell.fromFuture`, `Cell.fromStream`, and
///   `Cell.asyncMap` return plain `Cell`; the standard `CellBuilder`
///   cannot take them. This widget can.
/// - **`AsyncSnapshot` ergonomics**: the builder receives the same shape it
///   would from `StreamBuilder`, so switch-patterns on `hasData` /
///   `hasError` / connection state transfer directly.
/// - **Error surfacing**: failures of `Cell.fromFuture` become `hasError`
///   snapshots. See *Error pulses* below — `fromStream` and `asyncMap`
///   failures are not visible through this widget.
///
/// ### How it works
/// 1. **Seed**: on `initState`, the widget seeds `_snapshot` from
///    [initialSnapshot] if provided; otherwise from [snapshotForCell],
///    which serves every state-like operator's retained pulse (via
///    `Cell.latestPulse`) as well as [ValueCell]; otherwise from
///    `AsyncSnapshot<V>.nothing()`. See *Seed semantics* below.
/// 2. **Observe**: it opens one `Cell.observe<Pulse<Object?>>` link on
///    [cell] and forwards each pulse to `_onPulse`.
/// 3. **Decode**: `_onPulse` converts the pulse via [snapshotForPulse] and
///    assigns it to `_snapshot`. Data pulses produce data snapshots; error
///    pulses produce error snapshots; type-mismatched payloads produce
///    error snapshots.
/// 4. **Build-phase deferral**: pulses arriving during `persistentCallbacks`
///    or `midFrameMicrotasks` are queued and flushed in one post-frame
///    callback; only the most recent pending pulse is applied. Pulses
///    outside a build phase commit synchronously.
/// 5. **Cell swap**: if [cell] identity changes in `didUpdateWidget`, the
///    old egress is stopped, `_snapshot` is re-seeded, and a fresh egress
///    is bound.
/// 6. **Disposal**: the egress is stopped and pending pulses cleared.
///
/// ### Snapshot transitions
/// | Before first pulse | After a data pulse | After an error pulse |
/// |---|---|---|
/// | `ConnectionState.none` (`AsyncSnapshot.nothing()`) | `active`, `hasData == true` | `active`, `hasError == true` |
///
/// **`ConnectionState.done` is never reached.** No core operator emits a
/// completion pulse. `Cell.fromFuture` emits once and stays silent;
/// `Cell.fromStream` emits until the stream ends and then stays silent;
/// `Cell.asyncMap` emits per input and never completes. If the widget
/// needs completion detection, compose with a completion cell (see
/// `HowTo-CellAsyncBuilder.md`).
///
/// ### Design Note: `CellAsyncBuilder` vs. `CellValueBuilder`
/// | | `CellValueBuilder<V>` | `CellAsyncBuilder<V>` |
/// |---|---|---|
/// | Builder receives | `V?` | `AsyncSnapshot<V>` |
/// | Distinguishes loading / data / error | no (only data) | yes |
/// | Error pulses | reported via `FlutterError` when `emitErrors: true` | rendered as `hasError` snapshots |
/// | Typical source | derived / projection cells | async cells (`fromFuture`, `fromStream`, `asyncMap`) |
///
/// Pick `CellValueBuilder` for synchronous "latest value" rendering of a
/// non-`ValueCell` source. Pick `CellAsyncBuilder` when the builder must
/// branch on loading / data / error — that is, when the cell's history
/// matters, not just its current payload.
///
/// ### Error pulses
/// **Only `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on its
/// failure path.** `Cell.fromStream` and `Cell.asyncMap` do **not** emit
/// error pulses in the core package today: a stream error is silently
/// cancelled (or ignored), and an `asyncMap` mapper failure is dropped.
/// Consequently this widget produces `hasError == true` only for
/// `fromFuture` failures (and for type-mismatched data payloads, below).
/// A `CellAsyncBuilder` over an `asyncMap` that throws will keep the last
/// successful snapshot — the failure never reaches this widget. Callers who
/// need error visibility from `fromStream` / `asyncMap` must bridge those
/// sources through a custom cell that re-emits the failure as an `'error'`
/// pulse.
///
/// A **type-mismatched data payload** (a data pulse whose payload is not
/// assignable to `V`) is also surfaced as `hasError` — it is a caller bug,
/// not a transient source error. The per-source error-pulse behavior is
/// asserted in `test/error_pulse_sources_test.dart`.
///
/// ### Seed semantics (please read)
/// The default seed path uses [snapshotForCell] → [retainedPulseOf], which
/// reads the core package's retained pulse via `Cell.latestPulse`. A plain
/// async cell (`fromFuture`, `fromStream`, `asyncMap`, `derive`) that
/// **already emitted before** this widget subscribed therefore seeds that
/// value into the first frame — a completed `fromFuture` renders data
/// immediately instead of `nothing()`. A cell that has never emitted falls
/// back to `nothing()` until the next live pulse. Pass [initialSnapshot]
/// only to override the seed (cache hydration, or a snapshot the caller
/// already holds). See `test/seed_paths_test.dart` for the coverage.
///
/// ### Concurrent `asyncMap` caveat
/// When the source is `Cell.asyncMap` with `concurrency > 0` (or overlapping
/// `latestOnly` futures), this widget inherits the framework's
/// caveat: concurrent effect attribution is tracked separately and is not
/// yet verified end-to-end. The widget's own observation behavior is
/// correct; the caveat is about the source's replay fidelity. See the
/// `cell` core package for status.
///
/// ### Technical Details
/// - **One egress per element**: the widget owns exactly one observation
///   link; disposal stops it.
/// - **Coalesced flush**: build-phase pulses collapse into one post-frame
///   `setState`; only the last pending pulse is decoded, which is the right
///   semantics for a "latest value" view.
/// - **Type erasure at observation**: the subscription is typed
///   `Pulse<Object?>` so error and type-mismatch pulses can be received and
///   decoded; the type check happens inside [snapshotForPulse].
///
/// ### Example
/// ```dart
/// final user = Cell.fromFuture<User>(api.fetchUser());
///
/// CellAsyncBuilder<User>(
///   cell: user,
///   builder: (ctx, snapshot) => switch (snapshot) {
///     AsyncSnapshot(hasData: true) => ProfileView(snapshot.data!),
///     // Only failures of a `fromFuture` source produce hasError — see
///     // *Error pulses* above.
///     AsyncSnapshot(hasError: true) => ErrorView(snapshot.error!),
///     _ => const LoadingSpinner(),
///   },
/// );
/// ```
///
/// ### See Also:
/// - [snapshotForPulse] — the pulse-to-snapshot decoder.
/// - [snapshotForCell] — the seed probe used at subscription time.
/// - `CellValueBuilder` — the synchronous latest-value alternative.
/// - `Cell.fromFuture`, `Cell.fromStream`, `Cell.asyncMap` — the typical
///   sources this widget is built for.
/// - `AsyncSnapshot` — the Flutter snapshot type the builder receives.
class CellAsyncBuilder<V> extends StatefulWidget {
  /// Creates a builder bound to [cell].
  ///
  /// ### Parameters:
  /// * [cell]: **The Async Source.** Any [Cell] — typically a plain cell
  ///   produced by `Cell.fromFuture`, `Cell.fromStream`, or
  ///   `Cell.asyncMap`. Prefer `CellBuilder` when the source is a
  ///   [ValueCell].
  /// * [builder]: **The Render Callback.** Receives the current
  ///   [AsyncSnapshot] and is called on every pulse.
  /// * [initialSnapshot]: **Optional Seed Override.** When null, the widget
  ///   seeds from [snapshotForCell]; pass a snapshot here only to override
  ///   that (cache hydration, or to supply a retained value for a
  ///   non-`ValueCell` source — see class docs, *Seed semantics*).
  const CellAsyncBuilder({
    required this.cell,
    required this.builder,
    this.initialSnapshot,
    super.key,
  });

  /// The async-source cell.
  ///
  /// Accepts any [Cell]. For [ValueCell] sources, prefer `CellBuilder` —
  /// this widget is for the async operators that return plain `Cell`.
  final Cell cell;

  /// Renders the current snapshot. Called on every pulse.
  ///
  /// The snapshot carries `ConnectionState.active` once the first pulse has
  /// arrived, with either `hasData` or `hasError` set. See the class-level
  /// *Snapshot transitions* table.
  final Widget Function(BuildContext context, AsyncSnapshot<V> snapshot)
      builder;

  /// Optional initial snapshot. Defaults to `AsyncSnapshot<V>.nothing()`.
  ///
  /// Two use cases:
  /// 1. **Cache hydration** — pass
  ///    `AsyncSnapshot.withData(ConnectionState.active, cached)` to render
  ///    the cached value before the first pulse arrives.
  /// 2. **Seed override** — the default seed path already replays the
  ///    retained pulse of any state-like operator (`fromFuture`,
  ///    `fromStream`, `asyncMap`, `derive`) and [ValueCell]. Pass a snapshot
  ///    here only to replace that seed with a value the caller holds.
  ///
  /// When [initialSnapshot] is null, the widget seeds from
  /// [snapshotForCell], which serves the cell's retained pulse when one
  /// exists and returns `null` otherwise.
  final AsyncSnapshot<V>? initialSnapshot;

  @override
  State<CellAsyncBuilder<V>> createState() => _CellAsyncBuilderState<V>();
}

class _CellAsyncBuilderState<V> extends State<CellAsyncBuilder<V>> {
  late AsyncSnapshot<V> _snapshot;
  EgressHandle<Pulse<Object?>>? _egress;
  bool _disposed = false;
  bool _flushScheduled = false;
  final List<Pulse<Object?>> _pending = [];

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ??
        snapshotForCell<V>(widget.cell) ??
        AsyncSnapshot<V>.nothing();
    _bind();
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
    if (!mounted) return;
    if (!isCellBuildPhase) {
      setState(() => _apply(pulse));
      return;
    }
    // A pulse that arrives while this element is still initializing
    // (initState runs inside the first frame's build phase) takes the
    // same deferral path as any other build-phase pulse.
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
