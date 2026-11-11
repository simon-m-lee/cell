// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// The immutable blueprint underlying every [Cell] — its [receptor],
/// [testRule], [context], [synapses], and lifecycle policy, stored
/// separately from the live cell instance.
///
/// **You will almost never construct or reference this directly.** Every
/// `Cell.*` factory builds one internally from the parameters you already
/// pass it. This class exists so that behavior (the nucleus) can be
/// shared, cloned, and specialized independently of state — which is what
/// makes [Cell.deputy] cheap: a deputy is a new nucleus pointing back at
/// its principal, not a duplicated cell.
///
/// ### The one thing worth knowing
/// A nucleus can have a [principal] — an ancestor it falls back to for any
/// property it doesn't define locally. This is why a deputy created with
/// only a narrower [TestCell] still has the same [receptor] and [context]
/// as the cell it was made from: it didn't copy them, it inherits them by
/// walking up to [principal] on each lookup.
///
/// ### If you do need this directly
/// [Nucleus.create] and [Nucleus.evolve] are the entry points for
/// building custom cell types or framework-level tooling — not for
/// typical application code. If you find yourself reaching for these,
/// double-check whether [Cell.governed] or [Cell.deputy] already covers
/// what you need.
///
/// See also: [Cell.fromNucleus] (how a nucleus becomes a live cell),
/// [Cell.deputy] (the common, higher-level way this class gets used).
/// {@category Advanced}
/// {@category Nucleus}
abstract interface class Nucleus {
  /// The primary factory constructor for [Nucleus], which initializes a
  /// memory-optimized, tiered configuration for a reactive [Cell].
  ///
  /// ### When to use
  /// Only if you are building custom infrastructure that needs to define
  /// a cell's behavior from scratch. For most cases, use the higher‑level
  /// `Cell` factories.
  ///
  /// ### How it works
  /// All parameters are optional and default to framework standards.
  /// The constructor uses bitmasking to store only non‑default values,
  /// making it memory‑efficient.
  ///
  /// ### Parameters:
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines when the node
  ///   should be automatically neutralized and purged.
  /// - [bind]: **Ingress Link.** Establishes a dependency on an upstream [Cell].
  /// - [context]: **Operational Authority.** Defines the priority and semantic
  ///   domain of the node. Defaults to [Context.system].
  /// - [receptor]: **Transformation Pipeline.** The logic used to process
  ///   incoming [Pulse] signals.
  /// - [testRule]: **Integrity Gate.** Validation rules that act as a gate
  ///   for all state modifications. Defaults to [TestCell.allowAll].
  /// - [synapses]: **Egress Network.** Manages the connectivity and
  ///   distribution of signals to downstream observers.
  /// - [forceLock]: **Atomic Isolation.** If true, forces the allocation of
  ///   a unique [Lock], establishing a sovereign **Atomic Domain** isolated
  ///   from principal inheritance.
  /// - [user]: **Extension Metadata.** An optional record for domain-specific
  ///   properties kept separate from framework logic.
  factory Nucleus({
    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context context,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,
    bool forceLock,
    Record? user,
  }) = _Nucleus;

  /// Creates a specialized **Architectural Extension** of an existing [Nucleus] to
  /// support hierarchical property inheritance and contextual overrides.
  ///
  /// This factory constructor is the primary implementation of the **Prototype-based
  /// Inheritance** pattern (specifically the **Deputy-Principal Relationship**) within
  /// the framework. In its biological meta-language, [evolve] performs a directed
  /// **Genetic Mutation**, creating a descendant (Deputy) that inherits the
  /// foundational "DNA" of this nucleus (Principal) while layering on its own
  /// specific operational traits.
  ///
  /// ### When to use
  /// - **Specialization**: Creating a cell that shares the same [Context] and
  ///   [Receptor] but requires a stricter [TestCell] integrity gate.
  /// - **Contextual Shifting**: Moving a node to a different [Context] (e.g.,
  ///   from `module` to `system`) without redefining its transformation logic.
  /// - **Lifecycle Tuning**: Overriding an [EphemeralPolicy] to change the
  ///   TTL of a specific branch in the reactive graph.
  ///
  /// ### How it works
  /// The constructor utilizes a **Tiered Resolution Hierarchy** to determine the
  /// final state of any property:
  /// 1. **Local Override**: Values explicitly passed to this method.
  /// 2. **Prototype Inheritance**: Values inherited from the [principal].
  /// 3. **Causal Binding**: Values derived from the upstream [bind] dependency.
  /// 4. **Global Default**: Framework-level constants (e.g., [Context.system]).
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The source [Nucleus] from which this instance
  ///   derives its structural and logic inheritance.
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines when the node
  ///   should be automatically neutralized. Resolves from [principal] if null.
  /// - [bind]: **Ingress Link.** A [Cell] dependency. Note: bindings are
  ///   instance-specific and are **not** inherited from the [principal].
  /// - [context]: **Execution Environment.** Defines the security tier and
  ///   priority. Resolves from [principal] if null.
  /// - [receptor]: **Transformation Pipeline.** The logic used to process
  ///   incoming signals. Resolves from [principal] if null.
  /// - [testRule]: **Integrity Gate.** Validation rules that guard state
  ///   modifications. Resolves from [principal] if null.
  /// - [synapses]: **Signal Distribution.** Manages egress connectivity.
  ///   Resolves from [principal] if null.
  /// - [user]: **Extension Metadata.** An optional record for domain-specific
  ///   properties kept separate from framework logic.
  /// - [override]: Optional. A pre-compiled [Nucleus] whose internal record
  ///   will be adopted directly.
  factory Nucleus.evolve(Nucleus principal,
      {EphemeralPolicy? ephemeralPolicy,
      Cell? bind,
      Context? context,
      Receptor? receptor,
      TestCell? testRule,
      Synapses? synapses,
      Record? user,
      Nucleus? override}) {
    return _Nucleus.fromRecord((
      local: override != null
          ? (override as NucleusBase).record.local
          : NucleusBase.mask(
              bind: bind,
              context: context,
              receptor: receptor,
              testRule: testRule,
              synapses: synapses,
              user: user,
              ephemeralPolicy: ephemeralPolicy,
            ),
      principal: principal,
    ));
  }

  /// Creates a primary, immutable, and completely empty [Nucleus] instance.
  ///
  /// This `const` factory constructor represents the "Zero State" of the
  /// framework's property system. It returns a specialized, lightweight
  /// implementation that contains no local overrides, metadata, or principal links.
  ///
  /// ### When to use
  /// You never call this directly – the framework uses it internally as the
  /// root of the inheritance chain.
  ///
  /// ### Returns:
  /// A `const` [Nucleus] instance configured with global framework defaults.
  factory Nucleus.empty() => Nucleolus._singleton;

  /// A versatile static factory for creating a [Nucleus] configuration, serving
  /// as the architectural **Blueprint** for a [Cell] of type [C].
  ///
  /// This method is the primary entry point for defining the behavioral,
  /// security, and operational constraints of a reactive node. It supports
  /// the creation of both standalone "Root" property sets and specialized
  /// "Extended" sets that inherit from an existing [principal].
  ///
  /// ### When to use
  /// This is an advanced entry point for custom cell types. Most developers
  /// should use [Cell] or [ValueCell] factories.
  ///
  /// ### How it works
  /// You provide a set of parameters; the method creates a nucleus record.
  /// If [principal] is provided, the new nucleus inherits from it.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: Optional. The **Lifecycle Governance Policy** (TTL/Hops).
  ///   If null and a [principal] is provided, it is inherited from the principal.
  /// * [bind]: Optional. An upstream [Cell] to which the governed cell's
  ///   lifecycle or state is reactively bound.
  /// * [context]: Optional. The **Operational Environment**. Determines
  ///   execution priority, security tier, and authority context.
  /// * [receptor]: Optional. The **Transformation Pipeline** specialized for
  ///   type [C] that orchestrates how incoming signals are applied to the state.
  /// * [testRule]: Optional. The **Policy Guard** validator used to authorize
  ///   and validate state changes.
  /// * [synapses]: Optional. Configuration for the **Signal Distribution Network**.
  /// * [forceLock]: **Atomic Isolation.** If `true`, allocates a fresh,
  ///   private synchronization [Lock] for this nucleus. If `false` and a
  ///   [principal] is provided, the principal's lock is inherited instead.
  /// * [user]: Optional [Record] for developer-defined ad-hoc metadata
  ///   kept separate from core framework logic.
  /// * [principal]: Optional. An ancestor [Nucleus] to extend via the
  ///   [evolve] pattern, establishing a prototype-based inheritance link.
  ///
  /// ### Returns:
  /// A [Nucleus] instance configured as a stateless blueprint for the
  /// specified reactive node.
  static Nucleus create<C extends Cell>(
      {EphemeralPolicy<C>? ephemeralPolicy,
      Cell? bind,
      Context? context,
      Receptor<C>? receptor,
      TestCell<C>? testRule,
      Synapses? synapses,
      bool forceLock = false,
      Record? user,
      Nucleus? principal}) {
    if (principal != null) {
      final local = NucleusBase.mask(
          bind: bind,
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses,
          forceLock: forceLock,
          user: user);
      return _Nucleus.fromRecord((local: local, principal: principal));
    }
    return _Nucleus(
        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? Receptor.passThrough,
        testRule: testRule ?? TestCell.allowAll,
        synapses: synapses ?? Synapses.enabled,
        user: user,
        forceLock: forceLock);
  }

  /// Activates this nucleus by binding it to a live [Cell] instance.
  ///
  /// ### When to use
  /// You never call this – the framework does it automatically when you
  /// create a cell from a nucleus via [Cell.fromNucleus].
  ///
  /// ### How it works
  /// It establishes the bidirectional link between the nucleus and the cell.
  /// After activation, [isActivated] returns `true` and [cell] becomes
  /// accessible.
  ///
  /// ### Returns:
  /// - `true`: If the nucleus was successfully bound to the cell.
  /// - `false`: If the nucleus is already activated, the cell is invalid,
  ///   or an internal error occurred.
  bool activate(covariant Cell cell);

  /// Returns the live [Cell] instance that this nucleus is bound to.
  ///
  /// ### When to use
  /// Mostly for internal framework code. You rarely need this directly.
  ///
  Cell get cell;

  /// Indicates whether this nucleus has been bound to a live [Cell].
  ///
  /// ### When to use
  /// Debugging or diagnostic tools. You rarely need this in application code.
  ///
  /// ### How it works
  /// Returns `true` after [activate] has been called successfully.
  bool get isActivated;

  /// Indicates whether this node has reached the end of its **Functional Lifecycle**
  /// and is no longer capable of processing pulses or maintaining state.
  ///
  /// In the forensic architecture, invalidation represents a "Programmed Cell
  /// Death" (Apoptosis). Once a node is invalidated, it is logically severed
  /// from the reactive graph, and any further attempts to interact with it
  /// will fail to preserve the **Causal Integrity** of the system.
  ///
  /// ### When to use
  /// - **Resource Cleanup**: To determine if a node's allocated memory and
  ///   listeners can be safely decommissioned by the framework.
  /// - **Stale State Detection**: Checking if a derived [Cell] or deputy handle
  ///   is still linked to a living data source.
  /// - **Lifecycle Monitoring**: Determining if an [EphemeralPolicy] has
  ///   triggered a scheduled expiration.
  ///
  /// ### How it works
  /// The invalidation state is resolved through a **Lifecycle Inheritance Strategy**:
  /// 1. **Policy Authority**: If a local [EphemeralPolicy] is defined, its
  ///    internal logic (e.g., timeout, usage count) dictates the status.
  /// 2. **Causal Parity**: If no local policy exists but the node is [bind]ed
  ///    to an upstream source, it adopts the invalidation status of that source.
  ///    This ensures that projections never outlive their prototypes.
  /// 3. **Terminal Living**: If neither a local policy nor an upstream binding
  ///    is present, the node is considered permanent (`false`).
  ///
  /// ### Returns:
  /// `true` if the node has expired or its causal source has been invalidated.
  bool get isInvalidated;

  /// Indicates whether this node is subject to active **Administrative Oversight**
  /// or specialized **Lifecycle Governance**.
  ///
  /// In the biological metaphor, a [Nucleus] is considered "Governed" if it
  /// departs from the default, passive system state by possessing either a
  /// specific operational mandate ([context]) or a defined survival
  /// duration ([EphemeralPolicy]).
  ///
  /// ### When to use
  /// - **Resource Management**: To identify nodes that require active monitoring
  ///   by the garbage collector or specialized lifecycle managers.
  /// - **Security Auditing**: To distinguish between standard system-tier nodes
  ///   and nodes carrying specialized [Context] authority.
  /// - **Forensic Filtering**: When traversing the graph to isolate nodes
  ///   that possess non-standard provenance or specific integrity rules.
  ///
  /// ### How it works
  /// The governance state is determined by a **Causal Aggregation Strategy**:
  /// 1. **Local Mandate**: Returns `true` if the nucleus has a local
  ///    [EphemeralPolicy] (lifecycle limit) or if its [context] is evolved
  ///    beyond the default [Context.system].
  /// 2. **Causal Inheritance**: If no local mandate is found and the node is
  ///    [bind]ed to an upstream source, it adopts the governance status of
  ///    that source. This ensures that projections of a governed cell are
  ///    themselves considered governed.
  /// 3. **Passive Default**: If no local overrides exist and there is no
  ///    upstream binding, the node is considered un-governed (standard system state).
  ///
  /// ### Returns:
  /// `true` if the node is under specialized administrative or lifecycle control.
  bool get isGoverned;

  /// The synchronization primitive used to ensure thread-safe and atomic
  /// operations across the reactive [Cell] associated with this [Nucleus].
  ///
  /// ### When to use
  /// You typically don't need this – the framework handles locking
  /// automatically. Use it only for advanced manual synchronization.
  ///
  /// ### How it works
  /// Returns the [Lock] instance that protects this cell's state. May be
  /// `null` if the nucleus is not yet activated or if it uses a shared lock.
  Lock? get lock;

  /// The connectivity manager responsible for tracking and notifying downstream
  /// observers of this [Cell].
  ///
  /// ### When to use
  /// You can inspect this to see what observers are linked, but you normally
  /// use [Synapses.link]/[Synapses.unlink] to modify it.
  ///
  /// ### How it works
  /// Returns the [Synapses] instance that manages the observer registry.
  /// If synapses are disabled, returns [Synapses.disabled].
  Synapses get synapses;

  /// The upstream [Cell] dependency that serves as the primary **Ingress Source**
  /// for this node's reactive logic.
  ///
  /// ### When to use
  /// You rarely read this – it's set when you create a cell with `bind:`.
  ///
  /// ### How it works
  /// Returns the cell this nucleus is bound to, or `null` if none.
  /// This is not inherited from the principal.
  Cell? get bind;

  /// Retrieves the optional [Record] containing developer-defined metadata or
  /// custom property extensions for the associated [Cell].
  ///
  /// ### When to use
  /// Use this to attach custom data to a cell's blueprint – e.g.,
  /// configuration flags, UI hints, etc.
  ///
  /// ### How it works
  /// The `user` record is stored in the nucleus. It is resolved by walking
  /// up the principal chain if not defined locally.
  Record? get user;

  /// Retrieves the optimized **Logic Inheritance Handle** containing the
  /// shared behavioral configuration for this [Nucleus].
  ///
  /// ### When to use
  /// This is an internal handle used by the framework for efficient
  /// property resolution. You don't need to use it directly.
  ///
  /// ### How it works
  /// It aggregates [context], [receptor], and [testRule] into a single
  /// record that can be shared across multiple nuclei.
  InheritableHandle get inheritable;

  /// The **Transformation Pipeline** and pulse processing engine for the
  /// associated [Cell].
  ///
  /// ### When to use
  /// You typically define this when creating a custom cell; you rarely
  /// read it directly.
  ///
  /// ### How it works
  /// Returns the [Receptor] that processes incoming pulses. It is resolved
  /// by walking up the principal chain if not defined locally.
  Receptor get receptor;

  /// The active [TestCell] integrity gate that governs and validates all state
  /// transitions for this node.
  ///
  /// In the biological metaphor of the framework, the [testRule] acts as the
  /// **Immune System** or **Quality Control** mechanism of the [Nucleus]. It
  /// evaluates every incoming [Pulse] to ensure that only stimuli meeting the
  /// node's structural and security constraints are permitted to evolve the state.
  ///
  /// ### When to use
  /// - **Integrity Validation**: Defining business rules that must never be
  ///   violated (e.g., "Account balance cannot be negative").
  /// - **Security Constraints**: Verifying that a [Pulse] carries the
  ///   necessary [Context] authority before allowing a sensitive mutation.
  /// - **State Consistency**: Ensuring that complex structural changes in
  ///   reactive collections maintain valid internal relationships.
  ///
  /// ### How it works
  /// The integrity gate employs a **Tiered Resolution Strategy** to determine
  /// the active rule for a specific cell handle:
  /// 1. **Local Override**: It first checks for a [TestCell] defined
  ///    explicitly in this node's local segment.
  /// 2. **Prototype Inheritance**: If not found locally, it walks up the
  ///    [principal] chain to inherit a rule from its prototype (Flyweight pattern).
  /// 3. **Causal Binding**: If the resolved rule is the default
  ///    [TestCell.allowAll] and the node is [bind]ed to an upstream source,
  ///    it adopts the integrity gate of the bound cell to ensure causal parity.
  /// 4. **Global Default**: If no rule is found in the lineage or bindings,
  ///    it defaults to [TestCell.allowAll].
  ///
  /// ### See also:
  /// * [TestCell] – The functional interface for defining integrity gates.
  /// * [Context] – The operational anchor used within rules to verify authority.
  /// * [Receptor] – The transformation logic that executes only after the gate clears.
  TestCell get testRule;

  /// The operational [Context] defining the forensic identity, administrative
  /// authority, and causal lineage of this specific [Cell] handle.
  ///
  /// The [context] is a foundational architectural element that represents the
  /// "Identity" or "Provenance" under which the cell performs its logic. It
  /// acts as the primary metadata anchor for the [testRule], providing
  /// the necessary evidence to verify if an incoming [Pulse] possesses the
  /// required authority to trigger a state transition.
  ///
  /// ### Architectural Significance: The Forensic Anchor
  /// In a multi-package or monorepo environment, the context ensures
  /// **Causal Integrity**. It prevents unauthorized "cross-talk" between
  /// different layers of the application (e.g., a UI component attempting
  /// to trigger a low-level system-tier mutation) by validating the
  /// lineage of every stimulus.
  ///
  /// ### When to use
  /// - **Integrity Rules**: Within a [TestCell] gate to verify if the acting
  ///   authority matches the expected tier for a specific command.
  /// - **Forensic Auditing**: When logging state changes to identify which
  ///   subsystem or authority triggered the mutation.
  /// - **Deputy Evolution**: To use as a parent reference when calling
  ///   [Context.evolve] to create a more specialized or restricted scope.
  ///
  /// ### How it works
  /// The context employs a **Tiered Resolution Strategy** to determine the
  /// handle's identity:
  /// 1. **Local Override**: It first checks for a context defined explicitly
  ///    in this nucleus's local segment.
  /// 2. **Prototype Inheritance**: If not found locally, it walks up the
  ///    [principal] chain to inherit a context from its prototype.
  /// 3. **Causal Binding**: If the resolved context is the default
  ///    [Context.system] and the node is [bind]ed to an upstream source, it
  ///    adopts the context of the bound cell.
  /// 4. **Global Default**: If no context is found in the lineage or bindings,
  ///    it defaults to [Context.system].
  ///
  /// ### Returns:
  /// The [Context] instance representing the forensic anchor and authority
  /// tier of this node.
  Context get context;

  /// The optional reference to a precursor [Nucleus] in the inheritance
  /// hierarchy.
  ///
  /// ### When to use
  /// Rarely – this is mostly used internally to resolve inherited properties.
  ///
  /// ### How it works
  /// Returns the parent nucleus, or `null` if this is the root.
  Nucleus? get principal;

  /// The **Temporal Origin** and synthesis record of this [Nucleus] instance.
  ///
  /// ### When to use
  /// Debugging – to know when a cell's blueprint was created.
  ///
  /// ### How it works
  /// Returns the [DateTime] when this nucleus was constructed.
  DateTime get timestamp;

  /// Generates a decoupled, peer-level replica of the current [Nucleus] blueprint
  /// with an independent synchronization domain.
  ///
  /// ### When to use
  /// Almost never – the framework uses it internally when you create a
  /// cell from an already‑activated nucleus.
  ///
  /// ### How it works
  /// Creates a new nucleus with the same logic but a fresh lock and
  /// synapse registry, so it can be used to create an independent cell.
  Nucleus get clone;
}
