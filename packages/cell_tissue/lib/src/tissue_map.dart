// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A specialised, configuration‑centric interface that defines the behavioural
/// blueprint, security constraints, and execution strategy for a [TissueMap].
///
/// [TissueMapNucleus] acts as the **"DNA"** or **"Instruction Set"** of a
/// reactive map. Within the `cell.core` and `cell_tissue` ecosystem, a
/// [TissueMap] is split into two distinct parts: the **Container** (which
/// holds the physical data) and the **Nucleus** (which holds the logic,
/// validation rules, and identity).
///
/// ### When to use
/// You might reference this type when you need to:
/// - Pass a pre‑configured nucleus to [TissueMap.fromNucleus] to reuse a
///   validated map blueprint.
/// - Extend a custom map implementation that needs to override the default
///   behaviour.
/// - Debug why a map is behaving in a certain way – inspect its nucleus to see
///   the `testRule`, `identityMap` status, etc.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [TissueMap]. You interact with it indirectly when
/// creating a map via [TissueMap] or [TissueMap.create].
///
/// ### How it works
/// - The nucleus holds all the **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** via [containerType]
///   (standard Map vs. IdentityMap).
/// - A nucleus can be **evolved** (via the `evolve` factory) to create a
///   deputy – a restricted view that shares the same data but applies different
///   rules or context.
/// - The nucleus is immutable; once created, it cannot be changed. Any
///   variation requires creating a new nucleus (or deputy).
///
/// ### Non‑obvious
/// - The [identityMap] flag is **structural**: it is fixed at creation and
///   inherited by all deputies. You cannot change a value‑based map into an
///   identity‑based map through a deputy.
/// - The nucleus is a **flyweight** – many maps can share the same nucleus
///   (and thus the same logic) without duplicating memory.
/// - The [clone] getter creates a fresh copy of the nucleus with its own
///   [Lock] and [Synapses]. This is used internally when you create a new map
///   from an already‑activated nucleus to avoid sharing locks.
/// - The `principal` chain allows hierarchical inheritance – a deputy nucleus
///   can override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueMapNucleus.create<String, int>(
///   testRule: TestTissue<int>((v) => v > 0),
///   identityMap: false,
/// );
/// final map1 = TissueMap.fromNucleus(validNucleus);
/// final map2 = TissueMap.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// * [K]: The type of keys used in the associated [TissueMap].
/// * [V]: The type of values held within the associated [TissueMap].
///
/// See also:
/// - [TissueMap] – the reactive map instance governed by this nucleus.
/// - [TissueReceptor] – the engine that processes mutation signals.
/// - [TestTissue] – the validation logic for collection elements.
abstract interface class TissueMapNucleus<K,V> implements TissueNucleus<V> {

  /// Primary architectural factory for instantiating a [TissueMapNucleus],
  /// defining the **"Reactive DNA"** for a [TissueMap].
  ///
  /// This factory is the standard architectural constructor for initialising the
  /// governance layer of a reactive map. It utilises the **Flyweight Record
  /// Pattern** to internalise the provided parameters into a compact, deeply
  /// immutable configuration record.
  ///
  /// ### When to use
  /// Use this when you are building a custom map configuration from scratch.
  /// For most use cases, the simpler [TissueMap] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [identityMap] flag (default false) and optional governance
  ///   parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple maps that
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
  /// - [identityMap]: Whether keys are compared by identity (default: false).
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueMapNucleus<K, V>] instance strictly configured
  /// according to the provided reactive blueprint.
  factory TissueMapNucleus({
    Cell? bind,
    Context context,
    TissueReceptor<V, TissueMap<K, V>> receptor,
    TestTissue<V, TissueMap<K, V>> testRule,
    Synapses synapses,
    bool identityMap,
    Record? user
  }) = _TissueMapNucleus<K,V,TissueMap<K,V>>;

  /// Architectural factory for deriving a new [TissueMapNucleus] from a
  /// [principal] through the **Mutation‑Based Derivation** pattern.
  ///
  /// This factory is the primary engine behind the framework's **Deputy Pattern**.
  /// It allows for the creation of a hierarchical chain of governance where a
  /// child nucleus inherits the structural "Source of Truth" from a principal
  /// while layering specific behavioural overrides.
  ///
  /// ### When to use
  /// This is the engine behind the `deputy()` method on [TissueMap]. You
  /// rarely call it directly. Use it when you need a restricted view of a map
  /// that shares the same storage but applies different validation or context.
  ///
  /// ### How it works
  /// - The new nucleus inherits all properties from [principal] unless
  ///   explicitly overridden.
  /// - You can override the [testRule] (to narrow permissions), [context] (to
  ///   change authority), [receptor] (to transform mutations), or [synapses].
  /// - The [identityMap] status is always inherited and cannot be changed.
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
  /// final principal = TissueMapNucleus.create<String, int>();
  /// final readOnlyNucleus = TissueMapNucleus.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyMap = TissueMap.fromNucleus(readOnlyNucleus);
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
  /// A new [TissueMapNucleus<K, V>] instance that acts as a specialised
  /// behavioral layer over the [principal].
  factory TissueMapNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<V,TissueMap<K, V>>? receptor,
    TestTissue<V,TissueMap<K, V>>? testRule,
    Synapses? synapses,

    TissueMapNucleus<K,V>? override,
    required TissueMapNucleus<K,V> principal
  }) = _TissueMapNucleus<K,V,TissueMap<K,V>>.evolve;

  /// A static utility factory that produces a type‑safe nucleus configuration
  /// for a specific key type [K], value type [V], and a specialised [TissueMap]
  /// interface [C].
  ///
  /// This method is the preferred architectural entry point for defining the
  /// behavioural and structural blueprint of reactive maps. It ensures that
  /// all core components are strictly aligned with the target interface [C],
  /// providing compile‑time safety for complex map‑based data structures.
  ///
  /// ### When to use
  /// Use this when you are building a custom map implementation that extends
  /// [TissueMap] and you want to ensure type safety between the map and its
  /// receptor/testRule.
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [container] parameter determines the storage strategy (standard Map
  ///   or IdentityMap).
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
  /// - [container]: Optional storage strategy (e.g., Map or IdentityMap).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A nucleus instance strictly configured for the specified key, value, and
  /// tissue types.
  static TissueMapNucleusBase<K,V,C> create<K,V,C extends TissueMap<K,V>>({
    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueMapNucleusBase<K,V,C>? principal
  }) {
    if (principal != null) {
      final local = TissueNucleusBase.local<V,TissueMap<K,V>,C>(
        container: container,
        bind: bind,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses,
        forceLock: forceLock,
        user: user,
      );
      return _TissueMapNucleus<K,V,C>.fromRecord(
          (mask: local, principal: principal)
      );
    }

    return _TissueMapNucleus<K,V,C>(
        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? TissueReceptor.passThrough,
        testRule: testRule ?? TestTissue.allowAll,
        synapses: synapses ?? Synapses.enabled,
        identityMap: container == Container.identityMap,
        user: user,
        forceLock: forceLock
    );
  }

  /// Creates an independent, decoupled clone of the current [TissueMapNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** specifically for reactive
  /// map configurations. It generates a peer instance that replicates the
  /// structural logic and key‑comparison strategies (such as the [identityMap]
  /// status resolved via [containerType]) of the original without sharing its
  /// internal lifecycle state, observer registry, or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent maps.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a map instance.
  ///
  /// ### Non‑obvious
  /// - The clone does **not** share the same `principal` – it is a root nucleus
  ///   (no parent). This means it does not inherit from the original.
  /// - Cloning is a zero‑copy operation for the logic – the logic is shared
  ///   via the flyweight record, but the state (lock, synapses) is new.
  ///
  /// ### Returns:
  /// A new [TissueMapNucleus<K, V>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueMapNucleus<K,V> get clone;

  /// Retrieves the physical storage strategy ([Container]) defining the
  /// uniqueness and allocation policy for the [TissueMap].
  ///
  /// This property identifies the specialised data structure or allocation
  /// policy—specifically distinguishing between a standard [Map] (equality‑based
  /// keys) or an [identityMap] (referential‑based keys)—that holds the
  /// actual key‑value pairs.
  ///
  /// ### When to use
  /// Read this to understand how keys are compared (value equality vs identity).
  /// This is useful for conditional logic or debugging.
  ///
  /// ### How it works
  /// - The value is resolved by walking up the principal chain if not defined
  ///   locally.
  /// - It defaults to [Container.map] if no container type is set.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed and cannot be changed
  ///   through a deputy. All deputies inherit the same container type.
  /// - The container type affects how keys are matched (e.g., `identityMap`
  ///   uses [identical]).
  @override
  Container get containerType;

}

/// A high‑performance, reactive [Map]‑like structure that implements [Tissue<V>],
/// enabling type‑safe, event‑driven management of key‑value pairs.
///
/// [TissueMap<K, V>] acts as the primary reactive bridge for associative data
/// within the `cell_tissue` ecosystem. It combines the familiar, imperative
/// interface of a Dart [Map] with the advanced **Conactive** capabilities of the
/// framework, such as granular change propagation, hierarchical property
/// inheritance, and security‑scoped proxies.
///
/// ### When to use
/// Use a [TissueMap] whenever you need an associative collection that:
/// - Must be observable (UI updates automatically on changes).
/// - Must enforce invariants (e.g., key constraints, value ranges).
/// - Must be shared between components with different permissions (via deputies).
/// - Must participate in the reactive graph as a first‑class cell.
/// - Requires stable key comparisons (identity‑based) for mutable keys.
///
/// Most of the time, you create a [TissueMap] using the [TissueMap] factory,
/// optionally providing a [testRule] for validation:
/// ```dart
/// final scores = TissueMap<String, int>();
/// final validated = TissueMap<String, int>(
///   testRule: TestTissue<int, TissueMap<String, int>>(
///     (v, {required host, action}) => v != null && v >= 0,
///   ),
/// );
/// ```
///
/// ### How it works
/// - Internally, it uses a [TissueMapNucleus] to govern behaviour and a
///   [Container] for physical storage.
/// - Every mutation (e.g., `[]=`, `remove`, `clear`) goes through a validation
///   pipeline ([testRule]) and emits a [TissueEvent].
/// - The map is thread‑safe via its internal [Lock].
/// - It can be **deputised** to create restricted views (read‑only, scoped
///   authority, etc.) that share the same storage.
/// - It supports both value‑based and identity‑based key comparisons.
/// - It automatically links child [Cell] values when they are added, enabling
///   "bubbling" of internal changes.
///
/// ### Non‑obvious
/// - Equality (`==`) is based on the underlying map's content and identity,
///   so `map1 == map2` works like a normal Dart map.
/// - The [async] getter returns a [ModifiableMapAsync] for `Future`‑based
///   operations, useful for network callbacks or background tasks.
/// - The `unmodifiable` getter is **not a snapshot** – it's a live view that
///   stays in sync with the source.
/// - The [modifiable] getter returns the list of functions that can be invoked
///   via `apply`. For read‑only deputies, this list is empty.
/// - The map treats its **values** as the primary "elements" for validation
///   and events. Keys are the structural indices.
///
/// ### Example: Basic usage
/// ```dart
/// final map = TissueMap<String, int>();
/// map['a'] = 1;
/// map['b'] = 2;
/// print(map.length); // 2
///
/// // Listen for changes using the Cell observation system
/// final observer = Cell.observe(
///   bind: map,
///   onPulse: (pulse, {user}) {
///     if (pulse is ElementAddedEvent<int>) {
///       print('Added: ${pulse.payload}');
///     }
///   },
/// );
///
/// map['c'] = 3; // prints "Added: 3"
/// ```
///
/// ### Example: Validation
/// ```dart
/// final validMap = TissueMap<String, int>(
///   testRule: TestTissue<int, TissueMap<String, int>>(
///     (v, {required host, action}) => v != null && v >= 0 && v <= 100,
///   ),
/// );
/// validMap['a'] = 50; // allowed
/// validMap['b'] = 150; // rejected by the Integrity Gate – no event emitted
/// ```
///
/// ### Example: Read-only deputy for UI
/// ```dart
/// final source = TissueMap<String, int>();
/// final uiView = source.unmodifiable;
///
/// // uiView can be safely passed to a widget tree
/// // Changes to source are reflected in uiView automatically
/// source['score'] = 100;
/// print(uiView['score']); // 100
/// // uiView['score'] = 200; // Throws or is rejected by the Integrity Gate
/// // Changes to source are reflected in uiView automatically
/// ```
///
/// ### Type Parameters:
/// * [K]: The type of keys used for association.
/// * [V]: The type of values stored in the collection.
///
/// See also:
/// - [Tissue] – the base interface for all reactive collections.
/// - [TissueMapNucleus] – the blueprint and configuration for the map.
/// - [UnmodifiableTissueMap] – a read‑only deputy variant.
abstract interface class TissueMap<K,V> implements Tissue<V> {

  @override
  TissueMapNucleus<K,V> get _nucleus;

  /// The primary architectural factory for instantiating a [TissueMap],
  /// materializing a reactive associative state node governed by the
  /// **Conactive Model**.
  ///
  /// This factory serves as the standard entry point for creating a
  /// synchronised map that participates in the framework's high‑fidelity
  /// data‑flow graph. It orchestrates the relationship between the logical
  /// governance layer (the [TissueMapNucleus]) and the physical storage
  /// layer ([Container.map]), ensuring that every mutation is atomic,
  /// validated, and observable.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive map with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [TissueMap.create] or [TissueMap.fromNucleus].
  ///
  /// ### How it works
  /// - You provide an optional [nucleus] (or let the framework create a default).
  /// - Optionally, you can supply initial [entries].
  /// - The map is created and automatically linked to any child cells.
  ///
  /// ### Parameters
  /// - [nucleus]: Optional pre‑configured blueprint.
  /// - [entries]: Optional initial key‑value pairs.
  ///
  /// ### Returns
  /// A concrete [TissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final map = TissueMap<String, int>();
  /// map['a'] = 1;
  /// ```
  factory TissueMap({TissueMapNucleus<K,V>? properties, Iterable<MapEntry<K, V>>? entries})
  = _TissueMap<K,V,TissueMap<K,V>>;

  /// Factory constructor to create a new, pre‑populated [TissueMap] from an
  /// existing Dart [Map].
  ///
  /// This constructor is a high‑level utility for materialising a reactive,
  /// associative collection that begins its lifecycle with a cloned population
  /// of data. It ensures that the transition from a standard, non‑reactive Dart
  /// [Map] to a synchronised **Conactive** node is performed atomically and
  /// securely.
  ///
  /// ### When to use
  /// Use this when you already have a Dart [Map] and want to turn it into a
  /// reactive map in one step.
  ///
  /// ### How it works
  /// - It creates a nucleus (with the provided parameters) and then ingests
  ///   the [map] entries atomically under a lock.
  /// - Any values that are [Cell]s are automatically linked to the map.
  ///
  /// ### Parameters
  /// - [map]: The source data.
  /// - [nucleus]: Optional blueprint.
  ///
  /// ### Example
  /// ```dart
  /// final map = TissueMap.from({'a': 1, 'b': 2}, nucleus: ...);
  /// ```
  factory TissueMap.from(Map<K,V> map, {TissueMapNucleus<K,V>? properties})
  = _TissueMap<K,V,TissueMap<K,V>>.from;

  /// Factory constructor to create a new, pre‑populated [TissueMap] from an
  /// [Iterable] of [MapEntry] objects.
  ///
  /// This constructor is a high‑level utility for materialising a reactive,
  /// associative collection from a stream or list of key‑value pairs. It ensures
  /// that the transition from a standard Dart [Iterable] to a synchronised
  /// **Conactive** node is performed with **Atomic Population** and
  /// **Structural Validation**.
  ///
  /// ### When to use
  /// Use this when you have an iterable of entries and want to create a map
  /// in one step.
  ///
  /// ### How it works
  /// - It ingests the [entries] atomically, validating each against the
  ///   [testRule] in the nucleus.
  /// - Any values that are [Cell]s are linked.
  ///
  /// ### Parameters
  /// - [entries]: The source entries.
  /// - [nucleus]: Optional blueprint.
  ///
  /// ### Example
  /// ```dart
  /// final entries = [MapEntry('a', 1), MapEntry('b', 2)];
  /// final map = TissueMap.fromEntries(entries);
  /// ```
  factory TissueMap.fromEntries(Iterable<MapEntry<K, V>> entries, {TissueMapNucleus<K,V>? properties})
  = _TissueMap<K,V,TissueMap<K,V>>.fromEntries;

  /// Architectural factory for instantiating a [TissueMap] that utilises
  /// **Referential Identity** ([identical]) for key lookups and uniqueness.
  ///
  /// This constructor is a specialised entry point for creating a reactive map
  /// where the "Identity" of a key is distinct from its "Value." It ensures
  /// that even if two keys have the exact same field values (equal via `==`),
  /// they are treated as distinct entries if they are different instances
  /// in memory.
  ///
  /// ### When to use
  /// Use this when you need to track keys by identity rather than value. This is
  /// essential when keys are mutable objects (like [Cell]s) whose internal
  /// state might change, which would break a value‑based map.
  ///
  /// ### How it works
  /// - It creates a nucleus with `identityMap: true`.
  /// - The underlying storage uses [LinkedHashMap.identity].
  /// - All key lookups and uniqueness checks use [identical].
  ///
  /// ### Example
  /// ```dart
  /// final map = TissueMap.identity<MyKey, int>();
  /// final key = MyKey('id');
  /// map[key] = 42;
  /// print(map[key]); // 42
  /// ```
  factory TissueMap.identity({Iterable<MapEntry<K, V>>? entries})
  = _TissueMap<K,V,TissueMap<K,V>>.identity;

  /// Primary architectural factory for materialising a [TissueMap] from an
  /// existing [TissueMapNucleus] (the "Reactive DNA").
  ///
  /// This constructor is the preferred entry point for the **Blueprint‑First
  /// Initialisation** pattern. It decouples the definition of the map's
  /// governance—including its key‑uniqueness strategy, security rules, and
  /// command processing—from the instantiation of the reactive node itself.
  ///
  /// ### When to use
  /// - You have a reusable nucleus (e.g., a "Registry" blueprint).
  /// - You are building a custom map implementation that needs a specific
  ///   nucleus configuration.
  /// - You are restoring a map from a serialised state where the nucleus is
  ///   already constructed.
  ///
  /// ### How it works
  /// - The map adopts the nucleus's rules, context, and receptor.
  /// - If [entries] are provided, they are ingested atomically and validated
  ///   against the nucleus's [testRule].
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueMapNucleus.create<String, int>(
  ///   testRule: TestTissue<int>((v) => v > 0),
  ///   identityMap: true,
  /// );
  /// final map = TissueMap.fromNucleus(nucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The blueprint to use.
  /// - [entries]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [TissueMap<K, V>] instance.
  factory TissueMap.fromNucleus(TissueMapNucleus<K,V> properties, {Iterable<MapEntry<K, V>>? entries})
  = _TissueMap<K,V,TissueMap<K,V>>.fromNucleus;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueMap].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `map.unmodifiable` instead.
  ///
  /// ### When to use
  /// Use this when you need to share a map with code that should only read
  /// data, never write it. For example, passing a map to a UI widget.
  ///
  /// ### How it works
  /// - It creates a read‑only deputy that shares the same storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` and optionally projects child cells.
  /// - The view is live and stays in sync with the source.
  ///
  /// ### Parameters
  /// - [bind]: The source map to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [TissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueMap<String, int>();
  /// final readOnly = TissueMap.unmodifiable(source);
  /// // readOnly['a'] = 1; // blocked
  /// source['a'] = 1; // readOnly reflects the change
  /// ```
  factory TissueMap.unmodifiable(TissueMap<K,V> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueMap<K,V,TissueMap<K,V>>.view;

  /// A high‑level architectural factory for creating a specialised, type‑safe
  /// reactive map with explicit control over its behavioural and structural blueprint.
  ///
  /// This static method serves as the primary entry point for constructing
  /// [TissueMap] instances that require deep customisation. It streamlines
  /// the process by simultaneously defining the map's configuration (its "DNA")
  /// and initialising the reactive node within the data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simple [TissueMap] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]).
  /// - Provide a custom [receptor] or [testRule] with full type safety.
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueMapNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the map from that nucleus, optionally ingesting
  ///   [entries].
  /// - The [principal] parameter allows you to inherit configuration from an
  ///   existing nucleus, enabling the deputy pattern at the nucleus level.
  ///
  /// ### Parameters
  /// - [entries]: Optional initial data.
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
  /// A concrete [TissueMapBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final map = TissueMap.create<String, int, TissueMap<String, int>>(
  ///   container: Container.identityMap,
  ///   entries: [MapEntry('a', 1)],
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// ```
  static TissueMapBase<K,V,C> create<K,V,C extends TissueMap<K,V>>({
    Iterable<MapEntry<K,V>>? entries,

    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueMapNucleusBase<K,V,C>? principal
  }) {
    final properties = TissueMapNucleus.create<K,V,C>(
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
    return _TissueMap<K,V,C>.fromNucleus(properties, entries: entries);
  }

  /// Creates a delegated view (deputy) of this map with specialised behavioural
  /// and validation logic.
  ///
  /// The [deputy] method is a fundamental implementation of the **Deputy Pattern**
  /// within the associative reactive ecosystem. It allows for the instantiation
  /// of a derived [TissueMap] that remains physically anchored to the same
  /// underlying storage as the original (principal) map, but operates under a
  /// distinct layer of governance, validation rules, and execution context.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the map:
  /// - Read‑only view: `map.deputy(testRule: TestTissue.readOnly)`
  /// - Scoped authority: `map.deputy(context: DeputyContext.delegate(...))`
  /// - Temporary access: `map.deputy(ephemeralPolicy: ...)`
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
  /// final source = TissueMap<String, int>();
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly['a'] = 1; // blocked
  /// source['a'] = 1; // readOnly reflects the change
  /// ```
  @override
  FutureOr<TissueMap<K,V>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  // Map interfaces

  /// Returns the value associated with the given [key].
  /// If the key is not found, returns `null`.
  V? operator [](Object? key);

  /// Returns `true` if the map contains the given [key].
  bool containsKey(Object? key);

  /// Returns `true` if the map contains the given [value].
  bool containsValue(Object? value);

  /// Returns an iterable of all entries in the map.
  Iterable<MapEntry<K, V>> get entries;

  /// Returns an iterable of all keys in the map.
  Iterable<K> get keys;

  /// Returns an iterable of all values in the map.
  Iterable<V> get values;

  /// Associates the [key] with the given [value].
  ///
  /// If the key was already in the map, its associated value is changed.
  /// Otherwise the key‑value pair is added to the map.
  ///
  /// This operation is equivalent to calling `add(key, value)`.
  void operator []=(K key, V value) => add(key, value);

  /// Add a new entry to this map [Tissue].
  ///
  /// - [key]: The key of the entry to add.
  /// - [value]: The value of the entry to add.
  ///
  /// Returns `true` if the entry was added, `false` if the entry already exists.
  bool add(K key, covariant V value);

  /// Adds all entries from the given [other] map to this map.
  void addAll(covariant Map<K, V> other);

  /// Adds all entries from the given [newEntries] iterable to this map.
  void addEntries(covariant Iterable<MapEntry<K, V>> newEntries);

  /// Removes [key] and its associated value from this map.
  ///
  /// Returns the removed value if the key was found, `null` otherwise.
  V? remove(covariant Object? key);

  /// Removes all entries from this map that satisfy the given [predicate].
  void removeWhere(bool Function(K key, V value) predicate);

  /// Look up the value of [key], or add a new entry if it isn't there.
  ///
  /// Returns the value associated to key, if there is one. Otherwise calls
  /// [ifAbsent] to get a new value, associates [key] to that value, and then
  /// returns the new value.
  V putIfAbsent(K key, covariant V Function() ifAbsent);

  /// Updates the value associated with [key] using the given [update] function.
  ///
  /// Returns the updated value.
  V update(K key, covariant V Function(V value) update, {covariant V Function()? ifAbsent});

  /// Updates all entries in this map with the given [update] function.
  void updateAll(covariant V Function(K key, V value) update);

  /// Removes all entries from this map.
  void clear();

  /// Returns a read‑only, reactive projection (Deputy) of this [TissueMap].
  ///
  /// This getter provides a safe, immutable interface to the map's entries
  /// while maintaining a live, synchronised connection to the underlying
  /// source of truth.
  ///
  /// ### When to use
  /// Use this when you need to share the map with components that should
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
  /// A read‑only [TissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueMap<String, int>();
  /// final readOnly = source.unmodifiable;
  /// // readOnly['a'] = 1; // blocked
  /// source['a'] = 1;
  /// print(readOnly['a']); // 1 (live update)
  /// ```
  @override
  TissueMap<K, V> get unmodifiable;

  /// Returns an asynchronous wrapper for non‑blocking operations.
  ///
  /// The [async] getter returns a [ModifiableMapAsync] object. This allows
  /// you to perform map operations (like `add` or `remove`) and `await`
  /// their completion, which includes the propagation of reactive signals.
  ///
  /// ### When to use
  /// - You are in an `async` context (e.g., a network callback) and need to
  ///   wait for the mutation to be fully processed.
  /// - You want to avoid blocking the UI thread during a batch of updates.
  ///
  /// ### Example
  /// ```dart
  /// final map = TissueMap<String, int>();
  /// await map.async.add('a', 42);
  /// ```
  @override
  ModifiableMapAsync<K,V> get async;

}

/// A specialised, reactive projection of a [TissueMap] that enforces a
/// strict read‑only contract while maintaining full synchronicity with its
/// underlying source.
///
/// [UnmodifiableTissueMap] is the primary implementation of the
/// **Deputy Pattern** for associative collections. It serves as a
/// security‑scoped "Lens" into a map's data, allowing observers to track
/// changes without possessing the authority to evolve the state.
///
/// ### When to use
/// Use an unmodifiable map when you need to share a map with a component
/// that should **observe** changes but **never** initiate them. Common
/// scenarios include:
/// - Passing a map to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You never implement this interface directly. You obtain an instance by
/// calling the `.unmodifiable` getter on a [TissueMap]:
/// ```dart
/// final source = TissueMap<String, int>();
/// final readOnly = source.unmodifiable; // UnmodifiableTissueMap<String, int>
/// ```
///
/// ### How it works
/// - **Zero‑copy sharing**: The unmodifiable view uses the **same physical
///   storage** and **same lock** as the mutable source. No data is duplicated.
/// - **Mutation barrier**: The `modifiable` getter returns an empty set, and
///   the internal `TestTissue` policy is set to `readOnly`. Any attempt to
///   call `[]=`, `add`, `remove`, `clear`, or `apply` with a mutation function
///   throws an [UnsupportedError] or is silently rejected.
/// - **Live reactivity**: Because it shares the same storage, changes made
///   to the source are **immediately** and **atomically** reflected in the
///   view. Observers attached to the view still receive pulses.
/// - **Deep immutability**: If `unmodifiableElement` is `true` (the default),
///   any value that is itself a [Cell] is automatically projected as its
///   `.unmodifiable` deputy when accessed. This prevents "side‑door"
///   mutations.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: Unlike `Map.unmodifiable` in Dart, this view
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
/// final source = TissueMap<String, int>({'a': 1});
/// final readOnly = source.unmodifiable;
/// // Render in a widget
/// myWidget(data: readOnly);
/// // Later, source['b'] = 2;
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Type Parameters:
/// * [K]: The type of keys in the map.
/// * [V]: The type of values in the map.
///
/// See also:
/// - [TissueMap] – the mutable counterpart.
/// - [UnmodifiableTissue] – the general contract for read‑only tissues.
abstract interface class UnmodifiableTissueMap<K,V> implements TissueMap<K,V>, Unmodifiable {

  /// The primary architectural factory for instantiating an [UnmodifiableTissueMap],
  /// materializing a read‑only, reactive associative node from an initial
  /// collection of [entries].
  ///
  /// This factory is a fundamental component of the framework's **Security Scoping**
  /// and **Deep Immutability** architecture. It is designed to initialise a map
  /// node that conceptually represents a **Fixed Registry** or **Configuration
  /// Snapshot** that remains reactive—meaning it can be observed and
  /// synchronised across the graph—but strictly prohibits structural modification.
  ///
  /// ### When to use
  /// Use this when you need a standalone immutable map that is not derived
  /// from a mutable source – e.g., for configuration data or constants.
  ///
  /// ### How it works
  /// - The factory creates a new map node with a read‑only nucleus.
  /// - The provided [entries] are stored in a physical container that is
  ///   never modified.
  /// - If [unmodifiableElement] is `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - The map is fully reactive but blocks all mutations.
  ///
  /// ### Parameters:
  /// - [entries]: The immutable key‑value data set.
  /// - [nucleus]: Optional blueprint; if omitted, a standard read‑only nucleus
  ///   is used.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final config = UnmodifiableTissueMap<String, String>(
  ///   [MapEntry('theme', 'dark')],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  factory UnmodifiableTissueMap(Iterable<MapEntry<K,V>> entries, {
    TissueMapNucleus<K,V>? properties,
    bool unmodifiableElement,
  }) = _UnmodifiableTissueMap<K,V,TissueMap<K,V>>;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueMap].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `map.unmodifiable` instead.
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
  /// - [bind]: The source map to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [UnmodifiableTissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueMap<String, int>();
  /// final readOnly = UnmodifiableTissueMap.view(source);
  /// ```
  factory UnmodifiableTissueMap.view(TissueMap<K,V> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueMap<K,V,TissueMap<K,V>>.view;

  /// A low‑level architectural factory for materializing an
  /// [UnmodifiableTissueMap] directly from a pre‑constructed
  /// reactive blueprint ([nucleus]).
  ///
  /// This constructor is the primary **Materialization Hook** used when the
  /// behavioural identity—including security rules, execution context, and
  /// synchronisation domain—has already been synthesised (e.g., via
  /// [TissueMapNucleus.evolve] or a custom [Deputy] derivation).
  ///
  /// ### When to use
  /// Use this when you already have a pre‑configured read‑only nucleus and want
  /// to instantiate a map from it. Typically used in advanced customisation
  /// or serialisation scenarios.
  ///
  /// ### How it works
  /// - The map adopts the nucleus's rules, context, and receptor.
  /// - If [entries] are provided, they are ingested atomically.
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters:
  /// - [nucleus]: The pre‑configured read‑only blueprint.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [entries]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [UnmodifiableTissueMap<K, V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyNucleus = TissueMapNucleus.evolve(
  ///   principal: myNucleus,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyMap = UnmodifiableTissueMap.fromNucleus(readOnlyNucleus);
  /// ```
  factory UnmodifiableTissueMap.fromNucleus(TissueMapNucleus<K,V> properties, {bool unmodifiableElement, Iterable<MapEntry<K,V>> entries})
  = _UnmodifiableTissueMap<K,V,TissueMap<K,V>>.fromNucleus;

  /// An advanced architectural factory for creating a specialised, type‑safe
  /// [UnmodifiableTissueMap] with granular control over its behavioural
  /// and structural identity.
  ///
  /// This static method serves as the primary entry point for constructing
  /// read‑only reactive maps that require deep customisation of their
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
  /// - It builds a nucleus using [TissueMapNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the unmodifiable map from that nucleus, optionally
  ///   ingesting [entries].
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters
  /// - [entries]: Optional initial data.
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
  /// A concrete [UnmodifiableTissueMapBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyMap = UnmodifiableTissueMap.create<String, int, TissueMap<String, int>>(
  ///   container: Container.identityMap,
  ///   entries: [MapEntry('a', 1)],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  static UnmodifiableTissueMapBase<K,V,C> create<K,V,C extends TissueMap<K,V>>({
    Iterable<MapEntry<K,V>>? entries,
    bool unmodifiableElement = true,

    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueMapNucleusBase<K,V,C>? principal,
  }) {
    return _UnmodifiableTissueMap<K,V,C>.fromNucleus(
        TissueMapNucleus.create<K,V,C>(
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
        entries: entries
    );
  }

}