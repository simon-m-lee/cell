// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Internal implementation of [TissueMapNucleus] for reactive maps.
///
/// [_TissueMapNucleus] is the concrete nucleus that powers `_TissueMap`.
/// It extends [TissueMapNucleusBase] and provides the specific logic for
/// cloning and evolution.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueMapNucleus] instead.
///
/// ### How it works
/// - It extends [TissueMapNucleusBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own lock and synapses.
/// - The `evolve` constructor creates a deputy nucleus with overridden properties.
///
/// ### Type Parameters:
/// * [K]: The type of keys in the map.
/// * [V]: The type of values in the map.
/// * [C]: The concrete tissue map type.
class _TissueMapNucleus<K,V,C extends TissueMap<K,V>> extends TissueMapNucleusBase<K,V,C> {

  _TissueMapNucleus({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.identityMap,
    super.forceLock,
    super.user
  }) : super();

  _TissueMapNucleus.evolve({

    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    bool identityMap = false,
    bool forceLock = true,

    TissueMapNucleus<K,V>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueMapNucleus<K,V,C>.fromRecord(
          TissueNucleusBase.local<V, TissueMap<K,V>, C>(
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock
          ))
  );

  _TissueMapNucleus.fromRecord(super.record) : super.fromRecord();

  /// Creates an independent, decoupled clone of this nucleus.
  ///
  /// ### When to use
  /// This is used internally when creating a new map from a template nucleus.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a map instance.
  ///
  /// ### Returns:
  /// A new [TissueMapNucleusBase] instance with identical behavioural logic.
  @override
  TissueMapNucleusBase<K,V,C> get clone {
    return TissueMapNucleus.create<K,V,C>(
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

/// The foundational blueprint that defines the behaviour and constraints of a
/// reactive [TissueMap].
///
/// [TissueMapNucleusBase] holds the immutable configuration – the receptor,
/// validation rule, context, synapses, and the identityMap flag – that governs
/// how a map reacts to mutations. It is the **DNA** of every reactive map.
///
/// ### When to use
/// Only if you are building a custom map type that needs to override the
/// default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// You never extend this class directly. The framework provides concrete
/// implementations via [TissueMapNucleus.create] and the [TissueMap] factories.
/// This class is the base that powers the internal `_TissueMapNucleus`.
///
/// ### How it works
/// - It extends [TissueNucleusBase] to inherit the generic tissue
///   configuration engine (receptor, testRule, context, synapses).
/// - It specialises the storage type to [Map<K, V>] and forces the container
///   strategy to either [Container.map] (value‑based key equality) or
///   [Container.identityMap] (referential identity) based on the `identityMap` flag.
/// - It implements the [containerType] resolution by walking up the
///   `principal` chain, defaulting to [Container.map].
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   map instances from a template.
///
/// ### Non‑obvious
/// - The `identityMap` flag is **structural** – it is fixed at creation and
///   cannot be changed via a deputy. All deputies of a map share the
///   same key‑comparison strategy.
/// - The nucleus is a **flyweight** – many maps can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent map instances.
/// - In the collection hierarchy, the **value type [V]** is treated as the
///   primary "element" type for signals and validation, while the key [K]
///   serves as the structural index.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueMapNucleus.create<String, int>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   identityMap: false,
/// );
/// final map1 = TissueMap.fromNucleus(validNucleus);
/// final map2 = TissueMap.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// - [K]: The type of keys used in the map.
/// - [V]: The type of values associated with the keys.
/// - [C]: The specific [TissueMap] implementation type (usually `TissueMap<K, V>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueMapNucleusBase<K, V, C extends TissueMap<K,V>>
    extends TissueNucleusBase<V, TissueMap<K,V>, C>
    implements TissueMapNucleus<K, V> {

  /// **Primary Constructor** – defines the immutable behaviour and storage
  /// strategy for a reactive map.
  ///
  /// ### When to use
  /// This constructor is `public` only so that concrete subclasses can invoke
  /// it via `super()`. **Application code should never call this directly.**
  ///
  /// If you need a nucleus, use [TissueMapNucleus.create] to create one
  /// from scratch, or [TissueMapNucleus.evolve] to derive one from an
  /// existing principal.
  ///
  /// You are writing a custom map implementation that extends
  /// `TissueMapNucleusBase` and need to pass configuration up to the base.
  ///
  /// ### How it works
  /// 1. The [identityMap] flag determines the physical container:
  ///    - `true` → [Container.identityMap] – keys are compared using
  ///      [identical] (referential equality).
  ///    - `false` → [Container.map] – keys use standard `==` and `hashCode`.
  /// 2. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 3. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The `identityMap` flag is **structural** – once set, it cannot be
  ///   changed by a deputy. If you need both identity‑based and value‑based
  ///   views of the same data, you must create two separate nuclei (or use
  ///   a deputy with a different container type, which is not allowed –
  ///   deputies inherit the container type).
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new map. If you pass [Synapses.disabled], the map
  ///   will be terminal (no broadcasts).
  ///
  /// ### Example (Internal – how the framework uses it)
  /// ```dart
  /// class _MyCustomMapNucleus<K, V> extends TissueMapNucleusBase<K, V, TissueMap<K, V>> {
  ///   _MyCustomMapNucleus({super.identityMap = false, super.testRule, ...}) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] – the map will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [identityMap]: `true` for identity‑based key comparison, `false` for
  ///   value‑based (default).
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  TissueMapNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool identityMap = false,
    super.forceLock,
    super.user
  }) : super(container: identityMap ? Container.identityMap : Container.map);

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
  /// - The record must contain all necessary fields for a [Map] nucleus,
  ///   including the `container` (of type [Container<Map<K, V>>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (mask: (container: Container.map, ...), principal: null);
  /// final nucleus = TissueMapNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueMapNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// ### When to use
  /// This constructor is part of the **internal deputy machinery**. While it
  /// is `public`, it is intended to be called only by the framework when
  /// you invoke `deputy()` on a [TissueMap]. **Application code should use
  /// `TissueMap.deputy()` or [TissueMapNucleus.evolve] instead.**
  ///
  /// You are building a custom deputy implementation and need to control
  /// exactly how a child nucleus inherits from its principal.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and identityMap flag).
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
  /// - The `identityMap` flag is **always inherited** from the principal.
  ///   You cannot change a value‑based map into an identity‑based one, or
  ///   vice versa, through a deputy.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final principal = TissueMapNucleus.create<String, int>(identityMap: false);
  /// final readOnlyNucleus = TissueMapNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyMap = TissueMap.fromNucleus(readOnlyNucleus);
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
  TissueMapNucleusBase.evolve({
    super.override,
    required TissueMapNucleus<K,V> super.principal
  }) : super.evolve();

  /// Retrieves the hierarchical principal configuration of this map's properties.
  ///
  /// This getter is a specialized, type‑safe override of the core [Nucleus.principal]
  /// link. It facilitates the "Property Cascading" mechanism that allows
  /// [TissueMap] instances to participate in an inheritance‑based
  /// configuration model.
  ///
  /// ### When to use
  /// Only if you are building a custom map implementation and need to
  /// traverse the inheritance chain to resolve a property value. For most
  /// application code, you never call this – the framework handles it for you.
  ///
  /// You rarely need to read this directly. The framework uses it internally
  /// when you create a deputy via `deputy()`. It's what makes a deputy "share"
  /// the same logic and storage as its principal.
  ///
  /// ### How it works
  /// - When you call `deputy()` on a map, the new nucleus's `principal` is
  ///   set to the original map's nucleus.
  /// - When a property (like `testRule` or `receptor`) is accessed on the
  ///   deputy, the framework first checks the deputy's local record. If not
  ///   found, it "walks up" to the `principal` and asks for the property there.
  /// - This chain continues until a root nucleus (with no `principal`) is reached.
  /// - This is the engine behind zero‑copy deputies: they reuse the principal's
  ///   logic and storage without duplicating anything.
  ///
  /// ### Non‑obvious
  /// - The type is overridden to `TissueMapNucleusBase<K, V, C>?` instead of the
  ///   generic `Nucleus?`. This is a covariant override that ensures you get a
  ///   properly typed principal when you need to access map‑specific methods
  ///   (like `containerType` or `identityMap`).
  /// - The chain ends when this getter returns `null` – that's the "root" nucleus.
  /// - Even though the getter is `public`, it's intended for internal framework
  ///   use. Mutating or replacing the principal after construction is not
  ///   supported – the nucleus is immutable.
  /// - The principal chain determines the `containerType` (identityMap) and
  ///   all other structural properties; deputies cannot change the key‑comparison
  ///   strategy.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final map = TissueMap<String, int>();
  /// final deputy = map.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to map._nucleus
  /// // So when deputy needs the identityMap flag, it delegates to map._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueMapNucleusBase<K,V,C>? get principal => super.principal as TissueMapNucleusBase<K,V,C>?;

  /// The physical storage strategy (value‑based or identity‑based) used by this map.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines how keys are compared for uniqueness.
  ///
  /// ### When to use
  /// Read this to understand whether the map uses value equality (`==`) or
  /// referential identity (`identical`) for key lookup.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at creation and
  ///   inherited by all deputies. A deputy cannot change a value‑based map
  ///   into an identity‑based one.
  /// - Defaults to [Container.map] if not set.
  @override
  Container get containerType {
    return get<Container>(() => record.mask.inhertiable.container, fallback: () => principal?.containerType, orElse: Container.map);
  }

}

/// A concrete implementation of a mutable [TissueMap].
///
/// [_TissueMap] is the primary workhorse implementation of the [TissueMap]
/// interface. It provides the full reactive, observable, and thread‑safe
/// map capabilities.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// public factory methods on [TissueMap].
///
/// ### How it works
/// - It extends [TissueMapBase] and provides the mutable implementation.
/// - It holds a [TissueMapNucleus] that defines the map's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
///
/// ### Type Parameters:
/// * [K]: The type of keys in the map.
/// * [V]: The type of values in the map.
/// * [C]: The concrete tissue map type.
class _TissueMap<K,V,C extends TissueMap<K,V>> extends TissueMapBase<K,V,C> {

  _TissueMap({TissueMapNucleus<K,V>? properties, Iterable<MapEntry<K,V>>? entries})
      : this.fromNucleus(properties ?? _TissueMapNucleus<K,V,C>(), entries: entries);

  _TissueMap.from(super.map, {TissueMapNucleus<K,V>? properties})
      : super.from(properties: (properties ?? _TissueMapNucleus<K,V,C>()) as TissueMapNucleusBase<K,V,C>);

  _TissueMap.fromEntries(Iterable<MapEntry<K, V>> entries, {TissueMapNucleus<K,V>? properties})
      : this.fromNucleus(properties ?? _TissueMapNucleus<K,V,C>(), entries: entries);

  _TissueMap.identity({Iterable<MapEntry<K, V>>? entries})
      : this.fromNucleus(_TissueMapNucleus<K,V,C>(identityMap: true), entries: entries);

  _TissueMap.fromNucleus(TissueMapNucleus<K,V> properties, {Iterable<MapEntry<K, V>>? entries})
      : super.fromNucleus(properties as TissueMapNucleusBase<K,V,C>) {
    if (entries != null) {
      _nucleus.container.init(Map<K,V>.fromEntries(entries));
      final values = _nucleus.container.store.values;
      for (var v in values) {
        if (v is Cell) {
          _nucleus.synapses.link(v, downstreamCell: this);
        }
      }
    } else {
      _nucleus.container.init();
    }
  }

  @override
  FutureOr<TissueMap<K,V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueMapDeputy<K,V,C>._(this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  late final TissueMap<K,V> unmodifiable = _UnmodifiableTissueMap<K,V,C>.view(this, unmodifiableElement: true);

}

/// The foundational reactive engine for all associative collections in the
/// `cell_tissue` ecosystem.
///
/// [TissueMapBase] provides the concrete integration between the reactive
/// [TissueBase] framework and the standard Dart [Map] API. It uses
/// [TissueMapMixin] (to implement the standard Map contract) and the
/// internal [TissueBase] to create a high‑performance, governed, and
/// observable key‑value store.
///
/// ### When to use
/// Only if you are extending the framework to build a custom map variant
/// that requires precise control over the mutation pipeline or storage
/// behaviour. For standard use cases, the existing [TissueMap] factories
/// are sufficient.
///
/// You never use this class directly. It is the base class for the internal
/// implementations that power both mutable maps (`_TissueMap`) and read‑only
/// views (`_UnmodifiableTissueMap`). Your interaction with maps is through
/// the factories on [TissueMap].
///
/// ### How it works
/// - It extends [TissueBase] to inherit the core reactive lifecycle,
///   synchronisation domain, and nucleus‑container architecture.
/// - It mixes in [TissueMapMixin], which provides the full [Map] API and
///   routes all mutations through the `apply` command gateway.
/// - Every structural change (adding, removing, clearing) is:
///   1. Validated against the [TestTissue] rules.
///   2. Applied atomically to the [Container].
///   3. Dispatched as a [TissueEvent] to all observers.
/// - The underlying storage is a Dart `Map<K, V>` with the key‑comparison
///   strategy defined by the nucleus's `identityMap` flag.
///
/// ### Non‑obvious
/// - **The `apply` Gateway**: All mutations are funnelled through `apply`.
///   This is a security boundary – deputies override `modifiable` to return
///   an empty set, rejecting any mutation attempt.
/// - **Value‑centric validation**: The [testRule] validates **values**,
///   not keys. Keys are the structural indices; values are the primary data.
/// - **Identity vs. Value**: The `identityMap` flag is fixed at creation.
///   A deputy cannot change the key‑comparison strategy.
///
/// ### Example (Internal Usage)
/// While you never instantiate this directly, understanding it helps you
/// reason about how `TissueMap` works:
/// ```dart
/// final nucleus = TissueMapNucleus.create<String, int>(identityMap: false);
/// final map = _TissueMap<String, int>(nucleus);
/// map['a'] = 1; // Routed through `apply` -> validation -> pulse emission
/// ```
///
/// ### Type Parameters:
/// - [K]: The type of keys in the map.
/// - [V]: The type of values in the map.
/// - [C]: The specific [Tissue] implementation type (usually `TissueMap<K, V>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueMapBase<K, V, C extends TissueMap<K,V>>
    extends TissueBase<V, TissueMap<K,V>,C>
    with TissueMapMixin<K,V,C>
    implements TissueMap<K, V> {

  @override
  TissueMapNucleusBase<K,V,C> get _nucleus => super._nucleus as TissueMapNucleusBase<K,V,C>;

  /// Constructs a [TissueMapBase] with the specified [properties] and optional
  /// initial [entries].
  ///
  /// ### Parameters:
  /// - [properties]: The configuration and state container for this map.
  /// - [entries]: Optional initial key‑value pairs. These are loaded atomically.
  TissueMapBase({TissueMapNucleusBase<K,V,C>? properties, Iterable<MapEntry<K, V>>? entries})
      : this.fromNucleus(properties ?? _TissueMapNucleus<K,V,C>(),
      entries: entries);

  /// Creates a [TissueMapBase] from an existing [Map], optionally with
  /// custom [properties].
  ///
  /// ### Parameters:
  /// - [map]: The source map data.
  /// - [properties]: Optional nucleus configuration.
  TissueMapBase.from(Map<K,V> map, {TissueMapNucleusBase<K,V,C>? properties})
      : super(properties ?? _TissueMapNucleus<K,V,C>()) {
    _nucleus.container.init(map);
    for (var v in values) {
      if (v is Cell) {
        _nucleus.synapses.link(v, downstreamCell: this);
      }
    }
  }

  /// Creates a [TissueMapBase] initialized with the given [entries] and
  /// optional [properties].
  TissueMapBase.fromEntries(Iterable<MapEntry<K, V>> entries,
      {TissueMapNucleusBase<K,V,C>? properties})
      : this.fromNucleus(properties ??_TissueMapNucleus<K,V,C>(),
      entries: entries);

  /// Creates a [TissueMapBase] that uses identity comparison for its keys.
  ///
  /// Equivalent to `TissueMap.identity` but for the base class.
  TissueMapBase.identity({Iterable<MapEntry<K, V>>? entries})
      : this.fromNucleus(_TissueMapNucleus<K,V,C>(identityMap: true),
      entries: entries);

  /// Primary constructor that initialises the map from a [TissueMapNucleusBase].
  ///
  /// This is the internal entry point for all map instantiations. It sets up
  /// the physical container and links any child cells.
  ///
  /// If [entries] are provided, they are loaded into the underlying container,
  /// and any values that are [Cell] instances are automatically linked to
  /// this tissue's synapses.
  ///
  /// ### Parameters:
  /// - [properties]: The nucleus defining the map's behaviour and storage.
  /// - [entries]: Optional initial key‑value pairs.
  TissueMapBase.fromNucleus(TissueMapNucleusBase<K,V,C> super.properties,
      {Iterable<MapEntry<K, V>>? entries})
      : super() {
    if (entries != null) {
      _nucleus.container.init(Map<K, V>.fromEntries(entries));
      final values = _nucleus.container.store.values;
      for (var v in values) {
        if (v is Cell) {
          _nucleus.synapses.link(v, downstreamCell: this);
        }
      }
    }
  }

// ---- MapMixin mandatory overrides ----

  /// Associates the [key] with the [value] by applying the [add] operation.
  ///
  /// This is the standard index assignment operator. It is routed through
  /// the reactive pipeline: validation, atomic update, and event emission.
  ///
  /// ### Parameters:
  /// - [key]: The key to associate.
  /// - [value]: The value to store.
  @override
  void operator []=(K key, V value) => apply(add, positionalArguments: [key, value]).isNotEmpty;

  /// Looks up the value for [key] directly from the underlying storage.
  ///
  /// This is a synchronous, non‑triggering read. It bypasses the reactive
  /// pipeline for performance.
  ///
  /// ### Parameters:
  /// - [key]: The key to look up.
  /// - Returns: The associated value, or `null` if not found.
  @override
  V? operator [](Object? key) => _nucleus.container.store[key];

  // ---- Map modifiable methods (all routed through `apply`) ----

  /// Adds a new entry with the given [key] and [value].
  ///
  /// Returns `true` if the entry was added (i.e., the key was not already
  /// present and validation passed), `false` otherwise.
  @override
  bool add(K key, V value) => apply(add, positionalArguments: [key, value]).isNotEmpty;

  /// Adds all entries from the given [other] map.
  @override
  void addAll(Map<K, V> other) => apply(addAll, positionalArguments: [other]);

  /// Adds all entries from the given [newEntries] iterable.
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) =>
      apply(addEntries, positionalArguments: [newEntries]);

  /// Removes all entries from the map.
  @override
  void clear() => apply(clear);

  /// Looks up the value of [key], or adds a new entry if it isn't there.
  ///
  /// Returns the existing value if [key] is present; otherwise, calls
  /// [ifAbsent] to produce a new value, adds it, and returns that value.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) =>
      apply(putIfAbsent, positionalArguments: [key, ifAbsent]);

  /// Removes [key] and its associated value, returning the removed value,
  /// or `null` if the key was not present.
  @override
  V remove(Object? key) => apply(remove, positionalArguments: [key]);

  /// Removes all entries that satisfy the given [predicate].
  @override
  void removeWhere(bool Function(K key, V value) predicate) =>
      apply(removeWhere, positionalArguments: [predicate]);

  /// Updates the value associated with [key] using the [update] function.
  ///
  /// If [key] is not present, [ifAbsent] is called and its result is added.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      apply(update, positionalArguments: [key, update], namedArguments: {#ifAbsent: ifAbsent});

  /// Updates all values by applying the [update] function to each entry.
  @override
  void updateAll(V Function(K key, V value) update) =>
      apply(updateAll, positionalArguments: [update]);

  // ---- Deputy & Async ----

  @override
  FutureOr<TissueMap<K, V>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue<V, C> testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _TissueMapDeputy<K, V, C>._(
        this,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  /// Returns an asynchronous wrapper for non‑blocking operations.
  @override
  ModifiableMapAsync<K, V> get async => ModifiableMapAsync<K, V>._(this);

}

/// Internal deputy implementation for [TissueMap].
///
/// A deputy shares the same physical data as its principal but applies
/// different validation, context, or synapses. It is created via the
/// `deputy()` method on a [TissueMap].
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [TissueMap] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `TissueMapBase` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [K]: The type of keys in the map.
/// * [V]: The type of values in the map.
/// * [C]: The concrete tissue map type.
class _TissueMapDeputy<K,V,C extends TissueMap<K,V>> extends TissueMapBase<K,V,C> with Deputy<TissueMap<K,V>> {

  _TissueMapDeputy._(TissueMapBase<K,V,C> bind, {Context context = Context.system, TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueMapNucleus<K,V,C>.evolve(
      bind: bind,
      testRule: bind._nucleus.testRule + testRule,
      synapses: bind._nucleus.synapses != Synapses.disabled ? synapses : Synapses.disabled,
      principal: bind._nucleus as TissueMapNucleus<K,V>
  ));

  @override
  FutureOr<TissueMap<K,V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueMapDeputy<K,V,C>._(_nucleus.bind as TissueMapBase<K,V,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }
}

/// Internal implementation of an unmodifiable (read‑only) reactive map.
///
/// This is created when you call `.unmodifiable` on a [TissueMap]. It
/// shares the same physical storage and lock as the source, but blocks all
/// mutation attempts. It is a live view – changes to the source are
/// immediately reflected.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [TissueMap] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueMapBase] and provides the concrete
///   implementation.
/// - It shares the same physical storage and lock as the mutable source.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, child [Cell] values are projected
///   as read‑only deputies.
///
/// ### Type Parameters:
/// * [K]: The type of keys in the map.
/// * [V]: The type of values in the map.
/// * [C]: The concrete tissue map type.
class _UnmodifiableTissueMap<K,V,C extends TissueMap<K,V>> extends UnmodifiableTissueMapBase<K,V,C> {

  _UnmodifiableTissueMap(Iterable<MapEntry<K, V>> entries, {bool unmodifiableElement = true, TissueMapNucleus<K,V>? properties})
      : this.fromNucleus(
      (properties ?? TissueMapNucleus.create<K,V,C>()) as TissueMapNucleusBase<K,V,C>,
      unmodifiableElement: unmodifiableElement,
      entries: entries
  );

  _UnmodifiableTissueMap.view(TissueMap<K,V> bind, {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(TissueMapNucleus.create<K,V,C>(bind: bind,
      container: unmodifiableElement ? bind._nucleus.containerType : null,
      context: context,
      synapses: bind._nucleus.synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
      principal: bind._nucleus as TissueMapNucleusBase<K,V,C>
  ), unmodifiableElement: unmodifiableElement,
      entries: unmodifiableElement
          ? bind.entries.map((en) =>
          MapEntry<K, V>(en.key, en.value is Cell
              ? (en.value as Cell).unmodifiable as V
              : en.value))
          : null
  );

  _UnmodifiableTissueMap.fromNucleus(TissueMapNucleus<K,V> properties, {super.unmodifiableElement, Iterable<MapEntry<K, V>>? entries})
      : super(properties as TissueMapNucleusBase<K,V,C>) {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null) {
      if (entries != null) {
        _nucleus.container.store.addEntries(entries);
      }
    }
    if (entries != null) {
      final values = _nucleus.container.store.values;
      for (var v in values) {
        if (v is Cell) {
          _nucleus.synapses.link(v, downstreamCell: this);
        }
      }
    }
  }

  /// Creates an deputy for this unmodifiable list.
  ///
  /// Note: The deputy will still enforce unmodifiability of the underlying list.
  ///
  /// Parameters:
  ///   - testRule: Additional test rules
  ///   - map: Value mapping configuration
  @override
  FutureOr<TissueMap<K,V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueMapDeputy<K,V,C>._(this as TissueMapBase<K,V,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  TissueMap<K,V> get unmodifiable => this;

}

/// The foundational base class for all read‑only reactive map views.
///
/// [UnmodifiableTissueMapBase] is the abstract anchor for unmodifiable
/// map implementations (e.g., `_UnmodifiableTissueMap`). It ties together
/// a read‑only nucleus and a shared storage container, ensuring that all
/// mutations are blocked while reactivity remains live.
///
/// ### When to use
/// Only if you are building a custom read‑only map variant that needs
/// to override the default unmodifiable behaviour. For everyday use,
/// the existing `.unmodifiable` getter is all you need.
///
/// This class is **abstract** – you never instantiate it directly.
/// You obtain an unmodifiable map by calling `.unmodifiable` on any
/// mutable [TissueMap], or by using one of the dedicated factories
/// (`UnmodifiableTissueMap`, `UnmodifiableTissueMap.view`, etc.).
///
/// ### How it works
/// 1. The constructor receives a [TissueMapNucleusBase] that defines the
///    map's structural strategy (identityMap) and governance rules.
/// 2. The `unmodifiableElement` flag controls deep immutability:
///    - If `true`, any value that is a [Cell] is automatically projected
///      as its `.unmodifiable` deputy when accessed via this map.
///    - If `false`, child cells remain mutable (but the map itself is
///      still read‑only).
/// 3. The map shares the same physical storage as its mutable source
///    (when created via `.view`) – changes to the source are immediately
///    reflected in this read‑only view.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: The view is live. Changes to the mutable
///   source are instantly visible.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: If `unmodifiableElement` is `true`, the
///   iterator wraps each value that is a [Cell] in its `.unmodifiable`
///   deputy, preventing side‑door mutations.
/// - **Own observer registry**: The view has its own [Synapses] registry,
///   so observers attached to the view are independent of those on the
///   source.
///
/// ### Example (Internal)
/// ```dart
/// final source = TissueMap<String, int>();
/// source['a'] = 1;
/// final readOnly = _UnmodifiableTissueMap<String, int>.view(source);
/// // readOnly['b'] = 2; // throws UnsupportedError
/// source['b'] = 2; // readOnly now contains 'b' -> 2
/// ```
///
/// ### Type Parameters:
/// - [K]: The type of keys in the map.
/// - [V]: The type of values in the map.
/// - [C]: The specific [TissueMap] implementation type (usually `TissueMap<K, V>`).
abstract class UnmodifiableTissueMapBase<K,V,C extends TissueMap<K,V>>
    extends UnmodifiableTissueBase<V,TissueMap<K,V>,C>
    with TissueMapMixin<K,V,C>
    implements UnmodifiableTissueMap<K,V> {

  @override
  TissueMapNucleusBase<K, V, C> get _nucleus =>
      super._nucleus as TissueMapNucleusBase<K, V, C>;

  /// Initializes an unmodifiable map with the provided [properties] and optional [entries].
  ///
  /// If [entries] are provided, they are loaded into the underlying storage.
  /// Any values that are [Cell] instances are linked to this tissue's
  /// synapses to ensure reactivity is propagated from the elements.
  ///
  /// ### Parameters:
  /// - [properties]: The configuration for the reactive map.
  /// - [unmodifiableElement]: If true, elements retrieved from the map will
  ///   be returned as unmodifiable views (if they support it).
  /// - [entries]: Initial data to populate the map.
  UnmodifiableTissueMapBase(
      TissueMapNucleusBase<K,V,C> super.properties, {super.unmodifiableElement, Iterable<MapEntry<K,V>>? entries})
      : super() {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null) {
      _nucleus.container.init(entries);
    }
    if (unmodifiableElement) {
      final bind = get<Cell?>(() => _nucleus.record.mask.bind, orElse: null);
      if (bind != null && entries != null) {
        entries.map<V>((en) => en.value).whereType<Cell>()
            .forEach((e) => _nucleus.synapses.link(e, downstreamCell: this));
      }
    }

  }

  /// Returns an asynchronous wrapper for operations.
  ///
  /// Note: Since this is an unmodifiable map, the returned [ModifiableMapAsync]
  /// will still result in [UnsupportedError] for mutation attempts.
  @override
  ModifiableMapAsync<K, V> get async => _UnmodifiableModifiableMapAsync<K, V>();

  /// Retrieves the value associated with [key].
  @override
  V? operator [](Object? key) => _nucleus.container.store[key];

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void operator []=(K key, V value) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  bool add(K key, V value) => throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void clear() => throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  V? remove(Object? key) => throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void addAll(Map<K, V> other) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void removeWhere(bool Function(K key, V value) predicate) => throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) => throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void updateAll(V Function(K key, V value) update) => throw UnsupportedError('Unmodifiable operation');

}

/// A mixin that provides a standard [Map] interface implementation for
/// reactive maps.
///
/// [TissueMapMixin] implements all the read‑only methods of the Dart [Map]
/// interface by delegating to the underlying storage container. It also
/// defines the `modifiable` set of functions that can be invoked via `apply`.
///
/// ### When to use
/// Only if you are building a custom map implementation that needs to reuse
/// the standard Map logic.
///
/// This mixin is used internally by `TissueMapBase` and `UnmodifiableTissueMapBase`.
/// You don't interact with it directly – it provides the Map API for tissues.
///
/// ### How it works
/// - It requires the host class to provide `_nucleus` (a `TissueMapNucleusBase`)
///   and `validate` (a `TestTissue`).
/// - It implements all Map getters (`keys`, `values`, `entries`, `length`,
///   `isEmpty`, `isNotEmpty`, `containsKey`, `containsValue`) by delegating
///   to `_nucleus.container.store`.
/// - It defines the `modifiable` list, which includes `add`, `addAll`, `clear`,
///   `remove`, and `removeWhere`. These are the operations that are routed
///   through the `apply` gateway.
///
/// ### Non‑obvious
/// - The mixin does **not** implement mutation methods directly. Those are
///   provided by the host class (e.g., `TissueMapBase`) to ensure they go
///   through the reactive pipeline.
/// - The `operator []` and `containsKey` are read‑only and bypass the
///   reactive system – they are direct storage reads.
/// - The `modifiable` set is used by the `apply` method to determine which
///   functions are allowed to be invoked.
mixin TissueMapMixin<K,V,C extends TissueMap<K,V>> implements TissueMap<K,V> {

  @override
  TissueMapNucleusBase<K,V,C> get _nucleus;

  @override
  TestTissue<V,C> get validate => _nucleus.testRule;

  @override
  Iterable<Function> get modifiable => <Function>{
    add,
    addAll,
    clear,
    remove,
    removeWhere,
  };

  @override
  V? operator [](Object? key) => _nucleus.container.store[key];

  @override
  bool containsKey(Object? key) => _nucleus.container.store.containsKey(key);

  @override
  bool containsValue(Object? value) => _nucleus.container.store.containsValue(value);

  @override
  Iterable<MapEntry<K, V>> get entries => _nucleus.container.store.entries;

  @override
  bool get isEmpty => _nucleus.container.store.isEmpty;

  @override
  bool get isNotEmpty => _nucleus.container.store.isNotEmpty;

  @override
  Iterable<K> get keys => _nucleus.container.store.keys;

  @override
  int get length => _nucleus.container.store.length;

  @override
  Iterable<V> get values => _nucleus.container.store.values;

}

/// An asynchronous facade for performing reactive mutation operations on a [TissueMap].
///
/// `ModifiableMapAsync` provides a [Future]‑based API that mirrors the standard
/// mutation methods of a [TissueMap]. This class is essential for scenarios
/// where map modifications need to be offloaded to the event loop or handled
/// within an `async/await` workflow.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side‑effects.
///
/// You never construct this directly. It is returned by the `async` getter
/// on any [TissueMap] (e.g., `myMap.async`). Use it when you need to
/// perform asynchronous mutations.
///
/// ### How it works
/// - It wraps the synchronous mutation methods (like `add`, `clear`, etc.)
///   in a `Future`.
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
///
/// ### Example
/// ```dart
/// final map = TissueMap<String, int>();
/// await map.async.add('a', 42);
/// print('Entry added and all observers notified.');
/// ```
///
/// ### Type Parameters:
/// - [K]: The type of keys in the map.
/// - [V]: The type of values in the map.
class ModifiableMapAsync<K,V> extends TissueModifiableAsync<V,TissueMap<K,V>> {

  /// Creates an asynchronous callable wrapper for a [TissueMap].
  ///
  /// This constructor is typically not called directly. Instead, instances are
  /// accessed via the [TissueMap.async] getter.
  ///
  /// ### Parameters:
  ///   - `tissue`: The [TissueMap<K, V>] whose operations will be wrapped.
  const ModifiableMapAsync._(super.tissue);

  /// Asynchronously adds a new entry ([key], [value]) to the map.
  ///
  /// ### Parameters:
  ///   - [key]: The key to add.
  ///   - [value]: The value to associate with the key.
  ///
  /// ### Returns:
  ///   A [Future<bool>] that completes with `true` if the entry was
  ///   successfully added (i.e., the key was not already present and validation
  ///   passed), and `false` otherwise.
  Future<bool> add(K key, V value) {
    return Future<bool>(() => _tissue.add(key, value));
  }

  /// Asynchronously adds all entries from the given [other] map.
  ///
  /// ### Parameters:
  ///   - [other]: The [Map<K, V>] containing entries to add.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the operation is attempted.
  Future<void> addAll(Map<K, V> other) {
    return Future<void>(() => _tissue.addAll(other));
  }

  /// Adds all entries from the given [newEntries] iterable.
  ///
  /// ### Parameters:
  ///   - [newEntries]: The iterable containing entries to add.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the operation is attempted.
  Future<void> addEntries(Iterable<MapEntry<K, V>> newEntries) {
    return Future<void>(() => _tissue.addEntries(newEntries));
  }

  /// Asynchronously removes all entries from the map.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the clear operation is attempted.
  Future<void> clear() {
    return Future<void>(() => _tissue.clear());
  }

  /// Asynchronously looks up the value of [key], or adds a new entry if it isn't there.
  ///
  /// ### Parameters:
  ///   - [key]: The key to look up or add.
  ///   - [ifAbsent]: A function that returns the value to be added if [key] is not present.
  ///
  /// ### Returns:
  ///   A [Future<V>] that completes with the value associated with [key].
  Future<V> putIfAbsent(K key, V Function() ifAbsent) {
    return Future<V>(() => _tissue.putIfAbsent(key, ifAbsent));
  }

  /// Asynchronously removes [key] and its associated value.
  ///
  /// ### Parameters:
  ///   - [key]: The key of the entry to remove.
  ///
  /// ### Returns:
  ///   A [Future<V?>] that completes with the value associated with [key]
  ///   before it was removed, or `null` if [key] was not found.
  Future<V?> remove(Object? key) => Future<V?>(() => _tissue.remove(key));

  /// Asynchronously removes all entries that satisfy the given [predicate].
  ///
  /// ### Parameters:
  ///   - [predicate]: A function that takes a key-value pair and returns `true`
  ///     if the entry should be removed.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the removal operation is attempted.
  Future<void> removeWhere(bool Function(K key, V value) predicate) {
    return Future<void>(() => _tissue.removeWhere(predicate));
  }

  /// Asynchronously updates the value associated with [key].
  ///
  /// ### Parameters:
  ///   - [key]: The key whose associated value is to be updated.
  ///   - [update]: A function that computes the new value from the old value.
  ///   - [ifAbsent]: Optional. A function that computes a value if [key] is not present.
  ///
  /// ### Returns:
  ///   A [Future<V>] that completes with the new value associated with [key].
  Future<V> update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    return Future<V>(() => _tissue.update(key, update, ifAbsent: ifAbsent));
  }

  /// Asynchronously updates all values in the map.
  ///
  /// ### Parameters:
  ///   - [update]: A function that computes a new value given a key and its current value.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the update operation is attempted.
  Future<void> updateAll(V Function(K key, V value) update) {
    return Future<void>(() => _tissue.updateAll(update));
  }

}

/// An asynchronous implementation of an unmodifiable modifiable map.
///
/// This specialized class combines unmodifiable functionality with
/// asynchronous handling, offering methods that ensure immutability
/// while still supporting asynchronous operations.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly.
///
/// ### How it works
/// - Every mutation method throws [UnsupportedError] with a descriptive
///   message indicating that the operation is not supported on unmodifiable
///   views.
class _UnmodifiableModifiableMapAsync<K,V> implements ModifiableMapAsync<K,V> {

  const _UnmodifiableModifiableMapAsync();

  @override
  TissueMap<K, V> get _tissue => throw UnimplementedError();

  @override
  Future<bool> add(K key, V value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addAll(Map<K, V> other) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addEntries(Iterable<MapEntry<K, V>> newEntries) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

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

  @override
  Future<void> clear() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<V> putIfAbsent(K key, V Function() ifAbsent) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<V?> remove(Object? key) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeWhere(bool Function(K key, V value) predicate) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<V> update(K key, V Function(V value) update, {V Function()? ifAbsent}) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> updateAll(V Function(K key, V value) update) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

}