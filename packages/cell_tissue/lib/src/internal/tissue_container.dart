// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// An internal class that encapsulates the specific create, add, and remove
/// functions that define the behavior for a particular type of underlying storage `I`.
///
/// `_Container` acts as a strategy object. Instances of `_Container` are typically
/// obtained from the static constants on the [Container] interface (e.g.,
/// `Container.list`, `Container.set`) or created by `Container.create()`.
/// These instances are then passed to a [TissueContainer] to give it the
/// correct behavior for its specified storage type `I`.
///
/// ### When to use
/// This is an internal class used by the framework's storage strategy system.
/// You never instantiate this directly. Use the [Container] constants and
/// factories instead.
///
/// ### How it works
/// - It holds three strategy functions: `_init` (create/initialize storage),
///   `_add` (insert elements), and `_remove` (remove elements).
/// - It implements the [Container] interface, allowing it to be used both
///   as a standalone strategy and as a builder for [TissueContainer].
/// - The `create` method produces a [TissueContainer] configured with this
///   strategy.
/// - The `init`, `add`, and `remove` methods delegate to the stored functions.
///
/// ### Non‑obvious
/// - When used directly as a `Container`, the `add` and `remove` methods
///   create a **transient** store via `_init()` and operate on it. This is
///   different from `TissueContainer.add`, which operates on a persistent store.
/// - The `_init` function is called with an optional `initialization` parameter
///   that can be any type – the specific strategy interprets it accordingly
///   (e.g., as an `Iterable` for lists, or a `Map` for maps).
/// - The strategy functions are type‑polymorphic – they work with any element
///   type `E`, which is why they are stored as `Function` rather than
///   typed closures.
///
/// ### Type Parameters:
/// * [I]: The type of the underlying storage this `_Container` is configured for
///   (e.g., `List<E>`, `Set<E>`, `ValueContainer<E>`).
class _Container implements Container {

  /// The function responsible for creating/initializing the underlying store.
  ///
  /// Expected signature: `I Function<E>([dynamic initialization])`
  /// where `E` is the element type, and `I` is the store type.
  final Function _init;

  /// The function responsible for adding an element to the store.
  ///
  /// Expected signature:
  /// `bool Function<E>(Tissue<E> tissue, I container, E e)`
  final Function _add;

  /// The function responsible for removing an element from the store.
  ///
  /// Expected signature:
  /// `bool Function<E>(Tissue<E> tissue, I container, E e)`
  final Function _remove;

  /// Internal constant constructor to create a `_Container` with the required
  /// behavioral functions.
  ///
  /// This is used by the static constants and factory methods on the [Container]
  /// interface to instantiate concrete strategies.
  ///
  /// ### When to use
  /// This constructor is called internally by [Container] constants and factories.
  /// You never call it directly.
  ///
  /// ### Parameters:
  /// - `create`: The initialization function (assigned to `_init`). Should return
  ///   an instance of type `I`.
  /// - `add`: The element addition function (assigned to `_add`). Should return
  ///   `true` if the element was successfully added.
  /// - `remove`: The element removal function (assigned to `_remove`). Should
  ///   return `true` if the element was successfully removed.
  const _Container({
    required Function create,
    required Function add,
    required Function remove
  }) : _init = create, _add = add, _remove = remove;

  /// Creates a [TissueContainer] of type `<E,I>` using this `_Container`
  /// instance as its behavioral strategy.
  ///
  /// This is a utility method that allows a `_Container` to easily produce
  /// a `TissueContainer` that will use its defined `_init`, `_add`, and
  /// `_remove` functions.
  ///
  /// ### When to use
  /// This is called internally by the framework when creating a tissue. You
  /// rarely need to call it directly.
  ///
  /// ### How it works
  /// - Creates a new [TissueContainer] with this `_Container` as its strategy.
  /// - If [elements] are provided, they are initialised into the container
  ///   atomically.
  /// - The resulting container is ready to be used as the physical storage
  ///   for a [Tissue].
  ///
  /// ### Parameters:
  /// - [elements]: Optional initial data to populate the container.
  ///
  /// ### Type Parameters:
  /// - [E]: The element type for the new [TissueContainer].
  /// - [I]: The storage type (e.g., `List<E>`, `Set<E>`).
  ///
  /// ### Returns:
  /// A new [TissueContainer<E,I>] configured with this `_Container`'s behavior.
  TissueContainer<E,I> create<E,I extends Iterable<E>>({Iterable<E>? elements}) {
    final container = TissueContainer<E,I>._(this);
    if (elements != null) {
      container.init(elements);
    }
    return container;
  }

  /// Initializes a store of type `I` by delegating to the encapsulated `_init` function.
  ///
  /// When `_Container` is used as a standalone `Container`, this method is called.
  /// The generic type `<Out>` is used here to align with the `Container` interface's
  /// `init` method signature, though `_init` itself is expected to return type `I`.
  ///
  /// ### When to use
  /// This is called internally by the framework. You rarely call it directly.
  ///
  /// ### How it works
  /// - Delegates to the stored `_init` function.
  /// - The [initialization] parameter is passed through to the strategy function.
  /// - The result is cast to `Iterable` to satisfy the `Container` interface.
  ///
  /// ### Parameters:
  /// - [initialization]: Optional data for initialization, passed to the `_init` function.
  ///   The type depends on the specific strategy (e.g., `Iterable` for lists,
  ///   `Map` for maps, or a scalar value for value containers).
  ///
  /// ### Returns:
  /// The initialized store, expected to be of type `I` (cast to `Iterable`).
  @override
  Iterable init([initialization]) => _init(initialization);

  /// Adds an element by first initializing a new store and then calling `_add` on it.
  ///
  /// This implementation is for when `_Container` is used directly as a `Container`.
  /// It calls `this._init()` to get a (potentially new, transient) store instance
  /// and then attempts to add the element to that instance using `this._add`.
  ///
  /// ### When to use
  /// This is called internally by the framework. You rarely call it directly.
  /// For persistent storage, use [TissueContainer.add] instead.
  ///
  /// ### How it works
  /// - Creates a new transient store via `_init()`.
  /// - Calls `_add` with the tissue, the transient store, and the element.
  /// - The result is returned to the caller.
  ///
  /// ### Non‑obvious
  /// - This operates on a **transient** store, not the persistent store that
  ///   backs a [Tissue]. For persistent storage, [TissueContainer] calls the
  ///   `_add` function directly on its own persistent store.
  /// - The transient store is discarded after the operation – this method is
  ///   only used when `_Container` is used as a standalone strategy.
  ///
  /// ### Parameters:
  /// - [tissue]: The [Tissue] instance, passed to `_add`.
  /// - [e]: The element to add, passed to `_add`.
  ///
  /// ### Returns:
  /// `true` if the element was added to the transient store; `false` otherwise.
  @override
  bool add(covariant Tissue tissue, covariant e) => _add(tissue, _init(), e);

  /// Removes an element by first initializing a new store and then calling `_remove` on it.
  ///
  /// Similar to `add`, this is for direct use of `_Container` as a `Container`.
  /// It calls `this._init()` to get a transient store and then attempts to remove
  /// the element from it using `this._remove`.
  ///
  /// ### When to use
  /// This is called internally by the framework. You rarely call it directly.
  /// For persistent storage, use [TissueContainer.remove] instead.
  ///
  /// ### How it works
  /// - Creates a new transient store via `_init()`.
  /// - Calls `_remove` with the tissue, the transient store, and the element.
  /// - The result is returned to the caller.
  ///
  /// ### Non‑obvious
  /// - This operates on a **transient** store, not the persistent store that
  ///   backs a [Tissue]. For persistent storage, [TissueContainer] calls the
  ///   `_remove` function directly on its own persistent store.
  /// - The transient store is discarded after the operation – this method is
  ///   only used when `_Container` is used as a standalone strategy.
  ///
  /// ### Parameters:
  /// - [tissue]: The [Tissue] instance, passed to `_remove`.
  /// - [e]: The element to remove, passed to `_remove`.
  ///
  /// ### Returns:
  /// `true` if the element was removed from the transient store; `false` otherwise.
  @override
  bool remove(covariant Tissue tissue, covariant e) => _remove(tissue, _init(), e);

}