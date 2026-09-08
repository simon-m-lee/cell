// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A lightweight, single‑element storage vessel designed to bridge the
/// gap between scalar values and the [Tissue] reactive ecosystem.
///
/// [ValueContainer] is a specialised implementation of [IterableBase] that
/// models an "Option" or "Nullable Box" as a collection of zero or one
/// elements. Within the `cell_tissue` framework, it serves as the
/// primary physical storage for `TissueValue` instances.
///
/// ### When to use
/// This container is used internally by [TissueValue] to represent an optional
/// value. It's not something you typically interact with directly.
///
/// You never construct this directly. It's used automatically when you create
/// a [TissueValue]. The framework wraps your scalar value into this container
/// so it can participate in the collection‑based reactive graph.
///
/// ### How it works
/// - If the [value] is `null`, the container behaves as an empty collection
///   (`length == 0`).
/// - If the [value] is present, it behaves as a singleton collection
///   (`length == 1`).
/// - It provides an iterator that yields zero or one element.
/// - When the value is swapped, the owning [TissueValue] detects the change
///   and broadcasts the appropriate reactive signals.
///
/// ### Non‑obvious
/// - Unlike a [List] with a single element, [ValueContainer] avoids the
///   overhead of an underlying array allocation. It stores the reference
///   directly, making it memory‑efficient.
/// - The container is mutable – you can change `value` directly. However,
///   in a [Tissue] context, you should use the tissue's `set` method to
///   ensure validation and pulse propagation.
/// - The container itself is not reactive; it's just a dumb storage cell.
///   Reactivity is added by the [TissueValue] that wraps it.
///
/// ### Example (internal usage)
/// ```dart
/// final container = ValueContainer<int>(42);
/// print(container.length); // 1
/// print(container.first);  // 42
/// container.value = null;
/// print(container.length); // 0
/// ```
///
/// ### Type Parameters:
/// * [V]: The type of the value contained within.
class ValueContainer<V> extends IterableBase<V> {

  /// The single, optional value held by this container.
  ///
  /// Mutating this field directly within a [Tissue] context will
  /// trigger the associated [Receptor] logic to synchronize the
  /// reactive graph.
  V? value;

  /// Creates a [ValueContainer], optionally initializing it with a [value].
  ///
  /// ### When to use
  /// This constructor is called internally by [TissueValue]. You don't
  /// typically need to use it directly.
  ///
  /// ### Parameters:
  /// - [value]: The initial state of the container. Defaults to `null`.
  ValueContainer([this.value]);

  /// Returns an iterator that yields exactly zero or one elements.
  ///
  /// ### How it works
  /// - If [value] is `null`, returns an empty iterator.
  /// - If [value] is present, returns an iterator that yields the [value]
  ///   exactly once and then terminates.
  ///
  /// ### Returns:
  /// An iterator over the contained value, or an empty iterator if `null`.
  @override
  Iterator<V> get iterator => value != null ? [value as V].iterator : Iterable<V>.empty().iterator;

}

/// A concrete, strategy‑based implementation of the [Container] interface that
/// manages the physical storage and structural lifecycle of [Tissue] elements.
///
/// [TissueContainer] serves as the **Physical Storage Layer** of the
/// `cell_tissue` ecosystem. It bridges the abstract requirements of the
/// reactive framework with concrete Dart collection types (like [List], [Set],
/// [Map], or [ValueContainer]).
///
/// ### When to use
/// You might need to use this class if you are building a custom collection
/// type that requires a non‑standard storage strategy (e.g., an LRU cache,
/// a ring buffer). In most cases, the predefined [Container] strategies
/// (list, set, map, queue, value) are sufficient.
///
/// You rarely need to interact with this class directly. It is created
/// automatically when you instantiate a [Tissue] (list, set, map, queue, or
/// value). The container is accessible via the tissue's nucleus, but you
/// usually work with the high‑level collection API.
///
/// ### How it works
/// - It wraps a concrete storage instance ([store]) of type [I], delegating
///   structural operations to a specialised [_Container] strategy.
/// - The same container class can power diverse collection types (Lists,
///   Sets, Maps, Queues) by swapping the strategy.
/// - When a [Cell] is added to the container, it automatically establishes a
///   reactive [link] between the element and the owning [Tissue]. This enables
///   "Member‑Level Bubbling," where changes inside a nested cell trigger the
///   principal collection's observers.
/// - Operations are designed to be invoked within the synchronisation [Lock]
///   of a [Nucleus], ensuring atomic integrity.
/// - The [store] is initialised lazily via the [init] method, allowing
///   collections to defer memory allocation until the first pulse or
///   iteration occurs.
///
/// ### Non‑obvious
/// - The container is **not** itself reactive – it only stores data. Reactivity
///   is provided by the [Tissue] that wraps it.
/// - The `add` and `remove` methods automatically manage synaptic links for
///   child cells. When you add a cell, it's linked; when you remove it, it's
///   unlinked (if no other references exist).
/// - The `store` is `late final` – it must be initialised before use. The
///   `init` method is called by the tissue during construction.
/// - Equality of containers is based on the underlying store's equality.
///
/// ### Type Parameters:
/// * [E]: The type of elements managed by the tissue.
/// * [I]: The concrete [Iterable] type used for storage (e.g., `List<E>`).
///
/// ### Example (internal usage)
/// ```dart
/// // A container backed by a growable list
/// final container = Container.list.create<int>();
/// container.init([1, 2, 3]);
/// print(container.length); // 3
/// container.add(myTissue, 4); // adds and links if 4 is a Cell
/// ```
class TissueContainer<E,I extends Iterable<E>> extends IterableBase<E> implements Container {

  /// The physical, late-initialized storage instance for the tissue's data.
  ///
  /// This field represents the **Source of Truth** for the reactive collection.
  /// It is typed as [I], which is the concrete Dart [Iterable] implementation
  /// (e.g., `List<E>`, `Set<E>`, or `ValueContainer<E>`) that holds the actual
  /// elements.
  ///
  /// ### Initialization Strategy (Lazy & Explicit):
  /// To optimize memory and performance, the [store] is marked as `late final`.
  /// It is not allocated upon the container's creation, but rather through one
  /// of two pathways:
  ///
  /// 1.  **Explicit Initialization**: Via the [init] method, which is typically
  ///     called by the [TissueReceptor] when a collection is first populated
  ///     or hydrated from a persistent state.
  /// 2.  **Lazy Consumption**: If the [iterator] is accessed before an explicit
  ///     [init] call, the `late` mechanism triggers the initialization logic
  ///     to ensure the container is never in an invalid null state during
  ///     iteration.
  ///
  /// ### Architectural Role in the Conactive Model:
  /// Within the framework's split-architecture (Logic vs. Storage):
  /// - **Isolation**: The [store] remains isolated from the reactive propagation
  ///   logic. It only handles raw data storage.
  /// - **Atomic Boundary**: Access to and mutation of the [store] should
  ///   ideally be performed within the synchronization [Lock] of the owning
  ///   [Cell]'s nucleus to prevent partial-state reads during a propagation wave.
  /// - **Finality**: Once initialized, the identity of the [store] is immutable
  ///   (`final`). While the *contents* of the store may change (if the
  ///   collection is growable), the storage vessel itself remains constant for
  ///   the lifetime of the [TissueContainer].
  ///
  /// ### Type Constraints:
  /// The type [I] must be a subtype of `Iterable<E>`. This ensures that regardless
  /// of whether the underlying storage is a specialized Map-view, a singleton
  /// value, or a standard list, it can always be traversed and projected through
  /// the [Tissue] interface.
  late final I store;

  final _Container _type;

  /// Internal constructor to create a [TissueContainer] with a specific type strategy.
  ///
  /// ### When to use
  /// This constructor is marked as private and is typically intended to be
  /// called from within the library, ensuring that the `_type` provides the
  /// correct behavioral functions for type `I`.
  ///
  /// ### Parameters:
  /// - `_type`: The [_Container<I>] that dictates the initialization, add, and
  ///   remove behavior of this container.
  TissueContainer._(this._type);

  /// Returns an iterator over the elements in the [store].
  ///
  /// ### How it works
  /// If the [store] has not yet been initialised (which can happen if neither `init`
  /// nor `iterator` has been called before), this getter will trigger its
  /// initialisation by calling `_type._init<E>()`.
  ///
  /// ### Returns:
  /// An iterator over the elements in the store.
  @override
  Iterator<E> get iterator => store.iterator;

  /// Commits the initial state and allocates the physical [store] for the tissue.
  ///
  /// This method performs the **Physical Transition** from a logical nucleus
  /// configuration to a populated memory structure. Within the `cell_tissue`
  /// framework, [init] is the primary entry point for state hydration and
  /// bootstrapping.
  ///
  /// ### When to use
  /// You don't call this directly – it's invoked by the [Tissue] during
  /// construction or when the collection is first used.
  ///
  /// ### How it works
  /// - It processes the optional [initialisation] payload, which can be a raw
  ///   [Iterable], a [Map], or a scalar value depending on the [store] type [I].
  /// - It invokes the `_init` closure defined in the container's [_type] strategy.
  /// - The [store] is assigned exactly once; subsequent calls are no‑ops.
  ///
  /// ### Non‑obvious
  /// - The [initialisation] parameter is polymorphic – it can be an `Iterable`,
  ///   a `Map`, or a single value, depending on the storage strategy.
  /// - If the store was already initialised (e.g., by the [iterator] lazy path),
  ///   this method safely returns the existing instance.
  ///
  /// ### Parameters:
  /// - [initialisation]: Optional data used to populate the collection.
  ///
  /// ### Returns:
  /// The newly allocated and populated [store] instance of type [I].
  @override
  I init([initialization]) {
    return store = _init<E>(initialization);
  }

  /// Attempts to physically insert an element [e] into the underlying [store]
  /// while establishing the necessary reactive dependencies.
  ///
  /// ### When to use
  /// This is called by the tissue's mutation methods (e.g., `add`, `addAll`).
  /// You don't call it directly.
  ///
  /// ### How it works
  /// - Delegates to the `_add` function of the container's strategy.
  /// - If the element [e] is itself a [Cell], it automatically invokes
  ///   `synapses.link` to wire the element into the tissue's dependency graph.
  /// - The operation is designed to occur within the synchronisation [Lock] of
  ///   the [tissue], ensuring atomicity.
  ///
  /// ### Non‑obvious
  /// - The method is wrapped in a `try‑catch` to handle edge cases where the
  ///   underlying store might be fixed‑length (throwing an [UnsupportedError]).
  /// - If the element is a [Cell] and the addition succeeds, the link is
  ///   established. If the element was already present (in a Set), the link
  ///   is still established if it's a new reference.
  ///
  /// ### Parameters:
  /// - [tissue]: The [Tissue] instance that owns this container.
  /// - [e]: The element to be added.
  ///
  /// ### Returns:
  /// - `true` if the element was successfully added and (if applicable)
  ///   the reactive link was established.
  /// - `false` if the addition failed or was rejected by the strategy.
  @override
  bool add(Tissue<E> tissue, E e) {
    try {
      if (_add<E>(tissue, store, e)) {
        if (e is Cell) {
          tissue._nucleus.synapses.link(e, downstreamCell: tissue);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Attempts to physically remove an element [e] from the underlying [store]
  /// while gracefully dismantling its reactive dependencies.
  ///
  /// ### When to use
  /// Called by the tissue's mutation methods (e.g., `remove`, `removeAll`).
  /// You don't call it directly.
  ///
  /// ### How it works
  /// - Delegates to the `_remove` function of the container's strategy.
  /// - If the element [e] is a [Cell], it checks if the element still exists
  ///   elsewhere in the collection. If not, it invokes `synapses.unlink` to
  ///   sever the dependency.
  /// - The operation is atomic within the tissue's lock.
  ///
  /// ### Non‑obvious
  /// - The duplicate check is important for non‑unique collections like Lists.
  ///   If the same [Cell] instance appears multiple times, the link is
  ///   preserved until the last reference is removed.
  /// - If the element is not found, the method returns `false` without
  ///   attempting to unlink.
  ///
  /// ### Parameters:
  /// - [tissue]: The [Tissue] instance that owns this container.
  /// - [e]: The element to be removed.
  ///
  /// ### Returns:
  /// - `true` if the element was successfully removed and (if applicable)
  ///   its reactive link was cleaned up.
  /// - `false` if the element was not found or the removal failed.
  @override
  bool remove(Tissue<E> tissue, E e) {
    try {
      if (_remove<E>(tissue, store, e)) {
        if (e is Cell && !tissue.contains(e)) {
          tissue._nucleus.synapses.unlink(e, downstreamCell: tissue);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Gets the add function from the configured [_type].
  Function get _add => _type._add;

  /// Gets the initialisation function from the configured [_type].
  Function get _init => _type._init;

  /// Gets the remove function from the configured [_type].
  Function get _remove => _type._remove;

  @override
  String toString() => 'TissueContainer[$I]: $store';

}

/// A strategic architectural contract that defines how [Tissue] data is
/// physically stored, initialised, and manipulated.
///
/// [Container] serves as the **Storage Strategy Provider** for the
/// `cell_tissue` ecosystem. It decouples the high‑level reactive
/// requirements of a collection (like signalling and dependency tracking)
/// from the low‑level mechanics of Dart's native collection types (like [List],
/// [Set], or [Map]).
///
/// ### When to use
/// You might need to use this interface if you are building a custom
/// collection type that requires a non‑standard storage behaviour (e.g.,
/// a specialised list that maintains a fixed capacity, or a set that uses
/// identity equality). In such cases, you can create a custom `Container`
/// strategy using `Container.create()`.
///
/// You rarely need to interact with this interface directly. It is used
/// internally by the framework to select the appropriate storage strategy
/// based on the collection type. The predefined constants (`Container.list`,
/// `Container.set`, `Container.map`, `Container.queue`, `Container.value`)
/// are the entry points for most use cases.
///
/// ### How it works
/// - Each [Container] instance is a strategy object that defines three
///   functions: `create`, `add`, and `remove`.
/// - The `create` function initialises the underlying storage (e.g., a new
///   `List`, `Set`, or `Map`).
/// - The `add` and `remove` functions perform the actual mutation on the
///   storage, with the strategy handling type‑specific concerns (e.g.,
///   uniqueness for sets, shifting for lists).
/// - The framework uses these strategies via a [TissueContainer], which
///   holds the strategy and the actual storage instance.
///
/// ### Predefined Strategies
/// The interface provides several static constants for common storage types:
/// - [Container.list] – standard growable list.
/// - [Container.growableTrue] / [Container.growableFalse] – fixed/growable list.
/// - [Container.set] – value‑based set.
/// - [Container.identitySet] – identity‑based set (uses [identical]).
/// - [Container.map] – standard map (value‑based keys).
/// - [Container.identityMap] – identity‑based map.
/// - [Container.queue] – double‑ended queue.
/// - [Container.value] – mutable scalar value container.
/// - [Container.finalValue] – write‑once scalar container.
/// - [Container.iterable] – read‑only iterable (no mutations).
/// - [Container.iterableNever] – permanently empty iterable.
///
/// ### Non‑obvious
/// - The strategy is **stateless** – it holds no data. The data is stored
///   in a separate [TissueContainer] instance. This allows strategies to
///   be shared (flyweight pattern) across millions of collections.
/// - The `add` and `remove` functions are responsible for **reactive
///   lifecycle management** – they should not be called directly without
///   the appropriate context (tissue, lock, etc.). The framework handles
///   this via [TissueContainer].
/// - When you create a custom strategy, you must ensure that the `add` and
///   `remove` functions correctly handle the linking/unlinking of [Cell]
///   elements if needed. The framework expects that the container will
///   call `synapses.link`/`unlink` appropriately, but the strategy itself
///   only knows about the storage; the linking is done in [TissueContainer].
///
/// ### Example: Using a predefined strategy
/// ```dart
/// // Create a container backed by an identity set
/// final strategy = Container.identitySet;
/// final container = strategy.create<String>();
/// container.init(['a', 'b']);
/// ```
///
/// ### Example: Custom strategy
/// ```dart
/// final custom = Container.create<List<int>, List<int>>(
///   create: (init) => List<int>.from(init ?? [], growable: false),
///   add: (tissue, list, e) {
///     if (list.length < 10) { list.add(e); return true; }
///     return false;
///   },
///   remove: (tissue, list, e) => list.remove(e),
/// );
/// ```
///
/// ### See also:
/// - [TissueContainer] – the physical container that uses these strategies.
/// - [Container.create] – factory to build custom strategies.
abstract interface class Container {

  /// A specialised [Container] sentinel strategy specifically designed for
  /// collections that are intended to remain permanently empty and unmodifiable.
  ///
  /// [iterableNever] represents a terminal storage strategy within the
  /// `cell_tissue` ecosystem. It is primarily used for "Leaf" nodes in
  /// a reactive graph where no descendants, elements, or associations are
  /// permitted by the architectural model.
  ///
  /// ### When to use
  /// This is used internally as a fallback for collections that should never
  /// contain data, such as a `TissueNever` instance.
  ///
  /// ### How it works
  /// - The `create` function returns a singleton empty `Iterable<Never>`.
  /// - The `add` and `remove` functions always return `false`.
  /// - No reactive links are ever established.
  ///
  /// ### Non‑obvious
  /// - This is a singleton – all instances share the same empty iterable.
  /// - It is the most memory‑efficient container possible.
  static const iterableNever = _Container(create: _iterableNeverCreate, add: _iterableNeverAdd, remove: _iterableNeverRemove);

  /// A strategy for standard, read‑only [Iterable] behaviour.
  ///
  /// ### When to use
  /// Use this when you need a collection that can be traversed but never
  /// modified. It's used for static projections or external data sources.
  ///
  /// ### How it works
  /// - The `create` function returns the provided iterable (or an empty one).
  /// - The `add` and `remove` functions always return `false`.
  /// - No reactive linking is performed.
  ///
  /// ### Non‑obvious
  /// - The underlying iterable is not copied – the container holds a reference
  ///   to the original. If the original is mutable, changes will be visible.
  /// - This strategy is often used for `Tissue.unmodifiable` views.
  static const iterable = _Container(create: _iterableCreate, add: _iterableAdd, remove: _iterableRemove);

  /// A strategy for standard [Set] behaviour, ensuring element uniqueness
  /// through value equality (`==`).
  ///
  /// ### When to use
  /// Use this for collections that require unique elements, such as tags,
  /// IDs, or permission scopes.
  ///
  /// ### How it works
  /// - The `create` function returns a [LinkedHashSet] (preserves insertion order).
  /// - The `add` function adds the element if not already present.
  /// - The `remove` function removes the element if present.
  ///
  /// ### Non‑obvious
  /// - The set uses value equality, so two different objects with the same
  ///   `hashCode` and `==` are considered duplicates.
  /// - For identity‑based uniqueness, use [Container.identitySet].
  static const set = _Container(create: _setCreate, add: _setAdd, remove: _setRemove);

  /// A specialised [Container] strategy that determines uniqueness based on
  /// **Referential Identity** ([identical]) rather than value equality.
  ///
  /// ### When to use
  /// Use this when you need to track unique physical instances, even if they
  /// have the same value. Essential for managing collections of reactive
  /// nodes where identity matters.
  ///
  /// ### How it works
  /// - The `create` function returns a [LinkedHashSet.identity].
  /// - Membership is determined by [identical] comparisons.
  ///
  /// ### Non‑obvious
  /// - This is faster than value‑based sets because it avoids calling
  ///   `hashCode` and `==`.
  /// - It is the preferred strategy for collections of `Cell` objects.
  static const identitySet = _Container(create: _identitySetCreate, add: _setAdd, remove: _setRemove);

  /// A strategy for standard, growable [List] behaviour.
  ///
  /// ### When to use
  /// Use this for ordered collections that need to support dynamic growth,
  /// such as task lists, event logs, or UI data sources.
  ///
  /// ### How it works
  /// - The `create` function returns a growable `List<E>`.
  /// - The `add` function appends the element.
  /// - The `remove` function removes the first occurrence.
  ///
  /// ### Non‑obvious
  /// - Lists allow duplicate elements. The container tracks each reference
  ///   separately and only unlinks a `Cell` when the last reference is removed.
  /// - For fixed‑length lists, use [Container.growableFalse].
  static const list = _Container(create: _listCreate, add: _listAdd, remove: _listRemove);

  /// A strategy for explicitly **Growable** [List] behaviour.
  static const growableTrue = _Container(create: _growableTrueCreate, add: _listAdd, remove: _listRemove);

  /// A strategy for **Fixed‑Length** [List] behaviour, where the structural
  /// dimensions of the collection are immutable after initialisation.
  ///
  /// ### When to use
  /// Use this when you need a collection with a constant size, such as a
  /// coordinate vector or a fixed‑size buffer.
  ///
  /// ### How it works
  /// - The `create` function returns a fixed‑length `List<E>`.
  /// - The `add` function will throw if the list is full (or if the list is
  ///   not growable).
  /// - The `remove` function works on fixed‑length lists (removes by value,
  ///   shifting elements), but the length stays the same.
  ///
  /// ### Non‑obvious
  /// - Even though the list is fixed‑length, you can still replace elements
  ///   using index assignment. The `add` and `remove` methods operate on
  ///   content, not structure.
  /// - This strategy is memory‑efficient for known‑size collections.
  static const growableFalse = _Container(create: _growableFalseCreate, add: _listAdd, remove: _listRemove);

  /// A strategy for standard **Queue** (First‑In‑First‑Out) behaviour.
  ///
  /// ### When to use
  /// Use this for reactive buffers, event pipelines, or any FIFO structure.
  ///
  /// ### How it works
  /// - The `create` function returns a `Queue<E>` (using [ListQueue]).
  /// - The `add` function adds to the end (`addLast`).
  /// - The `remove` function removes the first occurrence.
  ///
  /// ### Non‑obvious
  /// - The queue strategy also supports a `capacity` parameter (via the nucleus)
  ///   for bounded queues. When capacity is reached, `add` may drop the oldest
  ///   element or reject the new one, depending on the implementation.
  static const queue = _Container(create: _queueCreate, add: _queueAdd, remove: _queueRemove);

  /// A strategy for standard [Map] behaviour, providing reactive
  /// key‑value association through value‑based indexing.
  ///
  /// ### When to use
  /// Use this for dictionaries, registries, or any key‑value store where
  /// keys are compared by value equality.
  ///
  /// ### How it works
  /// - The `create` function returns a `Map<K, V>` (using [LinkedHashMap]).
  /// - The `add` function updates or inserts the entry.
  /// - The `remove` function removes the entry by key.
  ///
  /// ### Non‑obvious
  /// - The map is treated as a collection of values; keys are the "indices".
  /// - For identity‑based keys, use [Container.identityMap].
  static const map = _Container(create: _mapCreate, add: _mapAdd, remove: _mapRemove);

  /// A specialised [Map] strategy that determines key uniqueness based on
  /// **Referential Identity** ([identical]) rather than value equality.
  ///
  /// ### When to use
  /// Use this when keys are themselves reactive nodes or complex objects
  /// that should be distinguished by identity.
  static const identityMap = _Container(create: _identityMapCreate, add: _mapAdd, remove: _mapRemove);

  /// A strategy for **Single‑Value** behaviour using [ValueContainer].
  ///
  /// ### When to use
  /// Used internally by [TissueValue] to represent an optional scalar value.
  ///
  /// ### How it works
  /// - The `create` function returns a `ValueContainer<V>`.
  /// - The `add` function replaces the current value (if different).
  /// - The `remove` function sets the value to `null`.
  ///
  /// ### Non‑obvious
  /// - This is not a collection in the traditional sense; it's a container
  ///   that behaves like a collection of zero or one element.
  static const value = _Container(create: _valueCreate, add: _valueAdd, remove: _valueRemove);

  /// A specialised [Container] strategy for representing a single,
  /// **Deeply Immutable** value within the tissue ecosystem.
  ///
  /// [finalValue] is a write‑once container. Once set, it cannot be changed.
  ///
  /// ### When to use
  /// Use this for constants or values that should never change after
  /// initialisation.
  ///
  /// ### How it works
  /// - The `create` function returns the value itself (not a container).
  /// - The `add` and `remove` functions always return `false`.
  ///
  /// ### Non‑obvious
  /// - This is the most memory‑efficient way to represent an immutable scalar.
  static const finalValue = _Container(create: _finalValueCreate, add: _finalValueAdd, remove: _finalValueRemove);

  /// Commits the initial state and allocates the physical storage for the
  /// collection.
  ///
  /// ### When to use
  /// You don't call this directly – it's invoked by [TissueContainer.init].
  ///
  /// ### How it works
  /// - Delegates to the strategy's `create` function.
  /// - The [initialisation] parameter is passed along.
  ///
  /// ### Returns:
  /// The newly allocated storage instance.
  init([initialization]);

  /// Attempts to physically insert an element [e] into the underlying storage.
  ///
  /// ### When to use
  /// Called by [TissueContainer.add]. You don't call this directly.
  ///
  /// ### Parameters:
  /// - [tissue]: The owning tissue.
  /// - [e]: The element to add.
  ///
  /// ### Returns:
  /// `true` if the element was added; `false` otherwise.
  bool add(covariant Tissue tissue, covariant e);

  /// Attempts to physically remove an element [e] from the underlying storage.
  ///
  /// ### When to use
  /// Called by [TissueContainer.remove]. You don't call this directly.
  ///
  /// ### Parameters:
  /// - [tissue]: The owning tissue.
  /// - [e]: The element to remove.
  ///
  /// ### Returns:
  /// `true` if the element was removed; `false` otherwise.
  bool remove(covariant Tissue tissue, covariant e);

  /// Creates and configures a [Container] strategy that defines the physical
  /// allocation, mutation logic, and structural behaviour for a [Tissue].
  ///
  /// ### When to use
  /// Use this when the predefined constants don't cover your needs – e.g.,
  /// a list with a custom capacity limit, or a set with a different
  /// underlying implementation.
  ///
  /// ### How it works
  /// - You provide optional `create`, `add`, and `remove` functions.
  /// - If you omit them, the factory infers a default strategy based on the
  ///   type parameter [I] (e.g., `List` -> `Container.list`).
  /// - You can also pass `growable`, `identitySet`, and `identityMap` flags
  ///   to select variants of the default strategies.
  ///
  /// ### Parameters:
  /// - [create]: Custom function to initialise the store.
  /// - [add]: Custom function to handle insertion.
  /// - [remove]: Custom function to handle deletion.
  /// - [growable]: For List‑like stores, indicates if the list is dynamic.
  /// - [identitySet]: For Set‑like stores, forces identity‑based membership.
  /// - [identityMap]: For Map‑like stores, forces identity‑based keys.
  ///
  /// ### Returns:
  /// A [Container] instance configured with the specified or inferred strategy.
  ///
  /// ### Example
  /// ```dart
  /// final cappedList = Container.create<List<int>, List<int>>(
  ///   create: (init) => List<int>.from(init ?? [], growable: false),
  ///   add: (tissue, list, e) {
  ///     if (list.length < 10) { list.add(e); return true; }
  ///     return false;
  ///   },
  ///   remove: (tissue, list, e) => list.remove(e),
  /// );
  /// ```
  static Container create<E,I>({
    I Function([dynamic initialization])? create,
    bool Function(Tissue<E> tissue, I container, E e)? add,
    bool Function(Tissue<E> tissue, I container, E e)? remove,
    growable = true,
    bool identitySet = false,
    bool identityMap = false,
  }) {
    final type = I.toString();

    if (I == Iterable<E>) {
      return [create,add,remove].every((a) => a == null)
          ? Container.iterable
          : _Container(create: create ?? _iterableCreate, add: add ?? _iterableAdd, remove: remove ?? _iterableRemove);
    }
    if (type.contains('Set')) {
      return [create,add,remove].every((a) => a == null)
          ? (identitySet ? Container.identitySet : Container.set)
          : _Container(create: create ?? (identitySet ? _identitySetCreate : _setCreate) , add: add ?? _setAdd, remove: remove ?? _setRemove);
    }

    if (type.contains('List')) {
      return [create,add,remove].every((a) => a == null)
          ? (growable ? Container.growableTrue : Container.growableFalse)
          : _Container(create: create ?? (growable ? _growableTrueCreate : _growableFalseCreate), add: add ?? _setAdd, remove: remove ?? _setRemove);
    }
    if (type.contains('Queue')) {
      return [create,add,remove].every((a) => a == null)
          ? Container.queue
          : _Container(create: create ?? _queueCreate, add: add ?? _queueAdd, remove: remove ?? _queueRemove);
    }
    if (type.contains('Map')) {
      return [create,add,remove].every((a) => a == null)
          ? (identityMap ? Container.identityMap : Container.map)
          : _Container(create: create ?? (identitySet ? _identitySetCreate : _setCreate) , add: add ?? _setAdd, remove: remove ?? _setRemove);
    }
    if (type.contains('?')) {
      return [create,add,remove].every((a) => a == null)
          ? Container.value
          : _Container(create: create ?? _valueCreate, add: add ?? _valueAdd, remove: remove ?? _valueRemove);
    }

    return _Container(create: create ?? _iterableCreate, add: add ?? _iterableAdd, remove: remove ?? _iterableRemove);
  }

  // Iterable<Never>
  static Iterable<Never> _iterableNeverCreate <Never>([Iterable? elements]) {
    return const Iterable.empty();
  }
  static bool _iterableNeverAdd <Never>(Tissue<Never> tissue, Iterable<Never> store, Never e) => false;
  static bool _iterableNeverRemove <Never>(Tissue<Never> tissue, Iterable<Never> store, Never e) => false;

  // Iterable
  static Iterable<E> _iterableCreate <E>([Iterable? elements]) {
    return elements != null
        ? Iterable<E>.generate(elements.length, (i) => elements.elementAt(i))
        : Iterable<E>.empty();
  }
  static bool _iterableAdd <E>(Tissue<E> tissue, Iterable<E> store, E e) => false;
  static bool _iterableRemove <E>(Tissue<E> tissue, Iterable<E> store, E e) => false;

  // Set
  static Set<E> _setCreate <E>([Iterable<E>? i]) => i != null ? Set<E>.of(i) : <E>{};
  static Set<E> _identitySetCreate <E>([Iterable<E>? i]) => i != null ? (Set<E>.identity()..addAll(i)) : Set<E>.identity();
  static bool _setAdd <E>(Tissue<E> tissue, Set<E> container, E e) => container.add(e);
  static bool _setRemove <E>(Tissue<E> tissue, Set<E> container, E e) => container.remove(e);

  // List
  static List<E> _listCreate <E>([Iterable<E>? i]) => i != null ? List<E>.of(i) : <E>[];
  static List<E> _growableTrueCreate <E>([Iterable<E>? i]) => i != null ? List<E>.from(i, growable: true) : List<E>.empty(growable: true);
  static List<E> _growableFalseCreate <E>([Iterable<E>? i]) => i != null ? List<E>.from(i, growable: false) : List<E>.empty(growable: false);
  static bool _listAdd<E>(Tissue <E> tissue, List<E> container, E e) {
    container.add(e);
    return true;
  }
  static bool _listRemove <E>(Tissue<E> tissue, List<E> container, E e) => container.remove(e);

  // Queue
  static Queue<E> _queueCreate <E>([Iterable<E>? i]) => i != null ? Queue<E>.of(i) : Queue<E>();
  static bool _queueAdd <E>(TissueQueue<E> base, Queue<E> container, E e) {
    if ((base as TissueQueueBase)._nucleus.capacity == container.length) {
      container.removeFirst();
      container.addLast(e);
      return true;
    }
    container.addLast(e);
    return true;
  }
  static bool _queueRemove <E>(TissueQueue<E> base, Queue<E> container, E e) {
    return container.remove(e);
  }

  // Value
  static ValueContainer<V> _valueCreate <V>([V? value]) {
    return ValueContainer<V>(value);
  }

  static bool _valueAdd <V>(TissueValue<V> tissue, ValueContainer<V> container, V? v) {
    if (container.value != v) {
      container.value = v;
      return true;
    }
    return false;
  }

  static bool _valueRemove <V>(Tissue<V> tissue, ValueContainer<V> container, V? v) {
    if (container.value == v) {
      container.value = null;
      return true;
    }
    return false;
  }

  // Final Value
  static V _finalValueCreate <V>(V value) {
    return value;
  }

  static bool _finalValueAdd <V>(TissueValue<V> tissue, ValueContainer<V> container, V v) {
    return false;
  }

  static bool _finalValueRemove <V>(Tissue<V> tissue, ValueContainer<V> container, V v) {
    return false;
  }

  // Map
  // ignore: strict_top_level_inference
  static Map<K,V> _mapCreate <K,V>([init]) {
    if (init is Map<K,V>) {
      return Map<K,V>.of(init);
    } else if (init is Iterable<MapEntry<K,V>>) {
      return Map<K,V>.fromEntries(init);
    }
    return <K,V>{};
  }

  // ignore: strict_top_level_inference
  static Map<K,V> _identityMapCreate <K,V>([init]) {
    if (init is Map<K,V>) {
      return init;
    } else if (init is Iterable<MapEntry<K,V>>) {
      return Map<K,V>.identity()..addEntries(init);
    }
    return Map<K,V>.identity();
  }

  static bool _mapAdd <K,V>(TissueMap<K,V> tissue, Map<K,V> container, V v) {
    if (v is K && !container.containsKey(v)) {
      container[v] = v;
      return true;
    }
    return false;
  }

  static bool _mapRemove <K,V>(TissueMap<K,V> tissue, Map<K,V> container, V v) {
    if (v is K && container[v] == v) {
      container.remove(v);
      return true;
    }
    return false;
  }

}