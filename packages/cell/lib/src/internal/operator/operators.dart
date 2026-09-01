// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// operator - switchMap
// ─────────────────────────────────────────────────────────────

/// Switches to a new dynamic reactive source.
Cell _switchMap<S, T>(
    Cell source,
    Cell Function(S value) mapper, {
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
    }) {
  // State for the current inner cell.
  final state = _SwitchMapState<S,T>(
    source: source,
    mapper: mapper,
    currentInner: null,
  );

  // Create a custom receptor that handles both source pulses (to switch) and
  // inner pulses (to forward).
  final receptor = _Receptor(
    reaction: (Pulse pulse, Cell cell, {dynamic user}) {
      final sourcePulse = pulse.source == source;
      if (sourcePulse) {
        // Source emitted a new value – switch the inner cell.
        final payload = pulse.payload as S?;
        if (payload == null) return null; // Ignore null payloads.

        final newInner = state.mapper(payload);
        // if (newInner == null) return null;

        // Unlink the old inner cell if it exists.
        if (state.currentInner != null) {
          state.currentInner!._nucleus.synapses.unlink(
            state.currentInner!,
            downstreamCell: cell,
          );
        }

        // Link the new inner cell to the output cell.
        newInner._nucleus.synapses.link(newInner, downstreamCell: cell);
        state.currentInner = newInner;

        // Do not forward the source pulse itself.
        return null;
      } else {
        // Pulse comes from the current inner cell – forward it.
        return pulse;
      }
    },
  );

  // Create the output cell.
  final outputCell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: receptor,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  // Link the source to the output cell so source pulses reach our receptor.
  source._nucleus.synapses.link(source, downstreamCell: outputCell);

  return outputCell;
}

class _SwitchMapState<S, T> {
  final Cell source;
  final Cell Function(S value) mapper;
  Cell? currentInner;

  _SwitchMapState({
    required this.source,
    required this.mapper,
    this.currentInner,
  });
}

// ─────────────────────────────────────────────────────────────
// operator - distinct
// ─────────────────────────────────────────────────────────────

/// Suppresses consecutive duplicate payloads (classic `distinctUntilChanged`).
///
/// [equals] defaults to `==`. Provide a custom comparator when needed.
Cell _distinct(
    Cell source, {
      bool Function(dynamic previous, dynamic next)? equals,
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
    }) {
  final state = _DistinctState();
  final eq = equals ?? (a, b) => a == b;

  final receptor = _Receptor(
    reaction: (pulse, cell, {dynamic user}) {
      if (pulse.source != source) return null;

      final next = pulse.payload;
      if (state.hasValue && eq(state.last, next)) {
        return null; // duplicate – drop
      }
      state
        ..hasValue = true
        ..last = next;
      return pulse;
    },
  );

  final outputCell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: receptor,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  source._nucleus.synapses.link(source, downstreamCell: outputCell);
  return outputCell;
}

class _DistinctState {
  bool hasValue = false;
  dynamic last;
}

// ─────────────────────────────────────────────────────────────
// operator - ingress
// ─────────────────────────────────────────────────────────────

IngressHandle<I> _ingress<I>({

  Pulse<I?>? Function(Cell host, Pulse<I> input)? refine,

  EphemeralPolicy? ephemeralPolicy,
  Cell? bind,
  Context context = Context.system,
  Receptor receptor = Receptor.passThrough,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,

  bool forceLock = false
}) {
  receptor = refine != null
      ? _Receptor(reaction: (pulse, cell, {dynamic user}) => refine(cell, pulse as Pulse<I>))
      : receptor;
  final cell = Cell.governed(bind: bind, ephemeralPolicy: ephemeralPolicy,
      context: context, testRule: testRule, synapses: synapses, receptor: receptor);
  bool emit(I input) => cell._nucleus.receptor.call(Pulse<I>(input, source: cell)) != null;

  Future<bool> emitAsync(I input)  async {
    final lock = cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() => emit(input)).then((value) => value);
    }
    return Future<bool>(() => emit(input)).then((value) => value);
  }

  Future<void> ingest(Pulse<I> pulse, {bool serializedCompletion = true}) async {
    final receptor = cell._nucleus.receptor;
    return await receptor.async.call(pulse as PulseBase<I>, serializedCompletion: serializedCompletion);
  }

  return (cell: cell, emit: emit, emitAsync: emitAsync, ingest: ingest);
}

// ─────────────────────────────────────────────────────────────
// operator - observe
// ─────────────────────────────────────────────────────────────

EgressHandle<P> _observe<P extends Pulse>({
  required Cell bind,
  required void Function(P pulse) effect,
  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  TestCell testRule = TestCell.allowAll,

  bool initiallyStarted = true,
  bool forceLock = false
}) {

  final cancel = Box<bool>(!initiallyStarted);
  bool start() => cancel.value = false;
  bool stop() => cancel.value = true;
  final receptor = _Receptor(reaction: (pulse, cell, {dynamic user}) {
    if (cancel.value == false) {
      effect(pulse as P);
    }
    return null;
  });
  final cell = Cell.governed(bind: bind, context: context, receptor: receptor, forceLock: forceLock,
      ephemeralPolicy: ephemeralPolicy, testRule: testRule, synapses: Synapses.disabled);
  return (cell: cell, start: start, stop: stop);
}

// ─────────────────────────────────────────────────────────────
// operator - fromStream
// ─────────────────────────────────────────────────────────────

/// Creates a cell that emits the values of a Dart [Stream].
///
/// The subscription is cancelled automatically when the cell is invalidated.
Cell _fromStream<T>(
    Stream<T> stream, {
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
      bool cancelOnError = false,
    }) {
  late final Cell cell;
  StreamSubscription<T>? sub;

  void cancelSubscription() {
    final current = sub;
    sub = null;
    current?.cancel();
  }

  final lifecycle = EphemeralPolicy<Cell>(
    duration: ephemeralPolicy?.duration,
    eventLimit: ephemeralPolicy?.eventLimit,
    onEvent: (object, {required Cell cell, required policy, arguments, user}) {
      if (ephemeralPolicy == null) return (events: 0);
      return (events: policy.events + 1);
    },
    onInvalidate: (nucleus) {
      cancelSubscription();
      return true;
    },
  );

  cell = Cell.governed(
    ephemeralPolicy: lifecycle,
    context: context,
    receptor: Receptor.passThrough,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  final hostRef = WeakReference(cell);

  sub = stream.listen(
    (value) {
      final host = hostRef.target;
      if (host == null || host.isInvalidated) {
        cancelSubscription();
        return;
      }
      host._nucleus.receptor.call(
        Pulse<T>.governed(payload: value, source: host),
      );
      // passThrough is not governed, so drive the lifecycle policy here.
      lifecycle(value, cell: host);
      final limit = lifecycle.eventLimit;
      if (host.isInvalidated ||
          (limit != null && lifecycle.events >= limit)) {
        cancelSubscription();
      }
    },
    onError: (Object error, StackTrace st) {
      if (cancelOnError) {
        cancelSubscription();
      }
    },
    onDone: cancelSubscription,
    cancelOnError: cancelOnError,
  );

  Finalizer<void Function()>(
    (cancel) => cancel(),
  ).attach(cell, cancelSubscription, detach: cell);

  return cell;
}

// ─────────────────────────────────────────────────────────────
// operator - fromFuture
// ─────────────────────────────────────────────────────────────

/// Creates a cell that emits the result of a [Future] exactly once.
Cell _fromFuture<T>(
    Future<T> future, {
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
    }) {
  final cell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: Receptor.passThrough,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  future.then((value) {
    if (!cell.isInvalidated) {
      cell._nucleus.receptor.call(
        Pulse<T>.governed(payload: value, source: cell),
      );
    }
  }, onError: (Object error, StackTrace stackTrace) {
    if (!cell.isInvalidated) {
      cell._nucleus.receptor.call(
        Pulse<Object>.governed(
          payload: error,
          type: 'error',
          source: cell,
        ),
      );
    }
  });

  return cell;
}

// ─────────────────────────────────────────────────────────────
// Multi-lock acquisition (reusable)
// ─────────────────────────────────────────────────────────────

/// Acquires [locks] in the given order, runs [body], then releases them
/// in reverse order (LIFO unwind of nested `synchronized` sections).
///
/// ### When to use
/// Any time several [Lock]s must be held together without deadlock risk.
/// Callers are responsible for sorting [locks] deterministically first.
///
/// ### How it works
/// Builds a nest of `lock.synchronized(...)` calls. The innermost
/// callback is [body]. When [body] finishes (success or error) the
/// nested sections unwind and every lock is released.
///
/// ### Non‑obvious
/// - `null` entries in [locks] are skipped (cells without a lock).
/// - An empty list runs [body] immediately with no locking.
/// - Exceptions from [body] propagate after all locks are released.
/// - Reentrant [Lock]s are safe – the same isolate may re-enter.
Future<T> withLocks<T>(
    Iterable<Lock?> locks,
    Future<T> Function() body,
    ) {
  final ordered = locks.whereType<Lock>().toList(growable: false);
  return _withLocksAt(ordered, 0, body);
}

Future<T> _withLocksAt<T>(
    List<Lock> locks,
    int index,
    Future<T> Function() body,
    ) {
  if (index >= locks.length) {
    return body();
  }
  return locks[index].synchronized(
        () => _withLocksAt(locks, index + 1, body),
  );
}

/// Convenience: acquire the locks of [cells] in a deterministic order.
///
/// [order] sorts a *copy* of [cells] before locks are read. Default is
/// `hashCode` ascending (deadlock-free for any participant set).
Future<T> withCellLocks<T>(
    Iterable<Cell> cells,
    Future<T> Function() body, {
      int Function(Cell a, Cell b)? order,
    }) {
  final sorted = List<Cell>.from(cells);
  sorted.sort(order ?? (a, b) => a.hashCode.compareTo(b.hashCode));

  final locks = sorted.map((c) => c._nucleus.lock);
  return withLocks(locks, body);
}