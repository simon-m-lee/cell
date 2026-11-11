// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

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
class _CollectivePulse<P> extends CollectivePulseBase<P> {
  _CollectivePulse(
    Iterable<Pulse<P>> pulses, {
    super.policy,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    void Function(Pulse pulse)? super.onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?
        super.onError,
    void Function(Pulse pulse, Cell cell, {String? message})? super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
    super.priority,
  }) : super(pulses: pulses);

  @override
  UnmodifiableCollectivePulse<P> get unmodifiable =>
      UnmodifiableCollectivePulse<P>._(this);
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
  CollectivePulseBase(
      {Iterable<Pulse<P>>? pulses,
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
      super.priority})
      : super(payload: pulses);
  // No branch-counter increment here. `mask` already allocates
  // `branches: Box<int>(1)` whenever `onComplete` is present, and the
  // empty-synapse terminal paths decrement exactly once per journey. An
  // extra increment would leave a single-terminal dead-end stuck at 1 and
  // the completion callback would never fire.

  /// The collection of pulses bundled in this collective.
  ///
  /// ### When to use
  /// Use this to access the individual pulses in the collective.
  ///
  @override
  Iterable<Pulse<P>> get payload => super.payload as Iterable<Pulse<P>>;

  @override
  // A collective iterates itself (see `iterator`), so its `last` is the
  // collective, not the final sub-pulse. The pipeline passes `pulse.last`
  // into instruction stages and must receive the batch itself.
  PulseBase get last => this;

  /// Completes every sub‑pulse before completing the collective itself.
  ///
  /// A collective is only truly settled once each sub‑pulse it carries has
  /// also completed. Completing them depth‑first guarantees that governed
  /// sub‑pulses fire their own `onComplete` callbacks before the collective's
  /// completion callback observes the settled batch.
  @override
  void _complete() {
    for (final sub in payload) {
      (sub as PulseBase)._complete();
    }
    super._complete();
  }

  /// Indicates that this pulse is a composite bundle.
  ///
  /// ### When to use
  /// Check this to know if a pulse contains multiple sub‑pulses.
  @override
  bool get isComposite => true;

  /// Returns an iterator over this collective itself.
  ///
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
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?
        super.onError,
    void Function(Pulse pulse, Cell cell, {String? message})? super.onProgress,
    required super.pulse,
    required super.parent,
  }) : super();

  @override
  EvolvedPulseBase<P> get unmodifiable => UnmodifiableEvolvedPulse<P>._(this);
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
abstract class EvolvedPulseBase<P> extends _SinglePulseBase<P>
    implements EvolvedPulse<P> {
  final List<PulseBase> _pulses;

  /// Creates a new evolved pulse that extends a causal chain.
  ///
  /// ### How it works
  /// - Accepts metadata for the new evolved pulse.
  /// - Passes all parameters to the superclass constructor.
  /// - The resulting pulse is a new node in the causal chain, linked to
  ///   its [parent] via the superclass.
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
    required PulseBase parent,
  })  : _pulses = pulse is EvolvedPulseBase
            ? [...pulse._pulses, pulse]
            : [parent, pulse],
        super(pulse: pulse, parent: parent);
  // No branch-counter increment here, for the same reason as
  // CollectivePulseBase: `mask` allocates `branches: Box<int>(1)` when
  // `onComplete` is present, and the terminal paths decrement once per
  // journey. An extra increment would strand a single-terminal dead-end
  // at 1 and the chain's completion callback would never fire.

  @override
  bool get isComposite => true;

  @override
  Pulse get parent => _parent!;

  @override
  PulseBase get last => _pulses.last;

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

/// An optimized, flat-field implementation of a pulse used for high-frequency
/// signal transmission.
///
/// In the framework's biological metaphor, [_FastPulse] represents a
/// **High-Speed Nervous Impulse**. It is designed for **Synaptic Ingress**—points
/// where data enters the reactive graph so frequently that the overhead of
/// standard governance must be bypassed for performance.
///
/// ### Why it is used
/// - **Performance Optimization**: Standard pulses use a flexible but complex
///   record-mask system. [_FastPulse] replaces this with direct fields,
///   drastically reducing memory allocation and CPU overhead during
///   "hot path" operations like [Cell.ingress].
/// - **Minimalist Footprint**: It avoids allocating nested record trees,
///   cycle-checker boxes, or eager timestamps unless they are specifically
///   requested.
///
/// ### How it works
/// - **Direct Storage**: Instead of resolving data through a bitmask, it stores
///   the [payload], [source], and [priority] directly on the instance.
/// - **Lazy Resolution**: Heavily computed fields, such as the [timestamp]
///   and the [CycleChecker], are only created if a downstream synapse
///   actually accesses them.
///
/// ### Technical Details
/// - **Shape Zero**: It explicitly sets its `_shape` to `0`, informing the
///   engine to skip the standard record-based resolution logic.
/// - **Flyweight Semantics**: Despite its internal optimizations, it fully
///   implements the [PulseBase] interface, ensuring it remains compatible
///   with all synapses and receptors.
///
/// See also:
/// - [Cell.ingress] — The primary entry point for fast pulses.
/// - [PulseBase] — The foundation for all signals in the Mitosis ledger.
/// - [guide/HowTo-Cell.apply.md](guide/HowTo-Cell.apply.md) — For
///   contrast with "Governed" signals.
class _FastPulse<P> extends PulseBase<P> {
  _FastPulse({
    P? payload,
    dynamic type,
    Cell? source,
    int? priority,
    String? step,
  })  : _payload = payload,
        _type = type,
        _source = source,
        _priority = priority,
        _step = step,
        super.fromRecord(());

  final P? _payload;
  final dynamic _type;
  final Cell? _source;
  final int? _priority;
  final String? _step;
  DateTime? _timestampCache;
  CycleChecker? _checkerCache;

  @override
  int get _shape => 0;

  @override
  P? get payload => _payload;

  @override
  Cell? get source => _source;

  @override
  DateTime get timestamp => _timestampCache ??= DateTime.now();

  @override
  PulseEphemeralPolicy? get policy => null;

  @override
  dynamic get type => _type;

  @override
  int get priority => _priority ?? Pulse.defaultPriority;

  @override
  PulseContext get context => PulseContext.system;

  @override
  bool get isGoverned => false;

  @override
  bool get isComposite => false;

  @override
  PulseBase? get _parent => null;

  @override
  PulseBase<P>? get _pulse => null;

  @override
  dynamic get _user => null;

  @override
  Function? get _scrutinize => null;

  @override
  void Function(Pulse pulse)? get _onComplete => null;

  @override
  void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?
      get _onError => null;

  @override
  void Function(Pulse pulse, Cell cell, {String? message})? get _onProgress =>
      null;

  @override
  Box<int>? get _branches => null;

  @override
  CycleChecker get _checker => _checkerCache ??= CycleChecker._();

  @override
  Iterator<PulseBase> get iterator => [this].iterator;

  @override
  PulseBase get last => this;

  @override
  List<String> get trace {
    final step = _step;
    return step == null ? const [] : [step];
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => 'Pulse<$P>($payload, priority: $priority)';
}

/// A lightweight node used to track a single step in a pulse's journey.
///
/// [_StepPulse] acts as a **Genetic Marker** in the **Forensic Ledger**. Instead of
/// recreating a full pulse with all its metadata, it simply points to a parent
/// pulse and adds a new "step" tag to the lineage.
///
/// ### Why it is used
/// - **Memory Efficiency**: It is a "Flyweight" implementation. It avoids the
///   overhead of allocating a full [PulseBase] record every time a pulse moves
///   through a new cell or processor.
/// - **Causal Traceability**: It allows the framework to build a complete `trace`
///   (a breadcrumb trail) of everywhere a **Nervous Signal** has traveled without
///   duplicating the payload data.
///
/// ### How it works
/// 1. **Lineage Link**: It holds a reference to the `parent` pulse, maintaining
///    the causal chain.
/// 2. **Step Tagging**: It stores a specific string representing the current
///    milestone (e.g., "validation", "ingress").
/// 3. **Lineage Resolution**: When you ask for the `trace`, the framework walks
///    back through these markers to assemble the history.
///
/// ### Technical Details
/// - **Minimal Allocation**: It uses a specialized bitmask ([PulseBase._kParent] |
///   [PulseBase._kStep]) to inform the engine that only lineage and step
///   data exist in its record.
/// - **Payload Resolution**: Accessing `payload` on this pulse will automatically
///   resolve to the parent's payload, ensuring the data remains consistent
///   throughout the chain.
///
/// See also:
/// - [PulseBase.withStep] — The primary way to create these markers.
/// - [PulseBase.trace] — The property that resolves these markers into a list of strings.
class _StepPulse<P> extends PulseBase<P> {
  _StepPulse(this._stepParent, this._stepValue) : super.fromRecord(());

  final PulseBase<P> _stepParent;
  final String _stepValue;

  @override
  int get _shape => 0;

  @override
  PulseBase? get _parent => _stepParent;

  @override
  List<String> get trace => [..._stepParent.trace, _stepValue];

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  @override
  Iterator<PulseBase> get iterator => [this].iterator;

  @override
  PulseBase get last => this;
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
  PulseBase get last => this;

  @override
  PulseBase<P> get unmodifiable => UnmodifiablePulse<P>(this) as PulseBase<P>;

  late final String _toString = _computeToString();

  String _computeToString() {
    final mask = ((payload != null ? 1 : 0) |
        (source != null ? 2 : 0) |
        (type != null ? 4 : 0) |
        (trace.isNotEmpty ? 8 : 0));

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
      14 =>
        'null, source: $source, type: $type, trace: $trace, priority: $priority',
      15 =>
        '$payload, source: $source, type: $type, trace: $trace, priority: $priority',
      _ => ('something is wrong with the mask: $mask')
    };
    return s;
  }

  @override
  String toString() => 'Pulse<$P>($_toString)';
}

/// The foundational blueprint for all nervous signals within the reactive graph.
///
/// [PulseBase] is the "Common DNA" shared by every signal, whether it is a
/// high-speed `_FastPulse` or a fully audited, governed impulse. It provides
/// the core logic for causal tracking, forensic logging, and signal evolution.
///
/// In the framework's biological metaphor, this class defines the
/// **Signal Architecture**. Every impulse that travels through a cell's
/// synapses is built upon this base, ensuring that the **Forensic Ledger**
/// can always trace a signal's origin and journey.
///
/// ### Why it is used
/// - **Causal Integrity**: It maintains the "Lineage" of signals. When a cell
///   reacts to an input and produces an output, [PulseBase] ensures the
///   new signal is "evolved" from the old one, preserving the audit trail.
/// - **Performance at Scale**: It uses a specialized **Bitmask Record**
///   system (`_shape`) to store metadata. This allows the framework to
///   handle thousands of signals per second by avoiding expensive object
///   allocations for every metadata field.
/// - **Unified Interface**: It allows receptors and synapses to treat all
///   signals—whether they are single values or collective batches—through
///   a single, type-safe API.
///
/// ### How it works
/// 1. **Signal Masking**: When a pulse is created, its metadata (timestamp,
///    source, priority, etc.) is packed into a sparse record. A bitmask
///    ([_shape]) is generated to tell the engine which fields exist.
/// 2. **Causal Evolution**: Through the [evolve] method, a pulse creates
///    a child signal. The child inherits the parent's "Causal Link,"
///    allowing the framework to detect infinite loops or trace history.
/// 3. **Forensic Tracking**: It provides a [trace] of "Genetic Markers"
///    (steps), which are breadcrumbs representing every milestone the
///    signal passed through.
///
/// ### Technical Details
/// - **Bitmask Optimization**: Field access (like `payload` or `source`)
///   checks the `_shape` bitmask first. This is an "exception-free"
///   sparse read that is significantly faster than standard reflection.
/// - **Flyweight Pattern**: The internal `_record` is a Dart Record,
///   which the compiler can often optimize into registers, reducing
///   heap pressure during high-frequency signaling.
///
/// See also:
/// - [Cell.apply] — The primary gateway where these signals are vetted.
/// - [Pulse] — The public-facing interface for this class.
abstract class PulseBase<P> with IterableMixin<Pulse> implements Pulse<P> {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

// ───── Shape Tag: The Genetic Fingerprint for Sparse Records ─────
  /// A bitmask that identifies which metadata fields exist within this pulse.
  ///
  /// In the framework's biological metaphor, the `_shape` tag is the
  /// **Genetic Fingerprint** of the signal. It tells the engine exactly
  /// which "organs" (fields like source, timestamp, or priority) the pulse
  /// possesses before any attempt is made to access them.
  ///
  /// ### Why it is used
  /// - **High-Speed Signaling**: Accessing fields in a dynamic record can be
  ///   slow or throw errors if a field is missing. By checking the bitmask
  ///   first, the framework ensures "zero-latency" reads on the hot path.
  /// - **Forensic Integrity**: It prevents the framework from processing
  ///   "malformed" signals by providing an immediate manifest of the
  ///   pulse's structure.
  ///
  /// ### How it works
  /// - **Stamping**: When a pulse is created, the `mask` utility stamps
  ///   a `shape` integer directly onto the underlying record.
  /// - **Validation**: Accessors (like `payload` or `source`) perform a
  ///   bitwise `&` check against this tag. If the bit isn't set, the
  ///   accessor returns `null` immediately without ever touching the
  ///   potentially missing record field.
  ///
  /// ### Technical Details
  /// - **Exception-Free**: This architecture avoids `NoSuchMethodError`
  ///   or `LateInitializationError`, which are expensive to catch during
  ///   high-frequency reactive cycles.
  /// - **Legacy Fallback**: If a pulse is created via [fromRecord] (legacy
  ///   or external data), the tag is resolved once and cached to maintain
  ///   compatibility with the forensic ledger.
  ///
  static const int _kPayload = 1 << 0;
  static const int _kSource = 1 << 1;
  static const int _kTimestamp = 1 << 2;
  static const int _kPolicy = 1 << 3;
  static const int _kGoverned = 1 << 4;
  static const int _kParent = 1 << 5;
  static const int _kPulse = 1 << 6;
  static const int _kType = 1 << 8;
  static const int _kContext = 1 << 9;
  static const int _kStep = 1 << 10;
  static const int _kPriority = 1 << 16;
  static const int _kUser = 1 << 17;
  static const int _kScrutinize = 1 << 18;
  static const int _kOnComplete = 1 << 24;
  static const int _kOnError = 1 << 25;
  static const int _kOnProgress = 1 << 26;

  /// The active **Genetic Fingerprint** of this specific signal.
  ///
  /// [_shape] retrieves the bitmask that identifies which metadata fields
  /// exist within the pulse's underlying record. This allows the framework
  /// to perform "Genetic Profiling" on a signal before attempting to
  /// read its data.
  ///
  /// ### Why it is used
  /// - **Zero-Latency Reads**: Checking a bit in a number is significantly
  ///   faster than querying a dynamic record. It allows the framework to
  ///   skip missing fields without any performance penalty.
  /// - **Integrity Protection**: It ensures that accessors only touch
  ///   valid data, preventing runtime errors during high-frequency
  ///   reactive cycles.
  ///
  /// ### How it works
  /// 1. **Extraction**: It attempts to read the `shape` property directly
  ///    from the [Nervous Signal]'s internal record.
  /// 2. **Fallback**: If the pulse was created through a legacy or external
  ///    source that lacks a fingerprint, it defaults to `0` (meaning no
  ///    optional metadata is present).
  ///
  /// ### Technical Details
  /// - **Exception-Free Path**: Modern pulses built via the [mask] utility
  ///   always carry this tag. The `try-catch` block is a safety net for
  ///   [fromRecord] instances, ensuring the "hot path" remains stable.
  /// - **Bitwise Scrutiny**: This value is used by every getter (like
  ///   [payload] or [source]) to verify field presence using bitwise `&`.
  ///
  int get _shape {
    try {
      return _record.shape as int;
    } catch (_) {
      return 0;
    }
  }

  PulseBase(
      {PulseEphemeralPolicy? policy,
      PulseContext? context,
      P? payload,
      dynamic type,
      DateTime? timestamp,
      Cell? source,
      String? step,
      int? priority,
      Function? onComplete, // void Function(Pulse pulse)? onComplete,
      Function?
          onError, // void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
      Function?
          onProgress, // void Function(Pulse pulse, Cell cell, {String? message})? onProgress,

      Pulse? pulse,
      Pulse? parent,
      FutureOr<Pulse?> Function(Receptor receptor)? scrutinize,
      dynamic user})
      : _record = mask(
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
            user: user);

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
  /// ### Parameters:
  /// - [record]: The record containing the pulse's metadata.
  ///
  /// ### Returns:
  /// A [PulseBase] instance with the provided record.
  const PulseBase.fromRecord(Record record) : _record = record;

  @override
  Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    // 1. Validate that the call is meaningful
    assert(
      pulse != null || step != null || context != null,
      'Pulse.evolve requires at least `pulse` or `step` or `context` not null.',
    );

    // 2. Validate internal invariants (Example: Ensure we aren't evolving a pulse with itself)
    assert(
      !identical(this, pulse),
      'A pulse cannot evolve using itself as the delta provider.',
    );

    // Ensure the new context is a legitimate descendant. Runtime check —
    // an `assert` would evaporate in release builds and leave the lineage
    // gate unenforced.
    if (context != null &&
        this.context != PulseContext.system &&
        context._parent != this.context) {
      throw StateError(
        'Causal Integrity Violation: The new context must be evolved from the current pulse context.',
      );
    }

    if (pulse != null) {
      if (pulse is PulseBase) {
        return pulse._asEvolvedFrom(this, step: step, context: context);
      }
      return _EvolvedPulse(
          context: context,
          step: step,
          pulse: pulse as PulseBase,
          parent: this);
    }
    return _Pulse<P>(context: context, step: step, parent: this);
  }

  /// Wraps [parent] as an [EvolvedPulse] whose payload type is this pulse's [P].
  Pulse<P> _asEvolvedFrom(PulseBase parent,
      {String? step, PulseContext? context}) {
    return _EvolvedPulse<P>(
      context: context,
      step: step,
      pulse: this,
      parent: parent,
    );
  }

  @override
  Pulse<P> withStep(String step) => _StepPulse<P>(this, step);

  @override
  CollectivePulse operator +(covariant Pulse other) {
    return other is Pulse<P>
        ? other is CollectivePulse<P>
            ? _CollectivePulse<P>([this, other])
            : _CollectivePulse<P>([this, other])
        : other is CollectivePulse
            ? _CollectivePulse([this, other])
            : _CollectivePulse([this, other]);
  }

  @override
  PulseBase<P> get unmodifiable => UnmodifiablePulse<P>(this) as PulseBase<P>;

  CycleChecker get _checker {
    // Exception-free: `cycleChecker` is present on every mask record and
    // FinalBox.value returns null before the first write, so the lazily
    // created checker costs no thrown error per pulse. Flat pulses
    // (_FastPulse) keep the checker on the instance instead of the record.
    final r = root;
    if (r is _FastPulse) return r._checker;
    final FinalBox<CycleChecker> finalBox = r._record.cycleChecker;
    final existing = finalBox.value;
    if (existing != null) return existing;
    final created = CycleChecker._();
    finalBox.value = created;
    return created;
  }

  // ───── primary ─────

  /// Main payload.
  @override
  P? get payload {
    if ((_shape & _kPayload) != 0) {
      return _record.root.primary.payload;
    }
    return _pulse?.payload ?? _parent?.payload;
  }

  /// Origin cell (for tracing).
  @override
  Cell? get source {
    if ((_shape & _kSource) != 0) {
      return _record.root.primary.source;
    }
    return _parent?.source;
  }

  /// When this pulse was created.
  @override
  DateTime get timestamp {
    if ((_shape & _kTimestamp) != 0) {
      return _record.root.primary.timestamp;
    }
    final inherited = _parent?.timestamp;
    if (inherited != null) return inherited;
    throw StateError('Pulse record has no timestamp.');
  }

  @override
  PulseEphemeralPolicy? get policy {
    if ((_shape & _kPolicy) != 0) {
      return _record.root.primary.policy;
    }
    return _parent?.policy;
  }

  // ───── secondary ─────

  /// Semantic type classification for pattern matching and routing.
  ///
  /// The value is [dynamic]: commonly a `String` tag, but any object (such as
  /// an enum) may be used as a classifier.
  @override
  dynamic get type {
    if ((_shape & _kType) != 0) {
      return _record.root.secondary.type;
    }
    return _pulse?.type ?? _parent?.type;
  }

  @override
  int get priority {
    int local() {
      if ((_shape & _kPriority) != 0) {
        return _record.root.tertiary.priority;
      }
      return _parent?.priority ?? Pulse.defaultPriority;
    }

    if (context != PulseContext.system) {
      return context.priority ?? local();
    }
    return local();
  }

  /// Execution/security context.
  @override
  PulseContext get context {
    if ((_shape & _kContext) != 0) {
      return _record.root.secondary.context;
    }
    return _parent?.context ?? PulseContext.system;
  }

  /// Causal trace path.
  @override
  List<String> get trace {
    final trace = <String>[];

    iterate(PulseBase? p) {
      String? step;
      while (p != null) {
        if (p is _StepPulse) {
          // Flat step node: its step lives in a plain field, not a record.
          trace.add(p._stepValue);
        } else {
          step =
              (p._shape & _kStep) != 0 ? p._record.root.secondary.step : null;
          if (step != null) {
            trace.add(step);
          }
        }
        p = p._parent;
      }
    }

    iterate(this);

    return trace.reversed.toList(growable: false);
  }

  Function? get _scrutinize {
    if ((_shape & _kScrutinize) != 0) {
      return _record.root.tertiary.scrutinize;
    }
    return null;
  }

  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
    final scrutinize = _scrutinize;
    if (scrutinize != null) {
      try {
        if (namedArguments != null &&
            namedArguments.containsKey(#serializedCompletion)) {
          return scrutinize(receptor,
              serializedCompletion: namedArguments[#serializedCompletion]);
        }
        return scrutinize(receptor);
      } catch (e) {
        return null;
      }
    }

    return receptor(this);
  }

  @override
  PulseShell<P, Receptor> get shell => PulseShell<P, Receptor>(this);

  /// The **Branch Completion Counter** for pulses carrying an `onComplete`
  /// callback.
  ///
  /// This internal getter tracks the remaining terminal branches of the
  /// pulse's own journey through the graph.
  ///
  /// ### When to use
  /// * This is an internal implementation detail. You never access this directly.
  ///   It exists to support the framework's pulse lifecycle management.
  /// * This is used internally by the framework. You don't need to use it
  ///   in application code.
  ///
  /// ### How it works
  /// 1. `mask` allocates `branches: Box<int>(1)` whenever a pulse is created
  ///    with an `onComplete` callback.
  /// 2. Each terminal branch (e.g. empty synapses) decrements the counter
  ///    exactly once.
  /// 3. When the counter reaches zero, `_complete()` fires — which, for
  ///    composites, first completes every sub-pulse depth-first.
  /// 4. This mechanism ensures a pulse completes when its journey reaches a
  ///    terminal, without stranding the callback.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final batch = Pulse.batch([pulse1, pulse2], onComplete: cb);
  /// // _branches.state == 1 (the batch's own journey)
  /// // Terminal branch: _branches.state == 0 -> _complete() -> sub-pulses
  /// // complete first, then the batch callback fires.
  /// ```
  ///
  /// ### Returns:
  /// A [Box<int>] containing the remaining branch count, or `null` if this
  /// pulse's root has no completion callback.
  Box<int>? get _branches {
    // Resolve through the lineage root: evolved descendants share the
    // originating pulse's completion counter, so every terminal along the
    // causal chain decrements the same box. Exception-free read: the
    // `branches` box is only present when `onComplete` was provided.
    final r = root;
    if ((r._shape & _kOnComplete) != 0) {
      return r._record.root.callbacks.branches;
    }
    return null;
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
    if ((_shape & _kOnComplete) != 0) {
      return _record.root.callbacks.onComplete;
    }
    return _parent?._onComplete;
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
  void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?
      get _onError {
    if ((_shape & _kOnError) != 0) {
      return _record.root.callbacks.onError;
    }
    return _parent?._onError;
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
    if ((_shape & _kOnProgress) != 0) {
      return _record.root.callbacks.onProgress;
    }
    return _parent?._onProgress;
  }

  // others

  PulseBase? get _parent {
    if ((_shape & _kParent) != 0) {
      return _record.parent;
    }
    return null;
  }

  PulseBase<P>? get _pulse {
    if ((_shape & _kPulse) != 0) {
      return _record.pulse;
    }
    return null;
  }

  dynamic get _user {
    if ((_shape & _kUser) != 0) {
      return _record.root.tertiary.user;
    }
    return null;
  }

  @override
  PulseBase<P> get root {
    if (_parent == null) {
      return this;
    }

    PulseBase p = this;
    PulseBase? parent = _parent;
    while (parent != null) {
      p = parent;
      parent = p._parent;
    }
    return p as PulseBase<P>;
  }

  @override
  bool get isInvalidated => policy?.isInvalidated ?? false;

  // ────────────────

  static Record mask({
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    dynamic payload,
    dynamic type,
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
    final primaryMask = ((payload != null ? 1 : 0) |
        (source != null ? 2 : 0) |
        (timestamp != null ? 4 : 0) |
        (policy != null ? 8 : 0) |
        (isGoverned ? 16 : 0));

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
      15 => (
          payload: payload,
          source: source,
          timestamp: timestamp,
          policy: policy
        ),
      16 => (isGoverned: isGoverned),
      17 => (payload: payload, isGoverned: isGoverned),
      18 => (source: source, isGoverned: isGoverned),
      19 => (payload: payload, source: source, isGoverned: isGoverned),
      20 => (timestamp: timestamp, isGoverned: isGoverned),
      21 => (payload: payload, timestamp: timestamp, isGoverned: isGoverned),
      22 => (source: source, timestamp: timestamp, isGoverned: isGoverned),
      23 => (
          payload: payload,
          source: source,
          timestamp: timestamp,
          isGoverned: isGoverned
        ),
      24 => (policy: policy, isGoverned: isGoverned),
      25 => (payload: payload, policy: policy, isGoverned: isGoverned),
      26 => (source: source, policy: policy, isGoverned: isGoverned),
      27 => (
          payload: payload,
          source: source,
          policy: policy,
          isGoverned: isGoverned
        ),
      28 => (timestamp: timestamp, policy: policy, isGoverned: isGoverned),
      29 => (
          payload: payload,
          timestamp: timestamp,
          policy: policy,
          isGoverned: isGoverned
        ),
      30 => (
          source: source,
          timestamp: timestamp,
          policy: policy,
          isGoverned: isGoverned
        ),
      31 => (
          payload: payload,
          source: source,
          timestamp: timestamp,
          policy: policy,
          isGoverned: isGoverned
        ),
      _ => ()
    };

    // Architectural placement (Type, Context, Metadata, Step).
    final secondaryMask = ((type != null ? 1 : 0) |
        (context != null ? 2 : 0) |
        (step != null ? 4 : 0));

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
    final tertiaryMask = ((priority != null ? 1 : 0) |
        (user != null ? 2 : 0) |
        (scrutinize != null ? 4 : 0));

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

    final callbackMask = ((onComplete != null ? 1 : 0) |
        (onError != null ? 2 : 0) |
        (onProgress != null ? 4 : 0));

    final callbacks = switch (callbackMask) {
      0 => (),
      1 => (onComplete: onComplete, branches: Box<int>(1)),
      2 => (onError: onError),
      3 => (onComplete: onComplete, branches: Box<int>(1), onError: onError),
      4 => (onProgress: onProgress),
      5 => (
          onComplete: onComplete,
          branches: Box<int>(1),
          onProgress: onProgress
        ),
      6 => (onError: onError, onProgress: onProgress),
      7 => (
          onComplete: onComplete,
          branches: Box<int>(1),
          onError: onError,
          onProgress: onProgress
        ),
      _ => ()
    };

    final finalMask = ((primaryMask > 0 ? 1 : 0) |
            (secondaryMask > 0 ? 2 : 0) |
            (tertiaryMask > 0 ? 4 : 0) |
            (callbackMask > 0 ? 8 : 0) |
            (parent != null ? 16 : 0)) |
        (pulse != null ? 32 : 0);

    // Field-level shape tag packed into one int. Accessors test these bits
    // and then read record fields directly — exception-free hot path.
    final shape = primaryMask |
        (secondaryMask << 8) |
        (tertiaryMask << 16) |
        (callbackMask << 24) |
        ((parent != null ? 1 : 0) << 5) |
        ((pulse != null ? 1 : 0) << 6);

    return switch (finalMask) {
      0 => (shape: shape, cycleChecker: FinalBox<CycleChecker>()),
      1 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary)
        ),
      2 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary)
        ),
      3 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary)
        ),
      4 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary)
        ),
      5 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary)
        ),
      6 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, tertiary: tertiary)
        ),
      7 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, tertiary: tertiary)
        ),
      8 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (callbacks: callbacks)
        ),
      9 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, callbacks: callbacks)
        ),
      10 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, callbacks: callbacks)
        ),
      11 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, callbacks: callbacks)
        ),
      12 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary, callbacks: callbacks)
        ),
      13 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary, callbacks: callbacks)
        ),
      14 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, tertiary: tertiary, callbacks: callbacks)
        ),
      15 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          )
        ),
      16 => (shape: shape, parent: parent),
      17 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary),
          parent: parent
        ),
      18 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary),
          parent: parent
        ),
      19 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary),
          parent: parent
        ),
      20 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary),
          parent: parent
        ),
      21 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary),
          parent: parent
        ),
      22 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, tertiary: tertiary),
          parent: parent
        ),
      23 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, tertiary: tertiary),
          parent: parent
        ),
      24 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (callbacks: callbacks),
          parent: parent
        ),
      25 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, callbacks: callbacks),
          parent: parent
        ),
      26 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, callbacks: callbacks),
          parent: parent
        ),
      27 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, callbacks: callbacks),
          parent: parent
        ),
      28 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary, callbacks: callbacks),
          parent: parent
        ),
      29 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary, callbacks: callbacks),
          parent: parent
        ),
      30 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          parent: parent
        ),
      31 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          parent: parent
        ),
      32 => (shape: shape, pulse: pulse),
      33 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary),
          pulse: pulse
        ),
      34 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary),
          pulse: pulse
        ),
      35 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary),
          pulse: pulse
        ),
      36 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary),
          pulse: pulse
        ),
      37 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary),
          pulse: pulse
        ),
      38 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, tertiary: tertiary),
          pulse: pulse
        ),
      39 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, tertiary: tertiary),
          pulse: pulse
        ),
      40 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (callbacks: callbacks),
          pulse: pulse
        ),
      41 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, callbacks: callbacks),
          pulse: pulse
        ),
      42 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, callbacks: callbacks),
          pulse: pulse
        ),
      43 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, callbacks: callbacks),
          pulse: pulse
        ),
      44 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary, callbacks: callbacks),
          pulse: pulse
        ),
      45 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary, callbacks: callbacks),
          pulse: pulse
        ),
      46 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          pulse: pulse
        ),
      47 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          pulse: pulse
        ),
      48 => (shape: shape, parent: parent, pulse: pulse),
      49 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary),
          parent: parent,
          pulse: pulse
        ),
      50 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary),
          parent: parent,
          pulse: pulse
        ),
      51 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary),
          parent: parent,
          pulse: pulse
        ),
      52 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary),
          parent: parent,
          pulse: pulse
        ),
      53 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary),
          parent: parent,
          pulse: pulse
        ),
      54 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, tertiary: tertiary),
          parent: parent,
          pulse: pulse
        ),
      55 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, tertiary: tertiary),
          parent: parent,
          pulse: pulse
        ),
      56 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      57 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      58 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (secondary: secondary, callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      59 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, secondary: secondary, callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      60 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (tertiary: tertiary, callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      61 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (primary: primary, tertiary: tertiary, callbacks: callbacks),
          parent: parent,
          pulse: pulse
        ),
      62 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          parent: parent,
          pulse: pulse
        ),
      63 => (
          shape: shape,
          cycleChecker: FinalBox<CycleChecker>(),
          root: (
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            callbacks: callbacks
          ),
          parent: parent,
          pulse: pulse
        ),
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
    return 'Pulse<$P>[${type.toString()}] ${payload ?? "null"}';
  }

  @override
  bool get isComposite => false;

  @override
  bool get isGoverned {
    if ((_shape & _kGoverned) != 0) {
      return _record.root.primary.isGoverned || (_parent?.isGoverned ?? false);
    }
    return _parent?.isGoverned ?? false;
  }

  @override
  List<T> lineage<T>(LineageArgument arg) {
    List<T> lineage = [];
    PulseBase? p = this;
    dynamic v;

    while (p != null) {
      switch (arg) {
        // Resolve as `Object?` and filter below: `lineage` deliberately
        // skips ancestors whose value does not match the requested [T]
        // instead of letting the cast throw (see the guarded `add` below).
        case LineageArgument.payload:
          v = get<Object?>(() => p!._record.root.primary.payload,
              fallback: () => p!._record.pulse._record.root.primary.payload,
              orElse: null);

        case LineageArgument.source:
          v = get<Object?>(() => p!._record.root.primary.source,
              fallback: () => p!._record.pulse._record.root.primary.source,
              orElse: null);

        case LineageArgument.policy:
          v = get<Object?>(() => p!._record.root.primary.policy,
              fallback: () => p!._record.pulse._record.root.primary.policy,
              orElse: null);

        case LineageArgument.type:
          v = get<Object?>(() => p!._record.root.secondary.type,
              fallback: () => p!._record.pulse._record.root.secondary.type,
              orElse: null);

        case LineageArgument.priority:
          v = get<Object?>(() => p!._record.root.tertiary.priority,
              fallback: () => p!._record.pulse._record.root.tertiary.priority,
              orElse: null);

        case LineageArgument.context:
          v = get<Object?>(() => p!._record.root.secondary.context,
              fallback: () => p!._record.pulse._record.root.secondary.context,
              orElse: null);
      }

      if (v != null) {
        try {
          lineage.add(v as T);
        } catch (e) {
          // intentionally left blank
        }
      }
      p = p._parent;
    }
    return lineage.reversed.toList(growable: false);
  }
}

/// Defines the specific data field to be extracted when traversing a [Pulse]'s
/// **Causal History** via the `lineage` method.
///
/// Lineage arguments allow the framework to reconstruct the **Provenance Path**
/// of a signal, identifying how properties like security [context], execution
/// [priority], or the [payload] itself have evolved as the pulse moved through
/// the reactive graph.
///
/// ### When to use
/// - **Auditing**: Use [source] or [context] to trace the authority behind a state change.
/// - **Debugging**: Use [payload] to see how data was transformed at each node.
/// - **Policy Inspection**: Use [policy] to understand why a pulse was retained or discarded.
enum LineageArgument {
  /// Extracts the data payload from each pulse in the chain.
  payload,

  /// Extracts the [Cell] that emitted or processed each pulse in the chain.
  source,

  /// Extracts the [PulseEphemeralPolicy] active at each transformation step.
  policy,

  /// Extracts the semantic type string associated with each pulse.
  type,

  /// Extracts the numerical priority level at each step of the lineage.
  priority,

  /// Extracts the [Context] metadata (security, domain) from each pulse.
  context,
}

class UnmodifiableCollectivePulse<P>
    extends _UnmodifiablePulse<Iterable<Pulse<P>>>
    implements CollectivePulse<P>, UnmodifiablePulse<Iterable<Pulse<P>>> {
  UnmodifiableCollectivePulse._(CollectivePulse<P> super.source) : super();

  @override
  Iterable<Pulse<P>> get payload =>
      (_source.payload as Iterable<Pulse<P>>).map((e) => e.unmodifiable);

  @override
  bool get isComposite => true;

  @override
  Iterator<UnmodifiableCollectivePulse<P>> get iterator => [this].iterator;

  @override
  String toString() =>
      'UnmodifiableCollectivePulse<$P>(${(_source as CollectivePulseBase<P>)._toString})';
}

class UnmodifiableEvolvedPulse<P> extends _UnmodifiablePulse<P>
    implements EvolvedPulseBase<P> {
  UnmodifiableEvolvedPulse._(EvolvedPulse<P> super.source) : super();

  @override
  PulseBase get last => (_source as EvolvedPulseBase).last;

  @override
  Pulse get parent => (_source as EvolvedPulse).parent.unmodifiable;

  @override
  String _computeToString() =>
      (_source as EvolvedPulseBase<P>)._computeToString();

  @override
  List<PulseBase<dynamic>> get _pulses {
    return (_source as EvolvedPulseBase<P>)
        ._pulses
        .map((e) => e.unmodifiable)
        .toList(growable: false);
  }

  @override
  String get _toString => (_source as EvolvedPulseBase<P>)._toString;

  @override
  Iterator<PulseBase> get iterator => _pulses.iterator;

  @override
  String toString() => 'UnmodifiableEvolvedPulse<$P>($_toString)';
}

class _UnmodifiablePulse<P> extends UnmodifiablePulseBase<P> {
  _UnmodifiablePulse(super.source);

  @override
  String toString() {
    return 'UnmodifiablePulse<$P>[$type] ${payload ?? "null"}';
  }
}

abstract class UnmodifiablePulseBase<P> extends PulseBase<P>
    implements UnmodifiablePulse<P>, Unmodifiable {
  final PulseBase<P> _source;

  UnmodifiablePulseBase(Pulse<P> source) : _source = source as PulseBase<P>;

  @override
  get _record => _source._record;

  /// Delegate the cycle checker to the wrapped pulse. The inherited
  /// [PulseBase._checker] resolves `root` to this wrapper and then reads
  /// `_record.cycleChecker` — for a `_FastPulse` source that record is the
  /// unit record and the lookup throws a [NoSuchMethodError].
  @override
  CycleChecker get _checker => _source._checker;

  @override
  @override
  P? get payload {
    final sourcePayload = _source.payload;
    if (sourcePayload == null) return null;

    if (sourcePayload is Unmodifiable) {
      return sourcePayload as P;
    }

    if (sourcePayload is Iterable<Cell>) {
      return sourcePayload.map((e) => e.unmodifiable).toList(growable: false)
          as P;
    }

    if (sourcePayload is Map) {
      return (Map.of(sourcePayload)
            ..updateAll((k, v) => v is Cell ? v.unmodifiable : v))
          .cast() as P;
    }

    if (sourcePayload is Cell) {
      return sourcePayload.unmodifiable as P;
    }

    return sourcePayload as P;
  }

  @override
  PulseContext get context => _source.context;

  @override
  bool get isComposite => _source.isComposite;

  @override
  void Function(Pulse pulse)? get _onComplete => _source._onComplete;

  @override
  void Function(Pulse pulse, Object error, {StackTrace? stackTrace})?
      get _onError => _source._onError;

  @override
  void Function(Pulse pulse, Cell cell, {String? message})? get _onProgress =>
      _source._onProgress;

  @override
  PulseBase? get _parent => _source._parent?.unmodifiable;

  @override
  PulseBase<P> get root => _source.root.unmodifiable;

  @override
  Cell? get source => _source.source?.unmodifiable;

  @override
  DateTime get timestamp => _source.timestamp;

  @override
  List<String> get trace => _source.trace;

  @override
  dynamic get type => _source.type;

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
  ///
  /// Identity-based on purpose: deputies are logically `==` to their
  /// principals, but they are distinct graph nodes with their own synapses
  /// and observers. A plain value-equality set would treat a deputy as
  /// already visited the moment its principal processed the pulse, silently
  /// cutting the deputy's entire branch. Real cycles are still caught
  /// because a loop must eventually revisit the *same* object.
  /// The first visited cell. The identity set is only materialized when a
  /// second, different cell is registered — single-path pulses never
  /// allocate one.
  Cell? _single;
  Set<Cell>? _visited;

  /// The set of lifecycle policies that have already been ticked for the
  /// current stimulus wave.
  ///
  /// This guarantees a shared (hosted or inherited) [EphemeralPolicy] counts
  /// each pulse exactly once, no matter how many governed cells the pulse
  /// visits while propagating through the reactive graph.
  Set<EphemeralPolicy>? _tickedPolicies;

  CycleChecker._();

  /// Registers a node in the current traversal path.
  ///
  /// Returns `true` if the [cell] was successfully added (no cycle detected).
  /// Returns `false` if the [cell] was already visited, indicating a
  /// **Circular Dependency**.
  bool add(Cell cell) {
    final single = _single;
    if (single == null) {
      _single = cell;
      return true;
    }
    if (identical(single, cell)) return false;
    final visited = _visited ??= Set<Cell>.identity()..add(single);
    if (visited.contains(cell)) return false;
    visited.add(cell);
    return true;
  }

  /// Verifies if a specific node has already been traversed by the current stimulus.
  ///
  /// This method performs a non-mutating lookup within the **Causal Path** registry,
  /// allowing internal logic to inspect the current propagation state without
  /// registering a new visit.
  bool contains(Cell cell) =>
      identical(_single, cell) || (_visited?.contains(cell) ?? false);

  /// Registers [policy] for the current stimulus wave.
  ///
  /// Returns `true` the first time the policy is seen for this pulse (and
  /// therefore should be ticked), and `false` on subsequent cell visits, so a
  /// policy shared through the upstream [Cell.bind] chain is only counted once
  /// per pulse.
  bool tickPolicy(EphemeralPolicy policy) =>
      (_tickedPolicies ??= <EphemeralPolicy>{}).add(policy);

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
  dynamic scrutinize(covariant T object, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]);
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
class PulseShell<P, R extends Receptor>
    with IterableMixin<Pulse>
    implements Pulse<P>, Shell<R> {
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
  PulseShell<P, R> get shell => this;

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
  dynamic get type => _kernal.type;

  @override
  Pulse<P> get unmodifiable => this;

  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
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

  @override
  List<T> lineage<T>(LineageArgument arg) {
    return const [];
  }
}
