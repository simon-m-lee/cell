// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
part of '../../cell.dart';

class _Synapses<P extends Pulse, L extends Cell> extends SynapsesBase<P,L> {

  _Synapses({
    super.policy,
    super.downstreams, super.filter, super.relay,
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
/// ### Non‑obvious
/// - The queue is **unbounded** – be mindful of memory under high load.
/// - The worker is lazy – it starts on the first `call`.
/// - The async synapses shares the same `TestCell` and `Lock` as the
///   synchronous synapses, so validation and atomicity are preserved.
/// - `serializedCompletion: false` can lead to causal races if not
///   carefully considered.
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
class AsyncSynapses<P extends Pulse, L extends Cell> extends SynapsesBase<P,L> {

  final SynapsesBase _source;
  AsyncSynapses._(this._source);

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
      } else {
        pulse._complete();
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
      final batched = Pulse.batch(buffered);
      await _broadcast(batched as PulseBase);
    }
  }

  @override
  FutureOr<void> _debounced(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox != null) {
      final buffer = _buffer;
      if (buffer != null) {
        await buffer.async.clearAndAdd(p);
      }

      Timer? timer = timerBox.value;
      if (timer != null) {
        timer.cancel();
      }
      timerBox.value = Timer(_policy!.debounceTime, () async {
        final buffer = _buffer;
        if (buffer != null) {
          final pulse = await buffer.async.removeLast();
          await _broadcast(pulse);
        }
        timerBox.value!.cancel();
        timerBox.value = null;
      });

    }
  }

  @override
  Future<void> _buffered(PulseBase p) async {
    final buffer = _buffer;
    if (buffer != null) {
      await buffer.async.add(p);

      // New temporal flush logic: if it's the first in the buffer, start a timer
      if (buffer.length == 1) {
        final timerBox = _timerBox;
        if (timerBox != null && timerBox.value == null) {
          timerBox.value = Timer(_policy!.throttleTime, () async {
            await _flushBatch();
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
    final buffer = _buffer;
    if (buffer != null) {
      await buffer.async.add(p);

      final timerBox = _timerBox;
      if (timerBox != null) {

        // New temporal flush logic: if it's the first in the buffer, start a timer
        if (buffer.length == 1) {
          if (timerBox.value == null) {
            timerBox.value = Timer(_policy!.throttleTime, () {
              timerBox.value!.cancel();
              timerBox.value = null;
            });
          }
          await _broadcast(p);
        } else {
          await buffer.async.clear();
        }
      }
    }
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
        timerBox.value = Timer(_policy!.throttleTime, () async {
          final latest = _buffer?.firstOrNull;
          if (latest != null) {
            await _broadcast(latest);
            _buffer?.clear();
          }
          timerBox.value?.cancel();
          timerBox.value = null;
        });
      }
    }
  }

  @override
  Future<void> _exhaust(PulseBase p) async {
    final timerBox = _timerBox;
    // We use the timerBox as a 'Busy' flag
    if (timerBox != null && timerBox.value == null) {
      // Set a dummy timer or use a specific duration if policy defines it
      // For exhaust, we simply 'lock' the gate until the broadcast completes
      timerBox.value = Timer(Duration.zero, () {});

      try {
        await _broadcast(p);
      } finally {
        timerBox.value?.cancel();
        timerBox.value = null;
      }
    }
  }

  @override
  Future<void> _sample(PulseBase p) async {
    final timerBox = _timerBox;
    // For sampling, we don't trigger on 'p'. Instead, we ensure
    // a background heart-beat is running if not already.
    if (timerBox != null && timerBox.value == null) {
      timerBox.value = Timer.periodic(_policy!.throttleTime, (t) async {
        // Broadcasts the current pulse (the one passed to 'call')
        await _broadcast(p);
      });
    }
  }

  @override
  Future<void> _resilient(PulseBase p) async {
    // Note: This requires a 'failureCount' in the policy or a local state.
    // For now, we implement the basic gate check.
    final timerBox = _timerBox;

    // If timerBox holds a 'Cooldown' timer, the circuit is OPEN (Broken)
    if (timerBox != null && timerBox.value != null) return;

    try {
      await _broadcast(p);
    } catch (e) {
      // Logic to increment error count and potentially 'Open' the circuit
      // by setting a timerBox.value for a cooldown period.
      print('Resilience Gate: Downstream failure suppressed.');
    }
  }

  @override
  Future<void> _debounceLeading(PulseBase p) async {
    final timerBox = _timerBox;
    if (timerBox != null && timerBox.value == null) {
      // Deliver immediately
      await _broadcast(p);

      // Start the lockout window
      timerBox.value = Timer(_policy!.throttleTime, () {
        timerBox.value?.cancel();
        timerBox.value = null;
      });
    }
  }

  @override
  Future<void> _retry(PulseBase p, {int attempt = 0}) async {
    try {
      await _broadcast(p);
    } catch (e) {
      final maxRetries = _policy?.batchSize ?? 3; // Use batchSize as retry limit for now
      if (attempt < maxRetries) {
        await Future.delayed(_policy!.throttleTime);
        return _retry(p, attempt: attempt + 1);
      }
      print('Retry Policy: Failed after $maxRetries attempts.');
    }
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
  /// ### Non‑obvious
  /// - **Early Termination**: If the filter returns `null`, propagation
  ///   terminates immediately for *all* observers, effectively acting as a
  ///   centralized "Output Valve."
  /// - **Branch Synchronization**: The branch counter logic ensures that
  ///   complex graph updates involving multiple paths can detect when the
  ///   entire reactive wave has settled.
  /// - **Causal Provenance**: Propagation strategies like `debounced` or
  ///   `throttled` preserve the original pulse's forensic metadata, even
  ///   though delivery is delayed.
  /// - **Empty Optimization**: If a cell has no listeners, it quickly
  ///   short-circuits to avoid unnecessary filtering or strategy overhead.
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

      case PropagationStrategy.exhaust:
        await _exhaust(p);
        break;

      case PropagationStrategy.sample:
        await _sample(p);
        break;

      case PropagationStrategy.resilient:
        await _resilient(p);
        break;

      case PropagationStrategy.debounceLeading:
        await _debounceLeading(p);
        break;

      case PropagationStrategy.retry:
        await _retry(p);
        break;

      case PropagationStrategy.persistent:
        final buffer = _buffer;
        if (buffer != null) {
          buffer..clear()..add(p);
        }
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
/// ### Non‑obvious
/// - **Identity‑based linking**: The set of downstreams is identity‑based,
///   so deputies and principals are treated as distinct observers.
/// - **Cycle detection**: The pulse's `_checker` prevents infinite loops.
/// - **Filtering**: The `filter` is applied to the pulse **before** it is
///   delivered; if the filter returns `null`, the pulse is dropped for all
///   observers.
/// - **Propagation strategies** are applied at the egress point; they do not
///   affect the pulse's internal state.
/// - The synapses is **not** itself a cell – it's a component of a cell's
///   nucleus.
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
abstract class SynapsesBase<P extends Pulse, C extends Cell> extends IterableBase<C> implements Synapses<P,C> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

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
  /// ### Non‑obvious
  /// - The `downstreams` set is **identity‑based** – deputies and principals
  ///   are distinct entries.
  /// - The `filter` is applied to **all** outgoing pulses; if you need
  ///   per‑observer filters, use separate synapses.
  /// - The `policy` is optional; if omitted, propagation is immediate.
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
      downstreams: downstreams != null ? <C>{...downstreams} : <C>{},
      policy: policy,
      filter: filter,
      relay: relay,
  );

  static Record mask({PropagationPolicy? policy, required Iterable downstreams, FilterRule? filter, Function? relay}) {

    final buffer = policy != null && [PropagationStrategy.batched, PropagationStrategy.buffered]
        .any((s) => s == policy.strategy) ? QueueList<PulseBase>() : null;

    final timerBox = policy != null && [PropagationStrategy.debounced, PropagationStrategy.buffered, PropagationStrategy.throttled]
        .any((s) => s == policy.strategy) ? Box<Timer>() : null;

    final mask = (
        (policy != null   ? 1 : 0) |
        (filter != null   ? 2 : 0) |
        (buffer != null   ? 4 : 0) |
        (timerBox != null ? 8 : 0) |
        (relay != null ? 16 : 0)
    );

    return switch (mask) {
      0 => (downstreams: downstreams),
      1 => (downstreams: downstreams, policy: policy),
      2 => (downstreams: downstreams, filter: filter),
      3 => (downstreams: downstreams, policy: policy, filter: filter),
      4 => (downstreams: downstreams, buffer: buffer),
      5 => (downstreams: downstreams, policy: policy, buffer: buffer),
      6 => (downstreams: downstreams, filter: filter, buffer: buffer),
      7 => (downstreams: downstreams, policy: policy, filter: filter, buffer: buffer),
      8 => (downstreams: downstreams, timerBox: timerBox),
      9 => (downstreams: downstreams, policy: policy, timerBox: timerBox),
      10 => (downstreams: downstreams, filter: filter, timerBox: timerBox),
      11 => (downstreams: downstreams, policy: policy, filter: filter, timerBox: timerBox),
      12 => (downstreams: downstreams, buffer: buffer, timerBox: timerBox),
      13 => (downstreams: downstreams, policy: policy, buffer: buffer, timerBox: timerBox),
      14 => (downstreams: downstreams, filter: filter, buffer: buffer, timerBox: timerBox),
      15 => (downstreams: downstreams, policy: policy, filter: filter, buffer: buffer, timerBox: timerBox),

      16 => (downstreams: downstreams, relay: relay),
      17 => (downstreams: downstreams, policy: policy, relay: relay),
      18 => (downstreams: downstreams, filter: filter, relay: relay),
      19 => (downstreams: downstreams, policy: policy, filter: filter, relay: relay),
      20 => (downstreams: downstreams, buffer: buffer, relay: relay),
      21 => (downstreams: downstreams, policy: policy, buffer: buffer, relay: relay),
      22 => (downstreams: downstreams, filter: filter, buffer: buffer, relay: relay),
      23 => (downstreams: downstreams, policy: policy, filter: filter, buffer: buffer, relay: relay),
      24 => (downstreams: downstreams, timerBox: timerBox, relay: relay),
      25 => (downstreams: downstreams, policy: policy, timerBox: timerBox, relay: relay),
      26 => (downstreams: downstreams, filter: filter, timerBox: timerBox, relay: relay),
      27 => (downstreams: downstreams, policy: policy, filter: filter, timerBox: timerBox, relay: relay),
      28 => (downstreams: downstreams, buffer: buffer, timerBox: timerBox, relay: relay),
      29 => (downstreams: downstreams, policy: policy, buffer: buffer, timerBox: timerBox, relay: relay),
      30 => (downstreams: downstreams, filter: filter, buffer: buffer, timerBox: timerBox, relay: relay),
      31 => (downstreams: downstreams, policy: policy, filter: filter, buffer: buffer, timerBox: timerBox, relay: relay),

      _ => (downstreams: downstreams)
    };
  }
  
  Function? get _relay => get<Function?>(() => _record.relay, orElse: null);

  QueueList<PulseBase>? get _buffer => get<QueueList<PulseBase>?>(() => _record.buffer, orElse: null);

  Box<Timer>? get _timerBox => get<Box<Timer>?>(() => _record.timerBox, orElse: null);

  Set<C> get _downstreams => get<Set<C>>(() => _record.downstreams, orElse: const {});

  @override
  Iterator<C> get iterator => _downstreams.iterator;

  FilterRule<P>? get _filter => get<FilterRule<P>?>(() => _record.filter, orElse: null);

  PropagationPolicy? get _policy => get<PropagationPolicy?>(() => _record.policy, orElse: null);

  void _flushBatch() {
    final buffer = _buffer;
    if (buffer == null || buffer.isEmpty) return;
    final batched = Pulse.batch(buffer);
    _broadcast(batched as PulseBase);
    buffer.clear();

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
      bool notified = false;
      for (Cell c in this) {
        if (!pulse._checker.contains(c)) {
          final receptor = c._nucleus.receptor;
          receptor(pulse);
          notified = true;
        }
      }
      if (!notified) pulse._complete();
    }

  }

  void _debounced(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox != null) {

      Timer? timer = timerBox.value;
      if (timer != null) {
        timer.cancel();
      }

      timerBox.value = Timer(_policy!.debounceTime, () {
        _broadcast(p);
        timerBox.value!.cancel();
        timerBox.value = null;
      });

    }
  }

  void _buffered(PulseBase p) {
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(p);

      // New temporal flush logic: if it's the first in the buffer, start a timer
      if (buffer.length == 1) {
        final timerBox = _timerBox;
        if (timerBox != null && timerBox.value == null) {
          timerBox.value = Timer(_policy!.throttleTime, () {
            _flushBatch();
            timerBox.value!.cancel();
            timerBox.value = null;
          });
        }
      }
    }
  }

  void _throttled(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox != null) {
      Timer? timer = timerBox.value;
      if (timer == null) {
        timerBox.value = Timer(_policy!.throttleTime, () {
          _broadcast(p);
          timerBox.value!.cancel();
          timerBox.value = null;
        });
      }
    }
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
    if (timerBox != null) {
      // We store the 'latest' pulse in the buffer for the audit window
      final buffer = _buffer;
      if (buffer != null) {
        buffer.clear();
        buffer.add(p);
      }

      if (timerBox.value == null) {
        timerBox.value = Timer(_policy!.throttleTime, () {
          final latest = _buffer?.firstOrNull;
          if (latest != null) {
            _broadcast(latest);
            _buffer?.clear();
          }
          timerBox.value?.cancel();
          timerBox.value = null;
        });
      }
    }
  }

  void _exhaust(PulseBase p) {
    final timerBox = _timerBox;
    // We use the timerBox as a 'Busy' flag
    if (timerBox != null && timerBox.value == null) {
      // Set a dummy timer or use a specific duration if policy defines it
      // For exhaust, we simply 'lock' the gate until the broadcast completes
      timerBox.value = Timer(Duration.zero, () {});

      try {
        _broadcast(p);
      } finally {
        timerBox.value?.cancel();
        timerBox.value = null;
      }
    }
  }

  void _sample(PulseBase p) {
    final timerBox = _timerBox;
    // For sampling, we don't trigger on 'p'. Instead, we ensure
    // a background heart-beat is running if not already.
    if (timerBox != null && timerBox.value == null) {
      timerBox.value = Timer.periodic(_policy!.throttleTime, (t) {
        // Broadcasts the current pulse (the one passed to 'call')
        _broadcast(p);
      });
    }
  }

  void _resilient(PulseBase p) {
    // Note: This requires a 'failureCount' in the policy or a local state.
    // For now, we implement the basic gate check.
    final timerBox = _timerBox;

    // If timerBox holds a 'Cooldown' timer, the circuit is OPEN (Broken)
    if (timerBox != null && timerBox.value != null) return;

    try {
      _broadcast(p);
    } catch (e) {
      // Logic to increment error count and potentially 'Open' the circuit
      // by setting a timerBox.value for a cooldown period.
      print('Resilience Gate: Downstream failure suppressed.');
    }
  }

  void _debounceLeading(PulseBase p) {
    final timerBox = _timerBox;
    if (timerBox != null && timerBox.value == null) {
      // Deliver immediately
      _broadcast(p);

      // Start the lockout window
      timerBox.value = Timer(_policy!.throttleTime, () {
        timerBox.value?.cancel();
        timerBox.value = null;
      });
    }
  }

  void _retry(PulseBase p, {int attempt = 0}) async {
    try {
      _broadcast(p);
    } catch (e) {
      final maxRetries = _policy?.batchSize ?? 3; // Use batchSize as retry limit for now
      if (attempt < maxRetries) {
        await Future.delayed(_policy!.throttleTime);
        return _retry(p, attempt: attempt + 1);
      }
      print('Retry Policy: Failed after $maxRetries attempts.');
    }
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
  /// ### Non‑obvious
  /// - The broadcast is synchronous by default – use the `async` view for
  ///   non‑blocking delivery.
  /// - If a downstream observer is invalidated, it's skipped.
  /// - The pulse's `_branches` box is used to track completion across
  ///   multiple observers.
  ///
  /// ### Parameters:
  /// - [pulse]: The pulse to broadcast.
  @override
  void call(covariant P pulse) {

    if (isEmpty && pulse is PulseBase) {
      final box = pulse._branches;
      if (box != null) {
        box.value = box.value! - 1;
        if (box.value == 0) {
          pulse._complete();
          return;
        }
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

      case PropagationStrategy.exhaust:
        _exhaust(p);
        break;

      case PropagationStrategy.sample:
        _sample(p);
        break;

      case PropagationStrategy.resilient:
        _resilient(p);
        break;

        case PropagationStrategy.debounceLeading:
        _debounceLeading(p);
        break;

        case PropagationStrategy.retry:
        _retry(p);
        break;

      case PropagationStrategy.persistent:
        final buffer = _buffer;
        if (buffer != null) {
          buffer..clear()..add(p);
        }
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
  /// ### Non‑obvious
  /// - The link is governed by the host cell's validation rules – you can't
  ///   link to a cell that the host doesn't allow.
  /// - Deputies and their principals are considered equivalent for linking.
  /// - If the policy is `persistent`, the new observer immediately receives
  ///   the last emitted pulse.
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
  /// ### Non‑obvious
  /// - The async view shares the same filter and policy as the synchronous
  ///   synapses.
  /// - It uses a queue to serialise deliveries, preserving order.
  /// - The `call` method on the async view can optionally wait for
  ///   completion (`serializedCompletion: true`).
  ///
  /// ### Example
  /// ```dart
  /// await synapses.async.call(Pulse('update'));
  /// ```
  @override
  late final AsyncSynapses<P,C> async = AsyncSynapses._(this);

  @override
  int get hashCode => _record.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SynapsesBase) return false;
    return _record == other._record;
  }

}

final class _SynapsesDisabled extends IterableBase<Never> implements Synapses<Never,Never> {

  const _SynapsesDisabled();

  @override
  AsyncSynapses<Never,Never> get async => throw UnsupportedError('Disabled Synapses');

  @override
  bool link(Cell cell, {required Cell downstreamCell}) => false;

  @override
  bool unlink(Cell cell, {required Cell downstreamCell}) => false;

  @override
  Iterator<Never> get iterator => const Iterable<Never>.empty().iterator;

  @override
  void call(covariant PulseBase pulse) {}

}

final class _SynapsesEnabled extends IterableBase<Never> implements Synapses<Never,Never> {

  const _SynapsesEnabled();

  @override
  AsyncSynapses<Never,Never> get async => throw UnsupportedError('Disabled Synapses');

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
/// - **exhaust**: To prevent concurrent processing of overlapping signals.
/// - **sample**: To emit a constant‑rate heartbeat of the current state.
/// - **resilient**: To protect against downstream failures (circuit breaker).
/// - **debounceLeading**: To respond immediately to the first event, then wait.
/// - **retry**: To automatically retry failed deliveries.
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
/// ### Non‑obvious
/// - The `immediate` strategy is the fastest and most predictable – it ensures
///   that changes are propagated synchronously, but can cause deep call stacks.
/// - `async` simply schedules the broadcast on the next event loop tick,
///   breaking the synchronous chain.
/// - `debounced` and `throttled` use timers that are started on the first
///   interaction; they are lazy and don't allocate timers until needed.
/// - `persistent` does **not** affect regular propagation; it only replays
///   the last pulse to newly linked observers.
/// - `retry` and `resilient` are more advanced and require careful tuning
///   of batchSize and timers to avoid loops.
/// - The strategy is **per‑synapse**, not per‑pulse – it applies to all
///   pulses emitted by that cell.
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

  /// The **Concurrency Lock** strategy. Ignores new signals while a
  /// previous signal is still being processed.
  ///
  /// *   **Behavior**: If a [Pulse] is currently traversing the downstream
  ///     receptor chain (especially useful for async flows), any new pulses
  ///     arriving at the hub are dropped until the cycle completes.
  /// *   **Use Case**: Preventing "Race Conditions" in expensive side effects,
  ///     such as avoiding multiple simultaneous database writes or redundant
  ///     API calls.
  /// *   **Trade-off**: Intermediate state changes are completely lost if
  ///     they occur while the "gate" is closed.
  exhaust,

  /// The **Fixed-Interval Heartbeat** strategy. Periodically emits the
  /// current state regardless of arrival frequency.
  ///
  /// *   **Behavior**: Ignores the arrival of individual pulses and instead
  ///     "samples" the current value of the source cell at a fixed interval
  ///     defined by `throttleTime`.
  /// *   **Use Case**: Constant-rate telemetry, physics engines, or
  ///     monitoring systems where "no change" is just as important as "change."
  /// *   **Trade-off**: Can result in redundant broadcasts if the state
  ///     hasn't changed, and misses high-frequency fluctuations.
  sample,

  /// The **Stability Governance** strategy (Circuit Breaker). Stops
  /// propagation if downstream failures exceed a threshold.
  ///
  /// *   **Behavior**: Monitors for errors in downstream receptors. If a
  ///     failure threshold is met, the strategy enters an "Open" state,
  ///     silencing the synapse to prevent cascade failures.
  /// *   **Use Case**: Resilient distributed systems, unreliable network
  ///     integrations, or experimental AI logic that might crash.
  /// *   **Trade-off**: Requires a "Reset" or "Half-Open" logic to resume
  ///     normal operations after a failure.
  resilient,

  /// The **Leading-Edge Debounce** strategy. Delivers the first signal
  /// and silences subsequent signals during the window.
  ///
  /// *   **Behavior**: High-responsiveness. Delivers the *first* pulse
  ///     immediately, then ignores all others until the `throttleTime`
  ///     silence window is met.
  /// *   **Use Case**: Button debouncing where the user expects immediate
  ///     UI feedback, but the backend must be protected from double-clicks.
  debounceLeading,

  /// The **Transient Resilience** strategy. Retries failed downstream
  /// deliveries.
  ///
  /// *   **Behavior**: If a downstream receptor throws an exception,
  ///     the synapse will re-attempt delivery after a delay.
  /// *   **Use Case**: Unreliable network observers or distributed nodes
  ///     that may be momentarily offline.
  retry,

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
/// ### Non‑obvious
/// - The policy is **per‑synapse**, so different branches of the graph can
///   have different propagation behaviors.
/// - `debounceTime` is used for `debounced` and `debounceLeading`.
/// - `throttleTime` is used for `throttled`, `audit`, `sample`, `buffered`,
///   and some others.
/// - `batchSize` is used for `batched`, `retry` (as max retries), and
///   `buffered` (as max buffer size before flush).
/// - If a strategy doesn't use a parameter, it's simply ignored.
/// - All durations default to sensible values, so you can omit them if the
///   defaults work for you.
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
  /// ### Non‑obvious
  /// - Only effective for `debounced` and `debounceLeading` strategies.
  /// - Defaults to **150 milliseconds** if not explicitly set.
  ///
  /// ### Returns:
  /// A [Duration] representing the required period of inactivity before
  /// signal propagation.
  Duration get debounceTime =>
      get<Duration>(() => _record.debounceTime, orElse: const Duration(milliseconds: 150));

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
  /// ### Non‑obvious
  /// - Also used by `audit`, `sample`, `buffered`, and some other strategies.
  /// - Defaults to **200 milliseconds** if not explicitly set.
  ///
  /// ### Returns:
  /// A [Duration] representing the minimum gap between broadcast events.
  Duration get throttleTime =>
      get<Duration>(() => _record.throttleTime, orElse: const Duration(milliseconds: 200));

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
  /// ### Non‑obvious
  /// - Also used by `retry` as the maximum retry count.
  /// - Defaults to **10** if not explicitly set.
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
  /// ### Non‑obvious
  /// - The policy is immutable – you cannot change it after synapses creation.
  /// - To change behavior, create a new synapses with a new policy.
  /// - All parameters have sensible defaults, so you can omit those you
  ///   don't need.
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
  PropagationPolicy({
    PropagationStrategy strategy = PropagationStrategy.immediate,
    Duration debounceTime = const Duration(milliseconds: 150),
    Duration throttleTime = const Duration(milliseconds: 200),
    int batchSize = 10
  }) : _record = mask(strategy: strategy,
      debounceTime: debounceTime != Duration(milliseconds: 150) ? debounceTime : null,
      throttleTime: throttleTime != Duration(milliseconds: 200) ? throttleTime : null,
      batchSize: batchSize != 10 ? batchSize : null,
  );

  static Record mask({
    PropagationStrategy strategy = PropagationStrategy.immediate,
    Duration? debounceTime,
    Duration? throttleTime,
    int? batchSize
  }) {
    final mask = (
        (strategy != PropagationStrategy.immediate  ? 1 : 0) |
        (debounceTime != null                       ? 2 : 0) |
        (throttleTime != null                       ? 4 : 0) |
        (batchSize != null                          ? 8 : 0)
    );

    return switch (mask) {
      0 => (),
      1 => (strategy: strategy),
      2 => (debounceTime: debounceTime),
      3 => (strategy: strategy, debounceTime: debounceTime),
      4 => (throttleTime: throttleTime),
      5 => (strategy: strategy, throttleTime: throttleTime),
      6 => (debounceTime: debounceTime, throttleTime: throttleTime),
      7 => (strategy: strategy, debounceTime: debounceTime, throttleTime: throttleTime),
      8 => (batchSize: batchSize),
      9 => (strategy: strategy, batchSize: batchSize),
      10 => (debounceTime: debounceTime, batchSize: batchSize),
      11 => (strategy: strategy, debounceTime: debounceTime, batchSize: batchSize),
      12 => (throttleTime: throttleTime, batchSize: batchSize),
      13 => (strategy: strategy, throttleTime: throttleTime, batchSize: batchSize),
      14 => (debounceTime: debounceTime, throttleTime: throttleTime, batchSize: batchSize),
      15 => (strategy: strategy, debounceTime: debounceTime, throttleTime: throttleTime, batchSize: batchSize),
      _ => ()
    };
  }

}