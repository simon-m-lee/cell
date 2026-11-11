// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
part of '../../cell.dart';

class _Synapses<P extends Pulse, L extends Cell> extends SynapsesBase<P, L> {
  _Synapses({
    super.policy,
    super.downstreams,
    super.filter,
    super.relay,
  }) : super();
}

/// An **Asynchronous Projection** of a [Synapses] instance for non‑blocking
/// signal distribution.
///
/// [AsyncSynapses] functions as a **Concurrent Dispatcher** within the
/// reactive network. It allows [Pulse] stimuli to be broadcast across
/// asynchronous boundaries, ensuring that high‑latency downstream
/// transformations do not block the primary execution thread.
///
/// ### When to use
/// * You obtain an instance via `synapses.async`:
///   ```dart
///
///   final asyncSynapses = cell._nucleus.synapses.async;
///   ```
/// * When you are in an asynchronous context and need to broadcast without
///   blocking.
/// * When you want to wait for the entire propagation to complete
///   (`serializedCompletion: true`).
/// * For fire‑and‑forget scenarios where you don't care about completion.
///
/// ### How it works
/// - The async synapses wraps the synchronous synapses.
/// - The `call` method queues the pulse into a thread‑safe buffer.
/// - A background worker processes the queue sequentially.
/// - The worker respects the propagation policy (debounce, throttle, etc.)
///   and the filter.
/// - The `serializedCompletion` flag controls whether to wait for all
///   downstream propagation to finish.
///
/// ### Example: Awaiting Completion
/// ```dart
/// final async = synapses.async;
/// await async.call(Pulse('update'), serializedCompletion: true);
/// print('Propagation complete');
/// ```
///
/// See also:
/// * [Synapses.async] – the getter that provides this.
/// * [ReceptorAsync] – similar pattern for receptors.
class AsyncSynapses<P extends Pulse, L extends Cell>
    extends SynapsesBase<P, L> {
  final SynapsesBase _source;

  AsyncSynapses._(this._source);

  @override
  Function? get _relay => _source._relay;

  @override
  QueueList<PulseBase>? get _buffer => _source._buffer;

  @override
  Box<Timer>? get _timerBox => _source._timerBox;

  @override
  FilterRule<P>? get _filter => _source._filter as FilterRule<P>?;

  @override
  PropagationPolicy? get _policy => _source._policy;

  @override
  Future<void> _broadcast(PulseBase pulse) async {
    final downstreams = _source.toList(growable: false);
    if (_source.isEmpty) {
      final box = pulse._branches;
      if (box != null) {
        box.value = box.value! - 1;
        if (box.value == 0) {
          pulse._complete();
          return;
        }
        return;
      } else {
        pulse._complete();
        return;
      }
    }

    final relay = _relay;
    if (relay != null) {
      if (_source.every((c) => pulse._checker.contains(c))) {
        pulse._complete();
        return;
      }
      relay.call(pulse);
    } else {
      // Fan-out accounting (mirrors the sync broadcast): each delivered
      // downstream owns one terminal decrement, so credit the root branch
      // box with (eligible - 1) before the drain loop starts.
      var eligible = 0;
      for (Cell c in downstreams) {
        if (!pulse._checker.contains(c)) eligible++;
      }
      if (eligible == 0) {
        pulse._complete();
        return;
      }
      final branches = pulse._branches;
      if (eligible > 1 && branches != null) {
        branches.value = branches.value! + (eligible - 1);
      }
      final futures = <Future>[];

      for (Cell c in downstreams) {
        if (!pulse._checker.contains(c)) {
          final receptor = c._nucleus.receptor;
          final f = receptor.async.call(pulse);
          futures.add(f);
        }
      }

      if (futures.isEmpty) {
        pulse._complete();
      } else {
        await Future.wait(futures);
      }
    }
  }

  @override
  Future<void> _flushBatch() async {
    final buffer = _buffer;
    if (buffer == null) return;

    final buffered = await buffer.async.toListAndClear(growable: false);
    if (buffered.isNotEmpty) {
      final batched = Pulse.batch(List<Pulse>.from(buffered));
      await _broadcast(batched as PulseBase);
    }
  }

  @override
  FutureOr<void> _debounced(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox == null) return;

    final buffer = _buffer;
    if (buffer != null) {
      await buffer.async.clearAndAdd(p);
    }

    timerBox.value?.cancel();
    final window = _policy!.debounceTime;
    if (window == Duration.zero) {
      timerBox.value = null;
      await _broadcast(p);
      return;
    }
    timerBox.value = Timer(window, () async {
      final buffer = _buffer;
      if (buffer != null) {
        final pulse = await buffer.async.removeLast();
        try {
          await _broadcast(pulse);
        } catch (e, st) {
          // Timer callbacks have no synchronous caller; a throwing
          // downstream must not become an unhandled zone error.
          pulse._fail(e, stackTrace: st);
        }
      }
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  @override
  Future<void> _buffered(PulseBase p) async {
    final buffer = _buffer;
    if (buffer != null) {
      await buffer.async.add(p);

      if (buffer.length == 1) {
        final timerBox = _timerBox;
        if (timerBox != null && timerBox.value == null) {
          timerBox.value = Timer(_policy!.throttleTime, () async {
            try {
              await _flushBatch();
            } catch (e, st) {
              p._fail(e, stackTrace: st);
            }
            timerBox.value!.cancel();
            timerBox.value = null;
          });
        }
      }
      if (_policy!.batchSize > 0 && buffer.length >= _policy!.batchSize) {
        await _flushBatch();
      }
    }
  }

  @override
  Future<void> _throttled(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox == null) return;
    if (timerBox.value != null) return;

    await _broadcast(p);
    final window = _policy!.throttleTime;
    if (window == Duration.zero) return;
    timerBox.value = Timer(window, () {
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  @override
  Future<void> _batched(PulseBase p) async {
    final buffer = _buffer;
    if (buffer != null) {
      await buffer.async.add(p);

      if (buffer.length >= (_policy!.batchSize)) await _flushBatch();
    }
  }

  @override
  Future<void> _audit(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox != null) {
      // We store the 'latest' pulse in the buffer for the audit window
      final buffer = _buffer;
      if (buffer != null) {
        await buffer.async.clearAndAdd(p);
      }

      if (timerBox.value == null) {
        final window = _policy!.throttleTime;
        if (window == Duration.zero) {
          await _broadcast(p);
          _buffer?.clear();
          return;
        }
        timerBox.value = Timer(window, () async {
          final latest = _buffer?.firstOrNull;
          if (latest != null) {
            try {
              await _broadcast(latest);
              _buffer?.clear();
            } catch (e, st) {
              latest._fail(e, stackTrace: st);
            }
          }
          timerBox.value?.cancel();
          timerBox.value = null;
        });
      }
    }
  }

  @override
  Future<void> _debounceLeading(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox == null || timerBox.value != null) return;

    await _broadcast(p);
    final window = _policy!.throttleTime;
    if (window == Duration.zero) return;
    timerBox.value = Timer(window, () {
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  // Note: _persistent is handled inside the 'link' method, not the 'call' method.
  @override
  Future<void> _rehydrate(Cell downstream) async {
    final lastPulse = _buffer?.lastOrNull;
    if (lastPulse != null) {
      final receptor = downstream._nucleus.receptor;
      await receptor.async.call(lastPulse);
    }
  }

  /// The primary execution entry point for the **Signal Distribution Network**,
  /// responsible for ingesting, filtering, and propagating pulses to all
  /// registered downstream observers.
  ///
  /// In the framework's architecture, the `call` method acts as the **Egress
  /// Gateway**. It sits at the boundary between a cell's internal logic and
  /// its external dependents, ensuring that signal propagation adheres to
  /// defined timing policies and structural invariants.
  ///
  /// ### When to use
  /// This method is called internally by the [Nucleus] whenever a cell
  /// completes its transformation logic. You rarely invoke this directly
  /// unless building custom [Synapses] implementations or low-level
  /// orchestration tools.
  ///
  /// ### How it works
  /// 1. **Graph Integrity**: If the cell has no observers, it decrements the
  ///    shared branch counter to signal that this path in the **Directed
  ///    Acyclic Graph (DAG)** has reached a dead end.
  /// 2. **Pre-Egress Filtering**: Applies the [FilterRule] (if any). This
  ///    allows the cell to redact, transform, or suppress pulses specifically
  ///    for its observers without affecting its own internal state.
  /// 3. **Protocol Selection**: Inspects the [PropagationPolicy] to determine
  ///    the delivery strategy (e.g., [PropagationStrategy.debounced],
  ///    [PropagationStrategy.batched]).
  /// 4. **Dispatch**: Forwards the pulse to the corresponding internal
  ///    handler (like `_debounced` or `_batched`) which manages timers,
  ///    buffers, and final delivery.
  ///
  /// ### Parameters:
  /// * [pulse]: **The Stimulus.** The [Pulse] instance to be distributed.
  ///   It contains the payload, source context, and forensic lineage.
  ///
  /// ### Returns:
  /// A [Future] that completes once the pulse has been accepted into the
  /// propagation fabric. Note that for asynchronous strategies (like debounce),
  /// the future completes once the *timer is scheduled*, not necessarily
  /// when the signal reaches the observers.
  ///
  /// ### See Also:
  /// * [PropagationStrategy]: For the various delivery timing models.
  /// * [FilterRule]: For intercepting pulses at the egress boundary.
  /// * [Synapses.link]: For managing the set of downstream observers.
  @override
  Future<void> call(covariant P pulse) async {
    if (_source.isEmpty) {
      final box = (pulse as PulseBase)._branches;
      if (box != null) {
        box.value = box.value! - 1;
        if (box.value == 0) {
          pulse._complete();
          return;
        }
        // Returning here serves two purposes:
        // 1. Do not complete a pulse that still has sibling branches.
        // 2. Do not fall through into the strategy switch, which would
        //    re-enter `_broadcast` and decrement the counter a second time.
        return;
      } else {
        pulse._complete();
        return;
      }
    }

    PulseBase? p;

    p = pulse as PulseBase?;

    if (_filter != null) {
      p = _filter!(pulse) as PulseBase?;
    }
    if (p == null) return;

    final strategy = _policy?.strategy ?? PropagationStrategy.immediate;
    switch (strategy) {
      case PropagationStrategy.immediate:
        await _broadcast(p);
        break;

      case PropagationStrategy.async:
        await _broadcast(p);
        break;

      case PropagationStrategy.batched:
        await _batched(p);
        break;

      case PropagationStrategy.buffered:
        await _buffered(p);
        break;

      case PropagationStrategy.debounced:
        await _debounced(p);
        break;

      case PropagationStrategy.throttled:
        await _throttled(p);
        break;

      case PropagationStrategy.audit:
        await _audit(p);
        break;

      case PropagationStrategy.debounceLeading:
        await _debounceLeading(p);
        break;

      case PropagationStrategy.persistent:
        final buffer = _buffer;
        if (buffer != null) {
          buffer
            ..clear()
            ..add(p);
        }
        await _broadcast(p);
        break;
    }
  }
}

/// The foundational base implementation for [Synapses], serving as the
/// **Transmission Engine** of the `cell.core` reactive framework.
///
/// `SynapsesBase` defines the mechanisms for pulse distribution,
/// hierarchical filtering, and graph topology management. It is the primary
/// component responsible for the **Conactive** (Concurrent + Reactive)
/// propagation of stimuli from a source cell to its downstream observers,
/// maintaining strict memory efficiency and transactional integrity.
///
/// ### When to use
/// * You rarely need to work with `SynapsesBase` directly – you typically
///   interact with a synapses instance via the `synapses` property of a cell.
///   However, if you're building custom cells, you might instantiate it:
///   ```dart
///   final synapses = Synapses(
///     policy: myPolicy,
///     downstreams: [observer1, observer2],
///     filter: myFilter,
///   );
///   ```
/// * You need to attach observers to a cell.
/// * You need to control how pulses are filtered or transformed before
///   reaching observers.
/// * You need to manage propagation timing (debounce, throttle, etc.).
///
/// ### How it works
/// - `SynapsesBase` holds a set of downstream cells (the observers).
/// - When `call(pulse)` is invoked, it applies the filter (if any), then
///   delivers the pulse to each observer, optionally applying a propagation
///   strategy.
/// - Links are added/removed via `link` and `unlink` – both are governed
///   by the cell's `TestCell.link` rule.
/// - The `async` getter provides a thread‑safe asynchronous version.
///
/// ### Example: Basic Synapses Setup
/// ```dart
/// final synapses = Synapses<String, Cell>(
///   downstreams: [logger, analytics],
///   filter: FilterRule((pulse, {user}) {
///     // Redact sensitive data
///     return Pulse(pulse.payload.replaceAll('secret', '***'));
///   }),
///   policy: PropagationPolicy(
///     strategy: PropagationStrategy.batched,
///     batchSize: 10,
///   ),
/// );
/// ```
///
/// See also:
/// * [Synapses] – the public interface.
/// * [FilterRule] – for pulse transformation.
/// * [PropagationPolicy] – for timing control.
abstract class SynapsesBase<P extends Pulse, C extends Cell>
    extends IterableBase<C> implements Synapses<P, C> {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// Depth of nested synchronous broadcasts currently iterating
  /// [_downstreams]. Link/unlink mutations received at depth > 0 are
  /// deferred so the live set is never modified mid-iteration (this replaces
  /// a per-broadcast `List.of` snapshot).
  int _broadcastDepth = 0;
  List<C>? _deferredAdds;
  List<C>? _deferredRemoves;

  /// Initializes a new [SynapsesBase] instance, acting as the **Network
  /// Controller** for signal distribution and graph topology management.
  ///
  /// This constructor establishes the infrastructure required to track
  /// downstream observers, apply hierarchical filtering, and manage the
  /// **Conactive** propagation of stimuli through the reactive **Switching Fabric**.
  ///
  /// ### When to use
  /// Use this when you need full control over the synapses configuration.
  /// Most of the time, you can rely on the default `Synapses.enabled`.
  ///
  /// ### How it works
  /// - The constructor stores the provided `policy`, `filter`, and initial
  ///   `downstreams` in a memory‑efficient record.
  /// - It prepares internal buffers and timers if the policy requires them.
  /// - The resulting instance is ready for linking and broadcasting.
  ///
  /// ### Parameters:
  /// * [policy]: The [PropagationPolicy] defining temporal flow control and
  ///   distribution strategy (e.g., immediate vs. batched).
  /// * [downstreams]: An initial [Iterable] of downstream [Cell] observers
  ///   acting as the initial egress targets.
  /// * [filter]: A [FilterRule] that acts as security and sanitization
  ///   middleware for the pulse stream.
  /// * [relay]: An optional **Manual Delegation** function. If provided, the
  ///   default broadcast loop is bypassed, allowing for a custom distribution
  ///   strategy across the downstream spokes.
  SynapsesBase({
    PropagationPolicy? policy,
    Iterable<C>? downstreams,
    FilterRule<P>? filter,
    void Function(P pulse)? relay,
  }) : _record = mask(
          // Identity-based edge set, on purpose: deputies are `==` to their
          // principals, but they are distinct graph nodes with their own
          // synapses and observers. A value-equality set would silently
          // collapse both edges into one (the same rule CycleChecker
          // already documents for pulse visitation).
          downstreams: downstreams != null
              ? (Set<C>.identity()..addAll(downstreams))
              : Set<C>.identity(),
          policy: policy,
          filter: filter,
          relay: relay,
        );

  static Record mask(
      {PropagationPolicy? policy,
      required Iterable downstreams,
      FilterRule? filter,
      Function? relay}) {
    final buffer = policy != null &&
            const [
              PropagationStrategy.batched,
              PropagationStrategy.buffered,
              PropagationStrategy.audit,
              PropagationStrategy.persistent,
              PropagationStrategy.throttled,
              PropagationStrategy.debounced,
            ].contains(policy.strategy)
        ? QueueList<PulseBase>()
        : null;

    final timerBox = policy != null &&
            const [
              PropagationStrategy.debounced,
              PropagationStrategy.buffered,
              PropagationStrategy.throttled,
              PropagationStrategy.audit,
              PropagationStrategy.debounceLeading,
            ].contains(policy.strategy)
        ? Box<Timer>()
        : null;

    final mask = ((policy != null ? 1 : 0) |
        (filter != null ? 2 : 0) |
        (buffer != null ? 4 : 0) |
        (timerBox != null ? 8 : 0) |
        (relay != null ? 16 : 0));

    return switch (mask) {
      0 => (downstreams: downstreams),
      1 => (downstreams: downstreams, policy: policy),
      2 => (downstreams: downstreams, filter: filter),
      3 => (downstreams: downstreams, policy: policy, filter: filter),
      4 => (downstreams: downstreams, buffer: buffer),
      5 => (downstreams: downstreams, policy: policy, buffer: buffer),
      6 => (downstreams: downstreams, filter: filter, buffer: buffer),
      7 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          buffer: buffer
        ),
      8 => (downstreams: downstreams, timerBox: timerBox),
      9 => (downstreams: downstreams, policy: policy, timerBox: timerBox),
      10 => (downstreams: downstreams, filter: filter, timerBox: timerBox),
      11 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          timerBox: timerBox
        ),
      12 => (downstreams: downstreams, buffer: buffer, timerBox: timerBox),
      13 => (
          downstreams: downstreams,
          policy: policy,
          buffer: buffer,
          timerBox: timerBox
        ),
      14 => (
          downstreams: downstreams,
          filter: filter,
          buffer: buffer,
          timerBox: timerBox
        ),
      15 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          buffer: buffer,
          timerBox: timerBox
        ),
      16 => (downstreams: downstreams, relay: relay),
      17 => (downstreams: downstreams, policy: policy, relay: relay),
      18 => (downstreams: downstreams, filter: filter, relay: relay),
      19 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          relay: relay
        ),
      20 => (downstreams: downstreams, buffer: buffer, relay: relay),
      21 => (
          downstreams: downstreams,
          policy: policy,
          buffer: buffer,
          relay: relay
        ),
      22 => (
          downstreams: downstreams,
          filter: filter,
          buffer: buffer,
          relay: relay
        ),
      23 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          buffer: buffer,
          relay: relay
        ),
      24 => (downstreams: downstreams, timerBox: timerBox, relay: relay),
      25 => (
          downstreams: downstreams,
          policy: policy,
          timerBox: timerBox,
          relay: relay
        ),
      26 => (
          downstreams: downstreams,
          filter: filter,
          timerBox: timerBox,
          relay: relay
        ),
      27 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          timerBox: timerBox,
          relay: relay
        ),
      28 => (
          downstreams: downstreams,
          buffer: buffer,
          timerBox: timerBox,
          relay: relay
        ),
      29 => (
          downstreams: downstreams,
          policy: policy,
          buffer: buffer,
          timerBox: timerBox,
          relay: relay
        ),
      30 => (
          downstreams: downstreams,
          filter: filter,
          buffer: buffer,
          timerBox: timerBox,
          relay: relay
        ),
      31 => (
          downstreams: downstreams,
          policy: policy,
          filter: filter,
          buffer: buffer,
          timerBox: timerBox,
          relay: relay
        ),
      _ => (downstreams: downstreams)
    };
  }

  Function? get _relay => get<Function?>(() => _record.relay, orElse: null);

  QueueList<PulseBase>? get _buffer =>
      get<QueueList<PulseBase>?>(() => _record.buffer, orElse: null);

  Box<Timer>? get _timerBox =>
      get<Box<Timer>?>(() => _record.timerBox, orElse: null);

  Set<C> get _downstreams =>
      get<Set<C>>(() => _record.downstreams, orElse: const {});

  @override
  Iterator<C> get iterator => _downstreams.iterator;

  @override
  bool get isEmpty => _downstreams.isEmpty;

  @override
  bool get isNotEmpty => _downstreams.isNotEmpty;

  FilterRule<P>? get _filter =>
      get<FilterRule<P>?>(() => _record.filter, orElse: null);

  PropagationPolicy? get _policy =>
      get<PropagationPolicy?>(() => _record.policy, orElse: null);

  void _flushBatch() {
    final buffer = _buffer;
    if (buffer == null || buffer.isEmpty) return;
    final snapshot = List<Pulse>.from(buffer);
    buffer.clear();
    _broadcast(Pulse.batch(snapshot) as PulseBase);
  }

  void _broadcast(PulseBase pulse) {
    if (isEmpty) {
      final box = pulse._branches;
      if (box != null) {
        box.value = box.value! - 1;
        if (box.value == 0) {
          pulse._complete();
          return;
        }
        // Sibling branches still own the completion counter. Decrement has
        // been applied; completion will be driven by whichever branch is
        // last to reach zero. Do NOT fall through to the empty-loop
        // `_complete()` guard below — that would complete the collective
        // while other branches are still in flight.
        return;
      }
    }

    final relay = _relay;
    if (relay != null) {
      if (every((c) => pulse._checker.contains(c))) {
        pulse._complete();
        return;
      }
      relay.call(pulse);
    } else {
      // Fan-out accounting: the root's branch box starts at one (the
      // emitting cell's own journey). Each downstream delivery owns one
      // terminal decrement, so credit the box with (eligible - 1) up
      // front — N terminals then drive it to zero exactly once, after the
      // last one. Without this the first terminal of a fan-out fires the
      // completion callback early and later terminals drive the counter
      // negative.
      var eligible = 0;
      for (Cell c in _downstreams) {
        if (!pulse._checker.contains(c)) eligible++;
      }
      if (eligible == 0) {
        pulse._complete();
        return;
      }
      final branches = pulse._branches;
      if (eligible > 1 && branches != null) {
        branches.value = branches.value! + (eligible - 1);
      }
      var delivered = 0;
      // Iterate the live set under the mutation guard: receptors may link
      // or unlink cells while they run (e.g. a switchMap mapper that binds
      // its inner cell to the source). Such mutations are deferred and
      // applied after the loop, so no snapshot allocation is needed.
      _broadcastDepth++;
      try {
        for (Cell c in _downstreams) {
          if (!pulse._checker.contains(c)) {
            final receptor = c._nucleus.receptor;
            // Fast path for the common observer shape: ungoverned,
            // allowAll, reaction-only receptor on a disabled-synapse cell
            // (what `Cell.observe` builds). Invoke the reaction directly
            // and perform the terminal accounting inline — the full
            // pipeline only adds no-ops for this configuration.
            if (receptor is _Receptor &&
                receptor._reaction != null &&
                receptor._instruction == null &&
                receptor._preProcess == null &&
                receptor._postProcess == null &&
                !c.isGoverned &&
                identical(c._nucleus.testRule, TestCell.allowAll) &&
                c._nucleus.synapses == Synapses.disabled) {
              if (pulse._checker.add(c)) {
                try {
                  // Same user contract as the slow path: reactions receive
                  // the RAW metadata, not the FinalBox it is stored in.
                  final userBox = receptor._user;
                  receptor._reaction!(
                    pulse,
                    c,
                    user: userBox is FinalBox ? userBox.value : userBox,
                  );
                } catch (e, stackTrace) {
                  // Match the contained path: route the failure to the
                  // pulse's onError and keep delivering to the remaining
                  // downstreams instead of aborting the broadcast into
                  // the emit() caller.
                  pulse._fail(e, stackTrace: stackTrace);
                }
                // Terminal accounting is ALWAYS on the input pulse: the
                // fan-out credit was applied to it, never to a pulse the
                // reaction returned. A returned pulse starts its own
                // journey (its own branch box); decrementing it here would
                // orphan the input's credit and hang its onComplete.
                final box = pulse._branches;
                if (box == null) {
                  pulse._complete();
                } else {
                  box.value = box.value! - 1;
                  if (box.value == 0) pulse._complete();
                }
                delivered++;
              }
            } else {
              receptor(pulse);
              delivered++;
            }
          }
        }
      } finally {
        _broadcastDepth--;
        if (_broadcastDepth == 0) _flushDeferredLinks();
      }
      // Reconcile fan-out accounting. The credit was granted for every
      // eligible downstream up front; a re-entrant receptor can mark a
      // later downstream as already-visited (or unlink it) mid-loop, so
      // fewer deliveries happen than were credited. Drive the shared
      // counter down by the difference — otherwise the pulse's onComplete
      // hangs forever.
      if (delivered < eligible) {
        final box = pulse._branches;
        if (box == null) {
          pulse._complete();
        } else {
          box.value = box.value! - (eligible - delivered);
          if (box.value! <= 0) pulse._complete();
        }
      }
    }
  }

  /// Applies link/unlink mutations that were deferred while a synchronous
  /// broadcast was iterating the downstream set.
  void _flushDeferredLinks() {
    final adds = _deferredAdds;
    _deferredAdds = null;
    final removes = _deferredRemoves;
    _deferredRemoves = null;

    if (adds != null) {
      final persistent = _policy?.strategy == PropagationStrategy.persistent;
      for (final c in adds) {
        if (_downstreams.add(c) && persistent) {
          _rehydrate(c);
        }
      }
    }
    if (removes != null) {
      for (final c in removes) {
        _downstreams.remove(c);
      }
    }
  }

  void _debounced(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox == null) return;

    timerBox.value?.cancel();
    final window = _policy!.debounceTime;
    if (window == Duration.zero) {
      timerBox.value = null;
      _broadcast(p);
      return;
    }
    timerBox.value = Timer(window, () {
      try {
        _broadcast(p);
      } catch (e, st) {
        p._fail(e, stackTrace: st);
      }
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  void _buffered(PulseBase p) {
    final buffer = _buffer;
    if (buffer == null) return;
    buffer.add(p);

    final timerBox = _timerBox;
    if (_policy!.batchSize > 0 && buffer.length >= _policy!.batchSize) {
      timerBox?.value?.cancel();
      timerBox?.value = null;
      _flushBatch();
      return;
    }

    if (buffer.length == 1 && timerBox != null && timerBox.value == null) {
      final window = _policy!.throttleTime;
      if (window == Duration.zero) {
        _flushBatch();
        return;
      }
      timerBox.value = Timer(window, () {
        try {
          _flushBatch();
        } catch (e, st) {
          p._fail(e, stackTrace: st);
        }
        timerBox.value?.cancel();
        timerBox.value = null;
      });
    }
  }

  void _throttled(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox == null || timerBox.value != null) return;

    _broadcast(p);
    final window = _policy!.throttleTime;
    if (window == Duration.zero) return;
    timerBox.value = Timer(window, () {
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  void _batched(PulseBase p) {
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(p);

      if (buffer.length >= _policy!.batchSize) {
        _flushBatch();
      }
    }
  }

  void _audit(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox == null) return;

    final buffer = _buffer;
    if (buffer != null) {
      buffer.clear();
      buffer.add(p);
    }

    if (timerBox.value != null) return;

    final window = _policy!.throttleTime;
    if (window == Duration.zero) {
      _broadcast(p);
      buffer?.clear();
      return;
    }
    timerBox.value = Timer(window, () {
      final latest = _buffer?.firstOrNull;
      if (latest != null) {
        try {
          _broadcast(latest);
          _buffer?.clear();
        } catch (e, st) {
          latest._fail(e, stackTrace: st);
        }
      }
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  void _debounceLeading(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox == null || timerBox.value != null) return;

    _broadcast(p);
    final window = _policy!.throttleTime;
    if (window == Duration.zero) return;
    timerBox.value = Timer(window, () {
      timerBox.value?.cancel();
      timerBox.value = null;
    });
  }

  // Note: _persistent is handled inside the 'link' method, not the 'call' method.
  void _rehydrate(Cell downstream) {
    final lastPulse = _buffer?.lastOrNull;
    if (lastPulse != null) {
      final receptor = downstream._nucleus.receptor;
      receptor(lastPulse);
    }
  }

  /// Synchronously orchestrates the atomic propagation wave for the
  /// provided [pulse] across all registered downstream observers.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it when a cell's
  /// state changes. You might use it for manual testing.
  ///
  /// ### How it works
  /// It applies the filter (if any), then delivers the pulse to each observer
  /// in sequence, respecting the propagation policy. If a cycle is detected,
  /// the branch is silently terminated.
  ///
  /// ### Parameters:
  /// - [pulse]: The pulse to broadcast.
  @override
  void call(covariant P pulse) {
    if (isEmpty && pulse is PulseBase) {
      if (_policy?.strategy == PropagationStrategy.persistent) {
        final buffer = _buffer;
        if (buffer != null) {
          buffer
            ..clear()
            ..add(pulse);
        }
      }
      final box = pulse._branches;
      if (box != null) {
        box.value = box.value! - 1;
        if (box.value == 0) {
          pulse._complete();
          return;
        }
        // Returning here serves two purposes:
        // 1. Do not complete a pulse that still has sibling branches.
        // 2. Do not fall through into the strategy switch, which would
        //    re-enter `_broadcast` and decrement the counter a second time.
        return;
      } else {
        pulse._complete();
        return;
      }
    }

    PulseBase? p;

    p = pulse as PulseBase?;

    if (_filter != null) {
      p = _filter!(p as P) as PulseBase?;
    }
    if (p == null) return;

    final strategy = _policy?.strategy ?? PropagationStrategy.immediate;
    switch (strategy) {
      case PropagationStrategy.immediate:
        _broadcast(p);
        break;

      case PropagationStrategy.async:
        Future(() => _broadcast(p!));
        break;

      case PropagationStrategy.batched:
        _batched(p);
        break;

      case PropagationStrategy.buffered:
        _buffered(p);
        break;

      case PropagationStrategy.debounced:
        _debounced(p);
        break;

      case PropagationStrategy.throttled:
        _throttled(p);
        break;

      case PropagationStrategy.audit:
        _audit(p);
        break;

      case PropagationStrategy.debounceLeading:
        _debounceLeading(p);
        break;

      case PropagationStrategy.persistent:
        final buffer = _buffer;
        if (buffer != null) {
          buffer
            ..clear()
            ..add(p);
        }
        _broadcast(p);
        break;
    }
  }

  /// Establishes a formal reactive connection (link) between the host [cell]
  /// and a [downstreamCell].
  ///
  /// ### When to use
  /// Use this to dynamically add an observer to a cell at runtime – e.g.,
  /// when a UI component mounts.
  ///
  /// ### How it works
  /// The method validates the link via the cell's [TestCell], then adds the
  /// downstream cell to the registry. If the cell is already linked, it's a
  /// no‑op. Returns `true` on success, `false` if rejected.
  ///
  /// ### Example
  /// ```dart
  /// final linked = await synapses.link(source, downstreamCell: observer);
  /// if (linked) { /* observer now receives updates */ }
  /// ```
  ///
  /// ### Parameters:
  /// - [cell]: The host cell that owns these synapses (the source of the
  ///   signals).
  /// - [downstreamCell]: The cell that should receive signals from the host
  ///   (the target observer).
  ///
  /// ### Returns:
  /// - `true` if the link was successfully established or already existed.
  /// - `false` if the connection was rejected by security rules or if
  ///   the synapses are disabled.
  @override
  FutureOr<bool> link(Cell cell, {required Cell downstreamCell}) {
    final synapse = cell._nucleus.synapses;

    if (identical(synapse, this)) {
      // 1. Capture the FutureOr validation result
      final validation = cell.validate(downstreamCell, host: cell);

      // 2. Define the registration logic as a reusable closure
      bool register() {
        if (downstreamCell is! C) return false;
        if (_broadcastDepth > 0) {
          // Defer the mutation: the sync broadcast is iterating the live
          // downstream set right now.
          (_deferredAdds ??= <C>[]).add(downstreamCell);
          return true;
        }
        final added = _downstreams.add(downstreamCell);

        // If strategy is persistent, send the last state to the new observer
        if (added && _policy?.strategy == PropagationStrategy.persistent) {
          _rehydrate(downstreamCell);
        }
        return added;
      }

      // 3. Branch: Asynchronous Path
      if (validation is Future<bool>) {
        return validation.then((passed) {
          return passed ? register() : false;
        });
      }

      // 4. Branch: Synchronous Path (Zero-cost)
      return validation ? register() : false;
    }

    return false;
  }

  /// Formally dissolves the reactive connection (link) between the host [cell]
  /// and the [downstreamCell], neutralising the signal path between them.
  ///
  /// ### When to use
  /// Use this to remove an observer when it's no longer needed – e.g., when
  /// a UI component unmounts, to prevent memory leaks.
  ///
  /// ### How it works
  /// The method removes the downstream cell from the registry. If the link
  /// doesn't exist, it's a no‑op. Returns `true` if the link was removed,
  /// `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// synapses.unlink(source, downstreamCell: observer);
  /// ```
  ///
  /// ### Parameters:
  /// - [cell]: The host cell that owns these synapses (the source of the signals).
  /// - [downstreamCell]: The observer cell that should be disconnected
  ///   from the host.
  ///
  /// ### Returns:
  /// - `true` if the link was successfully found and removed.
  /// - `false` if the link did not exist, or if the operation was rejected
  ///   by security rules or disabled synapses.
  @override
  bool unlink(Cell cell, {required Cell downstreamCell}) {
    final synapses = cell._nucleus.synapses;
    if (identical(synapses, this)) {
      if (_broadcastDepth > 0) {
        if (downstreamCell is! C) return false;
        (_deferredRemoves ??= <C>[]).add(downstreamCell);
        return true;
      }
      return _downstreams.remove(downstreamCell);
    }
    return false;
  }

  /// Returns an asynchronous projection of these synapses for non‑blocking
  /// signal distribution.
  ///
  /// ### When to use
  /// Use this when you need to broadcast pulses without blocking the current
  /// execution thread – e.g., for UI updates, logging, or background
  /// processing.
  ///
  /// ### How it works
  /// The async view schedules the broadcast on the event loop. It also
  /// uses a thread‑safe cycle checker to maintain causal integrity.
  ///
  /// ### Example
  /// ```dart
  /// await synapses.async.call(Pulse('update'));
  /// ```
  @override
  late final AsyncSynapses<P, C> async = AsyncSynapses._(this);

  @override
  int get hashCode => _record.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SynapsesBase) return false;
    return _record == other._record;
  }
}

final class _SynapsesDisabled extends IterableBase<Never>
    implements Synapses<Never, Never> {
  const _SynapsesDisabled();

  @override
  AsyncSynapses<Never, Never> get async =>
      throw UnsupportedError('Disabled Synapses');

  @override
  bool link(Cell cell, {required Cell downstreamCell}) => false;

  @override
  bool unlink(Cell cell, {required Cell downstreamCell}) => false;

  @override
  Iterator<Never> get iterator => const Iterable<Never>.empty().iterator;

  @override
  void call(covariant PulseBase pulse) {}
}

final class _SynapsesEnabled extends IterableBase<Never>
    implements Synapses<Never, Never> {
  const _SynapsesEnabled();

  @override
  AsyncSynapses<Never, Never> get async =>
      throw UnsupportedError('Disabled Synapses');

  @override
  void call(covariant Never pulse) {}

  @override
  bool link(Cell cell, {required Cell downstreamCell}) => false;

  @override
  bool unlink(Cell cell, {required Cell downstreamCell}) => false;

  @override
  Iterator<Never> get iterator => const Iterable<Never>.empty().iterator;
}

/// Defines the tactical execution models for **Pulse Propagation** within
/// the Cell framework's reactive graph.
///
/// The [PropagationStrategy] governs the temporal and behavioral characteristics
/// of how a stimulus (a [Pulse]) travels from a source [Cell] through its
/// [Synapses] to downstream observers. By selecting a strategy, developers
/// can optimise for latency, throughput, or stability, essentially defining
/// the "metabolic rate" of specific branches in the reactive graph.
///
/// ### When to use
/// * You typically set a strategy via a [PropagationPolicy] when creating synapses:
///   ```dart
///   final synapses = Synapses(
///     policy: PropagationPolicy(
///       strategy: PropagationStrategy.debounced,
///       debounceTime: Duration(milliseconds: 300),
///     ),
///   );
///   ```
///   Choose the strategy that matches your use case – most common are
///   `immediate` (default), `debounced` (for user input), and `throttled`
///   (for rate‑limiting).
/// * **immediate**: For critical state updates that must be synchronous.
/// * **async**: To break deep recursion or offload to the event loop.
/// * **debounced**: For search‑as‑you‑type, where only the final value matters.
/// - **throttled**: For rate‑limiting high‑frequency events (e.g., scroll).
/// - **batched**: For aggregating multiple updates into one (e.g., logging).
/// - **audit**: To get the latest value at a fixed interval.
/// - **debounceLeading**: To respond immediately to the first event, then wait.
/// - **persistent**: To replay the last state to new observers.
///
/// ### How it works
/// - The strategy is applied at the egress point – when a pulse is about to
///   be broadcast to observers.
/// - The policy holds the strategy and any timing parameters.
/// - The synapses implementation switches on the strategy to determine how
///   to buffer, delay, or batch outgoing pulses.
/// - Each strategy has a specific behaviour; see the individual enum values
///   for details.
///
/// ### Example: Debounced Search
/// ```dart
/// final searchSynapses = Synapses<String, Cell>(
///   policy: PropagationPolicy(
///     strategy: PropagationStrategy.debounced,
///     debounceTime: Duration(milliseconds: 300),
///   ),
/// );
/// ```
///
/// See also:
/// * [PropagationPolicy] – the configuration container.
/// * [Synapses] – the distribution network that uses the policy.
enum PropagationStrategy {
  /// The **Default Synchronous** strategy. Pulses are delivered immediately
  /// and recursively within the current execution pulse.
  ///
  /// *   **Behavior**: When a cell is triggered, it immediately invokes the
  ///     receptors of all linked cells on the same stack frame.
  /// *   **Use Case**: Ideal for critical state logic, validation rules, and
  ///     scenarios where "Tearing" (inconsistent state between related nodes)
  ///     must be strictly avoided.
  /// *   **Trade-off**: High-frequency updates can lead to UI jank or
  ///     temporary blocking of the event loop if the downstream graph is deep.
  immediate,

  /// The **Microtask Deferral** strategy. Pulses are scheduled to be
  /// broadcast on the next turn of the event loop.
  ///
  /// *   **Behavior**: Uses `Future` or `scheduleMicrotask` to decouple the
  ///     source trigger from the observer execution.
  /// *   **Use Case**: Beneficial for breaking up long execution chains and
  ///     ensuring the current function returns before downstream side effects
  ///     begin.
  /// *   **Trade-off**: Introduces a small amount of latency and breaks
  ///     immediate synchronous execution flow.
  async,

  /// The **Accumulative Processing** strategy. Multiple signals are
  /// collected into a buffer and delivered as a single unit.
  ///
  /// *   **Behavior**: Pulses are held in a `buffer` until a
  ///     specific `batchSize` is reached or a time window expires. They
  ///     are then delivered as a single [Pulse] containing a collection
  ///     of payloads.
  /// *   **Use Case**: High-throughput scenarios like logging, bulk
  ///     database writes, or multi-item UI updates where processing
  ///     individuals would be inefficient.
  /// *   **Trade-off**: Increased memory overhead for the buffer and
  ///     delayed delivery for the first items in the batch.
  batched,

  /// The **Temporal Aggregation** strategy for lossless signal delivery.
  ///
  /// *   **Behavior**: Pulses are accumulated in an internal queue during a
  ///     deterministic time window. Unlike [throttled] or [debounced], no
  ///     intermediate signals are discarded. Once the `throttleTime` expires,
  ///     all captured pulses are broadcast as a single composite event.
  /// *   **Use Case**: Ideal for high-density telemetry, audit trails, and
  ///     I/O-heavy operations (like database persistence or network logging)
  ///     where preserving every event is critical, but processing them
  ///     individually is inefficient.
  /// *   **Trade-off**: Introduces a delivery delay for all signals in the
  ///     buffer equal to the remaining duration of the current temporal cycle,
  ///     and increases memory pressure proportional to the burst volume.
  /// *   **Memory**: Requires temporary heap storage for the accumulated
  ///     pulses until the flush occurs.
  buffered,

  /// The **Trailing Edge** strategy. Delivery is delayed until a
  /// specified period of "silence" has passed.
  ///
  /// *   **Behavior**: Each new pulse resets a `debounced` timer. The
  ///     pulse is only broadcast if no new signals are received within
  ///     that window.
  /// *   **Use Case**: Search-as-you-type inputs, window resizing, or
  ///     any scenario where only the *final* state after a burst of
  ///     activity is relevant.
  /// *   **Trade-off**: Pulses that arrive during the burst are
  ///     discarded; only the last one survives.
  debounced,

  /// The **Fixed Frequency** strategy. Ensures signals are delivered at
  /// a controlled, maximum rate.
  ///
  /// *   **Behavior**: The first pulse is delivered immediately, and a
  ///     `throttled` timer starts. Subsequent signals during this
  ///     window are ignored until the timer expires.
  /// *   **Use Case**: Limiting expensive operations like scroll event
  ///     listeners, API rate-limiting, or physical hardware sensors
  ///     that emit more data than the consumer needs.
  /// *   **Trade-off**: Intermediate data points between throttle ticks
  ///     are lost, providing a "sampled" view of the state.
  throttled,

  /// The **Trailing-Edge Sampling** strategy. Ensures the latest state within
  /// a periodic window is delivered.
  ///
  /// *   **Behavior**: Similar to [throttled], but instead of delivering the
  ///     first pulse of a window, it delivers the *most recent* pulse received
  ///     when the `throttleTime` expires.
  /// *   **Use Case**: Real-time dashboards or telemetry where you need the
  ///     freshest data point at a fixed frequency, without the "silence"
  ///     requirement of [debounced].
  /// *   **Trade-off**: Introduces a constant latency equal to the
  ///     `throttleTime`.
  audit,

  /// The **Leading-Edge Debounce** strategy. Delivers the first signal
  /// and silences subsequent signals during the window.
  ///
  /// *   **Behavior**: High-responsiveness. Delivers the *first* pulse
  ///     immediately, then ignores all others until the `throttleTime`
  ///     silence window is met.
  /// *   **Use Case**: Button debouncing where the user expects immediate
  ///     UI feedback, but the backend must be protected from double-clicks.
  debounceLeading,

  /// The **State-Preserving Relink** strategy. Ensures newly linked observers
  /// receive the last known state.
  ///
  /// *   **Behavior**: When a new [Cell] is linked, it
  ///     automatically receives the most recent [Pulse] emitted by the source.
  /// *   **Use Case**: Late-binding UI components or dynamic observers that
  ///     need to "catch up" to the current system state.
  persistent,
}

/// A declarative blueprint defining the **Temporal Dynamics** and
/// **Operational Governance** of pulse propagation.
///
/// The [PropagationPolicy] acts as the **Structural Configuration** for
/// a [Synapses] instance. It determines how the framework reconciles
/// high‑frequency stimuli, manages aggregation buffers, and ensures
/// transactional integrity.
///
/// ### When to use
/// * You create a policy when you need non‑default propagation behavior:
///   ```dart
///   final policy = PropagationPolicy(
///     strategy: PropagationStrategy.debounced,
///     debounceTime: Duration(milliseconds: 300),
///   );
///   final synapses = Synapses(policy: policy);
///   ```
/// * Use a custom policy when the default `immediate` propagation is not
///   suitable – e.g., to avoid UI jank, to batch updates, or to rate‑limit.
///
/// ### How it works
/// - The policy holds the selected [strategy] and its parameters.
/// - When a pulse is emitted, the synapses checks the policy and applies
///   the appropriate buffering, timing, or filtering logic.
/// - The policy is immutable – you set it once at synapses creation.
///
/// ### Example: Debounced Search
/// ```dart
/// const searchConfig = PropagationPolicy(
///   strategy: PropagationStrategy.debounced,
///   debounceTime: Duration(milliseconds: 300),
/// );
/// ```
///
/// ### Example: High‑Frequency Sensor Throttle
/// ```dart
/// const sensorConfig = PropagationPolicy(
///   strategy: PropagationStrategy.throttled,
///   throttleTime: Duration(milliseconds: 16), // ~60fps
/// );
/// ```
///
/// ### Example: Bulk Data Batching
/// ```dart
/// const loggingConfig = PropagationPolicy(
///   strategy: PropagationStrategy.batched,
///   batchSize: 50,
/// );
/// ```
///
/// See also:
/// * [PropagationStrategy] – the execution model.
/// * [Synapses] – the distribution network that uses the policy.
/// {@category Advanced · Propagation Policy}
class PropagationPolicy {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// The specific tactical model used for pulse delivery.
  ///
  /// Defaults to [PropagationStrategy.immediate] for real‑time,
  /// synchronous consistency.
  ///
  /// ### When to use
  /// Read this to know what strategy is active. You rarely need to change it
  /// after policy creation because the policy is immutable.
  PropagationStrategy get strategy =>
      get<PropagationStrategy>(() => _record.strategy,
          orElse: PropagationStrategy.immediate);

  /// The window of **Environmental Stability** required before a signal
  /// is committed when using [PropagationStrategy.debounced].
  ///
  /// Each new incoming [Pulse] resets the internal timer. The signal is
  /// only broadcast once the system has remained "silent" (received no
  /// further stimuli) for the duration of the [debounceTime].
  ///
  /// ### When to use
  /// Use this to control how long to wait after the last event before
  /// delivering the pulse. A longer debounce gives more stability but
  /// increases latency.
  ///
  /// ### How it works
  /// While the timer is active, the [Pulse] is held in a transient state.
  /// If a new pulse arrives before the timer expires:
  /// - The previous pulse is discarded.
  /// - The timer is reset to the full [debounceTime].
  /// - The new pulse becomes the candidate for the next broadcast.
  ///
  /// ### Returns:
  /// A [Duration] representing the required period of inactivity before
  /// signal propagation.
  Duration get debounceTime => get<Duration>(() => _record.debounceTime,
      orElse: const Duration(milliseconds: 150));

  /// The minimum interval between consecutive signal emissions when using
  /// [PropagationStrategy.throttled].
  ///
  /// The first [Pulse] in a sequence is delivered immediately, while subsequent
  /// signals are suppressed until the [throttleTime] has elapsed. This ensures
  /// a predictable **Maximum Propagation Frequency**.
  ///
  /// ### When to use
  /// Use this to enforce a maximum rate of updates – e.g., to limit UI
  /// refreshes or API calls.
  ///
  /// ### How it works
  /// When a pulse is emitted, a "quiet period" equal to the [throttleTime]
  /// begins. Any pulses arriving during this window are dropped. Once the
  /// window expires, the next incoming pulse is again delivered immediately,
  /// restarting the cycle.
  ///
  /// ### Returns:
  /// A [Duration] representing the minimum gap between broadcast events.
  Duration get throttleTime => get<Duration>(() => _record.throttleTime,
      orElse: const Duration(milliseconds: 200));

  /// The maximum capacity of the aggregation buffer before a signal flush
  /// occurs when using [PropagationStrategy.batched].
  ///
  /// The [batchSize] defines the **Collection Threshold** for incoming stimuli.
  /// Pulses are held in a transient buffer until this count is reached, at which
  /// point the entire collection is collapsed into a single composite [Pulse]
  /// and transmitted across the distribution network.
  ///
  /// ### When to use
  /// Use this to control how many pulses to accumulate before flushing.
  /// A larger batch reduces overhead but increases latency.
  ///
  /// ### How it works
  /// As pulses arrive:
  /// - The system increments an internal counter and caches the [Pulse].
  /// - Once the counter equals the [batchSize], the buffer is flushed.
  /// - The resulting composite signal contains the chronological history
  ///   of all [batchSize] pulses.
  ///
  /// ### Returns:
  /// An [int] representing the signal accumulation threshold.
  int get batchSize => get<int>(() => _record.batchSize, orElse: 10);

  /// A declarative policy object used to define the **Temporal Dynamics**
  /// and **Operational Safety** of pulse propagation within a [Cell].
  ///
  /// The [PropagationPolicy] acts as the **Structural Governance Blueprint**
  /// for a [Synapses] instance. It determines the tactical execution
  /// model—defining how the system reconciles high‑frequency stimuli and
  /// manages batch synchronization.
  ///
  /// ### When to use
  /// Create a policy whenever you need non‑default propagation behavior.
  ///
  /// ### How it works
  /// - The policy stores the strategy and parameters.
  /// - It is attached to a synapses instance at creation.
  /// - The synapses uses the policy to decide how to handle each outgoing pulse.
  ///
  /// ### Parameters:
  /// * [strategy]: The tactical model defining the timing and delivery mode
  ///   (e.g., immediate, async, or throttled). Defaults to [PropagationStrategy.immediate].
  /// * [debounceTime]: The required window of environmental stability before
  ///   a signal is committed. Defaults to **150 milliseconds**.
  /// * [throttleTime]: The minimum interval between consecutive signal
  ///   emissions. Defaults to **200 milliseconds**.
  /// * [batchSize]: The threshold of accumulated signals required to trigger
  ///   a single delivery wave. Defaults to **10**.
  ///
  /// ### Example
  /// ```dart
  /// final policy = PropagationPolicy(
  ///   strategy: PropagationStrategy.debounced,
  ///   debounceTime: Duration(milliseconds: 300),
  /// );
  /// ```
  PropagationPolicy(
      {PropagationStrategy strategy = PropagationStrategy.immediate,
      Duration debounceTime = const Duration(milliseconds: 150),
      Duration throttleTime = const Duration(milliseconds: 200),
      int batchSize = 10})
      : _record = mask(
          strategy: strategy,
          debounceTime:
              debounceTime != Duration(milliseconds: 150) ? debounceTime : null,
          throttleTime:
              throttleTime != Duration(milliseconds: 200) ? throttleTime : null,
          batchSize: batchSize != 10 ? batchSize : null,
        );

  static Record mask(
      {PropagationStrategy strategy = PropagationStrategy.immediate,
      Duration? debounceTime,
      Duration? throttleTime,
      int? batchSize}) {
    final mask = ((strategy != PropagationStrategy.immediate ? 1 : 0) |
        (debounceTime != null ? 2 : 0) |
        (throttleTime != null ? 4 : 0) |
        (batchSize != null ? 8 : 0));

    return switch (mask) {
      0 => (),
      1 => (strategy: strategy),
      2 => (debounceTime: debounceTime),
      3 => (strategy: strategy, debounceTime: debounceTime),
      4 => (throttleTime: throttleTime),
      5 => (strategy: strategy, throttleTime: throttleTime),
      6 => (debounceTime: debounceTime, throttleTime: throttleTime),
      7 => (
          strategy: strategy,
          debounceTime: debounceTime,
          throttleTime: throttleTime
        ),
      8 => (batchSize: batchSize),
      9 => (strategy: strategy, batchSize: batchSize),
      10 => (debounceTime: debounceTime, batchSize: batchSize),
      11 => (
          strategy: strategy,
          debounceTime: debounceTime,
          batchSize: batchSize
        ),
      12 => (throttleTime: throttleTime, batchSize: batchSize),
      13 => (
          strategy: strategy,
          throttleTime: throttleTime,
          batchSize: batchSize
        ),
      14 => (
          debounceTime: debounceTime,
          throttleTime: throttleTime,
          batchSize: batchSize
        ),
      15 => (
          strategy: strategy,
          debounceTime: debounceTime,
          throttleTime: throttleTime,
          batchSize: batchSize
        ),
      _ => ()
    };
  }

  @override
  int get hashCode => _record.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PropagationPolicy && other._record == _record;
  }

  @override
  String toString() =>
      'PropagationPolicy(strategy: $strategy, debounceTime: $debounceTime, '
      'throttleTime: $throttleTime, batchSize: $batchSize)';
}
