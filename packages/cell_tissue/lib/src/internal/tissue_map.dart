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
class _TissueMapNucleus<K, V, C extends TissueMap<K, V>>
    extends TissueMapNucleusBase<K, V, C> {
  _TissueMapNucleus(
      {super.bind,
      super.context,
      super.receptor,
      super.testRule,
      super.synapses,
      super.ephemeralPolicy,
      super.identityMap,
      super.forceLock,
      super.user,
      super.principal})
      : super();

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
  TissueMapNucleusBase<K, V, C> get clone {
    final p = principal;
    return TissueMapNucleus.create<K, V, C>(
      container: containerType,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses:
          synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
      user: user,
      forceLock: false,
      ephemeralPolicy: _hostedEphemeralPolicy,
      // A deputy clone must keep the principal chain and bind.
      bind: p != null ? bind : null,
      principal: p == null ? null : this,
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
abstract class TissueMapNucleusBase<K, V, C extends TissueMap<K, V>>
    extends TissueNucleusBase<V, MapStore<K, V>, C>
    implements TissueMapNucleus<K, V> {
  /// **Primary Blueprint Constructor** – Defines the immutable behaviour and
  /// storage strategy for a reactive map.
  ///
  /// In the framework's biological metaphor, this constructor synthesizes the
  /// **Initial DNA** of a map. It establishes the structural constraints
  /// (identity vs. value comparison) and the foundational integrity gates that
  /// will govern all cells derived from this nucleus.
  ///
  /// ### When to use
  /// - **Internal Implementation**: This constructor is `public` specifically
  ///   to allow concrete subclasses (like `_TissueMapNucleus`) to invoke it
  ///   via `super()`.
  /// - **Custom Map Nuclei**: Use this if you are extending the framework to
  ///   create a specialized map type with unique storage needs.
  ///
  /// **Note**: Standard application code should use [TissueMapNucleus.create]
  /// or [TissueMapNucleus.evolve] instead of calling this directly.
  ///
  /// ### How it works
  /// 1. **Structural Selection**: The [identityMap] flag determines the
  ///    physical [Container] strategy:
  ///    - `true` → [Container.identityMap]: Keys are compared using
  ///      referential identity ([identical]).
  ///    - `false` → [Container.map]: Keys are compared using standard
  ///      value equality (`==` and `hashCode`).
  /// 2. **Bitmask Encoding**: All governance parameters are passed to the
  ///    [TissueNucleusBase] super-constructor, where they are packed into
  ///    a memory-optimized, bitmask-enabled record.
  /// 3. **Immutability**: Once constructed, the structural strategy is locked.
  ///    Any future [TissueMapNucleus.evolve] operations will maintain this core DNA.
  ///
  /// ### Parameters:
  /// - [bind]: **Ingress Link.** An optional upstream [Cell] for the map to
  ///   observe and mirror.
  /// - [context]: **Operational Authority.** The security tier and priority
  ///   domain (default: [Context.system]).
  /// - [receptor]: **Command Engine.** The logic used to process map mutations.
  /// - [testRule]: **Integrity Gate.** Validation rules that guard map values.
  /// - [synapses]: **Signal Distribution.** Manages egress connectivity and
  ///   event broadcasting.
  /// - [identityMap]: If `true`, keys are compared by referential identity.
  ///   Defaults to `false` (value equality).
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines the TTL for
  ///   the collection state.
  /// - [forceLock]: If `true`, shares the [principal]'s synchronization lock;
  ///   otherwise, allocates a new one.
  /// - [user]: **Extension Metadata.** Optional record for domain-specific tags.
  /// - [principal]: **Prototype Source.** The parent nucleus from which this
  ///   instance inherits its structural DNA.
  TissueMapNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool identityMap = false,
    super.ephemeralPolicy,
    super.forceLock,
    super.user,
    super.principal,
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
  TissueMapNucleusBase<K, V, C>? get principal =>
      super.principal as TissueMapNucleusBase<K, V, C>?;

  /// The physical storage strategy (value‑based or identity‑based) used by this map.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines how keys are compared for uniqueness.
  ///
  /// ### When to use
  /// Read this to understand whether the map uses value equality (`==`) or
  /// referential identity (`identical`) for key lookup.
  ///
  @override
  Container get containerType {
    return get<Container>(() => record.local.inheritable.container,
        fallback: () => principal?.containerType, orElse: Container.map);
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
class _TissueMap<K, V, C extends TissueMap<K, V>>
    extends TissueMapBase<K, V, C> {
  _TissueMap(
      {TissueMapNucleus<K, V>? properties, Iterable<MapEntry<K, V>>? entries})
      : this.fromNucleus(properties ?? _TissueMapNucleus<K, V, C>(),
            entries: entries);

  _TissueMap.from(super.map, {TissueMapNucleus<K, V>? properties})
      : super.from(
            properties: (properties ?? _TissueMapNucleus<K, V, C>())
                as TissueMapNucleusBase<K, V, C>);

  _TissueMap.fromEntries(Iterable<MapEntry<K, V>> entries,
      {TissueMapNucleus<K, V>? properties})
      : this.fromNucleus(properties ?? _TissueMapNucleus<K, V, C>(),
            entries: entries);

  _TissueMap.identity({Iterable<MapEntry<K, V>>? entries, Cell? bind})
      : this.fromNucleus(
            _TissueMapNucleus<K, V, C>(identityMap: true, bind: bind),
            entries: entries);

  _TissueMap.fromNucleus(TissueMapNucleus<K, V> properties,
      {Iterable<MapEntry<K, V>>? entries})
      : super.fromNucleus(properties as TissueMapNucleusBase<K, V, C>,
            entries: entries);

  @override
  FutureOr<TissueMap<K, V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueMapDeputy<K, V, C>._(this,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  @override
  late final TissueMap<K, V> unmodifiable =
      _UnmodifiableTissueMap<K, V, C>.view(this, unmodifiableElement: true);
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
///   3. Dispatched as a [TissuePulse] to all observers.
/// - The underlying storage is a Dart `Map<K, V>` with the key‑comparison
///   strategy defined by the nucleus's `identityMap` flag.
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
abstract class TissueMapBase<K, V, C extends TissueMap<K, V>>
    extends TissueBase<V, MapStore<K, V>, C>
    with TissueMapMixin<K, V, C>
    implements TissueMap<K, V> {
  @override
  TissueMapNucleusBase<K, V, C> get _nucleus =>
      super._nucleus as TissueMapNucleusBase<K, V, C>;

  /// Creates a [TissueMapBase] from an existing [Map], optionally with
  /// custom [properties].
  ///
  /// ### Parameters:
  /// - [map]: The source map data.
  /// - [properties]: Optional nucleus configuration.
  TissueMapBase.from(Map<K, V> map, {TissueMapNucleusBase<K, V, C>? properties})
      : super(properties ?? _TissueMapNucleus<K, V, C>()) {
    _nucleus.container.store.addEntries(map.entries);
    for (var v in values) {
      if (v is Cell) {
        _nucleus.synapses.link(v, downstreamCell: this);
      }
    }
  }

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
  TissueMapBase.fromNucleus(TissueMapNucleusBase<K, V, C> super.properties,
      {Iterable<MapEntry<K, V>>? entries})
      : super() {
    if (entries != null) {
      _nucleus.container.store.addEntries(entries);
      for (final v in _nucleus.container.store.values) {
        if (v is Cell) {
          _nucleus.synapses.link(v, downstreamCell: this);
        }
      }
    }
  }

// ---- MapMixin mandatory overrides ----

  /// Associates the [key] with the [value] by applying the [put] operation.
  ///
  /// This is the standard index assignment operator. It is routed through
  /// the reactive pipeline: validation, atomic update, and event emission.
  /// If the key already exists, its value is replaced and a
  /// `Tissue.entryUpdated` pulse is emitted; otherwise the entry is added
  /// and a `Tissue.elementAdded` pulse is emitted.
  ///
  /// ### Parameters:
  /// - [key]: The key to associate.
  /// - [value]: The value to store.
  @override
  void operator []=(K key, V value) => put(key, value);

  /// Upserts the [key]/[value] pair through the reactive [apply] gateway.
  ///
  /// Replaces the value of an existing key (emitting `Tissue.entryUpdated`)
  /// or inserts a new entry (emitting `Tissue.elementAdded`). This is the
  /// named counterpart of the `[]=` operator and the whitelisted "set"
  /// command for [apply]/[modifiable].
  ///
  /// ### Parameters:
  /// - [key]: The key to associate.
  /// - [value]: The value to store.
  @override
  void put(K key, V value) => dispatch(put, positionalArguments: [key, value]);

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
  bool add(K key, V value) =>
      (dispatch(add, positionalArguments: [key, value])?.isNotEmpty) ?? false;

  /// Adds all entries from the given [other] map.
  @override
  void addAll(Map<K, V> other) =>
      dispatch(addAll, positionalArguments: [other]);

  /// Adds all entries from the given [newEntries] iterable.
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) =>
      dispatch(addEntries, positionalArguments: [newEntries]);

  /// Removes all entries from the map.
  @override
  void clear() => dispatch(clear);

  /// Looks up the value of [key], or adds a new entry if it isn't there.
  ///
  /// Returns the existing value if [key] is present; otherwise, calls
  /// [ifAbsent] to produce a new value, adds it, and returns that value.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) =>
      dispatch(putIfAbsent, positionalArguments: [key, ifAbsent]);

  /// Removes [key] and its associated value, returning the removed value,
  /// or `null` if the key was not present.
  @override
  V? remove(Object? key) => dispatch(remove, positionalArguments: [key]);

  /// Removes all entries that satisfy the given [predicate].
  @override
  void removeWhere(bool Function(K key, V value) predicate) =>
      dispatch(removeWhere, positionalArguments: [predicate]);

  /// Updates the value associated with [key] using the [update] function.
  ///
  /// If [key] is not present, [ifAbsent] is called and its result is added.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      dispatch(this.update,
          positionalArguments: [key, update],
          namedArguments: {#ifAbsent: ifAbsent});

  /// Updates all values by applying the [update] function to each entry.
  @override
  void updateAll(V Function(K key, V value) update) =>
      dispatch(updateAll, positionalArguments: [update]);

  // ---- Deputy & Async ----

  @override
  FutureOr<TissueMap<K, V>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue<V, C> testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _TissueMapDeputy<K, V, C>._(this,
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
class _TissueMapDeputy<K, V, C extends TissueMap<K, V>>
    extends TissueMapBase<K, V, C> with Deputy<TissueMap<K, V>> {
  _TissueMapDeputy._(TissueMapBase<K, V, C> bind,
      {Context context = Context.system,
      TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueMapNucleus<K, V, C>.fromRecord((
          local: TissueNucleusBase.mask<V, MapStore<K, V>, C>(
            bind: bind,
            testRule: bind._nucleus.testRule + testRule,
            synapses: bind._nucleus.synapses != Synapses.disabled
                ? synapses
                : Synapses.disabled,
            forceLock: true,
            ephemeralPolicy: ephemeralPolicy,
          ),
          principal: bind._nucleus,
        )));

  @override
  FutureOr<TissueMap<K, V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    final bind = _nucleus.bind;
    if (bind is TissueMapBase<K, V, C>) {
      return _TissueMapDeputy<K, V, C>._(bind,
          context: context,
          testRule: testRule,
          ephemeralPolicy: ephemeralPolicy,
          synapses: synapses);
    }
    return this;
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
class _UnmodifiableTissueMap<K, V, C extends TissueMap<K, V>>
    extends UnmodifiableTissueMapBase<K, V, C> {
  _UnmodifiableTissueMap(Iterable<MapEntry<K, V>> entries,
      {bool unmodifiableElement = true, TissueMapNucleus<K, V>? properties})
      : this.fromNucleus(
            (properties ?? TissueMapNucleus.create<K, V, C>())
                as TissueMapNucleusBase<K, V, C>,
            unmodifiableElement: unmodifiableElement,
            entries: entries);

  _UnmodifiableTissueMap.view(TissueMap<K, V> bind,
      {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(
            TissueMapNucleus.create<K, V, C>(
                bind: bind,
                context: context,
                synapses: bind._nucleus.synapses == Synapses.disabled
                    ? Synapses.disabled
                    : Synapses.enabled,
                principal: bind._nucleus as TissueMapNucleusBase<K, V, C>),
            unmodifiableElement: unmodifiableElement,
            entries: unmodifiableElement
                ? bind.entries.map((en) => MapEntry<K, V>(
                    en.key,
                    en.value is Cell
                        ? (en.value as Cell).unmodifiable as V
                        : en.value))
                : null);

  _UnmodifiableTissueMap.fromNucleus(TissueMapNucleus<K, V> properties,
      {super.unmodifiableElement, Iterable<MapEntry<K, V>>? entries})
      : super(properties as TissueMapNucleusBase<K, V, C>, entries: entries);

  /// Creates an deputy for this unmodifiable list.
  ///
  /// Note: The deputy will still enforce unmodifiability of the underlying list.
  ///
  /// Parameters:
  ///   - testRule: Additional test rules
  ///   - map: Value mapping configuration
  @override
  FutureOr<TissueMap<K, V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    final bind = _nucleus.bind;
    if (bind is TissueMapBase<K, V, C>) {
      return _TissueMapDeputy<K, V, C>._(bind,
          context: context,
          testRule: testRule,
          ephemeralPolicy: ephemeralPolicy,
          synapses: synapses);
    }
    return this;
  }

  @override
  TissueMap<K, V> get unmodifiable => this;
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
abstract class UnmodifiableTissueMapBase<K, V, C extends TissueMap<K, V>>
    extends UnmodifiableTissueBase<V, MapStore<K, V>, C>
    with TissueMapMixin<K, V, C>
    implements UnmodifiableTissueMap<K, V> {
  @override
  TissueMapNucleusBase<K, V, C> get _nucleus =>
      super._nucleus as TissueMapNucleusBase<K, V, C>;

  @override
  Iterable<Function> get modifiable => <Function>{};

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
  UnmodifiableTissueMapBase(TissueMapNucleusBase<K, V, C> super.properties,
      {super.unmodifiableElement, Iterable<MapEntry<K, V>>? entries})
      : super() {
    // The unmodifiable base does not inherit TissueMapBase's seeding path —
    // populate the container and link any cell-valued entries here.
    if (entries != null) {
      _nucleus.container.store.addEntries(entries);
      for (final v in _nucleus.container.store.values) {
        if (v is Cell) {
          _nucleus.synapses.link(v, downstreamCell: this);
        }
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
  void put(K key, V value) => throw UnsupportedError('Unmodifiable operation');

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
  void removeWhere(bool Function(K key, V value) predicate) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      throw UnsupportedError('Unmodifiable operation');

  /// @no doc
  /// Throws [UnsupportedError] as this map is unmodifiable.
  @override
  void updateAll(V Function(K key, V value) update) =>
      throw UnsupportedError('Unmodifiable operation');
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
mixin TissueMapMixin<K, V, C extends TissueMap<K, V>>
    on TissueBase<V, MapStore<K, V>, C> implements TissueMap<K, V> {
  @override
  TissueMapNucleusBase<K, V, C> get _nucleus;

  @override
  TestTissue<V, C> get validate => _nucleus.testRule;

  @override
  Iterable<Function> get modifiable => <Function>{
        add,
        addAll,
        addEntries,
        clear,
        putIfAbsent,
        put,
        remove,
        removeWhere,
        update,
        updateAll,
      };

  @override
  bool containsKey(Object? key) => _nucleus.container.store.containsKey(key);

  @override
  bool containsValue(Object? value) =>
      _nucleus.container.store.containsValue(value);

  @override
  Iterable<MapEntry<K, V>> get entries => _nucleus.container.store.entries
      .map((en) => MapEntry<K, V>(en.key as K, en.value as V))
      .cast<MapEntry<K, V>>();

  @override
  bool get isEmpty => _nucleus.container.store.isEmpty;

  @override
  bool get isNotEmpty => _nucleus.container.store.isNotEmpty;

  @override
  Iterable<K> get keys =>
      _nucleus.container.store.keys.map((key) => key as K).cast<K>();

  @override
  int get length => _nucleus.container.store.length;

  @override
  Iterable<V> get values => _nucleus.container.store.values.cast<V>();

  /// Routes whitelisted mutation functions through validation and the
  /// private reactive helpers; rejects anything else.
  @override
  dynamic dispatch(
    Function function, {
    List? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  }) {
    try {
      if (validate.action(function, host: this as C, arguments: (
            positionalArguments: positionalArguments,
            namedArguments: namedArguments
          )) ==
          true) {
        final notification = namedArguments?[#$notification] ?? true;
        final deputy = namedArguments?[#deputy];

        if (function == add) {
          return Function.apply(_add, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == addAll) {
          return Function.apply(_addAll, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == addEntries) {
          return Function.apply(_addEntries, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == put) {
          return Function.apply(_put, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == clear) {
          return Function.apply(
              _clear, null, {#notification: notification, #deputy: deputy});
        } else if (function == putIfAbsent) {
          return Function.apply(_putIfAbsent, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == remove) {
          return Function.apply(_remove, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == removeWhere) {
          return Function.apply(_removeWhere, positionalArguments,
              {#notification: notification, #deputy: deputy});
        } else if (function == update) {
          return Function.apply(_update, positionalArguments, {
            #notification: notification,
            #deputy: deputy,
            #ifAbsent: namedArguments?[#ifAbsent]
          });
        } else if (function == updateAll) {
          return Function.apply(_updateAll, positionalArguments,
              {#notification: notification, #deputy: deputy});
        }
      }
    } catch (e) {
      if (e is StateError) {
        rethrow;
      }
    }
  }

  TissuePulse<MapEntry<K, V>>? _add(K key, V value,
      {bool notification = true, Tissue<V>? deputy}) {
    TissuePulse<MapEntry<K, V>>? event;
    if (this is! Unmodifiable && modifiable.contains(add)) {
      final dynamic map = _nucleus.container.store;
      if (!map.containsKey(key) &&
          validate.element(value, host: this as C, action: add) == true) {
        map[key] = value;
        final cell = value;
        if (cell is Cell) {
          _nucleus.synapses.link(cell, downstreamCell: this);
        }
        event = _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this,
            payload: MapEntry<K, V>(key, value),
            type: Tissue.elementAdded);
        if (notification) {
          _nucleus.receptor(event);
        }
      }
    }
    return event;
  }

  /// Upserts [key]/[value] through the `put` command vector.
  ///
  /// Replaces the value of an existing key (emitting `Tissue.entryUpdated`)
  /// or inserts a new entry (emitting `Tissue.elementAdded`). Reactive links
  /// of [Cell] values are maintained: a replaced child cell is unlinked (if
  /// it no longer occurs in the store) and the new child cell is linked.
  TissuePulseBase? _put(K key, V value,
          {bool notification = true, Tissue<V>? deputy}) =>
      _setEntry(key, value,
          action: put, notification: notification, deputy: deputy);

  /// Shared insert-or-replace engine used by [put]/`[]=` and [update].
  ///
  /// The [action] parameter is the whitelisted mutation vector used both for
  /// the [modifiable] gate and element validation, so `put` and `update`
  /// remain distinguishable by action‑aware [TestTissue] rules.
  TissuePulseBase? _setEntry(
    K key,
    V value, {
    required Function action,
    bool notification = true,
    Tissue<V>? deputy,
  }) {
    if (this is! Unmodifiable && modifiable.contains(action)) {
      final dynamic map = _nucleus.container.store;
      final existed = map.containsKey(key);
      final before = existed ? map[key] as V : null;
      if (validate.element(value, host: this as C, action: action) == true) {
        map[key] = value;
        if (existed && before is Cell && !map.containsValue(before)) {
          _nucleus.synapses.unlink(before, downstreamCell: this);
        }
        if (value is Cell) {
          _nucleus.synapses.link(value, downstreamCell: this);
        }
        final event = existed
            ? _TissuePulse<EntryUpdatedRecord<K, V>>(
                source: deputy ?? this,
                payload: (key: key, before: before, after: value),
                type: Tissue.entryUpdated)
            : _TissuePulse<MapEntry<K, V>>(
                source: deputy ?? this,
                payload: MapEntry<K, V>(key, value),
                type: Tissue.elementAdded);
        if (notification) {
          _nucleus.receptor(event);
        }
        return event;
      }
    }
    return null;
  }

  TissuePulse? _addAll(Map<K, V> other,
      {bool notification = true, Tissue<V>? deputy}) {
    TissuePulse? result;
    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      final entries = <MapEntry<K, V>>[];
      final dynamic map = _nucleus.container.store;
      for (final entry in other.entries) {
        final value = entry.value;
        if (!map.containsKey(entry.key) &&
            validate.element(value, host: this as C, action: add) == true) {
          map[entry.key] = value;
          if (value is Cell) {
            _nucleus.synapses.link(value, downstreamCell: this);
          }
          entries.add(MapEntry<K, V>(entry.key, value));
        }
      }
      if (entries.isNotEmpty) {
        final events = entries.map((en) => _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this, payload: en, type: Tissue.elementAdded));
        result = events.length == 1
            ? events.first
            : TissuePulse.batch<MapEntry<K, V>>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  TissuePulse? _addEntries(Iterable<MapEntry<K, V>> newEntries,
      {bool notification = true, Tissue<V>? deputy}) {
    TissuePulse? result;
    if (this is! Unmodifiable && modifiable.contains(addEntries)) {
      final entries = <MapEntry<K, V>>[];
      final dynamic map = _nucleus.container.store;
      for (final entry in newEntries) {
        final value = entry.value;
        if (!map.containsKey(entry.key) &&
            validate.element(value, host: this as C, action: add) == true) {
          map[entry.key] = value;
          if (value is Cell) {
            _nucleus.synapses.link(value, downstreamCell: this);
          }
          entries.add(MapEntry<K, V>(entry.key, value));
        }
      }
      if (entries.isNotEmpty) {
        final events = entries.map((en) => _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this, payload: en, type: Tissue.elementAdded));
        result = events.length == 1
            ? events.first
            : TissuePulse.batch<MapEntry<K, V>>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  TissuePulse? _clear({bool notification = true, Tissue<V>? deputy}) {
    TissuePulse? result;
    if (this is! Unmodifiable && modifiable.contains(clear)) {
      final entries = <MapEntry<K, V>>[];
      final dynamic map = _nucleus.container.store;
      final keys = map.keys.toList();
      for (final key in keys) {
        final value = map[key];
        if (value != null &&
            validate.element(value, host: this as C, action: remove) == true) {
          _nucleus.container.store.remove(key);
          if (value is Cell && !map.containsValue(value)) {
            _nucleus.synapses.unlink(value, downstreamCell: this);
          }
          entries.add(MapEntry<K, V>(key, value));
        }
      }
      if (entries.isNotEmpty) {
        final events = entries.map((en) => _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this, payload: en, type: Tissue.elementRemoved));
        result = events.length == 1
            ? events.first
            : TissuePulse.batch<MapEntry<K, V>>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  V _putIfAbsent(K key, V Function() ifAbsent,
      {bool notification = true, Tissue<V>? deputy}) {
    if (this is! Unmodifiable && modifiable.contains(putIfAbsent)) {
      final dynamic map = _nucleus.container.store;
      if (map.containsKey(key)) {
        return map[key] as V;
      }
      final value = ifAbsent();
      if (validate.element(value, host: this as C, action: add) == true) {
        map[key] = value;
        if (value is Cell) {
          _nucleus.synapses.link(value, downstreamCell: this);
        }
        final event = _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this,
            payload: MapEntry<K, V>(key, value),
            type: Tissue.elementAdded);
        if (notification) {
          _nucleus.receptor(event);
        }
      }
      return value;
    }
    throw UnsupportedError('Unmodifiable operation');
  }

  V? _remove(Object? key, {bool notification = true, Tissue<V>? deputy}) {
    if (this is! Unmodifiable && modifiable.contains(remove)) {
      final dynamic map = _nucleus.container.store;
      if (map.containsKey(key)) {
        V? value = map[key];
        if (value != null &&
            validate.element(value, host: this as C, action: remove) == true) {
          final en = MapEntry<K, V>(key as K, value);
          value = map.remove(key);
          if (value is Cell && !map.containsValue(value)) {
            _nucleus.synapses.unlink(value, downstreamCell: this);
          }
          final event = _TissuePulse<MapEntry<K, V>>(
              source: deputy ?? this, payload: en, type: Tissue.elementRemoved);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
        return value;
      }
    }
    return null;
  }

  TissuePulse? _removeWhere(bool Function(K key, V value) predicate,
      {bool notification = true, Tissue<V>? deputy}) {
    TissuePulse? result;
    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      final dynamic map = _nucleus.container.store;
      final entries = <MapEntry<K, V>>[];
      final keys = map.keys.toList();
      for (final rawKey in keys) {
        final key = rawKey;
        V? value = map[key];
        if (value != null &&
            predicate(key, value) &&
            validate.element(value, host: this as C, action: remove) == true) {
          map.remove(key);
          if (value is Cell && !map.containsValue(value)) {
            _nucleus.synapses.unlink(value, downstreamCell: this);
          }
          entries.add(MapEntry<K, V>(key, value));
        }
      }
      if (entries.isNotEmpty) {
        final events = entries.map((en) => _TissuePulse<MapEntry<K, V>>(
            source: deputy ?? this, payload: en, type: Tissue.elementRemoved));
        result = events.length == 1
            ? events.first
            : TissuePulse.batch<MapEntry<K, V>>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }

  V _update(K key, V Function(V value) update,
      {V Function()? ifAbsent, bool notification = true, Tissue<V>? deputy}) {
    if (this is! Unmodifiable && modifiable.contains(this.update)) {
      final dynamic map = _nucleus.container.store;
      if (map.containsKey(key)) {
        final newValue = update(map[key] as V);
        _setEntry(key, newValue,
            action: this.update, notification: notification, deputy: deputy);
        return newValue;
      }

      if (ifAbsent != null) {
        final value = ifAbsent();
        _setEntry(key, value,
            action: this.update, notification: notification, deputy: deputy);
        return value;
      }
      throw StateError('No element');
    }
    throw UnsupportedError('Unmodifiable operation');
  }

  TissuePulse? _updateAll(V Function(K key, V value) update,
      {bool notification = true, Tissue<V>? deputy}) {
    TissuePulse? result;
    if (this is! Unmodifiable && modifiable.contains(updateAll)) {
      final dynamic map = _nucleus.container.store;
      final records = <EntryUpdatedRecord<K, V>>[];
      final keys = map.keys.toList();
      for (final rawKey in keys) {
        final key = rawKey;
        final oldValue = map[key] as V;
        final newValue = update(key, oldValue);
        if (validate.element(newValue, host: this as C, action: updateAll) ==
            true) {
          map[key] = newValue;
          if (oldValue is Cell && !map.containsValue(oldValue)) {
            _nucleus.synapses.unlink(oldValue, downstreamCell: this);
          }
          if (newValue is Cell) {
            _nucleus.synapses.link(newValue, downstreamCell: this);
          }
          records.add((key: key, before: oldValue, after: newValue));
        }
      }
      if (records.isNotEmpty) {
        final events = records.map<TissuePulse<EntryUpdatedRecord<K, V>>>(
            (rec) => _TissuePulse<EntryUpdatedRecord<K, V>>(
                source: deputy ?? this,
                payload: rec,
                type: Tissue.entryUpdated));
        result = events.length == 1
            ? events.first
            : TissuePulse.batch<EntryUpdatedRecord<K, V>>(events);
        if (notification) {
          _nucleus.receptor(result);
        }
      }
    }
    return result;
  }
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
class ModifiableMapAsync<K, V>
    extends TissueModifiableAsync<V, TissueMap<K, V>> {
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

  /// Asynchronously upserts the ([key], [value]) pair into the map.
  ///
  /// Replaces the value of an existing key or inserts a new entry, and
  /// completes after the reactive propagation has settled.
  ///
  /// ### Parameters:
  ///   - [key]: The key to associate.
  ///   - [value]: The value to store.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the operation is attempted.
  Future<void> put(K key, V value) {
    return Future<void>(() => _tissue.put(key, value));
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
  Future<V> update(K key, V Function(V value) update,
      {V Function()? ifAbsent}) {
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
class _UnmodifiableModifiableMapAsync<K, V>
    implements ModifiableMapAsync<K, V> {
  const _UnmodifiableModifiableMapAsync();

  /// The read-only async projection has no command surface.
  @override
  Future<ApplyOutcome<R>> apply<R>(ApplyCommand command,
          {ApplyTransactionScope? tx}) =>
      Future<ApplyOutcome<R>>.error(UnsupportedError('Unmodifiable operation'));

  @override
  TissueMap<K, V> get _tissue => throw UnimplementedError();

  @override
  Future<bool> add(K key, V value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> put(K key, V value) async {
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
  Future<V> update(K key, V Function(V value) update,
      {V Function()? ifAbsent}) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> updateAll(V Function(K key, V value) update) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }
}

/// A physical map storage that is both an [Iterable] over its values and a
/// map-like accessor for keys. It bridges the gap between the generic
/// [TissueContainer] (which requires an [Iterable] store) and the map‑shaped
/// storage needs of [TissueMap].
class MapStore<K, V> extends IterableBase<V> {
  /// Creates a [MapStore] wrapping the provided [map].
  MapStore(Map<K, V> map) : _map = map;

  final Map<K, V> _map;

  /// The value associated with [key], if any.
  V? operator [](Object? key) => _map[key];

  /// Associates [key] with [value].
  void operator []=(K key, V value) => _map[key] = value;

  /// Whether the store contains [key].
  bool containsKey(Object? key) => _map.containsKey(key);

  /// Whether the store contains [value].
  bool containsValue(Object? value) => _map.containsValue(value);

  /// The entries of the underlying map.
  Iterable<MapEntry<K, V>> get entries => _map.entries;

  /// The keys of the underlying map.
  Iterable<K> get keys => _map.keys;

  /// The values of the underlying map.
  Iterable<V> get values => _map.values;

  /// The number of key‑value pairs.
  @override
  int get length => _map.length;

  /// Whether the store is empty.
  @override
  bool get isEmpty => _map.isEmpty;

  /// Whether the store is non‑empty.
  @override
  bool get isNotEmpty => _map.isNotEmpty;

  /// Adds all [newEntries].
  void addEntries(Iterable<MapEntry<K, V>> newEntries) =>
      _map.addEntries(newEntries);

  /// Removes [key] and returns its value, if present.
  V? remove(Object? key) => _map.remove(key);

  /// Iterates the values of the map.
  @override
  Iterator<V> get iterator => _map.values.iterator;

  @override
  String toString() => _map.toString();
}
