// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

/// A concrete implementation of [CollectivePulse] that bundles multiple pulses
/// into a single atomic unit.
///
/// ### When to use
/// * You never construct this directly — it's created by [Pulse.batch] or the
///   `+` operator. This class is the internal engine that makes collective
///   pulses work.
///
/// ### How it works
/// The constructor accepts an iterable of pulses and stores them as the
/// collective's payload. It also sets up the branch counter to track when all
/// sub‑pulses have completed.
///
/// ### Non‑obvious: branch counter tracks completion
/// The `_branches` counter is incremented in the superclass constructor. This
/// counter ensures that the collective's completion callback fires only when
/// **all** sub‑pulses have finished processing.
class _CollectivePulse<P> extends CollectivePulseBase<P> {

  _CollectivePulse(Iterable<Pulse<P>> pulses, {
    super.policy,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    void Function(Pulse pulse)? super.onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? super.onError,
    void Function(Pulse pulse, Cell cell, {String? message})? super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
    super.priority,
  }) : super(pulses: pulses);

}

/// The abstract base class for [CollectivePulse] implementations.
///
/// A [CollectivePulseBase] is the internal engine that bundles multiple
/// independent pulses into a single atomic wave. Each sub‑pulse retains its
/// own identity, trace, and lifecycle — they travel together but remain
/// distinct.
///
/// ### How it works
/// - Extends [_SinglePulseBase] with a payload of type `Iterable<Pulse<P>>`.
/// - Overrides `isComposite` to return `true`, marking this as a bundle.
/// - Provides the `payload` getter that returns the bundled pulses.
/// - Manages the branch counter for completion tracking across all sub‑pulses.
///
/// ### Non‑obvious: the collective iterates over itself, not its payload
/// The `iterator` returns an iterator over the collective itself (a single
/// element), not over the individual pulses. This is by design — the
/// collective is a single unit that happens to contain multiple pulses.
/// To access individual pulses, use the `payload` getter:
/// ```dart
/// for (final p in collective.payload) {
///   print(p.payload);
/// }
/// ```
///
/// ### Non‑obvious: the branch counter tracks completion
/// The `_branches` counter is incremented in the constructor. This counter
/// ensures that the collective's completion callback fires only when **all**
/// sub‑pulses have finished processing. Without this, the framework wouldn't
/// know when a composite pulse is truly complete.
///
/// ### Example
/// ```dart
/// // You never create this directly — the framework does it for you:
/// final collective = Pulse.batch([pulse1, pulse2, pulse3]);
/// // collective is a CollectivePulseBase instance
/// ```
///
/// See also:
/// - [CollectivePulse] – the public interface.
/// - [Pulse.batch] – the factory that creates collective pulses.
/// - [Pulse.+] – the operator that creates collective pulses.
abstract class CollectivePulseBase<P>
    extends _SinglePulseBase<Iterable<Pulse<P>>> implements CollectivePulse<P> {

  /// Creates a new collective pulse that bundles multiple individual pulses.
  ///
  /// ### How it works
  /// - Accepts an iterable of pulses to bundle.
  /// - Passes all metadata (policy, context, type, etc.) to the superclass.
  /// - Increments the `_branches` counter to track completion of all
  ///   sub‑pulses.
  /// - The resulting collective is a single unit that moves through the
  ///   graph atomically.
  ///
  /// ### Non‑obvious: the branch counter is critical for completion
  /// The `_branches` counter is incremented here. Each sub‑pulse
  /// decrements the counter when it completes. When the counter reaches
  /// zero, the collective's completion callback fires. This is how the
  /// framework knows when a composite pulse is fully processed.
  ///
  /// ### Non‑obvious: metadata is applied to the collective, not sub‑pulses
  /// The [policy], [context], [type], and other metadata are applied to the
  /// collective as a whole, not to individual sub‑pulses. Each sub‑pulse
  /// retains its own metadata.
  ///
  /// ### Parameters:
  /// - [pulses]: The individual pulses to bundle into a collective.
  /// - [policy]: Optional lifecycle policy for the collective (TTL, hop limit).
  /// - [type]: Optional semantic tag for the collective.
  /// - [context]: Optional provenance context for the collective.
  /// - [timestamp]: Optional creation time (defaults to now).
  /// - [source]: Optional originating cell.
  /// - [step]: Optional trace step for the collective.
  /// - [onComplete]: Called when all sub‑pulses complete.
  /// - [onError]: Called if any sub‑pulse fails.
  /// - [onProgress]: Called during processing.
  /// - [pulse]: Optional sub‑pulse to append (for evolution).
  /// - [parent]: Optional parent pulse (for causal chains).
  /// - [scrutinize]: Optional authorization challenge function.
  /// - [user]: Optional user‑defined metadata.
  /// - [priority]: Optional urgency (overrides individual priorities).
  ///
  /// ### Returns:
  /// A new [CollectivePulseBase] instance that bundles all the provided
  /// pulses into a single atomic unit.
  ///
  /// ### Example
  /// ```dart
  /// // Internal usage — you never write this directly:
  /// final collective = CollectivePulseBase(
  ///   pulses: [pulse1, pulse2],
  ///   type: 'batch_update',
  ///   onComplete: (Pulse p) =>. print('Batch complete'),
  /// );
  /// ```
  CollectivePulseBase({
    Iterable<Pulse<P>>? pulses,
    super.policy,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
    super.priority
  }) : super(payload: pulses) {
    final branches = _branches;
    if (branches != null) {
      branches.value = branches.value! + 1;
    }
  }

  /// The collection of pulses bundled in this collective.
  ///
  /// ### When to use
  /// Use this to access the individual pulses in the collective.
  ///
  /// ### Non‑obvious: this is the entire iterable
  /// This returns **all** the pulses, not just the first one.
  @override
  Iterable<Pulse<P>> get payload => super.payload as Iterable<Pulse<P>>;

  /// Indicates that this pulse is a composite bundle.
  ///
  /// ### When to use
  /// Check this to know if a pulse contains multiple sub‑pulses.
  @override
  bool get isComposite => true;

  /// Returns an iterator over this collective itself.
  ///
  /// ### Non‑obvious: this returns a single element
  /// Iterating over a collective yields the collective itself, not its
  /// constituent pulses. To access individual pulses, use the `payload` getter.
  @override
  Iterator<CollectivePulseBase<P>> get iterator => [this].iterator;

  @override
  String toString() => 'CollectivePulse<$P>($_toString)';

}

/// A concrete implementation of [EvolvedPulse] that represents a causal chain.
///
/// ### How it works
/// The constructor accepts a parent pulse and stores it. The branch counter
/// is incremented to track completion across the chain.
///
/// ### Non‑obvious: evolved pulses are immutable
/// Once created, an evolved pulse never changes. The parent chain is fixed
/// at construction time.
class _EvolvedPulse<P> extends EvolvedPulseBase<P> {

  _EvolvedPulse({
    super.policy,
    super.payload,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    void Function(Pulse pulse)? super.onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? super.onError,
    void Function(Pulse pulse, Cell cell, {String? message})? super.onProgress,
    required super.pulse,
    required super.parent,
  }) : super();

}

/// The abstract base class for [EvolvedPulse] implementations.
///
/// An [EvolvedPulseBase] is the internal engine that builds causal chains.
/// Each evolved pulse links back to its parent, preserving the signal's
/// lineage without duplicating data. This is how the framework maintains
/// full provenance with minimal memory overhead.
///
/// ### How it works
/// - Extends [_Pulse] and implements [EvolvedPulse].
/// - Overrides `isComposite` to return `true`, marking this as a chain.
/// - Provides the `parent` getter that returns the immediate ancestor.
/// - Builds a flattened list of all pulses in the chain for iteration.
/// - The payload is inherited from the last pulse in the chain.
///
/// ### Non‑obvious: evolution is not mutation
/// When you call [Pulse.evolve], you get a *new* pulse that points to the old
/// one. The old pulse is still there — unchanged, available for reference.
/// This is why you can trace the entire lineage without copying data.
///
/// ### Non‑obvious: payload is inherited, not copied
/// The `payload` getter returns the payload of the last pulse in the chain.
/// The data is inherited from the root — it's never duplicated. This is why
/// causal chains are memory‑efficient even when they're dozens of steps long.
///
/// ### Example
/// ```dart
/// // You never create this directly — the framework does it for you:
/// final root = Pulse(42);
/// final evolved = root.withStep('validation');
/// // evolved is an EvolvedPulseBase instance
/// ```
///
/// See also:
/// - [EvolvedPulse] – the public interface.
/// - [Pulse.evolve] – the method that creates evolved pulses.
/// - [Pulse.withStep] – a convenience wrapper around [evolve].
abstract class EvolvedPulseBase<P> extends _SinglePulseBase<P> implements EvolvedPulse<P> {

  final List<PulseBase> _pulses;

  /// Creates a new evolved pulse that extends a causal chain.
  ///
  /// ### How it works
  /// - Accepts metadata for the new evolved pulse.
  /// - Passes all parameters to the superclass constructor.
  /// - Increments the `_branches` counter to track completion of the chain.
  /// - The resulting pulse is a new node in the causal chain, linked to
  ///   its [parent] via the superclass.
  ///
  /// ### Non‑obvious: the branch counter tracks chain completion
  /// The `_branches` counter is incremented here. Each pulse in the chain
  /// decrements the counter when it completes. When the counter reaches zero,
  /// the chain's completion callback fires. This is how the framework knows
  /// when a causal chain is fully processed.
  ///
  /// ### Non‑obvious: metadata is additive
  /// When you evolve a pulse, the new metadata (context, step, etc.) is
  /// added to the chain. The original metadata is preserved in the parent.
  /// This is how the framework maintains full provenance — you can always
  /// walk back up the chain to see the complete history.
  ///
  /// ### Parameters:
  /// - [policy]: Optional lifecycle policy (TTL, hop limit).
  /// - [context]: Optional provenance context.
  /// - [payload]: The data carried by the pulse (inherited from root).
  /// - [type]: Optional semantic tag.
  /// - [timestamp]: Optional creation time (defaults to now).
  /// - [source]: Optional originating cell.
  /// - [step]: Optional trace step (added to the chain).
  /// - [priority]: Optional urgency.
  /// - [onComplete]: Called when the pulse completes.
  /// - [onError]: Called if the pulse fails.
  /// - [onProgress]: Called during processing.
  /// - [pulse]: Optional sub‑pulse to append.
  /// - [parent]: The parent pulse in the causal chain.
  ///
  /// ### Returns:
  /// A new [EvolvedPulseBase] instance that extends the causal chain.
  ///
  /// ### Example
  /// ```dart
  /// // Internal usage — you never write this directly:
  /// final evolved = EvolvedPulseBase(
  ///   step: 'validation',
  ///   parent: rootPulse,
  ///   onComplete: (Pulse p) =>. print('Chain complete'),
  /// );
  /// ```
  EvolvedPulseBase({
    super.policy,
    super.context,

    super.payload,
    super.type,
    super.timestamp,
    super.source,
    super.step,
    super.priority,

    super.onComplete,
    super.onError,
    super.onProgress,
    required PulseBase pulse,
    required PulseBase<P> parent,
  }) : _pulses = pulse is EvolvedPulseBase ? [...pulse._pulses, pulse] : [parent, pulse], super(pulse: pulse, parent: parent) {
    final branches = _branches;
    if (branches != null) {
      branches.value = branches.value! + 1;
    }
  }

  @override
  bool get isComposite => true;

  @override
  Pulse<P> get parent => _parent!;

  @override
  P? get payload {
    return _pulses.last.payload;
  }

  @override
  Iterator<PulseBase> get iterator => _pulses.iterator;

  @override
  String toString() => 'EvolvedPulse<$P>($_toString)';

}

/// A concrete implementation of a standard (non‑composite) pulse.
///
/// ### When to use
/// * You never construct this directly — it's created by the [Pulse] factory
///   constructors. This class is the internal engine for all basic pulses.
///
/// ### How it works
/// - Extends [_SinglePulseBase] with a payload of type `P`.
/// - Implements `iterator` to return a single element iterator.
///
/// ### Non‑obvious: this is a flyweight
/// Instances of this class are lightweight because they store only the
/// delta from their parent in a compact record.
class _Pulse<P> extends _SinglePulseBase<P> {
  _Pulse({
    super.policy,
    super.context,

    super.payload,
    super.type,
    super.timestamp,

    super.source,
    super.step,
    super.priority,

    super.onComplete,
    super.onError,
    super.onProgress,

    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
  }) : super();

}

/// The abstract base class for single (non‑composite) pulses.
///
/// ### When to use
/// * You never use this directly — it's the internal base for all atomic pulses.
///   It provides the core logic for single pulses that don't bundle others.
///
/// ### How it works
/// - Extends [PulseBase].
/// - Provides the `unmodifiable` getter that returns a read‑only projection.
/// - Implements a string representation that includes payload, source, type,
///   trace, and priority.
///
/// ### Non‑obvious: the string representation is computed lazily
/// The string representation is computed once and cached in `_toString` to
/// avoid repeated string building.
abstract class _SinglePulseBase<P> extends PulseBase<P> {

  _SinglePulseBase({
    super.policy,
    super.context,

    super.payload,
    super.type,
    super.timestamp,

    super.source,
    super.step,
    super.priority,

    super.onComplete,
    super.onError,
    super.onProgress,

    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
  }) : super();

  @override
  Iterator<PulseBase> get iterator => [this].iterator;

  @override
  PulseBase<P> get unmodifiable => UnmodifiablePulse<P>(this) as PulseBase<P>;

  late final String _toString = _computeToString();

  String _computeToString() {
    final mask = (
      (payload != null ? 1 : 0) |
      (source != null ? 2 : 0) |
      (type != null ? 4 : 0) |
      (trace.isNotEmpty ? 8 : 0)
    );

    final s = switch (mask) {
      0 => 'null, priority: $priority',
      1 => '$payload, priority: $priority',
      2 => 'null, source: $source, priority: $priority',
      3 => '$payload, source: $source, priority: $priority',
      4 => 'null, type: $type, priority: $priority',
      5 => '$payload, type: $type, priority: $priority',
      6 => 'null, source: $source, type: $type, priority: $priority',
      7 => '$payload, source: $source, type: $type, priority: $priority',
      8 => 'null, trace: $trace, priority: $priority',
      9 => '$payload, trace: $trace, priority: $priority',
      10 => 'null, source: $source, trace: $trace, priority: $priority',
      11 => '$payload, source: $source, trace: $trace, priority: $priority',
      12 => 'null, type: $type, trace: $trace, priority: $priority',
      13 => '$payload, type: $type, trace: $trace, priority: $priority',
      14 => 'null, source: $source, type: $type, trace: $trace, priority: $priority',
      15 => '$payload, source: $source, type: $type, trace: $trace, priority: $priority',
      _ => ('something is wrong with the mask: $mask')
    };
    return s;
  }

  @override
  String toString() => 'Pulse<$P>($_toString)';


}

abstract class PulseBase<P> with IterableMixin<Pulse> implements Pulse<P> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  PulseBase({
    PulseEphemeralPolicy? policy,
    PulseContext? context,

    P? payload,
    String? type,
    DateTime? timestamp,
    Cell? source,
    String? step,
    int? priority,

    Function? onComplete, // void Function(Pulse pulse)? onComplete,
    Function? onError, // void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    Function? onProgress, // void Function(Pulse pulse, Cell cell, {String? message})? onProgress,

    Pulse? pulse,
    Pulse<P>? parent,

    FutureOr<Pulse?> Function(Receptor receptor)? scrutinize,
    dynamic user
  }) : _record = mask(
          policy: policy,
          context: context,

          payload: payload,
          type: type,
          timestamp: timestamp ?? DateTime.now(),

          source: source,
          step: step,
          priority: priority,

          onComplete: onComplete,
          onError: onError,
          onProgress: onProgress,

          pulse: pulse,
          parent: parent,

          scrutinize: scrutinize,

          user: user
        );

  /// Creates a pulse from an existing record.
  ///
  /// ### When to use
  /// * This is used internally for cloning and deserialisation. You never
  ///   call it directly.
  /// * This constructor is used internally by the framework for:
  ///   - Cloning pulses (creating a copy with the same metadata).
  ///   - Deserialising pulses from a stored format.
  ///   - Framework extension points.
  ///
  /// ### How it works
  /// Directly assigns the provided record to `_record`. The record is
  /// assumed to be correctly shaped — no validation is performed.
  ///
  /// ### Non‑obvious: this bypasses the bitmask optimization
  /// Unlike the primary constructor, this does not call `mask`. It assumes
  /// the record is already correctly formed. This is why it's only used
  /// internally — to avoid the overhead of re‑masking when cloning.
  ///
  /// ### Parameters:
  /// - [record]: The record containing the pulse's metadata.
  ///
  /// ### Returns:
  /// A [PulseBase] instance with the provided record.
  const PulseBase.fromRecord(Record record) : _record = record;

  @override
  Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
  assert(
  pulse != null || step != null || context != null,
  'Pulse.evolve requires at least `pulse` or `step` or `context` not null.',
  );

    if (pulse == null && context == null) {
      return _Pulse<P>(step: step, parent: this);
    }

    return pulse is PulseBase<P>
        ? _EvolvedPulse<P>(context: context, step: step, pulse: pulse, parent: this)
        : _EvolvedPulse(context: context, step: step, pulse: pulse as PulseBase, parent: this);
  }

  @override
  Pulse<P> withStep(String step) => _Pulse<P>(step: step, parent: this);

  @override
  CollectivePulse operator +(covariant Pulse other) {
   return other is Pulse<P>
        ? other is CollectivePulse<P> ? _CollectivePulse<P>([this, other]) : _CollectivePulse<P>([this, other])
        : other is CollectivePulse ? _CollectivePulse([this, other]) : _CollectivePulse([this, other]);
  }

  @override
  PulseBase<P> get unmodifiable => UnmodifiablePulse<P>(this) as PulseBase<P>;

  CycleChecker get _checker {
    final finalBox = get<FinalBox<CycleChecker>>(() => root._record.cycleChecker);
    try {
      return finalBox.value as CycleChecker;
    } catch (e) {
      return finalBox.value = CycleChecker._();
    }
  }



  // ───── primary ─────

  /// Main payload.
  @override
  P? get payload {
    return get<P?>(() => _record.root.primary.payload,
        fallback: () => _pulse?.payload ?? _parent?.payload,
        orElse: null);
  }

  /// Origin cell (for tracing).
  @override
  Cell? get source {
    return get<Cell?>(() => _record.root.primary.source,
        fallback: () => _parent?.source, orElse: null);
  }

  /// When this pulse was created.
  @override
  DateTime get timestamp {
    return get<DateTime>(() => _record.root.primary.timestamp,
        fallback: () => _parent?.timestamp);
  }

  @override
  PulseEphemeralPolicy? get policy {
    return get<PulseEphemeralPolicy?>(() => _record.root.primary.policy,
        fallback: () => _parent?.policy, orElse: null);
  }

  // ───── secondary ─────

  /// Semantic type tag for pattern matching and routing.
  @override
  String? get type {
    return get<String?>(() => _record.root.secondary.type,
        fallback: () => _pulse?.type ?? _parent?.type, orElse: null);
  }

  @override
  int get priority {
    int local() {
      return get<int>(() => _record.root.tertiary.priority,
          fallback: () => _parent?.priority, orElse: Pulse.defaultPriority);
    }

    if (context != PulseContext.system) {
      return context.priority ?? local();
    }
    return local();

  }

  /// Execution/security context.
  @override
  PulseContext get context {
    return get<PulseContext>(() => _record.root.secondary.context,
        fallback: () => _parent?.context, orElse: PulseContext.system);
  }

  /// Causal trace path.
  @override
  List<String> get trace {
    final trace = <String>[];

    iterate(PulseBase? p) {
      String? step;
      while (p != null) {
        step = get<String?>(() => p!._record.root.secondary.step, orElse: null);
        if (step != null) {
          trace.add(step);
        }
        p = p._parent;
      }
    }

    iterate(this);

    return trace.reversed.toList(growable: false);
  }

  Function? get _scrutinize {
    return get<Function?>(() => _record.root.tertiary.scrutinize, orElse: null);
  }

  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {
    final scrutinize = _scrutinize;
    if (scrutinize != null) {
      try {
        if (namedArguments != null && namedArguments.containsKey(#serializedCompletion)) {
          return scrutinize(receptor, serializedCompletion: namedArguments[#serializedCompletion]);
        }
        return scrutinize(receptor);
      } catch (e) {
        return null;
      }
    }
    
    return receptor(this);
  }

  @override
  PulseShell<P,Receptor> get shell => PulseShell<P,Receptor>(this);

  /// The **Branch Completion Counter** for composite pulses.
  ///
  /// This internal getter tracks how many sub-pulses in a composite
  /// ([CollectivePulse] or [EvolvedPulse]) need to complete before the
  /// composite's completion callback can fire.
  ///
  /// ### When to use
  /// * This is an internal implementation detail. You never access this directly.
  ///   It exists to support the framework's composite pulse lifecycle management.
  /// * This is used internally by the framework. You don't need to use it
  ///   in application code.
  ///
  /// ### How it works
  /// 1. When a composite pulse is created, the `_branches` counter is
  ///    initialised to the number of sub-pulses.
  /// 2. As each sub-pulse completes, the counter is decremented.
  /// 3. When the counter reaches zero, the completion callback fires.
  /// 4. This mechanism ensures that a composite pulse only completes when
  ///    **all** of its constituent pulses have finished processing.
  ///
  /// ### Non‑obvious
  /// - The counter is stored in a [Box] – a mutable container that allows
  ///   the counter to be updated even though the pulse itself is immutable.
  /// - For atomic (non-composite) pulses, `_branches` is `null`.
  /// - The counter is incremented when a pulse is added to a composite,
  ///   and decremented when a sub-pulse completes.
  /// - If any sub-pulse is invalidated or filtered out, the counter
  ///   may not reach zero, and the completion callback will not fire.
  /// - The counter is thread-safe because pulse processing is serialised
  ///   through the cell's [Lock].
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final collective = Pulse.batch([pulse1, pulse2, pulse3]);
  /// // _branches.value == 3
  /// // After pulse1 completes: _branches.value == 2
  /// // After pulse2 completes: _branches.value == 1
  /// // After pulse3 completes: _branches.value == 0 -> onComplete fires
  /// ```
  ///
  /// ### Returns:
  /// A [Box<int>] containing the remaining branch count, or `null` if this
  /// is an atomic (non-composite) pulse.
  Box<int>? get _branches {
    return get<Box<int>?>(() => _record.root.callbacks.branches, orElse: null);
  }

  // ───── callbacks ─────
  /// The **Execution Confirmation** hook invoked upon the successful completion
  /// of the pulse's reactive cycle.
  ///
  /// The [_onComplete] getter provides the primary mechanism for **Imperative
  /// Synchronization**. It is emitted only after the pulse has successfully
  /// traversed the reactive graph, updated its target [Cell], and completed
  /// the notification of all downstream observers.
  ///
  /// ### When to use
  /// * You rarely access this directly. Instead, you provide an `onComplete`
  ///   callback when creating a governed pulse via [Pulse.governed] or
  ///   [Pulse.batch]. The framework invokes it automatically when the pulse
  ///   has finished its journey.
  /// * Coordinating side effects that must wait for graph stabilisation.
  /// * Triggering post-reactive actions like UI navigation or cache invalidation.
  /// * Logging the successful completion of a signal.
  /// * Chaining operations that depend on a full propagation cycle.
  ///
  /// ### How it works
  /// 1. The callback is stored in the pulse's record at creation time.
  /// 2. It is preserved through the `_parent` chain – even if the pulse is
  ///    [evolve]d multiple times, the original completion listener remains attached.
  /// 3. The callback is executed within the final phase of the conactive wave.
  /// 4. By the time [_onComplete] is called, the system has reached a
  ///    **Steady State**, and all related asynchronous side effects within
  ///    the reactive domain have been reconciled.
  /// 5. The callback receives the final, post-transformation [Pulse] instance
  ///    upon successful system-wide completion.
  ///
  /// ### Non‑obvious
  /// - The callback is **inherited** through the causal chain. If you attach
  ///   `onComplete` to a root pulse, it will fire even after the pulse has
  ///   been evolved multiple times.
  /// - For composite pulses ([CollectivePulse], [EvolvedPulse]), the callback
  ///   fires **only once** when all sub-pulses have completed. The `_branches`
  ///   counter tracks completion across all branches.
  /// - If the pulse is invalidated (TTL or hop limit exceeded), the completion
  ///   callback is **not** fired – instead, the error callback is triggered.
  /// - The callback is synchronous – it should not perform long-running
  ///   operations that would block the reactive wave.
  /// - The callback is **not** called if the pulse is filtered out by a
  ///   [TestCell] or [Receptor].
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<int>(
  ///   payload: 42,
  ///   onComplete: (pulse) {
  ///     print('Pulse fully processed: ${pulse.payload}');
  ///   },
  /// );
  /// receptor.call(pulse);
  /// // After propagation: "Pulse fully processed: 42"
  /// ```
  ///
  /// ### Returns:
  /// A nullable function that receives the final, post-transformation [Pulse]
  /// instance upon successful system-wide completion, or `null` if no
  /// completion callback was attached.
  void Function(Pulse pulse)? get _onComplete {
    return get<void Function(Pulse pulse)?>(
            () => _record.root.callbacks.onComplete,
        fallback: () => _parent?._onComplete,
        orElse: null);
  }

  /// The **Failure Feedback** hook invoked if the pulse encounters a processing
  /// error or is rejected by system policies.
  ///
  /// The [_onError] getter provides the primary **Exception Feedback Loop** for
  /// the reactive flow. It is triggered when a pulse cannot reach its
  /// destination or be successfully processed due to a validation failure
  /// (Policy Guard rejection) or an unhandled exception within a transformation
  /// pipeline ([Receptor]).
  ///
  /// ### When to use
  /// * You rarely access this directly. Instead, you provide an `onError`
  ///   callback when creating a governed pulse via [Pulse.governed] or
  ///   [Pulse.batch]. The framework invokes it automatically when the pulse
  ///   fails during propagation.
  /// * Handling validation failures (e.g., [TestCell] rejection).
  /// * Catching exceptions thrown by [Receptor] pipelines.
  /// * Logging errors for monitoring and debugging.
  /// * Implementing fallback logic when a signal cannot be processed.
  ///
  /// ### How it works
  /// 1. The callback is stored in the pulse's record at creation time.
  /// 2. It is preserved through the `_parent` chain – even if the pulse is
  ///    [evolve]d multiple times, the original error listener remains attached.
  /// 3. The callback is triggered when:
  ///    - A [TestCell] validation fails (Policy Guard rejection).
  ///    - A [Receptor] throws an unhandled exception.
  ///    - The pulse's TTL or hop limit is exceeded.
  /// 4. The callback receives the error object and an optional stack trace.
  /// 5. The framework ensures that the state transition is neutralized –
  ///    the reactive graph does not enter an inconsistent or "Partial Update"
  ///    state.
  ///
  /// ### Non‑obvious
  /// - The callback is **inherited** through the causal chain – an error
  ///   listener attached to the root pulse will be notified even if the
  ///   error occurs deep in a derived pulse.
  /// - For composite pulses, the error callback fires **once** for the
  ///   first error encountered, and processing of remaining sub-pulses
  ///   continues (the error does not cancel the entire composite).
  /// - The callback is synchronous – it should not perform long-running
  ///   operations that would block the reactive wave.
  /// - If both `onError` and `onComplete` are provided, `onError` takes
  ///   precedence – the completion callback is not fired if an error occurs.
  /// - The error callback is **not** called for expected filter outcomes
  ///   (e.g., a pulse returning `null` from a [Receptor]) – only for
  ///   actual exceptions or validation failures.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<int>(
  ///   payload: 42,
  ///   onError: (pulse, error, {stackTrace}) {
  ///     print('Pulse failed: $error');
  ///     // Implement fallback logic
  ///   },
  /// );
  /// receptor.call(pulse);
  /// // If validation fails: "Pulse failed: Validation rejected"
  /// ```
  ///
  /// ### Returns:
  /// A nullable function that receives the error object and optional stack
  /// trace upon a processing failure or policy rejection, or `null` if no
  /// error callback was attached.
  void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? get _onError {
    return get<void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?>(
            () => _record.root.callbacks.onError,
        fallback: () => _parent?._onError,
        orElse: null);
  }

  /// A callback invoked during high-latency or asynchronous operations to
  /// provide updates on the pulse's processing status.
  ///
  /// The [_onProgress] hook acts as a **Real-Time Status Monitor**. It is
  /// triggered as the pulse traverses computationally intensive handlers,
  /// cross-thread operations, or external I/O tasks, allowing the system
  /// to provide feedback before the final completion or error state is reached.
  ///
  /// ### When to use
  /// * You rarely access this directly. Instead, you provide an `onProgress`
  ///   callback when creating a governed pulse via [Pulse.governed] or
  ///   [Pulse.batch]. The framework invokes it automatically during the
  ///   pulse's traversal.
  /// * Tracking long-running operations (e.g., database queries, network calls).
  /// * Providing user feedback during complex transformations.
  /// * Debugging and monitoring pulse flow through the graph.
  /// * Implementing timeouts or progress bars for multi-step operations.
  ///
  /// ### How it works
  /// 1. The callback is stored in the pulse's record at creation time.
  /// 2. It is preserved through the `_parent` chain – even if the pulse is
  ///    [evolve]d multiple times, the original progress listener remains connected.
  /// 3. The callback is invoked when:
  ///    - A [Receptor] reports progress during execution.
  ///    - The pulse traverses a significant processing milestone.
  ///    - A [Cell] signals that it is processing the pulse.
  /// 4. The callback receives the active [Cell] and an optional `message`
  ///    describing the current stage of execution.
  /// 5. The callback is synchronous and should not block the reactive wave.
  ///
  /// ### Non‑obvious
  /// - The callback is **inherited** through the causal chain – a progress
  ///   listener attached to the root pulse will receive updates from all
  ///   derived pulses.
  /// - For composite pulses, progress callbacks may be triggered multiple
  ///   times – once for each sub-pulse that reports progress.
  /// - The callback is **not** guaranteed to be called for every step –
  ///   it depends on the receptors and cells implementing progress reporting.
  /// - The `message` parameter is optional and can be used to provide
  ///   contextual information (e.g., "50% complete", "Waiting for database").
  /// - The callback is synchronous – it should not perform expensive operations
  ///   that would slow down the reactive wave.
  /// - Progress callbacks are **not** fired if the pulse is invalidated or
  ///   filtered out – they only fire for actively processing pulses.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<int>(
  ///   payload: 42,
  ///   onProgress: (pulse, cell, {message}) {
  ///     print('Processing at ${cell.runtimeType}: $message');
  ///   },
  /// );
  /// receptor.call(pulse);
  /// // Outputs: "Processing at MyCell: validation started"
  /// // Outputs: "Processing at MyCell: validation complete"
  /// ```
  ///
  /// ### Returns:
  /// A nullable function that receives the active [Cell] and a status
  /// [String] during the pulse's lifecycle, or `null` if no progress
  /// callback was attached.
  void Function(Pulse pulse, Cell cell, {String? message})? get _onProgress {
    return get<void Function(Pulse pulse, Cell cell, {String? message})?>(
            () => _record.root.callbacks.onProgress,
        fallback: () => _parent?._onProgress,
        orElse: null);
  }

  // others

  PulseBase<P>? get _parent {
    return get<PulseBase<P>?>(() => _record.parent, orElse: null);
  }

  PulseBase<P>? get _pulse {
    return get<PulseBase<P>?>(() => _record.pulse, orElse: null);
  }

  dynamic get _user {
    return get<dynamic>(() => _record.root.tertiary.user, orElse: null);
  }

  @override
  PulseBase<P> get root {
    if (_parent == null) {
      return this;
    }

    PulseBase<P> p = this;
    PulseBase<P>? parent = _parent;
    while (parent != null) {
      p = parent;
      parent = p._parent;
    }
    return p;
  }

  @override
  bool get isInvalidated => policy?.isInvalidated ?? false;

  // ────────────────

  static Record mask({
    PulseEphemeralPolicy? policy,
    PulseContext? context,

    dynamic payload,
    String? type,
    DateTime? timestamp,
    Cell? source,
    String? step,

    Function? onComplete,
    Function? onError,
    Function? onProgress,

    int? priority,
    dynamic user,

    Pulse? pulse,
    Pulse? parent,

    Function? scrutinize,
  }) {

    final isGoverned = policy != null || context != null ? true : false;

    // Physical reality (Payload, Source, Timestamp, Policy).
    final primaryMask = (
        (payload != null ? 1 : 0) |
        (source != null ? 2 : 0) |
        (timestamp != null ? 4 : 0) |
        (policy != null ? 8 : 0) |
        (isGoverned ? 16 : 0)
    );

    final primary = switch (primaryMask) {
      0 => (),
      1 => (payload: payload),
      2 => (source: source),
      3 => (payload: payload, source: source),
      4 => (timestamp: timestamp),
      5 => (payload: payload, timestamp: timestamp),
      6 => (source: source, timestamp: timestamp),
      7 => (payload: payload, source: source, timestamp: timestamp),
      8 => (policy: policy),
      9 => (payload: payload, policy: policy),
      10 => (source: source, policy: policy),
      11 => (payload: payload, source: source, policy: policy),
      12 => (timestamp: timestamp, policy: policy),
      13 => (payload: payload, timestamp: timestamp, policy: policy),
      14 => (source: source, timestamp: timestamp, policy: policy),
      15 => (payload: payload, source: source, timestamp: timestamp, policy: policy),

      16 => (isGoverned: isGoverned),
      17 => (payload: payload, isGoverned: isGoverned),
      18 => (source: source, isGoverned: isGoverned),
      19 => (payload: payload, source: source, isGoverned: isGoverned),
      20 => (timestamp: timestamp, isGoverned: isGoverned),
      21 => (payload: payload, timestamp: timestamp, isGoverned: isGoverned),
      22 => (source: source, timestamp: timestamp, isGoverned: isGoverned),
      23 => (payload: payload, source: source, timestamp: timestamp, isGoverned: isGoverned),
      24 => (policy: policy, isGoverned: isGoverned),
      25 => (payload: payload, policy: policy, isGoverned: isGoverned),
      26 => (source: source, policy: policy, isGoverned: isGoverned),
      27 => (payload: payload, source: source, policy: policy, isGoverned: isGoverned),
      28 => (timestamp: timestamp, policy: policy, isGoverned: isGoverned),
      29 => (payload: payload, timestamp: timestamp, policy: policy, isGoverned: isGoverned),
      30 => (source: source, timestamp: timestamp, policy: policy, isGoverned: isGoverned),
      31 => (payload: payload, source: source, timestamp: timestamp, policy: policy, isGoverned: isGoverned),

      _ => ()
    };

    // Architectural placement (Type, Context, Metadata, Step).
    final secondaryMask = (
        (type != null ? 1 : 0) |
        (context != null ? 2 : 0) |
        (step != null ? 4 : 0)
    );

    final secondary = switch (secondaryMask) {
      0 => (),
      1 => (type: type),
      2 => (context: context),
      3 => (type: type, context: context),
      4 => (step: step),
      5 => (type: type, step: step),
      6 => (context: context, step: step),
      7 => (type: type, context: context, step: step),
      _ => ()
    };

    // Tertiary: Governance and Provenance (Priority, Actor, Reason).
    // This represents the "Who" and "Why" behind the signal,
    final tertiaryMask = (
        (priority != null ? 1 : 0) |
        (user != null ? 2 : 0) |
        (scrutinize != null ? 4 : 0)
    );

    final tertiary = switch (tertiaryMask) {
      0 => (),
      1 => (priority: priority),
      2 => (user: user),
      3 => (priority: priority, user: user),
      4 => (scrutinize: scrutinize),
      5 => (priority: priority, scrutinize: scrutinize),
      6 => (user: user, scrutinize: scrutinize),
      7 => (priority: priority, user: user, scrutinize: scrutinize),
      _ => ()
    };

    final callbackMask = (
        (onComplete != null ? 1 : 0) |
        (onError != null ? 2 : 0) |
        (onProgress != null ? 4 : 0)
    );

    final callbacks = switch (callbackMask) {
      0 => (),
      1 => (onComplete: onComplete, branches: Box<int>(1)),
      2 => (onError: onError),
      3 => (onComplete: onComplete, branches: Box<int>(1), onError: onError),
      4 => (onProgress: onProgress),
      5 => (onComplete: onComplete, branches: Box<int>(1), onProgress: onProgress),
      6 => (onError: onError, onProgress: onProgress),
      7 => (onComplete: onComplete, branches: Box<int>(1), onError: onError, onProgress: onProgress),
      _ => ()
    };

    final finalMask = ((primaryMask > 0 ? 1 : 0) |
        (secondaryMask > 0 ? 2 : 0) |
        (tertiaryMask > 0 ? 4 : 0) |
        (callbackMask > 0 ? 8 : 0) |
        (parent != null ? 16 : 0)) |
        (pulse != null ? 32 : 0);

    return switch (finalMask) {
      0 => (cycleChecker: FinalBox<CycleChecker>()),
      1 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary)),
      2 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary)),
      3 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary)),
      4 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary)),
      5 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary)),
      6 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary)),
      7 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary)),
      8 => (cycleChecker: FinalBox<CycleChecker>(), root: (callbacks: callbacks)),
      9 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, callbacks: callbacks)),
      10 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, callbacks: callbacks)),
      11 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, callbacks: callbacks)),
      12 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary, callbacks: callbacks)),
      13 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary, callbacks: callbacks)),
      14 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary, callbacks: callbacks)),
      15 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary, callbacks: callbacks)),

      16 => (parent: parent),
      17 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary), parent: parent),
      18 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary), parent: parent),
      19 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary), parent: parent),
      20 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary), parent: parent),
      21 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary), parent: parent),
      22 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary), parent: parent),
      23 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary), parent: parent),
      24 => (cycleChecker: FinalBox<CycleChecker>(), root: (callbacks: callbacks), parent: parent),
      25 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, callbacks: callbacks), parent: parent),
      26 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, callbacks: callbacks), parent: parent),
      27 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, callbacks: callbacks), parent: parent),
      28 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary, callbacks: callbacks), parent: parent),
      29 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary, callbacks: callbacks), parent: parent),
      30 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary, callbacks: callbacks), parent: parent),
      31 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary, callbacks: callbacks), parent: parent),

      32 => (pulse: pulse),
      33 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary), pulse: pulse),
      34 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary), pulse: pulse),
      35 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary), pulse: pulse),
      36 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary), pulse: pulse),
      37 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary), pulse: pulse),
      38 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary), pulse: pulse),
      39 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary), pulse: pulse),
      40 => (cycleChecker: FinalBox<CycleChecker>(), root: (callbacks: callbacks), pulse: pulse),
      41 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, callbacks: callbacks), pulse: pulse),
      42 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, callbacks: callbacks), pulse: pulse),
      43 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, callbacks: callbacks), pulse: pulse),
      44 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary, callbacks: callbacks), pulse: pulse),
      45 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary, callbacks: callbacks), pulse: pulse),
      46 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary, callbacks: callbacks), pulse: pulse),
      47 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary, callbacks: callbacks), pulse: pulse),

      48 => (parent: parent, pulse: pulse),
      49 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary), parent: parent, pulse: pulse),
      50 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary), parent: parent, pulse: pulse),
      51 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary), parent: parent, pulse: pulse),
      52 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary), parent: parent, pulse: pulse),
      53 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary), parent: parent, pulse: pulse),
      54 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary), parent: parent, pulse: pulse),
      55 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary), parent: parent, pulse: pulse),
      56 => (cycleChecker: FinalBox<CycleChecker>(), root: (callbacks: callbacks), parent: parent, pulse: pulse),
      57 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, callbacks: callbacks), parent: parent, pulse: pulse),
      58 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, callbacks: callbacks), parent: parent, pulse: pulse),
      59 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, callbacks: callbacks), parent: parent, pulse: pulse),
      60 => (cycleChecker: FinalBox<CycleChecker>(), root: (tertiary: tertiary, callbacks: callbacks), parent: parent, pulse: pulse),
      61 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, tertiary: tertiary, callbacks: callbacks), parent: parent, pulse: pulse),
      62 => (cycleChecker: FinalBox<CycleChecker>(), root: (secondary: secondary, tertiary: tertiary, callbacks: callbacks), parent: parent, pulse: pulse),
      63 => (cycleChecker: FinalBox<CycleChecker>(), root: (primary: primary, secondary: secondary, tertiary: tertiary, callbacks: callbacks), parent: parent, pulse: pulse),

      _ => ()
    };
  }

  /// Fires the completion callback for this pulse.
  ///
  /// ### Where to start
  /// This is an internal implementation detail. You never call this
  /// directly. It's called by the framework when a pulse completes its
  /// reactive cycle.
  ///
  /// ### How it works
  /// Calls the `_onComplete` callback on the root pulse, passing this pulse.
  /// The callback is invoked after all downstream propagation has finished.
  ///
  /// ### Non‑obvious: this delegates to the root
  /// The completion callback is stored on the root pulse, not on the current
  /// pulse. This ensures that callbacks attached to the original pulse are
  /// still fired even after multiple evolutions.
  void _complete() {
    root._onComplete?.call(this);
  }

  /// Fires the error callback for this pulse.
  ///
  /// ### When to use
  /// * This is an internal implementation detail. You never call this
  ///   directly. It's called by the framework when a pulse fails during
  ///   processing.
  ///
  /// ### How it works
  /// Calls the `_onError` callback on the root pulse, passing the error.
  /// The callback is invoked when a validation fails or a receptor throws.
  ///
  /// ### Parameters:
  /// - [error]: The error that occurred.
  /// - [stackTrace]: Optional stack trace.
  void _fail(Object error, {StackTrace? stackTrace}) {
    root._onError?.call(this, error, stackTrace: stackTrace);
  }

  /// Fires the progress callback for this pulse.
  ///
  /// ### When to use
  /// * This is an internal implementation detail. You never call this
  ///   directly. It's called by the framework during pulse processing.
  ///
  /// ### How it works
  /// Calls the `_onProgress` callback on the root pulse, passing the cell
  /// and optional message. The callback is invoked when a receptor reports
  /// progress.
  ///
  /// ### Parameters:
  /// - [cell]: The cell currently processing the pulse.
  /// - [message]: Optional progress message.
  void _progress(Cell cell, {String? message}) {
    root._onProgress?.call(this, cell, message: message);
  }

  @override
  int get hashCode => _record.hashCode;

  @override
  int compareTo(Pulse other) {

    if (identical(this, other)) {
      return 0;
    }

    /// Compares this [Pulse] with another to determine their relative **Execution Precedence**.
    ///
    /// In a reactive graph, deterministic ordering is essential for maintaining
    /// **Causal Integrity** and system state reproducibility. This method defines
    /// a multi-tier sorting strategy used by schedulers and distribution networks
    /// to prioritize signal propagation.
    ///
    /// ### 1. Primary Tier: Chronological Precedence
    /// The framework prioritizes signals based on their **Temporal Origin**.
    /// Signals created earlier in time represent the foundational intent of a
    /// transaction and are processed first to ensure that state updates follow
    /// a logical timeline.
    final timeComparison = timestamp.compareTo(other.timestamp);
    if (timeComparison != 0) {
      return timeComparison;
    }

    /// ### 2. Secondary Tier: Operational Priority
    /// Within the same temporal window, signals are sorted by their **Execution
    /// Urgency**. Higher priority values (found in the pulse metadata) are
    /// moved to the front of the processing queue to handle high-importance
    /// system tasks or real-time constraints.
    final thisPriority = priority;
    final otherPriority = other.priority;
    final priorityComparison = otherPriority.compareTo(thisPriority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    /// ### 3. Tertiary Tier: Causal Path Depth
    /// If signals share the same timestamp and priority, the framework
    /// prioritizes the one with the **Shallowest Transformation Trace**.
    /// A shorter `trace` length indicates the signal is closer to its initial
    /// source and represents a more direct instruction, whereas a longer trace
    /// represents a signal that has undergone multiple layers of transformation
    /// and refinement.
    return trace.length.compareTo(other.trace.length);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is PulseBase) {
      return _record == other._record;
    }
    return false;
  }

  @override
  String toString() {
    return 'Pulse<$P>[$type] ${payload ?? "null"}';
  }

  @override
  bool get isComposite => false;

  @override
  bool get isGoverned {
    return get<bool>(() => _record.root.isGoverned,
        fallback: () => _pulse?.isGoverned ?? _parent?.isGoverned,
        orElse: false
    );
  }

  @override
  List<T>? lineage<T>(dynamic fieldGetter, {bool fromPolicy = false}) {

    List<T> extract(Function(dynamic record) fn) {
      dynamic record;
      List<T> lineage = [];
      PulseBase<P>? p = this;

      while (p != null) {
        record = fromPolicy ? p.policy?._record : p._record;
        if (record != null) {
          final v = get<T>(() => fn(record), orElse: null);
          if (v != null) {
            lineage.add(v);
          }
        }
        p = p._parent;
      }
      return lineage.reversed.toList(growable: false);
    }

    if (fromPolicy) {
      if (policy != null) {
        if (fieldGetter == Provenance.actor) {
          return extract((record) => record.root.tertiary.user);
        }
      }

    }

    if (fieldGetter == payload) {
      return extract((record) => record.root.primary.payload);
    } else if (fieldGetter == type) {
      return extract((record) => record.root.secondary.type);
    } else if (fieldGetter == timestamp) {
      return extract((record) => record.root.primary.timestamp);
    } else if (fieldGetter == source) {
      return extract((record) => record.root.primary.source);
    } else if (fieldGetter == priority) {
      return extract((record) => record.root.tertiary.priority);
    } else if (fieldGetter == context) {
      return extract((record) => record.root.secondary.context);
    } else if (fromPolicy) {

    }
    return null;
  }

}

class _UnmodifiablePulse<P> extends UnmodifiablePulseBase<P> {
  _UnmodifiablePulse(super.source);
}

abstract class UnmodifiablePulseBase<P> extends PulseBase<P>
    implements UnmodifiablePulse<P>, Unmodifiable {
  final PulseBase<P> _source;

  UnmodifiablePulseBase(Pulse<P> source) : _source = source as PulseBase<P>;

  @override
  get _record => _source._record;

  @override
  P? get payload {
    if (_source.payload == null) return null;
    if (_source.payload is Unmodifiable) {
      return _source.payload as P;
    }
    if (_source.payload is Iterable<Cell>) {
      return (_source.payload as Iterable<Cell>).map((e) => e.unmodifiable) as P;
    }
    if (_source.payload is Map<dynamic,Cell>) {
      return (_source.payload as Map<dynamic, Cell>).map((k, v) => MapEntry(k, v.unmodifiable)) as P;
    }
    if (_source.payload is Cell) {
      return (_source.payload as Cell).unmodifiable as P;
    }
    return _source.payload;
  }

  @override
  PulseContext get context => _source.context;

  @override
  bool get isComposite => _source.isComposite;

  @override
  void Function(Pulse pulse)? get _onComplete => _source._onComplete;

  @override
  void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? get _onError =>
      _source._onError;

  @override
  void Function(Pulse pulse, Cell cell, {String? message})? get _onProgress =>
      _source._onProgress;

  @override
  PulseBase<P>? get _parent => _source._parent?.unmodifiable;

  @override
  PulseBase<P> get root => _source.root.unmodifiable;

  @override
  Cell? get source => _source.source?.unmodifiable;

  @override
  DateTime get timestamp => _source.timestamp;

  @override
  List<String> get trace => _source.trace;

  @override
  String? get type => _source.type;

  @override
  PulseBase<P> get unmodifiable => this;

  @override
  int get hashCode => _source.hashCode;

  @override
  bool operator ==(Object other) => _source == other;

  @override
  String toString() => _source.toString();

  @override
  int compareTo(Pulse other) => _source.compareTo(other);

  @override
  Iterator<Pulse> get iterator {
    return _source.map((e) => e.unmodifiable).iterator;
  }
}

/// A specialized **Traversal Guard** and **Topology Validator**, responsible for
/// preventing infinite recursion and ensuring the reactive graph remains a
/// **Directed Acyclic Graph (DAG)** during signal propagation.
///
/// [CycleChecker] acts as the "Short-Term Memory" of a reactive wave. It tracks
/// the path of a [Pulse] as it traverses through various nodes, identifying
/// and halting any attempts to re-enter a node that has already participated
/// in the current execution cycle.
///
/// ### When to use
/// - **Graph Integrity**: Use whenever a signal propagates through a network
///   where complex, interdependent relationships might lead to circular triggers.
/// - **Stack Protection**: Use to prevent `StackOverflowError` in deeply
///   nested or recursively defined reactive structures.
/// - **Traversal Auditing**: Use during debugging to trace the causal path
///   of a specific stimulus.
///
/// ### How it works
/// 1. **Registry Synthesis**: Maintains a transient set of [Cell] identities
///    representing the "Visited Nodes" of the current propagation wave.
/// 2. **Causal Registration**: Before a [Receptor] processes a pulse, it
///    registers itself via the [add] method.
/// 3. **Conflict Detection**: If the registration fails (node already visited),
///    a **Circular Dependency** is identified.
/// 4. **Graceful Termination**: Instead of crashing, the system suppresses
///    further propagation along the offending branch, allowing the rest of
///    the graph to settle normally.
///
/// ### Non‑obvious
/// - **Identity-Based**: Tracking is performed using referential identity of
///   the [Cell] instances, not their values or states.
/// - **Single-Wave Lifecycle**: Instances are intended to be ephemeral, typically
///   mapping 1:1 with the lifespan of a single [Pulse] wave.
/// - **Concurrency Bridge**: While optimized for synchronous execution, it
///   seamlessly transitions to thread-safe mode via the [async] property
///   ([SyncCycleChecker]) when crossing asynchronous boundaries.
/// - **Zero-Overhead for Linear Paths**: The internal `_visited` set is highly
///   optimized for small collections, minimizing the latency penalty for
///   most propagation paths.
///
/// ### Example
/// ```dart
/// void propagate(Pulse pulse, Cell node) {
///   // Check for cycles before processing
///   if (!pulse.checker.add(node)) {
///     print('Cycle detected at $node; halting branch.');
///     return;
///   }
///
///   // Safe to proceed with transformation
///   node.process(pulse);
/// }
/// ```
///
/// ### See Also:
/// * [SyncCycleChecker]: The synchronized counterpart for asynchronous flows.
/// * [Pulse]: The stimulus that carries the checker through the graph.
/// * [Receptor]: The primary component that implements this guard.
class CycleChecker {

  /// The set of nodes that have already processed the current stimulus.
  final Set<Cell> _visited = {};

  CycleChecker._();

  /// Registers a node in the current traversal path.
  ///
  /// Returns `true` if the [cell] was successfully added (no cycle detected).
  /// Returns `false` if the [cell] was already visited, indicating a
  /// **Circular Dependency**.
  bool add(Cell cell) {
    if (_visited.contains(cell)) return false;
    _visited.add(cell);
    return true;
  }

  /// Verifies if a specific node has already been traversed by the current stimulus.
  ///
  /// This method performs a non-mutating lookup within the **Causal Path** registry,
  /// allowing internal logic to inspect the current propagation state without
  /// registering a new visit.
  bool contains(Cell cell) => _visited.contains(cell);

  /// Provides a thread-safe, synchronized version of this checker for
  /// asynchronous propagation waves.
  late final SyncCycleChecker async = SyncCycleChecker(this);

}

/// A thread-safe, **Synchronized Circular Dependency Guard** for asynchronous
/// reactive flows.
///
/// [SyncCycleChecker] extends the cycle detection logic to handle propagation
/// waves that span across asynchronous boundaries or multi-threaded execution
/// contexts. It ensures that the "visited" state of the reactive graph remains
/// consistent and protected from race conditions during concurrent pulse
/// transmissions.
///
/// ### When to use
/// - **Asynchronous Propagation**: Use when a reactive wave spans across
///   asynchronous boundaries, such as `Future` transformations or cross-isolate
///   communication.
/// - **Multi-threaded Safety**: Use in concurrent environments where multiple
///   branches of the same pulse wave might be processed simultaneously.
/// - **Topology Protection**: Use to prevent infinite recursion in complex
///   graphs that involve asynchronous nodes or deferred execution.
///
/// ### How it works
/// 1. **Atomic Traversal**: Wraps the underlying [CycleChecker] operations in
///    a non-recursive [Lock]. This ensures that adding a node to the visited
///    set is an atomic operation, preventing race conditions between concurrent
///    branches of the same pulse.
/// 2. **Conflict Detection**: Before an asynchronous receptor processes a
///    pulse, it invokes the [add] method. If the node was already visited
///    within the current pulse wave, the operation is rejected.
/// 3. **Coordination**: Ensures that the "Visited" status is globally consistent
///    across all concurrent tasks associated with a single [Pulse] lineage.
/// 4. **Async Interface**: Provides a [Future]-based API to align with the
///    framework's non-blocking concurrency model.
///
/// ### Non‑obvious
/// - **Lifecycle**: Typically accessed via the `async` property of a base
///   [CycleChecker]. It is an ephemeral proxy that lasts for the duration
///   of a single propagation wave.
/// - **Principal Proxy**: It does not own the visited set itself but merely
///   coordinates synchronized access to its principal [CycleChecker].
/// - **Zero-Blocking**: Uses the framework's internal [Lock] to ensure the
///   calling thread remains available for other tasks while waiting for
///   registry access.
/// - **Forensic Integrity**: Maintains the causal path of a pulse even when
///   execution is deferred, parallelized, or moved to different execution tiers.
///
/// ### Example
/// ```dart
/// Future<void> asyncPropagate(Pulse pulse, Cell node) async {
///   // Access the synchronized checker for async flows
///   final isSafe = await pulse.checker.async.add(node);
///
///   if (!isSafe) {
///     print('Async cycle detected at $node; halting branch.');
///     return;
///   }
///
///   // Proceed with the asynchronous transformation
///   await node.processAsync(pulse);
/// }
/// ```
///
/// ### See Also:
/// * [CycleChecker]: The high-performance synchronous variant.
/// * [Lock]: The underlying primitive used for synchronization.
/// * [Pulse]: The stimulus that carries this guard through the graph.
/// * [Receptor]: The primary consumer of this topology guard.
class SyncCycleChecker {

  /// The atomic synchronization primitive used to protect the visitor set.
  final _lock = Lock();

  /// The underlying, non-thread-safe checker being synchronized.
  final CycleChecker _checker;

  SyncCycleChecker(this._checker);

  /// Atomically registers a node in the current asynchronous traversal path.
  ///
  /// Returns a [Future<bool>] that resolves to:
  /// * `true`: If the [cell] was successfully registered (no cycle detected).
  /// * `false`: If the [cell] was already visited by this pulse lineage,
  ///   indicating a **Circular Dependency**.
  Future<bool> add(Cell cell) async {
    return _lock.synchronized(() async {
      return _checker.add(cell);
    });
  }

  /// Atomically verifies if a specific node has already been traversed by
  /// the current asynchronous stimulus.
  ///
  /// This method performs a non-mutating lookup within the protected **Causal Path**
  /// registry, ensuring thread-safe inspection of the propagation state.
  Future<bool> contains(Cell cell) async {
    return _lock.synchronized(() async {
      return _checker.contains(cell);
    });
  }
}

/// A specialized **Defensive Perimeter** and **Projection Layer** representing
/// a formal contract for **Bidirectional Mutual Authorization**.
///
/// [Shell] acts as the primary mechanism for the **Reciprocal Handshake**,
/// wrapping a core kernel (such as a [Pulse]) to facilitate the **Ingress Phase**
/// of the reactive update cycle. It ensures that sensitive internal state is
/// only released to consumers that satisfy specific security invariants, acting
/// as a portable **Integrity Gate** across the switching fabric.
///
/// ### When to use
/// - **Capability-Based Access Control (CBAC)**: When you need to gate access
///   to a signal's payload based on the identity or authority of the target node.
/// - **Capability Attenuation**: Providing a redacted or masked view of an
///   object to prevent domain violations during traversal.
/// - **Authorization Challenges**: Enforcing business invariants by requiring a
///   formal challenge-response before a stimulus is allowed to affect state.
/// - **Signal Projection**: Creating transient, read-only views of core
///   framework entities to be shared across the **Egress Gateway** without
///   exposing the mutable kernel.
///
/// ### How it works
/// 1. **Authorization Challenge**: The shell wraps a kernel and requires the
///    caller (the [T] authority) to invoke [scrutinize], passing their own
///    identity or authority tokens.
/// 2. **Reciprocal Handshake**: The shell evaluates the caller's credentials
///    against the kernel's internal security policy and contextual requirements.
/// 3. **Dynamic Projection**: Based on the result of the scrutiny, the shell
///    either returns the internal kernel (**AUTHORIZED**), a filtered version,
///    or `null` (**NEUTRALIZED**).
/// 4. **Causal Provenance Preservation**: The shell maintains the identity
///    and lineage of the underlying object, ensuring metadata (trace,
///    timestamp, context) is preserved throughout the handshake.
///
/// ### Non‑obvious
/// - **Flyweight Strategy**: Many implementations (like [PulseShell]) utilize
///   `const` constructors and shared storage to minimize heap pressure
///   during high-frequency propagation waves.
/// - **Fail-Closed Design**: If the scrutiny process fails or is bypassed,
///   the shell remains opaque, preventing unauthorized leak of the internal
///   cytoplasm.
/// - **Identity Transparency**: The shell does not replace the identity of the
///   underlying stimulus but acts as a perceptual lens through which the
///   stimulus is viewed by specific consumers.
/// - **Structural Blueprint**: It defines the zero-cost anchoring for
///   defensive proxies, allowing security protocols to be embedded directly
///   into the signal propagation logic.
///
/// ### Example
/// ```dart
/// class SecureShell<P> implements Shell<Cell> {
///   final Pulse<P> _kernel;
///   const SecureShell(this._kernel);
///
///   @override
///   dynamic scrutinize(Cell host, List? args, [Map<Symbol, dynamic>? named]) {
///     // Only authorize nodes with matching security context
///     if (host.context.clearance >= _kernel.context.priority) {
///       return _kernel;
///     }
///     return null; // Neutralized
///   }
/// }
/// ```
///
/// ### Parameters:
/// * **[T]**: **The Target Authority.** The type of entity (usually a [Cell]
///   or [Receptor]) that this shell is designed to challenge and authorize.
///
/// ### Returns:
/// A [Shell] instance acting as a **Defensive Gateway**.
///
/// ### See Also:
/// * [PulseShell]: The standard implementation for reactive signals.
/// * [Receptor]: The primary consumer that interacts with these shells.
/// * [TestRule]: Often used within scrutiny logic to enforce business invariants.
abstract interface class Shell<T> {

  /// Filters the underlying object through a **Capability Lens**, returning a
  /// version of the data compatible with the caller's authorization scope and intent.
  ///
  /// This method is invoked by [Receptor]s and [TestCell]s during the
  /// **Validation Phase** to verify the compatibility between a signal and
  /// a specific **Managed Node**.
  ///
  /// ### Parameters:
  /// - [object]: The entity being scrutinized (e.g., a [Pulse] or [Cell]).
  ///   Marked as `covariant` to allow specialized shells to restrict the
  ///   types of objects they can project.
  /// - [positionalArguments]: Optional parameters for the scrutiny logic,
  ///   often containing contextual metadata or **Capability Attenuation** keys.
  /// - [namedArguments]: Highly specific triggers or flags (e.g., `dryRun: true`)
  ///   that modify how the shell projects the underlying data during the
  ///   **Reactive Update Cycle**.
  ///
  /// ### Returns:
  /// A [dynamic] result representing the **Authorized State**. This may be
  /// the internal kernel itself if **AUTHORIZED**, a redacted copy,
  /// or `null` if the interaction is **NEUTRALIZED** (Fail-Closed).
  dynamic scrutinize(covariant T object, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]);

}

/// A specialized [Shell] providing a **Perceptual Projection** of a [Pulse] to
/// facilitate pre-execution validation and security gating.
///
/// [PulseShell] acts as a high-integrity **Defensive Proxy** that wraps a core
/// kernel (the actual [Pulse]) to facilitate the **Ingress Phase** of the
/// framework's reactive update cycle. It implements the **Reciprocal Handshake**
/// protocol, ensuring that sensitive data is only released to nodes that
/// satisfy specific security and business invariants.
///
/// ### When to use
/// - **Identity-Gated Propagation**: When a signal contains sensitive information
///   that should only be accessible to authorized [Receptor]s.
/// - **Reciprocal Handshake**: To initiate a mutual authorization protocol between
///   a [Pulse] and a [Cell] during the **Ingress Phase**.
/// - **Defensive Projection**: Providing a terminal, read-only view of a stimulus
///   that cannot be further evolved or modified.
/// - **Validation Before Execution**: Gating access to the `payload` until the
///   target node satisfies specific **Integrity Gates**.
///
/// ### How it works
/// 1. **Encapsulation**: Wraps a core `PulseBase` kernel within a **Defensive
///    Perimeter**, acting as a projection layer.
/// 2. **Payload Masking**: Intentionally returns `null` for the `payload` and
///    `trace` properties, effectively "cloaking" the stimulus until authorized.
/// 3. **Identity Challenge**: During the **Ingress Phase**, the [Receptor] must
///    invoke [scrutinize], passing its own identity and context to the shell.
/// 4. **Reciprocal Authorization**: The shell executes the kernel's internal
///    validation logic against the receptor's authority tokens.
/// 5. **Kernel Release**: If authorized, the internal kernel is released for
///    the transformation phase; otherwise, the interaction is **Neutralized**.
///
/// ### Non‑obvious
/// - **Flyweight Strategy**: Implemented as a `const` class to ensure zero-cost
///   projections during high-frequency reactive waves.
/// - **Terminal Projection**: Unlike a standard [Pulse], a shell is non-composite
///   and cannot be evolved (using [evolve] or `+` will throw an [UnsupportedError]).
/// - **Causal Provenance Masking**: Suppresses internal [trace] and [lineage]
///   metadata to prevent information leakage before the handshake is complete.
/// - **Fail-Closed Policy**: If the scrutiny logic encounters an error or
///   insufficient authority, the shell defaults to a neutralized state
///   (returning `null`).
///
/// ### Example
/// ```dart
/// void onPulse(PulseShell<int, MyReceptor> shell, MyReceptor receptor) {
///   // Accessing payload directly returns null before the handshake
///   print(shell.payload); // null
///
///   // Perform the Reciprocal Handshake
///   final kernel = shell.scrutinize(receptor, []);
///
///   if (kernel != null) {
///     // Now authorized to access the real Causal Provenance and payload
///     print(kernel.payload);
///   }
/// }
/// ```
///
/// ### Type Parameters:
/// * **[P]**: The type of the underlying data payload.
/// * **[R]**: The specific type of [Receptor] qualified to challenge this shell.
///
/// ### Returns:
/// A [PulseShell] instance acting as a **Defensive Proxy**.
///
/// ### See Also:
/// * [Shell]: The core interface for mutual authorization.
/// * [Pulse]: The underlying stimulus being protected.
/// * [Receptor]: The primary consumer that interacts with these shells.
/// * [PulseContext]: The metadata governing the shell's security tier.
class PulseShell<P, R extends Receptor> with IterableMixin<Pulse> implements Pulse<P>, Shell<R> {

  final PulseBase<P> _kernal;

  /// Encapsulates the [Pulse] kernel within a perceptual boundary.
  ///
  /// This constructor initializes the shell as a **Defensive Proxy**, wrapping
  /// the internal `kernal` to enforce the **Ingress Phase** of the
  /// **Reactive Update Cycle**.
  ///
  /// The resulting instance is a terminal, read-only projection that prevents
  /// unauthorized access to the payload until identity verification via
  /// [scrutinize] is performed.
  const PulseShell(this._kernal);

  @override
  Iterator<Pulse> get iterator => [this].iterator;

  @override
  Pulse operator +(covariant Pulse other) {
    throw UnsupportedError('PulseShell not supported for addition.');
  }

  @override
  PulseShell<P,R> get shell => this;

  @override
  int compareTo(Pulse other) {
    if (identical(this, other)) {
      return 0;
    }
    
    final timeComparison = timestamp.compareTo(other.timestamp);
    if (timeComparison != 0) {
      return timeComparison;
    }
    
    final thisPriority = priority;
    final otherPriority = other.priority;
    final priorityComparison = otherPriority.compareTo(thisPriority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    
    return _kernal.trace.length.compareTo(other.trace.length);
  }

  @override
  PulseContext get context => _kernal.context;

  @override
  Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }

  @override
  bool get isComposite => false;

  @override
  bool get isGoverned => _kernal.isGoverned;

  @override
  bool get isInvalidated => _kernal.isInvalidated;

  @override
  List<T>? lineage<T>(fieldGetter, {bool fromPolicy = false}) {
    return null;
  }

  @override
  P? get payload => null;

  @override
  PulseEphemeralPolicy? get policy => null;

  @override
  int get priority => _kernal.priority;

  @override
  Pulse<P> get root => this;

  @override
  Cell? get source => _kernal.source;

  @override
  DateTime get timestamp => _kernal.timestamp;

  @override
  List<String> get trace => const [];

  @override
  String? get type => _kernal.type;

  @override
  Pulse<P> get unmodifiable => this;

  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {
    final validate = _kernal._scrutinize;
    if (validate != null) {
      try {
        return validate(receptor);
      } catch (e) {
        return null;
      }
    }
    return _kernal;
  }

  @override
  Pulse<P> withStep(String step) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }

}

// /// Middleware for intercepting, transforming, or observing Pulses.
// abstract class PulseMiddleware {
//   Pulse? before(Pulse pulse, {Cell? host});
//   void after(Pulse? input, Pulse? output, {Cell? host});
//   void onError(Object error, StackTrace? stackTrace, Pulse pulse, {Cell? host});
// }

// class _SimplePulseMiddleware implements PulseMiddleware {
//   final Pulse? Function(Pulse, {Cell? cell})? _before;
//   final void Function(Pulse?, Pulse?, {Cell?})? _after;
//   final void Function(Object, StackTrace?, Pulse, {Cell?})? _onError;
//
//   const _SimplePulseMiddleware(this._before, this._after, this._onError);
//
//   @override
//   Pulse? before(Pulse pulse, {Cell? host}) => _before?.call(pulse, host: host) ?? pulse;
//
//   @override
//   void after(Pulse? input, Pulse? output, {Cell? host}) => _after?.call(input, output, host: host);
//
//   @override
//   void onError(Object error, StackTrace? st, Pulse pulse, {Cell? host}) =>
//   _onError?.call(error, st, pulse, host: host);
// }
