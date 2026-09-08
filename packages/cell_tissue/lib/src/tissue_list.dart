// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A specialised, configuration‑centric interface that defines the behavioural
/// blueprint, security constraints, and execution strategy for a [TissueList].
///
/// [TissueListNucleus] acts as the **"DNA"** or the **"Instruction Set"** of a
/// reactive list. Within the `cell.core` and `cell_tissue` ecosystem, a
/// [TissueList] is architecturally split into two distinct parts: the
/// **Container** (which holds the physical [List] data) and the **Nucleus**
/// (which holds the reactive logic, validation rules, and identity).
///
/// ### When to use
/// You might reference this type when you need to:
/// - Pass a pre‑configured nucleus to [TissueList.fromNucleus] to reuse a
///   validated list blueprint.
/// - Extend a custom list implementation that needs to override the default
///   behaviour.
/// - Debug why a list is behaving in a certain way – inspect its nucleus to see
///   the `testRule`, `growable` status, etc.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [TissueList]. You interact with it indirectly when
/// creating a list via [TissueList] or [TissueList.create].
///
/// ### How it works
/// - The nucleus holds all the **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** via [containerType]
///   (growable vs fixed‑length list).
/// - A nucleus can be **evolved** (via the `evolve` factory) to create a
///   deputy – a restricted view that shares the same data but applies different
///   rules or context.
/// - The nucleus is immutable; once created, it cannot be changed. Any
///   variation requires creating a new nucleus (or deputy).
///
/// ### Non‑obvious
/// - The [growable] flag is **structural**: it is fixed at creation and
///   inherited by all deputies. You cannot change a fixed‑length list into a
///   growable one through a deputy.
/// - The nucleus is a **flyweight** – many lists can share the same nucleus
///   (and thus the same logic) without duplicating memory.
/// - The [clone] getter creates a fresh copy of the nucleus with its own
///   [Lock] and [Synapses]. This is used internally when you create a new list
///   from an already‑activated nucleus to avoid sharing locks.
/// - The `principal` chain allows hierarchical inheritance – a deputy nucleus
///   can override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueListNucleus.create<int>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   growable: true,
/// );
/// final list1 = TissueList.fromNucleus(validNucleus);
/// final list2 = TissueList.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements held within the associated [TissueList].
///
/// See also:
/// - [TissueList] – the reactive list instance governed by this nucleus.
/// - [TissueReceptor] – the engine that processes mutation signals.
/// - [TestTissue] – the validation logic for collection elements.
abstract interface class TissueListNucleus<E> implements TissueNucleus<E> {

  /// Creates a primary [TissueListNucleus] configuration, defining the
  /// foundational "Reactive DNA" and behavioural blueprint for a [TissueList].
  ///
  /// This factory is the standard architectural constructor for initialising the
  /// governance layer of a reactive list. It utilises the **Flyweight Record
  /// Pattern** to internalise the provided parameters into a compact, deeply
  /// immutable configuration record.
  ///
  /// ### When to use
  /// Use this when you are building a custom list configuration from scratch.
  /// For most use cases, the simpler [TissueList] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [growable] flag (default true) and optional governance
  ///   parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple lists that
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
  /// - [growable]: Whether the list can change size (default: true).
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueListNucleus<E>] instance strictly configured
  /// according to the provided reactive blueprint.
  factory TissueListNucleus({
    Cell? bind,
    Context context,
    TissueReceptor<E, TissueList<E>> receptor,
    TestTissue<E, TissueList<E>> testRule,
    Synapses synapses,
    bool growable,
    Record? user,
  }) = _TissueListNucleus<E, TissueList<E>>;

  /// Creates a derived [TissueListNucleus] by mutating or extending
  /// an existing [principal] configuration.
  ///
  /// This factory is the architectural implementation of **Prototypal Inheritance**
  /// and **Behavioural Shadowing** within the reactive list ecosystem. It
  /// allows for the creation of specialised "Deputy" configurations that logically
  /// inherit the structural DNA of a [principal] while selectively overriding
  /// specific operational traits.
  ///
  /// ### When to use
  /// This is the engine behind the `deputy()` method on [TissueList]. You
  /// rarely call it directly. Use it when you need a restricted view of a list
  /// that shares the same storage but applies different validation or context.
  ///
  /// ### How it works
  /// - The new nucleus inherits all properties from [principal] unless
  ///   explicitly overridden.
  /// - You can override the [testRule] (to narrow permissions), [context] (to
  ///   change authority), [receptor] (to transform mutations), or [synapses].
  /// - The [growable] status is always inherited and cannot be changed.
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
  /// final principal = TissueListNucleus.create<int>();
  /// final readOnlyNucleus = TissueListNucleus.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyList = TissueList.fromNucleus(readOnlyNucleus);
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
  /// A new [TissueListNucleus<E>] instance that acts as a specialised
  /// behavioral layer over the [principal].
  factory TissueListNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<E, TissueList<E>>? receptor,
    TestTissue<E, TissueList<E>>? testRule,
    Synapses? synapses,

    TissueListNucleus<E>? override,
    required TissueListNucleus<E> principal
  }) = _TissueListNucleus<E, TissueList<E>>.evolve;

  /// A static utility factory that produces a type‑safe nucleus configuration
  /// for a specific element type [E] and a specialised [TissueList] interface [C].
  ///
  /// This method is the preferred architectural entry point for configuring
  /// properties when working with generic collection implementations that
  /// extend [TissueList]. It ensures that all behavioural components are
  /// strictly aligned with the target interface [C], providing compile‑time
  /// safety for complex list logic.
  ///
  /// ### When to use
  /// Use this when you are building a custom list implementation that extends
  /// [TissueList] and you want to ensure type safety between the list and its
  /// receptor/testRule.
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [container] parameter determines the storage strategy (growable or
  ///   fixed‑length).
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
  /// - [container]: Optional storage strategy (e.g., growable or fixed).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A nucleus instance strictly configured for the specified element and
  /// tissue types.
  static TissueListNucleusBase<E,C> create<E, C extends TissueList<E>>({
    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueListNucleusBase<E,C>? principal
  }) {

    if (principal != null) {
      final local = TissueNucleusBase.local<E,Set<E>,C>(
        container: container,
        bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user,
      );
      return _TissueListNucleus<E,C>.fromRecord(
          (mask: local, principal: principal)
      );
    }

    return _TissueListNucleus<E,C>(
        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? TissueReceptor.passThrough,
        testRule: testRule ?? TestTissue.allowAll,
        synapses: synapses ?? Synapses.enabled,
        growable: container == Container.growableTrue,
        user: user,
        forceLock: forceLock
    );

  }

  /// Creates an independent, decoupled clone of the current [TissueListNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** specifically for reactive
  /// list configurations. It generates a peer instance that replicates the
  /// structural logic and list‑specific constraints (such as the [growable] status
  /// resolved via [containerType]) of the original without sharing its
  /// internal lifecycle state, observer registry, or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent lists.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a list instance.
  ///
  /// ### Non‑obvious
  /// - The clone does **not** share the same `principal` – it is a root nucleus
  ///   (no parent). This means it does not inherit from the original.
  /// - Cloning is a zero‑copy operation for the logic – the logic is shared
  ///   via the flyweight record, but the state (lock, synapses) is new.
  ///
  /// ### Returns:
  /// A new [TissueListNucleus<E>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueListNucleus<E> get clone;

  /// Retrieves the physical storage strategy ([Container]) defining the
  /// growth and allocation policy for the [TissueList].
  ///
  /// This property identifies the specialised data structure strategy—specifically
  /// distinguishing between a standard [Container.growableTrue] or a fixed‑length
  /// [Container.growableFalse]—that holds the actual elements [E].
  ///
  /// ### When to use
  /// Read this to understand whether the list can change size. This is useful
  /// for conditional UI logic (e.g., disabling an "Add" button on a fixed‑length
  /// list) or for debugging.
  ///
  /// ### How it works
  /// - The value is resolved by walking up the principal chain if not defined
  ///   locally.
  /// - It defaults to [Container.growableTrue] if no container type is set.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed and cannot be changed
  ///   through a deputy. All deputies inherit the same container type.
  /// - The container type affects which methods are allowed (e.g., `add` will
  ///   throw on a fixed‑length list).
  @override
  Container get containerType;

}

/// A reactive, observable, and optionally constrained implementation of the
/// standard Dart [List] interface.
///
/// [TissueList<E>] is a core component of the `cell_tissue` ecosystem,
/// serving as a high‑performance bridge between the familiar imperative [List]
/// API and the framework's **Conactive** reactive data‑flow graph. It allows
/// indexed collections to be treated as first‑class reactive entities (cells)
/// that participate in complex state transitions, validation cycles, and
/// cross‑thread synchronisation.
///
/// ### When to use
/// Use a [TissueList] whenever you need an ordered, indexable collection that:
/// - Must be observable (UI updates automatically on changes).
/// - Must enforce invariants (e.g., max length, element type, value range).
/// - Must be shared between components with different permissions (via deputies).
/// - Must participate in the reactive graph as a first‑class cell.
///
/// Most of the time, you create a [TissueList] using the [TissueList] factory,
/// optionally providing a [testRule] for validation:
/// ```dart
/// final numbers = TissueList<int>([1, 2, 3]);
/// final validated = TissueList<int>(
///   testRule: TestTissue<int>((v) => v > 0),
/// );
/// ```
///
/// ### How it works
/// - Internally, it uses a [TissueListNucleus] to govern behaviour and a
///   [Container] for physical storage.
/// - Every mutation (e.g., `add`, `removeAt`, `operator []=`) goes through a
///   validation pipeline ([testRule]) and emits a [TissueEvent].
/// - The list is thread‑safe via its internal [Lock].
/// - It can be **deputised** to create restricted views (read‑only, scoped
///   authority, etc.) that share the same storage.
/// - It supports both growable and fixed‑length storage (via the `growable` flag).
/// - It automatically links child [Cell]s when they are added, enabling
///   "bubbling" of internal changes.
///
/// ### Non‑obvious
/// - Equality (`==`) is based on the underlying list's content and identity,
///   so `list1 == list2` works like a normal Dart list.
/// - The [async] getter returns a [ModifiableListAsync] for `Future`‑based
///   operations, useful for network callbacks or background tasks.
/// - The `unmodifiable` getter is **not a snapshot** – it's a live view that
///   stays in sync with the source.
/// - Fixed‑length lists (growable: false) cannot change size, but you can still
///   replace elements using index assignment.
/// - The [modifiable] getter returns the list of functions that can be invoked
///   via `apply`. For read‑only deputies, this list is empty.
///
/// ### Example: Basic usage
/// ```dart
/// final list = TissueList<String>(['Hello']);
/// list.add('World');
/// print(list.length); // 2
///
/// // Listen for changes
/// list.listen((event) {
///   if (event is ElementAddedEvent<String>) {
///     print('Added: ${event.payload}');
///   }
/// });
/// list.add('!'); // prints "Added: !"
/// ```
///
/// ### Example: Validation
/// ```dart
/// final validList = TissueList<int>(
///   testRule: TestTissue<int>((v) => v >= 0 && v <= 100),
/// );
/// validList.add(50); // allowed
/// validList.add(150); // rejected – no event emitted
/// ```
///
/// ### Example: Read‑only deputy for UI
/// ```dart
/// final source = TissueList<String>(['A', 'B']);
/// final uiView = source.deputy(testRule: TestTissue.readOnly);
/// // uiView can be safely passed to a widget tree
/// // Changes to source are reflected in uiView automatically
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements contained in the list.
///
/// See also:
/// - [Tissue] – the base interface for all reactive collections.
/// - [TissueListNucleus] – the blueprint and configuration for the list.
/// - [UnmodifiableTissueList] – a read‑only deputy variant.
abstract interface class TissueList<E> implements Tissue<E>, List<E> {

  @override
  TissueListNucleus<E> get _nucleus;

  /// The primary architectural constructor for creating a [TissueList]—a
  /// reactive, synchronised, and optionally constrained implementation of
  /// the standard Dart [List] interface.
  ///
  /// This factory serves as the standard entry point for instantiating
  /// **Conactive** (Concurrent + Reactive) sequences within the `cell`
  /// framework. It orchestrates the transition from raw indexed data to
  /// a high‑fidelity reactive node by assembling physical storage, logical
  /// governance, and synaptic communication in a single atomic operation.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive list with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [TissueList.create] or [TissueList.fromNucleus].
  ///
  /// ### How it works
  /// - You provide an optional initial set of [elements].
  /// - Optionally, you can supply a [bind] (upstream cell), [receptor]
  ///   (transformation logic), [testRule] (validation), and [synapses]
  ///   (propagation configuration).
  /// - The list is created and automatically linked to any child cells.
  ///
  /// ### Parameters
  /// - [elements]: The initial data to populate the list.
  /// - [bind]: Optional upstream [Cell] for reactive dependency.
  /// - [receptor]: [TissueReceptor] for processing mutations.
  /// - [testRule]: [TestTissue] for validating changes.
  /// - [synapses]: [Synapses] configuration for broadcasting.
  /// - [growable]: Whether the list can change size (default: true).
  ///
  /// ### Returns
  /// A concrete [TissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList<int>([1, 2, 3]);
  /// print(list.length); // 3
  /// ```
  factory TissueList({
    Cell? bind,
    Context context,
    TissueReceptor<E,TissueList<E>> receptor,
    TestTissue<E,TissueList<E>> testRule,
    Synapses synapses,
    bool growable
  }) = _TissueList<E,TissueList<E>>;

  /// Creates a [TissueList] populated with elements from an existing [Iterable].
  ///
  /// This factory is the primary mechanism for migrating standard Dart
  /// data structures into the **Conactive** reactive graph. It combines
  /// the construction of a reactive node's logical "DNA" ([TissueListNucleus])
  /// with an atomic ingestion of the provided [elements], ensuring the
  /// resulting list is immediately "Live" and ready for observation.
  ///
  /// ### When to use
  /// Use this when you already have an iterable of data and want to turn it
  /// into a reactive list in one step.
  ///
  /// ### How it works
  /// - It creates a nucleus (with the provided parameters) and then ingests
  ///   the [elements] atomically under a lock.
  /// - Any elements that are [Cell]s are automatically linked to the list.
  ///
  /// ### Parameters
  /// - [elements]: The source data.
  /// - [bind], [context], [receptor], [testRule], [synapses], [growable] as
  ///   in the default constructor.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList.of([1, 2, 3], testRule: ...);
  /// ```
  factory TissueList.of(Iterable<E> elements, {
    Cell? bind,
    Context context,
    TissueReceptor<E, TissueList<E>> receptor,
    TestTissue<E, TissueList<E>> testRule,
    Synapses synapses,
    bool growable
  }) = _TissueList<E, TissueList<E>>.of;

  /// Creates a [TissueList] instance materialized from a pre‑configured
  /// [TissueListNucleus] blueprint, optionally ingesting a starting set of data.
  ///
  /// This factory is the primary architectural constructor for
  /// **Blueprint‑Driven Instantiation**. In the `cell_tissue` ecosystem,
  /// this constructor facilitates a strict separation between a list's
  /// "DNA" (its rules, context, and receptors) and its "Body" (its physical
  /// storage and elements).
  ///
  /// ### When to use
  /// - You have a reusable nucleus (e.g., a "ValidatedUserList" blueprint).
  /// - You are building a custom list implementation that needs a specific
  ///   nucleus configuration.
  /// - You are restoring a list from a serialised state where the nucleus is
  ///   already constructed.
  ///
  /// ### How it works
  /// - The list adopts the nucleus's rules, context, and receptor.
  /// - If [elements] are provided, they are ingested atomically and validated
  ///   against the nucleus's [testRule].
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueListNucleus.create<int>(
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// final list = TissueList.fromNucleus(nucleus, elements: [1, 2, 3]);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The blueprint to use.
  /// - [elements]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [TissueList<E>] instance.
  factory TissueList.fromNucleus(
      TissueListNucleus<E> properties, {
        Iterable<E>? elements
      }) = _TissueList<E, TissueList<E>>.fromNucleus;

  /// Creates a read‑only, reactive projection (Deputy) of an existing [TissueList],
  /// enforcing a strict non‑mutation contract while remaining fully synchronised
  /// with the source data.
  ///
  /// This factory is the high‑level constructor for the `.unmodifiable` getter.
  /// You almost never call it directly – instead, just write `list.unmodifiable`.
  ///
  /// ### When to use
  /// Use this when you need to share a list with code that should only read
  /// data, never write it. For example, passing a list to a UI widget.
  ///
  /// ### How it works
  /// - It creates a deputy that shares the same physical storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` – all mutations are blocked.
  /// - If `unmodifiableElement` is `true`, any child [Cell]s are also projected
  ///   as unmodifiable deputies.
  /// - The view remains **live** – changes to the source are immediately
  ///   reflected.
  ///
  /// ### Parameters
  /// - [bind]: The source list to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, recursively projects child cells as
  ///   unmodifiable.
  ///
  /// ### Returns
  /// A read‑only [TissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<int>([1, 2, 3]);
  /// final readOnly = TissueList.unmodifiable(source);
  /// // readOnly.add(4); // Throws UnsupportedError
  /// source.add(4);
  /// print(readOnly.length); // 4 (automatically updated)
  /// ```
  factory TissueList.unmodifiable(TissueList<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueList<E,TissueList<E>>.view;

  /// A high‑level architectural factory for creating a specialised, type‑safe
  /// reactive list with explicit control over its behavioural and structural blueprint.
  ///
  /// This static method serves as the primary entry point for constructing
  /// [TissueList] instances that require deep customisation. It streamlines
  /// the process by simultaneously defining the list's configuration (its "DNA")
  /// and initialising the reactive node within the data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simple [TissueList] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]).
  /// - Provide a custom [receptor] or [testRule] with full type safety.
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueListNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the list from that nucleus, optionally ingesting
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
  /// - [container]: Optional storage strategy.
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns
  /// A concrete [TissueListBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList.create<int, TissueList<int>>(
  ///   container: Container.growableFalse,
  ///   elements: [1, 2, 3],
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// ```
  static TissueListBase<E,C> create<E,C extends TissueList<E>>({
    Iterable<E>? elements,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueListNucleusBase<E,C>? principal
  }) {
    final properties = TissueListNucleus.create<E,C>(
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
    return _TissueList<E,C>.fromNucleus(properties, elements: elements);

  }

  /// Sets the element at the specified [index] to the given [value].
  ///
  /// While `operator []=` is the standard way to update an index,
  /// [setValueAt] is provided for programmatic or functional contexts
  /// where a named method is preferred. It follows the same reactive
  /// and validation pipeline as the operator.
  ///
  /// ### When to use
  /// Use this when you need to explicitly call a method rather than using
  /// the operator, e.g., in a functional pipeline or when passing the method
  /// as a callback.
  ///
  /// ### How it works
  /// - It calls `apply` with the `setValueAt` function and the arguments.
  /// - The mutation is validated by [testRule.action] and [testRule.element].
  /// - If successful, it emits an `ElementAddedEvent` (since this is an update,
  ///   it's treated as a replacement).
  ///
  /// ### Throws
  /// - [RangeError] if [index] is out of bounds.
  /// - [UnsupportedError] if the list is unmodifiable.
  void setValueAt(int index, E value);

  /// Sets the first element of the list to the given [value].
  ///
  /// This is a convenience method equivalent to `list[0] = value`.
  /// It ensures that the mutation is validated and signalled.
  ///
  /// ### Throws
  /// - [RangeError] if the list is empty.
  void setFirst(E value);

  /// Creates a delegated view (deputy) of this list with modified behavioural
  /// and validation logic.
  ///
  /// The [deputy] method is a cornerstone of the framework's security and
  /// architectural flexibility, implementing the **Deputy Pattern**. It allows
  /// for the creation of a derived [TissueList] that remains physically
  /// linked to the original (principal) data but operates under a unique
  /// layer of governance and execution context.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the list:
  /// - Read‑only view: `list.deputy(testRule: TestTissue.readOnly)`
  /// - Scoped authority: `list.deputy(context: DeputyContext.delegate(...))`
  /// - Temporary access: `list.deputy(ephemeralPolicy: ...)`
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
  /// final source = TissueList<String>(['A', 'B']);
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly.add('C'); // blocked
  /// source.add('C'); // readOnly reflects the change
  /// ```
  @override
  FutureOr<TissueList<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  // @override
  // dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
  //   ApplyTransactionScope? tx,
  //   Function? compensate,
  //   List? compensatePositional,
  //   Map<Symbol, dynamic>? compensateNamed,
  //   Cell? compensateCell,
  // });

  /// Returns a read‑only, reactive projection (Deputy) of this [TissueList].
  ///
  /// This getter provides a safe, immutable interface to the list's indexed data
  /// while maintaining a live, synchronised connection to the underlying
  /// source of truth.
  ///
  /// ### When to use
  /// Use this when you need to share the list with components that should
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
  /// A read‑only [TissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<int>([1, 2, 3]);
  /// final readOnly = source.unmodifiable;
  /// // readOnly.add(4); // blocked
  /// source.add(4);
  /// print(readOnly.length); // 4 (live update)
  /// ```
  @override
  TissueList<E> get unmodifiable;

  /// Provides an asynchronous interface for performing mutation operations.
  ///
  /// The [async] getter returns a [ModifiableListAsync] object. This allows
  /// you to perform list operations (like `add` or `remove`) and `await`
  /// their completion, which includes the propagation of reactive signals.
  ///
  /// ### When to use
  /// - You are in an `async` context (e.g., a network callback) and need to
  ///   wait for the mutation to be fully processed.
  /// - You want to avoid blocking the UI thread during a batch of updates.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList<int>();
  /// await list.async.add(42);
  /// ```
  @override
  ModifiableListAsync<E> get async;

}

/// A specialised, terminal architectural interface for a **Deeply
/// Immodifiable Reactive Sequence**.
///
/// [UnmodifiableTissueList] represents a "Security Shadow" or "Read‑Only
/// Lens" within the `cell_tissue` ecosystem. It adheres to the full
/// [TissueList] contract but structurally and logically prohibits all
/// state‑altering operations (e.g., `add`, `removeAt`, `insert`, `clear`, or
/// index‑based assignment).
///
/// ### When to use
/// Use an unmodifiable list when you need to share a list with a component
/// that should **observe** changes but **never** initiate them. Common
/// scenarios include:
/// - Passing a list to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You never implement this interface directly. You obtain an instance by
/// calling the `.unmodifiable` getter on a [TissueList]:
/// ```dart
/// final source = TissueList<int>([1, 2, 3]);
/// final readOnly = source.unmodifiable; // UnmodifiableTissueList<int>
/// ```
///
/// ### How it works
/// - **Zero‑copy sharing**: The unmodifiable view uses the **same physical
///   storage** ([Container]) and **same lock** as the mutable source. No data
///   is duplicated.
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
/// - **It is not a snapshot**: Unlike `List.unmodifiable` in Dart, this view
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
/// final source = TissueList<String>(['Apple', 'Banana']);
/// final readOnly = source.unmodifiable;
/// // Render in a widget
/// myListView(data: readOnly);
/// // Later, source.add('Cherry');
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements contained in the list.
///
/// See also:
/// - [TissueList] – the mutable counterpart.
/// - [UnmodifiableTissue] – the general contract for read‑only tissues.
abstract interface class UnmodifiableTissueList<E> implements TissueList<E>, UnmodifiableTissue<E> {

  /// The primary architectural factory for instantiating an [UnmodifiableTissueList],
  /// materializing a read‑only, reactive indexed node from an initial collection
  /// of [elements].
  ///
  /// This factory is a fundamental component of the framework's **Security Scoping**
  /// and **Deep Immutability** architecture. It is designed to initialise a list
  /// node that conceptually represents a **Fixed Sequence** or **Snapshot**
  /// that remains reactive—meaning it can be observed and synchronised across the
  /// graph—but strictly prohibits structural modification.
  ///
  /// ### When to use
  /// Use this when you need a standalone immutable list that is not derived
  /// from a mutable source – e.g., for configuration data or constants.
  ///
  /// ### How it works
  /// - The factory creates a new list node with a read‑only nucleus.
  /// - The provided [elements] are stored in a physical container that is
  ///   never modified.
  /// - If [unmodifiableElement] is `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - The list is fully reactive but blocks all mutations.
  ///
  /// ### Parameters:
  /// - [elements]: The immutable data set.
  /// - [nucleus]: Optional blueprint; if omitted, a standard read‑only nucleus
  ///   is used.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final countries = UnmodifiableTissueList<String>(
  ///   ['US', 'GB', 'DE'],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  factory UnmodifiableTissueList(Iterable<E> elements, {
    TissueListNucleus<E>? properties,
    bool unmodifiableElement,
  }) = _UnmodifiableTissueList<E,TissueList<E>>;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueList].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `list.unmodifiable` instead.
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
  /// - [bind]: The source list to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [UnmodifiableTissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<int>([1, 2, 3]);
  /// final readOnly = UnmodifiableTissueList.view(source);
  /// ```
  factory UnmodifiableTissueList.view(TissueList<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueList<E,TissueList<E>>.view;

  /// A low‑level architectural factory for materializing an [UnmodifiableTissueList]
  /// directly from a pre‑constructed reactive blueprint ([nucleus]).
  ///
  /// This constructor is the primary **Materialization Hook** used when the behavioural
  /// identity—including security rules, execution context, and synchronisation
  /// domain—has already been synthesised (e.g., via [TissueListNucleus.evolve]
  /// or a custom [Deputy] derivation).
  ///
  /// ### When to use
  /// Use this when you already have a pre‑configured read‑only nucleus and want
  /// to instantiate a list from it. Typically used in advanced customisation
  /// or serialisation scenarios.
  ///
  /// ### How it works
  /// - The list adopts the nucleus's rules, context, and receptor.
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
  /// A concrete [UnmodifiableTissueList<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyNucleus = TissueListNucleus.evolve(
  ///   principal: myNucleus,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyList = UnmodifiableTissueList.fromNucleus(readOnlyNucleus);
  /// ```
  factory UnmodifiableTissueList.fromNucleus(TissueListNucleus<E> properties, {bool unmodifiableElement, Iterable<E>? elements})
  = _UnmodifiableTissueList<E,TissueList<E>>.fromNucleus;

  /// An advanced architectural factory for creating a specialised, type‑safe
  /// [UnmodifiableTissueList] with granular control over its behavioural
  /// and structural identity.
  ///
  /// This static method serves as the primary entry point for constructing
  /// read‑only reactive lists that require deep customisation of their
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
  /// - It builds a nucleus using [TissueListNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the unmodifiable list from that nucleus, optionally
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
  /// A concrete [UnmodifiableTissueListBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyList = UnmodifiableTissueList.create<int, TissueList<int>>(
  ///   container: Container.growableFalse,
  ///   elements: [1, 2, 3],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  static UnmodifiableTissueListBase<E,C> create<E,C extends TissueList<E>>({
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
    TissueListNucleusBase<E,C>? principal,
  }) {
    return _UnmodifiableTissueList<E,C>.fromNucleus(
        TissueListNucleus.create<E,C>(
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