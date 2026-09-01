// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Defines the **Capability Profile and Authorization Scope** for a [Deputy].
///
/// ### When to use
/// You rarely need to interact with [Mandate] directly. Use the [DeputyContext]
/// factories like `DeputyContext.observer`, `DeputyContext.delegate`, etc.
/// Those factories set the mandate dimensions for you.
///
/// If you need a custom mandate, you can create one using the [DeputyContext]
/// constructor directly.
///
/// ### How it works
/// The mandate defines what a deputy can do (authority), its identity (role),
/// its autonomy (sovereignty), its structural rank (clearance), its temporal
/// validity (lease), and its operational guardrails (constraints).
///
/// ### Non‑obvious
/// - Some dimensions are static (immutable) while others are evolvable.
/// - The [evolvable] flag controls whether a dimension can be refined when
///   you call `evolve()` on a [DeputyContext].
/// - Static pillars (like `role`) prevent identity drift.
///
/// See also: [DeputyContext], [Clearance], [Isolation], [Sovereignty].
enum Mandate<V> with GovernanceMixin<Mandate<V>,V> implements Governance<V> {

  /// The specific **Functional Permission** or operational "Verb" authorized
  /// for this [Deputy].
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to define what actions the deputy is allowed to perform
  /// (e.g., `'READ'`, `'WRITE'`, `'DELETE'`). It's the primary way to enforce
  /// least privilege at the functional level.
  ///
  /// ### How it works
  /// During the mutual authorization handshake, the framework compares the
  /// deputy's authority string against the receptor's requirements. If the
  /// required verb isn't present, the pulse is neutralised.
  ///
  /// ### Non‑obvious
  /// - This is an evolvable dimension – a deputy can further restrict its own
  ///   authority when spawning child deputies.
  /// - Multiple verbs can be comma-separated (e.g., `'READ, WRITE'`).
  ///
  /// ### Examples
  /// * `'PRUNE_EXPIRED_RECORDS'` – only allowed to delete stale data.
  /// * `'MASK_PII_FIELDS'` – only allowed to transform data for compliance.
  authority<String>(true),

  /// The intended **Mission Identity** or functional designation assigned to
  /// the [Deputy].
  ///
  /// The `role` provides a semantic classification of the deputy's purpose
  /// within the system. Unlike [authority], which defines what the deputy
  /// *can* do, the `role` defines what the deputy *is* in the context of the
  /// current scene.
  ///
  /// **Type**: [String]
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Use this to categorise deputies for auditing, monitoring, or group-based
  /// policies. It's the semantic identity of the agent.
  ///
  /// ### How it works
  /// The role is used by `TestCell` rules and monitoring tools to apply
  /// group‑based policies or filter logs. It is scrutinised during the mutual
  /// handshake.
  ///
  /// ### Non‑obvious
  /// - This is a static pillar – once set, it cannot be changed. This prevents
  ///   "role creep".
  /// - A role like `'Auditor'` signals diagnostic intent, even if the deputy
  ///   has write authority.
  ///
  /// ### Examples
  /// * `'Auditor'` – diagnostic, even with write permissions.
  /// * `'PolicyEnforcer'` – applies encryption to pulses.
  role<String>(false),

  /// The **Execution Boundary** and virtualization level assigned to the
  /// [Deputy].
  ///
  /// **Type**: [Isolation]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to control the blast radius of a deputy's actions – e.g., to run
  /// a simulation without affecting production state.
  ///
  /// ### How it works
  /// The isolation level determines where the deputy's pulses are executed:
  /// - `shared`: direct live execution.
  /// - `scoped`: restricted to a domain.
  /// - `restricted`: zero‑trust filtering.
  /// - `sandboxed`: virtualized, no side‑effects.
  /// - `total`: air‑gapped, only ingests.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can tighten isolation for child tasks.
  /// - `sandboxed` mutations are not committed to the principal state.
  ///
  /// ### Examples
  /// * `Isolation.sandboxed` – safe for speculative logic.
  /// * `Isolation.restricted` – live state but strict filtering.
  isolation<Isolation>(true),

  /// The **Decision-Making Autonomy** and oversight level granted to
  /// the [Deputy].
  ///
  /// **Type**: [Sovereignty]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to control whether a deputy can act independently or needs
  /// approval – e.g., an emergency agent might be preemptive.
  ///
  /// ### How it works
  /// Sovereignty levels determine if a pulse requires approval before being
  /// committed:
  /// - `supervised`: all pulses queued for approval.
  /// - `collaborative`: mutates non‑critical state freely, blocks on high‑impact.
  /// - `sovereign`: fully autonomous.
  /// - `preemptive`: can override others for system safety.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can be promoted (e.g., from supervised to
  ///   sovereign) based on trust.
  /// - High‑sensitivity operations are blocked if sovereignty is insufficient.
  ///
  /// ### Examples
  /// * `Sovereignty.supervised` – suggests changes, waits for principal.
  /// * `Sovereignty.preemptive` – overrides for emergency shutdown.
  sovereignty<Sovereignty>(true),

  /// The formal **Structural Clearance** level defining the deputy's mutation
  /// capacity and architectural "Rank."
  ///
  /// **Type**: [Clearance]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to control the severity of mutations – e.g., prevent structural
  /// changes with `observational` clearance.
  ///
  /// ### How it works
  /// Clearance is a ranked integer. The framework compares the deputy's
  /// clearance against the required level for an operation. If it's lower,
  /// the pulse is neutralised.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can downgrade clearance for child tasks.
  /// - `observational` blocks all state mutations.
  /// - `administrative` allows structural refactoring.
  ///
  /// ### Examples
  /// * `Clearance.observational` – read‑only.
  /// * `Clearance.standard` – mutate values.
  /// * `Clearance.administrative` – link/unlink cells.
  clearance<Clearance>(true),

  /// The required **Observability Granularity** and rigor of the causal trace.
  ///
  /// **Type**: [AuditLevel]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to control logging verbosity – e.g., full audit for compliance,
  /// none for high‑frequency telemetry.
  ///
  /// ### How it works
  /// The audit level determines how much trace data is preserved. Higher levels
  /// capture more metadata but cost more performance.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a supervisor can increase audit rigour for risky
  ///   tasks.
  /// - Some high‑integrity cells reject pulses with low audit levels.
  ///
  /// ### Examples
  /// * `AuditLevel.full` – forensics.
  /// * `AuditLevel.none` – high‑frequency heartbeats.
  auditLevel<AuditLevel>(true),

/*
  /// The **Temporal Validity** and life-expectancy of the [Deputy]'s
  /// delegated authority.
  ///
  /// **Type**: [Duration]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to set a time‑to‑live (TTL) for a deputy – e.g., a temporary
  /// task that should self‑destruct after a few minutes.
  ///
  /// ### How it works
  /// The framework checks the lease against the creation timestamp. If the
  /// duration has elapsed, any pulse from the deputy is neutralised.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can shorten its own lease for child tasks.
  /// - The lease is checked at each hop; expired deputies are automatically
  ///   disconnected.
  ///
  /// ### Examples
  /// * `Duration(minutes: 5)` – short‑lived maintenance task.
  /// * `Duration(seconds: 30)` – emergency intervention with tight expiry.
  lease<Duration>(true),
*/

  /// The semantic **Rationale** or human-readable "Why" behind the
  /// delegation of authority to the [Deputy].
  ///
  /// **Type**: [String]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to document the mission intent – valuable for auditing and
  /// Explainable AI (XAI).
  ///
  /// ### How it works
  /// The justification is stored as a string and included in the causal trace.
  /// Receptors can use it to verify that the action aligns with the stated
  /// mission.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can refine the justification for sub‑tasks.
  /// - It provides the "why" for forensic analysis.
  ///
  /// ### Examples
  /// * `'Optimizing database indices due to high latency.'`
  /// * `'Suspected PII leak; masking outbound telemetry.'`
  justification<String>(true),

  /// A machine-readable map of **Quantifiable Operational Boundaries** and
  /// resource limits.
  ///
  /// **Type**: [Map<String, dynamic>]
  /// **Mutability**: **Fluid Boundary** (Evolvable)
  ///
  /// ### When to use
  /// Use this to set numeric limits like `max_hop_count`, `timeout_ms`, or
  /// `batch_size` to prevent runaway processes.
  ///
  /// ### How it works
  /// The framework checks these constraints in real time during the validation
  /// phase. If a pulse would exceed a limit, it's neutralised.
  ///
  /// ### Non‑obvious
  /// - This is evolvable – a deputy can tighten constraints for child tasks.
  /// - Constraints are enforced at the integrity gate level.
  ///
  /// ### Examples
  /// * `{ 'max_hop_count': 5, 'timeout_ms': 500 }`
  /// * `{ 'max_nodes_modified': 100, 'batch_size': 10 }`
  constraints<Map<String, dynamic>>(true);

  /// Indicates whether this **Mandate Dimension** is a structural invariant  /// or a dynamic operational attribute.
  ///
  /// In the framework's **Blueprint Synthesis** model, the [evolvable] flag
  /// determines the "rigidity" of a governance pillar during specialized
  /// state transitions such as [DeputyContext.evolve] or [Nucleus.evolve].
  ///
  /// ### When to use
  /// This property is used internally by the framework to control the
  /// **Policy Cascading** behavior. It distinguishes between the fixed,
  /// immutable identity of a deputy and its adjustable mission parameters
  /// that can be specialized for sub-tasks.
  ///
  /// ### How it works
  /// - **Static Pillar ([evolvable] is `false`)**: The dimension is a
  ///   structural invariant that must be inherited exactly from the principal.
  ///   These anchors form the deputy's **Causal Identity** (e.g., [Mandate.role],
  ///   [Mandate.authority]).
  /// - **Fluid Boundary ([evolvable] is `true`)**: The dimension can be
  ///   uniquely redefined or specialized within a downstream sub-mission.
  ///   These reflect the **Current Operational Scope** (e.g., [Mandate.constraints],
  ///   [Mandate.justification]).
  ///
  /// ### Non‑obvious
  /// - **Power Capping**: The [evolve] mechanism filters the ontology using
  ///   this flag to ensure that core power (Static Pillars) cannot be
  ///   expanded or "evolved away" by a delegate.
  /// - **Ontological Purity**: Human developers typically interact with
  ///   pre-configured [Mandate] enum values where this flag is hard-coded
  ///   to maintain a consistent and secure governance model.
  /// - **Integrity Enforcement**: During mission synthesis, the framework
  ///   ignores any evolution requests targeting a non-evolvable dimension,
  ///   preserving the integrity of the original mandate.
  ///
  /// ### See Also:
  /// * [DeputyContext.evolve]: For the primary mechanism that utilizes this flag.
  /// * [Mandate.evolve]: For the static utility that filters dimensions based
  ///   on this property.
  /// * [GovernanceEntry]: For the data structure used to represent these
  ///   dimensions in the graph.
  @override
  final bool evolvable;

  /// Internal constructor for defining a [Mandate] dimension.
  ///
  /// This is used internally by the framework. Human developers don't need
  /// to call it directly – the enum values are pre‑configured.
  const Mandate(this.evolvable);

  /// Generates a comprehensive **Mission Profile** by synthesizing a value for
  /// every defined dimension in the [Mandate] ontology.
  ///
  /// This method serves as the primary factory for creating the initial
  /// **Static Blueprint** of a deputy's authority. It iterates through all
  /// available mandate keys—both **Static Pillars** and **Fluid Boundaries**—to
  /// build a complete semantic profile for a [Deputy].
  ///
  /// ### When to use
  /// This is a low‑level utility used internally by the framework when building
  /// a [DeputyContext]. You rarely need it directly.
  ///
  /// ### How it works
  /// You provide a resolver function that returns a [GovernanceEntry] for each
  /// mandate dimension. If you return `null` for a dimension, it's omitted.
  /// The result is an iterable of entries that can be used to construct a context.
  ///
  /// ### Example (internal use)
  /// ```dart
  /// final entries = Mandate.compose((dimension) {
  ///   if (dimension == Mandate.role) return Mandate.role.entry('Auditor');
  ///   return null;
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that produces a [GovernanceEntry] for each
  ///   [Mandate] dimension, or `null` to omit it.
  ///
  /// ### Returns:
  /// An iterable of [GovernanceEntry] for the provided dimensions.
  static Iterable<GovernanceEntry> compose(GovernanceEntry? Function(Mandate dimension) resolver) {
    final entries = values.map((g) => resolver(g)).where((en) => en != null);
    return entries.cast();
  }

  /// Synthesizes a **Specialized Mission Extension** by resolving only the
  /// fluid dimensions of the [Mandate] ontology.
  ///
  /// This method is the specialized implementation of **Ontological
  /// Specialization** for delegated authority. It filters the mandate
  /// dimensions, allowing only those marked as [evolvable] to be processed
  /// by the provided [resolver].
  ///
  /// ### When to use
  /// This is used internally by [DeputyContext.evolve]. You rarely call it
  /// directly.
  ///
  /// ### How it works
  /// It iterates over all [evolvable] dimensions and lets you provide a new
  /// entry for each. Static pillars are skipped, ensuring they remain unchanged.
  ///
  /// ### Example (internal)
  /// ```dart
  /// final entries = Mandate.evolve((evolvable) {
  ///   if (evolvable == Mandate.clearance) {
  ///     return Mandate.clearance.entry(Clearance.observational);
  ///   }
  ///   return null;
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that produces a [GovernanceEntry] for each
  ///   evolvable dimension, or `null` to inherit.
  ///
  /// ### Returns:
  /// An iterable of [GovernanceEntry] for the evolved dimensions.
  static Iterable<GovernanceEntry> evolve(GovernanceEntry? Function(Mandate evolvable) resolver) {
    final entries = values.where((g) => g.evolvable == true)
        .map((g) => resolver(g)).where((en) => en != null);
    return entries.cast();
  }

}

class _DeputyContextSystem implements DeputyContext {

  const _DeputyContextSystem();

  @override
  DeputyContext evolve(GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = [...Ontology.evolve(resolver), ...Mandate.evolve(resolver)];
    return DeputyContext.fromEntries(entries, others: others);
  }

  @override
  operator [](Governance<dynamic> governance) => null;

  @override
  DeputyContext? get _parent => null;

  @override
  get _record => ();

  @override
  AuditLevel get auditLevel => AuditLevel.standard;

  @override
  Clearance get clearance => Clearance.standard;

  @override
  String? get compliance => null;

  @override
  Map<String, String>? get constraints => null;

  @override
  String? get dataSources => null;

  @override
  String? get domains => null;

  @override
  String? get isNot => null;

  @override
  Isolation get isolation => Isolation.scoped;

  @override
  String? get justification => null;

  @override
  List<String> lineage(Governance<dynamic> cxt) => const [];

  @override
  String? get partOf => null;

  @override
  String? get role => null;

  @override
  Sovereignty get sovereignty => Sovereignty.sovereign;

  @override
  String? get stakeholders => null;

  @override
  String? get subDomains => null;

  @override
  String? get taxonomy => null;

  @override
  String? get topology => null;

  @override
  String? get version => null;

  @override
  String? get identity => null;

  @override
  String? get type => null;
  
}

/// Represents the **Formal Mandate** and declaration of intention for a [Deputy].
///
/// [DeputyContext] serves as a contractual bridge between a Principal [Cell] and its
/// delegated agent. It codifies the "Mission" of the deputy, defining its [Clearance],
/// operational [role], and the [authority] granted by the principal.
///
/// ### When to use
/// You typically create a [DeputyContext] using one of the named factories:
/// - [DeputyContext.observer] – read‑only monitoring.
/// - [DeputyContext.delegate] – active state‑mutating task.
/// - [DeputyContext.sandbox] – speculative "what‑if" simulation.
/// - [DeputyContext.intervention] – emergency recovery.
/// - [DeputyContext.janitor] – resource cleanup.
/// - [DeputyContext.architect] – structural refactoring.
/// - [DeputyContext.auditor] – compliance auditing.
/// - [DeputyContext.ambassador] – cross‑domain communication.
/// - [DeputyContext.shielded] – secure enclave reasoning.
/// - [DeputyContext.gatekeeper] – policy enforcement.
/// - [DeputyContext.homeostasis] – background maintenance.
///
/// ### How it works
/// The context holds all the mandate dimensions (authority, clearance, isolation,
/// etc.) and is passed to [Cell.deputy] to create a restricted proxy. The deputy
/// shares the same state as the principal but applies these governance rules.
///
/// ### Non‑obvious
/// - Some dimensions are static (immutable) while others are evolvable – see
///   [Mandate] for details.
/// - The context supports prototype-based inheritance: if a dimension isn't set,
///   it's resolved from the parent context.
///
/// See also: [Mandate], [Cell.deputy], [DeputyContext.system].
/// {@category Advanced}
/// {@category Deputy Context}
class DeputyContext extends ContextBase {

  /// The canonical system context for deputies, providing safe defaults.
  static const system = _DeputyContextSystem();

  /// Initializes a **Formal Mandate** for a [Deputy], establishing the legal
  /// and operational boundaries granted by a Principal [Cell].
  ///
  /// ### When to use
  /// Use this constructor directly only when you need full control over all
  /// mandate dimensions. For common use cases, prefer the named factories.
  ///
  /// ### How it works
  /// It assembles the mandate dimensions from the provided parameters and
  /// links them to the [baseContext] via prototype‑based inheritance.
  ///
  /// ### Non‑obvious
  /// - The [authority] is required – there's no default.
  /// - The [role] is optional; if omitted, the deputy has no semantic identity.
  /// - The [clearance] defaults to `standard`, but you can override.
  ///
  /// ### Parameters:
  /// - [baseContext]: The parent [Context] providing the baseline lineage.
  /// - [authority]: The specific functional "Verb" permitted (e.g., 'UPDATE').
  /// - [role]: The semantic identity of the deputy (e.g., 'MAINTENANCE_BOT').
  /// - [isolation]: The virtualization level (defaults to [Isolation.scoped]).
  /// - [clearance]: The mutation rank (defaults to [Clearance.standard]).
  /// - [justification]: The semantic rationale for the delegation.
  /// - [constraints]: Machine-readable guardrails (e.g., max hop count).
  /// - [others]: Catch-all map for domain-specific telemetry.
  DeputyContext({
    required Context baseContext,
    required String authority,
    String? role,
    Isolation? isolation = Isolation.scoped,
    Clearance clearance = Clearance.standard, // Standard default,
    String? justification,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) : this.fromEntries(<GovernanceEntry>[
    Mandate.authority.entry(authority),
    if (role != null) Mandate.role.entry(role),
    if (isolation != null) Mandate.isolation.entry(isolation),
    if (clearance != Clearance.standard) Mandate.clearance.entry(clearance),
    if (justification != null) Mandate.justification.entry(justification),
    if (constraints != null) Mandate.constraints.entry(constraints),
  ], others: others, parent: baseContext);

  /// Synthesizes a **Delegated Governance Environment** from a collection of
  /// strongly-typed mandate entries.
  ///
  /// ### When to use
  /// This is the low‑level constructor used internally by the factories and
  /// by `evolve`. You rarely need it directly.
  ///
  /// ### How it works
  /// It takes a list of [GovernanceEntry] objects (typically from [Mandate])
  /// and builds a context record. If a [parent] is provided, it inherits from it.
  DeputyContext.fromEntries(super.entries, {super.others, super.parent});

  /// Synthesizes a **Read-Only Observation Mandate** for a [Deputy] intended
  /// for passive telemetry, auditing, and non-destructive monitoring.
  ///
  /// ### When to use
  /// Use this for UI observers, loggers, or any component that should only
  /// read state and never mutate it.
  ///
  /// ### How it works
  /// The factory sets the authority to `'OBSERVATION'` and the role to
  /// `'Observer'`. You can optionally set a [clearance] – use
  /// [Clearance.observational] for strict read‑only.
  ///
  /// ### Non‑obvious
  /// - The deputy is still reactive – changes to the principal are reflected.
  /// - Mutations are blocked at the integrity gate level.
  ///
  /// ### Example
  /// ```dart
  /// final uiObserver = DeputyContext.observer(
  ///   baseContext: context,
  ///   task: 'Render Dashboard',
  ///   clearance: Clearance.observational,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  /// - [task]: The specific observation mission (e.g., 'SYNC_METRICS').
  /// - [clearance]: The structural rank, defaulting to [Clearance.standard].
  ///
  /// See also: [Clearance.observational].
  factory DeputyContext.observer({
    required Context baseContext,
    required String task,
    Clearance clearance = Clearance.standard,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'OBSERVATION',
        role: 'Observer',
        clearance: clearance,
        others: {'task': task},
      );

  /// Synthesizes an **Operational Delegation Mandate** for a [Deputy]
  /// empowered to perform specific, state-mutating tasks on behalf of a
  /// Principal.
  ///
  /// ### When to use
  /// Use this for active agents that need to mutate state – e.g., maintenance
  /// tasks, user‑driven updates, or data transformation.
  ///
  /// ### How it works
  /// The factory sets the authority to `'DELEGATED_TASK'` and the role to
  /// `'Delegate'`. You provide a [task] description and optionally a
  /// [clearance] level.
  ///
  /// ### Non‑obvious
  /// - This is the standard mandate for most active deputies.
  /// - The [clearance] defaults to `standard` – raise to `administrative` for
  ///   structural changes.
  ///
  /// ### Example
  /// ```dart
  /// final janitor = DeputyContext.delegate(
  ///   baseContext: context,
  ///   task: 'PRUNE_EXPIRED_TOKENS',
  ///   clearance: Clearance.standard,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The authority source (Principal) granting the mandate.
  /// - [task]: A semantic description of the specific mission.
  /// - [clearance]: The formal [Clearance] level, defaulting to [Clearance.standard].
  ///
  /// See also: [Clearance].
  factory DeputyContext.delegate({
    required Context baseContext,
    required String task,
    Clearance clearance = Clearance.standard,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'DELEGATED_TASK',
        role: 'Delegate',
        clearance: clearance,
        others: {'task': task},
      );

  /// Creates an **Experimental Mandate** for a [Deputy] to perform simulated
  /// reasoning or speculative "What-if" analysis.
  ///
  /// ### When to use
  /// Use this for dry‑runs, A/B testing, or any exploration that shouldn't
  /// affect production state.
  ///
  /// ### How it works
  /// The factory sets [Isolation.sandboxed] to virtualize all mutations.
  /// Pulses from this deputy are never committed to the principal state.
  ///
  /// ### Non‑obvious
  /// - Even with high sovereignty, the sandbox prevents live mutation.
  /// - The clearance is set to `minimal` – only safe, idempotent operations.
  ///
  /// ### Example
  /// ```dart
  /// final strategist = DeputyContext.sandbox(
  ///   baseContext: context,
  ///   role: 'Profit_Projection_Model',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The authority source (Principal) granting the
  ///   simulated environment access.
  /// - [role]: The semantic identity of the sandbox, defaulting to 'Reasoning_Sandbox'.
  ///
  /// See also: [Isolation.sandboxed].
  factory DeputyContext.sandbox({
    required Context baseContext,
    String role = 'Reasoning_Sandbox',
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'SIMULATE',
        role: role,
        isolation: Isolation.sandboxed,
        clearance: Clearance.minimal,
      );

  /// Synthesizes an **Emergency Intervention Mandate** for a [Deputy] performing
  /// high-stakes system recovery, security shielding, or crisis mitigation.
  ///
  /// ### When to use
  /// Use this for high‑authority recovery operations – e.g., isolating a
  /// compromised node, shutting down a module, or forcing a state reset.
  ///
  /// ### How it works
  /// The factory sets [Clearance.administrative] and the role to `'Sentinel'`.
  /// The deputy can bypass standard constraints and perform structural changes.
  ///
  /// ### Non‑obvious
  /// - The mandate is reflexive – it's designed for immediate action.
  /// - The [reason] is mandatory and anchors the intervention in the causal trace.
  ///
  /// ### Example
  /// ```dart
  /// final sentinel = DeputyContext.intervention(
  ///   baseContext: context,
  ///   reason: 'Isolating compromised node #502',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  /// - [reason]: A machine-readable justification for the intervention.
  ///
  /// See also: [Clearance.administrative].
  factory DeputyContext.intervention({
    required Context baseContext,
    required String reason,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'SYSTEM_PROTECTION',
        role: 'Sentinel',
        clearance: Clearance.administrative,
        others: {'justification': reason, 'reflexive': true},
      );

  /// Synthesizes a **Structural Hygiene Mandate** for a [Deputy] managing
  /// resource cleanup, metabolic maintenance, and transient scene disposal.
  ///
  /// ### When to use
  /// Use this for background cleanup tasks – e.g., cache eviction, session
  /// cleanup, or synapse pruning.
  ///
  /// ### How it works
  /// The factory sets the authority to `'RESOURCE_MANAGEMENT'` and the role to
  /// `'Janitor'`. It grants [Clearance.administrative] by default to allow
  /// unlinking and deletion.
  ///
  /// ### Non‑obvious
  /// - The clearance is high to permit structural changes, but the scope is
  ///   limited to ephemeral targets.
  /// - The [target] helps identify the resource pool being cleaned.
  ///
  /// ### Example
  /// ```dart
  /// final cleaner = DeputyContext.janitor(
  ///   baseContext: context,
  ///   target: 'Telemetry_Buffer',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The authority source (Principal) granting the mandate.
  /// - [target]: The semantic description of the area being cleaned.
  /// - [clearance]: The structural rank, defaulting to [Clearance.administrative].
  ///
  /// See also: [Clearance.administrative].
  factory DeputyContext.janitor({
    required Context baseContext,
    required String target,
    Clearance clearance = Clearance.administrative,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'RESOURCE_MANAGEMENT',
        role: 'Janitor',
        clearance: clearance,
        others: {
          'target': target,
          'category': 'maintenance',
          'scope': 'ephemeral_only',
        },
      );

  /// Synthesizes an **Infrastructure Orchestration Blueprint** for a [Deputy]
  /// tasked with topology refactoring, resource scaling, or graph evolution.
  ///
  /// ### When to use
  /// Use this for structural changes – e.g., spawning new modules, merging
  /// collections, or re‑linking cells.
  ///
  /// ### How it works
  /// The factory sets the authority to `'INFRASTRUCTURE_EVOLUTION'` and the
  /// role to `'Architect'`. You provide a [mission] description and optional
  /// [clearance].
  ///
  /// ### Non‑obvious
  /// - The deputy can mutate the graph topology, but it's still governed by
  ///   the test rules.
  /// - The [mission] is recorded in the causal trace for auditing.
  ///
  /// ### Example
  /// ```dart
  /// final refactor = DeputyContext.architect(
  ///   baseContext: context,
  ///   mission: 'Scaling up the payment module',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The ancestral [Context] providing the baseline lineage.
  /// - [mission]: The functional justification for the refactor.
  /// - [clearance]: The structural rank, defaulting to [Clearance.standard].
  ///
  /// See also: [Clearance.standard].
  factory DeputyContext.architect({
    required Context baseContext,
    required String mission,
    Clearance clearance = Clearance.standard,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'INFRASTRUCTURE_EVOLUTION',
        role: 'Architect',
        clearance: clearance,
        others: {
          'mission_intent': mission,
          'evolution_type': 'structural_refactor',
        },
      );

  /// Synthesizes a **Compliance Witness Mandate** for a [Deputy] performing
  /// third-party auditing, integrity verification, or regulatory reporting.
  ///
  /// ### When to use
  /// Use this for compliance checks, security audits, or forensic analysis.
  ///
  /// ### How it works
  /// The factory sets [Clearance.observational] and the role to `'Witness'`.
  /// The authority is `'REGULATORY_AUDIT'`. It forces full audit logging.
  ///
  /// ### Non‑obvious
  /// - The deputy is read‑only – it cannot mutate state.
  /// - The audit level is forced to `full` for non‑repudiation.
  ///
  /// ### Example
  /// ```dart
  /// final auditor = DeputyContext.auditor(
  ///   baseContext: context,
  ///   regulation: 'SOC2',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  /// - [regulation]: A specific reference to the legal mandate or policy.
  ///
  /// See also: [Clearance.observational].
  factory DeputyContext.auditor({
    required Context baseContext,
    required String regulation,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'REGULATORY_AUDIT',
        role: 'Witness',
        clearance: Clearance.observational,
        others: {
          'target_regulation': regulation,
          'force_audit': 'full',
          'observational_only': true,
        },
      );

  /// Synthesizes a **Protocol Negotiator Mandate** for a [Deputy]
  /// communicating across different **System** or **Host** boundaries.
  ///
  /// ### When to use
  /// Use this for API gateways, cross‑host sync, or protocol adaptation.
  ///
  /// ### How it works
  /// The factory sets the authority to `'CROSS_DOMAIN_COMMUNICATION'` and
  /// the role to `'Ambassador'`. The clearance is `minimal` to prevent
  /// unwanted mutations across boundaries.
  ///
  /// ### Non‑obvious
  /// - The deputy can translate internal state to external formats.
  /// - It cannot emit structural changes in the foreign system.
  ///
  /// ### Example
  /// ```dart
  /// final gateway = DeputyContext.ambassador(
  ///   baseContext: context,
  ///   targetDomain: 'Partner_API',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  /// - [targetDomain]: The identifier of the external system.
  ///
  /// See also: [Clearance.minimal].
  factory DeputyContext.ambassador({
    required Context baseContext,
    required String targetDomain,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'CROSS_DOMAIN_COMMUNICATION',
        role: 'Ambassador',
        clearance: Clearance.minimal,
        others: {
          'external_domain': targetDomain,
          'permeability': 'selective',
          'translation_required': true,
        },
      );

  /// Synthesizes a **Shielded Logic Mandate** for a [Deputy] performing
  /// sensitive autonomous decisions in an isolated environment.
  ///
  /// ### When to use
  /// Use this for high‑security reasoning – e.g., cryptographic signing,
  /// PII processing, or security policy evolution.
  ///
  /// ### How it works
  /// The factory sets [Clearance.administrative] and the role to `'Sentinel'`.
  /// The deputy operates in a secure enclave with strict isolation.
  ///
  /// ### Non‑obvious
  /// - The deputy is isolated from the main reactive graph.
  /// - It can perform privileged mutations but is limited to the enclave.
  ///
  /// ### Example
  /// ```dart
  /// final enclave = DeputyContext.shielded(
  ///   baseContext: context,
  ///   reason: 'Processing payment keys',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  /// - [reason]: A semantic justification for the isolation.
  ///
  /// See also: [Clearance.administrative].
  factory DeputyContext.shielded({
    required Context baseContext,
    required String reason,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'SECURE_REASONING',
        role: 'Sentinel',
        clearance: Clearance.administrative,
        others: {
          'justification': reason,
          'isolated': true,
          'enclave_type': 'privileged_logic',
        },
      );

  /// Synthesizes a **Governance Enforcement Mandate** for a [Deputy]
  /// specialized in validating other mandates and enforcing structural laws.
  ///
  /// ### When to use
  /// Use this for policy enforcement points – e.g., rate limiters, schema
  /// validators, or ingress filters.
  ///
  /// ### How it works
  /// The factory sets the authority to `'GOVERNANCE_ENFORCEMENT'` and the
  /// role to `'Gatekeeper'`. It uses [Clearance.observational] to ensure it
  /// can block signals but not mutate state.
  ///
  /// ### Non‑obvious
  /// - The deputy can intercept and block pulses.
  /// - It cannot change the underlying state – it's strictly a firewall.
  ///
  /// ### Example
  /// ```dart
  /// final gate = DeputyContext.gatekeeper(
  ///   baseContext: context,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  ///
  /// See also: [Clearance.observational].
  factory DeputyContext.gatekeeper({
    required Context baseContext,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'GOVERNANCE_ENFORCEMENT',
        role: 'Gatekeeper',
        clearance: Clearance.observational,
        others: const {
          'force_audit': 'full',
          'enforcement_type': 'policy_guardrail',
        },
      );

  /// Synthesizes a **Metabolic Homeostasis Mandate** for a [Deputy] managing
  /// the health, resource allocation, and background stability of the
  /// **Switching Fabric**.
  ///
  /// ### When to use
  /// Use this for background system daemons – e.g., memory reclamation,
  /// lease enforcement, or topology optimisation.
  ///
  /// ### How it works
  /// The factory sets the authority to `'SYSTEM_MAINTENANCE'` and the role to
  /// `'Service_Daemon'`. The clearance is `standard` – it can perform routine
  /// maintenance but not structural refactoring.
  ///
  /// ### Non‑obvious
  /// - This is a background task with low priority.
  /// - It can prune ephemeral nodes but not static pillars.
  ///
  /// ### Example
  /// ```dart
  /// final daemon = DeputyContext.homeostasis(
  ///   baseContext: context,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The Principal [Context] providing the ancestral lineage.
  ///
  /// See also: [Clearance.standard].
  factory DeputyContext.homeostasis({
    required Context baseContext,
  }) =>
      DeputyContext(
        baseContext: baseContext,
        authority: 'SYSTEM_MAINTENANCE',
        role: 'Service_Daemon',
        clearance: Clearance.standard,
        others: {
          'scope': 'infrastructure',
          'category': 'metabolic',
          'priority': 'background',
        },
      );

  /// Synthesizes a **Specialized Mission Extension** by resolving the fluid
  /// dimensions of the [Mandate] pillars.
  ///
  /// This method implements **Mandate Specialization** for delegated
  /// authority. It allows a [Deputy] to refine its operational boundaries
  /// (such as tightening [Clearance] or updating [constraints]) while
  /// ensuring that the core authority granted by the Principal remains
  /// immutable and verifiable.
  ///
  /// ### When to use
  /// Use this when you need to narrow a mandate for a sub‑task – e.g., a
  /// general delegate spawning a read‑only janitor.
  ///
  /// ### How it works
  /// You provide a resolver that returns new [GovernanceEntry]s for evolvable
  /// dimensions. Static pillars are inherited unchanged. The new context
  /// links back to `this` as its parent.
  ///
  /// ### Non‑obvious
  /// - You cannot change static pillars (like [role]) – they're immutable.
  /// - The new context is a separate record; the original remains unchanged.
  ///
  /// ### Example
  /// ```dart
  /// final janitorMission = currentDeputy.evolve((evolvable) {
  ///   return switch (evolvable) {
  ///     Mandate.clearance => Clearance.observational.entry(),
  ///     Mandate.role => 'System_Cleanup_Task'.entry(),
  ///     Mandate.constraints => {'target_collection': 'tmp_cache'}.entry(),
  ///     _ => null, // Inherit remaining pillars
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
  /// A new [DeputyContext] with refined fluid boundaries.
  ///
  /// See also: [Mandate.evolve].
  @override
  DeputyContext evolve(covariant GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others}) {
    final entries = <GovernanceEntry>[...Ontology.evolve(resolver), ...Mandate.evolve(resolver)];
    return DeputyContext.fromEntries(entries, others: others, parent: this);
  }

  String? get role => get<String?>(
        () => _record.map[Mandate.role] ?? (_parent is DeputyContext ? (_parent as DeputyContext).role : null),
    orElse: null,
  );

  Isolation get isolation => get<Isolation>(
        () => _record.map[Mandate.isolation] ?? (_parent is DeputyContext ? (_parent as DeputyContext).isolation : null),
    orElse: Isolation.scoped,
  );

  Sovereignty get sovereignty => get<Sovereignty>(
        () => _record.map[Mandate.sovereignty] ?? (_parent is DeputyContext ? (_parent as DeputyContext).sovereignty : null),
    orElse: Sovereignty.sovereign,
  );

  Clearance get clearance => get<Clearance>(
        () => _record.map[Mandate.clearance] ?? (_parent is DeputyContext ? (_parent as DeputyContext).clearance : null),
    orElse: Clearance.standard,
  );

  AuditLevel get auditLevel => get<AuditLevel>(
        () => _record.map[Mandate.auditLevel] ?? (_parent is DeputyContext ? (_parent as DeputyContext).auditLevel : null),
    orElse: AuditLevel.standard,
  );

  String? get justification => get<String?>(
        () => _record.map[Mandate.justification] ?? (_parent is DeputyContext ? (_parent as DeputyContext).justification : null),
    orElse: null,
  );

  @override
  Map<String, dynamic>? get constraints => get<Map<String, dynamic>?>(
        () => _record.map[Mandate.constraints] ?? (_parent is DeputyContext ? (_parent as DeputyContext).constraints : null),
    orElse: null,
  );

}

/// Defines the **Sovereign Physical Laws** and structural boundaries of
/// reactive operations within the framework.
///
/// [Clearance] serves as the fundamental **Authorization Tier** for the
/// **Reciprocal Handshake** (Bidirectional Mutual Authorization) protocol.
/// It dictates the **Execution Perimeter** and logical boundaries of what an
/// autonomous agent (a **Managed Node**) is permitted to perform within a
/// specific cell or across the systemic topology.
///
/// ### When to use
/// Use this to control the severity of allowed operations. Higher clearance
/// means more powerful mutations.
///
/// ### How it works
/// Clearance is a ranked integer. The framework compares the deputy's
/// clearance against the required level for an operation. If it's lower,
/// the pulse is neutralised.
///
/// ### Non‑obvious
/// - The comparison is `incoming.level >= required.level`.
/// - `observational` is the lowest, `unrestricted` is the highest.
/// - This is an evolvable dimension – a deputy can downgrade clearance for
///   child tasks.
///
/// ### Levels
/// - `observational (0)`: read‑only.
/// - `minimal (1)`: safe mutations within a cell.
/// - `standard (2)`: default operational tier.
/// - `administrative (3)`: structural refactoring.
/// - `privileged (4)`: cross‑domain topology changes.
/// - `unrestricted (5)`: absolute authority.
///
/// See also: [Mandate.clearance].
enum Clearance {

  /// **Level 0: Observational (The Spectator)**
  /// The lowest tier. Allows for read-only access to public state and
  /// telemetry. This agent can perceive but cannot influence the state
  /// or topology.
  observational(0),

  /// **Level 1: Minimal (The Contributor)**
  /// Allows for state mutations within a single [Cell] that do not delete
  /// data. Suitable for leaf-node logic and local reasoning.
  minimal(1),

  /// **Level 2: Standard (The Resident)**
  /// The default operational tier. Allows for standard state updates and
  /// the broadcasting of new pulses to adjacent receptors within a module.
  standard(2),

  /// **Level 3: Administrative (The Overseer)**
  /// Grants the power to perform **Structural Refactoring**. This includes
  /// attaching new receptors, spawning child cells, or modifying the
  /// routing tables of a local **Collection**.
  administrative(3),

  /// **Level 4: Privileged (The Architect)**
  /// Allows for cross-domain topology changes and the modification of
  /// **Integrity Gates**. This tier is reserved for systemic evolution
  /// and high-level orchestration.
  privileged(4),

  /// **Level 5: Unrestricted (The Sovereign)**
  /// Absolute authority. Can override any [Mandate.constraints], bypass
  /// isolation, and decommission core infrastructure. This represents
  /// the root system authority or the **Principal Agent**.
  unrestricted(5);

  /// The integer representation of the authorization tier used for
  /// comparison in **Integrity Gates**.
  final int level;

  const Clearance(this.level);

  /// Returns `true` if this clearance level meets or exceeds the [required]
  /// threshold.
  bool authorizes(Clearance required) => level >= required.level;
}

/// Defines the **Architectural Boundary & State Visibility** of a [Deputy].
///
/// **Isolation** levels determine the "Blast Radius" of a deputy's operations.
/// They define how a deputy's actions affect the primary reactive graph and
/// whether its state transitions are virtualized, shadowed, or physically
/// partitioned from the core **Digital Organism**.
///
/// In the framework's **Capability-Based Access Control (CBAC)** model, isolation
/// is the primary mechanism for **Safety-Critical Sandboxing**. It allows
/// **Managed Nodes** (autonomous agents) to evaluate hypothetical logic
/// transformations during the **Reactive Update Cycle** without compromising
/// the production **Source of Truth**.
///
/// ### When to use
/// Choose the isolation level based on how much impact the deputy should have:
/// - `shared` for live, direct execution.
/// - `scoped` for restricted domains.
/// - `restricted` for zero‑trust filtering.
/// - `sandboxed` for safe simulation.
/// - `total` for air‑gapped observation.
///
/// ### How it works
/// The isolation level determines where pulses are executed and whether
/// they affect the principal state.
///
/// ### Non‑obvious
/// - `sandboxed` mutations are not committed to the principal state.
/// - `restricted` pulses go through extra governance filtering.
/// - This is an evolvable dimension – a deputy can tighten isolation.
///
/// See also: [Mandate.isolation].
enum Isolation {
  /// **Level 0: Direct Execution (Shared)**
  /// The deputy operates directly on the principal's state context.
  /// Transitions are "Live" and immediately visible to the graph. This level
  /// provides peak performance but requires strict **Integrity Gate**
  /// ([TestCell]) oversight to maintain systemic invariants.
  shared,

  /// **Level 1: Domain Isolation (Scoped)**
  /// The deputy is restricted to a specific [Ontology] domain or subset of fields.
  /// Mutations are live but physically constrained to prevent **Contextual Bleed**
  /// into unrelated system nodes.
  scoped,

  /// **Level 2: Zero-Trust Communication (Restricted)**
  /// Similar to [scoped], but every pulse generated by the deputy is
  /// intercepted and subjected to mandatory **Governance Filtering**.
  /// This ensures that **Causal Provenance** is verified at every step of
  /// the **Reactive Update Cycle**.
  restricted,

  /// **Level 3: Virtualized Execution (Sandboxed)**
  /// The deputy operates on a "Projection" or "Clone-on-Write" layer.
  /// Transformations are virtualized and do not affect the production state.
  ///
  /// For **Managed Nodes**, this provides a **Reasoning Playground**
  /// to evaluate multiple trajectories before committing to an optimal path.
  sandboxed,

  /// **Level 4: Logical Air-Gap (Total)**
  /// The deputy is completely decoupled. While it can ingest system state during
  /// the **Ingress Phase**, it is physically prevented from emitting signals
  /// that reach the global distribution graph. Used for analytical observers
  /// and isolated internal reasoning within a **Secure Enclave**.
  total;

  /// Returns `true` if the isolation level prevents live state mutations,
  /// requiring a virtualized or projection-based execution layer.
  bool get isVirtual => index >= Isolation.sandboxed.index;

  /// Returns `true` if the isolation requires strict per-pulse message
  /// filtering to maintain systemic integrity.
  bool get isGuarded => index == Isolation.restricted.index;
}

/// Defines the **Commitment Authority** and **Escalation Protocol**
/// assigned to a [Deputy].
///
/// Within the framework's **Capability-Based Access Control (CBAC)** model,
/// these tiers govern the **Reactive Update Cycle**. They define whether a
/// **Logic Transformation** (resulting from an agent's internal reasoning)
/// can be committed to the state graph automatically or if it must remain
/// a **Staged Mutation** pending administrative approval or
/// **Reciprocal Handshake** validation.
///
/// ### When to use
/// Choose the sovereignty level based on how much autonomy the deputy needs:
/// - `supervised` for proposals that require approval.
/// - `collaborative` for mixed autonomy.
/// - `sovereign` for full independence.
/// - `preemptive` for emergency overrides.
///
/// ### How it works
/// Sovereignty determines if a pulse is queued for approval or executed
/// immediately. High‑impact actions may be blocked even if the deputy is
/// sovereign, depending on cell rules.
///
/// ### Non‑obvious
/// - `supervised` pulses are held in a pending state until approval.
/// - `preemptive` can cancel other pulses.
/// - This is evolvable – a deputy can be promoted or demoted.
///
/// See also: [Mandate.sovereignty].
enum Sovereignty {
  /// **Level 0: Supervised.**
  /// The Deputy acts as a "Proposal Engine." Every generated [Pulse] is
  /// intercepted and requires explicit approval (manual or automated)
  /// by the Principal before committing to the state layer.
  ///
  /// This level is used for **High-Risk Reasoning** or training phases
  /// where the **Causal Provenance** must be verified by a higher authority.
  supervised,

  /// **Level 1: Collaborative.**
  /// The Deputy can mutate non-critical state independently but must
  /// pause and request authorization for high-impact transitions or
  /// operations that cross significant [Clearance] boundaries.
  ///
  /// This implements a "Human-in-the-loop" or "Orchestrator-in-the-loop"
  /// safety pattern.
  collaborative,

  /// **Level 2: Sovereign.**
  /// The Deputy is fully authorized to commit changes within its
  /// [Clearance] and [Mandate.authority] without real-time oversight.
  ///
  /// This represents a **Sovereign Resident** agent operating autonomously
  /// under the constraints of **System Law** (enforced via [TestCell]).
  sovereign,

  /// **Level 3: Preemptive.**
  /// Reserved for safety, homeostasis, or emergency recovery agents.
  /// A preemptive Deputy can override or cancel other active pulses
  /// to maintain system stability.
  ///
  /// These agents operate at the highest tier of the **Scene-Driven Ontology**,
  /// prioritizing system integrity over standard business logic.
  preemptive;

  /// Returns `true` if the deputy requires external validation or
  /// approval before its actions can affect the reactive graph.
  bool get requiresApproval => index <= Sovereignty.supervised.index;

  /// Returns `true` if the deputy has high-authority override capabilities
  /// to maintain system homeostasis.
  bool get isPreemptive => index == Sovereignty.preemptive.index;
}

/// Defines the **Observability Granularity** and **XAI Verbosity**
/// required for a [Deputy]'s operations.
///
/// Within the governance framework, audit levels determine the density of the
/// causal trace and the detail required for **Explainable AI (XAI)**
/// justifications. High-level auditing ensures that the **Causal Provenance**
/// is sufficiently documented to satisfy **System Law** ([TestCell]) requirements.
///
/// ### When to use
/// Choose the audit level based on forensic needs:
/// - `none` for high‑frequency telemetry.
/// - `minimal` for basic error logging.
/// - `standard` for general operations.
/// - `detailed` for XAI and debugging.
/// - `full` for compliance and forensics.
///
/// ### How it works
/// The audit level controls how much trace data is preserved. Higher levels
/// capture more metadata, which can impact performance.
///
/// ### Non‑obvious
/// - Some high‑integrity cells reject pulses with low audit levels.
/// - This is evolvable – a supervisor can increase audit rigour.
///
/// See also: [Mandate.auditLevel].
enum AuditLevel {
  /// **Level 0: None.**
  /// No logs or traces are generated. Used for high-frequency, non-critical
  /// pulses where performance is the absolute priority and historical
  /// reconstruction is unnecessary.
  none,

  /// **Level 1: Minimal.**
  /// Only final outcomes and critical errors are recorded. Suitable for
  /// stable, low-risk background tasks where basic failure monitoring
  /// is sufficient.
  minimal,

  /// **Level 2: Standard.**
  /// Records principal state changes and their immediate reasons. The default
  /// level for general application logic, providing a balance between
  /// performance and **Causal Provenance**.
  standard,

  /// **Level 3: Detailed.**
  /// Captures intermediate reasoning steps and metadata. Provides the
  /// necessary depth for **Explainable AI (XAI)**, allowing agents to
  /// provide a clear rationale for their state transitions.
  detailed,

  /// **Level 4: Full Trace.**
  /// Exhaustive logging of every micro-transition, internal monologue,
  /// and gate evaluation. Used for forensics, security audits, and
  /// debugging complex **Sovereign Resident** (AI) behavior.
  full;

  /// Returns `true` if the level requires high-fidelity XAI metadata to
  /// support deep reasoning and justification.
  bool get requiresDeepReasoning => index >= AuditLevel.detailed.index;

  /// Returns `true` if auditing is completely disabled to maximize performance.
  bool get isSilent => this == AuditLevel.none;
}


/// Defines the **Logical Pedigree** and algorithmic origin of a [Pulse].
///
/// **Reasoning Strategy** allows the framework to categorize signals based on
/// the reliability, methodology, and nature of the intelligence that produced
/// them. This classification is essential for the **Causal Provenance** pillar,
/// as it documents the "Why" behind a state transition.
///
/// Within the framework's **Capability-Based Access Control (CBAC)** model,
/// this enum facilitates **Automated Trust Resolution**. During the
/// **Reactive Update Cycle**, an **Integrity Gate** ([TestCell])
/// evaluates the strategy to determine if a signal requires a supplemental
/// **Authorization Challenge** (e.g., manual approval for [probabilistic]
/// results) or if it satisfies the criteria for an **Autonomous Commitment**.
///
/// ### When to use
/// Attach this to a pulse when you need to indicate the reasoning method used,
/// especially for AI‑generated signals.
///
/// ### How it works
/// The framework uses the strategy to determine trust levels. For example,
/// `probabilistic` signals may require confidence checks.
///
/// ### Non‑obvious
/// - `stochastic` signals are treated as hypothetical – they don't commit.
/// - `deterministic` and `reflexive` are considered system‑mandated.
///
/// See also: [PulseContext.strategy].
enum ReasoningStrategy {

  /// **Manual Intervention.**
  /// The pulse was initiated by a human actor via direct interaction. These
  /// pulses carry high subjective authority but are subject to human error.
  ///
  /// *Example:* A user clicking a "Delete" button in a UI or an administrator
  /// issuing a `force-reset` command via CLI.
  manual,

  /// **Deterministic Logic.**
  /// The pulse was generated by hard-coded business rules, safety
  /// heuristics, or physical constraints. These signals represent the
  /// "Physics of the System" and are considered highly reliable.
  ///
  /// *Example:* A counter incrementing by 1, a value being clamped to
  /// a range, or a simple `if-then` validation rule.
  deterministic,

  /// **Probabilistic Inference.**
  /// The pulse was generated by a Large Language Model (LLM), a neural
  /// network, or a stochastic process.
  ///
  /// These signals are treated as "Informed Guesses." They typically require
  /// a [Provenance.confidence] assessment and may emit a
  /// [Sovereignty.supervised] check before affecting critical state.
  probabilistic,

  /// **Stochastic Exploration.**
  /// The pulse was generated through a randomized, sampling-based, or
  /// exploratory process. This strategy explicitly seeks to explore the
  /// **State Possibility Space** rather than identifying a singular
  /// deterministic outcome.
  ///
  /// Unlike [ReasoningStrategy.probabilistic] reasoning—which attempts to
  /// identify the most likely state—this strategy explores the breadth of
  /// potential trajectories.
  ///
  /// *Example:* A Monte Carlo simulation of system loads or high-temperature
  /// generative text synthesis from an AI agent.
  stochastic,

  /// **Formal Verification.**
  /// The pulse is the result of a formal solver, symbolic logic engine,
  /// or theorem prover that has mathematically guaranteed the transition.
  /// For **Sovereign Resident** agents, this provides a "Certified Fact."
  ///
  /// *Example:* A Z3 solver proof ensuring a memory allocation is safe or
  /// a symbolic logic check that a state transition violates no safety laws.
  formal,

  /// **Reflexive Response.**
  /// An automated, low-latency reaction to a specific stimulus, analogous
  /// to a biological reflex. Reflexive strategies prioritize system
  /// homeostasis over complex reasoning.
  ///
  /// *Example:* A circuit-breaker tripping due to a signal overflow or an
  /// emergency shutdown emitted by a critical battery level.
  reflexive;

  /// Returns `true` if the strategy involves uncertainty, heuristic inference,
  /// or stochastic modeling that may require confidence-based validation.
  bool get isStochastic => this == ReasoningStrategy.stochastic;

  /// Returns `true` if the strategy represents a hard-coded, verifiable
  /// system rule or immediate safety protocol.
  bool get isSystemMandated =>
      this == ReasoningStrategy.deterministic ||
          this == ReasoningStrategy.reflexive;

  /// Returns `true` if the reasoning was produced by an external or
  /// non-deterministic agent (Human or AI).
  bool get isAgentic =>
      this == ReasoningStrategy.manual || this == ReasoningStrategy.probabilistic;
}

/// Defines the **Semantic Urgency Tiers** for signal execution.
///
/// In a reactive ecosystem, [PriorityTier] allows the framework and
/// **Sovereign Resident** (AI) agents to categorize the importance of a [Pulse]
/// relative to the system's current operational load.
///
/// Used by [Provenance.priority] to influence the scheduling and processing
/// order within the distribution network. This ensures that safety protocols
/// and emergency overrides transcend routine telemetry or background
/// optimizations.
///
/// ### When to use
/// Set the priority of a pulse to control its execution order. Higher priority
/// pulses leapfrog lower priority ones.
///
/// ### How it works
/// The dispatcher uses the numeric priority to order pulses. The default is
/// `routine` (21‑50).
///
/// ### Non‑obvious
/// - Emergency pulses (96‑100) are processed before anything else.
/// - Background pulses (0‑20) are only processed when resources are available.
///
/// See also: [Provenance.priority].
enum PriorityTier {
  /// **0 - 20: Background.**
  /// Low-priority maintenance, non-critical telemetry, or deferred
  /// cleanup tasks. These pulses are processed only when the system
  /// has surplus resources and is under low load.
  background,

  /// **21 - 50: Routine.**
  /// Standard operational pulses, standard user interactions, and
  /// routine state synchronizations. This is the default tier for
  /// most **Digital Organism** activity.
  routine,

  /// **51 - 80: High.**
  /// Time-sensitive operations or direct user-requested commands
  /// requiring immediate visual feedback or low-latency reasoning.
  high,

  /// **81 - 95: Critical.**
  /// System-critical transitions, safety protocols, or high-stakes
  /// autonomous optimizations. These pulses typically bypass standard
  /// processing queues to ensure immediate execution.
  critical,

  /// **96 - 100: Emergency.**
  /// Reserved for catastrophic failure recovery, security lockdowns,
  /// or preemptive overrides. These pulses take absolute precedence
  /// over all other system activity to maintain homeostasis.
  emergency;

  /// Maps a raw integer priority (0-100) to a semantic [PriorityTier].
  ///
  /// This utility allows for a granular numeric priority to be mapped back
  /// into a broad governance category for policy enforcement by
  /// **Integrity Gates** ([TestCell]).
  static PriorityTier fromValue(int value) {
    if (value >= 96) return emergency;
    if (value >= 81) return critical;
    if (value >= 51) return high;
    if (value >= 21) return routine;
    return background;
  }

  /// Returns `true` if this tier represents an urgent system intervention
  /// that should potentially bypass standard reactive debouncing or queues.
  bool get isUrgent => index >= PriorityTier.critical.index;
}

/// Defines the **Information Classification** and data-privacy tier of a [Pulse].
///
/// Sensitivity levels determine the encryption requirements, redaction policies,
/// and visibility of the [Pulse.payload] across different [Isolation] levels.
///
/// Within the framework's **Capability-Based Access Control (CBAC)** model,
/// this enum enables **Automated Compliance Enforcement**.
///
/// During the **Reactive Update Cycle**, a **Managed Node** or
/// **Integrity Gate ([TestCell])** utilizes the sensitivity tier to
/// determine if a specific agent possesses the required [Clearance] to
/// authorize the signal's **Ingress** or to perform a state mutation during
/// the **Transformation Phase**.
///
/// ### When to use
/// Attach a sensitivity level to a pulse to indicate its data classification.
/// This helps enforce privacy and compliance rules.
///
/// ### How it works
/// The framework uses sensitivity to determine redaction, encryption, and
/// access control. Higher sensitivity requires higher clearance.
///
/// ### Non‑obvious
/// - `restricted` and `secret` emit automatic redaction in logs.
/// - Some cells reject pulses with insufficient sensitivity clearance.
///
/// See also: [PulseContext.sensitivity].
enum Sensitivity {
  /// **Level 0: Public.**
  /// Non-sensitive data that can be safely logged, cached, and transmitted
  /// across unencrypted channels.
  ///
  /// *Example:* App version numbers, current theme name, or public constants.
  public,

  /// **Level 1: Internal.**
  /// Data intended for system-wide use but not for external exposure. Restricted
  /// from egress to external third-party adapters.
  ///
  /// *Example:* System-wide telemetry, cell topology metadata, or heartbeat signals.
  internal,

  /// **Level 2: Private.**
  /// Data restricted to the local **Sovereign Resident** or the immediate
  /// cell cluster. Never broadcast across public synapses.
  ///
  /// *Example:* An agent's local scratchpad, internal monologue, or local loop counters.
  private,

  /// **Level 3: Confidential.**
  /// Sensitive operational data requiring standard encryption at rest. Typically
  /// masked in low-level audit logs.
  ///
  /// *Example:* Feature flags, internal resource URIs, or obfuscated user IDs.
  confidential,

  /// **Level 4: Restricted.**
  /// Highly sensitive data, including PII (Personally Identifiable Information).
  /// Never logged in plaintext.
  ///
  /// *Example:* User email addresses, physical geolocation, or billing history.
  restricted,

  /// **Level 5: Secret.**
  /// The highest tier of confidentiality. Restricted to [Isolation.sandboxed]
  /// or [Isolation.total] environments to prevent leakage.
  ///
  /// *Example:* Private cryptographic keys, OAuth tokens, or administrative passwords.
  secret;

  /// Returns `true` if the data requires proactive masking or redaction
  /// within [AuditLevel.standard] logs.
  bool get requiresMasking => index >= Sensitivity.confidential.index;

  /// Returns `true` if the data carries significant legal or security risk,
  /// requiring elevated [Clearance] for any mutation.
  bool get isHighRisk => index >= Sensitivity.restricted.index;

}