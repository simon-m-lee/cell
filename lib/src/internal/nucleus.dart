// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

/// A structured grouping of the **Governance & Logic** properties that define
/// a node's operational identity and can be cascaded through the inheritance chain.
///
/// In the framework's SE-centric model, an [InheritableHandle] represents the
/// **Blueprint Signature** of a [Nucleus]. These properties are bundled to
/// facilitate the **Prototype Inheritance Pattern**, allowing a
/// [Nucleus.clone] or [Nucleus.evolve] operation to efficiently pass down
/// or override the core pillars of a node's behavior.
///
/// ### When to use
/// You rarely need to construct this directly – it's an internal record type
/// used by the framework to pass inheritable properties around.
///
/// ### How it works
/// It bundles the five pillars that define a node's behavior:
/// - `receptor`: transformation logic.
/// - `testRule`: validation gate.
/// - `context`: authority and domain.
/// - `bind`: upstream dependency.
/// - `ephemeralPolicy`: lifecycle TTL.
///
/// The framework uses this for flyweight sharing – when you create a deputy,
/// the new nucleus can inherit these from its principal without copying them.
///
/// ### Non‑obvious
/// - This is a record, not a class – it's lightweight and immutable.
/// - The framework resolves inherited properties by walking up the `principal`
///   chain; this record is the unit of transfer.
///
/// See also: [Nucleus], [Nucleus.evolve].
typedef InheritableHandle = ({
  /// The upstream [Cell] providing the primary data ingress.
  Cell? bind,

  /// The governing [Context] defining the node's authority and domain.
  Context context,

  /// The [Receptor] logic responsible for state transformation.
  Receptor receptor,

  /// The [TestCell] validation rule acting as the node's **Integrity Gate**.
  TestCell testRule,

  /// The [EphemeralPolicy] managing the node's lifecycle and TTL.
  EphemeralPolicy? ephemeralPolicy
});

class Inheritable {

}

class _Nucleus extends NucleusBase {

  _Nucleus({
    super.ephemeralPolicy,
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.user,

    super.forceLock,
    super.principal

  }) : super();

  _Nucleus.evolve({
    super.ephemeralPolicy,

    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.user,

    Nucleus? override,
    required super.principal
  }) : super.evolve();

  _Nucleus.fromRecord(super.record) : super.fromRecord();

  @override
  Nucleus get clone {
    final receptor = get<Receptor?>(() => record.mask.inheritable.receptor, orElse: null);
    final testRule = get<TestCell?>(() => record.mask.inheritable.testRule, orElse: null);
    final context = get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _Nucleus(
        context: context ?? Context.system,
        receptor: (receptor ?? this.receptor).clone,
        testRule: testRule ?? TestCell.allowAll,
        synapses: synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
        principal: this
    );
  }

}

/// The foundational base implementation of the [Nucleus] contract, providing
/// a memory-optimized storage engine for reactive cell properties.
///
/// [NucleusBase] serves as the architectural core of the framework's property
/// management system. It implements the **Flyweight** and **Prototype** patterns
/// by utilizing Dart **Records** and **Bitmask Optimization** to store only
/// the specific properties that deviate from framework defaults.
///
/// ### When to use
/// You rarely interact with this directly – it's the base class for all nuclei.
/// Use [Cell] or [Cell.state] factories; they handle nuclei for you.
///
/// ### How it works
/// - It stores cell configuration (context, receptor, testRule, etc.) in a
///   compact record that omits default values.
/// - Supports prototype inheritance via a `principal` link – if a property
///   isn't found locally, it walks up the chain.
/// - Provides low-level getters for all nucleus properties.
///
/// ### Non‑obvious
/// - The internal record is immutable; changes create a new nucleus.
/// - The `forceLock` parameter in the primary constructor defaults to `true`,
///   but in `evolve` it's typically inherited from the principal.
/// - The `mask` static method is the engine behind flyweight storage.
///
/// See also: [Nucleus], [_Nucleus], [Nucleolus].
abstract class NucleusBase implements Nucleus {

  // ignore: strict_top_level_inference, prefer_typing_uninitialized_variables
  final record;

  /// The primary constructor for [NucleusBase], initializing a memory-optimized
  /// tiered property storage for a reactive [Cell].
  ///
  /// This constructor serves as the architectural entry point for defining a
  /// node's identity, execution context, and operational logic. It is designed
  /// to satisfy the framework's **Structural Flyweight Pattern**, ensuring that
  /// a [Nucleus] consumes only the memory required for its specific deviation
  /// from system defaults.
  ///
  /// ### 1. Purpose: Zero-Overhead Configuration
  /// The fundamental purpose of this constructor is to achieve **Resource Efficiency**
  /// by partitioning property storage into three distinct, manageable segments:
  ///
  /// *   **The Inheritable Segment**: Contains logic-defining properties (`context`,
  ///     `receptor`, `testRule`) that define the **Operational Authority**.
  ///     These are bundled to allow seamless sharing or overriding during
  ///     [Nucleus.evolve] operations.
  /// *   **The User Segment**: A dedicated record slot for developer-defined
  ///     metadata or custom property sets, keeping user state distinct from
  ///     framework-level reactive logic.
  /// *   **The Instance Segment**: Contains properties fundamentally unique to
  ///     a specific node instance, such as its synchronization `lock`, its
  ///     observer registry (`synapses`), and its upstream `bind` dependency.
  ///
  /// ### 2. Functional Behaviors
  /// *   **Structural Compression**: This constructor delegates to the internal
  ///     `mask` utility, which evaluates each argument against framework defaults.
  ///     If a property matches the default (e.g., [Context.system]), it is
  ///     omitted from the record entirely, eliminating the "Nullable Field Tax."
  /// *   **Concurrency Governance**: Unless [forceLock] is explicitly set to
  ///     `true`, the constructor ensures the nucleus is equipped with a fresh
  ///     atomic `Lock`. This lock is the primary synchronization mechanism
  ///     guaranteeing that [Pulse] processing is atomic and thread-safe.
  /// *   **Logic Purity**: If the provided [receptor] is already "activated"
  ///     (bound to a live cell), the constructor automatically emits
  ///     `receptor.copy`. This prevents logic leakage and ensures each blueprint
  ///     remains a clean, unactivated template.
  /// *   **Synapses Lifecycle**: When [synapses] is provided as the
  ///     [Synapses.enabled] template, a fresh container is instantiated,
  ///     ensuring every live node maintains its own private **Signal Distribution Network**.
  ///
  /// ### 3. Memory Optimization
  /// By utilizing untyped Dart Records instead of traditional class fields,
  /// the resulting `_record` lacks the overhead of object headers for empty
  /// or default fields. In high-density reactive models, this allows the
  /// heap footprint to scale linearly with actual architectural complexity
  /// rather than a fixed class-definition cost.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: Defines the **Lifecycle Governance** (TTL/Hops)
  ///   for the node.
  /// * [bind]: The upstream [Cell] to observe. Establishes the **Ingress Link**.
  /// * [context]: The **Operational Authority** and environmental metadata.
  /// * [receptor]: The **Transformation Pipeline** gatekeeper.
  /// * [testRule]: The **Policy Guard** for state validation.
  /// * [synapses]: Manages the **Signal Distribution Network**.
  /// * [forceLock]: If `true`, prevents the creation of a new synchronization
  ///   primitive (used when sharing a lock with a [principal]).
  /// * [user]: Optional record for extension-specific metadata.
  /// * [principal]: Optional ancestor [Nucleus] for **Prototype Inheritance**.
 NucleusBase({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,

    bool forceLock = true,

    Record? user,

    Nucleus? principal
  }) : record = principal != null
     ? (local: mask(bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user), principal: principal)
     : (local: mask(bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user)
  );

  /// Reconstitutes a [NucleusBase] from a raw **Flyweight Record**, facilitating
  /// the restoration of architectural blueprints from a compressed state.
  ///
  /// The [NucleusBase.fromRecord] constructor is the framework's primary mechanism for
  /// **Structural Deserialization**. By utilizing the **Flyweight Strategy**, it
  /// allows for the creation of persistent, static, or cloned reactive
  /// configurations with zero runtime calculation overhead, bypassing the
  /// property masking logic.
  ///
  /// ### When to use
  /// - **Structural Evolution**: Efficiently creating a new nucleus from the
  ///   resolved record of a principal during [Nucleus.evolve] or [Nucleus.clone].
  /// - **Flyweight Reification**: Instantiating static nuclei (like [Nucleolus])
  ///   at compile-time to eliminate runtime heap allocation pressure.
  /// - **Module Restoration**: Re-hydrating a nucleus from a persisted
  ///   **Causal Trace** or snapshot for system auditing and recovery.
  /// - **Low-Level Trust**: When property sets have already been resolved or
  ///   optimized by other internal framework processes.
  ///
  /// ### How it works
  /// 1. **Direct State Injection**: Bypasses the standard `mask` utility and
  ///    bitmask optimization, assigning the [record] directly to internal storage.
  /// 2. **Structural Hydration**: Populates the node's blueprint using a tiered
  ///    record structure containing `local` properties and an optional
  ///    `principal` for inheritance.
  /// 3. **Hydration Logic**: It assumes the **Flyweight Optimization** has
  ///    already been applied to the input, allowing for immediate reification.
  ///
  /// ### Non‑obvious
  /// - **Trust Model**: Operates on a "Trusted Input" model; it does not validate
  ///   that mandatory pillars (like [testRule]) are present if the [principal]
  ///   is missing.
  /// - **Deterministic Identity**: By utilizing `const` records, the framework
  ///   maintains referential equality across the graph, ensuring a
  ///   stable **Causal Provenance**.
  /// - **Zero-Cost Path**: Provides a zero-latency path for restoring nuclei
  ///   within performance-critical reactive waves.
  /// - **Manual Pillar Resolution**: Property resolution will fall back to the
  ///   `principal` defined within the record, not an external argument.
  ///
  /// ### Example
  /// ```dart
  /// // Primarily used internally for structural evolution:
  /// const optimizedNucleus = NucleusBase.fromRecord(
  ///   record: (
  ///     local: (context: Context.module, receptor: MyCustomReceptor()),
  ///     principal: Nucleus.empty
  ///   )
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [record]: **The Blueprint Signature.** The internal data structure serving
  ///   as the node's identity and governance configuration.
  ///
  /// ### Returns:
  /// A [NucleusBase] instance reconstituted from its internal state.
  ///
  /// ### See Also:
  /// * [NucleusBase]: The standard parameter-based constructor.
  /// * [Nucleus.evolve]: For hierarchical property inheritance.
  /// * [Nucleolus]: For static, compile-time blueprint reification.
  const NucleusBase.fromRecord(this.record);

  /// Creates a specialized **Architectural Extension** of an existing [Nucleus] to
  /// support hierarchical property inheritance and contextual overrides.
  ///
  /// This constructor implements the **Prototype Inheritance Pattern** within the
  /// property system, allowing a derived nucleus to inherit its structural
  /// identity and core behavioral logic from a [principal] while layering on
  /// localized configuration overrides.
  ///
  /// ### When to use
  /// - **Contextual Specialization**: When many nodes share common logic (security
  ///   tiers, storage strategies) but differ in a single specific aspect.
  /// - **Creating Deputies**: Generating restricted-access or read-only views
  ///   of a cell that share data but use different [testRule] guards.
  /// - **Contextual Projections**: Projecting a system-level state into a
  ///   user-level view by overriding the [context] pillar.
  /// - **Behavioral Shadowing**: Overriding a [receptor] to add transformation
  ///   logic without altering the principal's original behavior.
  ///
  /// ### How it works
  /// 1. **The Linker Record**: It creates a multi-tiered record that points back
  ///    to the [principal] for any property not explicitly defined locally.
  /// 2. **Resolution Chain**: When a property is accessed, the system employs
  ///    a "walk-up" strategy: Local Segment -> Principal Segment ->
  ///    [Nucleus.empty] (Global Defaults).
  /// 3. **Shared Atomicity**: By default, extensions share the [principal]'s
  ///    atomic [Lock], ensuring they maintain a single atomic boundary for
  ///    complex graph transitions.
  /// 4. **Memory Optimization**: It avoids re-allocating a full property set,
  ///    storing only the "delta" between the extension and its prototype.
  ///
  /// ### Non‑obvious
  /// - **Binding Specificity**: Upstream bindings ([bind]) are instance-specific
  ///   and are **not** inherited from the principal to prevent accidental
  ///   graph recursion.
  /// - **Isolation Branching**: If an [override] is provided with its own lock,
  ///   the extension branches into an independent synchronization domain.
  /// - **Shadowing Rules**: Providing a `null` value for an inheritable pillar
  ///   (like [testRule]) typically triggers a fallback to the principal,
  ///   rather than clearing the property.
  /// - **Trust Model**: The framework assumes the [principal] is already
  ///   valid and optimized, skipping redundant bitmask checks during evolution.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Lifecycle Governance.** Defines when the resulting
  ///   cell should be automatically invalidated.
  /// * [bind]: **Upstream Dependency.** The cell this node monitors (not inherited).
  /// * [context]: **Operational Authority.** The execution tier (inherits from
  ///   [principal] if null).
  /// * [receptor]: **Transformation Pipeline.** The logic for processing pulses.
  /// * [testRule]: **Policy Guard.** Integrity rules for state changes (inherits
  ///   from [principal] if null).
  /// * [synapses]: **Egress Network.** Manages the observer registry for the
  ///   extension.
  /// * [user]: **Ad-hoc Metadata.** Optional extension-specific storage.
  /// * [override]: **Pre-compiled Blueprint.** A nucleus whose record will be
  ///   directly adopted.
  /// * [principal]: **The Prototype Source.** The nucleus providing structural
  ///   inheritance.
  ///
  /// ### Returns:
  /// A [Nucleus] instance representing a **Hierarchical Property Extension**.
  ///
  /// ### See Also:
  /// * [Nucleus.evolve]: The high-level extension method.
  /// * [DeputyContext.evolve]: For specializing security and mandate dimensions.
  /// * [NucleusBase.fromRecord]: For restoring evolved nuclei from state.
  NucleusBase.evolve({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context? context,
    Receptor? receptor,
    TestCell? testRule,
    Synapses? synapses,
    Record? user,

    Nucleus? override,
    required Nucleus principal
  }) : this.fromRecord((
      local: (override as NucleusBase?)?.record.local ?? NucleusBase.mask(bind: bind,
          context: context,
          receptor: receptor, testRule: testRule, synapses: synapses, user: user, ephemeralPolicy: ephemeralPolicy),
      principal: principal
  ));

  void _propagate(PulseBase pulse) {
    if (synapses == Synapses.disabled || synapses.isEmpty) {
      pulse._complete();
      return;
    }
    synapses.call(pulse);
  }

  @override
  bool activate(Cell cell) {
    try {
      if (identical(cell._nucleus, this) ) {
        return receptor.activate(cell);
      }
    } catch (_) {}
    return false;
  }

  @override
  bool get isActivated {
    try {
      // ignore: unnecessary_null_comparison
      return cell != null;
    } catch (_) {}
    return false;
  }

  @override
  bool get isInvalidated => _ephemeralPolicy?.isInvalidated ?? false;

  @override
  bool get isGoverned => receptor.isGoverned;

  @override
  Lock? get lock => get<Lock?>(() => record.local.lock, fallback: () => principal?.lock, orElse: null);

  @override
  Record? get user => get<Record?>(() => record.local.user, fallback: () => principal?.user, orElse: null);

  @override
  InheritableHandle get inheritable {
    return (bind: bind, context: context, receptor: receptor, testRule: testRule, ephemeralPolicy: _ephemeralPolicy);
  }

  @override
  Cell get cell => get<Cell>(() => record.local.cell.value, fallback: () => principal?.cell);

  @override
  Synapses get synapses => get<Synapses>(() => record.local.synapses, orElse: Synapses.disabled);

  @override
  Cell? get bind => get<Cell?>(() => record.local.bind, orElse: null);

  @override
  Receptor get receptor {
    return get<Receptor>(() => record.local.inheritable.receptor, fallback: () => principal?.receptor, orElse: Receptor.passThrough);
  }

  @override
  TestCell get testRule {
    return get<TestCell>(() => record.local.inheritable.testRule,
        fallback: () => principal?.testRule, orElse: TestCell.allowAll);
  }

  @override
  Context get context => get<Context>(() => record.local.inheritable.context,
      fallback: () => principal?.context, orElse: Context.system
  );

  @override
  Nucleus? get principal => get<Nucleus?>(() => record.principal, orElse: null);

  @override
  DateTime get timestamp => record.timestamp;

  EphemeralPolicy? get _ephemeralPolicy {
    return get<EphemeralPolicy?>(() => record.local.inheritable.ephemeralPolicy,
        fallback: () => (principal as NucleusBase?)?._ephemeralPolicy,
        orElse: null
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Nucleus) return false;

    Nucleus? p = this;
    while(p?.principal != null) {
      p = p!.principal;
    }
    Nucleus? p_ = other;
    while(p_?.principal != null) {
      p_ = p_!.principal;
    }

    return identical(p, p_);
  }

  @override
  int get hashCode => record.hashCode;

  /// Generates a memory-optimized, multi-tiered [Record] that serves as the
  /// fundamental state and behavior definition for a [Nucleus].
  ///
  /// This static helper is the core engine of the framework's **Structural
  /// Flyweight Pattern**. It translates high-level configuration parameters
  /// into a strictly typed, nested Dart [Record] to minimize memory pressure.
  ///
  /// ### When to use
  /// Use `mask` when you need to synthesize the physical storage for a nucleus,
  /// typically during:
  /// - **Nucleus Initialization**: Defining the blueprint for a new reactive node.
  /// - **Structural Evolution**: Creating specialized extensions or deputies
  ///   with localized overrides.
  /// - **Framework Bootstrapping**: Defining static, compile-time nuclei
  ///   with zero runtime allocation overhead.
  ///
  /// ### How it works
  /// 1. **Dual-Stage Bitmasking**: Translates the provided parameters into
  ///    numeric bitsets (a 4-bit `inheritableMask` and a 6-bit composition `mask`).
  /// 2. **Nullable Field Omission**: Instead of a class with multiple nullable
  ///    fields, it uses Dart's `switch` expressions to allocate a record
  ///    containing *only* the specific fields that are non-default. This
  ///    effectively eliminates the "Nullable Field Tax."
  /// 3. **Tiered Segregation**:
  ///    - **Inheritable Segment**: Logic-defining properties ([context],
  ///      [receptor], [testRule], [ephemeralPolicy]) that can be inherited.
  ///    - **Local Segment**: Instance-specific anchors ([bind], [synapses],
  ///      [lock]) and metadata ([user], [others]).
  ///
  /// ### Non‑obvious
  /// - **Receptor Auto-Cloning**: If the provided [receptor] is already
  ///   "activated" (bound to another cell), `mask` automatically clones it
  ///   to ensure independent logic states for the new node.
  /// - **Synapses Provisioning**: Passing [Synapses.enabled] triggers the
  ///   allocation of a new registry, ensuring every node has a unique
  ///   egress network for its dependents.
  /// - **Lock Injection**: By default, it allocates a new reentrant [Lock]
  ///   to serve as the node's atomic boundary, unless [forceLock] is `true`.
  /// - **Timestamping**: Every record is tagged with a `timestamp` to
  ///   facilitate causal ordering and cache invalidation.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Lifecycle Guard.** Defines when the nucleus
  ///   should be invalidated.
  /// * [bind]: **Upstream Anchor.** The cell this node monitors in the DAG.
  /// * [context]: **Governance Tier.** The execution authority (defaults to
  ///   [Context.system]).
  /// * [receptor]: **Transformation Logic.** The pipeline processing
  ///   incoming pulses.
  /// * [testRule]: **Integrity Gate.** Validation predicate for state changes.
  /// * [synapses]: **Egress Registry.** The observer network for signal
  ///   propagation.
  /// * [forceLock]: **Atomic Control.** If `true`, suppresses the allocation
  ///   of a new synchronization lock.
  /// * [user]: **Extension Data.** Compact storage for metadata or specialized
  ///   state.
  /// * [others]: **Overflow Slot.** Reserved for framework extensions and
  ///   ad-hoc records.
  ///
  /// ### Returns:
  /// A compact [Record] representing the physical storage for the nucleus.
  ///
  /// ### See Also:
  /// * [NucleusBase]: The primary implementation utilizing this masking logic.
  /// * [Lock]: The synchronization primitive injected by this method.
  static Record mask({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context? context,
    Receptor? receptor,
    TestCell? testRule,
    Synapses? synapses,

    bool forceLock = false,

    Record? user,
    dynamic others
  }) {

    if (synapses == Synapses.enabled) {
      synapses = Synapses();
    }

    if (receptor != null) {
      if (receptor == Receptor.passThrough) {
        receptor = _Receptor();
      } else
        if (receptor.isActivated) {
        receptor = receptor.clone;
      }
    }

    final inheritableMask = (
        (context != null && context != Context.system         ? 1 : 0) |
        (receptor != null && receptor != Receptor.passThrough ? 2 : 0) |
        (testRule != null && testRule != TestCell.allowAll    ? 4 : 0) |
        (ephemeralPolicy != null                              ? 8 : 0)
    );

    final inheritable = switch (inheritableMask) {
      0 => (),
      1 => (context: context),
      2 => (receptor: receptor),
      3 => (context: context, receptor: receptor),
      4 => (testRule: testRule),
      5 => (context: context, testRule: testRule),
      6 => (receptor: receptor, testRule: testRule),
      7 => (context: context, receptor: receptor, testRule: testRule),
      8 => (ephemeralPolicy: ephemeralPolicy),
      9 => (ephemeralPolicy: ephemeralPolicy, context: context),
      10 => (ephemeralPolicy: ephemeralPolicy, receptor: receptor),
      11 => (ephemeralPolicy: ephemeralPolicy, context: context, receptor: receptor),
      12 => (ephemeralPolicy: ephemeralPolicy, testRule: testRule),
      13 => (ephemeralPolicy: ephemeralPolicy, context: context, testRule: testRule),
      14 => (ephemeralPolicy: ephemeralPolicy, receptor: receptor, testRule: testRule),
      15 => (ephemeralPolicy: ephemeralPolicy, context: context, receptor: receptor, testRule: testRule),
      _ => ()
    };

    final mask = (
        (inheritableMask != 0  ? 1 : 0) |
        (user != null         ? 2 : 0) |
        (forceLock             ? 4 : 0) |
        (synapses != null && synapses != Synapses.disabled    ? 8 : 0) |
        (bind != null                     ? 16 : 0) |
        (others != null                   ? 32 : 0)
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return switch (mask) {
      0 => (timestamp: timestamp),
      1 => (timestamp: timestamp, inheritable: inheritable),
      2 => (timestamp: timestamp, user: user),
      3 => (timestamp: timestamp, inheritable: inheritable, user: user),
      4 => (timestamp: timestamp, lock: Lock(reentrant: true)),
      5 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true)),
      6 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true)),
      7 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true)),
      8 => (timestamp: timestamp, synapses: synapses),
      9 => (timestamp: timestamp, inheritable: inheritable, synapses: synapses),
      10 => (timestamp: timestamp, user: user, synapses: synapses),
      11 => (timestamp: timestamp, inheritable: inheritable, user: user, synapses: synapses),
      12 => (timestamp: timestamp, lock: Lock(reentrant: true), synapses: synapses),
      13 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), synapses: synapses),
      14 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), synapses: synapses),
      15 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), synapses: synapses),
      16 => (timestamp: timestamp, bind: bind),
      17 => (timestamp: timestamp, inheritable: inheritable, bind: bind),
      18 => (timestamp: timestamp, user: user, bind: bind),
      19 => (timestamp: timestamp, inheritable: inheritable, user: user, bind: bind),
      20 => (timestamp: timestamp, lock: Lock(reentrant: true), bind: bind),
      21 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), bind: bind),
      22 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), bind: bind),
      23 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), bind: bind),
      24 => (timestamp: timestamp, synapses: synapses, bind: bind),
      25 => (timestamp: timestamp, inheritable: inheritable, synapses: synapses, bind: bind),
      26 => (timestamp: timestamp, user: user, synapses: synapses, bind: bind),
      27 => (timestamp: timestamp, inheritable: inheritable, user: user, synapses: synapses, bind: bind),
      28 => (timestamp: timestamp, lock: Lock(reentrant: true), synapses: synapses, bind: bind),
      29 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), synapses: synapses, bind: bind),
      30 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), synapses: synapses, bind: bind),
      31 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), synapses: synapses, bind: bind),

      32 => (timestamp: timestamp, others: others),
      33 => (timestamp: timestamp, inheritable: inheritable, others: others),
      34 => (timestamp: timestamp, user: user, others: others),
      35 => (timestamp: timestamp, inheritable: inheritable, user: user, others: others),
      36 => (timestamp: timestamp, lock: Lock(reentrant: true), others: others),
      37 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), others: others),
      38 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), others: others),
      39 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), others: others),
      40 => (timestamp: timestamp, synapses: synapses, others: others),
      41 => (timestamp: timestamp, inheritable: inheritable, synapses: synapses, others: others),
      42 => (timestamp: timestamp, user: user, synapses: synapses, others: others),
      43 => (timestamp: timestamp, inheritable: inheritable, user: user, synapses: synapses, others: others),
      44 => (timestamp: timestamp, lock: Lock(reentrant: true), synapses: synapses, others: others),
      45 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), synapses: synapses, others: others),
      46 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), synapses: synapses, others: others),
      47 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), synapses: synapses, others: others),

      48 => (timestamp: timestamp, bind: bind, others: others),
      49 => (timestamp: timestamp, inheritable: inheritable, bind: bind, others: others),
      50 => (timestamp: timestamp, user: user, bind: bind, others: others),
      51 => (timestamp: timestamp, inheritable: inheritable, user: user, bind: bind, others: others),
      52 => (timestamp: timestamp, lock: Lock(reentrant: true), bind: bind, others: others),
      53 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), bind: bind, others: others),
      54 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), bind: bind, others: others),
      55 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), bind: bind, others: others),
      56 => (timestamp: timestamp, synapses: synapses, bind: bind, others: others),
      57 => (timestamp: timestamp, inheritable: inheritable, synapses: synapses, bind: bind, others: others),
      58 => (timestamp: timestamp, user: user, synapses: synapses, bind: bind, others: others),
      59 => (timestamp: timestamp, inheritable: inheritable, user: user, synapses: synapses, bind: bind, others: others),
      60 => (timestamp: timestamp, lock: Lock(reentrant: true), synapses: synapses, bind: bind, others: others),
      61 => (timestamp: timestamp, inheritable: inheritable, lock: Lock(reentrant: true), synapses: synapses, bind: bind, others: others),
      62 => (timestamp: timestamp, user: user, lock: Lock(reentrant: true), synapses: synapses, bind: bind, others: others),
      63 => (timestamp: timestamp, inheritable: inheritable, user: user, lock: Lock(reentrant: true), synapses: synapses, bind: bind, others: others),

      _ => ()
    };
  }

}

/// A semantic type alias representing the framework's **Zero-Overhead Root**
/// and the terminal ancestor of all reactive blueprints.
///
/// [NucleusSimplest] acts as the formal bridge to [Nucleolus], providing a
/// stable type signature for the most primitive, unconfigured state of a
/// reactive node. It serves as the baseline for the **Structural Flyweight
/// Pattern**, ensuring that default cells do not incur unique memory costs.
///
/// ### When to use
/// - **Root of Inheritance**: Used as the terminal `principal` in any
///   [Nucleus] hierarchy to stop recursive property lookups.
/// - **Default Allocation**: Used automatically by [Nucleus.empty] when a
///   cell requires framework-standard behavior without custom overrides.
/// - **Semantic Tagging**: Use when you need to explicitly denote that a
///   component operates under the system's baseline governance model
///   (e.g., [Context.system], [Receptor.passThrough]).
///
/// ### How it works
/// 1. **Structural Alias**: Maps directly to the [Nucleolus] constant class,
///    linking the alias to a transitively immutable singleton.
/// 2. **Terminal Boundary**: Because the underlying implementation returns
///    `null` for its principal, this type marks the functional end of any
///    reactive property walk.
/// 3. **Flyweight Reification**: It enables the framework to share a single
///    pre-compiled memory address for every "simplest" node in the graph.
///
/// ### Non‑obvious
/// - **Statelessness**: A nucleus of this type contains no local
///   bindings ([Cell.bind]) or egress synapses, ensuring it consumes
///   minimal resources even in massive dependency graphs.
/// - **Constant-Time Resolution**: Property access on this type bypasses
///   the record-masking logic used in [NucleusBase], achieving native
///   O(1) resolution speed.
/// - **Structural Purity**: It represents a "Naked Blueprint" devoid of
///   ad-hoc metadata, user-defined records, or specialized locks.
///
/// ### Parameters:
/// (None)
///
/// ### Returns:
/// A type handle for the framework's **Terminal Blueprint**.
///
/// ### See Also:
/// * [Nucleolus]: The concrete implementation of this primitive type.
/// * [Nucleus.empty]: The standard factory for obtaining this root.
/// * [NucleusBase]: The property-aware base for all blueprints.
typedef NucleusSimplest = Nucleolus;

/// A specialized, terminal implementation of the [Nucleus] contract representing
/// the framework's "zero-state" and **Ontological Root**.
///
/// [Nucleolus] serves as the canonical, immutable representation of a blueprint
/// that contains no custom configurations, no external dependencies, and no
/// ancestral inheritance. It defines the floor of the property resolution system.
///
/// ### When to use
/// - **Root of Inheritance**: Use as the terminal ancestor in any [Nucleus]
///   inheritance chain to stop recursive property walks.
/// - **Default Initialization**: Use to represent a cell with framework-standard
///   behavior (e.g., [Context.system], [Receptor.passThrough]).
/// - **Memory Optimization**: Use to avoid heap allocation for nodes that do
///   not require specialized configuration.
///
/// ### How it works
/// 1. **Terminal Boundary**: Implements the end-of-chain logic by returning
///    `null` for the [principal] property.
/// 2. **Static Provisioning**: Hard-codes framework baseline defaults for all
///    governance pillars ([context], [receptor], [testRule], etc.).
/// 3. **Flyweight Reification**: As a `const` class, it allows the entire
///    reactive fabric to share a single instance for every unconfigured node.
/// 4. **Zero-State Blueprint**: Its internal record is a constant empty unit `()`,
///    satisfying the structural contract of [NucleusBase] without runtime overhead.
///
/// ### Non‑obvious
/// - **Activation Resistance**: The `activate()` method always returns `false`
///   because the nucleolus represents an immutable blueprint, not a dynamic
///   operational state.
/// - **Constant-Time Resolution**: Property access on this class is O(1)
///   native speed, as it bypasses record-masking logic entirely.
/// - **Ontological Purity**: It provides the "naked" state of a reactive node,
///   devoid of any metadata, ad-hoc user records, or egress synapses.
/// - **Immutable Integrity**: Being transitively immutable, it ensures that
///   the global defaults of the system cannot be altered at runtime.
///
/// ### Parameters:
/// (None)
///
/// ### Returns:
/// A terminal [Nucleus] instance representing the framework's zero-state.
///
/// ### See Also:
/// * [Nucleus.empty]: The standard factory for obtaining this terminal root.
/// * [NucleusBase]: The property-aware base class for all blueprints.
/// * [Context.system]: The default authority level provided by this node.
class Nucleolus extends NucleusBase {

  static const _singleton = Nucleolus();

  /// The default constant constructor for [Nucleolus].
  ///
  /// This constructor creates a canonical, immutable instance of the
  /// framework's "zero-state" nucleus. Because [Nucleolus] is defined as a
  /// `const` class, this constructor is primarily used by the
  /// [Nucleus.empty] factory to provide a singleton-like, memory-efficient
  /// root for all cell property hierarchies.
  ///
  /// ### Efficiency:
  /// Using `const Nucleolus()` ensures that no unique heap allocation occurs
  /// for the nucleus of a standard cell. All cells using the default
  /// configuration point to the same transitively immutable instance in
  /// the data segment.
  const Nucleolus() : super.fromRecord(());

  @override
  Cell? get bind => null;

  @override
  Context get context => Context.system;

  @override
  Lock? get lock => null;

  @override
  Nucleus? get principal => null;

  @override
  Receptor<Cell> get receptor => Receptor.passThrough;

  @override
  Synapses<Pulse<dynamic>, Cell> get synapses => Synapses.disabled;

  @override
  TestCell<Cell> get testRule => TestCell.allowAll;

  @override
  bool get isActivated => true;

  @override
  bool activate(Cell cell) => false;

  @override
  InheritableHandle get inheritable => (bind: null, context: Context.system, receptor: Receptor.passThrough, testRule: TestCell.allowAll, ephemeralPolicy: null);

  @override
  Record? get user => null;

  @override
  Nucleus get clone => this;

  @override
  bool get isInvalidated => false;

  @override
  DateTime get timestamp => DateTime.now();

}

