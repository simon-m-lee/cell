// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

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
/// ### Non‑obvious: evolution is not mutation
/// [EvolvedPulse] is immutable. When you call [evolve], you get a *new* pulse
/// that points to the old one. The old pulse is still there — unchanged,
/// available for reference — which is why you can trace the entire lineage
/// without copying data.
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
  /// ### Non‑obvious: the chain is immutable
  /// Once set, [parent] never changes. For the root pulse (the original),
  /// [parent] is `null`. The chain is resolved by walking up — never duplicated.
  ///
  /// ### Example
  /// ```dart
  /// final evolved = root.evolve(PulseContext(reason: 'test'), step: 'step1');
  /// print(evolved.parent); // root
  /// ```
  Pulse<P> get parent;

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
  /// ### Non‑obvious
  /// - **Causal Integrity**: While this returns only the *last* value, the
  ///   entire history remains available for forensics via the [iterator]
  ///   or the [trace].
  /// - **CBAC Enforcement**: Access to the terminal payload is subject to
  ///   **Capability-Based Access Control**. If a caller lacks the required
  ///   [Mandate] for the final transformation step, this may return `null`
  ///   even if data exists.
  /// - **Efficiency**: Because evolution is a structural wrap, retrieving
  ///   the last payload avoids unnecessary data duplication across the fabric.
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
/// ### Non‑obvious: flat, not chained
/// A [CollectivePulse] does **not** create parent‑child relationships between
/// its members. Each pulse's `parent` remains unchanged. The collective's
/// `root` is itself, but each sub‑pulse's `root` remains its own root.
///
/// ### Non‑obvious: callbacks are per‑collective, not per‑pulse
/// The `onComplete`, `onError`, and `onProgress` callbacks are taken from the
/// itself as a `root` pulse. They are **not** applied to each individual
/// pulse — they fire once for the collective as a whole.
///
/// ### Non‑obvious: iterating over a collective
/// The collective itself is iterable — iterating over it yields the collective
/// as a single item, not its constituent pulses. To access individual pulses,
/// use the [payload] getter:
/// ```dart
/// for (final p in collective.payload) {
///   print(p.payload);
/// }
/// ```
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
abstract interface class CollectivePulse<P> implements Pulse<Iterable<Pulse<P>>> {

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
  /// ### Non‑obvious: the collective's payload is the iterable
  /// The [payload] of the collective is the iterable of pulses itself — not
  /// a combined value. To access the individual pulses, iterate over the payload.
  ///
  /// ### Parameters:
  /// - [pulses]: The individual pulses to bundle.
  /// - [type]: Optional semantic tag for the bundle.
  /// - [source]: Optional originating cell.
  /// - [priority]: Optional urgency (overrides individual priorities).
  /// - [step]: Optional trace step for the bundle.
  factory CollectivePulse.from(Iterable<Pulse<P>> pulses,
      {String? type, Cell? source, int? priority, String? step})
  = _CollectivePulse<P>;

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
  /// ### Non‑obvious: callbacks fire once, not per‑pulse
  /// The `onComplete`, `onError`, and `onProgress` callbacks are attached to
  /// the collective itself. They fire once when the collective completes
  /// (or fails), not once per sub‑pulse.
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
  factory CollectivePulse.governed(Iterable<Pulse<P>> pulses, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,

    String? type,

    Cell? source,
    String? step,

    int? priority,

    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,

    FutureOr<Pulse?> Function(Receptor receptor, {bool? serializedCompletion})? scrutinize,
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
  /// ### Non‑obvious: this is the entire iterable
  /// This is **all** the pulses, not just the first one. For a collective
  /// created with `+`, this contains all pulses from both operands.
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
/// - **[type]**: a semantic tag for routing and filtering.
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
/// ### Non‑obvious: a pulse is governed if it has a Context or Policy
/// A pulse is considered [isGoverned] if it was created with a non‑default
/// [PulseContext] and/or a [PulseEphemeralPolicy]. This triggers additional
/// validation, lifecycle management, and auditing behaviours during propagation.
///
/// ### Non‑obvious: pulses are flyweights
/// The framework uses a flyweight pattern internally. An evolved pulse doesn't
/// copy its parent's payload — it inherits it by walking up the parent chain.
/// This means you can have deep causal chains with minimal memory overhead.
///
/// ### Non‑obvious: pulses carry their own governance
/// A pulse can challenge a receptor before revealing its payload. This is the
/// **reciprocal handshake** — the pulse and receptor validate each other
/// before any data is exchanged. Use [shell] to send a pulse to untrusted code.
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
abstract interface class Pulse<P> implements Iterable<Pulse>, Comparable<Pulse<P>> {

  /// The default priority for pulses when none is specified.
  ///
  /// ### When to use
  /// * You rarely need this constant directly — it's the framework's fallback
  ///   when a pulse is created without an explicit priority.
  /// * Reading the default priority value.
  /// * Understanding the baseline urgency of ungoverned pulses.
  /// * Comparing against custom priorities.
  ///
  /// ### Non‑obvious: priority is 0‑100, higher = more urgent
  /// The recommended tiers are:
  /// - 0‑20: Background (telemetry, maintenance)
  /// - 21‑50: Routine (standard operations)
  /// - 51‑80: High (user interactions)
  /// - 81‑95: Critical (system safety)
  /// - 96‑100: Emergency (system recovery)
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
  /// ### Non‑obvious: ungoverned pulses are still trackable
  /// Even without explicit governance, all pulses carry a timestamp and trace.
  /// They're still part of the causal graph — they just don't have TTL or
  /// hop limits.
  ///
  /// ### Parameters:
  /// - [payload]: The data carried by the pulse.
  /// - [type]: Optional semantic tag for routing.
  /// - [source]: Optional originating cell.
  /// - [priority]: Urgency (defaults to [defaultPriority]).
  /// - [step]: Optional trace step (like an initial breadcrumb).
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse('Hello', type: 'message', priority: 60);
  /// ```
  factory Pulse(P? payload, {String? type, Cell? source, int? priority, String? step})
  => _Pulse<P>(payload: payload, type: type, source: source, priority: priority, step: step);

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
  /// ### Non‑obvious: callbacks travel with the pulse
  /// Callbacks attached to a governed pulse are **inherited** through the
  /// parent chain. If you evolve a pulse, the original callbacks are still
  /// present — they're not lost or duplicated.
  ///
  /// ### Non‑obvious: governance is determined by Context or Policy
  /// A pulse becomes governed when either [context] (non‑default provenance)
  /// or [policy] (lifecycle rules) is provided. Governed pulses undergo
  /// additional validation, TTL checks, and auditing during propagation.
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
  /// ### Non‑obvious: this is a flat bundle, not a chain
  /// Unlike [evolve], which creates a causal chain, [batch] creates a flat
  /// collection. There's no parent‑child relationship between the pulses —
  /// they're just grouped together for atomic propagation.
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
  static Pulse batch<P>(Iterable<Pulse<P>> pulses, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,

    String? type,

    Cell? source,
    String? step,

    int? priority,

    void Function(Pulse pulse)? onComplete,
    void Function(Pulse pulse, Object error, {StackTrace? stackTrace})? onError,
    void Function(Pulse pulse, Cell cell, {String? message})? onProgress,
  }) => _CollectivePulse<P>(pulses);

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
  /// ### Non‑obvious: payload is inherited, not copied
  /// For an evolved pulse, `payload` returns the root's payload. This is why
  /// causal chains are memory‑efficient — no data is duplicated.
  ///
  /// ### Non‑obvious: collective pulses have a collective payload
  /// For a [CollectivePulse], `payload` returns an `Iterable` of all sub‑pulses.
  /// To access individual payloads, iterate over the collective's payload:
  /// ```dart
  /// for (final p in collective.payload) {
  ///   print(p.payload);
  /// }
  /// ```
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
  /// ### Non‑obvious: the handshake is reciprocal
  /// This is **not** a one‑way permission check. Both the pulse and the
  /// receptor validate each other. A pulse can refuse to reveal its payload
  /// to a receptor it doesn't trust.
  ///
  /// ### Non‑obvious: this is how [PulseShell] works
  /// A [PulseShell] is a defensive proxy that wraps a pulse and forces any
  /// receiver to go through this scrutiny process before accessing the payload.
  ///
  /// ### Parameters:
  /// - [receptor]: The entity requesting access to the pulse's internal state.
  /// - [positionalArguments]: Contextual data for the handshake.
  /// - [namedArguments]: Additional named parameters (e.g., `serializedCompletion`).
  ///
  /// ### Returns:
  /// The internal kernel if authorised; `null` if neutralised.
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]);

  /// Creates a derived version of this pulse for the next processing stage.
  ///
  /// ### When to use
  /// - **Next Stage Evolution**: Use this when you need to change a pulse's context (authority, reason,
  ///   priority) or add a trace step without losing its causal history —
  ///   for example, after a transformation or validation step.
  /// - Adding a step to the causal trace.
  /// - Updating a pulse's provenance context.
  /// - Preserving causal history across transformations.
  /// - Annotating a signal's journey through the graph.
  /// - When you need to append a transformed pulse to a chain.
  ///
  /// ### How it works
  /// You provide a new [pulse] (to append), a [step] description, and/or a
  /// new [context]. The new pulse links back to this one via [EvolvedPulse.parent],
  /// preserving the history. If the new [context] is provided, the evolved
  /// pulse becomes (or remains) governed.
  ///
  /// ### Non‑obvious: you must provide at least one parameter
  /// At least one of [pulse], [step], or [context] must be non‑null. This
  /// assertion ensures you don't accidentally create a pointless no‑op
  /// evolution. If you just want to add a step, use [withStep] instead.
  ///
  /// ### Non‑obvious: payload is inherited
  /// The new pulse's payload is inherited from the root — you can't change
  /// it here. To change the payload, you'd create a new pulse separately
  /// and pass it as [pulse]. This is by design — it prevents accidental
  /// data corruption while preserving the causal chain.
  ///
  /// ### Parameters:
  /// - [pulse]: An optional pulse to append to the chain. If provided, the
  ///   new pulse will carry this as its sub‑pulse.
  /// - [step]: A descriptive string added to the [trace] log.
  /// - [context]: A new [PulseContext] for updated authority/provenance.
  ///   If provided, the evolved pulse becomes governed.
  ///
  /// ### Returns:
  /// A new [Pulse] with the causal lineage preserved. If only [step] is
  /// provided, returns a simple evolved pulse. If [pulse] or [context] is
  /// provided, returns a full evolved pulse.
  ///
  /// ### Example
  /// ```dart
  /// final root = Pulse<int>(42);
  /// final evolved = root.evolve(step: 'sanitization');
  /// print(evolved.trace); // ['sanitization']
  /// print(evolved.payload); // 42 (inherited from root)
  /// ```
  Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context});

  /// Adds a step to the pulse's causal trace and returns a new pulse.
  ///
  /// ### When to use
  /// * This is a convenience wrapper around [evolve] that keeps the same context
  ///   but appends a step to the trace. It's the simplest way to document a
  ///   signal's journey.
  /// * Marking significant processing stages.
  /// * Building a breadcrumb trail for debugging.
  /// * Documenting a signal's journey for auditing.
  /// * When you only need to add a step, not change context.
  ///
  /// ### How it works
  /// This is a convenience wrapper around [evolve] that keeps the same context
  /// but appends a step to the trace. It's the simplest way to document a
  /// signal's journey.
  ///
  /// ### Example
  /// ```dart
  /// final processed = Pulse(42)
  ///   .withStep('validation')
  ///   .withStep('transformation')
  ///   .withStep('persistence');
  ///
  /// print(processed.trace); // ['validation', 'transformation', 'persistence']
  /// ```
  ///
  /// ### Parameters:
  /// - [step]: The step description to append to the trace.
  ///
  /// ### Returns:
  /// A new [Pulse] with the step added to its trace.
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
  /// ### Non‑obvious: a collective iterates over itself, not its payload
  /// For a [CollectivePulse], iterating over the collective yields the
  /// collective as a single item, not its constituent pulses. To access the
  /// individual pulses, use the [payload] getter:
  /// ```dart
  /// for (final p in collective) { } // one item (the collective)
  /// for (final p in collective.payload) { } // all sub‑pulses
  /// ```
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
  /// ### Non‑obvious: the shell is read‑only and immutable
  /// You can't evolve a shell or change its metadata. It's a terminal,
  /// read‑only view designed for safe distribution.
  ///
  /// ### Returns:
  /// A [PulseShell] that gates access until **Reciprocal Authorization** is satisfied.
  PulseShell<P,Receptor> get shell;

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
  /// ### Non‑obvious: this is the root's timestamp
  /// This is the creation time of the **original** pulse, not the current
  /// derived one. If you evolve a pulse, the timestamp stays the same.
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
  /// It's a semantic tag that travels with the pulse.
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
  String? get type;

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
  /// ### Non‑obvious: the policy is attached to the root
  /// If you evolve a pulse, the policy travels with it — it's inherited
  /// through the parent chain, not duplicated.
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

  /// The primordial ancestor that initiated this entire message lineage.
  ///
  /// ### When to use
  /// - **Root Traceability**: Use this when you need to jump to the very start of the causal chain —
  ///   for root cause analysis or intent preservation.
  /// - Root cause analysis.
  /// - Intent preservation across transformations.
  /// - Auditing the original source of a signal.
  /// - When you need the original payload without traversing the chain.
  ///
  /// ### How it works
  /// The root is the original pulse that started the chain. It's immutable
  /// and never changes, even as you evolve the pulse.
  ///
  /// ### Non‑obvious: root is the original pulse
  /// For the original pulse, `pulse.root == pulse`. For any derived pulse,
  /// `pulse.root` points back to that original.
  Pulse<P> get root;

  /// Indicates whether this pulse is a multi‑message bundle.
  ///
  /// ### When to use
  /// - **Bundle Detection**: Check this if you need to know whether a pulse contains multiple
  ///   sub‑pulses — for example, when iterating over it.
  /// - Checking if a pulse is a bundle before iterating.
  /// - Conditional logic based on composite status.
  /// - Debugging to understand pulse structure.
  ///
  /// ### How it works
  /// A composite pulse is created with the `+` operator or [Pulse.batch].
  /// It acts as an iterable collection of pulses.
  ///
  /// ### Example
  /// ```dart
  /// final composite = Pulse<int>(1) + Pulse<String>('hello');
  /// if (composite.isComposite) {
  ///   for (final p in composite) {
  ///     print(p.payload); // 1, hello
  ///   }
  /// }
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
  /// ### Non‑obvious: governance is determined by Context or Policy
  /// A pulse is considered governed when either:
  /// - A non‑default [PulseContext] is provided (e.g., with actor, reason,
  ///   sensitivity, or compliance metadata).
  /// - A [PulseEphemeralPolicy] is provided (TTL, hop limit, or callbacks).
  ///
  /// Governed pulses undergo additional validation, TTL checks, and auditing
  /// during propagation. Ungoverned pulses are lightweight and bypass these
  /// checks.
  ///
  /// ### Returns:
  /// `true` if the pulse has explicit governance (Context or Policy),
  /// `false` otherwise.
  bool get isGoverned;

  /// Merges two signals into a [CollectivePulse] for atomic propagation.
  ///
  /// ### Where to start
  /// Use this when one event logically implies another, or when you need to
  /// trigger multiple downstream effects with a single emission.
  ///
  /// ### When to use
  /// - **Combining Pulses**: One event logically implies another (e.g., update + notify).
  /// - Triggering multiple downstream effects with a single emission.
  /// - Batching related updates.
  /// - Atomic operations that span multiple cells.
  /// - Minimising propagation cycles.
  ///
  /// ### How it works
  /// - The current pulse and [other] are combined into a [CollectivePulse].
  /// - If either is already a collective, the framework flattens them into a
  ///   single‑level sequence.
  /// - The resulting bundle's [payload] contains all individual pulses.
  ///
  /// ### Non‑obvious: order matters
  /// Pulses are processed in the order they were added (left to right).
  ///
  /// ### Non‑obvious: each pulse retains its own identity
  /// While the bundle has its own top‑level metadata, each sub‑pulse retains
  /// its original context, trace, and callbacks.
  ///
  /// ### Example
  /// ```dart
  /// final update = Pulse('New Value');
  /// final notify = Pulse('User Notified', type: 'telemetry');
  /// final bundle = update + notify;
  ///
  /// for (final p in bundle.payload) {
  ///   print(p.payload);
  /// }
  /// ```
  ///
  /// See also:
  /// - [Pulse.batch] – the factory version for iterables.
  /// - [isComposite] – to check if a pulse is a bundle.
  Pulse operator +(covariant Pulse other);

  /// Returns a read‑only projection of this pulse.
  ///
  /// ### When to use
  /// - **Tamper Protection**: Use this before handing a pulse to untrusted code — logging, external
  ///   APIs, or UI components. It prevents tampering.
  /// - Sending pulses to logging or monitoring systems.
  /// - Handing pulses to external APIs.
  /// - UI components that should only display data.
  /// - Any scenario where you don't want the receiver to mutate the pulse.
  /// - Audit trails where immutability is required.
  ///
  /// ### How it works
  /// The unmodifiable view disables [evolve] and [withStep]. Any attempt to
  /// change the pulse will throw. The payload remains readable.
  ///
  /// ### Non‑obvious: this is recursive
  /// The [EvolvedPulse.parent], [root], and [source] are also projected as unmodifiable.
  /// The underlying data is not copied — it's a protective wrapper.
  ///
  /// ### Example
  /// ```dart
  /// final immutable = pulse.unmodifiable;
  /// // immutable.evolve(...); // Throws
  /// logToExternalSystem(immutable); // Safe
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

  /// Traverses the dependency chain to reconstruct the complete execution trace.
  ///
  /// ### When to use
  /// - **Value Evolution Auditing**: Use this for advanced debugging or auditing — to see how a value or
  ///   property evolved across the causal chain.
  /// - Debugging value evolution across transformations.
  /// - Auditing the reasons behind each step.
  /// - Explainable AI (XAI) to show decision progression.
  /// - Understanding how a value changed over time.
  ///
  /// ### How it works
  /// You provide a field getter (e.g., `#payload`, `Provenance.reason`) and
  /// the method walks up the parent chain, collecting values along the way.
  ///
  /// ### Examples
  /// ```dart
  /// // Trace how a value changed over time
  /// final history = pulse.lineage<int>(#payload);
  /// // Returns: [100, 105, 98]
  ///
  /// // Trace the reasons behind each step
  /// final reasons = pulse.lineage<String>(Provenance.reason, fromPolicy: true);
  /// // Returns: ['User Input', 'Sanitization', 'Validation']
  /// ```
  ///
  /// ### Parameters:
  /// - [fieldGetter]: The key or property to extract from each pulse.
  ///   - If `fromPolicy` is `false`: Refers to [Pulse] members like `payload`.
  ///   - If `fromPolicy` is `true`: Refers to [Provenance] metadata keys.
  /// - [fromPolicy]: If `true`, traverse within the context of governance policy.
  ///
  /// ### Returns:
  /// A list of historical values in chronological order, or `null` if none
  /// match the requested type.
  List<T>? lineage<T>(dynamic fieldGetter, {bool fromPolicy = false});

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
/// ### Non‑obvious: Recursive Stabilization
/// The entire **Causal Provenance** chain—including the [EvolvedPulse.parent],
/// [Pulse.root], and [Pulse.source]—is projected as unmodifiable.
///
/// This ensures that a stabilized signal cannot be retroactively
/// evolved or tampered with through its lineage. The underlying data
/// ([payload]) remains readable, but the structural envelope is
/// permanently sealed.
///
/// ### Example
/// ```dart
/// final immutable = UnmodifiablePulse(pulse);
/// // immutable.evolve(...); // Throws
/// sendToExternalSystem(immutable); // Safe
/// ```
///
/// See also: [Pulse.unmodifiable] (the simpler way to get one of these).
abstract interface class UnmodifiablePulse<P> implements Pulse<P>, Unmodifiable {

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