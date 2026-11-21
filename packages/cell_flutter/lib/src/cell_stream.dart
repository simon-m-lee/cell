// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

import 'pulse_delivery.dart';

/// Bridges a [Cell] to a Dart `Stream<V?>`.
///
/// [CellAsStream] is the binding's **Egress Bridge**: the counterpart of
/// `Cell.ingress` at the widget/Dart-interop boundary. Where a cell is the
/// reactive graph's internal signal carrier, a `Stream` is the lingua franca
/// of most Dart APIs (isolate channels, package SDKs, test utilities). This
/// extension converts one to the other without exposing the cell's egress
/// machinery to the caller.
///
/// ### Why it is used
/// - **Dart interop**: hand a cell's values to a `Stream`-consuming API
///   (`StreamTransformer`, `StreamBuilder`, an isolate port, a third-party
///   SDK).
/// - **Testing**: `await for (final v in cell.asStream<int>())` gives a
///   pump-free way to observe pulses in widget tests and unit tests.
/// - **Composition**: `stream.where`, `stream.map`, `stream.first` are all
///   available once the cell is bridged — useful for one-shot adapters
///   outside the cell graph.
///
/// ### How it works
/// 1. A single-subscription [StreamController] is created; the underlying
///    `Cell.observe` link is **not** opened until the first `listen`
///    (`onListen`). Merely calling `asStream()` does not subscribe to [Cell].
/// 2. On `onListen`, the cell is observed and every pulse is forwarded into
///    the controller — errors go through `addError`, data through `add`.
/// 3. If the observed cell does **not** emit synchronously upon subscription,
///    the bridge falls back to [retainedPulseOf] for a one-shot seed — this
///    serves every state-like operator's retained pulse (`fromFuture`,
///    `fromStream`, `asyncMap`, `derive`) as well as a [ValueCell]'s current
///    value (see *Seed semantics* below).
/// 4. On `onCancel`, the egress is stopped. The controller is intentionally
///    **not** closed from `onCancel` — `close()` waits on `onCancel`, so
///    calling it from there deadlocks the `done` future.
///
/// ### Design Note: sync vs. async delivery
/// [sync] defaults to `true`. A sync stream delivers each value in the same
/// microtask that the pulse fires in — useful for tests, where a synchronous
/// subscription avoids `pump()`-style waits. Production interop with
/// `Stream`s that assume asynchronous delivery should pass `sync: false`.
///
/// ### Lifecycle
/// - **Single-subscription**: the controller is not broadcast. Calling
///   `stream.listen` twice throws `StateError`. For broadcast semantics,
///   wrap the returned stream with `.asBroadcastStream()` — the wrapper
///   creates and tears down its own single subscription.
/// - **Lazy**: dropping the stream without listening does not subscribe to
///   the cell.
/// - **Cancellation stops the egress**: after `onCancel`, no further pulses
///   are forwarded.
/// - **The stream never completes.** The controller is deliberately never
///   closed (see *How it works*), so `await for`, `drain`, and `toList`
///   hang forever on it. Use `listen` with a manual `cancel`, `take(...)`
///   with a completing terminal, or `timeout` — do not await completion.
/// - **Synchronous error delivery**: with [sync] `= true` (default), a
///   seed that turns out to be an error pulse is delivered synchronously
///   inside `listen`; a caller that has not registered `onError` before
///   the first microtask will see an unhandled zone error. Register
///   `onError`, or pass `sync: false`.
///
/// ### Seed semantics (please read)
/// The lazy seed is sourced from [retainedPulseOf], which reads the core
/// package's retained pulse via `Cell.latestPulse` and serves [ValueCell]
/// as a fallback. A plain async cell
/// (`Cell.fromFuture` / `Cell.fromStream` / `Cell.asyncMap` /
/// `Cell.derive`) that **already emitted before** the stream was listened
/// to is replayed as the first event. A cell that has never emitted
/// produces no seed — the stream waits for the next live pulse. See
/// `test/seed_paths_test.dart` for the coverage.
///
/// ### Error pulses
/// **Only `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on its
/// failure path.** `Cell.fromStream` and `Cell.asyncMap` do **not** emit
/// error pulses in the core package today, so their failures never reach
/// this bridge. With [emitErrors] `= true` (default), a received error
/// pulse becomes `Stream.addError`; with `emitErrors` `= false` it is
/// silently dropped. A type-mismatched data payload is **always** surfaced
/// as `Stream.addError` (a `StateError`), regardless of [emitErrors] — it
/// is a caller bug, not a transient source error. The per-source behavior
/// is asserted in `test/error_pulse_sources_test.dart`.
///
/// ### Concurrent `asyncMap` caveat
/// Sources produced by `Cell.asyncMap` with `concurrency > 0` (or overlapping
/// `latestOnly` futures) inherit the framework's caveat:
/// concurrent effect attribution is tracked separately and is not yet
/// verified end-to-end. The bridge itself is correct; the caveat concerns the
/// source's replay fidelity. See the `cell` core package for status.
///
/// ### Example: seed a `ValueCell`'s current value
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
/// final sub = counter.cell.asStream<int>().listen((v) => print('seed $v'));
/// // The seed serves `ValueCell` sources: the listener receives 0 on the
/// // first microtask after listen, then each later pulse.
/// counter.update(1); // → 1
/// await sub.cancel(); // stops the internal egress
/// ```
///
/// A plain cell (`fromFuture`, `fromStream`, `asyncMap`, `derive`) that
/// emitted before `listen` is replayed as the first event — see *Seed
/// semantics*.
///
/// ### Parameters:
/// * [sync]: **Delivery Mode.** `true` (default) delivers in the same
///   microtask as the pulse; `false` delivers asynchronously.
/// * [emitErrors]: **Error Forwarding.** When `true` (default), error
///   pulses become `Stream.addError`. Type-mismatch errors are always
///   forwarded regardless of this flag.
///
/// ### Returns:
/// A single-subscription `Stream<V?>` that forwards the cell's payloads.
///
/// ### See Also:
/// - [CellAsValue] — to mirror a cell into a [ValueCell] instead of a stream.
/// - `CellAsyncBuilder` — the snapshot-style widget form of the same idea.
/// - `Cell.ingress` — the reverse bridge (Stream → Cell is not provided;
///   use `Cell.fromStream`).
/// - [retainedPulseOf] — the lazy-seed probe.
/// - `test/seed_paths_test.dart` — the seed-behavior coverage.
/// - **Example**: see `test/` for pump-free stream-bridge usage in widget
///   tests.
extension CellAsStream on Cell {
  /// Bridges this cell to a `Stream<V?>`.
  ///
  /// Emits each pulse's payload. Error pulses become `Stream.addError` when
  /// [emitErrors] is `true` (default). The internal egress is opened on
  /// `onListen` and stopped on `onCancel`. See the extension-level docs for
  /// sync/async delivery, lifecycle, seeding, and error semantics.
  ///
  /// **The stream never completes** — do not `await for` or `drain` it.
  /// Cancel the subscription instead.
  Stream<V?> asStream<V>({bool sync = true, bool emitErrors = true}) {
    late final StreamController<V?> controller;
    EgressHandle<Pulse<Object?>>? egress;

    controller = StreamController<V?>(
      sync: sync,
      onListen: () {
        var sawLive = false;
        egress = Cell.observe<Pulse<Object?>>(
          source: this,
          effect: (pulse) {
            sawLive = true;
            if (controller.isClosed) return;
            _addPulse<V>(controller, pulse, emitErrors);
          },
          initiallyStarted: true,
        );
        if (!sawLive) {
          final latest = retainedPulseOf(this);
          if (latest != null && !controller.isClosed) {
            _addPulse<V>(controller, latest, emitErrors);
          }
        }
      },
      onCancel: () {
        egress?.stop();
        egress = null;
      },
    );
    return controller.stream;
  }
}

/// Forwards a single [Pulse] into [controller], typed as `V?`.
///
/// **Error policy:**
/// - `pulse.type == 'error'` → `controller.addError(payload ?? StateError(...))`
///   when [emitErrors] is `true`; otherwise dropped.
/// - Data payload assignable to `V` → `controller.add(payload)`.
/// - `null` payload with `null is V` → `controller.add(null)`.
/// - Data payload **not** assignable to `V` → `controller.addError(StateError)`
///   unconditionally; this is a caller bug and should not be swallowed by
///   [emitErrors].
///
/// ### Technical Details
/// - **Type-aware**: distinguishes a nullable `V` from a non-nullable one
///   using `null is V`, so `asStream<int?>` accepts `null` data and
///   `asStream<int>` rejects it with an error.
/// - **Controller-safety**: callers must guard `controller.isClosed` before
///   calling (the extension does).
///
/// See also:
/// - [CellAsStream.asStream] — the public entry point.
/// - [retainedPulseOf] — the seed probe used by `onListen`.
void _addPulse<V>(
  StreamController<V?> controller,
  Pulse<Object?> pulse,
  bool emitErrors,
) {
  if (pulse.type == 'error') {
    if (emitErrors) {
      controller.addError(
        pulse.payload ?? StateError('Unknown error pulse'),
      );
    }
    return;
  }
  final payload = pulse.payload;
  if (payload == null && null is V) {
    controller.add(null);
  } else if (payload is V) {
    controller.add(payload);
  } else {
    controller.addError(
      StateError(
        'asStream<$V>: pulse payload is ${payload.runtimeType}, not $V?.',
      ),
    );
  }
}
