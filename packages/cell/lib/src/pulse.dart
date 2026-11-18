// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// Resolves a `Cell.id` to a live [Cell].
///
/// ### When to use
/// Pass a resolver to [Pulse.fromJson] / [decodePulse] when the decoded
/// pulse carries a `source`. The resolver is the caller's contract with
/// the decoded pulse: it answers "which cell is this id?" The codec does
/// not supply a global registry, because the graph is the caller's
/// context, not the codec's.
///
/// ### How it works
/// The replay engine's resolver reads from the current graph; a unit
/// test's resolver returns a stub cell; a tooling resolver returns
/// `null` for ids that are not in the current graph. A `null` resolution
/// is not an error — the decoded pulse has `source == null`.
///
/// {@category Replay}
typedef PulseResolver = Cell? Function(String id);

// ── Override sentinels ──────────────────────────────────────────────────────
//
// `Pulse.fromJson` accepts an override for every constructor parameter.
// A nullable parameter cannot distinguish "no override" (use the JSON's
// value) from "explicitly override to null", so five `const` singletons
// disambiguate the two. Identity (`identical`) is the only way to use a
// sentinel: a user value that merely equals one by `==` is an override.

/// Explicitly override `policy` to `null` in [Pulse.fromJson].
const Object pulseNullPolicy = _PulseNullPolicy();

/// Explicitly override `payload` to `null` in [Pulse.fromJson].
const Object pulseNullPayload = _PulseNullPayload();

/// Explicitly override `type` to `null` in [Pulse.fromJson].
const Object pulseNullType = _PulseNullType();

/// Explicitly override `source` to `null` in [Pulse.fromJson].
const Object pulseNullSource = _PulseNullSource();

/// Explicitly override `step` to `null` in [Pulse.fromJson].
const Object pulseNullStep = _PulseNullStep();

class _PulseNullPolicy {
  const _PulseNullPolicy();
}

class _PulseNullPayload {
  const _PulseNullPayload();
}

class _PulseNullType {
  const _PulseNullType();
}

class _PulseNullSource {
  const _PulseNullSource();
}

class _PulseNullStep {
  const _PulseNullStep();
}

/// An immutable signal derived from a previous pulse through a transformation
/// step — a causal link in the signal's journey.
///
/// An [EvolvedPulse] is what you get when you call [evolve] on any pulse.
/// It carries a reference to its [parent], preserving the signal's lineage
/// without duplicating data. This is how the framework builds causal chains
/// while keeping memory usage low.
///
/// ### When to use
/// - **Causal Traceability**: You never implement this interface. It's returned by [evolve]. Use it when
///   you need to trace a signal's transformation history — for debugging,
///   auditing, or explainability.
/// - **Tracing** a signal's journey through the reactive graph.
/// - Debugging or auditing the evolution of a pulse.
/// - Building causal chains for explainability (XAI).
/// - Preserving provenance across transformation steps.
/// - Understanding which transformations were applied to a signal.
///
/// ### How it works
/// - Each evolved pulse links back to its [parent] — the pulse it came from.
/// - The [trace] property accumulates steps from all ancestors.
/// - The [root] always points to the original pulse that started the chain.
/// - The payload is inherited from the root — evolved pulses don't duplicate it.
///
/// ### Example
/// ```dart
/// final root = Pulse<int>(42);
/// final evolved = root.evolve(step: 'validation');
/// print(evolved is EvolvedPulse); // true
/// print(evolved.parent); // root
/// print(evolved.trace); // ['validation']
/// ```
///
/// See also:
/// - [Pulse.evolve] – the method that creates evolved pulses.
/// - [Pulse.withStep] – a convenience wrapper around [evolve].
/// - [CollectivePulse] – the flat bundle created by `+` or [Pulse.batch].
abstract interface class EvolvedPulse<P> implements Pulse<P> {
  /// The immediate causal ancestor of this pulse in the processing chain.
  ///
  /// ### When to use
  /// - **Walking History**: You rarely need this directly — it's mostly for debugging or when you
  ///   need to walk a pulse's evolution history manually.
  /// - Debugging to see what a pulse evolved from.
  /// - Building custom tracing or visualisation tools.
  ///
  /// ### How it works
  /// Every call to [evolve] creates a new pulse that links back to the old one
  /// via this property. This forms a chain you can traverse to see the entire
  /// transformation history.
  ///
  /// ### Example
  /// ```dart
  /// final evolved = root.evolve(PulseContext(reason: 'test'), step: 'step1');
  /// print(evolved.parent); // root
  /// ```
  Pulse get parent;

  /// The terminal data result of the evolution chain.
  ///
  /// An [EvolvedPulse] represents a  signal that has undergone one or more
  /// transformations. This getter provides the "Current Truth"—retrieving the
  /// **payload** from the **last pulse** in the causal lineage.
  ///
  /// ### When to use
  /// - **Egress Data Access**: Use this property during the **Egress** phase or within a downstream
  ///   **Transformation** logic block to access the data after all preceding
  ///   evolution steps have been applied.
  /// - Reading the most recent state to update a UI terminal (Egress).
  /// - Passing the result of a multi-step calculation to a target [Cell].
  /// - Inspecting the "Final Output" of a recursive reactive chain.
  ///
  /// ### How it works
  /// 1. The pulse maintains a link to its [EvolvedPulse.parent].
  /// 2. When this getter is called, the framework resolves the causal chain
  ///    to identify the most recent transformation step.
  /// 3. It returns the [payload] of that specific terminal pulse, representing
  ///    the cumulative result of the evolution.
  ///
  /// ### Returns:
  /// The payload of the final pulse in the chain, or `null` if the last step
  /// was a pure control signal or access is restricted by the governance tier.
  @override
  P? get payload;
}

/// A **Collective Pulse** — a flat bundle of independent pulses travelling
/// together as a single atomic wave.
///
/// A [CollectivePulse] is created via [Pulse.batch] or the `+` operator. It
/// represents a collection of pulses processed together. Unlike an
/// [EvolvedPulse], which creates a causal chain, a [CollectivePulse] is flat —
/// each member retains its own identity, trace, and lifecycle.
///
/// ### When to use
/// - **Pulse Batching**: You never implement this interface. It's returned by:
///   - [Pulse.batch] — for explicit batching of multiple pulses.
///   - The `+` operator — for combining two pulses into a collective.
/// - Batch updates that must be processed atomically.
/// - Coordinating multiple state changes that depend on each other.
/// - Reducing overhead by combining several small pulses into one wave.
/// - Applying common metadata to multiple pulses.
/// - When one logical operation spans multiple cells.
///
/// ### How it works
/// - The [payload] is an `Iterable<Pulse<P>>` containing all bundled pulses.
/// - The collective is processed atomically — all sub‑pulses travel together.
/// - Each sub‑pulse retains its independent identity and causal trace.
/// - The collective's [isComposite] returns `true`.
///
/// ### Example
/// ```dart
/// final p1 = Pulse<int>(1);
/// final p2 = Pulse<String>('hello');
/// final collective = Pulse.batch([p1, p2]);
/// // or
/// final combined = p1 + p2;
///
/// print(collective.isComposite); // true
/// for (final p in collective.payload) {
///   print(p.payload); // 1, hello
/// }
/// ```
///
/// See also:
/// - [Pulse.batch] – the factory that creates collective pulses.
/// - [Pulse.+] – the operator that creates collective pulses.
/// - [EvolvedPulse] – the chain‑based composite created by [evolve].
abstract interface class CollectivePulse<P>
    implements Pulse<Iterable<Pulse<P>>> {
  /// Creates a collective pulse from a list of individual pulses.
  ///
  /// ### When to use
  /// - **Bundling Pulses**: Use this factory when you have a list of pulses that should travel
  ///   together as a single atomic unit.
  /// - You already have a list of pulses and want to bundle them.
  /// - You need to apply common metadata to multiple pulses.
  /// - You want to batch pulses from different sources.
  ///
  /// ### How it works
  /// The pulses are bundled into a [CollectivePulse]. Each sub‑pulse retains
  /// its own identity, trace, and callbacks. The collective's metadata (type,
  /// source, priority, step) is applied to the bundle as a whole.
  ///
  /// ### Parameters:
  /// - [pulses]: The individual pulses to bundle.
  /// - [type]: Optional semantic tag for the bundle.
  /// - [source]: Optional originating cell.
  /// - [priority]: Optional urgency (overrides individual priorities).
  /// - [step]: Optional trace step for the bundle.
  factory CollectivePulse.from(Iterable<Pulse<P>> pulses,
      {String? type,
      Cell? source,
      int? priority,
      String? step}) = _CollectivePulse<P>;

  /// Creates a governed collective pulse with lifecycle and security metadata.
  ///
  /// ### When to use
  /// - **Governed Batches**: Use this when the collective itself needs governance — TTL, audit level,
  ///   or a custom security context — beyond what individual pulses provide.
  /// - The collective as a whole needs a TTL or hop limit.
  /// - You need audit-level logging for the entire batch.
  /// - Individual pulses don't have governance, but the batch does.
  /// - You want completion/error callbacks for the batch.
  ///
  /// ### How it works
  /// The [policy] controls the collective's lifetime (TTL/hop limit). The
  /// [context] provides provenance metadata for the bundle. Callbacks are
  /// attached to the collective and fire once when all sub‑pulses complete.
  ///
  /// ### Parameters:
  /// - [pulses]: The individual pulses to bundle.
  /// - [policy]: Optional lifecycle policy (TTL/hop limit).
  /// - [context]: Optional provenance context.
  /// - [type]: Optional semantic tag.
  /// - [source]: Optional originating cell.
  /// - [step]: Optional trace step.
  /// - [priority]: Optional urgency.
  /// - [onComplete]: Called when all sub‑pulses complete.
  /// - [onError]: Called if any sub‑pulse fails.
  /// - [onProgress]: Called during processing.
  /// - [scrutinize]: Optional authorization challenge function.
  factory CollectivePulse.governed(
    Iterable<Pulse<P>> pulses, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    String? type,
    Cell? source,
    String? step,
    int? priority,
    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,
    FutureOr<Pulse?> Function(Receptor receptor, {bool? serializedCompletion})?
        scrutinize,
  }) = _CollectivePulse<P>;

  /// The collection of pulses bundled in this collective.
  ///
  /// ### When to use
  /// - **Accessing Members**: Use this to access the individual pulses in the collective.
  /// - Access the individual pulses.
  /// - Iterate over the pulses manually.
  /// - Check the size of the collective.
  /// - Extract a specific pulse from the bundle.
  ///
  /// ### Example
  /// ```dart
  /// for (final p in collective.payload) {
  ///   print(p.payload);
  /// }
  /// ```
  @override
  Iterable<Pulse<P>> get payload;
}

/// A reactive signal — the fundamental unit of communication in the framework.
///
/// A [Pulse] is an immutable message that carries data, provenance, and
/// governance metadata through the reactive graph. It's the signal that cells
/// emit and observe — the "currency" of the switching fabric.
///
/// ### When to use
/// - **Communication**: Most of the time, you don't create pulses directly. Cells do it for you:
///   - [Cell.ingress] wraps external events in pulses.
///   - [Cell.state] emits pulses when state changes.
///   - [Cell.derive] transforms pulses into new pulses.
/// - **Manual Injection**: When you do need to create one, use the simple factory:
/// ```dart
/// final pulse = Pulse('Hello, World!');
/// ```
///
/// ### What a pulse carries
/// - **[payload]**: the actual data (the signal's content).
/// - **[type]**: a semantic classification for routing and filtering. It is
///   commonly a `String` tag, but may be any object (such as an enum).
/// - **[priority]**: urgency (0‑100, higher = more urgent).
/// - **[context]**: provenance — who sent it, why, with what clearance.
/// - **[trace]**: a breadcrumb trail of transformations.
/// - **[policy]**: lifecycle constraints (TTL, hop limit).
///
/// ### How it works
/// Pulses are immutable — you can't change one. To "update" a pulse, you
/// [evolve] it, creating a new pulse that links back to the original. This is
/// how the framework preserves causal history without duplicating data.
///
/// ### Example: Creating and Evolving a Pulse
/// ```dart
/// final root = Pulse<int>(42, type: 'counter');
/// final evolved = root
///   .withStep('validation')
///   .withStep('transformation');
///
/// print(evolved.payload); // 42 (inherited)
/// print(evolved.trace); // ['validation', 'transformation']
/// print(evolved.type); // 'counter' (inherited)
/// ```
///
/// See also:
/// - [Pulse.governed] – for pulses with explicit governance.
/// - [EvolvedPulse] – the causal chain created by [evolve].
/// - [CollectivePulse] – a flat bundle of pulses.
/// - [PulseShell] – a defensive proxy for untrusted receivers.
///
/// {@category Signals & Synapses}
/// {@category Pulse}
///
/// ### AI Agent Guide
/// **Layer:** Cell — this is the graph's message, not an operator (Flow), not a book (Tissue).
/// **When to use:** read `pulse.payload`, `pulse.source`, `pulse.type` in observers; create one for manual injection (`Pulse(value, type: '...')`).
/// **When NOT to use:** as a storage unit — state lives in `Cell.state` / Tissue books; pulses are immutable signals.
/// **Live signature:** `Pulse<P>(P? payload, {dynamic type, Cell? source, int? priority, String? step})` — pinned at `cell: 2.0.0`
/// **Do NOT confuse with:** `TissuePulse` (the collection-event variant in `cell_tissue`).
/// **Guide:** `guide/HowTo-Pulse.md` (pulse anatomy)
/// **Example:** `example/ingress_demo.dart`
/// **Cross-layer:** a Flow instruction emits evolved pulses; a Tissue mutation emits `TissuePulse`.
/// **Minimal compilable example**
/// ```dart
/// final p = Pulse<int>(42, type: 'counter', step: 'init');
/// print('${p.payload},${p.type}'); // 42,counter
/// ```
abstract interface class Pulse<P>
    implements Iterable<Pulse>, Comparable<Pulse<P>> {
  /// The default priority for pulses when none is specified.
  ///
  /// ### When to use
  /// * You rarely need this constant directly — it's the framework's fallback
  ///   when a pulse is created without an explicit priority.
  /// * Reading the default priority value.
  /// * Understanding the baseline urgency of ungoverned pulses.
  /// * Comparing against custom priorities.
  ///
  static int defaultPriority = 20;

  /// Creates a simple, ungoverned pulse.
  ///
  /// ### When to use
  /// - **Simple Propagation**: Use this for simple signals that don't need explicit governance (TTL,
  ///   audit, or custom provenance). For governed pulses, use [Pulse.governed].
  /// - Simple data transfer without governance requirements.
  /// - Signals that don't need TTL or hop limits.
  /// - Quick prototypes or tests.
  /// - When you don't need audit-level logging.
  ///
  /// ### How it works
  /// The pulse is created with the given [payload], optional [type], [source],
  /// [priority], and [step]. It inherits the default [PulseContext.system].
  ///
  /// ### Parameters:
  /// - [payload]: The data carried by the pulse.
  /// - [type]: Optional semantic classification for routing. Commonly a
  ///   `String` tag, but any object (such as an enum) may be supplied.
  /// - [source]: Optional originating cell.
  /// - [priority]: Urgency (defaults to [defaultPriority]).
  /// - [step]: Optional trace step (like an initial breadcrumb).
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse('Hello', type: 'message', priority: 60);
  /// ```
  factory Pulse(P? payload,
          {dynamic type, Cell? source, int? priority, String? step}) =>
      _Pulse<P>(
          payload: payload,
          type: type,
          source: source,
          priority: priority,
          step: step);

  /// Creates a governed pulse with lifecycle and security metadata.
  ///
  /// ### When to use
  /// - **Governed Signals**: Use this when you need a pulse to have explicit governance — TTL, hop
  ///   limits, a custom security context, or completion/error callbacks.
  /// - Pulses that must self-destruct after a time (TTL).
  /// - Signals with hop limits to prevent infinite propagation.
  /// - Audited signals requiring full provenance.
  /// - Security-sensitive signals with clearance requirements.
  /// - Signals that need completion/error callbacks.
  /// - Regulatory compliance (GDPR, HIPAA, PCI-DSS).
  ///
  /// ### How it works
  /// - The [policy] defines the pulse's lifetime (TTL and/or hop limit).
  /// - The [context] provides provenance (actor, reason, sensitivity, etc.).
  /// - Callbacks (`onComplete`, `onError`, `onProgress`) are attached to the
  ///   pulse and fire during its lifecycle.
  ///
  /// ### Example: A Time‑Sensitive Token
  /// ```dart
  /// final token = Pulse.governed<String>(
  ///   payload: 'session_123',
  ///   policy: PulseEphemeralPolicy(
  ///     duration: Duration(minutes: 5),
  ///     onInvalidate: (Pulse p) =>. print('Token expired'),
  ///   ),
  ///   context: PulseContext.userAction(
  ///     actor: 'admin',
  ///     reason: 'Session creation',
  ///   ),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [policy]: Lifecycle governance (TTL, hop limit, invalidation hook).
  /// - [context]: Provenance metadata (actor, reason, sensitivity, etc.).
  /// - [payload]: The data.
  /// - [type]: Optional semantic tag.
  /// - [source]: Optional originating cell.
  /// - [step]: Optional trace step.
  /// - [priority]: Urgency (defaults to [defaultPriority]).
  /// - [onComplete]: Called when the pulse successfully completes.
  /// - [onError]: Called if the pulse fails during processing.
  /// - [onProgress]: Called during processing (for long operations).
  ///
  /// See also: [PulseEphemeralPolicy], [PulseContext], [Pulse.governed].
  factory Pulse.governed({
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    P? payload,
    String? type,
    Cell? source,
    String? step,
    int? priority,
    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,
  }) = _Pulse<P>;

  /// Creates a collective pulse from an iterable of individual pulses.
  ///
  /// ### When to use
  /// - **Atomic Bundling**: Use this when you have several pulses that should travel together as a
  ///   single atomic unit — for example, when one logical operation updates
  ///   multiple cells, and you want all updates to propagate together.
  /// - One logical operation updates multiple cells.
  /// - You want atomic propagation across several signals.
  /// - Reducing dispatch overhead by batching.
  /// - Applying common metadata to a group of pulses.
  /// - Coordinating multiple state changes that depend on each other.
  ///
  /// ### How it works
  /// The individual pulses are bundled into a [CollectivePulse]. The collective
  /// moves through the graph as a single entity, but each sub‑pulse retains
  /// its own identity, trace, and callbacks.
  ///
  /// ### Parameters:
  /// - [pulses]: The pulses to bundle.
  /// - [policy]: Optional lifecycle policy for the bundle.
  /// - [context]: Optional provenance context for the bundle.
  /// - [type]: Optional semantic tag.
  /// - [source]: Optional originating cell.
  /// - [step]: Optional trace step.
  /// - [priority]: Optional urgency (overrides individual priorities).
  /// - [onComplete]: Called when all sub‑pulses complete.
  /// - [onError]: Called if any sub‑pulse fails.
  /// - [onProgress]: Called during processing.
  ///
  /// ### Example
  /// ```dart
  /// final pulse1 = Pulse('Update user');
  /// final pulse2 = Pulse('Update account');
  /// final batch = Pulse.batch([pulse1, pulse2]);
  /// ```
  static Pulse batch<P>(
    Iterable<Pulse<P>> pulses, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    String? type,
    Cell? source,
    String? step,
    int? priority,
    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,
  }) =>
      _CollectivePulse<P>(
        pulses,
        policy: policy,
        context: context,
        type: type,
        source: source,
        step: step,
        priority: priority,
        onComplete: onComplete,
        onError: onError,
        onProgress: onProgress,
      );

  /// Constructs a pulse from the canonical JSON produced by
  /// [Pulse.toJson], with optional overrides for every constructor
  /// parameter.
  ///
  /// The result is a **decoded pulse** — its `source` is resolved via
  /// [resolver] (or overridden by `source`), its `policy` and callbacks
  /// are `null` unless overridden, and its `branches` and cycle checker
  /// are fresh. The decoded pulse is semantically the same pulse the
  /// original had on the wire, plus the caller's overrides.
  ///
  /// ## Version discriminator
  ///
  /// The JSON must carry `"__pulse__": "<version>"` where `<version>` is
  /// supported by the current codec (`1.x`). A missing or unsupported
  /// version throws [PulseDecodeError].
  ///
  /// ## Source resolution
  ///
  /// If the encoded pulse carries a `source`, [resolver] is called with
  /// the encoded [Cell.id]. The resolver returns the live cell with that
  /// id, or `null` if the cell is not in the current graph. A `null`
  /// resolution is not an error — the decoded pulse has `source == null`.
  ///
  /// If `source` is passed, it overrides the resolver's result. To
  /// **strip** a source from the JSON, pass `source: pulseNullSource`.
  ///
  /// ## Overrides
  ///
  /// Every override is optional. An absent override means "use the JSON's
  /// value." A sentinel (`pulseNullX`) means "explicitly override to
  /// null." Anything else is an override.
  ///
  /// | Field | Absent override | Override | Sentinel |
  /// |---|---|---|---|
  /// | `policy` | `null` (a decoded pulse never has a policy) | the given policy | `pulseNullPolicy` (equivalent to absent) |
  /// | `context` | the JSON's context | the given context | — (`null` means "use JSON") |
  /// | `payload` | the JSON's payload | the given payload | `pulseNullPayload` |
  /// | `type` | the JSON's type (inheriting from parent) | the given type | `pulseNullType` |
  /// | `source` | the resolved source, or `null` | the given source | `pulseNullSource` |
  /// | `step` | the JSON's step | the given step | `pulseNullStep` |
  /// | `priority` | the JSON's priority (inheriting from parent) | the given priority | — (`null` means "use JSON") |
  /// | `onComplete` | `null` | the given callback | — (`null` means "use JSON", i.e., none) |
  /// | `onError` | `null` | the given callback | — (`null` means "use JSON", i.e., none) |
  /// | `onProgress` | `null` | the given callback | — (`null` means "use JSON", i.e., none) |
  ///
  /// ## Collective pulses
  ///
  /// A JSON with `isComposite: true` cannot have a `payload` override;
  /// the factory throws [PulseDecodeError]. The `children` cannot be
  /// overridden; a caller who wants different children constructs a new
  /// collective via [Pulse.batch].
  ///
  /// ## Re-encodability
  ///
  /// A pulse with an overridden `onComplete`, `onError`, `onProgress`, or
  /// `policy` cannot be re-encoded. [Pulse.toJson] on the result throws
  /// the corresponding [PulseNotSerializable]. This is the honest answer:
  /// the caller chose to attach a non-serializable field.
  ///
  /// ## Errors
  ///
  /// - [PulseDecodeError] if the JSON is malformed, the version is
  ///   unsupported, or an override is invalid for the JSON's shape.
  /// - [PulseNotSerializable] is **not** thrown by this factory; it is
  ///   thrown by [Pulse.toJson].
  factory Pulse.fromJson(
    Map<String, dynamic> json, {
    PulseResolver? resolver,

    // Overrides. Absent or null means "use the JSON's value."
    // Sentinels mean "explicitly override to null."
    Object? policy,
    PulseContext? context,
    Object? payload,
    Object? type,
    Object? source,
    Object? step,
    int? priority,
    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,
  }) {
    // 1. Reject an invalid override before any decoding work.
    if (json['isComposite'] == true && payload != null) {
      throw PulseDecodeError(
        'cannot override payload on a collective pulse; '
        'construct via Pulse.batch',
      );
    }

    // 2. Decode the JSON's envelope.
    final decoded = decodePulse(json, resolver: resolver);

    // 3. Apply overrides. The helper implements the sentinel convention:
    //    absent → JSON's value; sentinel → explicit null; present → the
    //    override. Sentinels compare by identity — pass the sentinel
    //    itself, never a value that merely equals it.
    T? resolveOverride<T>(Object? override, Object sentinel, T? current) {
      if (identical(override, sentinel)) return null;
      if (override == null) return current;
      return override as T;
    }

    final effectivePayload =
        resolveOverride<P>(payload, pulseNullPayload, decoded.payload as P?);
    final effectiveType =
        resolveOverride<Object?>(type, pulseNullType, decoded.type);
    final effectiveSource =
        resolveOverride<Cell>(source, pulseNullSource, decoded.source);
    final effectiveStep =
        resolveOverride<String>(step, pulseNullStep, _localStepOf(decoded));
    final effectivePolicy = identical(policy, pulseNullPolicy)
        ? null
        : (policy as PulseEphemeralPolicy?);
    final effectiveContext = context ?? decoded.context;
    final effectivePriority = priority ?? decoded.priority;
    final effectiveParent = decoded._parent;

    // 4. Construct. The type parameter P is the caller's; the cast is
    //    safe because the override or the decoded payload is already
    //    the correct type.
    return _Pulse<P>(
      payload: effectivePayload,
      type: effectiveType,
      context: effectiveContext,
      timestamp: decoded.timestamp,
      source: effectiveSource,
      step: effectiveStep,
      priority: effectivePriority,
      policy: effectivePolicy,
      parent: effectiveParent,
      onComplete: onComplete,
      onError: onError,
      onProgress: onProgress,
    );
  }

  /// The primary data or instruction carried by this signal.
  ///
  /// ### When to use
  /// * This is the reason the pulse exists — the actual data you want to send.
  ///   Read it to get the signal's content.
  /// * Reading the signal's content.
  /// * Extracting data for processing.
  /// * Inspecting what a pulse carries.
  ///
  /// ### How it works
  /// The payload is resolved by walking up the parent chain. Evolved pulses
  /// inherit their payload from their root — they don't duplicate it.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse<String>('Hello');
  /// print(pulse.payload); // 'Hello'
  /// ```
  P? get payload;

  /// Challenges a receptor to prove it has the authority to see this pulse.
  ///
  /// ### When to use
  /// - **Security Handshake**: You rarely call this directly — the framework uses it internally during
  ///   the reciprocal handshake. It's the mechanism that lets a pulse challenge
  ///   a receptor before revealing its payload.
  /// - Custom authorization logic.
  /// - Testing or debugging the handshake.
  /// - Advanced security scenarios.
  /// - When you need to implement a custom [PulseShell].
  ///
  /// ### How it works
  /// The receptor must "submit" itself to the pulse. The pulse examines the
  /// receptor's host cell, its governed status, and its context. If the
  /// receptor passes scrutiny, the pulse unlocks and returns its kernel
  /// (payload). If not, it returns `null` — the signal is neutralised.
  ///
  /// ### Parameters:
  /// - [receptor]: The entity requesting access to the pulse's internal state.
  /// - [positionalArguments]: Contextual data for the handshake.
  /// - [namedArguments]: Additional named parameters (e.g., `serializedCompletion`).
  ///
  /// ### Returns:
  /// The internal kernel if authorised; `null` if neutralised.
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]);

  /// Creates a derived version of this pulse for the next processing stage.
  ///
  /// ### When to use
  /// - **Next Stage Evolution**: Use this when you need to change a pulse's context (authority, reason,
  ///   priority) or add a trace step without losing its causal history.
  /// - Adding a step to the causal trace.
  /// - Updating a pulse's provenance context.
  /// - Preserving causal history across transformations.
  /// - Annotating a signal's journey through the graph.
  ///
  /// ### How it works
  /// You provide a new [pulse] (to append), a [step] description, and/or a
  /// new [context]. The new pulse links back to this one via [EvolvedPulse.parent],
  /// preserving the history.
  ///
  /// ### Causal Integrity (Enhanced Logic)
  /// To maintain strict provenance, the framework enforces **Contextual Lineage**:
  /// - If a new [context] is provided, it **must** be a direct descendant of the current
  ///   pulse's context (`context.parent == this.context`).
  /// - An exception is made if the current pulse is in the `PulseContext.system`
  ///   (root) context, which is permitted to evolve into any specialized context.
  /// - Attempting to "jump" a pulse to an unrelated context will trigger an [AssertionError].
  ///
  /// ### Parameters:
  /// - [pulse]: An optional pulse to append to the chain.
  /// - [step]: A descriptive string added to the [trace] log.
  /// - [context]: A new [PulseContext]. Must be a descendant of the current context
  ///   to satisfy causal integrity requirements.
  ///
  /// ### Returns:
  /// A new [Pulse] with the causal lineage preserved.
  ///
  /// ### Example
  /// ```dart
  /// final root = Pulse<int>(42);
  /// // Evolution within the same context tree
  /// final childContext = root.context.evolve(reason: 'processing');
  /// final evolved = root.evolve(step: 'sanitization', context: childContext);
  /// ```
  Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context});

  /// Appends [step] to the pulse's causal trace without branching the
  /// causal chain.
  ///
  /// Returns a new flat marker pulse that carries the same payload and
  /// context with [step] appended to its lineage; the original pulse is
  /// unchanged.
  ///
  /// ### Example
  /// ```dart
  /// final root = Pulse<int>(10);
  /// final processed = root.withStep('sanitized').withStep('validated');
  ///
  /// print(processed.trace);  // ['sanitized', 'validated']
  /// print(root.trace);       // [] (root doesn't know about future steps)
  /// print(processed.length); // 1 (lineage lengthened, not evolved)
  /// ```
  Pulse<P> withStep(String step);

  /// Returns an iterator over the sub‑pulses in this pulse.
  ///
  /// ### When to use
  /// * Use this to iterate over the individual pulses in a composite.
  /// * Iterating over the pulses in a collective.
  /// * Processing each pulse in a bundle individually.
  /// * Checking what pulses are in a composite.
  ///
  /// ### How it works
  /// - For a standard or collective pulse: returns an iterator over a single
  ///   element — the pulse itself.
  /// - For an evolved pulse: returns an iterator over the entire chain.
  ///
  /// ### Example
  /// ```dart
  /// final collective = Pulse<int>(1) + Pulse<String>('hello');
  /// for (final p in collective) {
  ///   print(p.payload); // Outputs: 1, hello
  /// }
  /// ```
  @override
  Iterator<Pulse> get iterator;

  /// Returns a **Defensive Proxy** of this pulse for untrusted receivers.
  ///
  /// ### When to use
  /// - **Untrusted Receivers**: Use this when you need to send a pulse to an untrusted component — a UI
  ///   widget, an external logger, or a third‑party plugin. The shell forces the
  ///   receiver to authenticate before the payload is revealed.
  /// - Sending pulses to untrusted components.
  /// - Protecting sensitive payloads from unauthorised access.
  /// - Zero‑trust propagation scenarios.
  /// - When you want the receiver to authenticate before seeing the data.
  /// - External APIs, loggers, or UI widgets that shouldn't see raw data.
  ///
  /// ### How it works
  /// The shell wraps the pulse and hides its payload. Any attempt to access
  /// the payload must go through [scrutinize], which forces the receiver to
  /// prove its identity and clearance.
  ///
  /// ### Returns:
  /// A [PulseShell] that gates access until **Reciprocal Authorization** is satisfied.
  PulseShell<P, Receptor> get shell;

  /// The exact moment this pulse was synthesised.
  ///
  /// ### When to use
  /// - **Temporal Ordering**: Read this to know when the pulse was created — useful for debugging,
  ///   auditing, or ordering signals in time.
  /// - Debugging to understand signal timing.
  /// - Auditing to know when an event occurred.
  /// - Ordering signals chronologically.
  /// - Performance analysis.
  ///
  /// ### How it works
  /// The timestamp is set when the root pulse is created and inherited by all
  /// derived pulses. It never changes.
  ///
  DateTime get timestamp;

  /// A semantic identifier representing the category or intent of the pulse.
  ///
  /// ### When to use
  /// * Use this to tag pulses by type — 'user_login', 'system_heartbeat',
  ///   'data_update'. It's useful for routing and filtering in hubs and valves.
  /// * Routing pulses to specific handlers in a hub.
  /// * Filtering pulses in a valve.
  /// * Categorising signals for monitoring.
  /// * Pattern matching in custom receptors.
  ///
  /// ### How it works
  /// The type is resolved by walking up the parent chain if not overridden.
  /// It's a semantic tag that travels with the pulse. The value is [dynamic]:
  /// most pulses use a `String` tag, but richer classifiers (for example an
  /// enum such as a domain event type) are also supported.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<String>(
  ///   payload: 'New Email',
  ///   type: 'action:update_email',
  /// );
  ///
  /// // In a Receptor
  /// if (pulse.type == 'action:update_email') {
  ///   // Handle email update
  /// }
  /// ```
  ///
  /// ### Example: non‑String classifier
  /// ```dart
  /// enum MailAction { update, archive }
  ///
  /// final pulse = Pulse<String>('New Email', type: MailAction.update);
  /// if (pulse.type == MailAction.update) {
  ///   // Handle email update
  /// }
  /// ```
  dynamic get type;

  /// The execution priority of this pulse (0‑100, higher = more urgent).
  ///
  /// ### When to use
  /// - **Execution Scheduling**: Set this when you need a pulse to jump the queue — for emergency signals
  ///   or user‑facing interactions that demand low latency.
  /// - User‑facing interactions needing low latency.
  /// - Emergency signals that must preempt others.
  /// - Background tasks that can wait.
  /// - Critical system operations.
  ///
  /// ### How it works
  /// The framework's dispatcher uses this to prioritise signals. Higher
  /// priority pulses are processed before lower priority ones.
  ///
  /// ### Priority Tiers (recommended)
  /// - **0‑20**: Background (telemetry, maintenance)
  /// - **21‑50**: Routine (standard operations)
  /// - **51‑80**: High (user interactions)
  /// - **81‑95**: Critical (system safety)
  /// - **96‑100**: Emergency (system recovery)
  ///
  /// ### Example
  /// ```dart
  /// final urgent = Pulse.governed<int>(
  ///   payload: 42,
  ///   priority: 95,  // Critical
  /// );
  /// ```
  int get priority;

  /// The lifecycle governance policy for this pulse.
  ///
  /// ### When to use
  /// * Use this when you need a pulse to self‑destruct — to prevent stale signals
  ///   from propagating forever, or to limit the number of hops.
  /// * Preventing stale signals from propagating.
  /// * Limiting propagation depth (hop limit).
  /// * Time‑sensitive operations that must expire.
  /// * Circuit breaker patterns.
  /// * Automatic cleanup of transient signals.
  ///
  /// ### How it works
  /// The policy enforces a TTL (time‑to‑live) and/or hop limit. The pulse is
  /// neutralised if it exceeds either limit. The framework checks this
  /// automatically during propagation.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<int>(
  ///   payload: 42,
  ///   policy: PulseEphemeralPolicy(
  ///     hopLimit: 3,
  ///     duration: Duration(seconds: 5),
  ///     onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
  ///     onInvalidate: (pulse) => print('Pulse expired'),
  ///   ),
  /// );
  /// ```
  PulseEphemeralPolicy? get policy;

  /// The operational tier and security authority under which this pulse propagates.
  ///
  /// ### When to use
  /// - **Security & Provenance**: Read this to understand the pulse's authority
  ///   — who sent it, why, and with what clearance. The framework uses it for
  ///   validation and auditing.
  /// - Validating a pulse's authority in a custom receptor.
  /// - Auditing who sent a signal.
  /// - Checking clearance before processing sensitive data.
  /// - Understanding the provenance of a signal.
  ///
  /// ### How it works
  /// The context carries actor, reason, sensitivity, and compliance metadata.
  /// It's resolved by walking up the parent chain if not explicitly set.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse.governed<int>(
  ///   payload: 42,
  ///   context: PulseContext(
  ///     actor: 'admin',
  ///     reason: 'system_update',
  ///     sensitivity: Sensitivity.confidential,
  ///   ),
  /// );
  /// ```
  PulseContext get context;

  /// The cell that originally emitted this pulse's lineage.
  ///
  /// ### When to use
  /// - **Origin Tracking**: Read this to know which cell originally sent the pulse — useful for
  ///   debugging, auditing, or loop prevention.
  /// - Debugging to trace the origin of a signal.
  /// - Auditing to know where a change came from.
  /// - Loop prevention (avoiding cycles).
  /// - Understanding the source of a signal.
  ///
  /// ### How it works
  /// The source is set when the root pulse is created and inherited by all
  /// derived pulses. It never changes.
  Cell? get source;

  /// An ordered sequence of steps documenting the signal's journey.
  ///
  /// ### When to use
  /// - **Forensic Auditing**: Use this for debugging or auditing — it shows every step the pulse has
  ///   taken through the graph.
  /// - Debugging to see what transformations were applied.
  /// - Auditing to understand a signal's journey.
  /// - Explainable AI (XAI) to show decision steps.
  /// - Understanding the evolution of a signal.
  ///
  /// ### How it works
  /// Every call to [evolve] or [withStep] appends to the trace. The list is
  /// accumulated by walking up the parent chain.
  ///
  /// ### Example
  /// ```dart
  /// final evolved = root
  ///   .withStep('validation')
  ///   .withStep('transformation')
  ///   .withStep('persistence');
  ///
  /// print(evolved.trace); // ['validation', 'transformation', 'persistence']
  /// ```
  List<String> get trace;

  /// The primordial ancestor that initiated this pulse's causal lineage.
  ///
  /// The root represents the "ground truth" of a signal before any
  /// transformations, metadata evolutions, or diagnostic steps were applied.
  ///
  /// ### When to use
  /// *   **Root Cause Analysis**: Use this to trace a signal back to its point
  ///     of origin during debugging or forensic auditing.
  /// *   **Intent Preservation**: Access the root when you need to verify the
  ///     original, unmodified payload or context that started a propagation
  ///     event.
  /// *   **Lineage Correlation**: Identifying if two different pulses in the
  ///     graph share the same starting point.
  ///
  /// ### How it works
  /// The [root] is established when the first pulse in a chain is constructed.
  /// Every subsequent evolution (via [evolve], [withStep], or [map]) inherits
  /// this reference. It is immutable and persists throughout the entire
  /// lifecycle of the signal.
  ///
  /// ### Example
  /// ```dart
  /// final original = Pulse<int>(1);
  /// final evolved = original
  ///   .withStep('sanitized')
  ///   .withStep('validated');
  ///
  /// print(evolved.trace);  // ['sanitized', 'validated']
  /// print(original.trace); // [] (The root doesn't know about future steps)
  ///
  /// print(identical(evolved.root, original)); // true
  /// ```
  Pulse<P> get root;

  /// Indicates whether this pulse is a multi-message bundle (a collection).
  ///
  /// ### When to use
  /// - **Bundle Detection**: Check this before iterating over a pulse to
  ///   determine if it contains a single signal or a collection of signals.
  /// - **Conditional Logic**: Use this to branch logic based on whether a
  ///   receptor is receiving an atomic update or a batch of updates.
  ///
  /// ### How it works
  /// A pulse is considered composite only when it acts as a container for
  /// other pulses. This occurs through:
  /// 1.  **Binary Composition**: Using the `+` operator.
  /// 2.  **Flat Aggregation**: Using the [Pulse.batch] factory or `.batch()`
  ///     extension.
  /// 3.  **Explicit Evolution**: Calling [evolve] while passing a new
  ///     [Pulse].
  ///
  /// ### Example
  /// ```dart
  /// final p1 = Pulse(1).withStep('validated');
  /// print(p1.isComposite); // false (still one signal)
  ///
  /// final p2 = Pulse(2);
  /// final bundle = p1 + p2;
  /// print(bundle.isComposite); // true (contains two signals)
  /// ```
  bool get isComposite;

  /// Indicates whether this message has reached its terminal lifecycle state.
  ///
  /// ### Where to start
  /// Check this before processing a pulse to ensure it's still valid —
  /// especially if it has a [PulseEphemeralPolicy].
  ///
  /// ### When to use
  /// - Before processing a pulse to ensure it's valid.
  /// - In custom receptors to skip stale signals.
  /// - Debugging expired pulses.
  /// - Conditional logic based on pulse validity.
  ///
  /// ### How it works
  /// A pulse becomes invalid if its TTL expires or it exceeds its hop limit.
  /// The framework checks this automatically, but you can also check manually.
  ///
  /// ### Example
  /// ```dart
  /// if (pulse.isInvalidated) {
  ///   // Pulse is stale, ignore it
  ///   return;
  /// }
  /// // Process the valid pulse
  /// ```
  bool get isInvalidated;

  /// Indicates whether this pulse is subject to explicit governance.
  ///
  /// ### When to use
  /// - **Governance Awareness**: This is mostly informational — you might use it to conditionally apply
  ///   stricter handling in custom code.
  /// - Conditional logic based on governance status.
  /// - Debugging to know if a pulse has a context or policy.
  /// - Applying stricter handling to governed pulses.
  ///
  /// ### How it works
  /// A pulse is governed if it was created with a non‑default [PulseContext]
  /// and/or a [PulseEphemeralPolicy]. The `isGoverned` flag is set in the
  /// record at construction time and resolved by walking up the parent chain
  /// if not found locally.
  ///
  /// ### Returns:
  /// `true` if the pulse has explicit governance (Context or Policy),
  /// `false` otherwise.
  bool get isGoverned;

  /// Combines this pulse and [other] into a composite [CollectivePulse].
  ///
  /// This operator performs **binary composition**. It treats both operands
  /// as distinct units, creating a new pulse whose payload contains exactly
  /// two elements: this pulse and the [other] pulse.
  ///
  /// ### When to use
  /// *   **Pairing**: Use this to link two signals where the relationship between
  ///     them (the "left" and "right" sides) is semantically meaningful.
  /// *   **Ad-hoc Bundling**: Quickly grouping two pulses for simultaneous
  ///     propagation without pre-allocating a list.
  ///
  /// ### How it works
  /// Unlike [Pulse.batch], this operator **does not flatten** the resulting
  /// structure. If you add a [CollectivePulse] to a [Pulse], the result is
  /// a new [CollectivePulse] where one of the two elements is itself a
  /// [CollectivePulse].
  ///
  /// ### Comparison: `+` vs `Pulse.batch`
  /// | Feature | `operator +` | `Pulse.batch()` |
  /// | :--- | :--- | :--- |
  /// | **Logic** | Binary Composition (Nesting) | Flattened Aggregation |
  /// | **Structure** | Always creates a pair | Creates a flat list |
  /// | **Payload** | `[Pulse, Pulse]` | `[Pulse, Pulse, Pulse, ...]` |
  ///
  /// ### Example
  /// ```dart
  /// final p1 = Pulse('A');
  /// final p2 = Pulse('B');
  /// final p3 = Pulse('C');
  ///
  /// // Binary composition creates a nested structure
  /// final nested = p1 + p2 + p3;
  /// print(nested.payload.length); // 2
  /// print(nested.payload.first is CollectivePulse); // true
  ///
  /// // Batching creates a flat structure
  /// final flat = Pulse.batch([p1, p2, p3]);
  /// print(flat.payload.length); // 3
  /// ```
  ///
  /// See also:
  /// * [Pulse.batch] for creating a flat collection of pulses.
  /// * [isComposite] to determine if a pulse contains multiple signals.
  Pulse operator +(covariant Pulse other);

  /// Returns a read‑only projection of this pulse, ensuring structural and
  /// payload-level finality for the current propagation hop.
  ///
  /// Use this method to stabilize a signal before it crosses architectural
  /// boundaries, such as passing data to UI components, external logging
  /// systems, or downstream [Receptor] chains that should not modify the
  /// current state.
  ///
  /// ### When to use
  /// *   **Receptor Protection**: A [Receptor] can call `.unmodifiable` before
  ///     returning a pulse to ensure that downstream consumers cannot mutate
  ///     the payload or the context of this specific instance.
  /// *   **Cell Payload Safety**: If the [payload] is a [Cell], this prevents
  ///     downstream logic from calling setters on that cell while still
  ///     allowing them to observe its values.
  /// *   **Archiving**: Ensuring a pulse stored in a history buffer or audit
  ///     log cannot be retroactively altered.
  ///
  /// ### How it works
  /// 1.  **Privilege Attenuation**: If the [payload] is a [Cell], the returned
  ///     pulse automatically projects it as an attenuated deputy (via [Cell.unmodifiable]).
  ///     This strips mutation capabilities ([Cell.modifiable]) while preserving
  ///     reactivity, ensuring downstream consumers can observe but not alter state.
  /// 2.  **Recursive Provenance Locking**: To maintain a tamper-proof **Chain of
  ///     Evidence**, the entire causal lineage—including the `parent`, `root`,
  ///     and `source` properties—is recursively projected as unmodifiable views.
  /// 3.  **Structural Finality**: The pulse envelope (metadata, context, and trace)
  ///     is effectively sealed. This creates an **Integrity Gate** that prevents
  ///     any modification to the current hop's record during the remainder of
  ///     the propagation cycle.
  ///
  /// ### Example
  /// ```dart
  /// // But you can still evolve the lineage
  /// final next = protected.withStep('forwarded');
  /// print(next.parent == protected); // true
  /// ```
  Pulse<P> get unmodifiable;

  /// Compares this pulse with another to determine relative execution precedence.
  ///
  /// ### When to use
  /// - **Execution Precedence**: You rarely call this directly — the framework uses it for ordering
  ///   pulses in the dispatcher.
  /// - Custom sorting of pulses.
  /// - Testing or debugging order.
  /// - Implementing custom dispatchers.
  ///
  /// ### How it works
  /// 1. **Primary**: Chronological order (earlier timestamps first).
  /// 2. **Secondary**: Priority (higher priority first).
  /// 3. **Tertiary**: Trace depth (shallower traces first).
  ///
  /// This multi-tier sorting strategy ensures deterministic ordering in
  /// the reactive stream, maintaining **Causal Integrity** and system
  /// state reproducibility.
  ///
  /// ### Parameters:
  /// - [other]: The pulse to compare with.
  ///
  /// ### Returns:
  /// A negative value if this pulse has higher precedence, a positive value
  /// if lower precedence, or zero if they are equal.
  @override
  int compareTo(Pulse other);

  /// Traverses the causal chain from the root ancestor to this pulse to
  /// reconstruct a historical timeline of values.
  ///
  /// ### When to use
  /// - **Value Evolution Auditing**: Use this to see how a specific property
  ///   (like `payload` or `step`) has changed across every hop in the graph.
  /// - **Forensic Debugging**: Identify exactly which transformation step
  ///   introduced an unexpected value.
  /// - **Explainable AI (XAI)**: Reconstruct the decision path of a signal
  ///   through a complex reactive network.
  /// - **State Drift Analysis**: Compare the primordial root value with the
  ///   current state to calculate total delta.
  ///
  /// ### How it works
  /// 1. The method starts at the current pulse and walks up the `parent` chain
  ///    until it reaches the [root].
  /// 2. For each pulse in the chain, it extracts the requested value using the
  ///    provided [arg].
  /// 3. The resulting collection is **reversed** to provide a chronological
  ///    sequence (FIFO: First-In, First-Out).
  ///
  /// ### Example
  /// ```dart
  /// // Trace how the payload evolved from the original input
  /// final history = pulse.lineage<double>(Pulse.payload);
  /// print(history); // [100.0, 115.0, 103.5]
  ///
  /// // Trace the causal "steps" taken through the graph
  /// final steps = pulse.lineage<String>(Pulse.step);
  /// print(steps); // ['origin', 'tax_calc', 'discount_apply']
  /// ```
  ///
  /// ### Parameters:
  /// - [arg]: A [LineageArgument] defining which property to extract from
  ///   the causal chain.
  ///
  /// ### Returns:
  /// A fixed-length [List<T>] containing the historical values in
  /// chronological order (Primordial -> Present).
  List<T> lineage<T>(LineageArgument arg);
}

/// Encodes this pulse to its canonical JSON wire form via [encodePulse].
///
/// The result is symmetric with [Pulse.fromJson] for the fields that are
/// **not** overridden. For a pulse whose round-trip is defined (see the
/// codec's round-trip table), `Pulse.fromJson(p.toJson())` reproduces the
/// pulse to the codec's documented precision — millisecond timestamps,
/// JSON-encodable payloads, `String` types, and the full parent chain.
///
/// Throws [PulseNotSerializable] if the pulse (or any pulse in its
/// `parent` chain) carries a `policy`, an `onComplete` / `onError` /
/// `onProgress` callback, or a `scrutinize` function.
///
/// {@category Replay}
extension PulseJson<P> on Pulse<P> {
  Map<String, dynamic> toJson() => encodePulse(this as PulseBase);
}

/// A read‑only projection of a pulse that enforces structural finality.
///
/// An [UnmodifiablePulse] is a locked message container. It ensures that once
/// a signal has reached a specific architectural boundary, it can no longer be
/// evolved or tampered with by downstream observers.
///
/// ### When to use
/// - **Tamper-Proof Signal**: You get this from [Pulse.unmodifiable]. You never need to construct it
///   directly.
/// - Audit trails where the pulse must remain unchanged.
/// - Sending pulses to logging or monitoring systems.
/// - Handing pulses to external APIs that shouldn't mutate them.
/// - UI components that should only display data.
/// - Any scenario requiring tamper‑proof signals.
///
/// ### How it works
/// The unmodifiable pulse wraps the original and disables all mutation methods
/// ([evolve], [withStep]). Any attempt to change it throws an error.
///
/// ### Example
/// ```dart
/// final immutable = UnmodifiablePulse(pulse);
/// // immutable.evolve(...); // Throws
/// sendToExternalSystem(immutable); // Safe
/// ```
///
/// See also: [Pulse.unmodifiable] (the simpler way to get one of these).
abstract interface class UnmodifiablePulse<P>
    implements Pulse<P>, Unmodifiable {
  /// Creates a read‑only projection of an existing pulse.
  ///
  /// ### When to use
  /// - **Explicit Stabilization**: You typically use [Pulse.unmodifiable] instead of calling this directly.
  ///   This factory exists for cases where you need to explicitly create an
  ///   unmodifiable wrapper — for example, in custom serialisation logic.
  /// - Custom serialisation logic.
  /// - Framework extensions.
  /// - Advanced use cases where you need explicit control.
  /// - When you want to create an unmodifiable wrapper manually.
  ///
  /// ### How it works
  /// It wraps the source pulse in a protective layer that blocks all
  /// evolutionary methods.
  ///
  /// ### Parameters:
  /// - [source]: The original [Pulse] to be stabilised and protected.
  ///
  /// ### Returns:
  /// An [UnmodifiablePulse] that preserves the original data but blocks any
  /// further changes to its envelope or lineage.
  factory UnmodifiablePulse(Pulse<P> source) = _UnmodifiablePulse<P>;
}
