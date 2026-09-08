// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A specialised architectural configuration interface that defines the behavioural
/// DNA, security protocols, and reactive strategies for a [TissueSet].
///
/// [TissueSetNucleus] serves as the **Stateless Blueprint** (the "Blueprint
/// Pattern") for reactive sets within the `cell_tissue` ecosystem. It
/// separates the collection's governance (how it behaves, validates, and signals)
/// from its physical state (the actual elements held in memory), enabling
/// high‑fidelity state management with minimal heap overhead.
///
/// ### When to use
/// You might reference this type when you need to:
/// - Pass a pre‑configured nucleus to [TissueSet.fromNucleus] to reuse a
///   validated set blueprint.
/// - Extend a custom set implementation that needs to override the default
///   behaviour.
/// - Debug why a set is behaving in a certain way – inspect its nucleus to see
///   the `identitySet`, `testRule`, etc.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [TissueSet]. You interact with it indirectly when
/// creating a set via [TissueSet] or [TissueSet.create].
///
/// The most common way to get a nucleus is to let the framework create one for
/// you when you use `TissueSet()`. You rarely need to construct one manually.
///
/// ### How it works
/// - The nucleus holds all **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** via [containerType]
///   (standard Set vs. IdentitySet).
/// - A nucleus can be **evolved** (via the `evolve` factory) to create a
///   deputy – a restricted view that shares the same data but applies different
///   rules or context.
/// - The nucleus is immutable; once created, it cannot be changed. Any
///   variation requires creating a new nucleus (or deputy).
///
/// ### Non‑obvious
/// - The [identitySet] flag is **structural**: it is fixed at creation and
///   inherited by all deputies. You cannot change a value‑based set into an
///   identity‑based set through a deputy.
/// - The nucleus is a **flyweight** – many sets can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a fresh copy of the nucleus with its own
///   [Lock] and [Synapses]. This is used internally when you create a new set
///   from an already‑activated nucleus to avoid sharing locks.
/// - The `principal` chain allows hierarchical inheritance – a deputy nucleus
///   can override only specific properties (like `testRule`) while inheriting
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
/// * [E]: The type of elements managed by the associated [TissueSet].
///
/// See also:
/// - [TissueSet] – the reactive set instance governed by this nucleus.
/// - [TissueReceptor] – the engine that processes mutation signals.
/// - [TestTissue] – the validation logic for collection elements.
abstract interface class TissueSetNucleus<E> implements TissueNucleus<E> {

  /// The primary architectural factory for instantiating a [TissueSetNucleus],
  /// defining the "DNA" and governance protocols for a reactive set.
  ///
  /// This constructor serves as the foundational "Blueprint Materializer" within
  /// the **Conactive Model**. It syntheses the logical identity of a set—its
  /// security rules, execution context, and command processing—into a high‑performance,
  /// memory‑optimised configuration record.
  ///
  /// ### When to use
  /// Use this when you are building a custom set configuration from scratch.
  /// For most use cases, the simpler [TissueSet] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [identitySet] flag (default false) and optional
  ///   governance parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple sets that
  ///   share the same logic but hold separate data.
  ///
  /// ### Non‑obvious
  /// - If you omit the [testRule], it defaults to [TestTissue.allowAll] – no
  ///   restrictions.
  /// - The [receptor] defaults to [TissueReceptor.passThrough] – mutations are
  ///   applied directly.
  /// - The [context] defaults to [Context.system] – system‑level authority.
  /// - The [synapses] default to [Synapses.enabled] – observers receive pulses.
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] to observe.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: Mutation command processor (default: pass‑through).
  /// - [testRule]: Validation gatekeeper (default: allow all).
  /// - [synapses]: Propagation configuration (default: enabled).
  /// - [identitySet]: Whether elements are compared by identity (default: false).
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueSetNucleus<E>] instance strictly configured
  /// according to the provided reactive blueprint.
  factory TissueSetNucleus({
    Cell? bind,
    Context context,
    TissueReceptor<E,TissueSet<E>> receptor,
    TestTissue<E,TissueSet<E>> testRule,
    Synapses synapses,
    bool identitySet,
    Record? user
  }) = _TissueSetNucleus<E,TissueSet<E>>;

  /// Creates a derived [TissueSetNucleus] by mutating or extending
  /// an existing [principal] configuration.
  ///
  /// This factory is the architectural implementation of **Prototypal Inheritance**
  /// and **Behavioural Shadowing** within the reactive graph. It allows for the
  /// creation of specialised "Deputy" configurations that logically inherit the
  /// structural DNA of a [principal] while selectively overriding specific
  /// operational traits.
  ///
  /// ### When to use
  /// This is the engine behind the `deputy()` method on [TissueSet]. You
  /// rarely call it directly. Use it when you need a restricted view of a set
  /// that shares the same storage but applies different validation or context.
  ///
  /// ### How it works
  /// - The new nucleus inherits all properties from [principal] unless
  ///   explicitly overridden.
  /// - You can override the [testRule] (to narrow permissions), [context] (to
  ///   change authority), [receptor] (to transform mutations), or [synapses].
  /// - The [identitySet] status is always inherited and cannot be changed.
  /// - The new nucleus shares the same [Lock] and physical storage as the
  ///   principal (unless you provide an [override] that introduces a new lock).
  ///
  /// ### Non‑obvious
  /// - The [override] parameter allows you to layer a complete pre‑configured
  ///   nucleus on top of the principal. This is useful for composing complex
  ///   deputies.
  /// - The resulting nucleus does **not** copy the principal's data – it shares
  ///   it via the inheritance chain.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry, so listeners attached to the deputy are separate from those
  ///   attached to the principal.
  ///
  /// ### Example
  /// ```dart
  /// final principal = TissueSetNucleus.create<int>(identitySet: true);
  /// final readOnlyNucleus = TissueSetNucleus.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlySet = TissueSet.fromNucleus(readOnlyNucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The base nucleus to extend.
  /// - [override]: Optional. A complete nucleus whose properties are layered
  ///   on top of the principal.
  /// - [bind]: Optional override for the upstream cell.
  /// - [context]: Optional override for the execution context.
  /// - [receptor]: Optional override for the mutation processor.
  /// - [testRule]: Optional override for the validation rule.
  /// - [synapses]: Optional override for propagation behaviour.
  ///
  /// ### Returns:
  /// A new [TissueSetNucleus<E>] instance that acts as a specialised
  /// behavioral layer over the [principal].
  factory TissueSetNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<E,TissueSet<E>>? receptor,
    TestTissue<E,TissueSet<E>>? testRule,
    Synapses? synapses,

    TissueSetNucleus<E>? override,
    required TissueSetNucleus<E> principal
  }) = _TissueSetNucleus<E,TissueSet<E>>.evolve;

  /// A static utility factory that produces a type‑safe nucleus configuration
  /// for a specific element type [E] and a specialised [TissueSet] interface [C].
  ///
  /// This method serves as the preferred architectural entry point for
  /// configuring reactive sets when working with generic collection
  /// implementations. It ensures that all behavioural components are strictly
  /// aligned with the target interface [C], providing compile‑time safety for
  /// complex set logic.
  ///
  /// ### When to use
  /// Use this when you are building a custom set implementation that extends
  /// [TissueSet] and you want to ensure type safety between the set and its
  /// receptor/testRule.
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [container] parameter determines the storage strategy (standard Set
  ///   or IdentitySet).
  ///
  /// ### Non‑obvious
  /// - The [forceLock] flag, when `true`, allows sharing the principal's lock.
  ///   This is typically used for deputies to maintain a single atomic boundary.
  /// - The [container] parameter can be used to explicitly set the storage
  ///   strategy – useful for custom container types.
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (e.g., Set or IdentitySet).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A nucleus instance strictly configured for the specified element and
  /// tissue types.
  static TissueSetNucleusBase<E,C> create<E,C extends TissueSet<E>>({
    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueSetNucleusBase<E,C>? principal
  }) {

    if (principal != null) {
      final local = TissueNucleusBase.local<E,Set<E>,C>(
        container: container,
        bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user,
      );
      return _TissueSetNucleus<E,C>.fromRecord(
          (mask: local, principal: principal)
      );
    }

    return _TissueSetNucleus<E,C>(
        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? TissueReceptor.passThrough,
        testRule: testRule ?? TestTissue.allowAll,
        synapses: synapses ?? Synapses.enabled,
        identitySet: container == Container.identitySet,
        user: user,
        forceLock: forceLock
    );

  }

  /// Creates an independent, decoupled clone of the current [TissueSetNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** specifically for reactive
  /// set configurations. It generates a peer instance that replicates the
  /// structural logic and uniqueness strategy (such as the [identitySet] status
  /// resolved via [containerType]) of the original without sharing its internal
  /// lifecycle state, observer registry, or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent sets.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a set instance.
  ///
  /// ### Non‑obvious
  /// - The clone does **not** share the same `principal` – it is a root nucleus
  ///   (no parent). This means it does not inherit from the original.
  /// - Cloning is a zero‑copy operation for the logic – the logic is shared
  ///   via the flyweight record, but the state (lock, synapses) is new.
  ///
  /// ### Returns:
  /// A new [TissueSetNucleus<E>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueSetNucleus<E> get clone;

  /// Retrieves the physical storage strategy ([Container]) defining the
  /// uniqueness and allocation policy for the [TissueSet].
  ///
  /// This property identifies the specialised data structure or allocation
  /// policy—specifically distinguishing between a standard [Set] (equality‑based)
  /// or an [identitySet] (referential‑based)—that holds the actual elements [E].
  ///
  /// ### When to use
  /// Read this to understand how elements are compared for uniqueness
  /// (value equality vs identity). This is useful for conditional logic or
  /// debugging.
  ///
  /// ### How it works
  /// - The value is resolved by walking up the principal chain if not defined
  ///   locally.
  /// - It defaults to [Container.set] if no container type is set.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed and cannot be changed
  ///   through a deputy. All deputies inherit the same container type.
  /// - The container type affects how duplicates are detected (e.g., `identitySet`
  ///   uses [identical]).
  @override
  Container get containerType;

}

/// A high‑performance, reactive implementation of a [Set] that integrates the standard
/// Dart [Set] contract with the `cell_tissue` conactive signalling ecosystem.
///
/// [TissueSet] is an `abstract interface class` that serves as the primary
/// container for unique elements within the reactive graph. It extends [Tissue]
/// to provide a synchronised, observable environment where structural changes
/// (additions/removals) and member‑level mutations are governed by strict
/// validation rules and propagated through the synaptic network.
///
/// ### When to use
/// Use a [TissueSet] whenever you need a collection of unique elements that:
/// - Must be observable (UI updates automatically on changes).
/// - Must enforce invariants (e.g., element type, value range).
/// - Must be shared between components with different permissions (via deputies).
/// - Must participate in the reactive graph as a first‑class cell.
/// - Requires deduplication based on value equality or identity.
///
/// Most of the time, you create a [TissueSet] using the [TissueSet] factory,
/// optionally providing a [testRule] for validation:
/// ```dart
/// final tags = TissueSet<String>();
/// final validated = TissueSet<int>(
///   testRule: TestTissue<int>((v) => v >= 0),
/// );
/// ```
///
/// ### How it works
/// - Internally, it uses a [TissueSetNucleus] to govern behaviour and a
///   [Container] for physical storage.
/// - Every mutation (e.g., `add`, `remove`, `clear`) goes through a validation
///   pipeline ([testRule]) and emits a [TissueEvent].
/// - The set is thread‑safe via its internal [Lock].
/// - It can be **deputised** to create restricted views (read‑only, scoped
///   authority, etc.) that share the same storage.
/// - It supports both value‑based and identity‑based uniqueness.
/// - It automatically links child [Cell]s when they are added, enabling
///   "bubbling" of internal changes.
///
/// ### Non‑obvious
/// - Equality (`==`) is based on the underlying set's content and identity,
///   so `set1 == set2` works like a normal Dart set.
/// - The [async] getter returns a [ModifiableSetAsync] for `Future`‑based
///   operations, useful for network callbacks or background tasks.
/// - The `unmodifiable` getter is **not a snapshot** – it's a live view that
///   stays in sync with the source.
/// - The [modifiable] getter returns the list of functions that can be invoked
///   via `apply`. For read‑only deputies, this list is empty.
/// - If an element is already in the set (based on equality/identity), adding
///   it again does nothing and does not emit an event.
///
/// ### Example: Basic usage
/// ```dart
/// final set = TissueSet<String>();
/// set.add('apple');
/// set.add('apple'); // no effect – already present
/// print(set.length); // 1
///
/// // Listen for changes
/// set.listen((event) {
///   if (event is ElementAddedEvent<String>) {
///     print('Added: ${event.payload}');
///   }
/// });
/// set.add('banana'); // prints "Added: banana"
/// ```
///
/// ### Example: Validation
/// ```dart
/// final validSet = TissueSet<int>(
///   testRule: TestTissue<int>((v) => v >= 0 && v <= 100),
/// );
/// validSet.add(50); // allowed
/// validSet.add(150); // rejected – no event emitted
/// ```
///
/// ### Example: Identity‑based set (for mutable objects)
/// ```dart
/// final identitySet = TissueSet.identity<MyMutableClass>();
/// final obj1 = MyMutableClass('id');
/// final obj2 = MyMutableClass('id'); // same value, different instance
/// identitySet.add(obj1);
/// identitySet.add(obj2); // both are kept (different identities)
/// print(identitySet.length); // 2
/// ```
///
/// ### Example: Read‑only deputy for UI
/// ```dart
/// final source = TissueSet<String>();
/// final uiView = source.deputy(testRule: TestTissue.readOnly);
/// // uiView can be safely passed to a widget tree
/// // Changes to source are reflected in uiView automatically
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements managed by the set.
///
/// See also:
/// - [Tissue] – the base interface for all reactive collections.
/// - [TissueSetNucleus] – the blueprint and configuration for the set.
/// - [UnmodifiableTissueSet] – a read‑only deputy variant.
abstract interface class TissueSet<E> implements Tissue<E>, Set<E> {

  /// Internal access to the specific property configuration for this set.
  @override
  TissueSetNucleus<E> get _nucleus;

  /// The primary architectural factory for instantiating a [TissueSet],
  /// creating a reactive, unique collection governed by the **Conactive Model**.
  ///
  /// This factory serves as the standard entry point for materialising a
  /// synchronised set that participates in the `cell` framework's
  /// high‑fidelity data‑flow graph. It orchestrates the relationship between
  /// the logical governance layer (the [Nucleus]) and the physical storage
  /// layer (the [Container]), ensuring that every mutation—whether adding
  /// a unique element or clearing the collection—is atomic, validated,
  /// and observable.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive set with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [TissueSet.create] or [TissueSet.fromNucleus].
  ///
  /// ### How it works
  /// - You provide an optional initial [elements] iterable and optional
  ///   governance parameters.
  /// - The set is created and automatically linked to any child cells.
  ///
  /// ### Parameters:
  /// - [elements]: Optional initial elements.
  /// - [bind]: Optional upstream [Cell] for reactive dependency.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: [TissueReceptor] for processing mutations.
  /// - [testRule]: [TestTissue] for validating changes.
  /// - [synapses]: [Synapses] configuration for broadcasting.
  /// - [identitySet]: Whether to use identity‑based uniqueness (default: false).
  ///
  /// ### Returns:
  /// A new [TissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final set = TissueSet<int>([1, 2, 3]);
  /// ```
  factory TissueSet(Iterable<E> elements, {
    Cell? bind,
    Context context,
    TestTissue<E,TissueSet<E>> testRule,
    TissueReceptor<E,TissueSet<E>> receptor,
    Synapses synapses,
    bool identitySet
  }) = _TissueSet<E,TissueSet<E>>;

  /// Architectural factory for instantiating an empty, reactive [TissueSet]
  /// governed by the **Conactive Model**.
  ///
  /// This constructor is the preferred entry point for materialising a unique
  /// collection that begins its lifecycle without data but requires full
  /// integration into the `cell` framework's reactive graph. It facilitates
  /// the creation of a "Hot" state node—ready to observe, validate, and
  /// synchronise future mutations.
  ///
  /// ### When to use
  /// Use this when you need an empty set that will be populated later.
  ///
  /// ### How it works
  /// - It creates an empty set with the provided governance parameters.
  /// - The set is fully integrated into the reactive graph.
  ///
  /// ### Parameters:
  /// - [bind], [context], [receptor], [testRule], [synapses], [identitySet] as
  ///   in the default constructor.
  ///
  /// ### Returns:
  /// A new, empty [TissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final emptySet = TissueSet.empty<int>();
  /// ```
  factory TissueSet.empty({
    Cell? bind,
    Context context,
    TestTissue<E,TissueSet<E>> testRule,
    TissueReceptor<E,TissueSet<E>> receptor,
    Synapses synapses,
    bool identitySet
  }) = _TissueSet<E,TissueSet<E>>.empty;

  /// Factory constructor to create a new, pre‑populated [TissueSet] from an
  /// [Iterable] of elements.
  ///
  /// This constructor serves as a high‑level utility for materialising a
  /// reactive, unique collection that begins its lifecycle with an initial
  /// population of data. It ensures that the transition from a standard Dart
  /// [Iterable] to a synchronised **Conactive** node is performed atomically,
  /// securely, and within the framework's governance rules.
  ///
  /// ### When to use
  /// Use this when you already have an iterable of data and want to turn it
  /// into a reactive set in one step.
  ///
  /// ### How it works
  /// - It creates a nucleus (with the provided parameters) and then ingests
  ///   the [elements] atomically under a lock.
  /// - Any elements that are [Cell]s are automatically linked to the set.
  ///
  /// ### Parameters:
  /// - [elements]: The source data.
  /// - [nucleus]: Optional blueprint.
  ///
  /// ### Example
  /// ```dart
  /// final set = TissueSet.of([1, 2, 3], nucleus: myNucleus);
  /// ```
  factory TissueSet.of(Iterable<E> elements, {
    TissueSetNucleus<E>? nucleus
  }) => _TissueSet<E,TissueSet<E>>.fromNucleus(
      nucleus ?? TissueSetNucleus<E>(), elements: Set<E>.of(elements)
  );

  /// Factory constructor to create a new, pre‑populated [TissueSet] from an
  /// [Iterable] of elements, performing dynamic type casting.
  ///
  /// This constructor is a high‑level utility for materialising a reactive,
  /// unique collection from data sources where the element type may not be
  /// statically guaranteed (e.g., JSON decoding or heterogeneous legacy
  /// collections). It ensures that the transition to a synchronised
  /// **Conactive** node is performed with **Atomic Population** and
  /// **Structural Validation**.
  ///
  /// ### When to use
  /// Use this when you have an iterable of unknown type and want to cast it
  /// to [E] in a single step.
  ///
  /// ### How it works
  /// - It uses `Set<E>.from(elements)` to perform the cast.
  /// - The resulting set is then ingested atomically.
  ///
  /// ### Parameters:
  /// - [elements]: The source data (will be cast to [E]).
  /// - [nucleus]: Optional blueprint.
  ///
  /// ### Example
  /// ```dart
  /// final dynamicList = [1, 2, 3] as List<dynamic>;
  /// final set = TissueSet.from<int>(dynamicList);
  /// ```
  factory TissueSet.from(Iterable elements, {
    TissueSetNucleus<E>? nucleus
  }) => _TissueSet<E,TissueSet<E>>.fromNucleus(
      nucleus ?? TissueSetNucleus<E>(), elements: Set<E>.from(elements)
  );

  /// Architectural factory for instantiating a [TissueSet] that utilises
  /// **Referential Identity** ([identical]) for membership and uniqueness.
  ///
  /// This constructor is a specialised entry point for creating a reactive set
  /// where the "Identity" of an object is distinct from its "Value." It ensures
  /// that even if two elements have the exact same field values (equal via `==`),
  /// they are treated as unique members if they are different instances
  /// in memory.
  ///
  /// ### When to use
  /// Use this when you need to track elements by identity rather than value.
  /// This is essential when elements are mutable objects (like [Cell]s) whose
  /// internal state might change, which would break a value‑based set.
  ///
  /// ### How it works
  /// - It creates a nucleus with `identitySet: true`.
  /// - The underlying storage uses [LinkedHashSet.identity].
  /// - All membership checks use [identical].
  ///
  /// ### Parameters:
  /// - [bind], [context], [testRule], [receptor], [synapses] as in the
  ///   default constructor.
  ///
  /// ### Example
  /// ```dart
  /// final identitySet = TissueSet.identity<MyKey>();
  /// final key1 = MyKey('id');
  /// final key2 = MyKey('id');
  /// identitySet.add(key1);
  /// identitySet.add(key2); // both are kept
  /// print(identitySet.length); // 2
  /// ```
  factory TissueSet.identity({
    Cell? bind,
    Context context = Context.system,
    TestTissue<E,TissueSet<E>> testRule = TestTissue.allowAll,
    TissueReceptor<E,TissueSet<E>> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
  }) => _TissueSet<E,TissueSet<E>>.fromNucleus(
      TissueSetNucleus<E>(
          bind: bind,
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses,
          identitySet: true
      )
  );

  /// Primary architectural factory for materialising a [TissueSet] from an
  /// existing [TissueSetNucleus] (the "Reactive DNA").
  ///
  /// This constructor is the preferred entry point for the **Blueprint‑First
  /// Initialisation** pattern. It decouples the definition of the set's
  /// governance—including its uniqueness strategy, security rules, and
  /// command processing—from the instantiation of the reactive node itself.
  ///
  /// ### When to use
  /// - You have a reusable nucleus (e.g., a "ValidatedUserSet" blueprint).
  /// - You are building a custom set implementation that needs a specific
  ///   nucleus configuration.
  /// - You are restoring a set from a serialised state where the nucleus is
  ///   already constructed.
  ///
  /// ### How it works
  /// - The set adopts the nucleus's rules, context, and receptor.
  /// - If [elements] are provided, they are ingested atomically and validated
  ///   against the nucleus's [testRule].
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueSetNucleus.create<int>(
  ///   testRule: TestTissue<int>((v) => v > 0),
  ///   identitySet: true,
  /// );
  /// final set = TissueSet.fromNucleus(nucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The blueprint to use.
  /// - [elements]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [TissueSet<E>] instance.
  factory TissueSet.fromNucleus(TissueSetNucleus<E> nucleus, {Iterable<E>? elements})
  = _TissueSet<E,TissueSet<E>>.fromNucleus;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueSet].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `set.unmodifiable` instead.
  ///
  /// ### When to use
  /// Use this when you need to share a set with code that should only read
  /// data, never write it. For example, passing a set to a UI widget.
  ///
  /// ### How it works
  /// - It creates a read‑only deputy that shares the same storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` and optionally projects child cells.
  /// - The view is live and stays in sync with the source.
  ///
  /// ### Parameters
  /// - [bind]: The source set to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [TissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueSet<int>();
  /// final readOnly = TissueSet.unmodifiable(source);
  /// // readOnly.add(1); // blocked
  /// source.add(1); // readOnly reflects the change
  /// ```
  factory TissueSet.unmodifiable(TissueSet<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueSet<E,TissueSet<E>>.view;

  /// A high‑fidelity, strategy‑based factory for creating specialised
  /// [TissueSetBase] instances with explicit control over their
  /// reactive DNA and storage mechanics.
  ///
  /// This method serves as the primary **Architectural Entry Point** for
  /// constructing reactive sets within the `cell_tissue` ecosystem.
  /// It facilitates the assembly of a [TissueSet] by combining
  /// physical storage strategies, security rules, and execution contexts
  /// into a single, synchronised reactive node.
  ///
  /// ### When to use
  /// Use this when the simple [TissueSet] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]).
  /// - Provide a custom [receptor] or [testRule] with full type safety.
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueSetNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the set from that nucleus, optionally ingesting
  ///   [elements].
  /// - The [principal] parameter allows you to inherit configuration from an
  ///   existing nucleus, enabling the deputy pattern at the nucleus level.
  ///
  /// ### Parameters
  /// - [elements]: Optional initial data.
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (e.g., Set or IdentitySet).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A concrete [TissueSetBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final set = TissueSet.create<int, TissueSet<int>>(
  ///   container: Container.identitySet,
  ///   elements: [1, 2, 3],
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  static TissueSetBase<E,C> create<E,C extends TissueSet<E>>({
    Iterable<E>? elements,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueSetNucleusBase<E,C>? principal
  }) {
    final nucleus = TissueSetNucleus.create<E,C>(
        bind: bind,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses,
        container: container,
        user: user,
        forceLock: forceLock,
        principal: principal
    );
    return _TissueSet<E,C>.fromNucleus(nucleus, elements: elements);

  }

  /// Creates a "Deputy" projection of this set—a specialised proxy that
  /// shares the same physical data but operates under unique behavioural rules.
  ///
  /// The [deputy] method is the primary engine for **Security Scoping** and
  /// **Behavioural Specialisation** within the `cell_tissue` ecosystem.
  /// It implements the **Deputy Pattern**, allowing a single "Principal"
  /// collection to be viewed through multiple restricted or specialised
  /// lenses without duplicating the underlying storage.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the set:
  /// - Read‑only view: `set.deputy(testRule: TestTissue.readOnly)`
  /// - Scoped authority: `set.deputy(context: DeputyContext.delegate(...))`
  /// - Temporary access: `set.deputy(ephemeralPolicy: ...)`
  ///
  /// ### How it works
  /// - The deputy shares the same physical storage and lock as the source.
  /// - The provided [testRule] is layered on top of the principal's rule
  ///   (you can only narrow permissions, never widen).
  /// - The deputy gets its own [Synapses] registry by default, so it can have
  ///   its own observers.
  /// - If all parameters are left at default, `deputy()` returns `this`.
  ///
  /// ### Non‑obvious
  /// - The deputy is logically equal to its principal (`deputy == principal`).
  /// - The deputy's [context] can be overridden to change priority or security.
  /// - The [ephemeralPolicy] controls the deputy's lifetime independently of
  ///   the principal.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueSet<String>();
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly.add('A'); // blocked
  /// source.add('A'); // readOnly reflects the change
  /// ```
  @override
  FutureOr<TissueSet<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// Returns a read‑only, reactive projection of this [TissueSet].
  ///
  /// This getter creates a specialised "View" (a Deputy) that provides a safe,
  /// immutable interface to the underlying data while maintaining a live,
  /// synchronised connection to the source state.
  ///
  /// ### When to use
  /// Use this when you need to share the set with components that should
  /// observe changes but never mutate it – e.g., UI widgets, loggers.
  ///
  /// ### How it works
  /// - Shares the same physical storage and lock as the source.
  /// - Applies `TestTissue.readOnly` – all mutations are blocked.
  /// - The view is **live** – changes to the source are immediately reflected.
  /// - If the source contains child [Cell]s, they are also projected as
  ///   read‑only deputies.
  ///
  /// ### Returns
  /// A read‑only [TissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueSet<int>();
  /// final readOnly = source.unmodifiable;
  /// // readOnly.add(1); // blocked
  /// source.add(1);
  /// print(readOnly.length); // 1 (live update)
  /// ```
  @override
  TissueSet<E> get unmodifiable;

  /// Returns an [Async] wrapper for this set to perform non‑blocking mutations.
  ///
  /// The [async] getter returns a [ModifiableSetAsync] object. This allows
  /// you to perform set operations (like `add`, `remove`) and `await`
  /// their completion, which includes the propagation of reactive signals.
  ///
  /// ### When to use
  /// - You are in an `async` context (e.g., a network callback) and need to
  ///   wait for the mutation to be fully processed.
  /// - You want to avoid blocking the UI thread during a batch of updates.
  ///
  /// ### Example
  /// ```dart
  /// final set = TissueSet<int>();
  /// await set.async.add(42);
  /// ```
  @override
  ModifiableSetAsync<E> get async;

}

/// A read‑only, reactive [Set] that reflects the state of a source collection
/// but prohibits direct structural mutations.
///
/// [UnmodifiableTissueSet] is an `abstract interface class` that
/// implements both [TissueSet] and [UnmodifiableTissue]. It serves as
/// the primary architectural mechanism for exposing unique collections within
/// the `cell_tissue` ecosystem while ensuring data encapsulation and
/// behavioural safety.
///
/// ### When to use
/// Use an unmodifiable set when you need to share a set with a component
/// that should **observe** changes but **never** initiate them. Common
/// scenarios include:
/// - Passing a set to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You never implement this interface directly. You obtain an instance by
/// calling the `.unmodifiable` getter on a [TissueSet]:
/// ```dart
/// final source = TissueSet<int>();
/// final readOnly = source.unmodifiable; // UnmodifiableTissueSet<int>
/// ```
///
/// ### How it works
/// - **Zero‑copy sharing**: The unmodifiable view uses the **same physical
///   storage** and **same lock** as the mutable source. No data is duplicated.
/// - **Mutation barrier**: The `modifiable` getter returns an empty set, and
///   the internal `TestTissue` policy is set to `readOnly`. Any attempt to
///   call `add`, `remove`, `clear`, or `apply` with a mutation function
///   throws an [UnsupportedError] or is silently rejected.
/// - **Live reactivity**: Because it shares the same storage, changes made
///   to the source are **immediately** and **atomically** reflected in the
///   view. Observers attached to the view still receive pulses.
/// - **Deep immutability**: If `unmodifiableElement` is `true` (the default),
///   any element that is itself a [Cell] is automatically projected as its
///   `.unmodifiable` deputy when accessed. This prevents "side‑door"
///   mutations.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: Unlike `Set.unmodifiable` in Dart, this view
///   is **live**. If the source changes, the view changes with it.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: Iterating over the view yields unmodifiable
///   deputies of any child [Cell]s.
/// - **Own observer registry**: The view has its own [Synapses] registry, so
///   observers attached to the view are separate from those on the source.
///
/// ### Example: Read‑only UI projection
/// ```dart
/// final source = TissueSet<String>({'a', 'b'});
/// final readOnly = source.unmodifiable;
/// // Render in a widget
/// myWidget(data: readOnly);
/// // Later, source.add('c');
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements contained in the set.
///
/// See also:
/// - [TissueSet] – the mutable counterpart.
/// - [UnmodifiableTissue] – the general contract for read‑only tissues.
abstract interface class UnmodifiableTissueSet<E> implements TissueSet<E>, UnmodifiableTissue<E> {

  /// The primary architectural factory for instantiating an [UnmodifiableTissueSet],
  /// materializing a read‑only, reactive set from an initial collection of [elements].
  ///
  /// This factory is a fundamental component of the framework's **Security Scoping**
  /// and **Deep Immutability** architecture. It is designed to initialise a set
  /// node that conceptually represents a "Fixed Unique Data Set" or "Snapshot"
  /// that remains reactive—meaning it can be observed and synchronised across the
  /// graph—but strictly prohibits structural modification.
  ///
  /// ### When to use
  /// Use this when you need a standalone immutable set that is not derived
  /// from a mutable source – e.g., for configuration data or constants.
  ///
  /// ### How it works
  /// - The factory creates a new set node with a read‑only nucleus.
  /// - The provided [elements] are stored in a physical container that is
  ///   never modified.
  /// - If [unmodifiableElement] is `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - The set is fully reactive but blocks all mutations.
  ///
  /// ### Parameters:
  /// - [elements]: The immutable data set.
  /// - [nucleus]: Optional blueprint; if omitted, a standard read‑only nucleus
  ///   is used.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final roles = UnmodifiableTissueSet<String>(
  ///   ['admin', 'editor', 'viewer'],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  factory UnmodifiableTissueSet(Iterable<E> elements, {
    TissueSetNucleus<E>? nucleus,
    bool unmodifiableElement,
  }) = _UnmodifiableTissueSet<E,TissueSet<E>>;

  /// A high‑fidelity architectural factory for creating a **Deeply Immodifiable
  /// Reactive View** (Deputy) of an existing [TissueSet].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `set.unmodifiable` instead.
  ///
  /// ### When to use
  /// Use this when you need fine‑grained control over the view's [context] or
  /// [unmodifiableElement] flag.
  ///
  /// ### How it works
  /// - It creates a read‑only deputy that shares the same storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` and optionally projects child cells.
  /// - The view is live and stays in sync with the source.
  ///
  /// ### Parameters
  /// - [bind]: The source set to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [UnmodifiableTissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueSet<int>();
  /// final readOnly = UnmodifiableTissueSet.view(source);
  /// ```
  factory UnmodifiableTissueSet.view(TissueSet<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueSet<E,TissueSet<E>>.view;

  /// A low‑level architectural factory for materializing an
  /// [UnmodifiableTissueSet] directly from a pre‑constructed
  /// reactive blueprint ([nucleus]).
  ///
  /// This constructor is the primary **Materialization Hook** used when the
  /// behavioural identity—including security rules, execution context, and
  /// synchronisation domain—has already been synthesised (e.g., via
  /// [TissueSetNucleus.evolve] or a custom [Deputy] derivation).
  ///
  /// ### When to use
  /// Use this when you already have a pre‑configured read‑only nucleus and want
  /// to instantiate a set from it. Typically used in advanced customisation
  /// or serialisation scenarios.
  ///
  /// ### How it works
  /// - The set adopts the nucleus's rules, context, and receptor.
  /// - If [elements] are provided, they are ingested atomically.
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters:
  /// - [nucleus]: The pre‑configured read‑only blueprint.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [elements]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [UnmodifiableTissueSet<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyNucleus = TissueSetNucleus.evolve(
  ///   principal: myNucleus,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlySet = UnmodifiableTissueSet.fromNucleus(readOnlyNucleus);
  /// ```
  factory UnmodifiableTissueSet.fromNucleus(TissueSetNucleus<E> nucleus, {bool unmodifiableElement, Iterable<E>? elements})
  = _UnmodifiableTissueSet<E,TissueSet<E>>.fromNucleus;

  /// A high‑level architectural factory for creating a specialised, type‑safe
  /// [UnmodifiableTissueSet] with granular control over its behavioural
  /// and structural identity.
  ///
  /// This static method serves as the primary entry point for constructing
  /// read‑only reactive sets that require deep customisation of their
  /// reactive blueprint. It streamlines the process by simultaneously
  /// resolving the property hierarchy and initialising the node within the
  /// reactive data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simpler factories don't provide enough control – e.g.,
  /// when you need to specify a custom [container] strategy, provide a
  /// specialised [receptor], or inherit from a [principal] nucleus.
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueSetNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the unmodifiable set from that nucleus, optionally
  ///   ingesting [elements].
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters
  /// - [elements]: Optional initial data.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy.
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns
  /// A concrete [UnmodifiableTissueSetBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlySet = UnmodifiableTissueSet.create<int, TissueSet<int>>(
  ///   container: Container.identitySet,
  ///   elements: [1, 2, 3],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  static UnmodifiableTissueSetBase<E,C> create<E,C extends TissueSet<E>>({
    Iterable<E>? elements,
    bool unmodifiableElement = true,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueSetNucleusBase<E,C>? principal,
  }) {
    return _UnmodifiableTissueSet<E,C>.fromNucleus(
        TissueSetNucleus.create<E,C>(
            bind: bind,
            context: context,
            testRule: testRule,
            receptor: receptor,
            synapses: synapses,

            container: container,
            user: user,
            forceLock: forceLock,
            principal: principal
        ),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

}