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
/// Consumes the result of a fire-and-forget link.
///
/// Operator pipelines are synchronous reactors, so their bridge links
/// assume synchronous [TestCell] rules. When a rule is explicitly async
/// the returned [Future] is still driven to completion: a rejected gate
/// is routed to the originating pulse's fail path (when a pulse is in
/// scope — construction-time links have none and are contained), and a
/// declined gate simply leaves the connection unestablished.
void _guardLink(FutureOr<bool> result, [PulseBase? pulse]) {
  if (result is! Future<bool>) return;
  unawaited(result.then((_) {}, onError: (Object e, StackTrace st) {
    if (pulse != null) {
      pulse._fail(e, stackTrace: st);
    }
    // Construction-time links have no pulse to fail; the error is consumed
    // so it does not become an unhandled zone error.
  }));
}

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
  final state = _SwitchMapState<S, T>(
    source: source,
    mapper: mapper,
    currentInner: null,
  );

  late final Cell outputCell;

  // Wrap the caller's policy (if any) with an invalidation hook that
  // unlinks the current inner cell. Without it, the inner's synapse keeps
  // a strong reference to the invalidated output — the inner keeps calling
  // its (dead) receptor and the output cell and its closure can never be
  // collected.
  final lifecycle = EphemeralPolicy<Cell>(
    duration: ephemeralPolicy?.duration,
    eventLimit: ephemeralPolicy?.eventLimit,
    onEvent: (object, {required Cell cell, required policy, arguments, user}) {
      // Tick the caller's policy so its own onEvent/limit semantics are
      // preserved, then mirror ITS counter — including a reset. Counting
      // the wrapper independently would discard the documented
      // "return (events: 0) to extend the TTL window" pattern.
      ephemeralPolicy?.call(object, cell: cell, arguments: arguments);
      return (events: ephemeralPolicy?.events ?? policy.events + 1);
    },
    onInvalidate: (nucleus) {
      // Delegate the reclamation decision to the caller's hook; only an
      // accepted invalidation tears the inner link down.
      // The caller's policy may already have reclaimed itself through its
      // own quota (the wrapper delegates  to it); an already
      // invalidated caller means the reclamation is accepted.
      final accepted = ephemeralPolicy == null ||
          ephemeralPolicy.isInvalidated ||
          ephemeralPolicy.invalidate(nucleus.cell);
      if (accepted) {
        final inner = state.currentInner;
        if (inner != null) {
          inner._nucleus.synapses.unlink(inner, downstreamCell: outputCell);
          state.currentInner = null;
        }
      }
      return accepted;
    },
  );

  // Create a custom receptor that handles both source pulses (to switch) and
  // inner pulses (to forward).
  final receptor = _Receptor(
    reaction: (Pulse pulse, Cell cell, {dynamic user}) {
      // Discriminate by the pulse's immediate source cell identity, not by
      // `pulse.source == source`: state cells and derived cells emit pulses
      // without a source stamp, so the old check misread their source
      // pulses as inner pulses and forwarded them.
      final inner = state.currentInner;
      if (inner != null && pulse.source == inner) {
        // Pulse comes from the current inner cell – forward it.
        return pulse;
      }
      // Source pulse – switch the inner cell.
      {
        final rawPayload = pulse.payload;
        // Drop null payloads and payloads of an unexpected runtime type.
        // A cast (`as S?`) would throw for mismatched types and tear down
        // the whole pulse wave; a switch operator should simply ignore
        // stimuli it cannot switch on.
        if (rawPayload == null || rawPayload is! S) return null;
        final payload = rawPayload;

        final newInner = state.mapper(payload);
        // if (newInner == null) return null;

        // Bump the generation so older async links can never resurrect
        // themselves as the active inner after this switch.
        final generation = ++state.switchGeneration;

        // Unlink the old inner cell if it exists.
        if (state.currentInner != null) {
          state.currentInner!._nucleus.synapses.unlink(
            state.currentInner!,
            downstreamCell: cell,
          );
          state.currentInner = null;
        }

        // Link the new inner cell to the output cell. A declined gate
        // (sync or async false) must NOT leave a rejected inner looking
        // active: `currentInner` is set only for accepted links, and an
        // async acceptance is dropped if a newer switch started first.
        final linkResult =
            newInner._nucleus.synapses.link(newInner, downstreamCell: cell);
        if (linkResult is Future<bool>) {
          unawaited(linkResult.then((accepted) {
            if (accepted && state.switchGeneration == generation) {
              state.currentInner = newInner;
            }
          }, onError: (Object e, StackTrace st) {
            (pulse as PulseBase)._fail(e, stackTrace: st);
          }));
        } else if (linkResult == true) {
          state.currentInner = newInner;
        }

        // Do not forward the source pulse itself.
        return null;
      }
    },
  );

  // Create the output cell.
  outputCell = Cell.governed(
    ephemeralPolicy: lifecycle,
    context: context,
    receptor: receptor,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  // Link the source to the output cell so source pulses reach our receptor.
  // Construction-time links have no pulse to fail; an async gate result is
  // driven to completion with errors contained (see _guardLink).
  _guardLink(source._nucleus.synapses.link(source, downstreamCell: outputCell));

  return outputCell;
}

class _SwitchMapState<S, T> {
  final Cell source;
  final Cell Function(S value) mapper;
  Cell? currentInner;
  /// Monotonic switch counter: an async link for an older switch must not
  /// become the active inner after a newer switch has started.
  int switchGeneration = 0;

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
      // This bridge is bound to exactly one source, so every pulse that
      // arrives here came from it. A `pulse.source == source` guard is
      // wrong: state cells and derived cells emit pulses without a source
      // stamp, which the guard silently dropped.
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

  // Construction-time link (see _guardLink).
  _guardLink(source._nucleus.synapses.link(source, downstreamCell: outputCell));
  return outputCell;
}

class _DistinctState {
  bool hasValue = false;
  dynamic last;
}

// ─────────────────────────────────────────────────────────────
// operator - ingress
// ─────────────────────────────────────────────────────────────

IngressHandle<I> _ingress<I>(
    {Pulse<I?>? Function(Cell host, Pulse<I> input)? refine,
    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false}) {
  receptor = refine != null
      ? _Receptor(
          reaction: (pulse, cell, {dynamic user}) =>
              refine(cell, pulse as Pulse<I>))
      : receptor;
  final cell = Cell.governed(
      bind: bind,
      ephemeralPolicy: ephemeralPolicy,
      context: context,
      testRule: testRule,
      synapses: synapses,
      receptor: receptor);

  bool emit(I input) {
    final nucleus = cell._nucleus;
    final receptor = nucleus.receptor;
    final pulse = _FastPulse<I>(payload: input, source: cell);

    // Fast path: ungoverned ingress with the default pass-through rule and
    // no pipeline stages. Skipping ReceptorBase.call here only elides the
    // no-ops it would perform (checker registration, an allowAll validate,
    // policy checks, progress) — the pulse still travels through the
    // cell's synapses exactly as before.
    if (!nucleus.isGoverned &&
        identical(nucleus.testRule, TestCell.allowAll) &&
        receptor is _Receptor &&
        receptor._instruction == null &&
        receptor._preProcess == null &&
        receptor._postProcess == null &&
        receptor._reaction == null) {
      final synapses = nucleus.synapses;
      if (synapses != Synapses.disabled) {
        synapses.call(pulse);
        return true;
      }
    }

    return receptor.call(pulse) != null;
  }

  Future<bool> emitAsync(I input) async {
    final lock = cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() => emit(input)).then((value) => value);
    }
    return Future<bool>(() => emit(input)).then((value) => value);
  }

  Future<void> ingest(Pulse<I> pulse,
      {bool serializedCompletion = true}) async {
    final receptor = cell._nucleus.receptor;
    return await receptor.async.call(pulse as PulseBase<I>,
        serializedCompletion: serializedCompletion);
  }

  return (cell: cell, emit: emit, emitAsync: emitAsync, ingest: ingest);
}

// ─────────────────────────────────────────────────────────────
// operator - observe
// ─────────────────────────────────────────────────────────────

EgressHandle<P> _observe<P extends Pulse>(
    {required Cell bind,
    required void Function(P pulse) effect,
    EphemeralPolicy? ephemeralPolicy,
    Context context = Context.system,
    TestCell testRule = TestCell.allowAll,
    bool initiallyStarted = true,
    bool forceLock = false}) {
  final cancel = Box<bool>(!initiallyStarted);
  bool start() => cancel.value = false;
  bool stop() => cancel.value = true;
  final receptor = _Receptor(reaction: (pulse, cell, {dynamic user}) {
    if (cancel.value == false) {
      effect(pulse as P);
    }
    return null;
  });
  final cell = Cell.governed(
      bind: bind,
      context: context,
      receptor: receptor,
      forceLock: forceLock,
      ephemeralPolicy: ephemeralPolicy,
      testRule: testRule,
      synapses: Synapses.disabled);
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
      // Tick the caller's policy so its own onEvent/limit/invalidation
      // semantics are preserved, then report the wrapper's own counter.
      ephemeralPolicy?.call(object, cell: cell, arguments: arguments);
      return (events: policy.events + 1);
    },
    onInvalidate: (nucleus) {
      cancelSubscription();
      // Preserve the caller's policy's own invalidation hook — the wrapper
      // replaced it on the host cell, so it would otherwise never run.
      ephemeralPolicy?.invalidate(nucleus.cell);
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
      // Removed: redundant lifecycle(value, cell: host) call.
      // passThrough is not governed, but the cell is.
      // ReceptorBase._proceed handles the lifecycle policy tick automatically.
      final limit = lifecycle.eventLimit;
      if (host.isInvalidated || (limit != null && lifecycle.events >= limit)) {
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

  // Prefer the public CellBase.lock accessor: reaching into the private
  // `_nucleus` member fails for cross-package Cell implementations whose
  // nuclei shadow that name (e.g., tissues). Cells outside CellBase simply
  // have no lock to acquire.
  final locks = sorted.map((c) => c is CellBase ? c.lock : null);
  return withLocks(locks, body);
}
