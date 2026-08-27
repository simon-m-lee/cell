// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

/// The foundational **Authority Protocol** for defining structural and
/// behavioral guardrails within the framework's [Mandate] ontology.
///
/// [Governance] acts as a **Type-Level Marker** for objects that represent
/// official system policies. It binds a generic type [V] to the governance
/// hierarchy, allowing the [Context] to organize metadata into
/// distinct, type-safe [Mandate] dimensions.
///
/// ### When to use
/// You rarely need to implement this interface directly. The framework
/// provides ready‑to‑use enums like [Ontology], [Provenance], and [Mandate].
/// Use their `.entry(value)` factory to create typed governance entries for
/// building contexts.
///
/// ### How it works
/// Each governance dimension is a typed key that holds a value of type [V].
/// The framework uses these to enforce security, compliance, and operational
/// rules. The [evolvable] flag decides whether a dimension can be refined
/// when you create a deputy.
///
/// ### Non‑obvious
/// - The [isType] guard prevents type mismatches at runtime – it's why
///   you can't accidentally put a `String` where a `List<String>` is expected.
/// - The [evolvable] flag is what stops a deputy from changing its core
///   identity (like `role` or `taxonomy`) – that's intentional to prevent
///   privilege escalation.
///
/// ### Type Parameters:
/// - [V]: The expected value type for this specific governance dimension.
abstract interface class Governance<V> implements Enum {

  /// Indicates whether this governance dimension can be specialized or
  /// modified during a context [Context.evolve] operation.
  ///
  /// In the framework's **Authority Model**, this property separates
  /// **Systemic Invariants** from **Operational Variables**.
  ///
  /// ### When to use
  /// You'll rarely check this directly – the framework uses it internally
  /// to decide what can be overridden when you call `context.evolve()`.
  ///
  /// ### Non‑obvious
  /// - Dimensions marked `false` (like `taxonomy`) cannot be changed, even
  ///   if you try to override them in a deputy. This prevents identity drift.
  /// - This is enforced at the engine level – you don't need to guard
  ///   against it manually.
  bool get evolvable;

  /// A **Type Guard** and **Ontological Validator** that verifies if a given
  /// value conforms to the expected type of this governance dimension.
  ///
  /// [isType] is the primary mechanism for preventing "Ontological Corruption"
  /// within the [Mandate]. It ensures that metadata entering the [Context]
  /// through a [Pulse] or an **evolve** operation matches the schema defined
  /// by the **dimension**.
  ///
  /// ```dart
  /// final isValid = Ontology.taxonomy.isType('PaymentProcessor');
  /// print(isValid); // true
  /// ```
  ///
  /// ### When to use
  /// Mostly used internally, but can be helpful for debugging or writing
  /// custom governance checks.
  bool isType(Object value);

  /// Synthesizes a new **GovernanceEntry** by binding a concrete [value]
  /// to this dimension's [Governance] protocol.
  ///
  /// [entry] acts as the primary factory for creating the individual
  /// "legal records" that populate a [Context]. It ensures that any value
  /// entering the system's **Authority Model** is properly wrapped with
  /// its associated **dimension** metadata.
  ///
  /// ```dart
  /// // Type-safe entry creation
  /// final entry = Ontology.domains.entry(['Finance', 'HR']);
  /// // entry is GovernanceEntry<Ontology<List<String>>>
  ///
  /// // Used to build contexts
  /// final context = Context.fromEntries([entry]);
  /// ```
  GovernanceEntry<Governance<V>,V> entry(V value);

}

/// A strongly-typed key-value pair that represents a single dimension of
/// governance within the framework's **Scene-Driven Ontology**.
///
/// [GovernanceEntry] pairs a [Governance] key (such as [Ontology.taxonomy] or
/// [Provenance.actor]) with a typed value. It is the fundamental building
/// block for constructing [Context]s, [DeputyContext]s, and [PulseContext]s
/// in a type-safe manner.
///
/// ### When to use
/// You'll almost always create entries via the `.entry()` method on a
/// governance enum, like `Ontology.taxonomy.entry('Processor')`.
/// This class is just the data container – you don't need to construct it
/// manually.
///
/// ### How it works
/// Each entry pairs a dimension key with a typed value. The framework uses
/// these internally to build context records.
///
/// ### Non‑obvious
/// The type parameters [G] and [V] are preserved so that when you later
/// read from a context using `context[Ontology.taxonomy]`, you get a
/// `String` (or whatever the expected type is) – not a loose `dynamic`.
/// This is why entries are type‑safe.
///
/// ### Type Parameters
/// - [G]: The specific [Governance] type (e.g., [Ontology], [Provenance], [Mandate])
/// - [V]: The value type for this governance dimension (e.g., [String], [List<String>])
///
/// See also:
/// * [Governance]: The interface that defines governance dimensions.
/// * [Context]: The operational environment built from governance entries.
/// * [DeputyContext]: The mandate profile for delegated authority.
class GovernanceEntry<G extends Governance<V>, V> {

  /// The governance dimension (key) for this entry.
  final G key;

  /// The typed value associated with this governance dimension.
  final V value;

  /// Converts this entry to a standard [MapEntry] for use in collections.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is useful when working with Map APIs:
  ///
  /// ```dart
  /// final entry = Ontology.taxonomy.entry('Processor');
  /// final mapEntry = entry.toEntry();
  /// // mapEntry is MapEntry<Ontology<String>, String>
  /// ```
  MapEntry<G,V> toEntry() => MapEntry(key, value);

  /// Creates a new [GovernanceEntry] with the specified [key] and [value].
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// While you can use this constructor directly, it's recommended to use
  /// the [Governance.entry] method for better readability:
  ///
  /// ```dart
  /// // Both are equivalent, but the extension method is more readable:
  /// final entry1 = GovernanceEntry(Ontology.taxonomy, 'Processor');
  /// final entry2 = Ontology.taxonomy.entry('Processor');
  /// ```
  const GovernanceEntry(this.key, this.value);

}

/// A convenient mixin that provides default implementations for the
/// [Governance] interface methods.
///
/// [GovernanceMixin] simplifies the creation of custom governance enums by
/// providing ready-to-use implementations of [isType] and [entry]. This
/// reduces boilerplate and ensures consistent behavior across all governance
/// dimensions.
///
/// ### Type Parameters
/// - [G]: The specific [Governance] type (must be an enum).
/// - [V]: The value type for this governance dimension.
///
/// See also:
/// * [Governance]: The interface that defines governance dimensions.
/// * [Ontology]: The structural governance enum.
/// * [Provenance]: The causal governance enum.
/// * [Mandate]: The delegation governance enum.
mixin GovernanceMixin<G extends Governance<V>, V> implements Governance<V> {

  /// Validates if the provided [value] matches the expected type [V].
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is primarily used internally, but can be helpful for debugging:
  ///
  /// ```dart
  /// final isValid = Ontology.taxonomy.isType('PaymentProcessor');
  /// print(isValid); // true
  ///
  /// final invalid = Ontology.taxonomy.isType(42);
  /// print(invalid); // false (int is not String)
  /// ```
  ///
  /// ### Implementation
  /// The default implementation uses Dart's `is` operator to check if
  /// [value] is an instance of [V]. This is type-safe and works with
  /// all value types including primitives, collections, and custom classes.
  @override
  bool isType(Object value) => value is V;

  /// Creates a strongly-typed [GovernanceEntry] for this governance dimension.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is the primary way to create governance entries:
  ///
  /// ```dart
  /// // Create an entry for taxonomy
  /// final entry = Ontology.taxonomy.entry('PaymentProcessor');
  /// // entry is GovernanceEntry<Ontology<String>, String>
  ///
  /// // Create an entry for domains
  /// final entry2 = Ontology.domains.entry(['Finance', 'HR']);
  /// // entry2 is GovernanceEntry<Ontology<List<String>>, List<String>>
  ///
  /// // Create an entry for compliance
  /// final entry3 = Ontology.compliances.entry(['GDPR', 'SOC2']);
  /// // entry3 is GovernanceEntry<Ontology<List<String>>, List<String>>
  /// ```
  ///
  /// ### Benefits
  /// - **Type Safety**: The compiler ensures the value type matches.
  /// - **Readability**: The entry creation reads naturally.
  /// - **Composability**: Entries can be easily combined into contexts.
  ///
  /// ### Example: Building a Context
  /// ```dart
  /// final context = Context.fromEntries([
  ///   Ontology.taxonomy.entry('SecureVault'),
  ///   Ontology.domains.entry(['Security', 'Cryptography']),
  ///   Ontology.compliances.entry(['FIPS-140-2', 'PCI-DSS']),
  ///   Ontology.constraints.entry({'encryption': 'AES-256'}),
  /// ]);
  /// ```
  @override
  GovernanceEntry<G,V> entry(V value) => GovernanceEntry<G,V>(this as G, value);

}

/// Defines the **Structural Taxonomy, Static Identity, and Architectural Shape**
/// of a [Cell].
///
/// In the Switching Fabric, [Ontology] represents the "Static Scene." While
/// [Provenance] tracks the dynamic history of a signal (the "How"), [Ontology]
/// provides the machine-readable schema that defines what a node *is* (the "What"),
/// its role in the topology, and the rules governing its existence.
///
/// ### When to use
/// You don't configure [Ontology] directly. Instead, you use context
/// factories like `Context.module()`, `Context.secureEnclave()`, etc.,
/// which automatically populate the relevant ontology dimensions.
/// Only reach for manual entries if none of the named factories fit.
///
/// ### How it works
/// Each dimension is a typed key that holds a value. Static pillars
/// (`evolvable: false`) are fixed at creation; fluid boundaries
/// (`evolvable: true`) can be refined via `context.evolve()`.
///
/// ### Non‑obvious
/// - The `evolvable` flag is not a suggestion – the framework enforces it
///   at the engine level. If you try to evolve a non‑evolvable dimension,
///   the change will be silently ignored.
/// - The `compose` and `evolve` methods are used internally by the framework
///   to build contexts. You'll rarely call them directly.
///
/// See also:
/// * [Context]: The operational environment built from ontology.
/// * [Mandate]: The delegation parameters that govern deputy behavior.
/// * [Provenance]: The dynamic history of a pulse.
enum Ontology<V> with GovernanceMixin<Ontology<V>,V> implements Governance<V> {

  // non-evolvable

  /// The high-level **Knowledge Domains** or business-level functional areas
  /// this [Cell] governs.
  ///
  /// **Type**: [String] (Comma-separated or specific identifier)
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Specify this if you want to group cells by business area (e.g., 'Finance',
  /// 'Security') for scoped observation or audit reporting.
  ///
  /// ### How it works
  /// The framework uses this for affinity routing and constraint scoping.
  /// Pulses can be broadcast to all cells in a given domain.
  ///
  /// ### Non‑obvious
  /// This is a static pillar – once set, it cannot be changed via `evolve`.
  /// This ensures that a cell's functional area doesn't drift.
  ///
  /// ### Example
  /// ```dart
  /// // Domains: 'Finance, PII'
  /// if (context.domains?.contains('PII') ?? false) {
  ///   redactSensitiveData(pulse.payload);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Ontology.subDomains]: For granularity within domains.
  /// * [Context.domains]: The runtime getter.
  domains<String>(false),

  /// The collection of origins, upstream interfaces, or sensory inputs from which
  /// this context derives its information.
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Set this if your cell ingests data from specific external systems or
  /// APIs, to establish trust and provenance.
  ///
  /// ### How it works
  /// The framework uses this for conflict resolution and security enforcement.
  /// It helps prevent "Source Injection" attacks.
  ///
  /// ### Example
  /// ```dart
  /// // DataSources: 'Auth_Service, User_DB'
  /// if (!context.dataSources?.contains('Auth_Service') ?? true) {
  ///   throw SecurityException("Unauthorized Data Origin");
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.dataSources]: The runtime getter.
  dataSources<String>(false),

  /// The formal **Categorical Identity** and functional archetype of the [Cell].
  ///
  /// **Type**: [String] (or a specialized Taxonomy identifier)
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Use this to define what the cell *is* (e.g., 'Repository', 'Gateway').
  /// This is often set automatically by context factories like `Context.core`.
  ///
  /// ### How it works
  /// The taxonomy dictates expected behavior and interface contracts.
  /// It is used for capability discovery and protocol enforcement.
  ///
  /// ### Non‑obvious
  /// As a static pillar, a cell's taxonomy cannot be changed after creation.
  /// This prevents identity drift – an 'Audit_Log' can't become a 'Mutable_Cache'.
  ///
  /// ### Example
  /// ```dart
  /// // Taxonomy: 'Audit_Repository'
  /// if (context.taxonomy == 'Audit_Repository') {
  ///   enforceCausalIntegrity(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.taxonomy]: The runtime getter.
  taxonomy<String>(false),

  /// The **Network Role** or structural position of the [Cell] within the system's
  /// organizational graph.
  ///
  /// **Type**: [String] (e.g., 'Principal', 'Tissue', 'Leaf')
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Set this if the cell's position in the hierarchy matters – e.g., it's a
  /// root orchestrator ('Principal') or a leaf node.
  ///
  /// ### How it works
  /// The topology is used for authority routing and discovery. A 'Leaf' node
  /// cannot override the governance of a 'Principal' node.
  ///
  /// ### Example
  /// ```dart
  /// // Topology: 'Principal'
  /// if (context.topology == 'Principal') {
  ///   enforceHighSovereignty(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.topology]: The runtime getter.
  topology<String>(false),

  /// The **Structural Revision** or schema version of the cell's payload and
  /// governing metadata.
  ///
  /// **Type**: [String] (Semantic Versioning recommended, e.g., '1.0.0')
  /// **Mutability**: **Static Pillar** (Invariant)
  ///
  /// ### When to use
  /// Use this to track schema versions for compatibility checks. It's useful
  /// when you have multiple versions of a cell type.
  ///
  /// ### How it works
  /// Receptors can reject pulses that use deprecated structures by checking
  /// this version.
  ///
  /// ### Example
  /// ```dart
  /// // Version: '2.1.0'
  /// if (context.version?.startsWith('2') ?? false) {
  ///   processV2Payload(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.version]: The runtime getter.
  version<String>(false),

  // evolvable

  /// The functional **Category or Archetype** of the signal or node, used to
  /// label the "Kind" of operation being performed.
  ///
  /// **Type**: [String] (e.g., 'command', 'event', 'telemetry')
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Set this to categorize a cell. This allows the system to perform high-level
  /// routing or filtering without inspecting the raw data.
  ///
  /// ### How it works
  /// The framework uses this to align **Signals** with **Boundaries**. For
  /// example, a `Pulse.type('alert')` can be screened by an **Integrity Gate**
  /// that specifically looks for the 'alert' type in the context.
  ///
  /// ### Non‑obvious
  /// While [taxonomy] is a static architectural identifier (what the cell
  /// *is*), [type] is a fluid operational identifier (what the current
  /// interaction *is about*). It is designed to match the `type` parameter
  /// in the [Pulse] factory.
  ///
  /// ### Example
  /// ```dart
  /// // Type: 'security_event'
  /// if (context.type == 'security_event') {
  ///   triggerHighPriorityAlert(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Pulse.type]: The factory for creating typed signals.
  /// * [Context.type]: The runtime getter.
  type<String>(true),

  /// The **Unique Instance Name** or specific label assigned to a [Cell] or
  /// [Pulse], distinguishing it from others of the same [type].
  ///
  /// **Type**: [String] (e.g., 'Primary_Auth_Node', 'User_123_Profile')
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Use this to name specific instances of components. While [type] defines
  /// *what* a thing is, [identity] defines *which* specific thing it is.
  ///
  /// ### How it works
  /// The framework uses this for **Precise Targeting** and **Forensic Audit**.
  /// When a [Pulse] moves through the fabric, its [identity] allows the
  /// **Switching Fabric** to track exactly which node initiated a change.
  ///
  /// ### Non‑obvious
  /// This dimension is **Evolvable** specifically to support the
  /// **Deputy Pattern**. When you create a proxy of a cell, its [identity]
  /// can be refined (e.g., from 'Auth_Node' to 'Auth_Node_ReadOnly_Proxy')
  /// to maintain clear **Identity Transparency** across the system.
  ///
  /// ### Example
  /// ```dart
  /// // Identity: 'Payment_Gateway_Alpha'
  /// if (context.identity == 'Payment_Gateway_Alpha') {
  ///   routeToHighIntegrityProcessor(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Ontology.type]: For categorical labeling.
  /// * [Ontology.partOf]: For structural membership.
  /// * [Context.identity]: The runtime getter.
  identity<String>(true),

  /// The specialized functional areas or localized operational zones within
  /// the primary [domains].
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// When you need finer-grained scoping than `domains` provides – e.g.,
  /// refining 'Finance' into 'Tax_Calculation'.
  ///
  /// ### How it works
  /// This dimension is used for precise routing and validation. A deputy can
  /// evolve to narrow its sub‑domain scope.
  ///
  /// ### Example
  /// ```dart
  /// // SubDomains: 'Tax_Calculation, VAT'
  /// if (context.subDomains?.contains('VAT') ?? false) {
  ///   applyVATRules(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.subDomains]: The runtime getter.
  subDomains<String>(true),

  /// The collection of entities, roles, or external systems **Accountable** for
  /// or affected by the state transitions within this [Cell].
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Specify who is responsible for this cell – e.g., 'Finance_Admin' or
  /// 'Compliance_Bot'. This is used for authorization and escalation.
  ///
  /// ### How it works
  /// The framework uses this for Attribute‑Based Access Control (ABAC). An
  /// `actor` in a pulse must match one of the stakeholders to be authorized.
  ///
  /// ### Example
  /// ```dart
  /// // Stakeholders: 'Billing_Dept, Security_Lead'
  /// if (context.stakeholders?.contains(pulse.actor) ?? false) {
  ///   executeAction(pulse);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.stakeholders]: The runtime getter.
  stakeholders<String>(true),

  /// The operational rules, boundary conditions, and validation schemas
  /// enforced within the [Cell].
  ///
  /// **Type**: [Map<String, dynamic>]
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Define runtime constraints like `max_items`, `timeout`, or `read_only`.
  /// This is the primary place to configure business invariants.
  ///
  /// ### How it works
  /// The framework checks these constraints during the validation phase.
  /// A deputy can tighten constraints via `evolve`.
  ///
  /// ### Example
  /// ```dart
  /// // Constraints: { 'max_value': 100, 'requires_auth': true }
  /// final config = context.constraints;
  /// if (proposedValue > (config?['max_value'] ?? 0)) {
  ///   proposedValue = config!['max_value'];
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.constraints]: The runtime getter.
  constraints<Map<String, dynamic>>(true),

  /// The exclusionary boundaries defining prohibited behaviors, out-of-scope
  /// responsibilities, or forbidden identities for the [Cell].
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Explicitly define what the cell is *not* – e.g., 'Currency_Exchange' for
  /// a payment gateway that shouldn't handle currency conversion.
  ///
  /// ### How it works
  /// During signal processing, if a pulse requires a capability listed in
  /// `isNot`, the transformation is aborted.
  ///
  /// ### Example
  /// ```dart
  /// // IsNot: 'Currency_Exchange, Credit_Issuer'
  /// if (context.isNot?.contains('Credit_Issuer') ?? false) {
  ///   if (pulse.action == 'Credit_Limit_Increase') {
  ///     throw SovereigntyException('Action forbidden by IsNot boundary.');
  ///   }
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.isNot]: The runtime getter.
  isNot<String>(true),

  /// The **Regulatory Frameworks** and architectural standards mandated by this
  /// authority (e.g., 'GDPR', 'PCI-DSS', 'HIPAA').
  ///
  /// **Type**: [String] (Comma-separated)
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Set this if the cell must comply with specific regulations – e.g., 'GDPR'
  /// for handling European user data.
  ///
  /// ### How it works
  /// The framework uses this for boundary validation and automatic auditing.
  /// Pulses that cross compliance zones are flagged.
  ///
  /// ### Example
  /// ```dart
  /// // Compliance: 'GDPR, SOC2'
  /// if (context.compliance?.contains('GDPR') ?? false) {
  ///   encryptPII(pulse.payload);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.compliance]: The runtime getter.
  compliance<String>(true),

  /// The structural pointer identifying the **Parent Container** or the
  /// ancestral system this [Cell] belongs to.
  ///
  /// **Type**: [String] (Typically a Unique Identity or Taxonomy string)
  /// **Mutability**: **Evolvable** (Operational Variable)
  ///
  /// ### When to use
  /// Use this to establish the cell's lineage – e.g., which module or service
  /// it belongs to.
  ///
  /// ### How it works
  /// The framework uses this for constraint resolution (inheriting rules from
  /// the parent) and for mutual authorization handshakes.
  ///
  /// ### Example
  /// ```dart
  /// // PartOf: 'Global_Ledger_Service'
  /// if (context.partOf == 'Global_Ledger_Service') {
  ///   await verifyPrincipalClearance(context.partOf);
  /// }
  /// ```
  ///
  /// ### See Also:
  /// * [Context.partOf]: The runtime getter.
  partOf<String>(true);

  /// Indicates whether this specific [Ontology] dimension is permitted to be
  /// modified or refined during a context transformation.
  ///
  /// In the framework's **Prototype-based Inheritance** model, dimensions are
  /// categorized into two distinct mutability tiers:
  ///
  /// *   **Static Pillars (`evolvable: false`)**: Core structural identifiers
  ///     such as [taxonomy], [topology], or [version]. These are anchored at
  ///     creation to ensure the fundamental architectural identity of the
  ///     [Cell] remains consistent across its entire lifecycle.
  /// *   **Fluid Boundaries (`evolvable: true`)**: Operational metadata such
  ///     as [constraints], [stakeholders], or [compliance]. These can be
  ///     re-defined or narrowed through the `evolve` (derive) method to
  ///     reflect changing situational requirements.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This flag helps developers understand which aspects of ontology
  /// can be customized:
  ///
  /// ```dart
  /// // evolvable: true (can be overridden)
  /// Ontology.constraints.evolvable // true
  ///
  /// // evolvable: false (fixed identity)
  /// Ontology.taxonomy.evolvable // false
  /// ```
  @override
  final bool evolvable;

  /// Internal constructor for defining an [Ontology] dimension and its
  /// evolutionary characteristics.
  ///
  /// This constructor is the mechanism by which the framework differentiates
  /// between the **Static Pillars** of a node's identity and the
  /// **Fluid Boundaries** of its operational scene.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is used internally by the framework. Human developers don't
  /// need to interact with it directly. The framework provides enum
  /// values with pre-configured evolvability.
  ///
  /// ### Parameters:
  /// - [evolvable]: If `true`, the dimension is a **Fluid Boundary** that can
  ///   be attenuated or refined. If `false`, it is a **Static Pillar** that
  ///   serves as a permanent anchor for the node's identity.
  const Ontology(this.evolvable);

  /// Generates a comprehensive **Knowledge Map** by synthesizing a value for
  /// every defined dimension in the [Ontology].
  ///
  /// This method serves as the primary factory for creating the initial
  /// **Static Blueprint** of a context. It iterates through all available
  /// ontological keys—both **Static Pillars** and **Fluid Boundaries**—to
  /// build a complete semantic profile for a [Cell].
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is used internally by the framework. Human developers typically
  /// use context factories instead:
  ///
  /// ```dart
  /// // Framework internal usage
  /// final entries = Ontology.compose((dimension) {
  ///   if (dimension == Ontology.taxonomy) {
  ///     return Ontology.taxonomy.entry('Processor');
  ///   }
  ///   return null;
  /// });
  ///
  /// // Human-friendly alternative
  /// final context = Context(
  ///   taxonomy: 'Processor',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback function that produces a [GovernanceEntry] (a
  ///   key-value pair) for each [Ontology] dimension. If the resolver
  ///   returns `null` for a key, that dimension is omitted from the result.
  ///
  /// ### Returns:
  /// An [Iterable<GovernanceEntry>] containing a synthesized entry for every
  /// applicable ontological dimension in the scene.
  static Iterable<GovernanceEntry> compose(GovernanceEntry? Function(Ontology dimension) resolver) {
    final entries = values.map((g) => resolver(g)).where((en) => en != null);
    return entries.cast();
  }

  /// Synthesizes a refined **Knowledge Map** by generating values only for the
  /// **Fluid Boundaries** of the [Ontology].
  ///
  /// This method is the primary engine for **Prototype-based Inheritance**
  /// within a context. It isolates the dimensions marked as [evolvable] and
  /// allows for the creation of a specialized delta—or "Evolutionary Layer"—
  /// that refines the behavior of a [Cell] without altering its core identity.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// This is used internally by [Context.evolve]. Human developers typically
  /// use [Context.evolve] instead:
  ///
  /// ```dart
  /// // Human-friendly evolution
  /// final evolved = baseContext.evolve((evolvable) {
  ///   if (evolvable == Ontology.domains) {
  ///     return Ontology.domains.entry(['Finance']);
  ///   }
  ///   return null;
  /// });
  ///
  /// // Framework internal equivalent
  /// final entries = Ontology.evolve((evolvable) {
  ///   if (evolvable == Ontology.domains) {
  ///     return Ontology.domains.entry(['Finance']);
  ///   }
  ///   return null;
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [resolver]: A callback function that produces refined values for the
  ///   **Fluid Boundaries** (evolvable dimensions). If the resolver returns
  ///   `null` for a key, that key is omitted from the delta.
  ///
  /// ### Returns:
  /// An [Iterable<GovernanceEntry>] containing only the evolved **Fluid Boundaries**
  /// that differ from or refine the base prototype.
  static Iterable<GovernanceEntry> evolve(GovernanceEntry? Function(Ontology evolvable) resolver) {
    final entries = values.where((g) => g.evolvable == true)
        .map((g) => resolver(g)).whereType<GovernanceEntry>();
    return entries;
  }

}

/// Metadata describing a [Cell]'s tier, domain, and operational
/// boundaries — used by [TestCell] rules to make context-aware decisions.
///
/// ### When to use
/// * [Context.system] — the default. Leave this alone unless you have a
///   specific reason to set it.
/// * Named factories for common roles: [Context.module] (application
///   logic), [Context.secureEnclave] (sensitive/regulated logic),
///   [Context.publicInterface] (external-facing boundary),
///   [Context.core] (infrastructure). Each pre-fills sensible defaults
///   for that role (audit level, sensitivity, priority) so you don't have
///   to reason about the individual dimensions yourself.
/// * `Context(domains: ..., compliances: ...)` — for a fully custom
///   context, if none of the named factories fit.
///
/// ### How it works
/// [Context] organizes metadata into distinct, type-safe [Mandate] dimensions.
/// It uses a **Prototype-based Inheritance** model where dimensions are
/// either **Static Pillars** (invariant) or **Fluid Boundaries** (evolvable).
///
/// ### Non‑obvious
/// **Not every field can be changed later.** Fields like [taxonomy] and [topology]
/// are fixed at creation — calling [evolve] can't change them, only fields
/// marked evolvable (like [constraints], [stakeholders], [compliance]) can be
/// refined. This is intentional: it stops a cell's fundamental identity from
/// silently drifting as it gets passed through [deputy] layers. If [evolve]
/// seems to be ignoring a field you passed, check whether that field is
/// evolvable at all.
///
/// ### See Also
/// * [Context.deputy]: Returns a [DeputyContext] for per‑proxy authority.
/// * [Context.pulse]: Returns a [PulseContext] for per‑signal provenance.
/// * [Ontology]: The underlying dimension keys.
/// {@category Advanced}
/// {@category Context}
abstract interface class Context {

  /// The canonical root context and **Terminal Ancestor** of the reactive fabric's
  /// governance model.
  ///
  /// [system] serves as the ultimate fallback for all ontological lookups,
  /// defining the global "Safe Mode" and default operational parameters for any
  /// [Cell] that has not been explicitly specialized.
  ///
  /// ### When to use
  /// - **Default Initialization**: Used automatically by the framework when no
  ///   explicit context is provided to a `Cell` factory.
  /// - **Baseline Security**: When you need a node to operate with minimal,
  ///   framework-standard authority and global visibility.
  /// - **Generic Logic**: For infrastructure or utility cells that do not
  ///   belong to a specific business domain.
  ///
  /// ### How it works
  /// 1. **Prototype-based Inheritance**: Acts as the root node of the
  ///    contextual graph. Any lookup that fails in a specialized context
  ///    cascades up to [system].
  /// 2. **Global Baseline**: Enforces minimal [Ontology.constraints] and
  ///    [Mandate] defaults to prevent "Authority Vacuum" errors during
  ///    pulse transmission.
  /// 3. **Hybrid Convergence**: As a `static const`, it provides a
  ///    pre-compiled, zero-cost path for metadata resolution and security
  ///    checks across the entire reactive wave.
  ///
  /// ### Non‑obvious
  /// - **Immutable Anchor**: Unlike specialized contexts, [system] cannot be
  ///   fully evolved into a different identity; it defines the shared
  ///   reality of the system.
  /// - **Visibility**: Nodes under the [system] context are visible to all
  ///   diagnostic and auditing layers by default.
  /// - **Zero-Cost Access**: Because it is shared across all nodes, it
  ///   incurs no heap pressure regardless of the graph size.
  ///
  /// ### Example: Implicit vs. Explicit System Context
  /// ```dart
  /// // Implicitly uses Context.system
  /// final defaultCell = Cell.ingress(0);
  ///
  /// // Explicitly referencing for configuration
  /// final loggerCell = Cell.ingress(
  ///   'Log entry',
  ///   context: Context.system,
  /// );
  /// ```
  ///
  /// ### Returns:
  /// The singleton [Context] instance representing the framework's **Root Authority**.
  ///
  /// ### See Also:
  /// * [Context.module]: For application-level business logic.
  /// * [Context.core]: For infrastructure-level components.
  /// * [Ontology]: For the underlying metadata dimensions.
  static const system = _ContextSystem();

  /// Creates a [Context] derived from a natural language [description], enabling
  /// **Semantic Hydration** of the node's governance model.
  ///
  /// This factory serves as the primary entry point for **Intent-Based
  /// Configuration**. It is specifically designed to be utilized by orchestration
  /// tools or **Autonomous Agents** (Managed Nodes) to perform **Semantic
  /// Synthesis**, converting high-level natural language specifications or
  /// agentic objectives into a structured, machine-readable [Ontology].
  ///
  /// ### When to use
  /// This is primarily for AI agents and automated tooling. For most
  /// application code, using the named factories like `Context.module` is
  /// simpler and clearer.
  ///
  /// ### How it works
  /// The framework parses the description and extracts relevant ontology
  /// dimensions. The result is a high-performance record that can be used
  /// like any other context.
  ///
  /// ### Example
  /// ```dart
  /// final context = Context.describe(
  ///   'A secure audit log for the Healthcare domain compliant with HIPAA'
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [description]: A prose string (e.g., "A secure audit log for the
  ///   Healthcare domain compliant with HIPAA") used to generate the
  ///   context's ontological dimensions.
  const factory Context.describe(String description) = _ContextDescribe;

  /// Primary constructor for building a [Context] from explicit ontological dimensions,
  /// establishing the **Static Blueprint** of the operational environment.
  ///
  /// This constructor maps standard Software Engineering terminology to the
  /// underlying **Scene-Driven Ontology**. It is designed for manual configuration
  /// where the structural role, domain, and governance rules of a [Cell] are
  /// strictly known at development time.
  ///
  /// ### When to use
  /// Use this when none of the named factories (like `Context.module`) fit
  /// your needs and you need full control over every dimension.
  ///
  /// ### How it works
  /// Each named parameter corresponds to an [Ontology] dimension. The context
  /// is built as an immutable record.
  ///
  /// ### Non‑obvious
  /// Remember that some fields (like `taxonomy` and `topology`) are not
  /// evolvable – they can't be changed later via `evolve`. Make sure you
  /// set them correctly upfront.
  ///
  /// ### Parameters:
  /// - [type]: The **Category or Archetype** of the cell.
  /// - [identity]: The unique identifier for this cell.
  /// - [partOf]: The hierarchical container or system name (Structural Parent).
  /// - [dataSources]: The origins or upstream interfaces supplying data to
  ///   this cell.
  /// - [constraints]: A map of operational rules and policy flags governing
  ///   state evolution.
  /// - [domains]: The high-level business or functional areas (e.g., 'Finance',
  ///   'Infrastructure').
  /// - [subDomains]: Specialized operational zones within the primary domains.
  /// - [stakeholders]: The entities, roles, or agents accountable for state
  ///   transitions.
  /// - [isNot]: Explicit exclusionary boundaries (Prohibited behaviors or
  ///   ontological negations).
  /// - [compliance]: Regulatory or safety standards (e.g., 'GDPR', 'HIPAA',
  ///   'ISO-27001').
  /// - [others]: A catch-all map for custom, scene-specific ontological
  ///   metadata that falls outside the standard pillars.
  factory Context({
    String? type,
    String? identity,

    String? domains,
    String? dataSources,
    String? taxonomy,
    String? topology,
    String? version,

    String? subDomains,
    String? stakeholders,
    Map<String, dynamic>? constraints,
    String? isNot,
    String? compliances,
    String? partOf,
    Map<String, dynamic>? others
  }) = _Context;

  /// Creates a specialized **Deputy Mandate**, allowing for authority
  /// delegation, mandate attenuation, and temporal governance.
  ///
  /// This factory serves as the primary mechanism for **Mandate Evolution**
  /// during the **Egress Phase** of the **Reactive Update Cycle**. It
  /// synthesizes a specialized **Capability Profile** for sub-tasks,
  /// maintaining a verifiable **Causal Trace** to the administrative principal.
  ///
  /// ### When to use
  /// Use this when you need to create a deputy with specific authority,
  /// clearance, or temporal lease – e.g., for a temporary task or a read‑only
  /// observer.
  ///
  /// ### How it works
  /// This factory returns a [DeputyContext] that extends the base [Context]
  /// with mandate‑specific fields. The resulting context can be passed to
  /// `cell.deputy()` to create a restricted proxy.
  ///
  /// ### Non‑obvious
  /// The deputy's authority is always **downward‑only** – you cannot grant
  /// more privileges than the base context provides. This enforces least
  /// privilege.
  ///
  /// ### Example (Use of [Ontology.type], [Ontology.identity], [Mandate.role] and [Mandate.authority] together)
  /// ```dart
  /// // The Principal Identity
  /// final room302 = Context(type: 'RoomController', identity: 'Room_302_Master');
  ///
  /// // Housekeeping Deputy Context
  /// final housekeepingMandate = DeputyContext(
  ///   baseContext: room302,
  ///   role: 'Housekeeping',          // The "Who" (Semantic)
  ///   authority: 'LIGHTS_AND_TEMP',  // The "Verb" (Functional)
  ///   justification: 'Daily cleaning cycle',
  ///   clearance: Clearance.standard,
  /// );
  ///
  /// // Security Deputy Context
  /// final securityMandate = DeputyContext(
  ///   baseContext: room302,
  ///   role: 'Security',              // The "Who"
  ///   authority: 'LOCK_OVERRIDE',    // The "Verb"
  ///   justification: 'Fire alarm triggered',
  ///   clearance: Clearance.administrative, // Higher clearance for dangerous verbs
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [baseContext]: The existing environment from which this deputy
  ///   derives its foundational [Ontology].
  /// - [authority]: The primary entity or "Sovereign Resident" name
  ///   responsible for actions taken under this mandate.
  /// - [role]: The functional title or organizational position of the deputy.
  /// - [isolation]: Defines the level of visibility into the parent context's
  ///   metadata.
  /// - [clearance]: The security tier or "Depth of Access" granted to the deputy.
  /// - [lease]: The temporal duration of this authority's validity (TTL).
  /// - [justification]: A prose explanation for the delegation, used in
  ///   governance audits.
  /// - [constraints]: Additional operational guardrails specific to this
  ///   mandate.
  /// - [others]: Catch-all for specialized ontological metadata.
  factory Context.deputy({
    required Context baseContext,

    required String authority,
    String? role,
    Isolation? isolation,
    Clearance clearance,
    String? justification,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) = DeputyContext;


  /// Synthesizes a **Pulse Context**, establishing the semantic and causal
  /// metadata for a specific reactive signal transmission.
  ///
  /// This factory serves as the authoritative entry point for establishing **Causal
  /// Traceability**. It synthesizes an ephemeral **Capability Profile** that
  /// accompanies a [Pulse] as it traverses the **Reactive Update Cycle**,
  /// providing the **Execution Trace** and logic metadata required for
  /// high-fidelity auditing and **Capability-Based Access Control (CBAC)**.
  ///
  /// ### When to use
  /// Use this when you need to attach provenance to a pulse – e.g., to record
  /// who triggered it, why, and with what priority. This is typically used
  /// with `Pulse.governed`.
  ///
  /// ### How it works
  /// The factory returns a [PulseContext] that carries per‑signal metadata
  /// like actor, reason, confidence, and traceId. The framework uses this
  /// for auditing and validation.
  ///
  /// ### Non‑obvious
  /// The [traceId] is automatically generated if not provided, ensuring
  /// uniqueness. You can link pulses via `parentTraceId` to build a causal
  /// chain.
  ///
  /// ### Parameters:
  /// - [baseContext]: The underlying environment (e.g., a **Context**)
  ///   under which this pulse is being authorized.
  /// - [actor]: The identifier of the entity (Human or AI) emitting the pulse.
  /// - [reason]: The immediate cause or "Trigger" for the state transition.
  /// - [purpose]: The high-level goal or "Strategic Intent" of the operation.
  /// - [strategy]: The **ReasoningStrategy** (e.g., Heuristic, LLM, Rule-Based)
  ///   used to calculate the pulse data.
  /// - [confidence]: A scalar value (0.0 to 1.0) representing the actor's
  ///   certainty in the pulse's validity.
  /// - [priority]: The relative urgency of the signal (lower = higher priority).
  /// - [compliance]: The specific regulatory or safety standard being
  ///   asserted by this pulse (e.g., 'SOC2', 'Internal-Audit').
  /// - [sensitivity]: The data classification tier (e.g., Public, Restricted).
  /// - [auditLevel]: The depth of logging and verification required for this signal.
  /// - [traceId]: The unique identifier for this specific causal wave.
  /// - [parentTraceId]: The identifier of the wave that emitted this one,
  ///   preserving lineage.
  /// - [others]: Catch-all for specialized ontological pulse metadata.
  factory Context.pulse({
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
  }) = PulseContext;

  /// Synthesizes a **Governance Environment** from a collection of strongly-typed
  /// ontological entries.
  ///
  /// This factory facilitates the construction of a [Context] by aggregating
  /// individual [GovernanceEntry] pairs. It is the architectural standard for
  /// **Scene Composition**, allowing both developers and AI agents to manifest
  /// operational boundaries through functional synthesis.
  ///
  /// ### When to use
  /// This is an advanced entry point. Use it when you need to build a context
  /// from a dynamic list of entries – e.g., in code generation or when
  /// deserializing a context from an external source.
  ///
  /// ### How it works
  /// You provide a list of [GovernanceEntry] objects, and the framework
  /// constructs a context record from them. You can optionally specify a
  /// [parent] to inherit from.
  ///
  /// ### Non‑obvious
  /// The entries are validated against their `isType` guard at construction
  /// time, so you can't build a context with mismatched types.
  ///
  /// ### Parameters:
  /// - [entries]: An iterable of [GovernanceEntry] objects (key-value pairs)
  ///   defining the ontological pillars of this context.
  /// - [others]: A catch-all map for dynamic, domain-specific metadata that
  ///   falls outside the standard governance schema.
  /// - [parent]: The ancestral [Context] providing the baseline lineage and
  ///   fallback properties for this evolution.
  factory Context.fromEntries(Iterable<GovernanceEntry<Ontology, dynamic>> entries, {Map<String, dynamic>? others, Context? parent})
  = _Context.fromEntries;

  /// Synthesizes a **Core Infrastructure Blueprint** for foundational nodes,
  /// ingress switches, and architectural plumbing within the Switching Fabric.
  ///
  /// This factory identifies high-authority **System-Space** nodes. It serves as
  /// the ontological anchor for the framework's internal orchestration layers
  /// and global signal management.
  ///
  /// ### When to use
  /// Use this factory when you are building infrastructure components that
  /// must operate at the highest priority and with system‑level authority.
  /// - Gateways, hubs, or system services.
  /// - Ingress switches that handle external events.
  /// - Nodes that manage global state or configuration.
  /// - Any component that must preempt standard application logic.
  ///
  /// For typical application logic, prefer [Context.module].
  ///
  /// ### How it works
  /// The factory sets the following ontological dimensions:
  /// - `type`: the provided [type] argument (e.g., 'Gateway', 'Orchestrator').
  ///   This aligns with `Pulse.type` for routing and filtering.
  /// - `identity`: an optional unique name for this specific instance.
  /// - `partOf`: the parent module or service, if provided.
  /// - `taxonomy`: fixed to `'core'` – identifies the cell as system‑level.
  /// - `domains`: fixed to `'system'` – scopes the cell to the system domain.
  /// - `priority`: set to `0` – maximum precedence for infrastructure
  ///   orchestration, ensuring these cells are processed before any others.
  ///
  /// ### Non‑obvious
  /// - The `type` parameter is not optional – it provides the semantic category
  ///   of the infrastructure component, which is critical for routing and
  ///   policy enforcement.
  /// - The `priority` of `0` means these cells execute before any module‑level
  ///   or user‑level cells, making them suitable for security checks,
  ///   authentication, and routing.
  /// - The `taxonomy` and `domains` are static pillars – they cannot be evolved.
  /// - If you need to add custom metadata (e.g., cluster tags, hardware IDs),
  ///   use the `others` map.
  ///
  /// ### Example
  /// ```dart
  /// final gatewayContext = Context.core(
  ///   type: 'Gateway',
  ///   identity: 'Public_Ingress_01',
  ///   partOf: 'Edge_Service',
  ///   others: {'rate_limit': 1000},
  /// );
  /// // The context is now ready for a system‑level ingress cell.
  /// ```
  ///
  /// ### Parameters
  /// - [type]: **Required**. The categorical archetype of the infrastructure
  ///   component (e.g., 'Gateway', 'Orchestrator', 'LoadBalancer'). This is
  ///   stored in [Ontology.type] and mirrors the `type` parameter in [Pulse].
  /// - [identity]: Optional. A unique instance name for this specific node,
  ///   stored in [Ontology.identity]. If omitted, the cell will be anonymous.
  /// - [partOf]: Optional. The parent system module or service, stored in
  ///   [Ontology.partOf].
  /// - [others]: Optional. A catch‑all map for additional metadata (e.g.,
  ///   cluster tags, hardware IDs, or version flags).
  ///
  /// ### Returns
  /// A [Context] configured for high‑authority, system‑level operation.
  ///
  /// See also:
  /// - [Context.module] – the standard factory for application logic.
  /// - [Ontology.type] – the dimension that stores the type.
  /// - [Pulse.type] – the pulse property that aligns with the context type.
  factory Context.core(String type, {String? identity, String? partOf, Map<String, dynamic>? others}) =>
      Context.fromEntries(
        [
          Ontology.type.entry(type), // Categorical alignment with Pulse.type
          if (identity != null) Ontology.identity.entry(identity),
          if (partOf != null) Ontology.partOf.entry(partOf),
          Ontology.taxonomy.entry('core'),
          Ontology.domains.entry('system'),
        ],
        others: {
          'priority': 0,
          ...?others,
        },
      );

  /// Synthesizes a **Module‑Level Context** for domain‑specific logic, feature
  /// components, and specialized state atoms.
  ///
  /// In the framework's **Scene‑Driven Ontology**, a `module` context identifies
  /// "User‑Space" logic. It serves as the primary organizational unit for the
  /// functional features of an application and defines the **Sovereign Resident**
  /// profile for a feature's logical boundary.
  ///
  /// ### When to use
  /// This is the standard factory for most application‑level cells. Use it for
  /// business logic, feature modules, and domain‑specific state containers.
  /// - Payment processing, user management, inventory control.
  /// - Feature modules (e.g., 'Auth', 'Cart', 'Checkout').
  /// - Any cell that implements application‑specific logic.
  /// - Components that should run with standard (non‑infrastructure) priority.
  ///
  /// Only reach for [Context.core] when building system‑level infrastructure.
  ///
  /// ### How it works
  /// The factory sets the following ontological dimensions:
  /// - `type`: the provided [type] argument (e.g., 'PaymentEngine', 'UserService').
  ///   This aligns with `Pulse.type` for routing and filtering.
  /// - `identity`: an optional unique name for this specific instance.
  /// - `partOf`: the parent module or service, if provided.
  /// - `taxonomy`: fixed to `'module'` – identifies the cell as application‑level.
  /// - `domains`: fixed to `'logic'` – scopes the cell to the logic domain.
  /// - `priority`: set to `10` – standard priority for application logic,
  ///   lower than infrastructure (0) but higher than background tasks.
  ///
  /// ### Non‑obvious
  /// - The `type` parameter is required – it provides the semantic category of
  ///   the module, which is used for routing and policy enforcement.
  /// - The `priority` of `10` means these cells execute after core infrastructure
  ///   but before background or telemetry tasks.
  /// - The `taxonomy` and `domains` are static pillars – they cannot be evolved.
  /// - If you need to add custom metadata (e.g., feature flags, versioning),
  ///   use the `others` map.
  ///
  /// ### Example
  /// ```dart
  /// final paymentContext = Context.module(
  ///   type: 'PaymentEngine',
  ///   identity: 'V3_Processor',
  ///   partOf: 'Checkout_Service',
  ///   others: {'currency': 'USD', 'retry_count': 3},
  /// );
  /// // The context is now ready for a module‑level payment cell.
  /// ```
  ///
  /// ### Parameters
  /// - [type]: **Required**. The categorical archetype of the module
  ///   (e.g., 'PaymentEngine', 'UserService', 'InventoryManager'). This is
  ///   stored in [Ontology.type] and mirrors the `type` parameter in [Pulse].
  /// - [identity]: Optional. A unique instance name for this specific node,
  ///   stored in [Ontology.identity]. If omitted, the cell will be anonymous.
  /// - [partOf]: Optional. The parent system module or service, stored in
  ///   [Ontology.partOf].
  /// - [others]: Optional. A catch‑all map for additional metadata (e.g.,
  ///   feature flags, version tags, or environment‑specific configuration).
  ///
  /// ### Returns
  /// A [Context] configured for standard application‑level operation.
  ///
  /// See also:
  /// - [Context.core] – for system‑level infrastructure.
  /// - [Ontology.type] – the dimension that stores the type.
  /// - [Pulse.type] – the pulse property that aligns with the context type.
  factory Context.module(String type, {String? identity, String? partOf, Map<String, dynamic>? others}) =>
      Context.fromEntries(
        [
          Ontology.type.entry(type),
          if (identity != null) Ontology.identity.entry(identity),
          if (partOf != null) Ontology.partOf.entry(partOf),
          Ontology.taxonomy.entry('module'),
          Ontology.domains.entry('logic'),
        ],
        others: {
          'priority': 10,
          ...?others,
        },
      );

  /// Synthesizes a **Secure Enclave Blueprint** for nodes managing
  /// high-integrity state, sensitive logic, or administrative policies.
  ///
  /// This factory serves as the architectural standard for **Logical
  /// Isolation**. It establishes a **Privileged Environment** by granting
  /// high clearance and enforcing full auditing, ensuring every transaction
  /// is recorded within the **Causal Trace**.
  ///
  /// ### When to use
  /// Use this for security‑critical operations – e.g., cryptography, PII
  /// processing, or administrative overrides.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'enclave'`
  /// - `domains: 'security'`
  /// - `subDomains: 'integrity-gate'`
  /// - `isNot: 'External_Signals,Unauthenticated_Telemetry'`
  /// - `sensitivity: Sensitivity.restricted`
  /// - `audit_level: AuditLevel.full`
  /// - `priority: 0` (infrastructure-level)
  ///
  /// ### Example
  /// ```dart
  /// final cryptoContext = Context.secureEnclave(
  ///   partOf: 'CryptoModule',
  ///   compliances: 'FIPS-140-2, PCI-DSS',
  ///   constraints: {'min_key_size': 2048},
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The hierarchical container or **Module** responsible for this enclave.
  /// - [compliance]: Regulatory or safety standards (e.g., 'SOC2', 'HIPAA').
  /// - [constraints]: Optional operational guardrails (e.g., rate limits).
  /// - [others]: Specialized security metadata or hardware IDs.
  factory Context.secureEnclave({
    required String partOf,
    required String compliances,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('enclave'),
        Ontology.domains.entry('security'),
        Ontology.subDomains.entry('integrity-gate'),
        Ontology.compliance.entry(compliances),
        Ontology.isNot.entry('External_Signals,Unauthenticated_Telemetry'),
      ],
      others: {
        'sensitivity': Sensitivity.restricted.name,
        'audit_level': AuditLevel.full.name,
        'priority': 0, // Enclaves operate at infrastructure-level precedence
        ...?constraints,
        ...?others,
      },
    );
  }

  /// Synthesizes a **Public Interface Blueprint** for boundary nodes
  /// interacting with external users, third-party systems, or unverified telemetry.
  ///
  /// This factory serves as the architectural standard for **Boundary Governance**.
  /// It establishes a **Sanitized Gateway** by optimizing for **High-Velocity Ingress**
  /// while maintaining strict ontological isolation from the system's core private state.
  ///
  /// ### When to use
  /// Use this for API gateways, webhook endpoints, or any component that
  /// receives external input.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'interface'`
  /// - `subDomains: 'ingress'`
  /// - `isNot: 'Internal_Commands,Private_State_Mutation'`
  /// - `sensitivity: Sensitivity.public`
  /// - `audit_level: AuditLevel.none`
  /// - `priority: 50`
  ///
  /// ### Example
  /// ```dart
  /// final apiContext = Context.publicInterface(
  ///   partOf: 'Public_Web_API',
  ///   domains: 'Web/v1',
  ///   stakeholders: 'Mobile_App_Users, Partner_SDK',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The identifier for this interface (e.g., 'RestApi', 'MobileApp').
  /// - [domains]: The functional domain classification (e.g., 'Web', 'Mobile').
  /// - [stakeholders]: A descriptor of the external entities authorized to interact.
  /// - [others]: Catch-all for protocol-specific metadata (e.g., rate limits).
  factory Context.publicInterface({
    required String partOf,
    required String domains,
    String? stakeholders,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('interface'),
        Ontology.domains.entry(domains),
        Ontology.subDomains.entry('ingress'),
        if (stakeholders != null) Ontology.stakeholders.entry(stakeholders),
        Ontology.isNot.entry('Internal_Commands,Private_State_Mutation'),
      ],
      others: {
        'sensitivity': Sensitivity.public.name,
        'audit_level': AuditLevel.none.name,
        'priority': 50, // Standard interface priority
        ...?others,
      },
    );
  }

  /// Synthesizes a **Shielded Cortex Blueprint** for high-reasoning nodes
  /// performing sensitive autonomous decisions.
  ///
  /// This factory is the standard for **Sovereign Logic Isolation**. It
  /// establishes a **Clean Room Environment** by enforcing strict [isNot]
  /// boundaries, ensuring that the node's **Reasoning Strategy** remains
  /// unpolluted by routine system telemetry or unverified background pulses.
  ///
  /// ### When to use
  /// Use this for autonomous decision‑making nodes that require a clean
  /// reasoning environment – e.g., financial trading, medical triage, or
  /// security policy resolution.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'cortex'`
  /// - `subDomains: 'reasoning-enclave'`
  /// - `isNot: 'Background_Noise,Unverified_Inference'`
  /// - `strategy: ReasoningStrategy.formal`
  /// - `sensitivity: Sensitivity.restricted`
  /// - `audit_level: AuditLevel.detailed`
  /// - `priority: 10`
  ///
  /// ### Example
  /// ```dart
  /// final tradingContext = Context.shieldedCortex(
  ///   partOf: 'Trading_Floor_A',
  ///   domains: 'Finance/HighFreq',
  ///   compliances: 'SEC, FINRA',
  ///   constraints: {'max_position': 1000000},
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The identifier for the governing organizational unit or module.
  /// - [domains]: The functional domain classification (e.g., 'Finance', 'Security').
  /// - [compliance]: Regulatory or safety standards being enforced (e.g., 'HIPAA').
  /// - [constraints]: Optional operational guardrails (e.g., 'max_latency_ms').
  /// - [others]: Catch-all for specialized logic metadata (e.g., model versions).
  factory Context.shieldedCortex({
    required String partOf,
    required String domains,
    required String compliances,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('cortex'),
        Ontology.domains.entry(domains),
        Ontology.subDomains.entry('reasoning-enclave'),
        Ontology.compliance.entry(compliances),
        Ontology.isNot.entry('Background_Noise,Unverified_Inference'),
      ],
      others: {
        'strategy': ReasoningStrategy.formal.name,
        'sensitivity': Sensitivity.restricted.name,
        'audit_level': AuditLevel.detailed.name,
        'priority': 10, // High reasoning priority
        ...?constraints,
        ...?others,
      },
    );
  }

  /// Synthesizes an **Ingestion Receptor Blueprint** for nodes specialized
  /// in normalizing and validating raw environmental stimuli.
  ///
  /// This factory is the architectural standard for **Perceptual Ingestion**.
  /// It optimizes for **Sensory Capture** by establishing broad [dataSources]
  /// and setting the ontological taxonomy to `sensor_receptor`, ensuring
  /// that incoming pulses are hydrated with the correct provenance before
  /// being distributed to the rest of the **System**.
  ///
  /// ### When to use
  /// Use this for sensor data ingestion, event streams, or any node that
  /// receives raw external data.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'sensor_receptor'`
  /// - `subDomains: 'Receptor'`
  /// - `audit_level: AuditLevel.minimal`
  /// - `sensitivity: Sensitivity.public`
  /// - `priority: 40`
  ///
  /// ### Example
  /// ```dart
  /// final sensorContext = Context.receptor(
  ///   dataSources: 'MQTT_Broker, IoT_Devices',
  ///   domains: 'Telemetry',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [dataSources]: The specific external origins (e.g., 'MQTT_Broker', 'User_Input_Stream').
  /// - [domains]: The functional area identifying where this receptor operates.
  /// - [others]: Catch-all for specialized sensor metadata (e.g., sample rate).
  factory Context.receptor({
    required String dataSources,
    required String domains,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.dataSources.entry(dataSources),
        Ontology.domains.entry(domains),
        Ontology.subDomains.entry('Receptor'),
        Ontology.taxonomy.entry('sensor_receptor'),
      ],
      others: {
        'audit_level': AuditLevel.minimal.name,
        'sensitivity': Sensitivity.public.name,
        'priority': 40, // Receptors run with slightly elevated priority
        ...?others,
      },
    );
  }

  /// Synthesizes an **Integrity Gate Blueprint** for nodes acting as the
  /// framework's "Judicial Branch."
  ///
  /// This factory is the architectural standard for **Security Governance**.
  /// It establishes a **Validation Barrier** by enforcing mandatory
  /// [AuditLevel.full], [Sensitivity.restricted], and administrative clearance,
  /// ensuring that no signal crosses into protected domains without a
  /// verifiable mandate.
  ///
  /// ### When to use
  /// Use this for policy enforcement points, validators, or any node that
  /// must strictly control access to protected resources.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'governance_gate'`
  /// - `subDomains: 'integrity-gate'`
  /// - `strategy: ReasoningStrategy.reflexive`
  /// - `sensitivity: Sensitivity.restricted`
  /// - `audit_level: AuditLevel.full`
  /// - `priority: 0`
  /// - `strict_mode: true`
  ///
  /// ### Example
  /// ```dart
  /// final auditGate = Context.integrityGate(
  ///   partOf: 'Treasury/Compliance',
  ///   compliances: 'SOX, Internal_Policy_v2',
  ///   constraints: {'fail_closed': true},
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The organizational unit, logical domain, or module this gate governs.
  /// - [compliance]: Regulatory or safety standards being enforced.
  /// - [constraints]: Optional operational parameters (e.g., 'fail_closed').
  /// - [others]: Catch-all for specialized regulatory metadata or encryption tags.
  factory Context.integrityGate({
    required String partOf,
    required String compliances,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('governance_gate'),
        Ontology.domains.entry('security'),
        Ontology.subDomains.entry('integrity-gate'),
        Ontology.compliance.entry(compliances),
      ],
      others: {
        'strategy': ReasoningStrategy.reflexive.name,
        'sensitivity': Sensitivity.restricted.name,
        'audit_level': AuditLevel.full.name,
        'priority': 0, // Governance gates operate at infrastructure-level precedence
        'strict_mode': true,
        ...?constraints,
        ...?others,
      },
    );
  }

  /// Synthesizes a **Homeostasis Blueprint** for nodes responsible for
  /// internal maintenance, resource balancing, and systemic health.
  ///
  /// This factory is the architectural standard for **Systemic Stability**.
  /// It establishes a **Regulatory Loop** by configuring nodes with high
  /// operational priority and reflexive reasoning, ensuring that the
  /// "Digital Organism" remains within its functional equilibrium.
  ///
  /// ### When to use
  /// Use this for background maintenance tasks – e.g., cache cleanup,
  /// memory management, heartbeat monitors, or self‑healing loops.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'stability_loop'`
  /// - `subDomains: 'Homeostasis'`
  /// - `strategy: ReasoningStrategy.reflexive`
  /// - `sensitivity: Sensitivity.internal`
  /// - `priority: 75`
  ///
  /// ### Example
  /// ```dart
  /// final cacheMonitor = Context.homeostasis(
  ///   partOf: 'System/Memory',
  ///   label: 'LruCacheMonitor',
  ///   constraints: {'max_memory_mb': 512},
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The system module, collection, or logical anchor this node maintains.
  /// - [label]: A unique human-readable identifier for the maintenance task.
  /// - [constraints]: Optional operational limits (e.g., 'cleanup_interval_ms').
  /// - [others]: Catch-all for specialized metabolic metadata or hardware metrics.
  factory Context.homeostasis({
    required String partOf,
    String? label,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('stability_loop'),
        Ontology.domains.entry('system'),
        Ontology.subDomains.entry('Homeostasis'),
      ],
      others: {
        'strategy': ReasoningStrategy.reflexive.name,
        'sensitivity': Sensitivity.internal.name,
        'priority': 75, // High priority maintenance
        if (label != null) 'label': label,
        ...?constraints,
        ...?others,
      },
    );
  }

  /// Synthesizes a **Sandbox Blueprint** for speculative reasoning, risk-free
  /// simulation, and non-destructive experimentation.
  ///
  /// This factory defines the standard for **Environment Isolation**.
  /// It establishes a **Simulation Workspace** where logic modules
  /// can model and validate **Reactive Update Cycle** outcomes without
  /// committing permanent mutations to the system's **Primary State Store**.
  ///
  /// ### When to use
  /// Use this for "what‑if" scenarios, dry‑run validations, or any
  /// non‑destructive testing.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'simulation_workspace'`
  /// - `subDomains: 'Sandbox'`
  /// - `strategy: ReasoningStrategy.probabilistic`
  /// - `ephemeral: true`
  /// - `sensitivity: Sensitivity.public`
  /// - `audit_level: AuditLevel.none`
  /// - `priority: 30`
  ///
  /// ### Non‑obvious
  /// Sandbox contexts are marked as `ephemeral` – they are not persisted
  /// and are automatically cleaned up when no longer in use.
  ///
  /// ### Example
  /// ```dart
  /// final testContext = Context.sandbox(
  ///   partOf: 'Finance/Strategies',
  ///   reason: 'Evaluating heuristic v2 performance',
  ///   readOnlyParent: true,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The system module or collection being simulated.
  /// - [reason]: The functional justification or hypothesis being tested.
  /// - [readOnlyParent]: If true, allows the sandbox to "see" the current
  ///   state of the principal without being able to modify it.
  /// - [others]: Catch-all for specialized simulation metadata.
  factory Context.sandbox({
    required String partOf,
    String? reason,
    bool readOnlyParent = true,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('simulation_workspace'),
        Ontology.subDomains.entry('Sandbox'),
      ],
      others: {
        'strategy': ReasoningStrategy.probabilistic.name,
        'reason': reason ?? 'SPECULATIVE_SIMULATION',
        'ephemeral': true,
        'read_only_parent': readOnlyParent,
        'sensitivity': Sensitivity.public.name,
        'audit_level': AuditLevel.none.name,
        'priority': 30, // Lower priority than live production logic
        ...?others,
      },
    );
  }

  /// Synthesizes an **Audit Observer Blueprint** for nodes specialized in
  /// non-repudiation, forensic logging, and compliance tracking.
  ///
  /// This factory is the architectural standard for **Systemic Accountability**.
  /// It establishes a **Passive Chronometer** by enforcing [AuditLevel.full]
  /// and [Sensitivity.private], ensuring that every signal traversing the
  /// switching fabric is captured without altering the primary state graph.
  ///
  /// ### When to use
  /// Use this for audit logging, compliance monitoring, or any node that
  /// must record every transaction for later analysis.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'audit_ledger'`
  /// - `subDomains: 'compliance-logging'`
  /// - `strategy: ReasoningStrategy.deterministic`
  /// - `sensitivity: Sensitivity.private`
  /// - `audit_level: AuditLevel.full`
  /// - `priority: 90` (background)
  ///
  /// ### Example
  /// ```dart
  /// final ledgerContext = Context.auditLog(
  ///   partOf: 'Treasury/Ledger',
  ///   compliances: 'PCI-DSS, SOC2',
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The module or system layer being audited.
  /// - [compliance]: Regulatory standards governing the audit (e.g., 'SOC2').
  /// - [others]: Specialized metadata for storage destination or retention policy.
  factory Context.auditLog({
    required String partOf,
    required String compliances,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('audit_ledger'),
        Ontology.domains.entry('maintenance'),
        Ontology.subDomains.entry('compliance-logging'),
        Ontology.compliance.entry(compliances),
      ],
      others: {
        'strategy': ReasoningStrategy.deterministic.name,
        'sensitivity': Sensitivity.private.name,
        'audit_level': AuditLevel.full.name,
        'priority': 90, // Low priority background task
        'retention_policy': 'standard',
        ...?others,
      },
    );
  }

  /// Synthesizes a **Transient Task Blueprint** for short-lived
  /// computational scenes or one-off agentic missions.
  ///
  /// This factory creates a context with an inherent **Temporal Lease**.
  /// It is the architectural standard for **Ephemeral Evolution**,
  /// allowing the framework to prune resources once the task's
  /// purpose is fulfilled.
  ///
  /// ### When to use
  /// Use this for one‑off tasks like data migrations, report generation,
  /// or any operation that should self‑destruct after a defined period.
  ///
  /// ### How it works
  /// The factory sets:
  /// - `taxonomy: 'transient_worker'`
  /// - `subDomains: 'Ephemeral_Task'`
  /// - `strategy: ReasoningStrategy.probabilistic`
  /// - `lease_duration_ms`: from the [lease] parameter
  /// - `auto_delete: true`
  /// - `priority: 60`
  ///
  /// ### Non‑obvious
  /// The `auto_delete` flag instructs the framework to automatically
  /// clean up the cell once the lease expires – you don't need to
  /// manually dispose of it.
  ///
  /// ### Example
  /// ```dart
  /// final taskContext = Context.transientTask(
  ///   partOf: 'System/Maintenance',
  ///   stakeholders: 'MigrationTeam',
  ///   lease: Duration(hours: 1),
  ///   constraints: {'batch_size': 1000},
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [partOf]: The module or collection the task is performing work for.
  /// - [stakeholders]: The entities (users or agents) responsible for the task.
  /// - [lease]: The duration for which the task environment remains valid.
  /// - [constraints]: Additional operational guardrails (e.g., 'max_retries').
  /// - [others]: Catch-all for specialized task metadata.
  ///
  /// ### Returns:
  /// A specialized [Context] configured for ephemeral execution with
  /// automatic resource reclamation logic.
  factory Context.transientTask({
    required String partOf,
    required String stakeholders,
    required Duration lease,
    Map<String, dynamic>? constraints,
    Map<String, dynamic>? others,
  }) {
    return Context.fromEntries(
      [
        Ontology.partOf.entry(partOf),
        Ontology.taxonomy.entry('transient_worker'),
        Ontology.stakeholders.entry(stakeholders),
        Ontology.subDomains.entry('Ephemeral_Task'),
      ],
      others: {
        'strategy': ReasoningStrategy.probabilistic.name,
        'lease_duration_ms': lease.inMilliseconds,
        'auto_delete': true,
        'priority': 60, // Standard background task priority
        ...?constraints,
        ...?others,
      },
    );
  }

  /// Synthesizes an **Ontological Specialization** of the current [Context],
  /// refining its governance dimensions to create a new branch in the
  /// system's **Causal Trace**.
  ///
  /// This method is the primary engine for **Functional Refinement** within
  /// the **Switching Fabric**. It allows a [Cell] or system process to
  /// produce a more specialized authority environment for its children
  /// or specialized sub-tasks, while maintaining an immutable link to its
  /// ancestral origins.
  ///
  /// ### When to use
  /// Use this when you need to create a refined context – e.g., to restrict
  /// constraints or change the sub‑domain for a deputy.
  ///
  /// ### How it works
  /// You provide a resolver function that returns a new governance entry
  /// for any evolvable dimension you want to change. Dimensions you don't
  /// touch are inherited from the current context.
  ///
  /// ### Non‑obvious
  /// Only dimensions marked `evolvable: true` can be changed – trying to
  /// change a static pillar will have no effect. This is by design.
  ///
  /// ### Parameters:
  /// - [resolver]: A callback that reconciles requested [Governance]
  ///   dimensions against the evolved context's state. Returning `null`
  ///   signals inheritance from the parent.
  /// - [others]: Optional map for domain-specific metadata (e.g.,
  ///   deployment environment, regional tags) to be included in the refinement.
  ///
  /// ### Returns:
  /// A specialized [Context] that represents a refined authority branch
  /// in the system's **Causal Lineage**.
  Context evolve(covariant GovernanceEntry? Function(Governance evolvable) resolver, {Map<String, dynamic>? others});

  /// Traverses the hierarchical tree to produce a **Causal Trace** of a specific
  /// **knowledge dimension** associated with this context.
  ///
  /// This method provides the architectural **Rationale Path**, mapping the
  /// journey of a specific [Governance] marker from the root system node
  /// down to the current specialized leaf.
  ///
  /// ### When to use
  /// This is useful for debugging – to see how a particular dimension
  /// has evolved across the context hierarchy.
  ///
  /// ### How it works
  /// The method walks up the `parent` chain and collects values for the
  /// specified [Governance] dimension, returning them in chronological order
  /// (root first).
  ///
  /// ### Parameters:
  /// - [dimension]: The [Governance] type-level marker to trace (e.g.,
  ///   `Governance.subDomains`, `Governance.compliances`).
  ///
  /// ### Returns:
  /// An ordered [List] of strings representing the evolution of the requested
  /// **dimension** from the system root down to the current node.
  List<String> lineage(covariant Governance dimension);

  /// The categorical archetype or "Kind" of functional operation this context
  /// represents.
  ///
  /// In the **Software Engineering (SE) Pivot**, [type] aligns the boundary
  /// with the signal, mirroring the `type` parameter found in [Pulse.type].
  /// It allows for high-level **Scene-Driven Governance** where
  /// **Integrity Gates** can screen entire classes of interactions
  /// (e.g., 'security', 'telemetry', 'command') without inspecting the soma.
  ///
  /// ### See Also:
  /// * [Ontology.type]
  String? get type;

  /// The unique instance name or specific label assigned to this context.
  ///
  /// While [type] defines *what* a thing is, [identity] defines *which*
  /// specific thing it is. This dimension is crucial for **Identity
  /// Transparency** and **Forensic Traceability**, as it allows the
  /// **Switching Fabric** to distinguish between multiple nodes of the
  /// same functional category.
  ///
  /// During the creation of a **Deputy**, the [identity] is typically evolved
  /// to reflect its specialized role (e.g., 'Auth_Node_ReadOnly').
  ///
  /// ### See Also:
  /// * [Ontology.identity]
  String? get identity;

  /// The fundamental categorical identity or functional archetype of this context.
  ///
  /// ### See Also:
  /// * [Ontology.taxonomy]
  String? get taxonomy;

  /// The structural position or network role of this context within the
  /// organizational hierarchy.
  ///
  /// ### See Also:
  /// * [Ontology.topology]
  String? get topology;

  /// The origins of information (synthetic or organic) that this context
  /// is permitted to ingest.
  ///
  /// ### See Also:
  /// * [Ontology.dataSources]
  String? get dataSources;

  /// Operational guardrails and logic parameters governing resource usage
  /// and agent behavior.
  ///
  /// ### See Also:
  /// * [Ontology.constraints]
  Map<String, dynamic>? get constraints;

  /// The entities, users, or autonomous agents responsible for or impacted
  /// by this context's execution.
  ///
  /// ### See Also:
  /// * [Ontology.stakeholders]
  String? get stakeholders;

  /// The primary high-level functional areas or business namespaces this
  /// context belongs to.
  ///
  /// ### See Also:
  /// * [Ontology.domains]
  String? get domains;

  /// Granular subdivisions of the primary [domains], used for precise
  /// scoping of authority.
  ///
  /// ### See Also:
  /// * [Ontology.subDomains]
  String? get subDomains;

  /// The schema or ontological version used to interpret the metadata
  /// within this context.
  ///
  /// ### See Also:
  /// * [Ontology.version]
  String? get version;

  /// Explicit prohibitions defining what this context is strictly
  /// forbidden from becoming or accessing.
  ///
  /// ### See Also:
  /// * [Ontology.isNot]
  String? get isNot;

  /// The regulatory standards or compliance frameworks (e.g., GDPR, PCI-DSS)
  /// governing this context.
  ///
  /// ### See Also:
  /// * [Ontology.compliance]
  String? get compliance;

  /// The parent system module or container that this context
  /// represents a logical slice of.
  ///
  /// ### See Also:
  /// * [Ontology.partOf]
  String? get partOf;

  /// Accesses a specific **Governance Pillar** or ontological dimension by its
  /// type-level marker, supporting the **Flyweight Pattern** and generic reasoning.
  ///
  /// In the framework's **Scene-Driven Ontology**, the `[]` operator provides
  /// a unified interface for querying the environment without requiring
  /// knowledge of specific getter methods. It is the primary mechanism for
  /// **Reflection-less Inspection** of a cell's governance state.
  ///
  /// ### When to use
  /// This is useful when you need to access a governance dimension
  /// dynamically – e.g., in generic code that doesn't know the specific
  /// getter name.
  ///
  /// ### How it works
  /// The operator looks up the dimension in the context's record, walking
  /// up the parent chain if necessary.
  ///
  /// ### Example
  /// ```dart
  /// final domain = context[Ontology.domains];
  /// print('Operating in: $domain');
  /// ```
  ///
  /// ### Parameters:
  /// - [dimension]: The [Governance] type-level marker to retrieve.
  ///
  /// ### Returns:
  /// The value associated with the requested [dimension], or `null` if not defined.
  dynamic operator [](Governance dimension);

}