// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Defines the **Causal Accountability, Audit Trail, and Operational Intent**
/// of a [Pulse].
///
/// [Provenance] documents the transient lifecycle of a signal. While [Ontology]
/// describes the "Static Scene" (what a node is), [Provenance] provides the dynamic
/// **Chain of Custody** (who, why, and how) for every stimulus traversing the
/// reactive tissue.
///
/// This metadata is utilised by the **Policy Enforcement Point (PEP)** to
/// perform **Capability-Based Access Control (CBAC)** and ensure
/// **Execution Traceability**.
///
/// ### When to use
/// * You rarely interact with [Provenance] directly. Instead, use the
///   [PulseContext] factories like `PulseContext.userAction`,
///   `PulseContext.aiInference`, or `PulseContext.regulated`. These factories
///   populate the relevant provenance dimensions for you.
/// * If you need a custom pulse context, you can create one with the
///   [PulseContext] constructor, passing the appropriate dimensions manually.
///   But in most cases, the pre‑defined factories are sufficient.
///
/// ### How it works
/// - Each [Provenance] dimension is a typed key that holds a value of type [V].
/// - Some dimensions are **Static Pillars** (`evolvable: false`) – they are
///   immutable and cannot be changed once a pulse is created. These anchor
///   the pulse's identity (e.g., `actor`, `traceId`).
/// - Others are **Fluid Boundaries** (`evolvable: true`) – they can be
///   refined as the pulse moves through the graph (e.g., `reason`,
///   `confidence`, `priority`).
/// - The framework uses these dimensions during validation (via [TestCell])
///   and auditing (via the causal trace).
///
/// ### Non‑obvious
/// - The [Provenance.evolvable] flag is enforced by the engine – you cannot change
///   a static pillar via `evolve()`.
/// - The `compose` and `evolve` static methods are used internally by
///   [PulseContext] to build contexts. You rarely call them directly.
/// - The [integrity] dimension is a cryptographic checksum of the payload,
///   ensuring tamper‑proofing – it's automatically handled by the framework.
///
/// ### Example: Creating a Pulse with Provenance
/// ```dart
/// final pulse = Pulse.governed<int>(
///   payload: 42,
///   context: PulseContext.userAction(
///     actor: 'admin_01',
///     reason: 'Manual override',
///     priority: 80,
///   ),
/// );
///
/// final fullProvenance = PulseContext.fromEntries([
///   // --- Static Pillars (Non-Evolvable Identity) ---
///   Provenance.actor.entry('Autonomous_Optimizer_7'), // Identity Source
///   Provenance.traceId.entry('trace_882-xf'),        // Causal Anchor
///   Provenance.parentTraceId.entry('trace_881-xf'),  // Lineage Link
///
///   // --- Fluid Boundaries (Evolvable Intent) ---
///   Provenance.reason.entry('Resource_Saturation_Detected'), // Rationale
///   Provenance.purpose.entry('TOPOLOGY_REFRESH'),           // Mission Category
///   Provenance.strategy.entry(ReasoningStrategy.probabilistic), // Logic Pedigree
///   Provenance.confidence.entry(0.85),                        // Trust Scalar
///   Provenance.priority.entry(40),                           // Urgency Rank
///   Provenance.compliance.entry('GDPR_EU_DATA_LOCALITY'),    // Safety Policy
/// ]);
/// ```
///
/// See also:
/// * [PulseContext] – the runtime container for these dimensions.
/// * [Ontology] – the static structural identity of a node.
/// * [Mandate] – the authority profile of a deputy.
enum Provenance<V> with GovernanceMixin<Provenance<V>,V> implements Governance<V> {

  /// The unique identifier for the **Principal, Service, or AI Agent**
  /// responsible for initiating or transforming this [Pulse].
  ///
  /// The `actor` (of type [String]) establishes the **Identity Layer** of the
  /// signal. It is the primary key used by the system to look up the [Mandate]
  /// or permissions associated with the source of the stimulus.
  ///
  /// ### When to use
  /// This is set automatically by the [PulseContext] factories. You rarely
  /// need to set it manually.
  ///
  /// ### How it works
  /// During the mutual authorization handshake, the `actor` is scrutinised
  /// to verify that the source has the required clearance and authority.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – once set, it cannot be changed.
  /// - The framework uses this for identity‑based access control.
  ///
  /// ### Examples
  /// * `'user_8823_admin'` – direct manual intervention.
  /// * `'service_cache_manager'` – background maintenance.
  /// * `'agent_thermal_optimizer_4'` – AI instance.
  actor<String>(false),

  /// A semantic justification explaining **why** the specific [Pulse] was
  /// created or transformed.
  ///
  /// While [purpose] describes the high-level mission, `reason` provides the
  /// **Immediate Causal Logic** behind a mutation. It is a critical component
  /// of the system's **Audit Dimension**.
  ///
  /// ### When to use
  /// This is set automatically by factories, but you can override it when
  /// evolving a pulse.
  ///
  /// ### How it works
  /// The `reason` is used for Explainable AI (XAI) and is inspected by
  /// integrity gates to ensure the mutation is justified.
  ///
  /// ### Non‑obvious
  /// - This is an **evolvable** dimension – you can refine it as the pulse
  ///   traverses the graph.
  /// - It should be human‑readable for audit purposes.
  ///
  /// ### Examples
  /// * `'Clamping signal to [0,1] range to prevent somatic overflow.'`
  /// * `'Refactoring topology to meet current Resource constraints.'
  reason<String>(true),

  /// The strategic operational mission or **Mission Category** that governs
  /// the life‑cycle and routing of a [Pulse].
  ///
  /// While [reason] explains the immediate "why", `purpose` defines the
  /// **Strategic Intent**. It acts as a high‑level classifier used by the
  /// framework for traffic shaping, priority queueing, and somatic shedding.
  ///
  /// ### When to use
  /// This is set by the factories (e.g., `PulseContext.homeostasis` sets it
  /// to `'SYSTEM_MAINTENANCE'`). You rarely set it manually.
  ///
  /// ### How it works
  /// Receptors can use `purpose` to filter or prioritise pulses – e.g.,
  /// dropping analytics pulses when under load.
  ///
  /// ### Non‑obvious
  /// - This is **evolvable** – a pulse can be refined to a more specific
  ///   purpose as it moves through the graph.
  /// - It is compared against the cell's [Ontology.domains] during validation.
  ///
  /// ### Examples
  /// * `'SYSTEM_MAINTENANCE'` – background grooming.
  /// * `'USER_TRANSACTION'` – user‑driven updates.
  /// * `'FORENSIC_AUDIT'` – observational pulses.
  purpose<String>(true),

  /// The specific **Reasoning Strategy** or algorithmic pedigree used to
  /// generate or transform this [Pulse].
  ///
  /// The `strategy` defines the **Methodology of Intent**. It allows the
  /// framework to evaluate the reliability and source logic of a signal.
  ///
  /// ### When to use
  /// This is set by factories (e.g., `aiInference` sets it to `probabilistic`).
  ///
  /// ### How it works
  /// Integrity gates can reject pulses that use an unacceptable strategy,
  /// e.g., a cell might only accept `deterministic` signals.
  ///
  /// ### Non‑obvious
  /// - This is **evolvable** – a `probabilistic` signal can be upgraded to
  ///   `deterministic` after validation.
  /// - The strategy influences trust and auditing.
  ///
  /// ### Examples
  /// * `ReasoningStrategy.deterministic` – hard‑coded business rules.
  /// * `ReasoningStrategy.probabilistic` – AI/ML generated.
  /// * `ReasoningStrategy.manual` – human intervention.
  strategy<ReasoningStrategy>(true),

  /// A numerical value (0.0 to 1.0) representing the **Reliability Estimate**
  /// of the pulse's payload.
  ///
  /// `confidence` represents the "Certainty Weight" of the stimulus. It is
  /// the primary metric for **Probabilistic Homeostasis**.
  ///
  /// ### When to use
  /// This is set by AI‑related factories (e.g., `aiInference`).
  ///
  /// ### How it works
  /// TestCells can require a minimum confidence; low‑confidence signals
  /// may be routed for supervised approval.
  ///
  /// ### Non‑obvious
  /// - This is **evolvable** – confidence can be adjusted as more evidence
  ///   is gathered.
  /// - The default is 1.0 for deterministic and manual signals.
  ///
  /// ### Examples
  /// * `0.65` – uncertain AI suggestion.
  /// * `0.98` – high‑confidence sensor fusion.
  confidence<double>(true),

  /// The **Execution Urgency** (0-100) assigned to the signal.
  ///
  /// `priority` defines the scheduling importance of the [Pulse]. It
  /// determines the signal's position in the dispatch queue.
  ///
  /// ### When to use
  /// Set this when you need to control the order of processing. Most
  /// factories set it appropriately (e.g., `userAction` sets 60).
  ///
  /// ### How it works
  /// The dispatcher uses this to prioritise pulses; higher numbers leapfrog
  /// lower ones. The framework uses standard tiers: background (0-20),
  /// routine (21-50), high (51-80), critical (81-95), emergency (96-100).
  ///
  /// ### Non‑obvious
  /// - This is **evolvable** – priority can be promoted or demoted.
  /// - The default is 21 (routine) if not set.
  ///
  /// ### Examples
  /// * `10` – background telemetry.
  /// * `90` – critical system recovery.
  ///
  /// ### Priority Tiers:
  /// - **0-20**: Background (telemetry, maintenance)
  /// - **21-50**: Routine (standard operations)
  /// - **51-80**: High (user interactions)
  /// - **81-95**: Critical (system safety)
  /// - **96-100**: Emergency (system recovery)
  priority<int>(true),

  /// The **Regulatory Framework** or legal protocol that governs the
  /// handling of this [Pulse].
  ///
  /// `compliance` provides the **Legal Context** for the stimulus. It
  /// dictates how the payload must be treated, stored, and transmitted.
  ///
  /// ### When to use
  /// Use this when the pulse must adhere to specific regulations (GDPR,
  /// HIPAA, etc.). The `regulated` factory sets it automatically.
  ///
  /// ### How it works
  /// Integrity gates can block pulses that lack required compliance markers.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – cannot be changed once set.
  /// - The framework enforces compliance constraints automatically.
  ///
  /// ### Examples
  /// * `'GDPR'` – triggers redaction of PII.
  /// * `'PCI-DSS'` – forces encryption and full audit.
  compliance<String>(false),

  /// The **Information Classification** tier of the payload.
  ///
  /// `sensitivity` establishes the **Privacy Perimeter** for the signal.
  /// It informs the framework how to handle data at rest, in transit, and
  /// during observability.
  ///
  /// ### When to use
  /// This is set by factories (e.g., `userAction` defaults to `public`;
  /// `regulated` sets `confidential`).
  ///
  /// ### How it works
  /// The framework uses sensitivity to enforce redaction, encryption, and
  /// access control.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – cannot be changed.
  /// - Higher sensitivity requires higher clearance to process.
  ///
  /// ### Examples
  /// * `Sensitivity.public` – safe for logging.
  /// * `Sensitivity.secret` – restricted to secure enclaves.
  sensitivity<Sensitivity>(false),

  /// The specific **Observability Density** applied to this pulse.
  ///
  /// `auditLevel` defines the **Forensic Fidelity** of the signal. It
  /// determines how much causal metadata and payload information is captured.
  ///
  /// ### When to use
  /// This is set by factories – e.g., `regulated` sets `full`.
  ///
  /// ### How it works
  /// The framework uses this to decide what to log and trace.
  ///
  /// ### Non‑obvious
  /// - This is **evolvable** – a pulse can be promoted to `full` on demand.
  /// - Higher audit levels may impact performance.
  ///
  /// ### Examples
  /// * `AuditLevel.none` – high‑frequency telemetry, no logging.
  /// * `AuditLevel.full` – forensic‑grade trace.
  auditLevel<AuditLevel>(true),

  /// The globally unique **Causal Anchor** for tracing a signal across
  /// distributed execution paths.
  ///
  /// `traceId` establishes the **Deterministic Lineage** of a pulse. It
  /// ensures that every state change can be correlated back to its origin.
  ///
  /// ### When to use
  /// This is automatically generated by the framework. You never set it
  /// manually.
  ///
  /// ### How it works
  /// The traceId is used for deduplication and to link parent/child pulses.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – immutable.
  /// - It is generated as a UUID v4.
  traceId<String>(false),

  /// The [traceId] of the [Pulse] that logically preceded or triggered this one.
  ///
  /// `parentTraceId` establishes the **Causal Link** between pulses,
  /// enabling multi‑step reasoning chains.
  ///
  /// ### When to use
  /// This is automatically set when you evolve a pulse.
  ///
  /// ### How it works
  /// The framework uses this to link a child pulse to its parent,
  /// preserving the full causal chain.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – immutable.
  /// - If a parent pulse is invalidated, children may also be invalidated.
  parentTraceId<String>(false),

  /// The cryptographic or checksum‑based **Verification Signature**
  /// ensuring the pulse's payload has not been tampered with.
  ///
  /// `integrity` provides the **Immutable Shield** for the pulse.
  ///
  /// ### When to use
  /// This is automatically computed by the framework. You never set it.
  ///
  /// ### How it works
  /// The framework hashes the payload and stores the hash; on receipt,
  /// the hash is re‑computed and compared.
  ///
  /// ### Non‑obvious
  /// - This is a **static pillar** – immutable.
  /// - If the payload changes, the integrity signature must be re‑generated.
  ///
  /// ### Examples
  /// * `sha256:e3b0c442...` – standard hash.
  /// * `rsa-sig:a92f81...` – signed with a private key.
  integrity<String>(false);

  /// Indicates whether this **Provenance Dimension** is a structural
  /// invariant or a dynamic operational attribute.
  ///
  /// In the framework's **Blueprint Synthesis** model, the [evolvable] flag
  /// determines the "rigidity" of a signal's metadata during a
  /// [PulseContext.evolve] operation. It separates the pulse's immutable
  /// identity from its mutable mission.
  ///
  /// ### When to use
  /// This property is used internally by the [PulseContext] engine during
  /// **Ontological Specialization**. It identifies dimensions that constitute
  /// the pulse's core identity vs. those that represent current operational intent.
  ///
  /// ### How it works
  /// - **Static Pillars ([evolvable] is `false`)**: These are structural
  ///   invariants (e.g., [Provenance.traceId], [Provenance.actor]). They
  ///   must be inherited exactly from the source. The [PulseContext.evolve]
  ///   logic explicitly ignores overrides for these keys to maintain trace integrity.
  /// - **Fluid Boundaries ([evolvable] is `true`)**: These are operational
  ///   attributes (e.g., [Provenance.priority], [Provenance.reason]). They
  ///   can be redefined or specialized to reflect the specific task a cell
  ///   is performing as a pulse propagates.
  ///
  /// ### Non‑obvious
  /// - **Security Invariant**: Prevents "metadata tampering" downstream. A
  ///   pulse's compliance tier or causal actor cannot be downgraded or spoofed
  ///   via evolution once the pulse is in flight.
  /// - **Flyweight Optimization**: Evolution logic uses this flag to pre-filter
  ///   update maps, minimizing the overhead of record synthesis during
  ///   high-frequency reactive waves.
  /// - **Integrity Enforcement**: The framework ensures that capability-based
  ///   access checks are anchored in non-evolvable dimensions, preventing
  ///   accidental authority elevation.
  ///
  /// ### Example
  /// ```dart
  /// // Overriding a Static Pillar is ignored:
  /// // (Provenance.actor.evolvable is false)
  /// final evolved = context.evolve((dim) =>
  ///   dim == Provenance.actor ? 'malicious_actor' : null
  /// );
  /// // Result: evolved.actor is still the original verified identity.
  ///
  /// // Overriding a Fluid Boundary is accepted:
  /// // (Provenance.priority.evolvable is true)
  /// final emergency = context.evolve((dim) =>
  ///   dim == Provenance.priority ? 100 : null
  /// );
  /// // Result: emergency.priority reflects the elevation.
  /// ```
  ///
  /// ### See Also:
  /// * [PulseContext.evolve]: The primary operation governed by this flag.
  /// * [Provenance.evolve]: The utility that synthesizes specialized extensions.
  /// * [GovernanceEntry]: The underlying record pairing keys with policies.
  @override
  final bool evolvable;

  /// Syntheses a **Provenance Dimension** for use within the [PulseContext]
  /// ontological framework.
  ///
  /// This constructor initialises a governance pillar that specifically
  /// regulates the **Causal Trace** and metadata lineage of a signal.
  ///
  /// ### Parameters:
  /// - [evolvable]: A boolean flag indicating whether the resulting
  ///   dimension supports scene‑specific overrides.
  const Provenance(this.evolvable);

  /// Generates a comprehensive **Signal Manifest** by synthesising a value for
  /// every defined dimension in the [Provenance] ontology.
  ///
  /// This method serves as the primary factory for creating the initial
  /// **Static Blueprint** of a signal's metadata. It iterates through all
  /// available provenance keys—both **Static Pillars** and **Fluid Boundaries**—
  /// to build a complete semantic profile for a [Pulse].
  ///
  /// ### When to use
  /// * You don't call this directly. It's an internal utility used by the
  ///   [PulseContext] factories (like `userAction`, `regulated`, `aiInference`)
  ///   to build the initial context. Your day‑to‑day interaction with
  ///   [Provenance] is through [PulseContext] and its factories.
  /// * Only if you're building a custom context factory that needs to generate
  ///   a full manifest from scratch. For most code, the existing [PulseContext]
  ///   factories are sufficient.
  ///
  /// ### How it works
  /// - The method iterates over every [Provenance] enum value.
  /// - For each, it calls your [resolver] function.
  /// - If the resolver returns a [GovernanceEntry], it's included in the result.
  /// - If the resolver returns `null`, that dimension is omitted.
  /// - The result is an iterable of entries that can be used to build a
  ///   [PulseContext] via `PulseContext.fromEntries()`.
  ///
  /// ### Non‑obvious
  /// - This method includes **all** dimensions – both static and evolvable.
  ///   It's used for creating a new pulse from scratch, not for evolving
  ///   an existing one.
  /// - The resolver is called for every dimension, so you must handle each
  ///   one explicitly or let it return `null` to omit it.
  /// - The result is intended to be consumed by [PulseContext.fromEntries],
  ///   which performs type validation and record packing.
  ///
  /// ### Example
  /// ```dart
  /// // Internal use – building a user action context
  /// final entries = Provenance.compose((dimension) {
  ///   switch (dimension) {
  ///     case Provenance.actor: return Provenance.actor.entry('admin_01');
  ///     case Provenance.reason: return Provenance.reason.entry('Manual override');
  ///     case Provenance.priority: return Provenance.priority.entry(80);
  ///     default: return null; // Omit other dimensions
  ///   }
  /// });
  /// final context = PulseContext.fromEntries(entries);
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that produces a [GovernanceEntry] for each
  ///   [Provenance] dimension, or `null` to omit it.
  ///
  /// ### Returns:
  /// An [Iterable<GovernanceEntry>] containing a synthesised entry for
  /// every applicable provenance dimension.
  static Iterable<GovernanceEntry> compose(GovernanceEntry? Function(Provenance dimension) resolver) {
    final entries = values.map((g) => resolver(g)).where((en) => en != null);
    return entries.cast();
  }

  /// Syntheses a **Specialised Signal Extension** by resolving only the
  /// fluid dimensions of the [Provenance] ontology.
  ///
  /// This method implements **Ontological Specialisation** for signal metadata.
  /// It filters the provenance dimensions, allowing only those marked as
  /// [evolvable] to be processed by the provided [resolver]. This ensures that
  /// a pulse's immutable identity (static pillars) cannot be accidentally
  /// changed during evolution.
  ///
  /// ### When to use
  /// * You don't call this directly. It's an internal utility used by
  ///   [PulseContext.evolve] to refine a context without altering its core
  ///   identity. Your day‑to‑day interaction is through `context.evolve()`.
  /// * Only if you're implementing a custom context evolution mechanism.
  ///   For most code, the `PulseContext.evolve` method is the correct entry point.
  ///
  /// ### How it works
  /// - The method iterates only over [Provenance] dimensions where
  ///   `evolvable == true`.
  /// - For each, it calls your [resolver] function.
  /// - If the resolver returns a [GovernanceEntry], it's included in the result.
  /// - If the resolver returns `null`, that dimension is inherited from the
  ///   parent context (not omitted from the entire context – the parent's
  ///   value is preserved).
  /// - Static pillars (like `actor`, `traceId`, `compliance`, `sensitivity`)
  ///   are **excluded** from the evolution, preserving the pulse's identity.
  ///
  /// ### Non‑obvious
  /// - This method only processes **evolvable** dimensions. It deliberately
  ///   ignores static pillars to prevent identity spoofing.
  /// - The result is a **delta** – it only contains dimensions that have
  ///   changed. Dimensions not provided in the resolver are inherited from
  ///   the parent context.
  /// - The result is intended to be consumed by [PulseContext.fromEntries]
  ///   with the parent context passed in, so inheritance works correctly.
  ///
  /// ### Example
  /// ```dart
  /// // Internal use – evolving a context
  /// final delta = Provenance.evolve((evolvable) {
  ///   switch (evolvable) {
  ///     case Provenance.reason:
  ///       return Provenance.reason.entry('Refined for storage');
  ///     case Provenance.priority:
  ///       return Provenance.priority.entry(75);
  ///     default:
  ///       return null; // Inherit from parent
  ///   }
  /// });
  /// final evolved = PulseContext.fromEntries(delta, parent: original);
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that produces a [GovernanceEntry] for each
  ///   [evolvable] dimension, or `null` to inherit from the parent.
  ///
  /// ### Returns:
  /// An [Iterable<GovernanceEntry>] containing the specialised metadata
  /// entries used to form an evolved pulse context.
  static Iterable<GovernanceEntry> evolve(GovernanceEntry? Function(Provenance evolvable) resolver) {
    final entries = values.where((g) => g.evolvable == true)
        .map((g) => resolver(g)).where((en) => en != null);
    return entries.cast();
  }

}

/// Represents the **Causal Identity** and ontological **Provenance** of a [Pulse].
///
/// [PulseContext] serves as the telemetric anchor for a stimulus, tracking its
/// historical lineage, reasoning justification, and priority as it propagates
/// through the **Switching Fabric**.
///
/// ### When to use
/// * You rarely create a [PulseContext] directly. Instead, use one of the
///   specialised factories:
///   - [PulseContext.userAction] – for human‑initiated actions.
///   - [PulseContext.aiInference] – for AI‑generated signals.
///   - [PulseContext.regulated] – for compliance‑bound pulses.
///   - [PulseContext.homeostasis] – for system maintenance.
///   - [PulseContext.telemetry] – for high‑frequency monitoring.
///   - [PulseContext.instruction] – for administrative commands.
///   - And many more – see the factories below.
/// * If none of these fit, you can use the general constructor with named
///   parameters (actor, reason, priority, etc.).
/// * Use [PulseContext] whenever you need to attach provenance metadata to a
///   pulse – e.g., to record who triggered it, why, and with what priority.
///   This is essential for auditing, debugging, and security enforcement.
///
/// ### How it works
/// - [PulseContext] extends [ContextBase], so it supports **prototype
///   inheritance** via a `parent` chain.
/// - It stores its dimensions in a memory‑efficient record, using the
///   [Provenance] enum as keys.
/// - Some dimensions are static (immutable), others are evolvable.
/// - The `evolve` method creates a refined context, useful when a pulse
///   passes through multiple processing stages.
///
/// ### Non‑obvious
/// - The context is **immutable** – all changes create a new instance.
/// - The `traceId` is auto‑generated if not provided, ensuring uniqueness.
/// - The `parentTraceId` is automatically linked when you evolve a context
///   from an existing one.
/// - The `integrity` dimension is computed automatically by the framework
///   and is not something you set manually.
/// - The context is **not** the pulse – it's a separate metadata container
///   that travels with the pulse.
///
/// ### Example: Creating a User Action Context
/// ```dart
/// final context = PulseContext.userAction(
///   actor: 'admin_01',
///   reason: 'Manual price update',
///   priority: 80,
/// );
/// final pulse = Pulse.governed<int>(payload: 100, context: context);
/// ```
///
/// See also:
/// * [Provenance] – the underlying dimensions.
/// * [Pulse.governed] – the factory that attaches a context to a pulse.
/// * [Context] – the base context interface.
/// {@category Advanced}
/// {@category Pulse Context}
class PulseContext extends ContextBase {

  /// Accessor for the **Core System Blueprint**, providing a set of pre‑defined
  /// telemetric templates for standard internal operations.
  ///
  /// This static member provides access to specialised utilities that facilitate
  /// the rapid synthesis of **System‑Level Stimuli**. It ensures that internal
  /// signals carry a consistent **Causal Trace**.
  ///
  /// ### When to use
  /// Use this when you need a minimal context for internal framework operations.
  /// It's the default fallback when no explicit context is provided.
  static const system = _PulseContextSystem();

  /// Syntheses a **Signal Provenance** environment from discrete telemetric
  /// parameters.
  ///
  /// This constructor serves as the primary gateway for **Stimulus
  /// Materialisation**. It transforms a declarative set of telemetric
  /// dimensions into a memory‑optimised record, anchoring the signal's
  /// identity and intent.
  ///
  /// ### When to use
  /// Use this when none of the specialised factories fit your needs and you
  /// need full control over every dimension.
  ///
  /// ### How it works
  /// Each named parameter corresponds to a [Provenance] dimension. The context
  /// is built as an immutable record, and if a `baseContext` is provided,
  /// it inherits from it.
  ///
  /// ### Non‑obvious
  /// - The `traceId` is auto‑generated if not provided.
  /// - The `parentTraceId` must be set manually if you're linking to a
  ///   previous pulse.
  /// - The `integrity` dimension is not set here – it's computed by the
  ///   framework when the pulse is created.
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for inheritance.
  /// - [actor]: The entity originating the stimulus.
  /// - [reason]: Functional justification.
  /// - [purpose]: High‑level intent.
  /// - [strategy]: [ReasoningStrategy] used.
  /// - [confidence]: Validity probability (0.0 to 1.0).
  /// - [priority]: Execution urgency (0‑100).
  /// - [compliance]: Regulatory framework.
  /// - [sensitivity]: Data classification.
  /// - [auditLevel]: Observability depth.
  /// - [traceId]: Unique causal anchor (auto‑generated if omitted).
  /// - [parentTraceId]: Ancestral trace ID.
  /// - [others]: Catch‑all for custom metadata.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext(
  ///   actor: 'service_daemon',
  ///   reason: 'Cache invalidation',
  ///   priority: 30,
  ///   traceId: 'custom-trace-123',
  /// );
  /// ```
  PulseContext({
    Context? baseContext,

    String? actor,
    String? reason,
    String? purpose,
    ReasoningStrategy? strategy,
    double? confidence,
    int? priority,
    String? compliance,
    Sensitivity? sensitivity,
    AuditLevel? auditLevel,
    String? traceId,
    String? parentTraceId,

    Map<String, dynamic>? others,
  }) : this.fromEntries(<GovernanceEntry>[
    if (actor != null) Provenance.actor.entry(actor),
    if (reason != null) Provenance.reason.entry(reason),
    if (purpose != null) Provenance.purpose.entry(purpose),
    if (strategy != null) Provenance.strategy.entry(strategy),
    if (confidence != null) Provenance.confidence.entry(confidence),
    if (priority != null) Provenance.priority.entry(priority),
    if (compliance != null) Provenance.compliance.entry(compliance),
    if (sensitivity != null) Provenance.sensitivity.entry(sensitivity),
    if (auditLevel != null) Provenance.auditLevel.entry(auditLevel),
    Provenance.traceId.entry(traceId ?? Identity.next()),
    if (parentTraceId != null) Provenance.parentTraceId.entry(parentTraceId),
  ], others: others, parent: baseContext);

  /// Syntheses a **Signal Provenance Environment** from a collection of
  /// strongly‑typed telemetric entries.
  ///
  /// This constructor facilitates the creation of a [PulseContext] by
  /// aggregating individual [GovernanceEntry] pairs. It is the architectural
  /// standard for **Stimulus Composition**.
  ///
  /// ### When to use
  /// This is an advanced entry point. Use it when you need to build a context
  /// from a dynamic list of entries – e.g., in code generation or when
  /// deserialising a context from an external source.
  ///
  /// ### How it works
  /// You provide a list of [GovernanceEntry] objects (typically from
  /// [Provenance]), and the framework constructs a context record from them.
  /// You can optionally specify a [parent] to inherit from.
  ///
  /// ### Non‑obvious
  /// - The entries are validated against their `isType` guard at construction
  ///   time, so you can't build a context with mismatched types.
  /// - The `parent` chain is immutable.
  ///
  /// ### Parameters:
  /// - [entries]: An iterable of [GovernanceEntry] objects defining the
  ///   telemetric pillars.
  /// - [others]: A catch‑all map for dynamic, domain‑specific metadata.
  /// - [parent]: The ancestral [Context] for baseline lineage.
  PulseContext.fromEntries(super.entries, {super.others, super.parent});

  /// Creates a [PulseContext] anchored to a specific **Regulatory Framework**
  /// (e.g., GDPR, HIPAA, SOC2).
  ///
  /// This factory is a **Human‑Centric Shortcut** designed to enforce
  /// institutional safety constraints automatically. It pre‑configures:
  /// - `compliance` to the specified framework (static pillar).
  /// - `auditLevel` to `full` (forensic trace).
  /// - `strategy` to `deterministic`.
  /// - `sensitivity` to `confidential` (or as provided).
  ///
  /// ### When to use
  /// Use this when the pulse contains regulated data (e.g., PII, financial
  /// info) that must be audited and handled with extra care.
  ///
  /// ### How it works
  /// The factory populates all necessary provenance dimensions to ensure
  /// compliance. The resulting pulse will be fully audited and carry the
  /// required legal markers.
  ///
  /// ### Non‑obvious
  /// - The `auditLevel` is forced to `full` – you cannot reduce it.
  /// - The `strategy` is set to `deterministic` to avoid probabilistic
  ///   reasoning on regulated data.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.regulated(
  ///   actor: 'Payment_Processor_B',
  ///   framework: 'PCI-DSS',
  ///   reason: 'Authorizing Transaction #992',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [actor]: The entity originating the regulated stimulus.
  /// - [framework]: The legal/regulatory protocol (e.g., 'GDPR', 'HIPAA').
  /// - [reason]: The immediate justification.
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [sensitivity]: Data classification, defaulting to [Sensitivity.confidential].
  factory PulseContext.regulated({
    required String actor,
    required String framework,
    String? reason,
    PulseContext? baseContext,
    Sensitivity sensitivity = Sensitivity.confidential,
  }) {
    return PulseContext.fromEntries([
      // Static Pillars
      Provenance.actor.entry(actor),
      Provenance.compliance.entry(framework),
      Provenance.sensitivity.entry(sensitivity),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext != null) Provenance.parentTraceId.entry(baseContext.traceId!),

      // Operational Boundaries (Escalated for Compliance)
      Provenance.auditLevel.entry(AuditLevel.full),
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.priority.entry(85), // High priority due to regulatory nature
      Provenance.purpose.entry('REGULATED_TRANSACTION'),
      Provenance.reason.entry(reason ?? 'Executing within $framework framework.'),
      Provenance.confidence.entry(1.0),
    ]);
  }

  /// Creates a [PulseContext] specialised for **System Maintenance** and
  /// **Metabolic Stability** (e.g., garbage collection, heartbeat, topology
  /// rebalancing).
  ///
  /// This factory is a **Human‑Centric Shortcut** designed for background
  /// tasks where performance and system health are prioritised over
  /// high‑fidelity audit trails. It pre‑configures:
  /// - `purpose` to `SYSTEM_MAINTENANCE`.
  /// - `priority` to a low tier (10).
  /// - `auditLevel` to `minimal`.
  /// - `strategy` to `deterministic`.
  ///
  /// ### When to use
  /// Use this for periodic health checks, cache invalidation, or resource
  /// cleanup tasks.
  ///
  /// ### How it works
  /// The context is lightweight and low‑priority, ensuring it doesn't
  /// interfere with user‑facing operations.
  ///
  /// ### Non‑obvious
  /// - The `priority` is set to 10 (background) by default, but you can
  ///   override it.
  /// - The `auditLevel` is `minimal` to reduce logging overhead.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.homeostasis(
  ///   actor: 'Cache_Janitor_Service',
  ///   reason: 'Evicting stale entries due to memory pressure',
  ///   priority: 15,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [actor]: The background service or daemon originating the stimulus.
  /// - [reason]: The specific trigger for the maintenance task.
  /// - [baseContext]: Optional ancestral [Context] for lineage.
  /// - [priority]: Execution urgency, defaulting to 10.
  factory PulseContext.homeostasis({
    required String actor,
    String? reason,
    PulseContext? baseContext,
    int priority = 10,
  }) {
    return PulseContext.fromEntries([
      // Static Pillars
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext != null) Provenance.parentTraceId.entry(baseContext.traceId!),

      // Operational Boundaries (Optimized for Metabolism)
      Provenance.purpose.entry('SYSTEM_MAINTENANCE'),
      Provenance.priority.entry(priority),
      Provenance.auditLevel.entry(AuditLevel.minimal),
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.reason.entry(reason ?? 'Routine metabolic maintenance.'),

      // Default Safety/Trust
      Provenance.sensitivity.entry(Sensitivity.public),
      Provenance.confidence.entry(1.0),
    ]);
  }

  /// Syntheses a **Deterministic System Blueprint** for signals originating
  /// from the framework's internal maintenance and homeostasis infrastructure.
  ///
  /// This factory is a **Human‑Centric Shortcut** designed for **Automated
  /// Pulse Synthesis**. It ensures that internal operational signals carry a
  /// consistent and verifiable **Causal Trace**.
  ///
  /// ### When to use
  /// Use this when creating internal daemons or janitorial receptors that need
  /// to broadcast state updates without manual provenance tuning.
  ///
  /// ### How it works
  /// It sets `actor` to `'system_daemon'`, `strategy` to `deterministic`,
  /// and `priority` to 35 (routine). The context is optimised for low‑latency
  /// validation.
  ///
  /// ### Non‑obvious
  /// - The `actor` is fixed to `system_daemon` – you cannot change it.
  /// - The `confidence` is 1.0, as system tasks are assumed reliable.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.systemInternal(
  ///   baseContext: incomingPulse.context,
  ///   reason: 'Reclaiming stagnant somatic state',
  ///   purpose: 'GARBAGE_COLLECTION',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [reason]: Immediate causal logic.
  /// - [purpose]: High‑level mission category, defaulting to 'MAINTENANCE'.
  /// - [priority]: Execution urgency, defaulting to 35.
  factory PulseContext.systemInternal({
    required Context baseContext,
    String? reason,
    String? purpose,
    int priority = 35,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry('system_daemon'),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.public),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(1.0),
      Provenance.auditLevel.entry(AuditLevel.minimal),
      Provenance.priority.entry(priority),
      Provenance.purpose.entry(purpose ?? 'MAINTENANCE'),
      Provenance.reason.entry(reason ?? 'automated internal task'),
    ]);
  }

  /// Syntheses a **User‑Initiated Blueprint** for signals originating from
  /// direct human interaction or external client‑side triggers.
  ///
  /// This factory is a **Human‑Centric Shortcut** designed for **Explicit Intent**.
  /// It ensures that user actions carry a verified **Causal Trace** that
  /// identifies the human [actor] as the primary source of authority.
  ///
  /// ### When to use
  /// Use this when capturing input from an application's presentation layer,
  /// such as form submissions, button clicks, or API calls from a client.
  ///
  /// ### How it works
  /// - Sets `strategy` to `manual` (human intervention).
  /// - Sets `confidence` to 1.0 (human intent is treated as absolute).
  /// - Sets `priority` to 60 (high, for UI responsiveness).
  ///
  /// ### Non‑obvious
  /// - The `confidence` is 1.0 – the framework trusts human actions unless
  ///   explicitly overridden.
  /// - The `purpose` defaults to `USER_INTERACTION`.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.userAction(
  ///   baseContext: uiNode.context,
  ///   actor: 'user_442',
  ///   reason: 'Confirmed payment checkout',
  ///   purpose: 'TRANSACTION_COMMIT',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The specific user or client identifier.
  /// - [reason]: Functional justification.
  /// - [purpose]: Mission category, defaulting to 'USER_INTERACTION'.
  /// - [priority]: Urgency, defaulting to 60.
  /// - [sensitivity]: Data classification, defaulting to [Sensitivity.public].
  factory PulseContext.userAction({
    required Context baseContext,
    required String actor,
    required String reason,
    String? purpose,
    int priority = 60,
    Sensitivity sensitivity = Sensitivity.public,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(sensitivity),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.manual),
      Provenance.confidence.entry(1.0), // Human intent is treated as absolute
      Provenance.auditLevel.entry(AuditLevel.standard),
      Provenance.priority.entry(priority),
      Provenance.purpose.entry(purpose ?? 'USER_INTERACTION'),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Syntheses a **Forensic Blueprint** for signals generated by regulatory
  /// monitors, automated auditors, or integrity scanning daemons.
  ///
  /// This factory is a **Human‑Centric Shortcut** designed to satisfy
  /// institutional transparency requirements. It ensures that auditing
  /// signals are subject to the highest level of scrutiny and logging.
  ///
  /// ### When to use
  /// Use this when creating receptors that monitor policy violations or when
  /// generating reports for external regulatory bodies.
  ///
  /// ### How it works
  /// - Forces `auditLevel` to `full`.
  /// - Sets `compliance` to the specified framework.
  /// - Uses `deterministic` strategy for reproducibility.
  ///
  /// ### Non‑obvious
  /// - The `priority` is 35 (routine) – audits are important but not urgent.
  /// - The `sensitivity` is `confidential` to protect the audit data.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.complianceAudit(
  ///   baseContext: systemOntology,
  ///   actor: 'Security_Monitor_01',
  ///   framework: 'HIPAA',
  ///   reason: 'Quarterly access log verification',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The auditing agent or system service.
  /// - [framework]: Regulatory protocol being enforced.
  /// - [reason]: Specific justification for the audit.
  /// - [priority]: Urgency, defaulting to 35.
  factory PulseContext.complianceAudit({
    required Context baseContext,
    required String actor,
    required String framework,
    required String reason,
    int priority = 35,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.compliance.entry(framework),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.confidential),

      // --- Fluid Boundaries (Escalated for Forensics) ---
      Provenance.auditLevel.entry(AuditLevel.full),
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(1.0),
      Provenance.priority.entry(priority),
      Provenance.purpose.entry('AUDIT_LOG'),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Syntheses an **Autonomous Inference Blueprint** for signals originating
  /// from AI‑driven reasoning, pattern recognition, or optimisation tasks.
  ///
  /// This factory is the architectural standard for **Non‑Deterministic Intent**.
  /// It ensures that signals generated by **Autonomous Agents** carry the
  /// necessary metadata – specifically [confidence] and [AuditLevel.detailed]
  /// auditing – to be properly governed.
  ///
  /// ### When to use
  /// Use this when an AI agent proposes a state change based on observed
  /// patterns or heuristics.
  ///
  /// ### How it works
  /// - Sets `strategy` to `probabilistic`.
  /// - Sets `auditLevel` to `detailed` for XAI transparency.
  /// - Defaults `priority` to 20 (background) to avoid interfering with
  ///   user actions.
  ///
  /// ### Non‑obvious
  /// - The `confidence` is a required parameter; it must be between 0.0 and 1.0.
  /// - Integrity gates may reject low‑confidence signals.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.aiInference(
  ///   baseContext: clusterOntology,
  ///   actor: 'Heuristic_Optimizer_v2',
  ///   reason: 'Detected high latency in somatic processing',
  ///   confidence: 0.82,
  ///   purpose: 'RESOURCE_SCALING',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The specific AI model or heuristic engine.
  /// - [reason]: Functional justification or evidence.
  /// - [confidence]: Validity probability (0.0 to 1.0).
  /// - [purpose]: Mission category, defaulting to 'AUTONOMOUS_OPTIMIZATION'.
  /// - [priority]: Urgency, defaulting to 20.
  factory PulseContext.aiInference({
    required Context baseContext,
    required String actor,
    required String reason,
    required double confidence,
    String? purpose,
    int priority = 20,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.internal),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.probabilistic),
      Provenance.confidence.entry(confidence),
      Provenance.auditLevel.entry(AuditLevel.detailed),
      Provenance.priority.entry(priority),
      Provenance.purpose.entry(purpose ?? 'AUTONOMOUS_OPTIMIZATION'),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Syntheses a **Self‑Correction Blueprint** for signals originating from
  /// automated recovery, error mitigation, or state‑repair logic.
  ///
  /// This factory is the architectural standard for **Autonomous Resilience**.
  /// It ensures that pulses triggered to rectify inconsistencies carry the
  /// specialised **Causal Trace** required to distinguish a "Homeostatic
  /// Adjustment" from a "New Intent."
  ///
  /// ### When to use
  /// Use this inside error handlers or watchdog receptors to broadcast a
  /// state repair.
  ///
  /// ### How it works
  /// - Sets `strategy` to `deterministic` (proven recovery protocols).
  /// - Sets `priority` to 85 (very high, to preempt further drift).
  /// - Sets `auditLevel` to `detailed` for traceability.
  ///
  /// ### Non‑obvious
  /// - The `targetField` is included in the `reason` for context.
  /// - The default `confidence` is 0.9 – repairs are usually reliable but
  ///   not absolute.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.selfCorrection(
  ///   baseContext: incomingPulse.context,
  ///   actor: 'Homeostasis_Guard',
  ///   reason: 'Value out of bounds (150 > 100)',
  ///   targetField: 'somatic_pressure',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The entity performing the repair.
  /// - [reason]: Functional justification.
  /// - [targetField]: The specific state dimension being rectified.
  /// - [confidence]: Reliability of the correction, defaulting to 0.9.
  factory PulseContext.selfCorrection({
    required Context baseContext,
    required String actor,
    required String reason,
    required String targetField,
    double confidence = 0.9,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.internal),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(confidence),
      Provenance.auditLevel.entry(AuditLevel.detailed),

      // High priority to preempt further drift and stabilize the fabric
      Provenance.priority.entry(85),
      Provenance.purpose.entry('SELF_HEALING'),
      Provenance.reason.entry('Homeostasis Recovery ($targetField): $reason'),
    ]);
  }

  /// Syntheses an **Infrastructure Orchestration Blueprint** for signals
  /// originating from topology refactoring, resource scaling, or graph pruning.
  ///
  /// This factory is the architectural standard for **Structural Evolution**.
  /// It ensures that modifications to the reactive landscape carry a
  /// verifiable **Causal Trace** that adheres to strict scaling laws.
  ///
  /// ### When to use
  /// Use this when building orchestration agents or scaling controllers that
  /// need to reconfigure the cell mesh.
  ///
  /// ### How it works
  /// - Sets `strategy` to `formal` (derived from architectural proofs).
  /// - Sets `priority` to 40 (moderate, to ensure orderliness).
  /// - Sets `sensitivity` to `internal` to avoid leaking structural metadata.
  ///
  /// ### Non‑obvious
  /// - The `reason` is required and should explain the refactor.
  /// - The `confidence` is 1.0 – structural changes are mandated.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.infrastructureChange(
  ///   baseContext: meshOntology,
  ///   actor: 'Orchestrator_Node_A',
  ///   reason: 'Node saturation above 85%; splitting collection',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The scaling engine or principal authority.
  /// - [reason]: Functional justification for the refactor.
  factory PulseContext.infrastructureChange({
    required Context baseContext,
    required String actor,
    required String reason,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.internal),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.formal),
      Provenance.confidence.entry(1.0),
      Provenance.auditLevel.entry(AuditLevel.standard),

      // Moderate priority: structural updates must be orderly
      Provenance.priority.entry(40),
      Provenance.purpose.entry('INFRASTRUCTURE_REFACTOR'),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Syntheses a **Threat Mitigation Blueprint** for signals originating from
  /// high‑priority security lock‑downs or pre‑emptive shielding operations.
  ///
  /// This factory is the architectural standard for **System Defense**. It
  /// ensures that pulses triggered by an **Integrity Gate** carry the maximum
  /// level of authority and visibility restriction.
  ///
  /// ### When to use
  /// Use this within Integrity Gates or watchdog services when a protocol
  /// violation is detected.
  ///
  /// ### How it works
  /// - Sets `strategy` to `reflexive` (immediate action).
  /// - Sets `priority` to 100 (absolute maximum).
  /// - Sets `sensitivity` to `secret` to isolate the intervention.
  /// - Sets `auditLevel` to `full` for forensic capture.
  ///
  /// ### Non‑obvious
  /// - This pulse preempts all other traffic.
  /// - The `reason` is prefixed with 'SECURITY_SHIELD:' for clarity.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.securityIntervention(
  ///   baseContext: violatingPulse.context,
  ///   actor: 'Sentinel_Prime',
  ///   reason: 'Brute-force pattern detected on Auth_Cell',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The security agent or sentinel.
  /// - [reason]: Functional justification.
  factory PulseContext.securityIntervention({
    required Context baseContext,
    required String actor,
    required String reason,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext) Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.secret),

      // --- Fluid Boundaries (Escalated for Maximum Safety) ---
      // Reflexive strategy bypasses standard reasoning delays to ensure immediate action.
      Provenance.strategy.entry(ReasoningStrategy.reflexive),
      Provenance.confidence.entry(1.0),
      Provenance.auditLevel.entry(AuditLevel.full),

      // Absolute maximum priority: must be processed before anything else in the fabric.
      Provenance.priority.entry(100),
      Provenance.purpose.entry('THREAT_MITIGATION'),
      Provenance.reason.entry('SECURITY_SHIELD: $reason'),
    ]);
  }

  /// Syntheses a **Telemetry & Observation Blueprint** for high‑frequency
  /// signals that provide visibility without driving state mutation.
  ///
  /// This factory is the architectural standard for **Non‑Invasive Monitoring**.
  /// It ensures that observability pulses carry a consistent **Causal Trace**
  /// while minimising metabolic and storage overhead.
  ///
  /// ### When to use
  /// Use this when emitting heartbeat signals or performance metrics from
  /// within a cell.
  ///
  /// ### How it works
  /// - Sets `auditLevel` to `none` to avoid log bloat.
  /// - Sets `priority` to 10 (background).
  /// - Sets `sensitivity` to `public`.
  /// - Uses `deterministic` strategy.
  ///
  /// ### Non‑obvious
  /// - These pulses are never audited – they are pure telemetry.
  /// - They are low priority and will not interfere with critical operations.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.telemetry(
  ///   baseContext: currentPulse.context,
  ///   actor: 'Throughput_Monitor',
  ///   reason: 'Reporting batch completion latency',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The monitoring service or sensor name.
  /// - [reason]: The specific metric being reported.
  /// - [purpose]: Observation category, defaulting to 'METRIC_COLLECTION'.
  /// - [priority]: Urgency, defaulting to 10.
  factory PulseContext.telemetry({
    required Context baseContext,
    required String actor,
    required String reason,
    String purpose = 'METRIC_COLLECTION',
    int priority = 10,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext)
        Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.public),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(1.0),

      // Default to none to prevent log-bloat from diagnostic cycles
      Provenance.auditLevel.entry(AuditLevel.none),

      Provenance.priority.entry(priority),
      Provenance.purpose.entry(purpose),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Synthesizes an **Autonomous Inference Blueprint** for signals originating
  /// from AI-driven reasoning, pattern recognition, or optimization tasks.
  ///
  /// This factory is the architectural standard for **Non-Deterministic Intent**,
  /// ensuring that signals generated by autonomous agents carry the necessary
  /// metadata for Explainable AI (XAI) and confidence-based governance.
  ///
  /// ### When to use
  /// Use `inference` for signals generated by AI agents, heuristic engines, or
  /// pattern recognition systems. It is the standard for **Autonomous Optimization**
  /// tasks where the intent is based on perception rather than explicit logic.
  ///
  /// ### How it works
  /// 1. **Trace Anchoring**: Generates a unique `traceId` and links to the
  ///    `baseContext` to maintain the **Causal Trace**.
  /// 2. **Heuristic Strategy**: Marks the pulse with [ReasoningStrategy.probabilistic],
  ///    triggering confidence-based filtering at the receptor boundary.
  /// 3. **Transparency Logging**: Sets [AuditLevel.detailed] to capture the
  ///    agent's perception state for auditing and debugging.
  /// 4. **Resource Management**: Assigns a background priority (20) and `internal`
  ///    sensitivity to prevent interference with high-priority user waves.
  ///
  /// ### Non‑obvious
  /// - **Confidence Gates**: The [confidence] value allows [TestCell] integrity
  ///   gates to neutralize low-probability inferences before they trigger
  ///   expensive downstream side-effects.
  /// - **Reciprocal Handshake**: Probabilistic signals are subject to the
  ///   framework's mutual authorization protocol, evaluating agent certainty
  ///   against the target node's stability requirements.
  /// - **XAI Integration**: The `detailed` audit level is specifically intended
  ///   to record the "Why" behind an autonomous transition, making the AI
  ///   reasoning observable.
  ///
  /// ### Example
  /// ```dart
  /// final inference = PulseContext.inference(
  ///   baseContext: appOntology,
  ///   actor: 'Resource_Optimizer_Agent',
  ///   reason: 'Detected high latency in somatic processing',
  ///   confidence: 0.82,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [baseContext]: **The Causal Anchor.** Provides the lineage and trace
  ///   identity for the inference.
  /// * [actor]: **The Cognitive Source.** The specific AI model, agent, or
  ///   heuristic engine.
  /// * [reason]: **The Functional Justification.** The evidence or pattern
  ///   that triggered the inference.
  /// * [confidence]: **The Validity Probability.** A value (0.0 to 1.0)
  ///   representing the agent's certainty.
  /// * [purpose]: **The Mission Category.** Defaults to 'AUTONOMOUS_OPTIMIZATION'.
  /// * [priority]: **The Execution Urgency.** Defaults to 20 (Background).
  ///
  /// ### Returns:
  /// A [PulseContext] instance configured for **Autonomous Inference**.
  ///
  /// ### See Also:
  /// * [PulseContext.telemetry]: For non-invasive monitoring signals.
  /// * [ReasoningStrategy.probabilistic]: For the underlying heuristic logic.
  /// * [AuditLevel.detailed]: For transparency in autonomous decision making.
  factory PulseContext.inference({
    required Context baseContext,
    required String actor,
    required String reason,
    required double confidence,
    String? purpose,
    int priority = 20,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext)
        Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.internal),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.probabilistic),
      Provenance.confidence.entry(confidence),
      Provenance.auditLevel.entry(AuditLevel.detailed),
      Provenance.priority.entry(priority),
      Provenance.purpose.entry(purpose ?? 'AUTONOMOUS_OPTIMIZATION'),
      Provenance.reason.entry(reason),
    ]);
  }

  /// Syntheses a **Collaboration & Delegation Blueprint** for signals
  /// routed between different **Managed Nodes** or autonomous agents.
  ///
  /// This factory facilitates the handover of operational intent between agents,
  /// ensuring that the **Causal Trace** explicitly documents the transfer of
  /// responsibility.
  ///
  /// ### When to use
  /// Use this when one agent decomposes a high‑level goal and delegates
  /// sub‑tasks to specialised residents.
  ///
  /// ### How it works
  /// - Sets `purpose` to `COLLABORATIVE_TASK`.
  /// - Sets `priority` to 60 (high, for coordination).
  /// - Sets `sensitivity` to `private` (inter‑agent metadata).
  /// - The `reason` includes the target agent and task description.
  ///
  /// ### Non‑obvious
  /// - The `auditLevel` is `full` to track delegation chains.
  /// - The `strategy` is `deterministic` – delegation is a formal handoff.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.collaboration(
  ///   baseContext: currentPulse.context,
  ///   actor: 'Orchestrator_Agent',
  ///   targetAgent: 'Database_Resident',
  ///   task: 'Fetch user transaction history (2023)',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The delegating agent.
  /// - [targetAgent]: The agent receiving the mandate.
  /// - [task]: Semantic description of the delegated responsibility.
  factory PulseContext.collaboration({
    required Context baseContext,
    required String actor,
    required String targetAgent,
    required String task,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext)
        Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.private),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(1.0),
      Provenance.auditLevel.entry(AuditLevel.full),
      Provenance.priority.entry(60),
      Provenance.purpose.entry('COLLABORATIVE_TASK'),
      Provenance.reason.entry('DELEGATION: Assigning $task to $targetAgent'),
    ]);
  }

  /// Syntheses an **Exploratory Hypothesis Blueprint** for "What‑If"
  /// simulations or non‑committal state projections.
  ///
  /// This factory is the architectural standard for **Speculative Perception**.
  /// It allows agents and cells to model potential state transitions without
  /// committing to permanent mutations.
  ///
  /// ### When to use
  /// Use this when an agent needs to predict the outcome of a complex
  /// interaction without triggering side effects.
  ///
  /// ### How it works
  /// - Sets `confidence` to 0.0 (non‑committal).
  /// - Sets `strategy` to `stochastic` (exploratory).
  /// - Sets `auditLevel` to `none` (simulations are not audited).
  /// - Sets `priority` to 20.
  ///
  /// ### Non‑obvious
  /// - Receptors will treat this pulse as a dry‑run and route it to a
  ///   virtual buffer.
  /// - The `theory` is included in the `reason`.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.hypothesis(
  ///   baseContext: activeContext,
  ///   actor: 'Prediction_Agent_01',
  ///   theory: 'Scaling memory allocation by 2x',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [actor]: The agent or simulator originating the theory.
  /// - [theory]: Semantic description of the hypothesis.
  factory PulseContext.hypothesis({
    required Context baseContext,
    required String actor,
    required String theory,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(actor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext)
        Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.internal),

      // --- Fluid Boundaries (Evolvable Intent) ---
      Provenance.strategy.entry(ReasoningStrategy.stochastic),

      // Zero confidence signals a non-committal projection
      Provenance.confidence.entry(0.0),

      // Simulations are low priority and typically not audited to disk
      Provenance.auditLevel.entry(AuditLevel.none),
      Provenance.priority.entry(20),

      Provenance.purpose.entry('SIMULATION'),
      Provenance.reason.entry('HYPOTHESIS_TEST: $theory'),
    ]);
  }

  /// Syntheses a **Manual Override Blueprint** for signals originating from
  /// direct administrative commands or developer‑level interventions.
  ///
  /// This factory is the architectural standard for **Explicit Authority**.
  /// It provides a mechanism for humans or high‑clearance controllers to
  /// issue direct "How‑To" commands that bypass standard autonomous reasoning.
  ///
  /// ### When to use
  /// Use this when providing an interface for administrative recovery or
  /// manual system steering.
  ///
  /// ### How it works
  /// - Sets `strategy` to `deterministic`.
  /// - Sets `priority` to 90 (critical).
  /// - Sets `auditLevel` to `full`.
  /// - The `directive` is included in the `reason`.
  ///
  /// ### Non‑obvious
  /// - Manual overrides have very high priority – they preempt almost
  ///   everything.
  /// - The `sensitivity` is `public` because these are administrative actions.
  ///
  /// ### Example
  /// ```dart
  /// final context = PulseContext.instruction(
  ///   baseContext: systemOntology,
  ///   humanActor: 'admin_user_01',
  ///   directive: 'FLUSH_ALL_SOMATIC_BUFFERS',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: Ancestral [Context] for lineage.
  /// - [humanActor]: The administrator or root authority.
  /// - [directive]: Semantic description of the mandated action.
  factory PulseContext.instruction({
    required Context baseContext,
    required String humanActor,
    required String directive,
  }) {
    return PulseContext.fromEntries([
      // --- Static Pillars (Non-Evolvable Identity) ---
      Provenance.actor.entry(humanActor),
      Provenance.traceId.entry(Identity.next()),
      if (baseContext is PulseContext)
        Provenance.parentTraceId.entry(baseContext.traceId!),
      Provenance.sensitivity.entry(Sensitivity.public),

      // --- Fluid Boundaries (Escalated for Authority) ---
      Provenance.strategy.entry(ReasoningStrategy.deterministic),
      Provenance.confidence.entry(1.0),
      Provenance.auditLevel.entry(AuditLevel.full),

      // Critical priority: manual overrides must preempt standard logic
      Provenance.priority.entry(90),

      Provenance.purpose.entry('MANUAL_OVERRIDE'),
      Provenance.reason.entry('USER_DIRECTIVE: $directive'),
    ]);
  }

  /// Syntheses a **Structural Signal Refinement** of the current provenance,
  /// producing a specialised [PulseContext].
  ///
  /// This method is the primary engine for **Causal Specialisation**. It
  /// enables a pulse to pivot its tactical intent or refine its sensory
  /// data (e.g., updating [confidence], [reason], or [priority]) while
  /// ensuring the ancestral [traceId] and [actor] remain verifiable.
  ///
  /// ### When to use
  /// Use [evolve] when a receptor needs to transform a raw stimulus into
  /// a specific mandate or derivative pulse for downstream processing.
  ///
  /// ### How it works
  /// You provide a resolver function that returns a new [GovernanceEntry]
  /// for any evolvable dimension you want to change. Dimensions you don't
  /// touch are inherited from the current context.
  ///
  /// ### Non‑obvious
  /// - Only dimensions marked `evolvable` in [Provenance] can be changed.
  /// - Static pillars (e.g., `actor`, `traceId`) are preserved.
  /// - The new context links back to `this` as its parent, preserving the
  ///   causal chain.
  ///
  /// ### Example
  /// ```dart
  /// final evolvedContext = incomingPulse.context.evolve((evolvable) {
  ///   return switch (evolvable) {
  ///     Provenance.reason => evolvable.entry('Refined for database storage'),
  ///     Provenance.priority => evolvable.entry(75),
  ///     _ => null, // Other dimensions are inherited
  ///   };
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that returns a [GovernanceEntry] for each
  ///   evolvable dimension, or `null` to inherit.
  /// - [others]: Optional extra metadata for the evolved context.
  ///
  /// ### Returns:
  /// A specialised [PulseContext] that represents a refined branch in the
  /// system's causal tree.
  @override
  PulseContext evolve(covariant GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = <GovernanceEntry>[...Ontology.evolve(resolver), ...Provenance.evolve(resolver)];
    return PulseContext.fromEntries(entries, others: others, parent: this);
  }

  String? get actor => get<String?>(
        () => _record.map[Provenance.actor] ?? (_parent is PulseContext ? (_parent as PulseContext).actor : null),
    orElse: null,
  );

  String? get reason => get<String?>(
        () => _record.map[Provenance.reason] ?? (_parent is PulseContext ? (_parent as PulseContext).reason : null),
    orElse: null,
  );

  String? get purpose => get<String?>(
        () => _record.map[Provenance.purpose] ?? (_parent is PulseContext ? (_parent as PulseContext).purpose : null),
    orElse: null,
  );

  ReasoningStrategy? get strategy => get<ReasoningStrategy?>(
        () => _record.map[Provenance.strategy] ?? (_parent is PulseContext ? (_parent as PulseContext).strategy : null),
    orElse: null,
  );

  double? get confidence => get<double?>(
        () => _record.map[Provenance.confidence] ?? (_parent is PulseContext ? (_parent as PulseContext).confidence : null),
    orElse: null,
  );

  int? get priority => get<int?>(
        () => _record.map[Provenance.priority] ?? (_parent is PulseContext ? (_parent as PulseContext).priority : null),
    orElse: null,
  );

  @override
  String? get compliance => get<String?>(
        () => _record.map[Provenance.compliance] ?? (_parent is PulseContext ? (_parent as PulseContext).compliance : null),
    orElse: null,
  );

  Sensitivity? get sensitivity => get<Sensitivity?>(
        () => _record.map[Provenance.sensitivity] ?? (_parent is PulseContext ? (_parent as PulseContext).sensitivity : null),
    orElse: null,
  );

  AuditLevel? get auditLevel => get<AuditLevel?>(
        () => _record.map[Provenance.auditLevel] ?? (_parent is PulseContext ? (_parent as PulseContext).auditLevel : null),
    orElse: null,
  );

  String? get traceId => get<String?>(
        () => _record.map[Provenance.traceId] ?? (_parent is PulseContext ? (_parent as PulseContext).traceId : null),
    orElse: null,
  );

  String? get parentTraceId => get<String?>(
        () => _record.map[Provenance.parentTraceId] ?? (_parent is PulseContext ? (_parent as PulseContext).parentTraceId : null),
    orElse: null,
  );

  String? get integrity => get<String?>(() => _record.map[Provenance.integrity] ?? (_parent is PulseContext ? (_parent as PulseContext).integrity : null),
      orElse: null,
  );

  Map<String, dynamic>? get others => get<Map<String, dynamic>?>(() => _record.others ?? (_parent is PulseContext ? (_parent as PulseContext).others : null),
    orElse: null,
  );
}

class _PulseContextSystem implements PulseContext {

  const _PulseContextSystem();

  @override
  PulseContext evolve(GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = [...Ontology.evolve(resolver), ...Provenance.evolve(resolver)];
    return PulseContext.fromEntries(entries, others: others);
  }

  @override
  operator [](Governance<dynamic> governance) => null;

  @override
  PulseContext? get _parent => null;

  @override
    get _record => null;

  @override
    String? get actor => null;

  @override
    AuditLevel? get auditLevel => null;

  @override
    String? get compliance => null;

  @override
    double? get confidence => null;

  @override
    Map<String, String>? get constraints => null;

  @override
    String? get dataSources => null;

  @override
    String? get domains => null;

  @override
    String? get integrity => null;

  @override
    String? get isNot => null;

  @override
  List<String> lineage(Governance<dynamic> cxt) => const [];

  @override
  String? get parentTraceId => null;

  @override
  String? get partOf => null;

  @override
  int? get priority => null;

  @override
  String? get purpose => null;

  @override
  String? get reason => null;

  @override
  Sensitivity? get sensitivity => null;

  @override
  String? get stakeholders => null;

  @override
  ReasoningStrategy? get strategy => null;

  @override
  String? get subDomains => null;

  @override
  String? get taxonomy => null;

  @override
  String? get topology => null;

  @override
  String? get traceId => null;

  @override
  String? get version => null;

  @override
  Map<String, dynamic>? get others => null;

  @override
  String? get identity => null;

  @override
  String? get type => null;

}

/// A utility for materializing unique identities within the somatic graph.
abstract final class Identity {
  static const _uuid = Uuid();

  /// Generates a unique, high-entropy [PulseContext.traceId].
  ///
  /// Utilizes UUID v4 to ensure that every causal chain in the reactive
  /// fabric possesses a distinct and non-colliding identity.
  static String next() => _uuid.v4();
}

/*


// -----------------------------------------------------------------
// Private helpers
// -----------------------------------------------------------------

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static String _generateUuidV4() {
// Simplified – in production use package:uuid
    return '${DateTime.now().microsecondsSinceEpoch}-${Object.hashCode(this)}';
  }
}

*/
