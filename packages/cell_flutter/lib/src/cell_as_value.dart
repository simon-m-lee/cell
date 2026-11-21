// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

import 'pulse_delivery.dart';

/// The paired result of [CellAsValue.asValueCell]: a mirror cell and the
/// callback that releases it.
///
/// [MirroredCell] is the binding's **Mirror Handle**. It packages a fresh
/// [ValueCell] (the "mirror") with the `dispose` callback that stops the
/// egress backing it. The pairing is deliberate: mirroring a cell opens a
/// `Cell.observe` link, and that link is **not** closed automatically. The
/// handle makes the lifecycle obligation impossible to miss — you cannot
/// obtain a mirror without also receiving the way to tear it down.
///
/// ### Why it is used
/// - **Explicit lifetime**: a plain `ValueCell<V>` return would hide the
///   `EgressHandle`. The caller would have no handle to stop mirroring, and
///   the egress would leak when the mirror outlives the source or is created
///   in a `build`.
/// - **Record shape, zero boilerplate**: Dart record destructuring gives you
///   `final (:cell, :dispose) = source.asValueCell<int>();` for free — no
///   class, no allocation overhead beyond the mirror itself.
/// - **Non-optional contract**: because `dispose` is a required member of the
///   record, callers cannot accidentally discard it the way they could
///   ignore a returned `EgressHandle`.
///
/// ### Contract
/// - **`dispose` must be called** when the mirror is no longer needed. Failing
///   to do so leaves the underlying `Cell.observe` link open: the mirror
///   continues to receive pulses (and hold them in its box) for as long as
///   the source lives, and the observation is never reclaimed.
/// - **`dispose` is idempotent** with respect to the egress it stops:
///   `EgressHandle.stop` is safe to call more than once.
/// - **The mirror outlives nothing else** — it does not need to be
///   invalidated separately. Once `dispose` has been called the mirror
///   simply stops updating; it does not become invalidated and its current
///   value remains readable.
/// - **The mirror is a one-way copy.** It is an ordinary [ValueCell]:
///   writes to `mirror.cell.value` do **not** reach the source, and the
///   next source pulse overwrites them. "Mirror" describes the read
///   direction only — the source is the single writer.
///
/// ### Parameters (record fields)
/// * `cell`: **The Mirror.** A fresh [ValueCell] that is seeded from the
///   source's current value (see [CellAsValue.asValueCell]) and updated on
///   every subsequent pulse from the source.
/// * `dispose`: **The Release Callback.** Stops the egress that keeps the
///   mirror in sync with the source. Call exactly once when the mirror is
///   no longer needed; safe to call more than once.
///
/// ### See Also:
/// - [CellAsValue.asValueCell] — the method that produces this handle.
/// - `CellValueBuilder` — the widget-layer alternative that Flutter's own
///   state lifecycle manages.
/// - `EgressHandle` — the underlying primitive `dispose` wraps.
typedef MirroredCell<V> = ({
  ValueCell<V> cell,
  void Function() dispose,
});

/// An extension that mirrors any [Cell] into a fresh [ValueCell].
///
/// [CellAsValue] is the binding's **Mirror Factory**. Widgets that require a
/// [ValueCell] — `CellBuilder`, `CellSelector` — cannot take a plain `Cell`
/// (`Cell.derive`, `Cell.synthesis`, `Cell.switchMap`, async sources,
/// `cell_tissue` collections). This extension bridges that gap: it opens a
/// `Cell.observe` link on the source and re-emits the source's payloads into
/// a brand-new [ValueCell] whose `value` can be read synchronously.
///
/// ### Why it is used
/// - **Bridge to `ValueCell`-only widgets**: obtain a [ValueCell] from any
///   [Cell] so `CellBuilder` / `CellSelector` can be used without changing
///   their `ValueCell` requirement.
/// - **Service-layer mirrors**: share a mirrored value across components
///   that outlive any single widget, without routing through Flutter's
///   lifecycle. The returned [MirroredCell] gives you explicit ownership of
///   the mirror's lifetime.
///
/// ### How it works
/// 1. **Create the mirror**: a fresh [ValueCell] is created and seeded from
///    the source's retained pulse (any state-like operator that already
///    emitted, plus [ValueCell]'s current value), or from the caller's
///    `initial` if no visible value is available (see *Seed semantics*).
/// 2. **Observe the source**: a `Cell.observe` link is opened on the source
///    and forwards each data pulse into the mirror's `value` setter, which
///    broadcasts to the mirror's own observers.
/// 3. **Return the handle**: the mirror and the egress-stop callback are
///    paired in a [MirroredCell] record.
///
/// ### Design Note: why a record and not just the `ValueCell`
/// Returning a bare `ValueCell<V>` would be a shorter signature but a worse
/// contract. The mirror's backing egress is not observable from the
/// `ValueCell` interface, so a caller who wanted to stop mirroring would
/// have no way to do so. The [MirroredCell] record makes the disposal
/// obligation part of the return type — you cannot obtain a mirror without
/// receiving the way to release it.
///
/// ### Seed semantics (please read)
/// The mirror is seeded through `retainedPulseOf`, which reads the core
/// package's retained pulse via `Cell.latestPulse` (covering `fromFuture`,
/// `fromStream`, `asyncMap`, `derive`) and serves a [ValueCell]'s current
/// `value` as a fallback. A plain async cell that **already emitted
/// before** the mirror was created is therefore seeded from its retained
/// value, not from `initial` — a completed `Cell.fromFuture` mirrors `42`
/// on the first read. `initial` is the fallback when the source has never
/// emitted a visible data pulse. See `test/seed_paths_test.dart` for the
/// coverage.
///
/// ### Error pulses
/// Error pulses from the source are **silently skipped**. Mirroring is a
/// value-display operation; errors have no place in a `ValueCell`'s value
/// slot. If you need to observe errors, subscribe to the source directly
/// (via `Cell.observe`, `CellListener`, or `asStream(emitErrors: true)`).
///
/// ### Type-mismatch payloads
/// A data pulse whose payload is not assignable to `V` is reported through
/// `Zone.current.handleUncaughtError` with a `StateError`. This differs from
/// the other bindings, which use `FlutterError.reportError` — the mirror is
/// widget-independent, so it cannot assume a Flutter error reporter is
/// installed. A type-mismatch is a caller bug: the source emits payloads of
/// a type the mirror's `V` cannot hold.
///
/// ### Concurrent `asyncMap` caveat
/// If the source is `Cell.asyncMap` with `concurrency > 0` (or overlapping
/// `latestOnly` futures), the mirror inherits the framework's
/// caveat: concurrent effect attribution is tracked separately and is not
/// yet verified end-to-end. The mirror's observation is correct; the caveat
/// is about the source's replay fidelity. See the `cell` core package for
/// status.
///
/// ### Example
/// ```dart
/// class MyService {
///   late final MirroredCell<int> _mirror;
///
///   MyService(Cell source) {
///     _mirror = source.asValueCell<int>(initial: 0);
///   }
///
///   void dispose() => _mirror.dispose();
///
///   ValueCell<int> get mirror => _mirror.cell;
/// }
/// ```
///
/// ### See Also:
/// - [MirroredCell] — the handle this extension returns.
/// - [CellAsValue.asValueCell] — the single method on this extension.
/// - `CellValueBuilder` — the widget-layer alternative that manages a
///   mirror's lifetime through Flutter's own state lifecycle.
/// - `asStream` — the equivalent bridge from [Cell] to `Stream`.
/// - `test/seed_paths_test.dart` — the seed-behavior coverage.
extension CellAsValue on Cell {
  /// Mirrors this cell into a fresh [ValueCell] and returns the paired
  /// handle.
  ///
  /// The returned [MirroredCell] contains both the mirror (a [ValueCell]
  /// seeded from this cell's currently visible value, or from [initial]) and
  /// a `dispose` callback that **must** be called when the mirror is no
  /// longer needed — otherwise the backing egress leaks.
  ///
  /// ### When to use
  /// **Prefer `CellValueBuilder` inside widgets** — it manages the mirror's
  /// lifecycle automatically. Use [asValueCell] when the mirror must outlive
  /// a widget (for example, shared across a service layer), or when you
  /// need a synchronous, `ValueCell`-typed value that `CellBuilder` /
  /// `CellSelector` can consume.
  ///
  /// ### How it works
  /// 1. A fresh [ValueCell] is created and seeded via the same priority
  ///    rules documented under *Seed semantics* on the extension: the
  ///    retained pulse if it is a data pulse assignable to `V`, otherwise
  ///    [initial].
  /// 2. A `Cell.observe` link is opened on this cell; each data pulse
  ///    assigns `pulse.payload` to the mirror.
  /// 3. The mirror and the egress-stop callback are packaged as a
  ///    [MirroredCell] record.
  ///
  /// ### Disposal contract
  /// Calling the returned `dispose` callback is **mandatory**. Failure to
  /// call it leaves the egress attached to this cell, receiving (and holding)
  /// every pulse for the mirror's remaining lifetime. `dispose` is safe to
  /// call more than once.
  ///
  /// ### The mirror is a one-way copy
  /// The returned [ValueCell] is writable like any other, but writes to it
  /// do **not** reach the source and are overwritten by the next source
  /// pulse. Mutate the source cell when the value must change; treat the
  /// mirror as read-only in practice.
  ///
  /// ### Error pulses
  /// Error pulses are **silently skipped**; the mirror's value stays at its
  /// last data value. To observe errors, use `CellValueBuilder(emitErrors: true)`,
  /// `CellListener`, or `asStream(emitErrors: true)` on the source.
  ///
  /// ### Technical Details
  /// - **One egress per mirror**: each call to `asValueCell` opens a new
  ///   observation link. Two mirrors from the same source are two egresses.
  /// - **Type erasure at observation**: the link is typed
  ///   `Pulse<Object?>` so error and type-mismatch pulses can be received;
  ///   the payload is narrowed with `is V` / `null is V` inside the effect.
  /// - **Payload type-mismatch**: reported via `Zone.current.handleUncaughtError`
  ///   with a `StateError` (see the extension docs for why this differs from
  ///   the other bindings).
  ///
  /// ### Concurrent `asyncMap` caveat
  /// If the source is `Cell.asyncMap` with `concurrency > 0`, the mirror
  /// inherits the framework's caveat. The mirror's observation is
  /// correct; the caveat is about the source's replay fidelity.
  ///
  /// ### Parameters:
  /// * [initial]: **The Seed Fallback.** Used when no retained data pulse is
  ///   assignable to `V` on the source (the source has never emitted, the
  ///   retained pulse is an error, or its payload is not a `V`). Defaults to
  ///   `null`.
  ///
  /// ### Returns:
  /// A [MirroredCell] record: `cell` is the fresh [ValueCell]; `dispose` is
  /// the egress-stop callback.
  ///
  /// ### Example
  /// ```dart
  /// final source = Cell.derive<Pulse<int>, Pulse<int>>(
  ///   source: counter.cell,
  ///   project: (p) => Pulse((p.payload ?? 0) * 2),
  /// );
  /// final mirrored = source.asValueCell<int>(initial: 0);
  /// try {
  ///   // ... use mirrored.cell with CellBuilder ...
  /// } finally {
  ///   mirrored.dispose(); // required — releases the egress
  /// }
  /// ```
  ///
  /// ### See Also:
  /// - [MirroredCell] — the return type.
  /// - `CellValueBuilder` — the widget-layer alternative (no manual
  ///   disposal).
  /// - `CellBuilder` / `CellSelector` — the widgets that need a
  ///   [ValueCell].
  MirroredCell<V> asValueCell<V>({V? initial}) {
    final mirror = ValueCell<V>(initial: seedFromRetained(this, initial));
    final egress = Cell.observe<Pulse<Object?>>(
      source: this,
      effect: (pulse) {
        if (pulse.type == 'error') return;
        final payload = pulse.payload;
        if (payload == null && null is V) {
          mirror.value = null;
        } else if (payload is V) {
          mirror.value = payload;
        } else {
          Zone.current.handleUncaughtError(
            StateError(
              'asValueCell<$V>: pulse payload is ${payload.runtimeType}, '
              'not $V.',
            ),
            StackTrace.current,
          );
        }
      },
      initiallyStarted: true,
    );
    return (cell: mirror, dispose: egress.stop);
  }
}
