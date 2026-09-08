// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Internal implementation of [TissueSetNucleus] for reactive sets.
///
/// [_TissueSetNucleus] is the concrete nucleus that powers `_TissueSet`.
/// It extends [TissueSetNucleusBase] and provides the specific logic for
/// cloning and evolution.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueSetNucleus] instead.
///
/// ### How it works
/// - It extends [TissueSetNucleusBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own lock and synapses.
/// - The `evolve` constructor creates a deputy nucleus with overridden properties.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue set type.
class _TissueSetNucleus<E,C extends TissueSet<E>> extends TissueSetNucleusBase<E,C> {
  _TissueSetNucleus({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.identitySet,
    super.forceLock,
    super.user
  }) : super();

  _TissueSetNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    bool identitySet = false,
    bool forceLock = true,

    TissueSetNucleus<E>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueSetNucleus<E,C>.fromRecord(
          TissueNucleusBase.local<E,Set<E>,C>(
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock
          )
      )
  );

  _TissueSetNucleus.fromRecord(super.record) : super.fromRecord();

  /// Creates an independent, decoupled clone of this nucleus.
  ///
  /// ### When to use
  /// This is used internally when creating a new set from a template nucleus.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a set instance.
  ///
  /// ### Returns:
  /// A new [TissueSetNucleusBase] instance with identical behavioural logic.
  @override
  TissueSetNucleusBase<E,C> get clone {
    return TissueSetNucleus.create<E,C>(
        container: containerType,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
        user: user,
        forceLock: false
    );
  }

}

/// The foundational blueprint that defines the behaviour, storage strategy,
/// and governance of a reactive [TissueSet].
///
/// [TissueSetNucleusBase] holds the immutable configuration – the receptor,
/// validation rule, context, synapses, and the identitySet flag – that governs
/// how a set reacts to mutations. It is the **DNA** of every reactive set.
///
/// ### When to use
/// Only if you are building a custom set type that needs to override the
/// default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// You never extend this class directly. The framework provides concrete
/// implementations via [TissueSetNucleus.create] and the [TissueSet] factories.
/// This class is the base that powers the internal `_TissueSetNucleus`.
///
/// ### How it works
/// - It extends [TissueNucleusBase] to inherit the core property resolution
///   engine (bitmask records, principal chain, lock management).
/// - It specialises the storage type to [Set<E>] and forces the container
///   strategy to either [Container.set] (value‑based equality) or
///   [Container.identitySet] (referential identity) based on the `identitySet`
///   flag.
/// - It implements the [containerType] resolution by walking up the
///   `principal` chain, defaulting to [Container.set].
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   set instances from a template.
///
/// ### Non‑obvious
/// - The `identitySet` flag is **structural** – it is fixed at creation and
///   inherited by all deputies. A deputy cannot change a value‑based set
///   into an identity‑based set.
/// - The nucleus is a **flyweight** – many sets can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent set instances.
/// - The [principal] chain enables **prototype inheritance** – a deputy can
///   override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueSetNucleus.create<int>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   identitySet: true,
/// );
/// final set1 = TissueSet.fromNucleus(validNucleus);
/// final set2 = TissueSet.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements held within the associated [TissueSet].
/// - [C]: The specific [TissueSet] implementation type (usually `TissueSet<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueSetNucleusBase<E,C extends TissueSet<E>>
    extends TissueNucleusBase<E, Set<E>, C>
    implements TissueSetNucleus<E> {

  /// **Primary Constructor** – defines the immutable behaviour and storage
  /// strategy for a reactive set.
  ///
  /// ### When to use
  /// **Internal framework use only.** This constructor is `public` only so
  /// that concrete subclasses (like `_TissueSetNucleus`) can invoke it via
  /// `super()`. **Application code should never call this directly.**
  ///
  /// If you need a nucleus, use [TissueSetNucleus.create] to create one
  /// from scratch, or [TissueSetNucleus.evolve] to derive one from an
  /// existing principal.
  ///
  /// You are writing a custom set implementation that extends
  /// `TissueSetNucleusBase` and need to pass configuration up to the base.
  ///
  /// ### How it works
  /// 1. The [identitySet] flag determines the physical container:
  ///    - `true` → [Container.identitySet] – elements are compared using
  ///      [identical] (referential equality).
  ///    - `false` → [Container.set] – elements use standard `==` and `hashCode`.
  /// 2. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 3. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The `identitySet` flag is **structural** – once set, it cannot be
  ///   changed by a deputy. If you need both identity‑based and value‑based
  ///   views of the same data, you must create two separate nuclei.
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new set. If you pass [Synapses.disabled], the set
  ///   will be terminal (no broadcasts).
  /// - The [forceLock] flag controls whether a new synchronization lock is
  ///   allocated. `false` (default) creates a new lock; `true` shares the
  ///   principal's lock (used for deputies).
  ///
  /// ### Example (Internal – how the framework uses it)
  /// ```dart
  /// class _MyCustomSetNucleus<E> extends TissueSetNucleusBase<E, TissueSet<E>> {
  ///   _MyCustomSetNucleus({super.identitySet = false, ...}) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] – the set will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [identitySet]: `true` for identity‑based element comparison, `false` for
  ///   value‑based (default).
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  TissueSetNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool identitySet = false,
    super.forceLock,
    super.user,
  }) : super(container: identitySet ? Container.identitySet : Container.set);

  /// **Low‑level Record Constructor** – instantiates a nucleus from a
  /// pre‑packed property record.
  ///
  /// ### When to use
  /// **Strictly internal framework use only.** This constructor bypasses
  /// all parameter validation and default‑value logic. It is designed for
  /// performance‑critical paths like cloning and state restoration.
  /// **Application code must never call this.**
  ///
  /// - When implementing `clone` or `evolve` in a custom nucleus subclass.
  /// - When restoring a nucleus from a serialised state where the record
  ///   shape is already guaranteed.
  ///
  /// ### How it works
  /// - The provided [record] is directly assigned to the internal storage.
  /// - No validation or default‑value logic is performed – the record is
  ///   assumed to be correct and complete.
  /// - This bypasses the bitmask optimisation of the primary constructor,
  ///   which is why it is only safe to use when the record shape is
  ///   guaranteed.
  ///
  /// ### Non‑obvious
  /// - The record must contain all necessary fields for a set nucleus,
  ///   including the `container` (of type [Container<Set<E>>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (mask: (container: Container.set, ...), principal: null);
  /// final nucleus = TissueSetNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueSetNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// ### When to use
  /// This constructor is part of the **internal deputy machinery**. While it
  /// is `public`, it is intended to be called only by the framework when
  /// you invoke `deputy()` on a [TissueSet]. **Application code should use
  /// `TissueSet.deputy()` or [TissueSetNucleus.evolve] instead.**
  ///
  /// You are building a custom deputy implementation and need to control
  /// exactly how a child nucleus inherits from its principal.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and identitySet flag).
  /// 2. If [override] is provided, its entire record is used as the local
  ///    base – any individual parameters (bind, context, etc.) are ignored.
  /// 3. If [override] is `null`, a new local record is built from the
  ///    individual parameters, falling back to the principal's values for
  ///    any omitted property.
  /// 4. The new nucleus links to the [principal] via its `principal` chain,
  ///    so property lookups walk up the chain.
  /// 5. The resulting nucleus shares the same [Lock] as the principal
  ///    (unless [override] introduces its own lock).
  ///
  /// ### Non‑obvious
  /// - The `identitySet` flag is **always inherited** from the principal.
  ///   You cannot change a value‑based set into an identity‑based set, or
  ///   vice versa, through a deputy.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final principal = TissueSetNucleus.create<int>(identitySet: false);
  /// final readOnlyNucleus = TissueSetNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlySet = TissueSet.fromNucleus(readOnlyNucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The source nucleus to inherit from.
  /// - [override]: Optional. A complete nucleus whose record will replace
  ///   the local base. If provided, individual parameters are ignored.
  /// - [bind]: Optional override for the upstream cell.
  /// - [context]: Optional override for the execution context.
  /// - [receptor]: Optional override for the mutation processor.
  /// - [testRule]: Optional override for the validation rule (layered
  ///   on top of the principal's).
  /// - [synapses]: Optional override for propagation behaviour.
  /// - (Other parameters like [forceLock] and [user] are typically
  ///   inherited from the principal or taken from [override]).
  TissueSetNucleusBase.evolve({
    super.override,
    required TissueSetNucleus<E> super.principal,
  }) : super.evolve();

  /// Retrieves the hierarchical principal configuration of this set's properties.
  ///
  /// This getter is a specialized, type‑safe override of the core [Nucleus.principal]
  /// link. It facilitates the "Property Cascading" mechanism that allows
  /// [TissueSet] instances to participate in an inheritance‑based
  /// configuration model.
  ///
  /// ### When to use
  /// Only if you are building a custom set implementation and need to
  /// traverse the inheritance chain to resolve a property value. For most
  /// application code, you never call this – the framework handles it for you.
  ///
  /// You rarely need to read this directly. The framework uses it internally
  /// when you create a deputy via `deputy()`. It's what makes a deputy "share"
  /// the same logic and storage as its principal.
  ///
  /// ### How it works
  /// 1. **Delegation**: If a property is requested but not explicitly defined
  ///    in the local [record], the system "walks up" this [principal] chain.
  /// 2. **Contextual Overrides**: A "Deputy" set (created via `deputy()`)
  ///    typically has a [principal] link to the original set's nucleus,
  ///    allowing it to inherit the physical data [container] and `identitySet`
  ///    while providing a local override for the [context] or [testRule].
  /// 3. **Termination**: The chain ends when this getter returns `null` –
  ///    that's the "root" nucleus.
  ///
  /// ### Non‑obvious
  /// - The type is overridden to `TissueSetNucleusBase<E, C>?` – a covariant
  ///   override that ensures you get a properly typed principal when you need
  ///   to access set‑specific methods (like `containerType`).
  /// - Even though the getter is `public`, it's intended for internal
  ///   framework use. Mutating or replacing the principal after construction
  ///   is not supported – the nucleus is immutable.
  /// - The principal chain determines the `containerType` and all other
  ///   structural properties; a deputy cannot change the uniqueness strategy.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final set = TissueSet<int>();
  /// final deputy = set.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to set._nucleus
  /// // So when deputy needs the identitySet flag, it delegates to set._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueSetNucleusBase<E, C>? get principal =>
      super.principal as TissueSetNucleusBase<E, C>?;

  /// The physical storage strategy (value‑based or identity‑based) used by this set.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines how elements are compared for uniqueness.
  ///
  /// ### When to use
  /// Read this to understand whether the set uses value equality (`==`) or
  /// referential identity (`identical`) for element uniqueness.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at creation and
  ///   inherited by all deputies. A deputy cannot change a value‑based set
  ///   into an identity‑based one.
  /// - Defaults to [Container.set] if not set.
  @override
  Container get containerType {
    return get<Container>(
            () => record.mask.inhertiable.container,
        fallback: () => principal?.containerType,
        orElse: Container.set);
  }

}

/// Concrete implementation of a mutable reactive set.
///
/// [_TissueSet] is the live instance you get from factories like `TissueSet()`.
/// It ties together the nucleus (logic) and the container (data) to provide
/// a fully reactive, thread‑safe set with validation and event emission.
///
/// ### When to use
/// You never create this directly – use [TissueSet] or one of its named
/// constructors (`TissueSet.empty`, `TissueSet.of`, `TissueSet.identity`,
/// `TissueSet.fromNucleus`).
///
/// ### How it works
/// - It extends [TissueSetBase] and provides the mutable implementation.
/// - It holds a [TissueSetNucleus] that defines the set's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue set type.
class _TissueSet<E,C extends TissueSet<E>> extends TissueSetBase<E,C> {

  _TissueSet(Iterable<E> elements, {
    Cell? bind,
    Context context = Context.system,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool identitySet = false
  }) : super(_TissueSetNucleus<E,C>(
      bind: bind,
      context: context,
      identitySet: identitySet,
      testRule: testRule,
      receptor: receptor,
      synapses: synapses
  ), elements: elements);

  _TissueSet.empty({
    Cell? bind,
    Context context = Context.system,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool identitySet = false
  }) : super(_TissueSetNucleus<E,C>(
      bind: bind,
      context: context,
      identitySet: identitySet,
      testRule: testRule,
      receptor: receptor,
      synapses: synapses
  ));

  _TissueSet.fromNucleus(TissueSetNucleus<E> nucleus, {super.elements})
      : super(nucleus as _TissueSetNucleus<E,C>);

  @override
  FutureOr<TissueSet<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueSetDeputy<E,C>._(this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  late final TissueSet<E> unmodifiable = _UnmodifiableTissueSet<E,C>.view(this, unmodifiableElement: true);

  @override
  TissueSetNucleusBase<E, C> get _nucleus => super._nucleus as TissueSetNucleusBase<E, C>;

}

/// The foundational reactive engine for all unique collections in the
/// `cell_tissue` ecosystem.
///
/// [TissueSetBase] provides the concrete integration between the reactive
/// [TissueBase] framework and the standard Dart [Set] API. It uses
/// [SetMixin] (to fulfil the full [Set] contract) and [TissueSetMixin]
/// (to implement the reactive mutation pipeline), creating a high‑performance,
/// governed, and observable unique‑element collection.
///
/// ### When to use
/// Only if you are extending the framework to build a custom set variant
/// that requires precise control over the mutation pipeline or storage
/// behaviour. For standard use cases, the existing [TissueSet] factories
/// are sufficient.
///
/// You never use this class directly. It is the base class for the internal
/// implementations that power both mutable sets (`_TissueSet`) and read‑only
/// views (`_UnmodifiableTissueSet`). Your interaction with sets is through
/// the factories on [TissueSet].
///
/// ### How it works
/// - It extends [TissueBase] to inherit the core reactive lifecycle,
///   synchronisation domain, and nucleus‑container architecture.
/// - It mixes in [SetMixin], which provides the entire standard Dart [Set]
///   API based on a handful of core methods (`contains`, `length`, `add`,
///   `remove`, `clear`, `iterator`).
/// - It mixes in [TissueSetMixin], which overrides all mutation methods
///   to route them through the `apply` command gateway. This ensures every
///   structural change is:
///   1. Validated against the [TestTissue] rules.
///   2. Applied atomically to the [Container].
///   3. Dispatched as a [TissueEvent] to all observers.
/// - The underlying storage is a Dart `Set<E>` with uniqueness defined by
///   the `identitySet` flag.
///
/// ### Non‑obvious
/// - **The Mixin Magic**: `SetMixin` provides many methods for free, but
///   relies on the implementing class to correctly handle mutations.
///   `TissueSetMixin` ensures that *every* mutation is intercepted.
/// - **The `apply` Gateway**: All mutations are funnelled through `apply`.
///   This is a security boundary – deputies override `modifiable` to return
///   an empty set, rejecting any mutation attempt.
/// - **Uniqueness Strategy**: The `identitySet` flag is fixed at creation.
///   A deputy cannot change a value‑based set into an identity‑based one.
/// - **Member‑level bubbling**: If the set contains [Cell] elements, they
///   are automatically linked, so internal changes trigger [ElementUpdatedEvent]s.
///
/// ### Example (Internal Usage)
/// While you never instantiate this directly, understanding it helps you
/// reason about how `TissueSet` works:
/// ```dart
/// final nucleus = TissueSetNucleus.create<int>(identitySet: false);
/// final set = _TissueSet<int>(nucleus);
/// set.add(42); // Routed through `apply` -> validation -> pulse emission
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the set.
/// - [C]: The specific [Tissue] implementation type (usually `TissueSet<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueSetBase<E,C extends TissueSet<E>>
    extends TissueBase<E, Set<E>, C>
    with SetMixin<E>, TissueSetMixin<E, C>
    implements TissueSet<E> {

  /// Creates a new [TissueSetBase] with the provided [nucleus].
  ///
  /// Optionally accepts an initial collection of [elements] to populate
  /// the underlying container during initialization.
  ///
  /// ### Parameters:
  /// - [nucleus]: The [TissueSetNucleusBase] defining the set's behaviour.
  /// - [elements]: Optional initial elements. Each element is validated
  ///   against the nucleus's [testRule] before being added.
  TissueSetBase(TissueSetNucleusBase<E, C> super.nucleus, {super.elements})
      : super();

  /// The set of modifiable functions that can be invoked via `apply`.
  ///
  /// This includes all standard Dart [Set] mutation methods. It is used
  /// by the `apply` gateway to determine which operations are permitted.
  ///
  /// ### Non‑obvious
  /// - For an [UnmodifiableTissueSet] (or any class implementing
  ///   [Unmodifiable]), this getter is overridden to return an empty set,
  ///   effectively blocking all mutations.
  /// - The `apply` method checks this list before executing any function.
  @override
  Iterable<Function> get modifiable => <Function>{
    add,
    addAll,
    clear,
    remove,
    removeAll,
    removeWhere,
    // ...super.modifiable
  };

  /// Returns an unmodifiable reactive view of this set.
  ///
  /// Subclasses must implement this to return a version of the set that
  /// throws errors on mutation attempts while still reflecting updates
  /// made to the original source.
  @override
  TissueSet<E> get unmodifiable;

  /// Returns an [Async] wrapper for this set.
  ///
  /// The [async] property allows users to perform set operations (like `add`
  /// or `remove`) that return a [Future]. This is particularly useful when
  /// mutations are bound to external cells or require synchronization across
  /// different execution contexts.
  @override
  ModifiableSetAsync<E> get async => ModifiableSetAsync<E>(this);

  /// Provides access to the validation rules defined for this collection.
  ///
  /// This getter extracts the [TestTissue] rules from the set's nucleus,
  /// allowing the [TissueSetMixin] and other internal logic to verify
  /// whether specific elements or operations are permitted before execution.
  @override
  TestTissue<E, C> get validate => _nucleus.testRule;
}

/// Internal deputy implementation for [TissueSet].
///
/// A deputy shares the same physical data as its principal but applies
/// different validation, context, or synapses. It is created via the
/// `deputy()` method on a [TissueSet].
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [TissueSet] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `_TissueSet` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue set type.
class _TissueSetDeputy<E, C extends TissueSet<E>> extends _TissueSet<E, C>
    with Deputy<TissueSet<E>> {
  _TissueSetDeputy._(
      TissueSetBase<E, C> bind, {
        Context context = Context.system,
        TestTissue<E, C> testRule = TestTissue.allowAll,
        EphemeralPolicy? ephemeralPolicy,
        Synapses synapses = Synapses.enabled,
      }) : super.fromNucleus(TissueSetNucleus<E>.evolve(
    bind: bind,
    context: context,
    testRule: testRule,
    synapses: bind._nucleus.synapses != Synapses.disabled ? synapses : Synapses.disabled,
    principal: bind._nucleus,
  ));

  @override
  FutureOr<TissueSet<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue<E, C> testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _TissueSetDeputy<E, C>._(_nucleus.bind as TissueSetBase<E, C>,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }
}

/// Internal implementation of an unmodifiable (read‑only) reactive set.
///
/// This is created when you call `.unmodifiable` on a [TissueSet]. It
/// shares the same physical storage and lock as the source, but blocks all
/// mutation attempts. It is a live view – changes to the source are
/// immediately reflected.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [TissueSet] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueSetBase] and provides the concrete
///   implementation.
/// - It shares the same physical storage and lock as the mutable source.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, child [Cell] elements are projected
///   as read‑only deputies.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue set type.
class _UnmodifiableTissueSet<E,C extends TissueSet<E>> extends UnmodifiableTissueSetBase<E,C> {

  _UnmodifiableTissueSet(Iterable<E> elements, {bool unmodifiableElement = true, TissueSetNucleus<E>? nucleus})
      : this.fromNucleus(
      (nucleus ?? TissueSetNucleus.create<E,C>()) as TissueSetNucleusBase<E,C>,
      unmodifiableElement: unmodifiableElement,
      elements: elements
  );

  _UnmodifiableTissueSet.view(TissueSet<E> bind, {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(TissueSetNucleus.create<E,C>(bind: bind,
      container: unmodifiableElement ? bind._nucleus.containerType : null,
      context: context,
      synapses: bind._nucleus.synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
      principal: bind._nucleus as TissueSetNucleusBase<E,C>
  ), unmodifiableElement: unmodifiableElement,
      elements: unmodifiableElement ? bind.map<E>((e) => e is Cell ? e.unmodifiable as E : e) : null
  );

  _UnmodifiableTissueSet.fromNucleus(TissueSetNucleus<E> nucleus, {super.unmodifiableElement, super.elements})
      : super(nucleus as TissueSetNucleusBase<E,C>);

  @override
  FutureOr<TissueSet<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueSetDeputy<E,C>._(this as TissueSetBase<E,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  TestTissue<E,C> get validate => _nucleus.testRule;

}

/// The foundational base class for all read‑only reactive set views.
///
/// [UnmodifiableTissueSetBase] is the abstract anchor for unmodifiable
/// set implementations (e.g., `_UnmodifiableTissueSet`). It ties together
/// a read‑only nucleus and a shared storage container, ensuring that all
/// mutations are blocked while reactivity remains live.
///
/// ### When to use
/// Only if you are building a custom read‑only set variant that needs
/// to override the default unmodifiable behaviour. For everyday use,
/// the existing `.unmodifiable` getter is all you need.
///
/// This class is **abstract** – you never instantiate it directly.
/// You obtain an unmodifiable set by calling `.unmodifiable` on any
/// mutable [TissueSet], or by using one of the dedicated factories
/// (`UnmodifiableTissueSet`, `UnmodifiableTissueSet.view`, etc.).
///
/// ### How it works
/// 1. The constructor receives a [TissueSetNucleusBase] that defines the
///    set's structural strategy (`identitySet`) and governance rules.
/// 2. The `unmodifiableElement` flag controls deep immutability:
///    - If `true`, any element that is a [Cell] is automatically projected
///      as its `.unmodifiable` deputy when accessed via this set.
///    - If `false`, child cells remain mutable (but the set itself is
///      still read‑only).
/// 3. The set shares the same physical storage as its mutable source
///    (when created via `.view`) – changes to the source are immediately
///    reflected in this read‑only view.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: The view is live. Changes to the mutable
///   source are instantly visible.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: If `unmodifiableElement` is `true`, the
///   iterator wraps each element that is a [Cell] in its `.unmodifiable`
///   deputy, preventing side‑door mutations.
/// - **Own observer registry**: The view has its own [Synapses] registry,
///   so observers attached to the view are independent of those on the
///   source.
///
/// ### Example (Internal)
/// ```dart
/// final source = TissueSet<int>();
/// source.add(1);
/// final readOnly = _UnmodifiableTissueSet<int>.view(source);
/// // readOnly.add(2); // throws UnsupportedError
/// source.add(2); // readOnly now contains {1, 2}
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the set.
/// - [C]: The specific [TissueSet] implementation type (usually `TissueSet<E>`).
///
/// See also:
/// * [TissueSet] – the mutable counterpart.
/// * [UnmodifiableTissue] – the base interface for all read‑only tissues.
abstract class UnmodifiableTissueSetBase<E,C extends TissueSet<E>>

    extends UnmodifiableTissueBase<E, Set<E>, C>
    with SetMixin<E>, TissueSetMixin<E, C>
    implements UnmodifiableTissueSet<E> {

  @override
  TissueSetNucleusBase<E, C> get _nucleus =>
      super._nucleus as TissueSetNucleusBase<E, C>;

  /// The internal constructor that materialises a read‑only, live view of a
  /// reactive set.
  ///
  /// ### When to use
  /// You never call this constructor directly. It is invoked by the framework
  /// when you write `mySet.unmodifiable`, or when you use one of the
  /// specialised factories (`UnmodifiableTissueSet`, `UnmodifiableTissueSet.view`,
  /// or `UnmodifiableTissueSet.fromNucleus`).
  ///
  /// You don't. This is an internal constructor. But understanding it helps
  /// you trust that `.unmodifiable` is cheap (zero‑copy), live, and deeply
  /// safe.
  ///
  /// ### How it works
  /// 1. **Logic activation**: It receives a [TissueSetNucleusBase] (the
  ///    immutable blueprint) and binds it to the new view instance. The
  ///    nucleus holds the set's structural strategy (`identitySet`), its
  ///    synchronisation [Lock], and its governance rules.
  /// 2. **Immutability enforcement**: The `modifiable` getter is overridden
  ///    to return an empty set – any mutation attempt is intercepted and
  ///    rejected by the `apply` gateway.
  /// 3. **Deep immutability (`unmodifiableElement`)**: If this flag is
  ///    `true`, any element that is itself a [Cell] is automatically
  ///    projected as its `.unmodifiable` deputy when you access it through
  ///    this view. This prevents "side‑door" mutations via nested mutable
  ///    cells.
  /// 4. **Pre‑computed storage ([elements])**: If you provide an optional
  ///    iterable of [elements], they are added directly to the underlying
  ///    container **atomically** during initialisation. This is an
  ///    optimisation used by the `.view` factory: it avoids lazy wrapping
  ///    of each element when you iterate over the view, making iteration
  ///    faster (O(1) per access).
  /// 5. **Lazy container resolution**: The container is resolved via a helper
  ///    (`get`) that walks up the principal chain if needed. This means
  ///    the view shares the same physical storage as its source – **zero‑copy**.
  ///
  /// ### Non‑obvious
  /// - The [elements] parameter is **only** used when the view is created
  ///   from a nucleus that does not yet have a container (e.g., when you
  ///   create a standalone unmodifiable set from scratch). For deputies
  ///   created via `.view`, the storage is already shared with the source,
  ///   so [elements] is typically `null` to avoid overwriting.
  /// - The `unmodifiableElement` flag is **not** stored in the nucleus – it
  ///   is a behaviour of the view itself. It is applied during iteration
  ///   and element access.
  /// - If you pass [elements] that contain [Cell]s, they are **not**
  ///   automatically linked to the view's synapses unless the
  ///   `unmodifiableElement` flag is `true`. This is because the view is
  ///   read‑only – it only reflects changes, it does not propagate them.
  /// - The constructor does **not** emit any pulses – the view is considered
  ///   "hydrated" and ready for observation.
  ///
  /// ### Example (internal usage – how the framework creates a view)
  /// ```dart
  /// // When you write source.unmodifiable, the framework does something like:
  /// final source = TissueSet<int>({1, 2, 3});
  /// final readOnly = UnmodifiableTissueSetBase<int, TissueSet<int>>(
  ///   source._nucleus,                    // shares the same blueprint
  ///   unmodifiableElement: true,          // deep immutability on
  ///   elements: source.map((e) => e is Cell ? e.unmodifiable : e), // pre‑wrapped
  /// );
  /// // Now readOnly shares the same storage, blocks mutations, and is live.
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: **Required**. The immutable blueprint that defines the set's
  ///   behaviour, storage strategy, and governance. It is typically the same
  ///   nucleus as the source set.
  /// - [unmodifiableElement]: If `true`, any [Cell] element accessed through
  ///   this view is projected as its `.unmodifiable` deputy. Defaults to
  ///   `true` in most factories.
  /// - [elements]: Optional pre‑computed elements to seed the storage
  ///   container. This is an optimisation to avoid lazy projection overhead
  ///   during iteration.
  UnmodifiableTissueSetBase(
      TissueSetNucleusBase<E,C> super.nucleus, {super.unmodifiableElement, Iterable<E>? elements})
      : super(elements: elements) {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null && elements != null) {
      _nucleus.container.store.addAll(elements);
    }
  }

  /// Returns a collection of functions that are permitted to modify this set.
  ///
  /// This list is used by the reactive system to determine if a specific
  /// operation (like `add` or `clear`) is supported by the current instance.
  @override
  Iterable<Function> get modifiable => <Function>{};

  /// Returns this instance, as it is already unmodifiable.
  ///
  /// This is an optimization to prevent redundant wrapping when
  /// `.unmodifiable` is called on a set that is already read-only.
  @override
  TissueSet<E> get unmodifiable => this;

  /// Returns an asynchronous view of this set.
  ///
  /// For unmodifiable sets, this returns a specialized async view that
  /// prohibits asynchronous modifications, maintaining consistency with
  /// the synchronous API.
  @override
  ModifiableSetAsync<E> get async => const _UnmodifiableModifiableSetAsync();

}

/// A mixin that provides the core implementation of the [Set] interface for
/// tissue set types.
///
/// [TissueSetMixin] bridges the gap between the standard [Set] API and the
/// reactive "Tissue" infrastructure. It handles the delegation of standard
/// set operations (like `add`, `remove`, `contains`) to the underlying
/// [TissueSetNucleusBase.container], while integrating with the
/// reactive [apply] and validation systems.
///
/// ### When to use
/// Only if you are building a custom set implementation that needs to reuse
/// the standard Set logic.
///
/// This mixin is used internally by `TissueSetBase` and
/// `UnmodifiableTissueSetBase`. You don't interact with it directly – it
/// provides the Set API for tissues.
///
/// ### How it works
/// - It requires the host class to provide `_nucleus` (a `TissueSetNucleusBase`)
///   and `validate` (a `TestTissue`).
/// - It implements all Set read methods (`contains`, `length`, `lookup`,
///   `containsAll`, `toSet`) by delegating to `_nucleus.container.store`.
/// - It implements all Set mutation methods (`add`, `addAll`, `remove`,
///   `removeAll`, `clear`, `retainAll`, `removeWhere`, `retainWhere`) by
///   routing them through the `apply` gateway.
/// - The `apply` method validates the action and then calls the appropriate
///   private `_` method (e.g., `_add`, `_remove`) which updates the container
///   and emits the corresponding `TissueEvent`.
///
/// ### Non‑obvious
/// - The mixin does **not** hold any state itself – all state is in the nucleus.
/// - The private `_` methods (e.g., `_add`) are responsible for the actual
///   container mutation and event emission.
/// - If the host class is [Unmodifiable], the mutation methods are bypassed
///   (the host's `modifiable` is empty), so the mixin's mutation logic is
///   never reached.
/// - The `lookup` method is O(n) – it iterates through the entire set to
///   find an equivalent element. For large sets, consider using the
///   underlying container's direct lookup if available.
mixin TissueSetMixin<E,C extends TissueSet<E>> implements TissueSet<E> {
  /// Provides access to the specific property container for sets.
  ///
  /// This must be implemented by the consuming class to provide the
  /// [TissueSetNucleusBase] which holds the actual [Set] data.
  @override
  TissueSetNucleusBase<E, C> get _nucleus;

  /// Checks if the set contains the specified [element].
  ///
  /// Directly queries the underlying container.
  @override
  bool contains(Object? element) => _nucleus.container.contains(element);

  /// Returns the number of elements in the set.
  @override
  int get length => _nucleus.container.length;

  /// Returns the element in the set that is equal to [element], if any.
  ///
  /// Iterates through the container to find an object [e] such that `e == element`.
  @override
  E? lookup(Object? element) {
    for (var e in _nucleus.container) {
      if (e == element) {
        return e;
      }
    }
    return null;
  }

  /// Checks whether this set contains all the elements of [other].
  @override
  bool containsAll(Iterable<Object?> other) {
    return other.every((e) => _nucleus.container.any((ee) => ee == e));
  }

  /// Creates a standard [Set] containing the same elements as this tissue.
  @override
  Set<E> toSet() => _nucleus.container.toSet();

  /// Adds [element] to the set.
  ///
  /// This operation is reactive. It uses [apply] to route the request through
  /// validation and signaling logic. Returns `true` if the element was added.
  @override
  bool add(E element) => apply(add, positionalArguments: [element]).isNotEmpty;

  /// Adds all [elements] to the set.
  ///
  /// Elements are validated individually. Only those passing the `testRule`
  /// are added.
  @override
  void addAll(Iterable<E> elements) => apply(addAll, positionalArguments: [elements]);

  /// Removes all elements from the set.
  @override
  void clear() => apply(clear);

  /// Removes [object] from the set.
  ///
  /// Returns `true` if the object was present and successfully removed.
  @override
  bool remove(Object? object) => apply(remove, positionalArguments: [object]).isNotEmpty;

  /// Removes all elements that satisfy [test].
  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, positionalArguments: [test]);

  /// Removes all elements that fail to satisfy [test].
  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, positionalArguments: [test]);

  /// Removes all elements contained in [elements].
  @override
  void removeAll(Iterable<Object?> elements) => apply(removeAll, positionalArguments: [elements]);

  /// Removes all elements except those contained in [elements].
  @override
  void retainAll(Iterable<Object?> elements) => apply(retainAll, positionalArguments: [elements]);

  // Internal Reactive Implementations (prefixed with _)
  // These handle the actual logic and pulse dispatching.

  TissueEvent? _add(E element, {bool notification = true, Tissue<E>? deputy}) {
    ElementAddedEvent<E>? event;
    if (this is! Unmodifiable && modifiable.contains(add)) {
      if (validate.element(element, host: this, action: add) == true && _nucleus.container.add(this,element)) {
        event = ElementAddedEvent<E>._(source: deputy ?? this, payload: element);
        if (notification) {
          _nucleus.receptor(event);
        }
      }
    }
    return event;
  }

  TissueEvent? _addAll(Iterable<E> elements, {bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;
    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      final events = <ElementAddedEvent<E>>[];
      final adds = elements.where((e) => validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: add) == true);
      final added = adds.where((e) => _nucleus.container.add(this,e));
      if (added.isNotEmpty) {
        for (var e in added) {
          events.add(ElementAddedEvent<E>._(source: deputy ?? this, payload: e));
        }
        result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  TissueEvent? _clear({bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;
    if (this is! Unmodifiable && modifiable.contains(clear)) {
      final events = <ElementRemovedEvent<E>>[];
      final removes = _nucleus.container.where((e) => validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true);
      final removed = removes.where((e) => _nucleus.container.remove(this,e));
      if (removed.isNotEmpty) {
        for (var e in removed) {
          events.add(ElementRemovedEvent<E>._(source: deputy ?? this, payload: e));
        }
        result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  TissueEvent? _remove(Object? object, {bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<E>? event;
    if (this is! Unmodifiable && modifiable.contains(remove)) {
      final e = lookup(object);
      if (e != null && validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true && _nucleus.container.remove(this,e)) {
        event = ElementRemovedEvent<E>._(source: deputy ?? this, payload: e);
        if (notification) {
          _nucleus.receptor(event);
        }
      }
    }
    return event;
  }

  TissueEvent? _removeAll(Iterable<Object?> objects, {bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;
    if (this is! Unmodifiable && modifiable.contains(removeAll)) {
      if (_nucleus.container.isNotEmpty) {
        final events = <ElementRemovedEvent<E>>[];
        final removes = objects.map((o) => lookup(o)).where((e) => e != null && validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e as E));
        if (removed.isNotEmpty) {
          for (var e in removed) {
            events.add(ElementRemovedEvent<E>._(source: deputy ?? this, payload: e));
          }
          result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
          if (notification) {
            _nucleus.receptor(result);
          }
        }
      }
    }
    return result;
  }

  TissueEvent? _removeWhere(bool Function(E element) test, {bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;

    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      if (_nucleus.container.isNotEmpty) {
        final events = <ElementRemovedEvent<E>>[];
        final removes = _nucleus.container.where((e) => test(e) && validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          for (var e in removed) {
            events.add(ElementRemovedEvent<E>._(source: deputy ?? this, payload: e));
          }
          result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
          if (notification) {
            _nucleus.receptor(result);
          }
        }
      }
    }
    return result;
  }

  TissueEvent? _retainAll(Iterable<Object?> objects, {bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;

    if (this is! Unmodifiable && modifiable.contains(retainAll)) {
      if (_nucleus.container.isNotEmpty) {
        final events = <ElementRemovedEvent<E>>[];
        final retains = objects.map((o) => lookup(o)).where((e) => e != null).cast<E>();
        final removes = _nucleus.container.where((e) => !retains.contains(e) && validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          for (var e in removed) {
            events.add(ElementRemovedEvent<E>._(source: deputy ?? this, payload: e));
          }
          result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
          if (notification) {
            _nucleus.receptor(result);
          }
        }
      }
    }
    return result;
  }

  TissueEvent? _retainWhere(bool Function(E element) test, {bool notification = true, Tissue<E>? deputy}) {
    TissueEvent? result;

    if (this is! Unmodifiable && modifiable.contains(retainWhere)) {
      if (_nucleus.container.isNotEmpty) {
        final events = <ElementRemovedEvent<E>>[];
        final removes = _nucleus.container.where((e) => !test(e) && validate.element(e, host: deputy is TissueSet<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          for (var e in removed) {
            events.add(ElementRemovedEvent<E>._(source: deputy ?? this, payload: e));
          }
          result = events.length == 1 ? events.first : TissueEvent.batch<E>(events);
          if (notification) {
            _nucleus.receptor(result);
          }
        }
      }
    }
    return result;
  }

  @override
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {

    if (modifiable.contains(function)) {
      try {
        if (validate.action(function, host: this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments)) == true) {
          final notification = namedArguments?[#$notification] ?? true;
          final deputy = namedArguments?[#deputy];

          if (function == add) {
            return Function.apply(_add, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == addAll) {
            return Function.apply(_addAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == clear) {
            return Function.apply(_clear, null, {#notification: notification, #deputy: deputy});
          }
          else if (function == remove) {
            return Function.apply(_remove, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == removeAll) {
            return Function.apply(_removeAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == removeWhere) {
            return Function.apply(_removeWhere, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == retainAll) {
            return Function.apply(_retainAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == retainWhere) {
            return Function.apply(_retainWhere, positionalArguments, {#notification: notification, #deputy: deputy});
          }
        }} catch (_) {}
      return null;
    }
    return Function.apply(function, positionalArguments, namedArguments);
  }

}

/// An asynchronous facade for performing reactive mutation operations on a [TissueSet].
///
/// `ModifiableSetAsync` provides a [Future]‑based API that mirrors the standard
/// mutation methods of a [TissueSet]. This class is essential for scenarios
/// where set modifications need to be offloaded to the event loop or handled
/// within an `async/await` workflow.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side‑effects.
///
/// You never construct this directly. It is returned by the `async` getter
/// on any [TissueSet] (e.g., `mySet.async`). Use it when you need to
/// perform asynchronous mutations.
///
/// ### How it works
/// - It wraps the synchronous mutation methods (like `add`, `removeAll`,
///   `clear`, etc.) in a `Future`.
/// - All operations are scheduled through the tissue's lock, ensuring
///   atomicity.
/// - The returned `Future` completes when the mutation has been validated,
///   applied, and propagated through the reactive graph.
///
/// ### Non‑obvious
/// - The async wrapper does **not** change the validation or reactivity – it's
///   the same pipeline as synchronous calls, just non‑blocking.
/// - If the tissue is unmodifiable, the async methods will throw
///   `UnsupportedError`.
/// - The `await` ensures that all downstream observers have been notified
///   before the Future resolves.
/// - For identity‑based sets, the uniqueness check uses [identical].
///
/// ### Example
/// ```dart
/// final set = TissueSet<int>();
/// await set.async.add(42);
/// print('Element added and all observers notified.');
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained within the set.
///
/// See also:
/// - [TissueSet.async] – the typical way to access an instance of this class.
/// - [TissueModifiableAsync] – the base class providing common async wrapping.
class ModifiableSetAsync<E> extends TissueModifiableAsync<E, TissueSet<E>> {

  /// Creates an asynchronous facade for the given [tissue].
  ///
  /// Parameters:
  /// - [tissue]: The [TissueSet] instance that this facade will operate upon.
  const ModifiableSetAsync(super.tissue);

  /// Asynchronously adds [element] to the set.
  ///
  /// Returns a [Future] that completes with `true` if the element was
  /// successfully added (i.e., it passed validation and was not already present).
  Future<bool> add(E element) async {
    return Future<bool>(() => _tissue.add(element));
  }

  /// Asynchronously adds all [elements] to the set.
  ///
  /// Returns a [Future] that completes when all valid elements from the
  /// [elements] iterable have been processed and added.
  Future<void> addAll(Iterable<E> elements) async {
    return Future<void>(() => _tissue.addAll(elements));
  }

  /// Asynchronously removes [element] from the set.
  ///
  /// Returns a [Future] that completes with `true` if the element was
  /// present in the set and successfully removed.
  Future<bool> remove(Object? element) async {
    return Future<bool>(() => _tissue.remove(element));
  }

  /// Asynchronously removes all elements contained in [elements] from the set.
  ///
  /// Returns a [Future] that completes once the removal operation is finished.
  Future<void> removeAll(Iterable<Object?> elements) async {
    return Future<void>(() => _tissue.removeAll(elements));
  }

  /// Asynchronously clears all elements from the set.
  ///
  /// Returns a [Future] that completes when the set has been emptied
  /// (subject to validation rules).
  Future<void> clear() async {
    return Future<void>(() => _tissue.clear());
  }

  /// Asynchronously removes all elements except those contained in [elements].
  ///
  /// This is the asynchronous equivalent of the intersection-like
  /// [Set.retainAll] operation.
  Future<void> retainAll(Iterable<Object?> elements) async {
    return Future<void>(() => _tissue.retainAll(elements));
  }

  /// Asynchronously removes all elements that do not satisfy the [test] predicate.
  ///
  /// Parameters:
  /// - [test]: A function that returns `true` for elements that should be kept.
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => _tissue.retainWhere(test));
  }

  /// Asynchronously removes all elements that satisfy the [test] predicate.
  ///
  /// Parameters:
  /// - [test]: A function that returns `true` for elements that should be removed.
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => _tissue.removeWhere(test));
  }

}

/// An unmodifiable async facade that throws [UnsupportedError] on any mutation.
///
/// This is returned by the `async` getter on unmodifiable set views to
/// ensure that even asynchronous mutation attempts are rejected.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly.
///
/// ### How it works
/// - Every mutation method throws [UnsupportedError] with a descriptive
///   message indicating that the operation is not supported on unmodifiable
///   views.
class _UnmodifiableModifiableSetAsync<E> implements ModifiableSetAsync<E> {

  const _UnmodifiableModifiableSetAsync();

  @override
  Future<bool> add(E element) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addAll(Iterable<E> elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<bool> remove(Object? element) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeAll(Iterable<Object?> elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> clear() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainAll(Iterable<Object?> elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  TissueSet<E> get _tissue => throw UnimplementedError();

}