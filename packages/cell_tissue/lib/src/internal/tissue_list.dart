// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Internal implementation of [TissueListNucleus] for mutable lists.
///
/// [_TissueListNucleus] is the concrete nucleus that powers `_TissueList`.
/// It extends [TissueListNucleusBase] and provides the specific logic for
/// cloning and evolution.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueListNucleus] instead.
///
/// ### How it works
/// - It extends [TissueListNucleusBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own lock and synapses.
/// - The `evolve` constructor creates a deputy nucleus with overridden properties.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue list type.
class _TissueListNucleus<E,C extends TissueList<E>> extends TissueListNucleusBase<E,C> {

  _TissueListNucleus({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.forceLock,
    super.user,

    super.growable,
  }) : super();

  _TissueListNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    bool forceLock = true,

    TissueListNucleus<E>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueListNucleus<E,C>.fromRecord(
          TissueNucleusBase.local<E,List<E>,C>(
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock
          ))
  );

  _TissueListNucleus.fromRecord(super.record) : super.fromRecord();

  /// Creates an independent, decoupled clone of this nucleus.
  ///
  /// ### When to use
  /// This is used internally when creating a new list from a template nucleus.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a list instance.
  ///
  /// ### Returns:
  /// A new [TissueListNucleusBase] instance with identical behavioural logic.
  @override
  TissueListNucleusBase<E,C> get clone {
    return TissueListNucleus.create<E,C>(
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

/// A foundational base class for implementing [TissueListNucleus].
///
/// [TissueListNucleusBase] provides the core state management and
/// configuration logic used by [TissueList] and its variants. It acts as
/// the bridge between the high‑level [TissueListNucleus] interface and
/// the internal [TissueNucleusBase] logic.
///
/// ### When to use
/// Only if you are building a custom list type that needs to override the
/// default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// You never extend this class directly. It is the base for the internal
/// nucleus implementations (`_TissueListNucleus`). Your interaction with
/// list nuclei is through the factories on [TissueListNucleus] (like
/// `TissueListNucleus.create`).
///
/// ### How it works
/// - It extends [TissueNucleusBase] to inherit the generic tissue
///   configuration engine (receptor, testRule, context, synapses).
/// - It specialises the storage type to [List<E>] and forces the container
///   strategy to either [Container.growableTrue] or [Container.growableFalse]
///   based on the `growable` flag.
/// - It implements the [containerType] resolution by walking up the
///   `principal` chain, defaulting to [Container.growableTrue].
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   list instances from a template.
///
/// ### Non‑obvious
/// - The `growable` flag is **structural** – it is fixed at creation and
///   cannot be changed via a deputy. All deputies of a list share the
///   same growability status.
/// - The nucleus is a **flyweight** – many lists can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent list instances.
///
/// ### Parameters (constructor):
/// - [bind]: Optional upstream cell.
/// - [context]: Execution environment (default: [Context.system]).
/// - [receptor]: Mutation processor (default: pass‑through).
/// - [testRule]: Validation gatekeeper (default: allow all).
/// - [synapses]: Propagation configuration (default: enabled).
/// - [growable]: Whether the list can change size (default: true).
/// - [forceLock]: If `true`, shares the principal's lock.
/// - [user]: Optional metadata.
///
/// ### Returns:
/// A nucleus instance that governs a reactive list.
abstract class TissueListNucleusBase<E, C extends TissueList<E>>
    extends TissueNucleusBase<E, List<E>, C>
    implements TissueListNucleus<E> {

  /// Primary constructor for a [TissueListNucleusBase] configuration.
  ///
  /// This constructor initializes the behavioral and structural metadata
  /// required for a reactive [TissueList]. It bridges the generic
  /// collection framework with [List]-specific constraints, most notably
  /// the physical storage strategy defined by [growable].
  ///
  /// ### How it works
  /// 1. The [growable] flag determines the physical container:
  ///    - `true` → [Container.growableTrue] – an ordinary, resizable list.
  ///    - `false` → [Container.growableFalse] – a fixed‑length list.
  /// 2. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 3. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The [growable] flag is **structural** – once set, it cannot be changed
  ///   by a deputy. If you need a growable and a fixed‑length view of the
  ///   same data, you must create two separate nuclei (or use a deputy with
  ///   a different container type, which is not allowed – deputies inherit
  ///   the container type).
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new list. If you pass [Synapses.disabled], the list
  ///   will be terminal (no broadcasts).
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] – the list will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [growable]: `true` for a resizable list, `false` for fixed length.
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  TissueListNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool growable = true,
    super.forceLock,
    super.user
  }) : super(container: growable ? Container.growableTrue : Container.growableFalse);

  /// **Low‑level Record Constructor** – instantiates a nucleus from a
  /// pre‑packed property record.
  ///
  /// This constructor is designed for framework internals and performance‑
  /// critical scenarios where the configuration record has already been
  /// computed or deserialize.
  ///
  /// ### When to use
  /// Only if you are extending the framework and have a raw [Record]
  /// containing a valid nucleus configuration. For everyday use, stick
  /// to the primary constructor or the [TissueList] factories.
  ///
  /// You will almost never call this directly. It is used by the framework
  /// when:
  /// - Cloning a nucleus (via `clone`).
  /// - Restoring a nucleus from a serialised state.
  /// - Internal evolution (deputy creation) where the local record is
  ///   already resolved.
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
  /// - The record must contain all necessary fields for a [List] nucleus,
  ///   including the `container` (of type [Container<List<E>>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (mask: (container: Container.growableTrue, ...), principal: null);
  /// final nucleus = TissueListNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueListNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// This is the engine behind `deputy()` calls on [TissueList]. It allows
  /// you to create a new nucleus that inherits most of its configuration
  /// from a parent (the principal) while overriding specific properties
  /// like the [testRule] or [context] – all while sharing the same
  /// physical list data.
  ///
  /// ### When to use
  /// You rarely call this directly – use [TissueList.deputy] instead.
  /// This constructor is exposed for advanced cases where you need to
  /// create a deputy nucleus programmatically.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and growable flag).
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
  /// - The [growable] flag is **always inherited** from the principal.
  ///   You cannot change a fixed‑length list into a growable one, or
  ///   vice versa, through a deputy.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example
  /// ```dart
  /// final principal = TissueListNucleus.create<int>(growable: true);
  /// final readOnlyNucleus = TissueListNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyList = TissueList.fromNucleus(readOnlyNucleus);
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
  TissueListNucleusBase.evolve({
    super.override,
    required TissueListNucleus<E> super.principal
  }) : super.evolve();

  /// Retrieves the hierarchical principal configuration of this list's properties.
  ///
  /// This getter is a specialized, type‑safe override of the core [Nucleus.principal]
  /// link. It facilitates the "Property Cascading" mechanism that allows
  /// [TissueList] instances to participate in an inheritance‑based
  /// configuration model.
  ///
  /// ### When to use
  /// Only if you are building a custom list implementation and need to
  /// traverse the inheritance chain to resolve a property value. For most
  /// application code, you never call this – the framework handles it for you.
  ///
  /// You rarely need to read this directly. The framework uses it internally
  /// when you create a deputy via `deputy()`. It's what makes a deputy "share"
  /// the same logic and storage as its principal.
  ///
  /// ### How it works
  /// - When you call `deputy()` on a list, the new nucleus's `principal` is
  ///   set to the original list's nucleus.
  /// - When a property (like `testRule` or `receptor`) is accessed on the
  ///   deputy, the framework first checks the deputy's local record. If not
  ///   found, it "walks up" to the `principal` and asks for the property there.
  /// - This chain continues until a root nucleus (with no `principal`) is reached.
  /// - This is the engine behind zero‑copy deputies: they reuse the principal's
  ///   logic and storage without duplicating anything.
  ///
  /// ### Non‑obvious
  /// - The type is overridden to `TissueListNucleusBase<E, C>?` instead of the
  ///   generic `Nucleus?`. This is a covariant override that ensures you get a
  ///   properly typed principal when you need to access list‑specific methods.
  /// - The chain ends when this getter returns `null` – that's the "root" nucleus.
  /// - Even though the getter is `public`, it's intended for internal framework
  ///   use. Mutating or replacing the principal after construction is not
  ///   supported – the nucleus is immutable.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final list = TissueList<int>();
  /// final deputy = list.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to list._nucleus
  /// // So when deputy needs the growable flag, it delegates to list._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueListNucleusBase<E,C>? get principal => super.principal as TissueListNucleusBase<E,C>?;

  /// The physical storage strategy (growable or fixed) used by this list.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines whether the list can change size, which affects
  /// which mutation methods are allowed.
  ///
  /// ### When to use
  /// Read this to conditionally enable or disable UI controls (e.g., an "Add"
  /// button) based on the list's growability.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at creation and
  ///   inherited by all deputies. A deputy cannot change a fixed‑length list
  ///   into a growable one.
  /// - Defaults to [Container.growableTrue] if not set.
  @override
  Container get containerType {
    return get<Container>(() => record.mask.inhertiable.container, fallback: () => principal?.containerType, orElse: Container.growableTrue);
  }

}

/// A concrete implementation of a mutable [TissueList].
///
/// [_TissueList] is the primary workhorse implementation of the [TissueList]
/// interface. It provides the full reactive, observable, and thread‑safe
/// list capabilities.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// public factory methods on [TissueList].
///
/// ### How it works
/// - It extends [TissueListBase] and provides the mutable implementation.
/// - It holds a [TissueListNucleus] that defines the list's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
/// - The `+` operator combines two lists into a new list.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue list type.
class _TissueList<E,C extends TissueList<E>> extends TissueListBase<E,C> {

  _TissueList({
    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    Synapses synapses= Synapses.enabled,
    bool growable = true
  }) : super(_TissueListNucleus<E,C>(
      bind: bind,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses,
      growable: growable
  ));

  _TissueList.of(Iterable<E> elements, {
    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    Synapses synapses= Synapses.enabled,
    bool growable = true
  }) : super(_TissueListNucleus<E,C>(
      bind: bind,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses,
      growable: growable
  ), elements: elements);

  _TissueList.fromNucleus(TissueListNucleus<E> properties, {super.elements})
      : super(properties as TissueListNucleusBase<E,C>);

  @override
  FutureOr<TissueList<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueListDeputy<E,C>._(this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  late final TissueList<E> unmodifiable = _UnmodifiableTissueList<E,C>.view(this, unmodifiableElement: true);

  /// Combines this list with another list to create a new list.
  ///
  /// ### When to use
  /// Use this to concatenate two reactive lists into a new list containing
  /// all elements from both sources.
  ///
  /// ### How it works
  /// - Creates a new list with the same nucleus configuration as this list.
  /// - The new list contains all elements from this list followed by all
  ///   elements from [other].
  /// - The new list has its own independent storage and observers.
  ///
  /// ### Parameters:
  /// - [other]: The list to concatenate with this one.
  ///
  /// ### Returns:
  /// A new [TissueList] containing all elements from both lists.
  @override
  TissueList<E> operator +(covariant TissueList<E> other) {
    return _TissueList.fromNucleus(_nucleus.clone, elements: [...this, ...other]);
  }

}

/// The foundational reactive engine for all indexable collections in the
/// `cell_tissue` ecosystem.
///
/// [TissueListBase] provides the concrete integration between the reactive
/// [TissueBase] framework and the standard Dart [List] API. It synergies
/// [ListMixin] (to fulfil the full [List] contract) and [TissueListMixin]
/// (to implement the reactive mutation pipeline), creating a high‑performance,
/// governed, and observable indexable sequence.
///
/// ### When to use
/// Only if you are extending the framework to build a custom list variant
/// that requires precise control over the mutation pipeline or storage
/// behaviour. For standard use cases, the existing [TissueList] factories
/// are sufficient.
///
/// You never use this class directly. It is the base class for the internal
/// implementations that power both mutable lists (`_TissueList`) and read‑only
/// views (`_UnmodifiableTissueList`). Your interaction with lists is through
/// the factories on [TissueList].
///
/// ### How it works
/// - It extends [TissueBase] to inherit the core reactive lifecycle,
///   synchronisation domain, and nucleus‑container architecture.
/// - It mixes in [ListMixin], which provides the entire standard Dart [List]
///   API (methods like `map`, `where`, `indexOf`, etc.) based on a handful
///   of core getters and setters (`length`, `operator []`, `length=`, and
///   `operator []=`).
/// - It mixes in [TissueListMixin], which overrides all mutation methods
///   (e.g., `add`, `removeAt`, `operator []=`) to route them through the
///   `apply` command gateway. This ensures every structural change is:
///   1.  Validated against the [TestTissue] rules.
///   2.  Applied atomically to the [Container].
///   3.  Dispatched as a [TissueEvent] to all observers.
/// - The underlying storage type is strictly [List<E>], ensuring index‑based
///   access and positional integrity.
///
/// ### Non‑obvious
/// - **The Mixin Magic**: `ListMixin` provides hundreds of methods for free,
///   but relies on the implementing class to correctly handle mutations.
///   `TissueListMixin` ensures that *every* mutation is intercepted.
/// - **The `apply` Gateway**: All mutations are funnelled through `apply`.
///   This is a security boundary – deputies override `modifiable` to return
///   an empty set, rejecting any mutation attempt.
/// - **Growability**: The list's ability to change size (`growable` flag)
///   is a structural property determined by the underlying [Container].
///   A fixed‑length list cannot be turned into a growable one via a deputy.
///
/// ### Example (Internal Usage)
/// While you never instantiate this directly, understanding it helps you
/// reason about how `TissueList` works:
/// ```dart
/// final nucleus = TissueListNucleus.create<int>(growable: true);
/// final list = _TissueList<int>(nucleus, elements: [1, 2, 3]);
/// // `list` is an instance of `TissueListBase`.
/// list.add(4); // Routed through `apply` -> validation -> pulse emission
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the list.
/// - [C]: The specific [Tissue] implementation type (usually `TissueList<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueListBase<E,C extends TissueList<E>>
    extends TissueBase<E, List<E>, C>
    with ListMixin<E>, TissueListMixin<E,C>
    implements TissueList<E> {

  /// Accesses the underlying properties specific to tissue lists.
  ///
  /// This overrides the base properties to provide access to list-specific
  /// configuration, such as the `growable` status of the internal container.
  @override
  TissueListNucleusBase<E, C> get _nucleus =>
      super._nucleus as TissueListNucleusBase<E, C>;

  /// Constructs a [TissueListBase] with the specified properties.
  ///
  /// ### Parameters:
  /// - [properties]: The configuration and state container for this list.
  /// - [elements]: Optional initial elements to populate the list. These
  ///   will be added to the internal container during initialization.
  TissueListBase(
      TissueListNucleusBase<E, C> super.properties, {
        super.elements,
      }) : super();

  /// Returns an unmodifiable version of this tissue list.
  ///
  /// Subclasses must implement this to return a view that prevents structural
  /// and element-level mutations while remaining reactive to changes in this
  /// base list.
  @override
  TissueList<E> get unmodifiable;

  /// Provides an asynchronous view of this list's mutation API.
  ///
  /// Wraps this instance in a [ModifiableListAsync] which allows for
  /// `await`-ing mutation operations. This is particularly useful when
  /// mutations trigger complex reactive graphs that need to resolve before
  /// the next step in business logic.
  @override
  ModifiableListAsync<E> get async => ModifiableListAsync<E>(this);

  /// Returns the validation rule governing this list.
  ///
  /// This is used by the [TissueListMixin] during [apply] calls to
  /// verify if a proposed change (like adding an element) is permitted
  /// based on the [TestTissue] rules defined in [_nucleus].
  @override
  TestTissue<E, C> get validate => _nucleus.testRule;

}

/// A concrete implementation of a deputy (restricted view) of a [TissueList].
///
/// [_TissueListDeputy] implements the **Deputy Pattern** for lists. It shares
/// the same physical storage and lock as the principal but applies different
/// validation rules, context, or lifecycle policies.
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [TissueList] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `_TissueList` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue list type.
class _TissueListDeputy<E,C extends TissueList<E>> extends _TissueList<E,C> with Deputy<TissueList<E>> {

  _TissueListDeputy._(TissueListBase<E,C> bind, {Context context = Context.system, TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueListNucleus<E,C>.evolve(
      bind: bind,
      testRule: bind._nucleus.testRule + testRule,
      synapses: bind._nucleus.synapses != Synapses.disabled ? synapses : Synapses.disabled,
      principal: bind._nucleus
  ));

  @override
  FutureOr<TissueList<E>> deputy({covariant DeputyContext context = DeputyContext.system, TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueListDeputy<E,C>._(_nucleus.bind as TissueListBase<E,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

}

/// A concrete implementation of an unmodifiable (read‑only) list view.
///
/// [_UnmodifiableTissueList] is the primary implementation of the `.unmodifiable`
/// getter on [TissueList]. It provides a live, read‑only projection that shares
/// the same physical storage as the mutable source.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [TissueList] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueListBase] and provides the concrete
///   implementation.
/// - It shares the same physical storage and lock as the mutable source.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, child [Cell]s are projected as
///   read‑only deputies.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue list type.
class _UnmodifiableTissueList<E,C extends TissueList<E>> extends UnmodifiableTissueListBase<E,C> {

  _UnmodifiableTissueList(Iterable<E> elements, {bool unmodifiableElement = true, TissueListNucleus<E>? properties})
      : this.fromNucleus(
      (properties ?? TissueListNucleus.create<E,C>()) as TissueListNucleusBase<E,C>,
      unmodifiableElement: unmodifiableElement,
      elements: elements
  );

  _UnmodifiableTissueList.view(TissueList<E> bind, {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(TissueListNucleus.create<E,C>(bind: bind,
      container: unmodifiableElement ? bind._nucleus.containerType : null,
      context: context,
      synapses: bind._nucleus.synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
      principal: bind._nucleus as TissueListNucleusBase<E,C>
  ), unmodifiableElement: unmodifiableElement,
      elements: unmodifiableElement ? bind.map<E>((e) => e is Cell ? e.unmodifiable as E : e) : null
  );

  _UnmodifiableTissueList.fromNucleus(TissueListNucleus<E> properties, {super.unmodifiableElement, super.elements})
      : super(properties as TissueListNucleusBase<E,C>);

  @override
  FutureOr<TissueList<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueListDeputy<E,C>._(this as TissueListBase<E,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  TestTissue<E,C> get validate => _nucleus.testRule;

}

/// A foundational architectural base class that provides the skeletal
/// implementation for unmodifiable, reactive [List] entities.
///
/// [UnmodifiableTissueListBase] serves as the structural anchor for
/// read‑only reactive lists within the `cell_tissue` ecosystem. It
/// synergies the standard Dart [ListMixin] API with the specialised
/// signalling, validation, and synchronisation behaviours of the
/// reactive data‑flow graph.
///
/// ### When to use
/// You don't instantiate this – it's internal. But understanding it helps
/// you trust that `.unmodifiable` views are truly immutable and reactive.
///
/// You never use this class directly. It is the base for the read‑only
/// list views returned by `.unmodifiable` on a `TissueList`. Your
/// interaction is through the `unmodifiable` getter.
///
/// ### How it works
/// - It extends [UnmodifiableTissueBase] to inherit the core read‑only
///   plumbing and the ability to share storage with a mutable source.
/// - It mixes in [ListMixin] to provide the full [List] read API.
/// - It mixes in [TissueListMixin] but the `modifiable` getter returns an
///   empty set, so all mutation attempts are rejected.
/// - The `async` getter returns a specialised `_UnmodifiableModifiableListAsync`
///   that throws `UnsupportedError` on any mutation.
/// - If `unmodifiableElement` is `true`, iterating over the list yields
///   unmodifiable deputies of any child [Cell]s, ensuring deep immutability.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: The view is live – changes to the mutable
///   source are immediately reflected.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: The iterator wraps child cells in their
///   `.unmodifiable` deputies, preventing side‑door mutations.
/// - **Own observer registry**: The view has its own [Synapses] registry,
///   so observers attached to the view are separate from those on the source.
///
/// ### Example (Internal)
/// ```dart
/// final source = TissueList<int>([1, 2, 3]);
/// final readOnly = _UnmodifiableTissueList<int>.view(source);
/// // readOnly.add(4); // throws UnsupportedError
/// source.add(4); // readOnly now contains [1, 2, 3, 4]
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the list.
/// - [C]: The specific [Tissue] implementation type (usually `TissueList<E>`).
abstract class UnmodifiableTissueListBase<E,C extends TissueList<E>>
    extends UnmodifiableTissueBase<E, List<E>, C>
    with ListMixin<E>, TissueListMixin<E, C>
    implements UnmodifiableTissueList<E> {

  /// Provides access to the list-specific configuration properties.
  ///
  /// Overrides the base properties to provide a typed
  /// [TissueListNucleusBase], which includes metadata about the
  /// list's container, growability, and reactive context.
  @override
  TissueListNucleusBase<E, C> get _nucleus =>
      super._nucleus as TissueListNucleusBase<E, C>;

  /// Initializes a new [UnmodifiableTissueListBase] instance, anchoring
  /// a read-only reactive list to its behavioral and structural blueprint.
  ///
  /// This constructor is the internal structural initializer for the
  /// unmodifiable list hierarchy. It bridges the gap between the
  /// [TissueListNucleusBase] configuration and the live reactive [Cell]
  /// infrastructure, ensuring that the list enters the graph with an
  /// established "Read-Only" barrier.
  ///
  /// ### How it works
  /// 1. The provided [properties] (a [TissueListNucleusBase]) define the
  ///    list's structural strategy (growable/fixed), synchronisation domain,
  ///    and reactive blueprint.
  /// 2. The [unmodifiableElement] flag controls deep immutability – when
  ///    `true`, any element that is a [Cell] is automatically projected as
  ///    its `.unmodifiable` deputy when accessed.
  /// 3. If [elements] are provided, they are used to seed a dedicated
  ///    high‑performance storage container for this instance. This is an
  ///    optimisation used by the `.view` factory to avoid lazy projection
  ///    overhead.
  /// 4. The resulting instance enters the reactive graph with a read‑only
  ///    barrier – all mutation methods are disabled.
  ///
  /// ### Non‑obvious
  /// - The [unmodifiableElement] flag is **not** stored in the nucleus – it
  ///   is a behaviour of the view itself. The view applies it during
  ///   iteration and element access.
  /// - The [elements] parameter is only used when the underlying container
  ///   is not already populated (e.g., when creating a fresh unmodifiable
  ///   list from scratch). For deputies (views), the storage is shared with
  ///   the source, so [elements] should be `null` to avoid overwriting.
  /// - The view's `modifiable` getter returns an empty set, so the
  ///   [TissueListMixin] will never execute mutations – they are rejected
  ///   at the `apply` gate.
  ///
  /// ### Parameters:
  /// - [properties]: **Required**. The [TissueListNucleusBase] defining
  ///   the list's structural strategy and reactive blueprint.
  /// - [unmodifiableElement]: If `true`, any [Cell] element accessed
  ///   through this list is projected as its `.unmodifiable` deputy.
  /// - [elements]: Optional. Pre‑computed elements to populate the
  ///   storage container. Used for optimisation when the list is created
  ///   with a known immutable set.
  UnmodifiableTissueListBase(
      TissueListNucleusBase<E,C> super.properties, {
        super.unmodifiableElement, Iterable<E>? elements}) : super(elements: elements) {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null && elements != null) {
      _nucleus.container.store.addAll(elements);
    }
  }

  /// Returns this instance as the unmodifiable view of the list.
  ///
  /// Because this class is explicitly designed to be unmodifiable,
  /// this getter returns `this` directly. This is an optimization that
  /// avoids unnecessary recursive wrapping when a consumer calls
  /// `.unmodifiable` on an already read-only list.
  ///
  /// Returns:
  ///   The current [UnmodifiableTissueListBase] instance.
  @override
  TissueList<E> get unmodifiable => this;

  /// Returns an asynchronous interface for interacting with this list.
  ///
  /// While [TissueList] supports asynchronous operations, an
  /// unmodifiable list provides a restricted async facade. Any attempts
  /// to perform mutations via the returned [ModifiableListAsync] will
  /// follow the unmodifiable contract (typically resulting in no-ops or
  /// immediate failures).
  ///
  /// Returns:
  ///   An instance of [_UnmodifiableModifiableListAsync].
  @override
  ModifiableListAsync<E> get async => const _UnmodifiableModifiableListAsync();

  /// Exposes the validation logic associated with this tissue.
  ///
  /// Even as an unmodifiable view, the list maintains its [testRule].
  /// This is used by the system to ensure that this list—and any
  /// "deputies" derived from it—adhere to the required data constraints
  /// and permissions.
  ///
  /// Returns:
  ///   The [TestTissue] rule defined in this list's properties.
  @override
  TestTissue<E, C> get validate => _nucleus.testRule;
}


/// A core reactive mixin that provides the implementation for [TissueList] operations.
///
/// `TissueListMixin` serves as the primary bridge between the standard Dart
/// [List] interface and the reactive [Tissue] framework. It provides the
/// logic necessary to handle list‑specific data storage, mutation interception,
/// validation, and pulse propagation.
///
/// ### When to use
/// Only if you are building a custom list implementation that needs to
/// integrate with the reactive pipeline. For standard use, the existing
/// list types are sufficient.
///
/// This mixin is used internally by `TissueListBase` and `UnmodifiableTissueListBase`.
/// You don't interact with it directly – it's the engine behind all list mutations.
///
/// ### How it works
/// - **Data Access**: Implements core index‑based access (`operator []`)
///   and structural properties (`length`) by interacting with the internal
///   storage container.
/// - **Mutation Interception**: Overrides all standard Dart [List] mutation
///   methods (e.g., `add`, `remove`, `clear`, `operator []=`). Instead of
///   modifying the data directly, these methods are routed through the
///   `apply` mechanism.
/// - **Validation & Security**: Before any change is committed, the mixin
///   checks the [TestTissue] rules (both action and element validation).
/// - **Pulse Propagation**: After a successful mutation, the mixin triggers
///   the [TissueReceptor], which notifies listeners and propagates changes
///   through the reactive graph.
///
/// ### Non‑obvious
/// - The mixin relies on the host class to provide `_nucleus` and `validate`.
///   It does not hold any state itself – all state is in the nucleus.
/// - The `apply` method uses a large `if`‑`else` chain to dispatch to the
///   appropriate private `_` method (e.g., `_add`, `_remove`). This is an
///   optimisation that avoids reflection overhead.
/// - The private methods (e.g., `_add`) are responsible for actually
///   updating the container and generating the corresponding `TissueEvent`.
/// - If the host class is [Unmodifiable], the mutation methods are bypassed
///   (the host's `modifiable` is empty), so the mixin's mutation logic is
///   never reached.
///
/// ### Required Host Members:
/// - `TissueListNucleusBase<E, C> get _nucleus`
/// - `TestTissue<E, C> get validate`
/// - `bool get isUnmodifiable` (from `Unmodifiable` check in the mixin)
///
/// ### Example (Internal)
/// When you call `list.add(42)`, the following chain occurs:
/// 1. `list.add` (from `ListMixin`) calls `apply(add, [42])`.
/// 2. `apply` checks `modifiable.contains(add)` (true for mutable lists).
/// 3. It calls `_add(42)`, which validates the element, updates the container,
///    and emits an `ElementAddedEvent`.
/// 4. The event is dispatched through the receptor to all observers.
mixin TissueListMixin<E,C extends TissueList<E>>
implements TissueList<E> {

  /// Provides type-safe access to the list-specific configuration properties.
  ///
  /// This must be implemented by the host class to return an instance of
  /// [TissueListNucleusBase], which contains the specialized
  /// storage container and metadata required for list operations.
  @override
  TissueListNucleusBase<E, C> get _nucleus;

  /// An exhaustive collection of functions that represent modifiable operations
  /// supported by this reactive list.
  ///
  /// This getter combines the base tissue operations with standard Dart
  /// [List] mutation methods. This registry is used by the internal
  /// signaling system to track and validate specific types of changes
  /// being performed on the collection.
  @override
  Iterable<Function> get modifiable => <Function>{
    add, addAll, clear, remove, removeWhere,
    retainWhere, fillRange, insert, insertAll, removeAt,
    removeLast, removeRange, replaceRange,
    // setAll, setRange, sort, shuffle, ...super.modifiable
  };

  /// Retrieves the element at the specified [index].
  ///
  /// This is a primary read operation. It bypasses the signaling system
  /// and accesses the underlying container directly for high-performance
  /// data retrieval.
  ///
  /// ### Parameters:
  /// - [index]: The zero-based location of the element.
  ///
  /// ### Returns:
  /// The element of type [E] at the given position.
  @override
  E operator [](int index) => _nucleus.container.elementAt(index);

  /// Updates the length of the list, potentially truncating or expanding it.
  ///
  /// This setter is guarded to prevent modifications if the current
  /// instance is an [Unmodifiable] view. If modifiable, it updates
  /// the physical storage capacity of the underlying container.
  ///
  /// ### Parameters:
  /// - [newLength]: The desired new size for the list.
  @override
  set length(int newLength) {
    if (this is! Unmodifiable) {
      _nucleus.container.store.length = newLength;
    }
  }

  /// Returns the current number of elements in the reactive list.
  @override
  int get length => _nucleus.container.length;

  /// Updates the value at a specific [index] using the reactive `apply` cycle.
  ///
  /// This is the preferred way to update individual indices as it ensures
  /// validation and change notification.
  ///
  /// ### Parameters:
  /// - [index]: The position to be updated.
  /// - [value]: The new value to be stored at that position.
  @override
  void setValueAt(int index, E value) => apply(setValueAt, positionalArguments: [index, value]);

  /// Sets the first element of the list to [value] after validation.
  ///
  /// ### Parameters:
  /// - [value]: The new element for index 0.
  @override
  void setFirst(E value) => apply(setFirst, positionalArguments: [value]);

  /// The standard Dart index assignment operator.
  ///
  /// Internally redirects to [setValueAt] to ensure that the assignment
  /// is processed through the reactive system's validation and
  /// signaling logic.
  ///
  /// ### Parameters:
  /// - [index]: The position to update.
  /// - [value]: The new element to store.
  @override
  void operator []=(int index, E value) => apply(setValueAt, positionalArguments: [index, value]);

  /// Appends [element] to the end of the list through the reactive system.
  ///
  /// This operation is subject to the tissue's [testRule]. If the
  /// rule rejects the action or the specific element, the list
  /// remains unchanged.
  ///
  /// ### Parameters:
  /// - [element]: The item to be added.
  @override
  void add(E element) => apply(add, positionalArguments: [element]);

  /// Appends all items in [iterable] to the end of this list.
  ///
  /// ### Parameters:
  /// - [iterable]: The collection of elements to add.
  @override
  void addAll(Iterable<E> iterable) => apply(addAll, positionalArguments: [iterable]);

  /// Removes all elements from the list.
  ///
  /// This effectively resets the list to an empty state (length 0)
  /// after passing validation.
  @override
  void clear() => apply(clear);

  /// Removes the first occurrence of [object] from the list.
  ///
  /// ### Parameters:
  /// - [object]: The element to find and remove.
  ///
  /// ### Returns:
  /// `true` if the element was found and successfully removed;
  /// otherwise `false`.
  @override
  bool remove(Object? object) => apply(remove, positionalArguments: [object]).isNotEmpty;

  /// Removes all elements that satisfy the given [test] predicate.
  ///
  /// ### Parameters:
  /// - [test]: A function returning `true` for items to be removed.
  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, positionalArguments: [test]);

  /// Retains only the elements that satisfy the given [test] predicate.
  ///
  /// ### Parameters:
  /// - [test]: A function returning `true` for items to keep.
  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, positionalArguments: [test]);

  /// Replaces a range of elements with [fillValue].
  ///
  /// ### Parameters:
  /// - [start]: Starting index (inclusive).
  /// - [end]: Ending index (exclusive).
  /// - [fillValue]: The value used to overwrite the range.
  @override
  void fillRange(int start, int end, [E? fillValue]) => apply(fillRange, positionalArguments: [start, end, fillValue]);

  /// Inserts [element] at the specified [index].
  ///
  /// Shifts all subsequent elements to the right.
  ///
  /// ### Parameters:
  /// - [index]: The position where the element should be placed.
  /// - [element]: The element to insert.
  @override
  void insert(int index, E element) => apply(insert, positionalArguments: [index, element]);

  /// Inserts a collection of elements starting at the specified [index].
  ///
  /// ### Parameters:
  /// - [index]: The position where insertion begins.
  /// - [iterable]: The elements to insert.
  @override
  void insertAll(int index, Iterable<E> iterable) => apply(insert, positionalArguments: [index, iterable]);

  /// Removes the element at the given [index] and returns it.
  ///
  /// ### Parameters:
  /// - [index]: The position of the element to remove.
  ///
  /// ### Returns:
  /// The element that was removed.
  @override
  E removeAt(int index) => apply(removeAt, positionalArguments: [index]).values.first.first;

  /// Removes the last element of the list and returns it.
  ///
  /// ### Returns:
  /// The removed element.
  @override
  E removeLast() => apply(removeLast).values.first.first;

  /// Removes a range of elements from the list.
  ///
  /// ### Parameters:
  /// - [start]: The beginning index (inclusive).
  /// - [end]: The ending index (exclusive).
  @override
  void removeRange(int start, int end) => apply(removeRange, positionalArguments: [start, end]);

  /// Replaces a specified range of elements with the contents of [newContents].
  ///
  /// ### Parameters:
  /// - [start]: The beginning of the replacement range (inclusive).
  /// - [end]: The end of the replacement range (exclusive).
  /// - [newContents]: The iterable providing the new elements.
  @override
  void replaceRange(int start, int end, Iterable<E> newContents) => apply(removeRange, positionalArguments: [start, end, newContents]);

  /// Overwrites elements with the objects of [iterable] starting at [index].
  ///
  /// ### Parameters:
  /// - [index]: The start index to begin overwriting.
  /// - [iterable]: The source elements.
  @override
  void setAll(int index, Iterable<E> iterable) => apply(setAll, positionalArguments: [index, iterable]);

  /// Writes some elements of [iterable] into a range of this list.
  ///
  /// ### Parameters:
  /// - [start]: The start of the range to write to.
  /// - [end]: The end of the range to write to.
  /// - [iterable]: The source of the elements.
  /// - [skipCount]: How many elements to skip in the source [iterable].
  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    apply(setRange, positionalArguments: [start, end, iterable, skipCount]);
  }

  /// Shuffles the elements of this list randomly.
  ///
  /// ### Parameters:
  /// - [random]: An optional [Random] number generator to use.
  @override
  void shuffle([Random? random]) => apply(shuffle, positionalArguments: [random]);

  /// Sorts this list according to the order specified by the [compare] function.
  ///
  /// ### Parameters:
  /// - [compare]: An optional comparison function.
  @override
  void sort([int Function(E a, E b)? compare]) => apply(sort, positionalArguments: [compare]);

  // ... (private mutation methods _setValueAt, _add, _addAll, _clear, etc.)
  // These methods follow the same pattern and are documented in the mixin
  // overview above.

  @override
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {
    // ... implementation ...
  }

}

/// An asynchronous facade for performing reactive mutation operations on a [TissueList].
///
/// `ModifiableListAsync` provides a [Future]‑based API that mirrors the standard
/// mutation methods of a [TissueList]. This class is essential for scenarios
/// where list modifications need to be offloaded to the event loop or handled
/// within an `async/await` workflow, ensuring that reactive updates do not
/// block the main execution thread or trigger synchronous side‑effects
/// prematurely.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side‑effects.
///
/// You never construct this directly. It is returned by the `async` getter
/// on any [TissueList] (e.g., `myList.async`). Use it when you need to
/// perform asynchronous mutations.
///
/// ### How it works
/// - It wraps the synchronous mutation methods (like `add`, `removeAt`,
///   `clear`, etc.) in a `Future`.
/// - All operations are scheduled through the tissue's lock, ensuring
///   atomicity.
/// - The returned `Future` completes when the mutation has been validated,
///   applied, and propagated through the reactive graph.
/// - The underlying synchronous method is called within the `Future`'s
///   execution, so all validation and pulse emission happen exactly as they
///   would in a synchronous call.
///
/// ### Non‑obvious
/// - The async wrapper does **not** change the validation or reactivity – it's
///   the same pipeline as synchronous calls, just non‑blocking.
/// - If the tissue is unmodifiable, the async methods will throw
///   `UnsupportedError`.
/// - The `await` ensures that all downstream observers have been notified
///   before the Future resolves.
/// - The [ModifiableListAsync] extends [TissueModifiableAsync] which provides
///   the common `apply` method for dynamic command execution.
///
/// ### Example
/// ```dart
/// final list = TissueList<int>();
/// await list.async.add(42);
/// print('Item added and all observers notified.');
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained within the list.
///
/// See also:
/// - [TissueList.async] – the typical way to access an instance of this class.
/// - [TissueModifiableAsync] – the base class providing common async wrapping.
class ModifiableListAsync<E> extends TissueModifiableAsync<E,TissueList<E>> {

  /// Creates an asynchronous callable wrapper for a [TissueList].
  ///
  /// This constructor is typically not called directly. Instead, instances are
  /// accessed via the [TissueList.async] getter.
  ///
  /// ### Parameters:
  ///   - `tissue`: The [TissueList<E>] whose operations will be wrapped
  const ModifiableListAsync(super.tissue);

  /// Asynchronously sets the value at the given `index` in the list to `value`.
  ///
  /// Wraps [TissueList.setValueAt]. The `Future` completes successfully if the
  /// operation is permitted by validation rules and the list is modifiable.
  /// Otherwise, it completes with an error (e.g., `RangeError`, `UnsupportedError`,
  /// or validation-specific error).
  ///
  /// ### Parameters:
  ///   - `index`: The index of the element to replace.
  ///   - `value`: The new value.
  ///
  /// ### Returns:
  ///   A `Future<void>` that completes when the operation is done.
  Future<void> setValueAt(int index, E value) async {
    return Future<void>(() => _tissue.setValueAt(index, value));
  }

// ... (all other async methods follow the same pattern)

}

/// An unmodifiable async facade that throws [UnsupportedError] on any mutation.
///
/// This is returned by the `async` getter on unmodifiable list views to
/// ensure that even asynchronous mutation attempts are rejected.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly.
///
/// ### How it works
/// - Every mutation method throws [UnsupportedError] with a descriptive
///   message indicating that the operation is not supported on unmodifiable
///   views.
/// - Read operations are not provided by this class – they are handled by the
///   synchronous view.
class _UnmodifiableModifiableListAsync<E> implements ModifiableListAsync<E> {

  const _UnmodifiableModifiableListAsync();

  /// Async sets the value at the given [index] in the list to [value].
  @override
  Future<void> setValueAt(int index, E value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> setFirst(E value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> add(E element) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> addAll(Iterable<E> elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> clear() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<bool> remove(Object? element) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> removeWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> retainWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> fillRange(int start, int end, [dynamic fillValue]) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> insert(int index, element) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> insertAll(int index, Iterable elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> removeAt(int index) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> removeLast() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> removeRange(int start, int end) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> replaceRange(int start, int end, Iterable newContents) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> setAll(int index, Iterable elements) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> setRange(int start, int end, Iterable newContents, [int skipCount = 0]) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> shuffle([Random? random]) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<void> sort([int Function(E a, E b)? compare]) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  TissueList<E> get _tissue => throw UnimplementedError();

  @override
  Future apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

}